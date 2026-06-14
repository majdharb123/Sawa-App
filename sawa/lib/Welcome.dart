import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> with SingleTickerProviderStateMixin {
  late AnimationController _carController;

  bool _showS = false;
  bool _showA1 = false;
  bool _showW = false;
  bool _showA2 = false;
  bool _showBottomBox = false;

  @override
  void initState() {
    super.initState();
    _carController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _carController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerLogoAndBottomBox();
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _carController.forward();
    });
  }

  void _triggerLogoAndBottomBox() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _showS = true);

    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) setState(() => _showA1 = true);

    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) setState(() => _showW = true);

    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) setState(() => _showA2 = true);

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _showBottomBox = true);
  }

  @override
  void dispose() {
    _carController.dispose();
    super.dispose();
  }

  Path _buildWindingPath(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, -100);
    path.quadraticBezierTo(
      size.width + 50,
      size.height * 0.15,
      size.width / 2,
      size.height * 0.25,
    );
    path.quadraticBezierTo(
      -50,
      size.height * 0.35,
      size.width / 2,
      size.height * 0.45,
    );
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final path = _buildWindingPath(size);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: WhatsAppDoodleMapPainter()),
          ),
          AnimatedBuilder(
            animation: _carController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: RoadTrailPainter(
                  path: path,
                  progress: _carController.value,
                ),
              );
            },
          ),
          Positioned(
            top: size.height * 0.26,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAnimatedLetter("S", _showS, 0),
                _buildAnimatedLetter("A", _showA1, 200),
                _buildAnimatedLetter("W", _showW, 400),
                _buildAnimatedLetter("A", _showA2, 600),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _carController,
            builder: (context, child) {
              final metrics = path.computeMetrics().isNotEmpty
                  ? path.computeMetrics().first
                  : null;

              if (metrics == null) return const SizedBox.shrink();

              final currentLength = metrics.length * _carController.value;
              final tangent = metrics.getTangentForOffset(currentLength);

              final position =
                  tangent?.position ?? Offset(size.width / 2, -100);
              final angle = tangent != null
                  ? tangent.angle + (math.pi / 2)
                  : 0.0;

              return Positioned(
                left: position.dx - 22,
                top: position.dy - 55,
                child: Transform.rotate(
                  angle: angle,
                  child: SizedBox(
                    width: 44,
                    height: 110,
                    child: CustomPaint(painter: RealisticBusPainter()),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              offset: _showBottomBox ? Offset.zero : const Offset(0, 1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _showBottomBox ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 35,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 25,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "How would you like to continue?",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A1F2C),
                        ),
                      ),
                      const SizedBox(height: 25),

                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              title: "Zamil",
                              icon: Icons.person_outline,
                              color: const Color(0xFF1D9E75),
                              onTap: () {
                                context.push('/CreateAccZamil');
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              title: "Captain",
                              icon: Icons.directions_bus_outlined,
                              color: const Color(0xFF185FA5),
                              onTap: () {
                                context.push('/CreateAccCaptain');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              context.push('/login');
                            },
                            child: const Text(
                              "Log in",
                              style: TextStyle(
                                color: Color(0xFF1D9E75),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLetter(String letter, bool isVisible, int delayInMs) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      offset: isVisible ? Offset.zero : const Offset(0, 1.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: isVisible ? 1.0 : 0.0,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 2000),
          builder: (context, value, child) {
            final double time = DateTime.now().millisecondsSinceEpoch / 500;
            final double waveValue = math.sin(time + (delayInMs / 200));

            return Transform.scale(
              scale: isVisible ? 1.0 + (waveValue * 0.05) : 1.0,
              child: Opacity(
                opacity: isVisible ? 0.85 + (waveValue * 0.15) : 1.0,
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 55,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1D9E75),
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class WhatsAppDoodleMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double i = 0; i < size.height; i += 80)
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    for (double i = 0; i < size.width; i += 80)
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoadTrailPainter extends CustomPainter {
  final Path path;
  final double progress;
  RoadTrailPainter({required this.path, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || path.computeMetrics().isEmpty) return;
    final roadPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;
    final metrics = path.computeMetrics().first;
    final currentPath = metrics.extractPath(0, metrics.length * progress);
    canvas.drawPath(currentPath, roadPaint);
    final dashPaint = Paint()
      ..color = const Color(0xFF1D9E75).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const double dashWidth = 10, dashSpace = 8;
    double distance = 0;
    while (distance < metrics.length * progress) {
      final extractPath = metrics.extractPath(distance, distance + dashWidth);
      canvas.drawPath(extractPath, dashPaint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant RoadTrailPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class RealisticBusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final shadowPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(4, 4, w, h),
          const Radius.circular(10),
        ),
      );
    canvas.drawShadow(shadowPath, Colors.black, 10, true);

    final bodyRect = Rect.fromLTWH(0, 0, w, h);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF5F7FA), Color(0xFFFFFFFF), Color(0xFFE4E8EC)],
      ).createShader(bodyRect);

    final bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    final stripeGreen = Paint()..color = const Color(0xFF1D9E75);
    final stripeBlue = Paint()..color = const Color(0xFF185FA5);
    canvas.drawRect(Rect.fromLTWH(2, 10, 3, h - 20), stripeGreen);
    canvas.drawRect(Rect.fromLTWH(w - 5, 10, 3, h - 20), stripeBlue);

    final glassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A2930), Color(0xFF3E515B)],
      ).createShader(Rect.fromLTWH(4, 4, w - 8, 16));

    final windshieldPath = Path()
      ..moveTo(4, 18)
      ..quadraticBezierTo(w / 2, -2, w - 4, 18)
      ..lineTo(w - 6, 22)
      ..lineTo(6, 22)
      ..close();
    canvas.drawPath(windshieldPath, glassPaint);

    final rearGlassPaint = Paint()..color = const Color(0xFF1A2930);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, h - 12, w - 12, 8),
        const Radius.circular(2),
      ),
      rearGlassPaint,
    );

    final roofShadowPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(6, 26, w - 12, h - 45),
          const Radius.circular(4),
        ),
      );
    canvas.drawShadow(roofShadowPath, Colors.black, 4, false);

    final roofPaint = Paint()..color = Colors.white;
    final roofRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 26, w - 12, h - 45),
      const Radius.circular(4),
    );
    canvas.drawRRect(roofRect, roofPaint);

    final acPaint = Paint()..color = const Color(0xFFE0E0E0);
    final acBorder = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final acRect1 = Rect.fromLTWH(12, 38, w - 24, 20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(acRect1, const Radius.circular(3)),
      acPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(acRect1, const Radius.circular(3)),
      acBorder,
    );

    final fanLine = Paint()
      ..color = Colors.black45
      ..strokeWidth = 1.5;
    for (double i = 41; i < 56; i += 3.5) {
      canvas.drawLine(Offset(16, i), Offset(w - 16, i), fanLine);
    }

    final acRect2 = Rect.fromLTWH(16, h - 40, w - 32, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(acRect2, const Radius.circular(2)),
      acPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(acRect2, const Radius.circular(2)),
      acBorder,
    );

    final mirrorPaint = Paint()..color = Colors.black87;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-3, 14, 5, 8),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - 2, 14, 5, 8),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );

    final headlightGlow = Paint()
      ..color = Colors.yellowAccent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final headlightSolid = Paint()..color = Colors.white;

    canvas.drawOval(Rect.fromLTWH(5, -2, 8, 6), headlightGlow);
    canvas.drawOval(Rect.fromLTWH(w - 13, -2, 8, 6), headlightGlow);
    canvas.drawOval(Rect.fromLTWH(6, 0, 6, 3), headlightSolid);
    canvas.drawOval(Rect.fromLTWH(w - 12, 0, 6, 3), headlightSolid);

    final taillightGlow = Paint()
      ..color = Colors.redAccent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final taillightSolid = Paint()..color = Colors.red;

    canvas.drawRect(Rect.fromLTWH(4, h - 2, 10, 4), taillightGlow);
    canvas.drawRect(Rect.fromLTWH(w - 14, h - 2, 10, 4), taillightGlow);
    canvas.drawRect(Rect.fromLTWH(5, h - 1, 8, 2), taillightSolid);
    canvas.drawRect(Rect.fromLTWH(w - 13, h - 1, 8, 2), taillightSolid);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
