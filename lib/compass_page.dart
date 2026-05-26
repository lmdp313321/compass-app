import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class CompassPage extends StatefulWidget {
  const CompassPage({super.key});

  @override
  State<CompassPage> createState() => _CompassPageState();
}

class _CompassPageState extends State<CompassPage> with WidgetsBindingObserver {
  double _heading = 0;
  StreamSubscription? _subscription;

  static const _directions = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];

  String get _directionText {
    int idx = (_heading / 45).round() % 8;
    return _directions[idx];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSensor();
  }

  void _startSensor() {
    _subscription = magnetometerEventStream().listen(
      (MagnetometerEvent event) {
        if (!mounted) return;
        setState(() {
          _heading = (math.atan2(event.y, event.x) * 180 / math.pi + 360) % 360;
        });
      },
      onError: (e) {
        debugPrint('传感器错误: $e');
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSensor();
    } else if (state == AppLifecycleState.paused) {
      _subscription?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('指南针'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 方向文字
            Text(
              _directionText,
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            // 度数
            Text(
              '\${_heading.toStringAsFixed(1)}°',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            // 指南针表盘
            SizedBox(
              width: 280,
              height: 280,
              child: CustomPaint(
                painter: CompassPainter(
                  heading: _heading,
                  primaryColor: theme.colorScheme.primary,
                  surfaceColor: theme.colorScheme.surface,
                  onSurfaceColor: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // 说明
            Text(
              '将手机平放，指向真实北方',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  final double heading;
  final Color primaryColor;
  final Color surfaceColor;
  final Color onSurfaceColor;

  CompassPainter({
    required this.heading,
    required this.primaryColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // 背景圆
    final bgPaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 外圈
    final borderPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    // 刻度
    for (int i = 0; i < 72; i++) {
      final angle = (i * 5 - heading) * math.pi / 180;
      final isMajor = i % 9 == 0;
      final inner = radius - (isMajor ? 20 : 10);
      final outer = radius - 5;

      final x1 = center.dx + inner * math.cos(angle);
      final y1 = center.dy + inner * math.sin(angle);
      final x2 = center.dx + outer * math.cos(angle);
      final y2 = center.dy + outer * math.sin(angle);

      final linePaint = Paint()
        ..color = isMajor ? primaryColor : onSurfaceColor.withOpacity(0.3)
        ..strokeWidth = isMajor ? 2 : 1;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }

    // 方向文字 (N/S/E/W)
    const dirLabels = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - heading) * math.pi / 180;
      final textRadius = radius - 32;
      final x = center.dx + textRadius * math.sin(angle);
      final y = center.dy - textRadius * math.cos(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: dirLabels[i],
          style: TextStyle(
            color: i == 0 ? Colors.red : onSurfaceColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // 指针 - 红色北针
    final northAngle = (-heading) * math.pi / 180;
    final pointerLen = radius - 25;

    // 北针（红色）
    final northPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(center.dx, center.dy - pointerLen);
    path.lineTo(center.dx - 6, center.dy);
    path.lineTo(center.dx + 6, center.dy);
    path.close();

    final matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..rotateZ(northAngle)
      ..translate(-center.dx, -center.dy);
    final rotated = path.transform(matrix.storage);
    canvas.drawPath(rotated, northPaint);

    // 南针（灰色）
    final southPaint = Paint()
      ..color = onSurfaceColor.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    final southPath = Path();
    southPath.moveTo(center.dx, center.dy + pointerLen);
    southPath.lineTo(center.dx - 6, center.dy);
    southPath.lineTo(center.dx + 6, center.dy);
    southPath.close();
    final southRotated = southPath.transform(matrix.storage);
    canvas.drawPath(southRotated, southPaint);

    // 中心圆点
    final dotPaint = Paint()
      ..color = onSurfaceColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) =>
      oldDelegate.heading != heading;
}
