import 'package:flutter/material.dart';
import '../models/measurement_point.dart';
import '../models/spec_sheet_model.dart';
import '../models/tolerance_standard.dart';
import '../services/excel_export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_histogram.dart';
import '../widgets/quick_deviation_sheet.dart';
import '../widgets/custom_measurement_dialog.dart';
import 'scan_web_qr_screen.dart';

class DigitalInspectionSheetScreen extends StatefulWidget {
  final GarmentSpecSheet initialSpecSheet;

  const DigitalInspectionSheetScreen({
    super.key,
    required this.initialSpecSheet,
  });

  @override
  State<DigitalInspectionSheetScreen> createState() =>
      _DigitalInspectionSheetScreenState();
}

class _DigitalInspectionSheetScreenState
    extends State<DigitalInspectionSheetScreen> {
  late GarmentSpecSheet _specSheet;
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScrollLeft = ScrollController();
  final ScrollController _verticalScrollRight = ScrollController();
  bool _syncingScroll = false;
  String? _focusedSize;

  // Frozen / Docked Keypad state (Page 3 feature request)
  bool _dockKeypad = true;
  bool _advanceTopToBottom = true; // Flow: Top-to-Bottom (garment inspection) vs Left-to-Right
  String? _activePomCode;
  String? _activeSize;
  int? _activeSampleIndex;

  @override
  void initState() {
    super.initState();
    _specSheet = widget.initialSpecSheet;
    if (_specSheet.sizes.isNotEmpty) {
      _focusedSize = _specSheet.sizes.first;
      if (_specSheet.poms.isNotEmpty) {
        _activePomCode = _specSheet.poms.first.pomCode;
        _activeSize = _specSheet.sizes.first;
        _activeSampleIndex = 1;
      }
    }

    _verticalScrollLeft.addListener(() {
      if (_syncingScroll) return;
      _syncingScroll = true;
      if (_verticalScrollRight.hasClients &&
          _verticalScrollRight.offset != _verticalScrollLeft.offset) {
        _verticalScrollRight.jumpTo(_verticalScrollLeft.offset);
      }
      _syncingScroll = false;
    });

    _verticalScrollRight.addListener(() {
      if (_syncingScroll) return;
      _syncingScroll = true;
      if (_verticalScrollLeft.hasClients &&
          _verticalScrollLeft.offset != _verticalScrollRight.offset) {
        _verticalScrollLeft.jumpTo(_verticalScrollRight.offset);
      }
      _syncingScroll = false;
    });
  }

  void _jumpToSize(String size) {
    setState(() {
      _focusedSize = size;
      if (_dockKeypad && _activePomCode != null) {
        _activeSize = size;
      }
    });
    final index = _specSheet.sizes.indexOf(size);
    if (index >= 0) {
      const double specColWidth = 60.0;
      const double sampleColWidth = 44.0;
      const double sizeBlockDividerWidth = 1.5;
      final double sizeBlockWidth =
          specColWidth + (_specSheet.sampleCountPerSize * sampleColWidth) + sizeBlockDividerWidth;
      _horizontalScroll.animateTo(
        index * sizeBlockWidth,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScrollLeft.dispose();
    _verticalScrollRight.dispose();
    super.dispose();
  }

  void _onCellTapped(String pomCode, String size, int sampleIndex) {
    if (_dockKeypad) {
      setState(() {
        _activePomCode = pomCode;
        _activeSize = size;
        _activeSampleIndex = sampleIndex;
        _focusedSize = size;
      });
    } else {
      final pomRow = _specSheet.poms.firstWhere((p) => p.pomCode == pomCode);
      final specVal = pomRow.sizeSpecs[size] ?? '-';
      final currentReading = _specSheet.getReading(pomCode, size, sampleIndex);
      _openModalKeypad(
        pomCode: pomCode,
        description: pomRow.description,
        size: size,
        specValue: specVal,
        sampleIndex: sampleIndex,
        currentDeviation: currentReading?.deviation,
      );
    }
  }

  void _recordSample(
    String pomCode,
    String size,
    int sampleIndex,
    double deviation,
    String text,
  ) {
    // Clean any accidental double plus signs (Page 3 bug)
    String cleanText = text.trim();
    while (cleanText.startsWith('++')) {
      cleanText = cleanText.substring(1);
    }

    setState(() {
      final key = GarmentSpecSheet.cellKey(pomCode, size, sampleIndex);
      final updatedReadings = Map<String, SampleReading>.from(_specSheet.readings);
      updatedReadings[key] = SampleReading(
        pomCode: pomCode,
        size: size,
        sampleIndex: sampleIndex,
        deviation: deviation,
        deviationText: cleanText,
        recordedAt: DateTime.now(),
      );
      _specSheet = _specSheet.copyWith(readings: updatedReadings);

      // If docked keypad: auto-advance sample seamlessly without moving/reloading keypad
      if (_dockKeypad) {
        if (_advanceTopToBottom) {
          // Flow: Top to Bottom (Up to Down across POM rows for the same garment/sample)
          final currentPomIdx = _specSheet.poms.indexWhere((p) => p.pomCode == pomCode);
          if (currentPomIdx >= 0 && currentPomIdx < _specSheet.poms.length - 1) {
            _activePomCode = _specSheet.poms[currentPomIdx + 1].pomCode;
          } else {
            // Reached bottom of current sample -> wrap to first POM of next sample
            if (sampleIndex < _specSheet.sampleCountPerSize) {
              _activePomCode = _specSheet.poms.isNotEmpty ? _specSheet.poms.first.pomCode : null;
              _activeSampleIndex = sampleIndex + 1;
            } else {
              // Wrap to next size if available
              final currentSizeIdx = _specSheet.sizes.indexOf(size);
              if (currentSizeIdx >= 0 && currentSizeIdx < _specSheet.sizes.length - 1) {
                final nextSz = _specSheet.sizes[currentSizeIdx + 1];
                _activeSize = nextSz;
                _focusedSize = nextSz;
                _activePomCode = _specSheet.poms.isNotEmpty ? _specSheet.poms.first.pomCode : null;
                _activeSampleIndex = 1;
                _jumpToSize(nextSz);
              }
            }
          }
        } else {
          // Flow: Left to Right across samples of the same POM
          if (sampleIndex < _specSheet.sampleCountPerSize) {
            _activeSampleIndex = sampleIndex + 1;
          } else {
            final currentPomIdx = _specSheet.poms.indexWhere((p) => p.pomCode == pomCode);
            if (currentPomIdx >= 0 && currentPomIdx < _specSheet.poms.length - 1) {
              _activePomCode = _specSheet.poms[currentPomIdx + 1].pomCode;
              _activeSampleIndex = 1;
            }
          }
        }
      }
    });

    // Auto advance in modal mode
    if (!_dockKeypad) {
      String nextPom = pomCode;
      int nextSample = sampleIndex;
      String nextSize = size;

      if (_advanceTopToBottom) {
        final currentPomIdx = _specSheet.poms.indexWhere((p) => p.pomCode == pomCode);
        if (currentPomIdx >= 0 && currentPomIdx < _specSheet.poms.length - 1) {
          nextPom = _specSheet.poms[currentPomIdx + 1].pomCode;
        } else if (sampleIndex < _specSheet.sampleCountPerSize) {
          nextPom = _specSheet.poms.isNotEmpty ? _specSheet.poms.first.pomCode : pomCode;
          nextSample = sampleIndex + 1;
        } else {
          final currentSizeIdx = _specSheet.sizes.indexOf(size);
          if (currentSizeIdx >= 0 && currentSizeIdx < _specSheet.sizes.length - 1) {
            nextSize = _specSheet.sizes[currentSizeIdx + 1];
            nextPom = _specSheet.poms.isNotEmpty ? _specSheet.poms.first.pomCode : pomCode;
            nextSample = 1;
          }
        }
      } else {
        if (sampleIndex < _specSheet.sampleCountPerSize) {
          nextSample = sampleIndex + 1;
        }
      }

      if (nextPom != pomCode || nextSample != sampleIndex || nextSize != size) {
        final pomRow = _specSheet.poms.firstWhere((p) => p.pomCode == nextPom);
        final specVal = pomRow.sizeSpecs[nextSize] ?? '-';
        final currentReading = _specSheet.getReading(nextPom, nextSize, nextSample);

        Future.delayed(const Duration(milliseconds: 180), () {
          if (!mounted) return;
          _openModalKeypad(
            pomCode: nextPom,
            description: pomRow.description,
            size: nextSize,
            specValue: specVal,
            sampleIndex: nextSample,
            currentDeviation: currentReading?.deviation,
          );
        });
      }
    }
  }

  void _clearSample(String pomCode, String size, int sampleIndex) {
    setState(() {
      final key = GarmentSpecSheet.cellKey(pomCode, size, sampleIndex);
      final updatedReadings = Map<String, SampleReading>.from(_specSheet.readings);
      updatedReadings.remove(key);
      _specSheet = _specSheet.copyWith(readings: updatedReadings);
    });
  }

  void _openModalKeypad({
    required String pomCode,
    required String description,
    required String size,
    required String specValue,
    required int sampleIndex,
    double? currentDeviation,
  }) {
    final reading = _specSheet.getReading(pomCode, size, sampleIndex);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickDeviationSheet(
        pomCode: pomCode,
        description: description,
        size: size,
        specValue: specValue,
        sampleIndex: sampleIndex,
        tolerance: _specSheet.tolerance,
        pomTolerance: _specSheet.getPomTolerance(pomCode, size: size),
        currentDeviation: currentDeviation,
        currentDeviationText: reading?.deviationText,
        advanceTopToBottom: _advanceTopToBottom,
        onToggleAdvanceDirection: () => setState(() => _advanceTopToBottom = !_advanceTopToBottom),
        onOpenKeyboard: () {
          Navigator.pop(ctx);
          _openCustomKeyboardDialog(pomCode, size, sampleIndex);
        },
        onSelect: (dev, txt) =>
            _recordSample(pomCode, size, sampleIndex, dev, txt),
        onClear: () => _clearSample(pomCode, size, sampleIndex),
      ),
    );
  }

  void _openCustomKeyboardDialog(String pomCode, String size, int sampleIndex) {
    final pomRow = _specSheet.poms.firstWhere((p) => p.pomCode == pomCode);
    final specVal = pomRow.sizeSpecs[size] ?? '-';
    final currentReading = _specSheet.getReading(pomCode, size, sampleIndex);

    if (_dockKeypad) {
      setState(() {
        _activePomCode = pomCode;
        _activeSize = size;
        _activeSampleIndex = sampleIndex;
        _focusedSize = size;
      });
    }

    CustomMeasurementDialog.show(
      context,
      pomCode: pomCode,
      description: pomRow.description,
      size: size,
      specValue: specVal,
      sampleIndex: sampleIndex,
      currentDeviation: currentReading?.deviation,
      currentDeviationText: currentReading?.deviationText,
      tolerance: _specSheet.tolerance,
      pomTolerance: _specSheet.getPomTolerance(pomCode, size: size),
      advanceTopToBottom: _advanceTopToBottom,
      onSave: (dev, txt) => _recordSample(pomCode, size, sampleIndex, dev, txt),
      onSaveAndNext: (dev, txt) {
        _recordSample(pomCode, size, sampleIndex, dev, txt);
        _advanceToNextCellForKeyboard(pomCode, size, sampleIndex);
      },
      onClear: () => _clearSample(pomCode, size, sampleIndex),
    );
  }

  void _advanceToNextCellForKeyboard(String pomCode, String size, int sampleIndex) {
    String nextPom = pomCode;
    int nextSample = sampleIndex;
    String nextSize = size;

    if (_advanceTopToBottom) {
      final currentPomIdx = _specSheet.poms.indexWhere((p) => p.pomCode == pomCode);
      if (currentPomIdx >= 0 && currentPomIdx < _specSheet.poms.length - 1) {
        nextPom = _specSheet.poms[currentPomIdx + 1].pomCode;
      } else if (sampleIndex < _specSheet.sampleCountPerSize) {
        nextPom = _specSheet.poms.isNotEmpty ? _specSheet.poms.first.pomCode : pomCode;
        nextSample = sampleIndex + 1;
      } else {
        final currentSizeIdx = _specSheet.sizes.indexOf(size);
        if (currentSizeIdx >= 0 && currentSizeIdx < _specSheet.sizes.length - 1) {
          nextSize = _specSheet.sizes[currentSizeIdx + 1];
          nextPom = _specSheet.poms.isNotEmpty ? _specSheet.poms.first.pomCode : pomCode;
          nextSample = 1;
        }
      }
    } else {
      if (sampleIndex < _specSheet.sampleCountPerSize) {
        nextSample = sampleIndex + 1;
      } else {
        final currentPomIdx = _specSheet.poms.indexWhere((p) => p.pomCode == pomCode);
        if (currentPomIdx >= 0 && currentPomIdx < _specSheet.poms.length - 1) {
          nextPom = _specSheet.poms[currentPomIdx + 1].pomCode;
          nextSample = 1;
        }
      }
    }

    if (nextPom != pomCode || nextSample != sampleIndex || nextSize != size) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        _openCustomKeyboardDialog(nextPom, nextSize, nextSample);
      });
    }
  }

  /// Interactive Inspection Summary with Embedded Real-time Histogram (Page 2 request: POM-specific histogram)
  void _showStatsSummary() {
    String selectedPomFilter = _activePomCode ?? (_specSheet.poms.isNotEmpty ? _specSheet.poms.first.pomCode : 'ALL');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final readings = _specSheet.readings.values.toList();
          final filteredReadings = selectedPomFilter == 'ALL'
              ? readings
              : readings.where((r) => r.pomCode == selectedPomFilter).toList();

          final total = filteredReadings.length;
          final outOfTol = filteredReadings
              .where((r) => !_specSheet.isWithinTolerance(r.deviation, pomCode: r.pomCode, size: r.size))
              .length;
          final inTol = total - outOfTol;
          final passRatePercent = (total == 0) ? 100 : ((inTol / total) * 100).round();

          final deviationsList = filteredReadings.map((r) => r.deviation).toList();

          final SpecPomRow? activePomRow = selectedPomFilter == 'ALL'
              ? null
              : _specSheet.poms.cast<SpecPomRow?>().firstWhere((p) => p?.pomCode == selectedPomFilter, orElse: () => null);

          final PomTolerance activePomTol = activePomRow != null
              ? _specSheet.getPomTolerance(activePomRow.pomCode)
              : PomTolerance(posTol: _specSheet.tolerance, negTol: _specSheet.tolerance);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            title: Row(
              children: [
                const Icon(Icons.analytics_rounded, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_specSheet.style} • Inspection Analytics',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Brand: ${_specSheet.brand}  •  Stage: ${_specSheet.stage}  •  Category: ${_specSheet.toleranceCategory.label}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slateNavy.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 12),

                    // Top KPI Badges (Strictly reflecting the selected POM or Overall)
                    Row(
                      children: [
                        Expanded(child: _statBadge('Pass Rate', '$passRatePercent%', passRatePercent >= 90 ? AppColors.inTolGreen : AppColors.outTolRed)),
                        const SizedBox(width: 6),
                        Expanded(child: _statBadge('Measured', '$total pcs', AppColors.primaryBlue)),
                        const SizedBox(width: 6),
                        Expanded(child: _statBadge('Out of Tol', '$outOfTol', outOfTol > 0 ? AppColors.outTolRed : AppColors.inTolGreen)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Specific POM Header Card
                    if (activePomRow != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                activePomRow.pomCode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                activePomRow.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Text(
                                'Tol: ${activePomTol.displayString}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // POM Filter selector
                    Row(
                      children: [
                        const Text(
                          'Select POM: ',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slateNavy),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('ALL POINTS'),
                                  selected: selectedPomFilter == 'ALL',
                                  selectedColor: AppColors.selectedBlueLight,
                                  labelStyle: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: selectedPomFilter == 'ALL' ? AppColors.primaryBlue : AppColors.deepNavy,
                                  ),
                                  onSelected: (_) => setDlgState(() => selectedPomFilter = 'ALL'),
                                ),
                                const SizedBox(width: 6),
                                ..._specSheet.poms.map((p) {
                                  final isSel = selectedPomFilter == p.pomCode;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text('${p.pomCode} - ${p.description}'),
                                      selected: isSel,
                                      selectedColor: AppColors.selectedBlueLight,
                                      labelStyle: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isSel ? AppColors.primaryBlue : AppColors.deepNavy,
                                      ),
                                      onSelected: (_) => setDlgState(() => selectedPomFilter = p.pomCode),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live Interactive Histogram (POM Specific)
                    Text(
                      activePomRow != null
                          ? 'Histogram: ${activePomRow.pomCode} (${activePomRow.description})'
                          : 'Measurement Deviation Histogram (Total Sample):',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.deepNavy),
                    ),
                    const SizedBox(height: 8),
                    InteractiveHistogram(
                      tolerance: activePomTol.posTol,
                      deviations: deviationsList,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.file_download_rounded, size: 18, color: AppColors.primaryBlue),
                label: const Text('Export to Excel', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showExcelExportDialog();
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Selective Excel Export with Size Selection Modal (Page 3 request)
  void _showExcelExportDialog() {
    final selectedSizes = Set<String>.from(_specSheet.sizes);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.file_download_rounded, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Export to Excel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select sizes to export (${selectedSizes.length} of ${_specSheet.sizes.length} selected):',
                    style: const TextStyle(fontSize: 13, color: AppColors.slateNavy, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setDlgState(() => selectedSizes.addAll(_specSheet.sizes)),
                        child: const Text('Select All', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: () => setDlgState(() => selectedSizes.clear()),
                        child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _specSheet.sizes.map((sz) {
                          final isChecked = selectedSizes.contains(sz);
                          return FilterChip(
                            label: Text(sz, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            selected: isChecked,
                            selectedColor: AppColors.selectedBlueLight,
                            checkmarkColor: AppColors.primaryBlue,
                            onSelected: (val) {
                              setDlgState(() {
                                if (val) {
                                  selectedSizes.add(sz);
                                } else {
                                  selectedSizes.remove(sz);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.file_download_rounded, size: 18),
                label: Text(
                  selectedSizes.length == _specSheet.sizes.length
                      ? 'Export Full Spec'
                      : 'Export Selected (${selectedSizes.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: selectedSizes.isEmpty
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        ExcelExportService.exportAndShare(
                          context,
                          _specSheet,
                          selectedSizes: selectedSizes.toList(),
                        );
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Manual Add POM Row during inspection (Page 1 request: individual size specs & tolerances)
  void _addNewPomRow() {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final defaultSpecCtrl = TextEditingController();

    // Per-size spec controllers
    final Map<String, TextEditingController> sizeSpecCtrls = {
      for (final sz in _specSheet.sizes) sz: TextEditingController(),
    };

    // Per-size tolerance overrides (null means inherits POM tolerance)
    final Map<String, double?> sizeTolOverrides = {
      for (final sz in _specSheet.sizes) sz: null,
    };

    double baseTol = _specSheet.tolerance;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add Measurement Point',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // POM Code & Description
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'POM Code *',
                              hintText: 'e.g. LOOP',
                              isDense: true,
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: descCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Description *',
                              hintText: 'e.g. NUMBER OF LOOPS',
                              isDense: true,
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Base Tolerance Selector
                    const Text(
                      'Standard POM Tolerance:',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.slateNavy),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [0.125, 0.25, 0.375, 0.5, 0.75, 1.0].map((tol) {
                        final isSel = (baseTol - tol).abs() < 0.001;
                        return ChoiceChip(
                          label: Text('±${formatDeviation(tol)}"'),
                          selected: isSel,
                          selectedColor: AppColors.selectedBlueLight,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSel ? AppColors.primaryBlue : AppColors.deepNavy,
                          ),
                          onSelected: (_) => setDlgState(() => baseTol = tol),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Quick Nominal Spec Autofill
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cardFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Nominal Spec (Fill All Sizes):',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.slateNavy),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: defaultSpecCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 5 or 32',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: () {
                                  final val = defaultSpecCtrl.text.trim();
                                  if (val.isNotEmpty) {
                                    setDlgState(() {
                                      for (final ctrl in sizeSpecCtrls.values) {
                                        ctrl.text = val;
                                      }
                                    });
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: const Text('Apply to All Sizes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Individual Size Specs & Tolerance Matrix (Page 1 request)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Individual Size Specs & Tolerances:',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.deepNavy),
                        ),
                        Text(
                          '${_specSheet.sizes.length} sizes',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slateNavy.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _specSheet.sizes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                        itemBuilder: (ctx, idx) {
                          final sz = _specSheet.sizes[idx];
                          final ctrl = sizeSpecCtrls[sz]!;
                          final customTol = sizeTolOverrides[sz];
                          final effectiveTol = customTol ?? baseTol;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                // Size Badge
                                Container(
                                  width: 60,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    sz,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Nominal Spec input
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: ctrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Nominal Spec',
                                      hintText: 'e.g. 32',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Per-size tolerance button/dropdown
                                PopupMenuButton<double?>(
                                  tooltip: 'Tolerance for size $sz',
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (val) => setDlgState(() => sizeTolOverrides[sz] = val),
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem<double?>(
                                      value: null,
                                      child: Text(
                                        'Default (±${formatDeviation(baseTol)}")',
                                        style: TextStyle(
                                          fontWeight: customTol == null ? FontWeight.w800 : FontWeight.normal,
                                          fontSize: 12,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                    ),
                                    const PopupMenuDivider(height: 1),
                                    ...[0.125, 0.25, 0.375, 0.5, 0.75, 1.0].map((t) => PopupMenuItem<double?>(
                                      value: t,
                                      child: Text(
                                        '±${formatDeviation(t)}"',
                                        style: TextStyle(
                                          fontWeight: customTol == t ? FontWeight.w800 : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: customTol != null ? AppColors.inTolLight : AppColors.cardFill,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: customTol != null ? AppColors.inTolGreen : AppColors.borderLight,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '±${formatDeviation(effectiveTol)}"',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: customTol != null ? AppColors.inTolGreen : AppColors.slateNavy,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.slateNavy),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final code = codeCtrl.text.trim().toUpperCase();
                final desc = descCtrl.text.trim();
                if (code.isEmpty || desc.isEmpty) return;

                final defaultSpec = defaultSpecCtrl.text.trim().isNotEmpty ? defaultSpecCtrl.text.trim() : '-';
                final Map<String, String> sizeSpecs = {};
                for (final sz in _specSheet.sizes) {
                  final spec = sizeSpecCtrls[sz]?.text.trim();
                  sizeSpecs[sz] = (spec != null && spec.isNotEmpty) ? spec : defaultSpec;
                }

                final newPom = SpecPomRow(
                  no: _specSheet.poms.length + 1,
                  pomCode: code,
                  description: desc,
                  sizeSpecs: sizeSpecs,
                );

                // Save base POM tolerance and any per-size custom tolerances
                final updatedCustomTol = Map<String, PomTolerance>.from(_specSheet.customPomTolerances);
                updatedCustomTol[code] = PomTolerance(posTol: baseTol, negTol: baseTol);

                for (final entry in sizeTolOverrides.entries) {
                  if (entry.value != null) {
                    updatedCustomTol['${code}_${entry.key}'] = PomTolerance(posTol: entry.value!, negTol: entry.value!);
                  }
                }

                final updatedPoms = List<SpecPomRow>.from(_specSheet.poms)..add(newPom);
                setState(() {
                  _specSheet = _specSheet.copyWith(
                    poms: updatedPoms,
                    customPomTolerances: updatedCustomTol,
                  );
                  _activePomCode = code;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add Point', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  /// Manually adjust tolerance for a specific POM (Page 1 request)
  void _editPomTolerance(SpecPomRow pom) {
    final activeTol = _specSheet.getPomTolerance(pom.pomCode);
    double pos = activeTol.posTol;
    double neg = activeTol.negTol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isSymmetric = (pos - neg).abs() < 0.001;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tolerance: ${pom.pomCode}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pom.description, style: const TextStyle(fontSize: 12, color: AppColors.slateNavy)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.selectedBlueLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Setting:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(
                        isSymmetric ? '±${formatDeviation(pos)}"' : '+${formatDeviation(pos)}" / -${formatDeviation(neg)}"',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Positive (+) Limit:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [0.25, 0.375, 0.5, 0.75, 1.0, 1.25].map((val) {
                    final sel = (pos - val).abs() < 0.001;
                    return ChoiceChip(
                      label: Text('+${formatDeviation(val)}"'),
                      selected: sel,
                      selectedColor: AppColors.selectedBlueLight,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: sel ? AppColors.primaryBlue : AppColors.deepNavy,
                      ),
                      onSelected: (_) => setDlgState(() => pos = val),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                const Text('Negative (-) Limit:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [0.25, 0.375, 0.5, 0.75, 1.0, 1.25].map((val) {
                    final sel = (neg - val).abs() < 0.001;
                    return ChoiceChip(
                      label: Text('-${formatDeviation(val)}"'),
                      selected: sel,
                      selectedColor: Colors.deepOrange.shade50,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: sel ? Colors.deepOrange : AppColors.deepNavy,
                      ),
                      onSelected: (_) => setDlgState(() => neg = val),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              if (_specSheet.customPomTolerances.containsKey(pom.pomCode))
                TextButton(
                  onPressed: () {
                    final updatedCustom = Map<String, PomTolerance>.from(_specSheet.customPomTolerances)..remove(pom.pomCode);
                    setState(() => _specSheet = _specSheet.copyWith(customPomTolerances: updatedCustom));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Reset to Standard', style: TextStyle(color: AppColors.outTolRed)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final updatedCustom = Map<String, PomTolerance>.from(_specSheet.customPomTolerances);
                  updatedCustom[pom.pomCode] = PomTolerance(posTol: pos, negTol: neg);
                  setState(() => _specSheet = _specSheet.copyWith(customPomTolerances: updatedCustom));
                  Navigator.pop(ctx);
                },
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.slateNavy)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalReadings = _specSheet.recordedCount;
    final outOfTol = _specSheet.outOfToleranceCount;

    // Active POM details for docked keypad
    final activePomRow = _activePomCode != null
        ? _specSheet.poms.cast<SpecPomRow?>().firstWhere(
            (p) => p?.pomCode == _activePomCode,
            orElse: () => null,
          )
        : null;
    final activeSpecVal = (activePomRow != null && _activeSize != null)
        ? (activePomRow.sizeSpecs[_activeSize!] ?? '-')
        : '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    'STYLE: ${_specSheet.style}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ),
                if (_specSheet.po.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'PO: ${_specSheet.po}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slateNavy.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              '${_specSheet.brand} • ${_specSheet.stage} • ${_specSheet.toleranceCategory.shortLabel}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.slateNavy.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          // Quick QA Defect / Analytics status button with badge
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.analytics_rounded, color: AppColors.primaryBlue),
                if (outOfTol > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.outTolRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$outOfTol',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Inspection Stats & Histogram',
            onPressed: _showStatsSummary,
          ),
          // 3-dot Overflow Menu with all tool options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.deepNavy),
            tooltip: 'Options',
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            onSelected: (value) {
              switch (value) {
                case 'add_pom':
                  _addNewPomRow();
                  break;
                case 'toggle_dock':
                  setState(() => _dockKeypad = !_dockKeypad);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _dockKeypad
                            ? 'Tolerance chart frozen at bottom'
                            : 'Keypad in popup modal mode',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                  break;
                case 'export_excel':
                  _showExcelExportDialog();
                  break;
                case 'link_web':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ScanWebQrScreen()),
                  );
                  break;
                case 'stats':
                  _showStatsSummary();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'add_pom',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.playlist_add_rounded, color: AppColors.primaryBlue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Measurement Point',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.deepNavy),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_dock',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (_dockKeypad ? AppColors.inTolGreen : AppColors.slateNavy).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _dockKeypad ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        color: _dockKeypad ? AppColors.inTolGreen : AppColors.slateNavy,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dockKeypad ? 'Docked Keypad' : 'Pop-up Keypad',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.deepNavy),
                          ),
                          Text(
                            _dockKeypad ? 'Keypad is frozen at bottom' : 'Keypad appears as popup',
                            style: TextStyle(fontSize: 10, color: AppColors.slateNavy.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_excel',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.inTolGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.file_download_rounded, color: AppColors.inTolGreen, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Export to Excel (.xlsx)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.deepNavy),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'link_web',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryBlue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Link Web Device (Scan QR)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.deepNavy),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: AppColors.primaryDark, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Inspection Summary',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.deepNavy),
                      ),
                    ),
                    if (outOfTol > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.outTolRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$outOfTol out',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Banner row: Form guide, Dock indicator, and Size jump chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app_rounded, size: 14, color: AppColors.primaryBlue),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _dockKeypad
                                    ? 'Tap cell to inspect • Tap again or ⌨️ to edit'
                                    : 'Tap any cell to enter deviation',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() => _advanceTopToBottom = !_advanceTopToBottom);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _advanceTopToBottom
                                  ? 'Flow: ⬇️ Top-to-Bottom across POMs (Garment mode)'
                                  : 'Flow: ➡️ Left-to-Right across samples (POM mode)',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _advanceTopToBottom ? Icons.arrow_downward_rounded : Icons.arrow_forward_rounded,
                              size: 13,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _advanceTopToBottom ? 'Flow: ⬇️ Down' : 'Flow: ➡️ Right',
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
                    if (_dockKeypad && _activePomCode != null && _activeSize != null && _activeSampleIndex != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _openCustomKeyboardDialog(_activePomCode!, _activeSize!, _activeSampleIndex!),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.keyboard_alt_rounded, size: 13, color: AppColors.primaryBlue),
                              SizedBox(width: 3),
                              Text(
                                'Edit (⌨️)',
                                style: TextStyle(
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
                    const SizedBox(width: 8),
                    Text(
                      '$totalReadings recorded',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slateNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Horizontal quick size jump chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'Jump to Size: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slateNavy,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ..._specSheet.sizes.map((sz) {
                        final isFocused = _focusedSize == sz;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _jumpToSize(sz),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isFocused ? AppColors.primaryBlue : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isFocused ? AppColors.primaryBlue : AppColors.borderLight,
                                ),
                              ),
                              child: Text(
                                sz,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isFocused ? Colors.white : AppColors.deepNavy,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Main Interactive Inspection Table
          Expanded(
            child: _buildInspectionGrid(),
          ),
        ],
      ),
      // Frozen Bottom Keypad (Pages 2 & 3: stays docked at bottom without moving randomly)
      bottomNavigationBar: (_dockKeypad && _activePomCode != null && activePomRow != null && _activeSize != null && _activeSampleIndex != null)
          ? QuickDeviationSheet(
              isDocked: true,
              onClose: () => setState(() {
                _activePomCode = null;
                _activeSize = null;
                _activeSampleIndex = null;
              }),
              pomCode: _activePomCode!,
              description: activePomRow.description,
              size: _activeSize!,
              specValue: activeSpecVal,
              sampleIndex: _activeSampleIndex!,
              tolerance: _specSheet.tolerance,
              pomTolerance: _specSheet.getPomTolerance(_activePomCode!, size: _activeSize),
              currentDeviation: _specSheet.getReading(_activePomCode!, _activeSize!, _activeSampleIndex!)?.deviation,
              currentDeviationText: _specSheet.getReading(_activePomCode!, _activeSize!, _activeSampleIndex!)?.deviationText,
              advanceTopToBottom: _advanceTopToBottom,
              onToggleAdvanceDirection: () => setState(() => _advanceTopToBottom = !_advanceTopToBottom),
              onOpenKeyboard: () => _openCustomKeyboardDialog(_activePomCode!, _activeSize!, _activeSampleIndex!),
              onSelect: (dev, txt) => _recordSample(_activePomCode!, _activeSize!, _activeSampleIndex!, dev, txt),
              onClear: () => _clearSample(_activePomCode!, _activeSize!, _activeSampleIndex!),
            )
          : null,
    );
  }

  Widget _buildInspectionGrid() {
    const double pomColWidth = 64.0;
    const double descColWidth = 140.0;
    const double specColWidth = 60.0;
    const double sampleColWidth = 44.0;
    const double rowHeight = 44.0;
    const double sizeBlockDividerWidth = 1.5;

    final sizes = _specSheet.sizes;
    final poms = _specSheet.poms;
    final samplesCount = _specSheet.sampleCountPerSize;

    // Width of one size block: spec col + (samplesCount * sampleColWidth) + sizeBlockDividerWidth
    final double sizeBlockWidth = specColWidth + (samplesCount * sampleColWidth) + sizeBlockDividerWidth;
    final double scrollableContentWidth = sizes.length * sizeBlockWidth;

    return Row(
      children: [
        // 1. Frozen Left Columns (POM + DESCRIPTION)
        Container(
          width: pomColWidth + descColWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(3, 0),
              ),
            ],
            border: const Border(
              right: BorderSide(color: AppColors.borderLight, width: 1.5),
            ),
          ),
          child: Column(
            children: [
              // Header row for POM & Description
              Container(
                height: 52,
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    const SizedBox(
                      width: pomColWidth - 6,
                      child: Text(
                        'POM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'DESCRIPTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primaryBlue),
                      tooltip: 'Add POM Row',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: _addNewPomRow,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderLight),

              // Rows for POM & Description
              Expanded(
                child: ListView.separated(
                  controller: _verticalScrollLeft,
                  physics: const ClampingScrollPhysics(),
                  itemCount: poms.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                  itemBuilder: (ctx, index) {
                    final pom = poms[index];
                    final isRowActive = _activePomCode == pom.pomCode;

                    return Container(
                      height: rowHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      color: isRowActive
                          ? AppColors.selectedBlueLight.withValues(alpha: 0.4)
                          : (index.isEven ? Colors.white : const Color(0xFFFBFDFF)),
                      child: Row(
                        children: [
                          SizedBox(
                            width: pomColWidth - 6,
                            child: Text(
                              pom.pomCode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _editPomTolerance(pom),
                              child: Text(
                                pom.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 2. Scrollable Right Area (Sizes & Multi-Sample Boxes)
        Expanded(
          child: SingleChildScrollView(
            controller: _horizontalScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: scrollableContentWidth,
              child: Column(
                children: [
                  // Top Two-Tier Header: Sizes & Sub-Columns (Spec, 1, 2, 3, 4, 5)
                  Container(
                    height: 52,
                    color: const Color(0xFFF1F5F9),
                    child: Row(
                      children: sizes.map((size) {
                        return Container(
                          width: sizeBlockWidth,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.borderLight, width: sizeBlockDividerWidth),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Top size title pill (e.g. "30/30", "30/32")
                              Container(
                                height: 26,
                                alignment: Alignment.center,
                                color: const Color(0xFFE2E8F0),
                                child: Text(
                                  size,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.deepNavy,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              // Sub-column header: Spec | 1 | 2 | 3 | 4 | 5
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: specColWidth,
                                      alignment: Alignment.center,
                                      color: const Color(0xFFF8FAFC),
                                      child: const Text(
                                        'SPEC',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.slateNavy,
                                        ),
                                      ),
                                    ),
                                    ...List.generate(samplesCount, (sIdx) {
                                      return Container(
                                        width: sampleColWidth,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            left: BorderSide(color: AppColors.borderLight),
                                          ),
                                        ),
                                        child: Text(
                                          '${sIdx + 1}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),

                  // Data Grid Body (Synced with vertical scroll)
                  Expanded(
                    child: ListView.separated(
                      controller: _verticalScrollRight,
                      physics: const ClampingScrollPhysics(),
                      itemCount: poms.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (ctx, rowIndex) {
                        final pom = poms[rowIndex];
                        final isRowActive = _activePomCode == pom.pomCode;

                        return Container(
                          height: rowHeight,
                          color: isRowActive
                              ? AppColors.selectedBlueLight.withValues(alpha: 0.15)
                              : (rowIndex.isEven ? Colors.white : const Color(0xFFFBFDFF)),
                          child: Row(
                            children: sizes.map((size) {
                              final specVal = pom.sizeSpecs[size] ?? '-';
                              return Container(
                                width: sizeBlockWidth,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: AppColors.borderLight, width: sizeBlockDividerWidth),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Spec Column
                                    Container(
                                      width: specColWidth,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      color: const Color(0xFFF8FAFC),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          specVal,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.deepNavy,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Sample Columns (1 to N)
                                    ...List.generate(samplesCount, (sampleIdx) {
                                      final sNumber = sampleIdx + 1;
                                      final reading = _specSheet.getReading(pom.pomCode, size, sNumber);
                                      return _buildSampleCell(
                                        pomCode: pom.pomCode,
                                        description: pom.description,
                                        size: size,
                                        specValue: specVal,
                                        sampleIndex: sNumber,
                                        reading: reading,
                                        width: sampleColWidth,
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSampleCell({
    required String pomCode,
    required String description,
    required String size,
    required String specValue,
    required int sampleIndex,
    required SampleReading? reading,
    required double width,
  }) {
    final hasReading = reading != null;
    final isWithin = hasReading
        ? _specSheet.isWithinTolerance(reading.deviation, pomCode: pomCode, size: size)
        : true;

    final isActive = _dockKeypad &&
        _activePomCode == pomCode &&
        _activeSize == size &&
        _activeSampleIndex == sampleIndex;

    Color cellBg = Colors.white;
    Color textColor = AppColors.deepNavy;

    if (hasReading) {
      if (reading.deviation == 0.0) {
        cellBg = const Color(0xFFDCFCE7); // Light green for exact match
        textColor = const Color(0xFF15803D);
      } else if (isWithin) {
        cellBg = const Color(0xFFF0FDF4); // Soft green for within tolerance
        textColor = const Color(0xFF166534);
      } else {
        cellBg = const Color(0xFFFEE2E2); // Light red for out of tolerance
        textColor = const Color(0xFFB91C1C);
      }
    }

    return InkWell(
      onTap: () {
        if (_dockKeypad && isActive) {
          // If cell is already active and tapped again, directly open keyboard edit dialog!
          _openCustomKeyboardDialog(pomCode, size, sampleIndex);
        } else {
          _onCellTapped(pomCode, size, sampleIndex);
        }
      },
      onDoubleTap: () => _openCustomKeyboardDialog(pomCode, size, sampleIndex),
      onLongPress: () => _openCustomKeyboardDialog(pomCode, size, sampleIndex),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: width,
            height: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cellBg,
              border: isActive
                  ? Border.all(color: AppColors.primaryBlue, width: 2.2)
                  : const Border(left: BorderSide(color: AppColors.borderLight)),
            ),
            child: hasReading
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        reading.deviationText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ),
                  )
                : Text(
                    '·',
                    style: TextStyle(
                      fontSize: 16,
                      color: isActive ? AppColors.primaryBlue : Colors.grey.shade300,
                      fontWeight: isActive ? FontWeight.w900 : FontWeight.normal,
                    ),
                  ),
          ),
          if (isActive)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(3)),
                ),
                child: const Icon(Icons.edit, size: 7, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
