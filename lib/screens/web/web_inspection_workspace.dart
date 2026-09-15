import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/spec_sheet_model.dart';
import '../../models/tolerance_standard.dart';
import '../../services/excel_export_service.dart';
import '../../services/firestore_service.dart';
import '../../services/measurement_parser.dart';
import '../../services/pdf_scanner_service.dart';
import '../../services/qr_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_measurement_dialog.dart';
import '../../widgets/interactive_histogram.dart';
import '../../widgets/quick_deviation_sheet.dart';
import '../digital_inspection_sheet_screen.dart';
import '../home_screen.dart';
import '../upload_spec_screen.dart';
import 'web_qr_login_screen.dart';

class WebInspectionWorkspace extends StatefulWidget {
  final QrAuthSession session;
  final bool keepSignedIn;

  const WebInspectionWorkspace({
    super.key,
    required this.session,
    this.keepSignedIn = true,
  });

  @override
  State<WebInspectionWorkspace> createState() => _WebInspectionWorkspaceState();
}

class _WebInspectionWorkspaceState extends State<WebInspectionWorkspace> {
  GarmentSpecSheet? _activeSpecSheet;
  List<GarmentSpecSheet> _userSheets = [];
  bool _isLoading = true;
  String _selectedPomFilter = 'ALL';

  // Active cell & inspection flow
  String? _activePomCode;
  String? _activeSize;
  int? _activeSampleIndex;
  bool _advanceTopToBottom = true; // Flow: ⬇️ Down across POMs vs ➡️ Right across samples
  final bool _dockKeypad = true;

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserSheets();
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserSheets() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.session.userId ?? '';
      final sheets = await FirestoreService.getUserSpecSheets(userId: userId);
      if (mounted) {
        setState(() {
          _userSheets = sheets;
          _activeSpecSheet = sheets.isNotEmpty
              ? sheets.first
              : PdfScannerService.getExampleWranglerSpecSheet();
          _initializeActiveCell();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activeSpecSheet = PdfScannerService.getExampleWranglerSpecSheet();
          _initializeActiveCell();
          _isLoading = false;
        });
      }
    }
  }

  void _initializeActiveCell() {
    if (_activeSpecSheet != null &&
        _activeSpecSheet!.sizes.isNotEmpty &&
        _activeSpecSheet!.poms.isNotEmpty) {
      _activePomCode = _activeSpecSheet!.poms.first.pomCode;
      _activeSize = _activeSpecSheet!.sizes.first;
      _activeSampleIndex = 1;
    }
  }

  void _onLogout() async {
    await QrAuthService.revokeSession(widget.session.sessionId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WebQrLoginScreen()),
    );
  }

  void _recordSample(String pomCode, String size, int sampleIndex, double deviation, String text) {
    if (_activeSpecSheet == null) return;
    String cleanText = text.trim();
    while (cleanText.startsWith('++')) {
      cleanText = cleanText.substring(1);
    }

    setState(() {
      final key = GarmentSpecSheet.cellKey(pomCode, size, sampleIndex);
      final updatedReadings = Map<String, SampleReading>.from(_activeSpecSheet!.readings);
      updatedReadings[key] = SampleReading(
        pomCode: pomCode,
        size: size,
        sampleIndex: sampleIndex,
        deviation: deviation,
        deviationText: cleanText,
        recordedAt: DateTime.now(),
      );
      _activeSpecSheet = _activeSpecSheet!.copyWith(readings: updatedReadings);

      // Save to Firestore in background
      FirestoreService.saveSpecSheet(_activeSpecSheet!);

      // Auto-advance active cell
      _advanceActiveCell(pomCode, size, sampleIndex);
    });
  }

  void _advanceActiveCell(String pomCode, String size, int sampleIndex) {
    if (_activeSpecSheet == null) return;
    if (_advanceTopToBottom) {
      // Flow: Down across POMs
      final currentPomIdx = _activeSpecSheet!.poms.indexWhere((p) => p.pomCode == pomCode);
      if (currentPomIdx >= 0 && currentPomIdx < _activeSpecSheet!.poms.length - 1) {
        _activePomCode = _activeSpecSheet!.poms[currentPomIdx + 1].pomCode;
      } else if (sampleIndex < _activeSpecSheet!.sampleCountPerSize) {
        _activePomCode = _activeSpecSheet!.poms.isNotEmpty ? _activeSpecSheet!.poms.first.pomCode : null;
        _activeSampleIndex = sampleIndex + 1;
      } else {
        final currentSizeIdx = _activeSpecSheet!.sizes.indexOf(size);
        if (currentSizeIdx >= 0 && currentSizeIdx < _activeSpecSheet!.sizes.length - 1) {
          final nextSz = _activeSpecSheet!.sizes[currentSizeIdx + 1];
          _activeSize = nextSz;
          _activePomCode = _activeSpecSheet!.poms.isNotEmpty ? _activeSpecSheet!.poms.first.pomCode : null;
          _activeSampleIndex = 1;
        }
      }
    } else {
      // Flow: Right across samples
      if (sampleIndex < _activeSpecSheet!.sampleCountPerSize) {
        _activeSampleIndex = sampleIndex + 1;
      } else {
        final currentPomIdx = _activeSpecSheet!.poms.indexWhere((p) => p.pomCode == pomCode);
        if (currentPomIdx >= 0 && currentPomIdx < _activeSpecSheet!.poms.length - 1) {
          _activePomCode = _activeSpecSheet!.poms[currentPomIdx + 1].pomCode;
          _activeSampleIndex = 1;
        }
      }
    }
  }

  void _clearSample(String pomCode, String size, int sampleIndex) {
    if (_activeSpecSheet == null) return;
    setState(() {
      final key = GarmentSpecSheet.cellKey(pomCode, size, sampleIndex);
      final updatedReadings = Map<String, SampleReading>.from(_activeSpecSheet!.readings);
      updatedReadings.remove(key);
      _activeSpecSheet = _activeSpecSheet!.copyWith(readings: updatedReadings);
      FirestoreService.saveSpecSheet(_activeSpecSheet!);
    });
  }

  void _openCustomKeyboardDialog(String pomCode, String size, int sampleIndex) {
    if (_activeSpecSheet == null) return;
    final pomRow = _activeSpecSheet!.poms.firstWhere(
      (p) => p.pomCode == pomCode,
      orElse: () => SpecPomRow(no: 1, pomCode: pomCode, description: pomCode, sizeSpecs: {}),
    );
    final specVal = pomRow.sizeSpecs[size] ?? '-';
    final currentReading = _activeSpecSheet!.getReading(pomCode, size, sampleIndex);

    setState(() {
      _activePomCode = pomCode;
      _activeSize = size;
      _activeSampleIndex = sampleIndex;
    });

    CustomMeasurementDialog.show(
      context,
      pomCode: pomCode,
      description: pomRow.description,
      size: size,
      specValue: specVal,
      sampleIndex: sampleIndex,
      currentDeviation: currentReading?.deviation,
      currentDeviationText: currentReading?.deviationText,
      tolerance: _activeSpecSheet!.tolerance,
      pomTolerance: _activeSpecSheet!.getPomTolerance(pomCode, size: size),
      advanceTopToBottom: _advanceTopToBottom,
      onSave: (dev, txt) => _recordSample(pomCode, size, sampleIndex, dev, txt),
      onSaveAndNext: (dev, txt) {
        _recordSample(pomCode, size, sampleIndex, dev, txt);
        Future.delayed(const Duration(milliseconds: 160), () {
          if (!mounted || _activePomCode == null || _activeSize == null || _activeSampleIndex == null) return;
          _openCustomKeyboardDialog(_activePomCode!, _activeSize!, _activeSampleIndex!);
        });
      },
      onClear: () => _clearSample(pomCode, size, sampleIndex),
    );
  }

  void _handleDesktopKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_activePomCode == null || _activeSize == null || _activeSampleIndex == null || _activeSpecSheet == null) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _openCustomKeyboardDialog(_activePomCode!, _activeSize!, _activeSampleIndex!);
    } else if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      _clearSample(_activePomCode!, _activeSize!, _activeSampleIndex!);
    } else if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      _recordSample(_activePomCode!, _activeSize!, _activeSampleIndex!, 0.0, '0');
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final poms = _activeSpecSheet!.poms;
      final idx = poms.indexWhere((p) => p.pomCode == _activePomCode);
      if (idx < poms.length - 1) {
        setState(() => _activePomCode = poms[idx + 1].pomCode);
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final poms = _activeSpecSheet!.poms;
      final idx = poms.indexWhere((p) => p.pomCode == _activePomCode);
      if (idx > 0) {
        setState(() => _activePomCode = poms[idx - 1].pomCode);
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (_activeSampleIndex! < _activeSpecSheet!.sampleCountPerSize) {
        setState(() => _activeSampleIndex = _activeSampleIndex! + 1);
      } else {
        final sizes = _activeSpecSheet!.sizes;
        final sIdx = sizes.indexOf(_activeSize!);
        if (sIdx < sizes.length - 1) {
          setState(() {
            _activeSize = sizes[sIdx + 1];
            _activeSampleIndex = 1;
          });
        }
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (_activeSampleIndex! > 1) {
        setState(() => _activeSampleIndex = _activeSampleIndex! - 1);
      } else {
        final sizes = _activeSpecSheet!.sizes;
        final sIdx = sizes.indexOf(_activeSize!);
        if (sIdx > 0) {
          setState(() {
            _activeSize = sizes[sIdx - 1];
            _activeSampleIndex = _activeSpecSheet!.sampleCountPerSize;
          });
        }
      }
    }
  }

  void _showAddPomDialog() {
    if (_activeSpecSheet == null) return;
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final specControllers = <String, TextEditingController>{};
    for (final sz in _activeSpecSheet!.sizes) {
      specControllers[sz] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('Add New Measurement Point (POM)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'POM Code (e.g. WAST, COLL)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description (e.g. Collar Width)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Nominal Spec Values per Size:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.deepNavy)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _activeSpecSheet!.sizes.map((sz) {
                    return SizedBox(
                      width: 110,
                      child: TextField(
                        controller: specControllers[sz],
                        decoration: InputDecoration(
                          labelText: sz,
                          hintText: 'e.g. 32 1/4',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
            onPressed: () {
              final code = codeCtrl.text.trim().toUpperCase();
              final desc = descCtrl.text.trim();
              if (code.isEmpty || desc.isEmpty) return;

              final specs = <String, String>{};
              specControllers.forEach((sz, ctrl) {
                if (ctrl.text.trim().isNotEmpty) specs[sz] = ctrl.text.trim();
              });

              final newPom = SpecPomRow(no: _activeSpecSheet!.poms.length + 1, pomCode: code, description: desc, sizeSpecs: specs);
              setState(() {
                final updatedPoms = List<SpecPomRow>.from(_activeSpecSheet!.poms)..add(newPom);
                _activeSpecSheet = _activeSpecSheet!.copyWith(poms: updatedPoms);
                FirestoreService.saveSpecSheet(_activeSpecSheet!);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add POM Row'),
          ),
        ],
      ),
    );
  }

  void _editPomTolerance(SpecPomRow pom) {
    if (_activeSpecSheet == null) return;
    final currentTol = _activeSpecSheet!.getPomTolerance(pom.pomCode);
    double posVal = currentTol.posTol;
    double negVal = currentTol.negTol;
    bool isSymmetric = (posVal - negVal).abs() < 0.001;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          const tolPresets = [0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 1.0];
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Override Tolerance: ${pom.pomCode} • ${pom.description}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Symmetric Tolerance (±)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Switch(
                        value: isSymmetric,
                        activeThumbColor: AppColors.primaryBlue,
                        onChanged: (val) {
                          setDlgState(() {
                            isSymmetric = val;
                            if (isSymmetric) negVal = posVal;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isSymmetric
                        ? 'Tolerance: ±${MeasurementParser.formatDeviation(posVal, explicitPlus: false)}"'
                        : 'Tolerance: +${MeasurementParser.formatDeviation(posVal, explicitPlus: false)}" / -${MeasurementParser.formatDeviation(negVal, explicitPlus: false)}"',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 12),
                  const Text('Positive (+) Tolerance:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.slateNavy)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tolPresets.map((t) {
                      final selected = (posVal - t).abs() < 0.001;
                      return ChoiceChip(
                        label: Text('+${MeasurementParser.formatDeviation(t, explicitPlus: false)}"'),
                        selected: selected,
                        onSelected: (_) {
                          setDlgState(() {
                            posVal = t;
                            if (isSymmetric) negVal = t;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (!isSymmetric) ...[
                    const SizedBox(height: 12),
                    const Text('Negative (-) Tolerance:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.slateNavy)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tolPresets.map((t) {
                        final selected = (negVal - t).abs() < 0.001;
                        return ChoiceChip(
                          label: Text('-${MeasurementParser.formatDeviation(t, explicitPlus: false)}"'),
                          selected: selected,
                          onSelected: (_) => setDlgState(() => negVal = t),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    final updatedCustom = Map<String, PomTolerance>.from(_activeSpecSheet!.customPomTolerances);
                    updatedCustom.remove(pom.pomCode);
                    _activeSpecSheet = _activeSpecSheet!.copyWith(customPomTolerances: updatedCustom);
                    FirestoreService.saveSpecSheet(_activeSpecSheet!);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Reset to Default', style: TextStyle(color: AppColors.outTolRed)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    final updatedCustom = Map<String, PomTolerance>.from(_activeSpecSheet!.customPomTolerances);
                    updatedCustom[pom.pomCode] = PomTolerance(posTol: posVal, negTol: negVal);
                    _activeSpecSheet = _activeSpecSheet!.copyWith(customPomTolerances: updatedCustom);
                    FirestoreService.saveSpecSheet(_activeSpecSheet!);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save Tolerance'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePomRow = (_activeSpecSheet != null && _activePomCode != null)
        ? _activeSpecSheet!.poms.cast<SpecPomRow?>().firstWhere(
            (p) => p?.pomCode == _activePomCode,
            orElse: () => null,
          )
        : null;

    final activeSpecVal = (activePomRow != null && _activeSize != null)
        ? (activePomRow.sizeSpecs[_activeSize!] ?? '-')
        : '-';

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleDesktopKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildTopNav(),
        body: _isLoading || _activeSpecSheet == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
            : _buildWideBody(),
        bottomNavigationBar: (_dockKeypad &&
                _activeSpecSheet != null &&
                _activePomCode != null &&
                activePomRow != null &&
                _activeSize != null &&
                _activeSampleIndex != null)
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
                tolerance: _activeSpecSheet!.tolerance,
                pomTolerance: _activeSpecSheet!.getPomTolerance(_activePomCode!, size: _activeSize),
                currentDeviation: _activeSpecSheet!.getReading(_activePomCode!, _activeSize!, _activeSampleIndex!)?.deviation,
                currentDeviationText: _activeSpecSheet!.getReading(_activePomCode!, _activeSize!, _activeSampleIndex!)?.deviationText,
                advanceTopToBottom: _advanceTopToBottom,
                onToggleAdvanceDirection: () => setState(() => _advanceTopToBottom = !_advanceTopToBottom),
                onOpenKeyboard: () => _openCustomKeyboardDialog(_activePomCode!, _activeSize!, _activeSampleIndex!),
                onSelect: (dev, txt) => _recordSample(_activePomCode!, _activeSize!, _activeSampleIndex!, dev, txt),
                onClear: () => _clearSample(_activePomCode!, _activeSize!, _activeSampleIndex!),
              )
            : null,
      ),
    );
  }

  PreferredSizeWidget _buildTopNav() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryBlue, Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.straighten_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEASURA WEB',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Interactive Digital Garment Inspection Suite',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(width: 20),

          // Active Job Selector Dropdown
          if (_userSheets.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _activeSpecSheet?.id,
                  isDense: true,
                  items: _userSheets.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${s.style} • PO: ${s.po.isNotEmpty ? s.po : "N/A"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      setState(() {
                        _activeSpecSheet = _userSheets.firstWhere((s) => s.id == id);
                        _initializeActiveCell();
                      });
                    }
                  },
                ),
              ),
            ),
        ],
      ),
      actions: [
        // 1. Upload Spec Button (PDF / Excel)
        TextButton.icon(
          icon: const Icon(Icons.upload_file_rounded, size: 16, color: AppColors.primaryBlue),
          label: const Text('Upload Spec', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primaryBlue)),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadSpecScreen())).then((_) => _loadUserSheets());
          },
        ),
        const SizedBox(width: 6),

        // 2. Add POM Button
        TextButton.icon(
          icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryBlue),
          label: const Text('Add POM', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primaryBlue)),
          onPressed: _showAddPomDialog,
        ),
        const SizedBox(width: 6),

        // 3. Launch Single-Sheet Mobile/Tablet View
        TextButton.icon(
          icon: const Icon(Icons.phone_iphone_rounded, size: 16, color: Color(0xFF0F172A)),
          label: const Text('Full Sheet View', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A))),
          onPressed: () {
            if (_activeSpecSheet != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DigitalInspectionSheetScreen(initialSpecSheet: _activeSpecSheet!),
                ),
              ).then((_) => _loadUserSheets());
            }
          },
        ),
        const SizedBox(width: 6),

        // 4. QA Dashboard / History View
        TextButton.icon(
          icon: const Icon(Icons.dashboard_rounded, size: 16, color: Color(0xFF0F172A)),
          label: const Text('Dashboard & Jobs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A))),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeScreen()));
          },
        ),
        const SizedBox(width: 8),

        // 5. Export Excel Button
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEFF6FF),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          icon: const Icon(Icons.file_download_rounded, size: 16, color: AppColors.primaryBlue),
          label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primaryBlue)),
          onPressed: () {
            if (_activeSpecSheet != null) {
              ExcelExportService.exportAndShare(context, _activeSpecSheet!);
            }
          },
        ),
        const SizedBox(width: 8),

        // Logout / Disconnect
        IconButton(
          icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF64748B)),
          tooltip: 'Disconnect Session',
          onPressed: _onLogout,
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildWideBody() {
    final sheet = _activeSpecSheet!;
    final totalDeviations = <double>[];
    for (final pom in sheet.poms) {
      if (_selectedPomFilter != 'ALL' && pom.pomCode != _selectedPomFilter) continue;
      for (final size in sheet.sizes) {
        for (int s = 1; s <= sheet.sampleCountPerSize; s++) {
          final r = sheet.getReading(pom.pomCode, size, s);
          if (r != null) totalDeviations.add(r.deviation);
        }
      }
    }

    final totalCount = sheet.readings.length;
    final outOfTolCount = sheet.outOfToleranceCount;
    final inTolCount = totalCount - outOfTolCount;
    final passRate = totalCount == 0 ? 100 : ((inTolCount / totalCount) * 100).round();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT: Wide Panoramic Interactive Inspection Matrix (72% of screen)
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildJobHeaderBanner(sheet),
              _buildTableControlBar(sheet),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(child: _buildInspectionTable(sheet)),
            ],
          ),
        ),

        // Vertical divider
        Container(width: 1.5, color: const Color(0xFFE2E8F0)),

        // RIGHT: Sticky Live Analytics & Interactive Histogram (28% of screen)
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_rounded, size: 20, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      const Text(
                        'Real-Time QA Analytics',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: passRate >= 90 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$passRate% Pass',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: passRate >= 90 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick Statistics Badges
                  Row(
                    children: [
                      _statMiniBadge('Recorded', '$totalCount', const Color(0xFFF1F5F9), AppColors.deepNavy),
                      const SizedBox(width: 8),
                      _statMiniBadge('In Tol', '$inTolCount', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
                      const SizedBox(width: 8),
                      _statMiniBadge('Out Tol', '$outOfTolCount', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Tolerance Standard: ${sheet.toleranceCategory.label}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),

                  // Filter by POM
                  Row(
                    children: [
                      const Text('Filter:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('ALL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                selected: _selectedPomFilter == 'ALL',
                                onSelected: (_) => setState(() => _selectedPomFilter = 'ALL'),
                              ),
                              const SizedBox(width: 6),
                              ...sheet.poms.map((p) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(p.pomCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                      selected: _selectedPomFilter == p.pomCode,
                                      onSelected: (_) => setState(() => _selectedPomFilter = p.pomCode),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Embedded Live Histogram
                  InteractiveHistogram(
                    tolerance: sheet.tolerance,
                    deviations: totalDeviations,
                    title: _selectedPomFilter == 'ALL' ? 'Overall Spec Distribution' : 'POM $_selectedPomFilter Distribution',
                  ),
                  const SizedBox(height: 16),

                  // Keyboard Help hint
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Desktop Shortcuts:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.deepNavy)),
                        SizedBox(height: 4),
                        Text('• Double-click cell or press Enter: Open Keyboard Input\n• Arrow keys: Navigate cells\n• 0 key: Instant 0 (Spec)\n• Backspace: Clear cell',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.4)),
                      ],
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

  Widget _statMiniBadge(String label, String value, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: textColor.withValues(alpha: 0.8))),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildJobHeaderBanner(GarmentSpecSheet sheet) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _metaBadge('STYLE', sheet.style, Icons.style_rounded),
          const SizedBox(width: 18),
          _metaBadge('PO NUMBER', sheet.po.isNotEmpty ? sheet.po : 'N/A', Icons.tag_rounded),
          const SizedBox(width: 18),
          _metaBadge('BRAND', sheet.brand, Icons.business_rounded),
          const SizedBox(width: 18),
          _metaBadge('STAGE', sheet.stage, Icons.wash_rounded),
          const Spacer(),
          Text(
            '${sheet.poms.length} POMs • ${sheet.sizes.length} Sizes (${sheet.sizes.join(", ")})',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTableControlBar(GarmentSpecSheet sheet) {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          // Direction Toggle Button
          InkWell(
            onTap: () {
              setState(() => _advanceTopToBottom = !_advanceTopToBottom);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _advanceTopToBottom ? Icons.arrow_downward_rounded : Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _advanceTopToBottom ? 'Flow: ⬇️ Down across POMs' : 'Flow: ➡️ Right across samples',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Active cell indicator & Keyboard edit button
          if (_activePomCode != null && _activeSize != null && _activeSampleIndex != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Row(
                children: [
                  Text(
                    'Active: ${_activePomCode!} • ${_activeSize!} • #${_activeSampleIndex!}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _openCustomKeyboardDialog(_activePomCode!, _activeSize!, _activeSampleIndex!),
                    child: const Row(
                      children: [
                        Icon(Icons.keyboard_alt_rounded, size: 14, color: AppColors.primaryBlue),
                        SizedBox(width: 3),
                        Text('Edit (⌨️)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.primaryBlue)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),

          // Guide hint
          const Text(
            '💡 Click cell to select • Double-click or ⌨️ for general keyboard entry',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _metaBadge(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primaryBlue),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          ],
        ),
      ],
    );
  }

  Widget _buildInspectionTable(GarmentSpecSheet sheet) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
          headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columnSpacing: 10,
          horizontalMargin: 12,
          columns: [
            const DataColumn(label: Text('POM')),
            const DataColumn(label: Text('DESCRIPTION')),
            const DataColumn(label: Text('TOLERANCE')),
            ...sheet.sizes.expand((size) => [
                  DataColumn(label: Text('SPEC\n$size', textAlign: TextAlign.center)),
                  ...List.generate(sheet.sampleCountPerSize, (i) => DataColumn(label: Text('$size\n#${i + 1}', textAlign: TextAlign.center))),
                ]),
          ],
          rows: sheet.poms.map((pom) {
            final isRowActive = _activePomCode == pom.pomCode;
            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (isRowActive) return const Color(0xFFF0F9FF);
                return null;
              }),
              cells: [
                // POM Code
                DataCell(
                  InkWell(
                    onTap: () => setState(() => _activePomCode = pom.pomCode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pom.pomCode,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.primaryBlue),
                      ),
                    ),
                  ),
                ),
                // POM Description
                DataCell(
                  InkWell(
                    onTap: () => _editPomTolerance(pom),
                    child: Text(
                      pom.description,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ),
                // POM Tolerance Badge (Clickable to edit tolerance!)
                DataCell(
                  InkWell(
                    onTap: () => _editPomTolerance(pom),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sheet.getPomTolerance(pom.pomCode).displayString,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.deepNavy),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.edit, size: 10, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                ),
                // Sizes & Samples
                ...sheet.sizes.expand((size) {
                  final specVal = pom.sizeSpecs[size] ?? '-';
                  return [
                    // Spec nominal cell
                    DataCell(
                      Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          specVal,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppColors.deepNavy),
                        ),
                      ),
                    ),
                    // Sample Cells (#1..#5)
                    ...List.generate(sheet.sampleCountPerSize, (sIdx) {
                      final sNumber = sIdx + 1;
                      final reading = sheet.getReading(pom.pomCode, size, sNumber);
                      final isActive = _activePomCode == pom.pomCode && _activeSize == size && _activeSampleIndex == sNumber;

                      final hasReading = reading != null;
                      final isWithin = hasReading
                          ? sheet.isWithinTolerance(reading.deviation, pomCode: pom.pomCode, size: size)
                          : true;

                      Color cellBg = Colors.white;
                      Color textColor = AppColors.deepNavy;

                      if (hasReading) {
                        if (reading.deviation == 0.0) {
                          cellBg = const Color(0xFFDCFCE7);
                          textColor = const Color(0xFF15803D);
                        } else if (isWithin) {
                          cellBg = const Color(0xFFF0FDF4);
                          textColor = const Color(0xFF166534);
                        } else {
                          cellBg = const Color(0xFFFEE2E2);
                          textColor = const Color(0xFFB91C1C);
                        }
                      }

                      return DataCell(
                        InkWell(
                          onTap: () {
                            if (isActive) {
                              _openCustomKeyboardDialog(pom.pomCode, size, sNumber);
                            } else {
                              setState(() {
                                _activePomCode = pom.pomCode;
                                _activeSize = size;
                                _activeSampleIndex = sNumber;
                              });
                            }
                          },
                          onDoubleTap: () => _openCustomKeyboardDialog(pom.pomCode, size, sNumber),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: cellBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isActive ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
                                    width: isActive ? 2.0 : 1.0,
                                  ),
                                ),
                                child: hasReading
                                    ? FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          reading.deviationText,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            color: textColor,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        '·',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isActive ? AppColors.primaryBlue : const Color(0xFFCBD5E1),
                                          fontWeight: isActive ? FontWeight.w900 : FontWeight.normal,
                                        ),
                                      ),
                              ),
                              if (isActive)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(1),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit, size: 6, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ];
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
