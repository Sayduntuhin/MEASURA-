import 'package:flutter/material.dart';
import '../models/measurement_point.dart';
import '../models/spec_sheet_model.dart';
import '../models/tolerance_standard.dart';
import '../services/excel_export_service.dart';
import '../theme/app_theme.dart';
import 'digital_inspection_sheet_screen.dart';

class SpecReviewScreen extends StatefulWidget {
  final GarmentSpecSheet specSheet;

  const SpecReviewScreen({super.key, required this.specSheet});

  @override
  State<SpecReviewScreen> createState() => _SpecReviewScreenState();
}

class _SpecReviewScreenState extends State<SpecReviewScreen> {
  late TextEditingController _styleController;
  late TextEditingController _poController;
  late TextEditingController _brandController;
  late double _tolerance;
  late ToleranceCategory _toleranceCategory;
  late Map<String, PomTolerance> _customPomTolerances;
  late int _sampleCount;
  late List<String> _sizes;
  late List<SpecPomRow> _poms;

  @override
  void initState() {
    super.initState();
    _styleController = TextEditingController(text: widget.specSheet.style);
    _poController = TextEditingController(text: widget.specSheet.po);
    _brandController = TextEditingController(text: widget.specSheet.brand);
    _tolerance = widget.specSheet.tolerance;
    _toleranceCategory = widget.specSheet.toleranceCategory;
    _customPomTolerances = Map<String, PomTolerance>.from(widget.specSheet.customPomTolerances);
    _sampleCount = widget.specSheet.sampleCountPerSize;
    _sizes = List<String>.from(widget.specSheet.sizes);
    _poms = List<SpecPomRow>.from(widget.specSheet.poms);
  }

  @override
  void dispose() {
    _styleController.dispose();
    _poController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  GarmentSpecSheet _buildUpdatedSpecSheet() {
    return widget.specSheet.copyWith(
      style: _styleController.text.trim().isEmpty ? 'Style' : _styleController.text.trim(),
      po: _poController.text.trim(),
      brand: _brandController.text.trim(),
      tolerance: _tolerance,
      toleranceCategory: _toleranceCategory,
      customPomTolerances: _customPomTolerances,
      sampleCountPerSize: _sampleCount,
      sizes: _sizes,
      poms: _poms,
    );
  }

  void _proceedToInspection() {
    final updated = _buildUpdatedSpecSheet();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DigitalInspectionSheetScreen(initialSpecSheet: updated),
      ),
    );
  }

  void _showExcelExportDialog() {
    final selectedSizes = Set<String>.from(_sizes);

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
                    'Select which sizes to export (${selectedSizes.length} of ${_sizes.length} selected):',
                    style: const TextStyle(fontSize: 13, color: AppColors.slateNavy, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setDlgState(() => selectedSizes.addAll(_sizes)),
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
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _sizes.map((sz) {
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
                  selectedSizes.length == _sizes.length
                      ? 'Export Full Spec'
                      : 'Export Selected (${selectedSizes.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: selectedSizes.isEmpty
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        final current = _buildUpdatedSpecSheet();
                        ExcelExportService.exportAndShare(
                          context,
                          current,
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

  /// Manually add an extra measurement point row (Page 2 request)
  void _addNewPomRow() {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final specCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Expanded(
              child: Text('Add Measurement Point', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'POM Code (e.g. LOOP, B12)',
                hintText: 'e.g. LOOP',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. NUMBER OF LOOPS',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: specCtrl,
              decoration: const InputDecoration(
                labelText: 'Default Nominal Spec (optional)',
                hintText: 'e.g. 5 or 6 1/2',
              ),
            ),
          ],
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

              final defaultSpec = specCtrl.text.trim().isNotEmpty ? specCtrl.text.trim() : '-';
              final Map<String, String> sizeSpecs = {};
              for (final sz in _sizes) {
                sizeSpecs[sz] = defaultSpec;
              }

              setState(() {
                _poms.add(
                  SpecPomRow(
                    no: _poms.length + 1,
                    pomCode: code,
                    description: desc,
                    sizeSpecs: sizeSpecs,
                  ),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add Point', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// Manually adjust individual tolerance for a specific POM (Page 1 request)
  void _editPomTolerance(SpecPomRow pom) {
    final activeTol = _customPomTolerances[pom.pomCode] ??
        KontoorToleranceEngine.getStandardTolerance(
          category: _toleranceCategory,
          pomCode: pom.pomCode,
          description: pom.description,
          is38OrAbove: false,
          defaultTolerance: _tolerance,
        );

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
                    'Tolerance: ${pom.pomCode} (${pom.description})',
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.selectedBlueLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Tolerance:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(
                        isSymmetric ? '±${formatDeviation(pos)}"' : '+${formatDeviation(pos)}" / -${formatDeviation(neg)}"',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 12),
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
              if (_customPomTolerances.containsKey(pom.pomCode))
                TextButton(
                  onPressed: () {
                    setState(() => _customPomTolerances.remove(pom.pomCode));
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
                  setState(() {
                    _customPomTolerances[pom.pomCode] = PomTolerance(posTol: pos, negTol: neg);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save Tolerance', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review Scanned Spec Sheet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_rounded, color: AppColors.primaryBlue),
            tooltip: 'Export to Excel (.xlsx)',
            onPressed: _showExcelExportDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inTolLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inTolGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.inTolGreen, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Spec Sheet Successfully Loaded',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.deepNavy,
                          ),
                        ),
                        Text(
                          '${_poms.length} points across ${_sizes.length} sizes. Tolerance: ${_toleranceCategory.label}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slateNavy.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Job Details & Standard Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Job Details & Tolerance Standard',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _styleController,
                    decoration: const InputDecoration(
                      labelText: 'Style Name / Code',
                      prefixIcon: Icon(Icons.style_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _poController,
                          decoration: const InputDecoration(
                            labelText: 'PO Number',
                            prefixIcon: Icon(Icons.tag_rounded, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _brandController,
                          decoration: const InputDecoration(
                            labelText: 'Brand / Buyer',
                            prefixIcon: Icon(Icons.business_rounded, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tolerance Standard Category Switcher (Page 1 & 2)
                  const Text(
                    'Tolerance Category (Kontoor Global Standard)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slateNavy),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ToleranceCategory.values.map((cat) {
                      final selected = _toleranceCategory == cat;
                      return ChoiceChip(
                        label: Text(cat.label),
                        selected: selected,
                        selectedColor: AppColors.selectedBlueLight,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.primaryBlue : AppColors.deepNavy,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        onSelected: (_) => setState(() => _toleranceCategory = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Default Inspection Tolerance (Inches)
                  const Text(
                    'Default Fallback Tolerance (Inches)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slateNavy),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [0.125, 0.25, 0.375, 0.5].map((tol) {
                      final selected = _tolerance == tol;
                      final label = '± ${formatDeviation(tol)}"';
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        selectedColor: AppColors.selectedBlueLight,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.primaryBlue : AppColors.deepNavy,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setState(() => _tolerance = tol),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Samples per size
                  const Text(
                    'Sample Pieces Measured Per Size',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slateNavy),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [3, 5, 8, 10].map((cnt) {
                      final selected = _sampleCount == cnt;
                      return ChoiceChip(
                        label: Text('$cnt Samples'),
                        selected: selected,
                        selectedColor: AppColors.selectedBlueLight,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.primaryBlue : AppColors.deepNavy,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setState(() => _sampleCount = cnt),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Sizes Chip Preview
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Extracted Sizes',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.deepNavy),
                      ),
                      Text(
                        '${_sizes.length} sizes',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _sizes.map((s) {
                      return Chip(
                        label: Text(s, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // POM Points List with Manual Add Row & Individual Tolerance Adjustment (Pages 1 & 2)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Measurement Points (POM)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.deepNavy),
                            ),
                            Text(
                              '${_poms.length} points • Tap tolerance box to adjust per POM',
                              style: TextStyle(fontSize: 11, color: AppColors.slateNavy.withValues(alpha: 0.7)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Row', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        onPressed: _addNewPomRow,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _poms.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                    itemBuilder: (ctx, i) {
                      final pom = _poms[i];
                      final isCustom = _customPomTolerances.containsKey(pom.pomCode);
                      final tol = _customPomTolerances[pom.pomCode] ??
                          KontoorToleranceEngine.getStandardTolerance(
                            category: _toleranceCategory,
                            pomCode: pom.pomCode,
                            description: pom.description,
                            is38OrAbove: false,
                            defaultTolerance: _tolerance,
                          );

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.cardFill,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                pom.pomCode,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pom.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.deepNavy,
                                    ),
                                  ),
                                  Text(
                                    '${pom.sizeSpecs.length} specs',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.slateNavy.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Individual Tolerance Box Button (Page 1)
                            InkWell(
                              onTap: () => _editPomTolerance(pom),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCustom ? AppColors.selectedBlueLight : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCustom ? AppColors.primaryBlue : AppColors.borderLight,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tol.displayString,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isCustom ? AppColors.primaryBlue : AppColors.deepNavy,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.edit_rounded,
                                      size: 12,
                                      color: isCustom ? AppColors.primaryBlue : AppColors.slateNavy,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Start Inspection Button
            Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _proceedToInspection,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_chart_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Open Digital Inspection Sheet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
