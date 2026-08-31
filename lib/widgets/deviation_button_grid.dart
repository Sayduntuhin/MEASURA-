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
        const Row(
          children: [
            Icon(Icons.add_circle_outline, size: 18, color: AppColors.primaryBlue),
            SizedBox(width: 6),
            Text(
              'Positive Deviation (+)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.deepNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _row(positives),
        const SizedBox(height: 18),
        const Row(
          children: [
            Icon(Icons.remove_circle_outline, size: 18, color: Colors.orange),
            SizedBox(width: 6),
            Text(
              'Negative Deviation (-)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.deepNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _row(negatives),
        const SizedBox(height: 18),
        const Row(
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: AppColors.passGreen),
            SizedBox(width: 6),
            Text(
              'Exact Measurement (0)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.deepNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _zeroButton(),
      ],
    );
  }

  Widget _row(List<double> values) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) => _button(v)).toList(),
    );
  }

  Widget _zeroButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceWhite,
          side: const BorderSide(color: AppColors.passGreen, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => onSelected(0),
        child: const Text(
          '0"  (EXACT MATCH)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: AppColors.passGreen,
          ),
        ),
      ),
    );
  }

  Widget _button(double value) {
    final selected = selectedValue == value;
    return SizedBox(
      width: 72,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor:
              selected ? AppColors.primaryBlue : AppColors.surfaceWhite,
          foregroundColor: selected ? Colors.white : AppColors.deepNavy,
          side: BorderSide(
            color: selected ? AppColors.primaryBlue : AppColors.borderLight,
            width: selected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => onSelected(value),
        child: Text(
          formatDeviation(value),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: selected ? Colors.white : AppColors.deepNavy,
          ),
        ),
      ),
    );
  }
}
