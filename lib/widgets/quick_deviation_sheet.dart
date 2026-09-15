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
  final String? currentDeviationText;
  final Function(double deviation, String text) onSelect;
  final VoidCallback onClear;
  final bool isDocked;
  final VoidCallback? onClose;
  final bool advanceTopToBottom;
  final VoidCallback? onToggleAdvanceDirection;
  final VoidCallback? onOpenKeyboard;

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
    this.currentDeviationText,
    required this.onSelect,
    required this.onClear,
    this.isDocked = false,
    this.onClose,
    this.advanceTopToBottom = true,
    this.onToggleAdvanceDirection,
    this.onOpenKeyboard,
  });

  /// Sequential Options: 0 in center, Positives: 1/8 to 2", Negatives: -1/8 to -2"
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
    {'value': 1.125, 'label': '+1 1/8"'},
    {'value': 1.25, 'label': '+1 1/4"'},
    {'value': 1.375, 'label': '+1 3/8"'},
    {'value': 1.5, 'label': '+1 1/2"'},
    {'value': 1.625, 'label': '+1 5/8"'},
    {'value': 1.75, 'label': '+1 3/4"'},
    {'value': 1.875, 'label': '+1 7/8"'},
    {'value': 2.0, 'label': '+2"'},
    // Negatives in sequence from -1/8 to -2"
    {'value': -0.125, 'label': '-1/8"'},
    {'value': -0.25, 'label': '-1/4"'},
    {'value': -0.375, 'label': '-3/8"'},
    {'value': -0.5, 'label': '-1/2"'},
    {'value': -0.625, 'label': '-5/8"'},
    {'value': -0.75, 'label': '-3/4"'},
    {'value': -0.875, 'label': '-7/8"'},
    {'value': -1.0, 'label': '-1"'},
    {'value': -1.125, 'label': '-1 1/8"'},
    {'value': -1.25, 'label': '-1 1/4"'},
    {'value': -1.375, 'label': '-1 3/8"'},
    {'value': -1.5, 'label': '-1 1/2"'},
    {'value': -1.625, 'label': '-1 5/8"'},
    {'value': -1.75, 'label': '-1 3/4"'},
    {'value': -1.875, 'label': '-1 7/8"'},
    {'value': -2.0, 'label': '-2"'},
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

    final positives = deviationOptions.where((opt) => (opt['value'] as double) > 0).toList();
    final negatives = deviationOptions.where((opt) => (opt['value'] as double) < 0).toList();

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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Size: $size • Spec: $specValue" • #$sampleIndex',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.slateNavy.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (currentDeviationText != null && currentDeviationText!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _checkWithinTol(currentDeviation ?? 0.0)
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$currentDeviationText"',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _checkWithinTol(currentDeviation ?? 0.0)
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Tolerance Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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
                // General Keyboard Button
                if (onOpenKeyboard != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      if (!isDocked) Navigator.pop(context);
                      onOpenKeyboard!();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_alt_rounded, size: 14, color: AppColors.primaryBlue),
                          SizedBox(width: 3),
                          Text(
                            'Keyboard',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (onToggleAdvanceDirection != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onToggleAdvanceDirection,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            advanceTopToBottom
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_forward_rounded,
                            size: 13,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            advanceTopToBottom ? 'Down' : 'Right',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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

            // Tolerance Buttons arranged sequentially with horizontal scrolling
            // Row 1: Zero (Spec) & Positive Deviations in Sequence: 0, 1/8 .. +2" + [Keyboard Button]
            // Row 2: Negative Deviations in Sequence: Clear/Trash, -1/8 .. -2" + [Keyboard Button]
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Positives Row (0 .. +2" + Custom)
                  Row(
                    children: [
                      _buildButton(context, deviationOptions[0], isCompact: isLandscape), // 0 (Spec)
                      const SizedBox(width: 6),
                      ...positives.map((opt) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildButton(context, opt, isCompact: isLandscape),
                          )),
                      if (onOpenKeyboard != null)
                        _buildKeyboardOptionButton(context, isCompact: isLandscape),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Negatives Row (-1/8 .. -2")
                  Row(
                    children: [
                      // Spacer to align with 0 or Clear button
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
                      ...negatives.map((opt) => Padding(
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

  Widget _buildKeyboardButton(BuildContext context, {required bool isCompact}) {
    return SizedBox(
      height: isCompact ? 36 : 40,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFEFF6FF),
          side: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        onPressed: () {
          if (!isDocked) Navigator.pop(context);
          if (onOpenKeyboard != null) onOpenKeyboard!();
        },
        icon: const Icon(Icons.keyboard_alt_rounded, size: 15, color: AppColors.primaryBlue),
        label: const Text(
          'More (⌨️)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardOptionButton(BuildContext context, {required bool isCompact}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: _buildKeyboardButton(context, isCompact: isCompact),
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
      width: isZero ? (isCompact ? 68 : 72) : (isCompact ? 62 : 66),
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
