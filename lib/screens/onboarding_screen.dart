import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_histogram.dart';
import 'job_history_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _finishOnboarding() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const JobHistoryScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.straighten_rounded,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        title: const Text(
          'MEASURA ONBOARDING',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.primaryDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _finishOnboarding,
            child: const Text(
              'Skip',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.slateNavy,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildHistogramSlide(),
                  _buildFindingsSummarySlide(),
                  _buildCloudWorkflowSlide(),
                ],
              ),
            ),

            // Bottom Navigation Bar
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderLight.withValues(alpha: 0.7),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(3, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primaryBlue
                              : AppColors.borderLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Get Started Button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < 2) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                        );
                      } else {
                        _finishOnboarding();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == 2 ? 'Get Started' : 'Next Step',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentPage == 2
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 1: Histogram & Summary Data
  Widget _buildHistogramSlide() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.selectedBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live QA Histogram & Stats',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    Text(
                      'Interactive deviation bell curve & pass rates',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.slateNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Interactive Histogram with Summary Data
          const InteractiveHistogram(),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 20,
                  color: AppColors.primaryBlue,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap on the tolerance pills above (±1/8", ±1/4", ±3/8", ±1/2") to see how pass rates and flagged defects calculate in real time.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryDark,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Slide 2: Digital Findings Summary
  Widget _buildFindingsSummarySlide() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.selectedBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Digital Findings Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    Text(
                      'Replaces paper tally sheets with instant tallies',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.slateNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Mock Point Cards
          _mockSummaryRow(
            point: 'Waist Band',
            passCount: 28,
            failCount: 2,
            meanDev: '+0.045"',
            isPass: true,
          ),
          const SizedBox(height: 12),
          _mockSummaryRow(
            point: 'Inseam Length',
            passCount: 30,
            failCount: 0,
            meanDev: '0.000"',
            isPass: true,
          ),
          const SizedBox(height: 12),
          _mockSummaryRow(
            point: 'Thigh Width',
            passCount: 25,
            failCount: 5,
            meanDev: '-0.320"',
            isPass: false,
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    color: AppColors.primaryBlue, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'During inspection, tap deviation numbers (-1" to +1") on the 17-bucket keypad to automatically update counts.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.slateNavy,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Slide 3: Cloud Workflow & History
  Widget _buildCloudWorkflowSlide() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.selectedBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automated Cloud Sync',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    Text(
                      'Real-time factory floor QA collaboration',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.slateNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _featureHighlightBox(
            icon: Icons.history_edu_rounded,
            title: 'Job Batch History',
            description:
                'Store and search past inspection jobs by Style, PO, and Pattern number anytime.',
          ),
          const SizedBox(height: 14),
          _featureHighlightBox(
            icon: Icons.verified_user_rounded,
            title: 'Instant Sign-off & Tolerances',
            description:
                'Eliminate manual calculation errors with automatic mean deviation and pass/fail metrics.',
          ),
          const SizedBox(height: 14),
          _featureHighlightBox(
            icon: Icons.devices_rounded,
            title: 'Multi-Device Access',
            description:
                'Access live inspection batches seamlessly across tablets, mobile phones, and web terminals.',
          ),
        ],
      ),
    );
  }

  Widget _mockSummaryRow({
    required String point,
    required int passCount,
    required int failCount,
    required String meanDev,
    required bool isPass,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPass
              ? AppColors.borderLight
              : AppColors.failRed.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                point,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.deepNavy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPass
                      ? AppColors.passGreen.withValues(alpha: 0.12)
                      : AppColors.failRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPass ? 'PASS' : 'OUT OF TOL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isPass ? AppColors.passGreen : AppColors.failRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Samples: ${passCount + failCount} pcs  ·  Mean: $meanDev',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.slateNavy.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$passCount pass / $failCount out',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isPass ? AppColors.primaryBlue : AppColors.failRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureHighlightBox({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.selectedBlueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.slateNavy.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
