import 'package:flutter/material.dart';
import '../../models/spec_sheet_model.dart';
import '../../services/excel_export_service.dart';
import '../../services/firestore_service.dart';
import '../../services/pdf_scanner_service.dart';
import '../../services/qr_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_histogram.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserSheets();
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
              : PdfScannerService.getExampleWranglerSpecSheet(); // Fallback to rich default
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activeSpecSheet = PdfScannerService.getExampleWranglerSpecSheet();
          _isLoading = false;
        });
      }
    }
  }

  void _onLogout() async {
    await QrAuthService.revokeSession(widget.session.sessionId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WebQrLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildTopNav(),
      body: _isLoading || _activeSpecSheet == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _buildWideBody(),
    );
  }

  PreferredSizeWidget _buildTopNav() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      titleSpacing: 24,
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
            child: const Icon(Icons.straighten_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEASURA DESKTOP',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Wide Multi-Size QA Inspection Suite',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(width: 28),

          // Active Job Selector
          if (_userSheets.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _activeSpecSheet?.id,
                  items: _userSheets.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.style} • PO: ${s.po}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      setState(() {
                        _activeSpecSheet = _userSheets.firstWhere((s) => s.id == id);
                      });
                    }
                  },
                ),
              ),
            ),
        ],
      ),
      actions: [
        // Linked mobile session indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                'Linked: ${widget.session.userEmail ?? "Mobile Device"}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Export Excel Button
        FilledButton.tonalIcon(
          icon: const Icon(Icons.file_download_rounded, size: 18),
          label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          onPressed: () {
            if (_activeSpecSheet != null) {
              ExcelExportService.exportAndShare(context, _activeSpecSheet!);
            }
          },
        ),
        const SizedBox(width: 12),

        // Logout
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
          tooltip: 'Disconnect Web Session',
          onPressed: _onLogout,
        ),
        const SizedBox(width: 16),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT: Wide Panoramic Inspection Matrix (68% of screen)
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildJobHeaderBanner(sheet),
              Expanded(child: _buildInspectionTable(sheet)),
            ],
          ),
        ),

        // Vertical divider
        Container(width: 1.5, color: const Color(0xFFE2E8F0)),

        // RIGHT: Sticky Live Analytics & Interactive Histogram (32% of screen)
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Real-Time QA Analytics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tolerance Standard: ${sheet.toleranceCategory.label}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Filter by POM
                  Row(
                    children: [
                      const Text('Filter:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('ALL'),
                                selected: _selectedPomFilter == 'ALL',
                                onSelected: (_) => setState(() => _selectedPomFilter = 'ALL'),
                              ),
                              const SizedBox(width: 6),
                              ...sheet.poms.map((p) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(p.pomCode),
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJobHeaderBanner(GarmentSpecSheet sheet) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          _metaBadge('STYLE', sheet.style, Icons.style_rounded),
          const SizedBox(width: 20),
          _metaBadge('PO NUMBER', sheet.po.isNotEmpty ? sheet.po : 'N/A', Icons.tag_rounded),
          const SizedBox(width: 20),
          _metaBadge('BRAND', sheet.brand, Icons.business_rounded),
          const SizedBox(width: 20),
          _metaBadge('STAGE', sheet.stage, Icons.wash_rounded),
          const Spacer(),
          Text(
            '${sheet.poms.length} POMs • ${sheet.sizes.length} Sizes (${sheet.sizes.join(", ")})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _metaBadge(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryBlue),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
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
          headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
          dataRowMinHeight: 38,
          dataRowMaxHeight: 46,
          columnSpacing: 18,
          columns: [
            const DataColumn(label: Text('POM')),
            const DataColumn(label: Text('DESCRIPTION')),
            const DataColumn(label: Text('TOL')),
            ...sheet.sizes.expand((size) => [
                  DataColumn(label: Text('SPEC\n$size')),
                  ...List.generate(sheet.sampleCountPerSize, (i) => DataColumn(label: Text('$size\n#${i + 1}'))),
                ]),
          ],
          rows: sheet.poms.map((pom) {
            return DataRow(
              cells: [
                DataCell(Text(pom.pomCode, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryBlue))),
                DataCell(Text(pom.description, style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      sheet.getPomTolerance(pom.pomCode).displayString,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                ),
                ...sheet.sizes.expand((size) {
                  final specVal = pom.sizeSpecs[size] ?? '-';
                  return [
                    DataCell(Text(specVal, style: const TextStyle(fontWeight: FontWeight.w800))),
                    ...List.generate(sheet.sampleCountPerSize, (sIdx) {
                      final reading = sheet.getReading(pom.pomCode, size, sIdx + 1);
                      if (reading == null) {
                        return const DataCell(Text('-', style: TextStyle(color: Color(0xFFCBD5E1))));
                      }
                      final isWithin = sheet.isWithinTolerance(reading.deviation, pomCode: pom.pomCode, size: size);
                      Color bgColor;
                      Color textColor;
                      if (reading.deviation == 0.0) {
                        bgColor = const Color(0xFFDCFCE7);
                        textColor = const Color(0xFF15803D);
                      } else if (isWithin) {
                        bgColor = const Color(0xFFF0FDF4);
                        textColor = const Color(0xFF166534);
                      } else {
                        bgColor = const Color(0xFFFEE2E2);
                        textColor = const Color(0xFFB91C1C);
                      }
                      return DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            reading.deviationText,
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: textColor),
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
