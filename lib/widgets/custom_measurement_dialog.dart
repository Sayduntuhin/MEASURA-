import 'package:flutter/material.dart';
import '../models/tolerance_standard.dart';
import '../services/measurement_parser.dart';
import '../theme/app_theme.dart';

/// Modal dialog / bottom-sheet allowing custom measurement and deviation entry
/// via standard keyboard, with live fraction parsing and tolerance evaluation.
class CustomMeasurementDialog extends StatefulWidget {
  final String pomCode;
  final String description;
  final String size;
  final String specValue;
  final int sampleIndex;
  final double? currentDeviation;
  final String? currentDeviationText;
  final double tolerance;
  final PomTolerance? pomTolerance;
  final Function(double deviation, String text) onSave;
  final Function(double deviation, String text)? onSaveAndNext;
  final VoidCallback? onClear;
  final bool advanceTopToBottom;

  const CustomMeasurementDialog({
    super.key,
    required this.pomCode,
    required this.description,
    required this.size,
    required this.specValue,
    required this.sampleIndex,
    this.currentDeviation,
    this.currentDeviationText,
    required this.tolerance,
    this.pomTolerance,
    required this.onSave,
    this.onSaveAndNext,
    this.onClear,
    this.advanceTopToBottom = true,
  });

  static Future<void> show(
    BuildContext context, {
    required String pomCode,
    required String description,
    required String size,
    required String specValue,
    required int sampleIndex,
    double? currentDeviation,
    String? currentDeviationText,
    required double tolerance,
    PomTolerance? pomTolerance,
    required Function(double deviation, String text) onSave,
    Function(double deviation, String text)? onSaveAndNext,
    VoidCallback? onClear,
    bool advanceTopToBottom = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomMeasurementDialog(
        pomCode: pomCode,
        description: description,
        size: size,
        specValue: specValue,
        sampleIndex: sampleIndex,
        currentDeviation: currentDeviation,
        currentDeviationText: currentDeviationText,
        tolerance: tolerance,
        pomTolerance: pomTolerance,
        onSave: onSave,
        onSaveAndNext: onSaveAndNext,
        onClear: onClear,
        advanceTopToBottom: advanceTopToBottom,
      ),
    );
  }

  @override
  State<CustomMeasurementDialog> createState() => _CustomMeasurementDialogState();
}

class _CustomMeasurementDialogState extends State<CustomMeasurementDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  // 0 = Direct Deviation Mode (e.g. +2, -1 1/2), 1 = Measured Tape Reading Mode (e.g. 34 1/4)
  int _entryMode = 0;

  double? _parsedDeviation;
  String _formattedDisplay = '';
  double? _parsedActualReading;

  @override
  void initState() {
    super.initState();
    String initialText = '';
    if (widget.currentDeviationText != null && widget.currentDeviationText!.isNotEmpty) {
      initialText = widget.currentDeviationText!;
    } else if (widget.currentDeviation != null) {
      initialText = MeasurementParser.formatDeviation(widget.currentDeviation!);
    }
    _controller = TextEditingController(text: initialText);
    _controller.addListener(_onTextChanged);
    _recalculate();

    // Auto-focus after render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _recalculate();
    });
  }

  void _recalculate() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _parsedDeviation = null;
      _formattedDisplay = '';
      _parsedActualReading = null;
      return;
    }

    if (_entryMode == 0) {
      // Direct deviation mode
      final parsed = MeasurementParser.parse(text);
      if (parsed != null) {
        _parsedDeviation = parsed;
        _formattedDisplay = MeasurementParser.formatDeviation(parsed);
      } else {
        _parsedDeviation = null;
        _formattedDisplay = '';
      }
    } else {
      // Measured tape reading mode: Deviation = Measured - Spec
      final actual = MeasurementParser.parse(text);
      _parsedActualReading = actual;
      final specParsed = MeasurementParser.parse(widget.specValue);
      if (actual != null && specParsed != null) {
        final diff = actual - specParsed;
        _parsedDeviation = diff;
        _formattedDisplay = MeasurementParser.formatDeviation(diff);
      } else {
        _parsedDeviation = null;
        _formattedDisplay = '';
      }
    }
  }

  bool _isWithinTolerance(double val) {
    if (widget.pomTolerance != null) {
      return widget.pomTolerance!.isWithin(val);
    }
    return val.abs() <= (widget.tolerance + 0.0001);
  }

  void _setPreset(String val) {
    _controller.text = val;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: val.length));
  }

  void _toggleSign() {
    String t = _controller.text.trim();
    if (t.startsWith('-')) {
      t = '+${t.substring(1).trim()}';
    } else if (t.startsWith('+')) {
      t = '-${t.substring(1).trim()}';
    } else if (t.isNotEmpty) {
      t = '-$t';
    }
    _controller.text = t;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: t.length));
  }

  void _appendFraction(String frac) {
    String t = _controller.text.trim();
    if (t.isEmpty) {
      t = frac;
    } else if (RegExp(r'[\+\-]?\d+$').hasMatch(t)) {
      t = '$t $frac';
    } else {
      t = '$t $frac';
    }
    _controller.text = t;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: t.length));
  }

  void _handleSave({bool advance = false}) {
    if (_parsedDeviation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid measurement figure (e.g. +2, -1 1/4, 0.5)'),
          backgroundColor: AppColors.outTolRed,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final dev = _parsedDeviation!;
    final display = _formattedDisplay.isNotEmpty
        ? _formattedDisplay
        : MeasurementParser.formatDeviation(dev);

    Navigator.pop(context);

    if (advance && widget.onSaveAndNext != null) {
      widget.onSaveAndNext!(dev, display);
    } else {
      widget.onSave(dev, display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final tolString = widget.pomTolerance != null
        ? widget.pomTolerance!.displayString
        : '±${widget.tolerance}"';

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? bottomInset + 12 : 20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle
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

              // Title and Cell Details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.keyboard_alt_rounded, size: 22, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.pomCode,
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
                                widget.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Size: ${widget.size}  •  Spec: ${widget.specValue}"  •  Sample #${widget.sampleIndex}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slateNavy.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close_rounded, size: 20, color: AppColors.slateNavy),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Entry Mode Segmented Switch: Direct Deviation vs Actual Measured Value
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (_entryMode != 0) {
                            setState(() {
                              _entryMode = 0;
                              _recalculate();
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _entryMode == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _entryMode == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Enter Deviation (±)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _entryMode == 0 ? AppColors.primaryBlue : AppColors.slateNavy,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (_entryMode != 1) {
                            setState(() {
                              _entryMode = 1;
                              _recalculate();
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _entryMode == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _entryMode == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Enter Tape Reading',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _entryMode == 1 ? AppColors.primaryBlue : AppColors.slateNavy,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Main Input TextField with System Keyboard Support
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleSave(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepNavy,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        hintText: _entryMode == 0 ? 'e.g. +2, -1 1/2, 2.5' : 'e.g. 34 1/4, 32.5',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey.shade400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                        ),
                        prefixIcon: _entryMode == 0
                            ? InkWell(
                                onTap: _toggleSign,
                                child: Container(
                                  margin: const EdgeInsets.all(6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '±',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                              )
                            : const Icon(Icons.straighten_rounded, color: AppColors.primaryBlue, size: 20),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20, color: AppColors.slateNavy),
                                onPressed: () => _controller.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick Sign Toggles
                  if (_entryMode == 0) ...[
                    InkWell(
                      onTap: () {
                        String t = _controller.text.trim();
                        if (t.startsWith('-')) t = t.substring(1).trim();
                        if (!t.startsWith('+') && t.isNotEmpty) t = '+$t';
                        _controller.text = t;
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.inTolGreen.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '+',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.inTolGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        String t = _controller.text.trim();
                        if (t.startsWith('+')) t = t.substring(1).trim();
                        if (!t.startsWith('-') && t.isNotEmpty) t = '-$t';
                        _controller.text = t;
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.outTolRed.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '–',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.outTolRed),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Quick Preset Chips (Large deviations including +2, +1 1/2, +1, etc.)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_entryMode == 0) ...[
                      _buildChip('+2"', () => _setPreset('+2')),
                      _buildChip('+1 3/4"', () => _setPreset('+1 3/4')),
                      _buildChip('+1 1/2"', () => _setPreset('+1 1/2')),
                      _buildChip('+1 1/4"', () => _setPreset('+1 1/4')),
                      _buildChip('+1"', () => _setPreset('+1')),
                      _buildChip('0 (Spec)', () => _setPreset('0')),
                      _buildChip('-1"', () => _setPreset('-1')),
                      _buildChip('-1 1/4"', () => _setPreset('-1 1/4')),
                      _buildChip('-1 1/2"', () => _setPreset('-1 1/2')),
                      _buildChip('-1 3/4"', () => _setPreset('-1 3/4')),
                      _buildChip('-2"', () => _setPreset('-2')),
                    ] else ...[
                      // Quick spec-relative tape reading chips
                      _buildChip('${widget.specValue}" (Spec)', () => _setPreset(widget.specValue)),
                      _buildChip('1/8', () => _appendFraction('1/8')),
                      _buildChip('1/4', () => _appendFraction('1/4')),
                      _buildChip('3/8', () => _appendFraction('3/8')),
                      _buildChip('1/2', () => _appendFraction('1/2')),
                      _buildChip('5/8', () => _appendFraction('5/8')),
                      _buildChip('3/4', () => _appendFraction('3/4')),
                      _buildChip('7/8', () => _appendFraction('7/8')),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Live Status / Tolerance Feedback Box
              if (_parsedDeviation != null) ...[
                Builder(
                  builder: (context) {
                    final dev = _parsedDeviation!;
                    final isWithin = _isWithinTolerance(dev);
                    final isZero = dev == 0.0;

                    Color boxBg = isWithin ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
                    Color boxBorder = isWithin ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);
                    Color titleColor = isWithin ? const Color(0xFF166534) : const Color(0xFFB91C1C);
                    IconData icon = isWithin ? Icons.check_circle_rounded : Icons.warning_amber_rounded;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: boxBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: boxBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 18, color: titleColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Deviation: $_formattedDisplay"  •  ${isZero ? 'Exact Spec Match' : (isWithin ? 'In Tolerance' : 'OUT OF TOLERANCE')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: titleColor,
                                  ),
                                ),
                                if (_entryMode == 1 && _parsedActualReading != null)
                                  Text(
                                    'Measured ${_parsedActualReading!}" vs Spec ${widget.specValue}" = Diff: $_formattedDisplay"',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: titleColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Action Buttons: Clear, Cancel, Save & Next, Save
              Row(
                children: [
                  if (widget.currentDeviation != null && widget.onClear != null) ...[
                    IconButton.outlined(
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.outTolRed,
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      tooltip: 'Clear Reading',
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onClear!();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: AppColors.borderLight),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.slateNavy),
                      ),
                    ),
                  ),
                  if (widget.onSaveAndNext != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _parsedDeviation != null
                            ? () => _handleSave(advance: true)
                            : null,
                        icon: Icon(
                          widget.advanceTopToBottom
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_forward_rounded,
                          size: 16,
                        ),
                        label: Text(
                          widget.advanceTopToBottom ? 'Save & ⬇️' : 'Save & ➡️',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _parsedDeviation != null ? () => _handleSave() : null,
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.cardFill,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.deepNavy,
            ),
          ),
        ),
      ),
    );
  }
}
