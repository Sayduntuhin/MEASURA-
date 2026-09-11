import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;

  // Staggered animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _rulerSweep;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _rulerSweep = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.7, curve: Curves.easeInOutCubic),
    );

    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.75, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.9, curve: Curves.easeOut),
    );

    _footerFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();

    // Navigate to next screen after splash completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    widget.nextScreen,
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 600),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF071B49),
                    AppColors.primaryDark,
                    AppColors.deepNavy,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Ambient Background Radial Glows
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // Animated Glowing Logo
                      AnimatedBuilder(
                        animation: Listenable.merge([_controller, _pulseController]),
                        builder: (context, child) {
                          final pulse = 1.0 + (_pulseController.value * 0.06);
                          return FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: Transform.scale(
                                scale: pulse,
                                child: Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryBlue.withValues(
                                          alpha: 0.4 + (_pulseController.value * 0.25),
                                        ),
                                        blurRadius: 36,
                                        spreadRadius: 4 + (_pulseController.value * 6),
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF60A5FA).withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 60,
                                        spreadRadius: 8,
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.straighten_rounded,
                                      size: 72,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 36),

                      // Title & Subtitle with Slide + Fade
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Color(0xFFE0E7FF),
                                    Color(0xFF93C5FD),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ).createShader(bounds),
                                child: const Text(
                                  'MEASURA',
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FadeTransition(
                                opacity: _taglineFade,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'GARMENT QA & TOLERANCE SUITE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.8,
                                      color: Color(0xFFBAE6FD),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Precision Tape Measure Animation Widget
                      AnimatedBuilder(
                        animation: _rulerSweep,
                        builder: (context, child) {
                          return SizedBox(
                            width: 260,
                            height: 44,
                            child: CustomPaint(
                              painter: _PrecisionRulerPainter(
                                progress: _rulerSweep.value,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 50),

                      // Modern Minimal Loading Indicator & Tag
                      FadeTransition(
                        opacity: _footerFade,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color(0xFF60A5FA).withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Initializing system...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.8,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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
}

/// Custom painter for precision garment measurement tape ruler animation
class _PrecisionRulerPainter extends CustomPainter {
  final double progress;

  _PrecisionRulerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Draw baseline ruler track
    final yMid = height * 0.7;
    canvas.drawLine(
      Offset(0, yMid),
      Offset(width, yMid),
      basePaint,
    );

    // Draw active progress baseline
    final activeWidth = width * progress;
    canvas.drawLine(
      Offset(0, yMid),
      Offset(activeWidth, yMid),
      activePaint,
    );

    // Draw tick marks
    const int tickCount = 28;
    for (int i = 0; i <= tickCount; i++) {
      final x = (width / tickCount) * i;
      final isMajor = i % 4 == 0;
      final isHalf = i % 2 == 0 && !isMajor;
      final tickHeight = isMajor ? 16.0 : (isHalf ? 10.0 : 6.0);

      final isPast = x <= activeWidth;
      final currentPaint = isPast ? activePaint : basePaint;

      canvas.drawLine(
        Offset(x, yMid - tickHeight),
        Offset(x, yMid),
        currentPaint,
      );
    }

    // Draw indicator cursor with pulsing precision dot
    if (activeWidth > 0) {
      canvas.drawCircle(
        Offset(activeWidth, yMid),
        7.0,
        glowPaint,
      );
      canvas.drawCircle(
        Offset(activeWidth, yMid),
        4.0,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PrecisionRulerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
