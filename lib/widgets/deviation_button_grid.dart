import 'package:flutter/material.dart';
import '../models/measurement_point.dart';
import '../theme/app_theme.dart';

/// Grid of tappable deviation-value buttons, split into a
/// positive row and a negative row — with instant tactile feedback.
class DeviationButtonGrid extends StatelessWidget {
  final double? selectedValue;
  final ValueChanged<double> onSelected;

  const DeviationButtonGrid({
    super.key,
    required this.onSelected,
    this.selectedValue,
  });

  @override
  Widget build(BuildContext context) {
    final positives =
        kDeviationBuckets.where((v) => v > 0).toList(); // 1/8 .. 1
    final negatives =
        kDeviationBuckets.where((v) => v < 0).toList().reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.selectedBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 8),
            const Text(
              'Positive Deviation (+)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.deepNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _row(positives, isPositive: true),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.remove_rounded, size: 16, color: Colors.deepOrange),
            ),
            const SizedBox(width: 8),
            const Text(
              'Negative Deviation (-)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.deepNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _row(negatives, isPositive: false),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.passGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 16, color: AppColors.passGreen),
            ),
            const SizedBox(width: 8),
            const Text(
              'Exact Nominal Measurement (0)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.deepNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _zeroButton(),
      ],
    );
  }

  Widget _row(List<double> values, {required bool isPositive}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) => _button(v, isPositive: isPositive)).toList(),
    );
  }

  Widget _zeroButton() {
    final selected = selectedValue == 0;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: selected ? AppColors.passGreen : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.passGreen : AppColors.passGreen.withValues(alpha: 0.5),
          width: selected ? 2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.passGreen.withValues(alpha: selected ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelected(0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_rounded,
                size: 20,
                color: selected ? Colors.white : AppColors.passGreen,
              ),
              const SizedBox(width: 8),
              Text(
                '0" (NOMINAL / EXACT SPEC)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                  color: selected ? Colors.white : AppColors.passGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(double value, {required bool isPositive}) {
    final selected = selectedValue == value;

    return Container(
      width: 74,
      height: 50,
      decoration: BoxDecoration(
        color: selected
            ? (isPositive ? AppColors.primaryBlue : Colors.deepOrange)
            : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? (isPositive ? AppColors.primaryBlue : Colors.deepOrange)
              : AppColors.borderLight,
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? (isPositive ? AppColors.primaryBlue : Colors.deepOrange).withValues(alpha: 0.3)
                : AppColors.deepNavy.withValues(alpha: 0.03),
            blurRadius: selected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(value),
          child: Center(
            child: Text(
              formatDeviation(value),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: selected
                    ? Colors.white
                    : (isPositive ? AppColors.deepNavy : const Color(0xFF9A3412)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
