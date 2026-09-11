import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _loading = false;
  String? _error;

  late final AnimationController _entranceController;
  late final AnimationController _floatController;
  late final AnimationController _pulseController;

  // Staggered entrance animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;
  late final Animation<double> _featuresFade;

  // Feature carousel
  int _activeFeatureIndex = 0;
  Timer? _featureTimer;

  final List<_FeatureItem> _features = const [
    _FeatureItem(
      icon: Icons.straighten_rounded,
      title: 'Precision QA Measurement',
      desc: 'Real-time tolerance validation & deviation tracking.',
    ),
    _FeatureItem(
      icon: Icons.insights_rounded,
      title: 'Batch Statistics & Tallies',
      desc: 'Instant pass/fail distribution and sample analytics.',
    ),
    _FeatureItem(
      icon: Icons.cloud_done_rounded,
      title: 'Instant Cloud Sync',
      desc: 'Secure Firestore sync across all production lines.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _headerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _cardFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _featuresFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    );

    // 2. Floating & Pulsing ambient animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _entranceController.forward();

    // 3. Feature highlight timer
    _featureTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _activeFeatureIndex = (_activeFeatureIndex + 1) % _features.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _featureTimer?.cancel();
    _entranceController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      final credential = await auth.signInWithGoogle();
      if (credential == null && mounted) {
        setState(() => _loading = false);
      }
      // When login succeeds, _AuthGate automatically navigates.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Google Sign-In failed: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Dynamic Ambient Animated Blobs
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              final floatOffset = _floatController.value * 20.0;
              return Stack(
                children: [
                  Positioned(
                    top: -90 + floatOffset,
                    right: -70,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 240 - floatOffset,
                    left: -90,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Main Scrollable Area
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),

                      // Animated Logo with Floating Glow
                      AnimatedBuilder(
                        animation: Listenable.merge(
                            [_entranceController, _pulseController, _floatController]),
                        builder: (context, child) {
                          final floatY =
                              (1 - _floatController.value) * 6.0; // gentle float
                          final glowSpread = 4.0 + (_pulseController.value * 8.0);
                          final glowAlpha = 0.16 + (_pulseController.value * 0.12);

                          return FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: Transform.translate(
                                offset: Offset(0, floatY),
                                child: Center(
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryBlue
                                              .withValues(alpha: glowAlpha),
                                          blurRadius: 28,
                                          spreadRadius: glowSpread,
                                          offset: const Offset(0, 8),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF38BDF8)
                                              .withValues(alpha: 0.12),
                                          blurRadius: 40,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.straighten_rounded,
                                        size: 60,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 22),

                      // Title & Subtitle Entrance
                      SlideTransition(
                        position: _headerSlide,
                        child: FadeTransition(
                          opacity: _headerFade,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [
                                        AppColors.primaryDark,
                                        AppColors.primaryBlue,
                                      ],
                                    ).createShader(bounds),
                                    child: const Text(
                                      'MEASURA',
                                      style: TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3.0,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.selectedBlueLight,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'GARMENT QA & TOLERANCE SUITE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryBlue,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Main Login & Features Card
                      SlideTransition(
                        position: _cardSlide,
                        child: FadeTransition(
                          opacity: _cardFade,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.borderLight.withValues(alpha: 0.8),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryDark
                                      .withValues(alpha: 0.06),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Welcome Back',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.deepNavy,
                                    letterSpacing: -0.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in with your Google account to access measurement batches and real-time QA stats.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.slateNavy.withValues(alpha: 0.75),
                                    height: 1.45,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 22),

                                // Animated Feature Carousel Indicator
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.05, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    key: ValueKey<int>(_activeFeatureIndex),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardFill,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.borderLight
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryBlue
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            _features[_activeFeatureIndex].icon,
                                            size: 20,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _features[_activeFeatureIndex]
                                                    .title,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.deepNavy,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _features[_activeFeatureIndex]
                                                    .desc,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.slateNavy
                                                      .withValues(alpha: 0.7),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Feature dots
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_features.length, (index) {
                                    final isActive = index == _activeFeatureIndex;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      width: isActive ? 16 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppColors.primaryBlue
                                            : AppColors.borderLight,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    );
                                  }),
                                ),

                                const SizedBox(height: 24),

                                // Error Banner
                                if (_error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline_rounded,
                                            size: 20,
                                            color: Colors.red.shade700),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                              color: Colors.red.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                // Google Sign-In Button with Interactive State
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed:
                                        _loading ? null : _handleGoogleSignIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.deepNavy,
                                      elevation: 0,
                                      side: const BorderSide(
                                        color: AppColors.borderLight,
                                        width: 1.4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: AppColors.primaryBlue,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              // Clean Google G Icon
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Image.network(
                                                  'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                    Icons.g_mobiledata,
                                                    size: 24,
                                                    color: AppColors.primaryBlue,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                'Continue with Google',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.deepNavy,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Footer Cloud Badge
                      FadeTransition(
                        opacity: _featuresFade,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.passGreen.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                size: 14,
                                color: AppColors.passGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'End-to-End Encrypted Cloud Sync',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slateNavy.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
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
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.desc,
  });
}
