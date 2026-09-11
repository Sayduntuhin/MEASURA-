import 'package:flutter/material.dart';
import '../models/tolerance_standard.dart';
import '../theme/app_theme.dart';

class QuickDeviationSheet extends StatelessWidget {
  final String pomCode;
  final String description;
  final String size;
  final String specValue;
  final int sampleIndex;
  final double tolerance;
  final PomTolerance? pomTolerance;
  final double? currentDeviation;
  final Function(double deviation, String text) onSelect;
  final VoidCallback onClear;
  final bool isDocked;
  final VoidCallback? onClose;

  const QuickDeviationSheet({
    super.key,
    required this.pomCode,
    required this.description,
    required this.size,
    required this.specValue,
    required this.sampleIndex,
    required this.tolerance,
    this.pomTolerance,
    this.currentDeviation,
    required this.onSelect,
    required this.onClear,
    this.isDocked = false,
    this.onClose,
  });

  /// Sequential Options: 0 in center, Positives: 1/8 to 1, Negatives: -1/8 to -1 (including 7/8)
  static const List<Map<String, dynamic>> deviationOptions = [
    // Zero / Exact nominal
    {'value': 0.0, 'label': '0 (Spec)'},
    // Positives in ascending sequence
    {'value': 0.125, 'label': '+1/8"'},
    {'value': 0.25, 'label': '+1/4"'},
    {'value': 0.375, 'label': '+3/8"'},
    {'value': 0.5, 'label': '+1/2"'},
    {'value': 0.625, 'label': '+5/8"'},
    {'value': 0.75, 'label': '+3/4"'},
    {'value': 0.875, 'label': '+7/8"'},
    {'value': 1.0, 'label': '+1"'},
    // Negatives in sequence from -1/8 to -1
    {'value': -0.125, 'label': '-1/8"'},
    {'value': -0.25, 'label': '-1/4"'},
    {'value': -0.375, 'label': '-3/8"'},
    {'value': -0.5, 'label': '-1/2"'},
    {'value': -0.625, 'label': '-5/8"'},
    {'value': -0.75, 'label': '-3/4"'},
    {'value': -0.875, 'label': '-7/8"'},
    {'value': -1.0, 'label': '-1"'},
  ];

  static String formatCleanDisplay(double val, String label) {
    if (val == 0.0) return '0';
    String clean = label.replaceAll('"', '').trim();
    if (val > 0 && !clean.startsWith('+')) {
      clean = '+$clean';
    }
    // Remove any accidental multiple plus signs
    while (clean.startsWith('++')) {
      clean = clean.substring(1);
    }
    return clean;
  }

  bool _checkWithinTol(double val) {
    if (pomTolerance != null) {
      return pomTolerance!.isWithin(val);
    }
    return val.abs() <= (tolerance + 0.0001);
  }

  @override
  Widget build(BuildContext context) {
    final tolString = pomTolerance != null ? pomTolerance!.displayString : '±$tolerance"';
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isLandscape ? 14 : 18,
        isDocked ? 10 : 14,
        isLandscape ? 14 : 18,
        isDocked ? 12 : 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: isDocked
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar (modal only)
            if (!isDocked) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Header row with POM, Size, Spec, Tolerance & Close
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pomCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.deepNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Size: $size • Spec: $specValue" • #$sampleIndex',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.slateNavy.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardFill,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    'Tol: $tolString',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slateNavy,
                    ),
                  ),
                ),
                if (isDocked && onClose != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 20, color: AppColors.slateNavy),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.borderLight, height: 1),
            const SizedBox(height: 10),

            // Tolerance Buttons arranged sequentially
            // Row 1: Zero (Spec) & Positive Deviations in Sequence: 0, 1/8, 1/4, 3/8, 1/2, 5/8, 3/4, 7/8, 1
            // Row 2: Negative Deviations in Sequence: -1/8, -1/4, -3/8, -1/2, -5/8, -3/4, -7/8, -1
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Positives Row (0 .. +1)
                  Row(
                    children: [
                      _buildButton(context, deviationOptions[0], isCompact: isLandscape), // 0 (Spec)
                      const SizedBox(width: 6),
                      ...deviationOptions.sublist(1, 9).map((opt) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildButton(context, opt, isCompact: isLandscape),
                          )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Negatives Row (-1/8 .. -1)
                  Row(
                    children: [
                      // Spacer to align with 0
                      SizedBox(
                        width: isLandscape ? 68 : 72,
                        child: currentDeviation != null
                            ? InkWell(
                                onTap: () {
                                  if (!isDocked) Navigator.pop(context);
                                  onClear();
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: isLandscape ? 36 : 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.outTolRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.outTolRed.withValues(alpha: 0.3)),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.outTolRed),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      ...deviationOptions.sublist(9).map((opt) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildButton(context, opt, isCompact: isLandscape),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, Map<String, dynamic> opt, {required bool isCompact}) {
    final double val = opt['value'];
    final String label = opt['label'];
    final isZero = val == 0.0;
    final isWithin = _checkWithinTol(val);
    final isSelected = currentDeviation != null && (currentDeviation! - val).abs() < 0.001;

    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isSelected) {
      bgColor = isWithin ? AppColors.inTolGreen : AppColors.outTolRed;
      textColor = Colors.white;
      borderColor = bgColor;
    } else if (isZero) {
      bgColor = AppColors.inTolLight;
      textColor = AppColors.inTolGreen;
      borderColor = AppColors.inTolGreen.withValues(alpha: 0.4);
    } else if (isWithin) {
      bgColor = AppColors.inTolLight.withValues(alpha: 0.5);
      textColor = AppColors.inTolGreen;
      borderColor = AppColors.borderLight;
    } else {
      bgColor = AppColors.outTolLight.withValues(alpha: 0.6);
      textColor = AppColors.outTolRed;
      borderColor = AppColors.borderLight;
    }

    final displayStr = formatCleanDisplay(val, label);

    return SizedBox(
      width: isZero ? (isCompact ? 68 : 72) : (isCompact ? 60 : 64),
      height: isCompact ? 36 : 40,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {
          if (!isDocked) Navigator.pop(context);
          onSelect(val, displayStr);
        },
        child: Text(
          label,
          style: TextStyle(
            fontSize: isZero ? 11 : 12,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
