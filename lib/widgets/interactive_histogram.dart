import 'package:flutter/material.dart';
import '../models/measurement_point.dart';
import '../theme/app_theme.dart';

class InteractiveHistogram extends StatefulWidget {
  final double tolerance;
  final Function(double selectedTolerance)? onToleranceChanged;
  final List<double>? deviations;
  final String? title;

  const InteractiveHistogram({
    super.key,
    this.tolerance = 0.25,
    this.onToleranceChanged,
    this.deviations,
    this.title,
  });

  @override
  State<InteractiveHistogram> createState() => _InteractiveHistogramState();
}

class _InteractiveHistogramState extends State<InteractiveHistogram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _barGrowth;

  late double _currentTolerance;
  int? _selectedBucketIndex;

  // Standard garment QA measurement sample buckets (-1" to +1" in 1/8" steps)
  final List<double> _buckets = [
    -1.0,
    -0.875,
    -0.75,
    -0.625,
    -0.5,
    -0.375,
    -0.25,
    -0.125,
    0.0,
    0.125,
    0.25,
    0.375,
    0.5,
    0.625,
    0.75,
    0.875,
    1.0,
  ];

  late List<int> _sampleCounts;

  List<int> _calculateCounts() {
    if (widget.deviations != null) {
      final counts = List<int>.filled(_buckets.length, 0);
      for (final dev in widget.deviations!) {
        int bestIdx = 0;
        double bestDist = (dev - _buckets[0]).abs();
        for (int i = 1; i < _buckets.length; i++) {
          final dist = (dev - _buckets[i]).abs();
          if (dist < bestDist) {
            bestDist = dist;
            bestIdx = i;
          }
        }
        counts[bestIdx]++;
      }
      return counts;
    }

    // Default simulated distribution for onboarding
    return [
      0, // -1"
      1, // -7/8"
      2, // -3/4"
      3, // -5/8"
      4, // -1/2"
      8, // -3/8"
      12, // -1/4"
      18, // -1/8"
      28, // 0 (Nominal)
      20, // +1/8"
      14, // +1/4"
      7, // +3/8"
      3, // +1/2"
      2, // +5/8"
      1, // +3/4"
      0, // +7/8"
      0, // +1"
    ];
  }


  @override
  void initState() {
    super.initState();
    _currentTolerance = widget.tolerance;
    _sampleCounts = _calculateCounts();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _barGrowth = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant InteractiveHistogram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tolerance != widget.tolerance || oldWidget.deviations != widget.deviations) {
      setState(() {
        _currentTolerance = widget.tolerance;
        _sampleCounts = _calculateCounts();
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int get totalSamples =>
      _sampleCounts.fold<int>(0, (sum, count) => sum + count);

  int get withinToleranceSamples {
    int sum = 0;
    for (int i = 0; i < _buckets.length; i++) {
      if (_buckets[i].abs() <= _currentTolerance + 0.0001) {
        sum += _sampleCounts[i];
      }
    }
    return sum;
  }

  int get outOfToleranceSamples => totalSamples - withinToleranceSamples;

  double get passRate =>
      totalSamples == 0 ? 0 : (withinToleranceSamples / totalSamples);

  double get meanDeviation {
    if (totalSamples == 0) return 0.0;
    double totalDev = 0;
    for (int i = 0; i < _buckets.length; i++) {
      totalDev += _buckets[i] * _sampleCounts[i];
    }
    return totalDev / totalSamples;
  }

  @override
  Widget build(BuildContext context) {
    final rawMax = _sampleCounts.isEmpty ? 1 : _sampleCounts.reduce((a, b) => a > b ? a : b);
    final maxCount = rawMax <= 0 ? 1 : rawMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary KPI Stats Cards
        Row(
          children: [
            Expanded(
              child: _kpiCard(
                title: 'Pass Rate',
                value: '${(passRate * 100).toStringAsFixed(1)}%',
                subtitle: '$withinToleranceSamples / $totalSamples in tol',
                badgeColor: passRate >= 0.9
                    ? AppColors.passGreen
                    : (passRate >= 0.75 ? Colors.orange : AppColors.failRed),
                isPositive: passRate >= 0.9,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpiCard(
                title: 'Mean Dev',
                value:
                    '${meanDeviation >= 0 ? '+' : ''}${meanDeviation.toStringAsFixed(3)}"',
                subtitle: 'Total: $totalSamples pcs',
                badgeColor: AppColors.primaryBlue,
                isPositive: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpiCard(
                title: 'Tolerance',
                value: '±${formatDeviation(_currentTolerance)}"',
                subtitle: '$outOfToleranceSamples flagged',
                badgeColor: outOfToleranceSamples == 0
                    ? AppColors.passGreen
                    : AppColors.failRed,
                isPositive: outOfToleranceSamples == 0,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Interactive Tolerance Pill Selector
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            Text(
              'Tolerance Limit: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.slateNavy.withValues(alpha: 0.8),
              ),
            ),
            ...[0.125, 0.25, 0.375, 0.5].map((tol) {
              final isSelected = (_currentTolerance - tol).abs() < 0.001;
              return InkWell(
                onTap: () {
                  setState(() {
                    _currentTolerance = tol;
                  });
                  widget.onToleranceChanged?.call(tol);
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.cardFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Text(
                    '±${formatDeviation(tol)}"',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.deepNavy,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),

        const SizedBox(height: 16),

        // Animated Histogram Chart Container
        Container(
          height: 190,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _barGrowth,
            builder: (context, child) {
              return Column(
                children: [
                  // Bars area
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(_buckets.length, (index) {
                        final bucket = _buckets[index];
                        final count = _sampleCounts[index];
                        final isWithinTol =
                            bucket.abs() <= _currentTolerance + 0.0001;
                        final isSelected = _selectedBucketIndex == index;
                        final isZero = bucket == 0;

                        final barHeightFraction =
                            (count / maxCount) * _barGrowth.value;

                        final barColor = isWithinTol
                            ? (isZero
                                ? AppColors.primaryBlue
                                : const Color(0xFF38BDF8))
                            : AppColors.failRed;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedBucketIndex =
                                    _selectedBucketIndex == index ? null : index;
                              });
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Count badge on hover/selected
                                if (isSelected || count >= 15)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.deepNavy,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.slateNavy
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                const SizedBox(height: 3),

                                // Bar
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  height:
                                      (105 * barHeightFraction).clamp(4.0, 105.0),
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                    border: isSelected
                                        ? Border.all(
                                            color: AppColors.deepNavy,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Divider baseline
                  Container(
                    height: 1.5,
                    color: AppColors.slateNavy.withValues(alpha: 0.15),
                    margin: const EdgeInsets.only(top: 2, bottom: 4),
                  ),

                  // Bucket Labels
                  Row(
                    children: List.generate(_buckets.length, (index) {
                      final bucket = _buckets[index];
                      final isZero = bucket == 0;
                      return Expanded(
                        child: Text(
                          formatDeviation(bucket),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight:
                                isZero ? FontWeight.w900 : FontWeight.w600,
                            color: isZero
                                ? AppColors.primaryBlue
                                : AppColors.slateNavy,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Legend
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 6,
          children: [
            _legendItem(const Color(0xFF38BDF8), 'Within Tolerance'),
            _legendItem(AppColors.primaryBlue, 'Nominal (0)'),
            _legendItem(AppColors.failRed, 'Out of Tolerance'),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.slateNavy.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color badgeColor,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slateNavy.withValues(alpha: 0.7),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: badgeColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.slateNavy.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
