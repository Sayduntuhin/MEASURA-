import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/tolerance_standard.dart';
import '../services/pdf_scanner_service.dart';
import '../theme/app_theme.dart';
import 'spec_review_screen.dart';

class UploadSpecScreen extends StatefulWidget {
  const UploadSpecScreen({super.key});

  @override
  State<UploadSpecScreen> createState() => _UploadSpecScreenState();
}

class _UploadSpecScreenState extends State<UploadSpecScreen> {
  final PdfScannerService _scannerService = PdfScannerService();
  PlatformFile? _selectedFile;
  int _totalPages = 1;
  int _selectedPage = 1;
  ToleranceCategory _selectedCategory = ToleranceCategory.adultMaleStretch;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickFile() async {
    final file = await _scannerService.pickDocument();
    if (file != null) {
      int pages = 1;
      final ext = (file.extension ?? '').toLowerCase();
      if (ext == 'pdf') {
        try {
          final bytes = await PdfScannerService.getFileBytes(file);
          if (bytes != null && bytes.isNotEmpty) {
            final doc = PdfDocument(inputBytes: bytes);
            pages = doc.pages.count;
            doc.dispose();
          }
        } catch (_) {}
      }

      setState(() {
        _selectedFile = file;
        _totalPages = pages;
        _selectedPage = 1;
      });
    }
  }

  Future<void> _processFile({bool useExample = false}) async {
    if (!useExample && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first.')),
      );
      return;
    }

    final ext = (_selectedFile?.extension ?? '').toLowerCase();
    final isSpreadsheet = ext == 'xlsx' || ext == 'xls' || ext == 'csv' || ext == 'tsv' || ext == 'txt';

    Timer? ticker;
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = isSpreadsheet
          ? 'Reading spreadsheet cells (100% accurate, offline)... (20%)'
          : 'Starting document scanner... (0%)';
    });

    if (isSpreadsheet) {
      // Fast immediate progression for local spreadsheet parsing
      ticker = Timer.periodic(const Duration(milliseconds: 50), (t) {
        if (!mounted || !_isProcessing) {
          t.cancel();
          return;
        }
        setState(() {
          if (_progress < 0.90) {
            _progress += 0.20;
            _statusMessage = 'Extracting sizes & POM tolerance specifications... (${(_progress * 100).toInt()}%)';
          }
        });
      });
    } else {
      // Smooth progression for PDF scanner
      ticker = Timer.periodic(const Duration(milliseconds: 100), (t) {
        if (!mounted || !_isProcessing) {
          t.cancel();
          return;
        }
        setState(() {
          if (_progress < 0.25) {
            _progress += 0.03;
            _statusMessage = 'Reading document layout... (${(_progress * 100).toInt()}%)';
          } else if (_progress < 0.55) {
            _progress += 0.02;
            _statusMessage = 'Extracting page $_selectedPage for scan... (${(_progress * 100).toInt()}%)';
          } else if (_progress < 0.85) {
            _progress += 0.012;
            _statusMessage = 'Scanning measurement table... (${(_progress * 100).toInt()}%)';
          } else if (_progress < 0.94) {
            _progress += 0.005;
            _statusMessage = 'Formatting POM measurements & sizes... (${(_progress * 100).toInt()}%)';
          }
        });
      });
    }

    try {
      final specSheet = useExample
          ? PdfScannerService.getExampleWranglerSpecSheet()
          : await _scannerService.parseSpecSheet(
              file: _selectedFile!,
              targetPageIndex: _selectedPage - 1,
              onProgress: (p, msg) {
                if (mounted) {
                  setState(() {
                    _progress = p;
                    _statusMessage = msg;
                  });
                }
              },
            );

      ticker.cancel();
      if (!mounted) return;

      setState(() {
        _progress = 1.0;
        _statusMessage = isSpreadsheet
            ? 'Import complete! 100% exact specs loaded. (100%)'
            : 'Scan complete! (100%)';
      });

      // Brief delay so user sees the 100% completion badge
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final configuredSpec = specSheet.copyWith(toleranceCategory: _selectedCategory);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SpecReviewScreen(specSheet: configuredSpec),
        ),
      );
    } catch (e) {
      ticker.cancel();
      if (mounted) {
        String cleanMessage = e.toString();
        // Strip Dart/Flutter Exception prefix
        cleanMessage = cleanMessage.replaceFirst(RegExp(r'^Exception:\s*'), '');

        // If message is a raw JSON payload, extract the message property
        if (cleanMessage.contains('"message":')) {
          final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(cleanMessage);
          if (match != null && match.group(1) != null) {
            cleanMessage = match.group(1)!;
          }
        }

        final isOffline = cleanMessage.contains('SocketException') ||
            cleanMessage.contains('Failed host lookup') ||
            cleanMessage.contains('No address associated with hostname') ||
            cleanMessage.contains('Network is unreachable') ||
            cleanMessage.contains('No internet connection');

        final isTimeout = cleanMessage.contains('TimeoutException') ||
            cleanMessage.contains('Future not completed') ||
            cleanMessage.contains('timed out');

        if (isOffline) {
          cleanMessage = 'No internet connection. Please connect to Wi-Fi or mobile data to scan PDFs with AI Vision, or import an Excel (.xlsx / .csv) file for 100% offline scanning.';
        } else if (isTimeout) {
          cleanMessage = 'Processing timed out. The tech pack took longer than expected over this network. Please retry or import an Excel (.xlsx / .csv) file for instant offline parsing.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOffline ? Icons.wifi_off_rounded : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cleanMessage,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.outTolRed,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      ticker.cancel();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _progress = 0.0;
          _statusMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = (_selectedFile?.extension ?? '').toLowerCase();
    final isSpreadsheet = ext == 'xlsx' || ext == 'xls' || ext == 'csv' || ext == 'tsv' || ext == 'txt';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Import Tech Pack Spec'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.deepNavy, AppColors.slateNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepNavy.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paper & Digital QA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Instant Excel (.xlsx/.csv) & Vector PDF Importer',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Upload your garment measurement specs from Excel (.xlsx, .csv) or PDF. Excel tech packs are imported 100% accurately offline without AI or cost.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Product Category & Kontoor Tolerance Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
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
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryBlue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Product Category & Tolerance Standard',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select garment type to automatically apply Kontoor Global Tolerance chart (including Waist <38" vs ≥38" rules):',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.slateNavy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ToleranceCategory.values.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat.label),
                        selected: isSelected,
                        selectedColor: AppColors.selectedBlueLight,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.primaryBlue : AppColors.deepNavy,
                        ),
                        onSelected: _isProcessing
                            ? null
                            : (_) => setState(() => _selectedCategory = cat),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Upload Box
            InkWell(
              onTap: _isProcessing ? null : _pickFile,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedFile != null
                        ? (isSpreadsheet ? const Color(0xFF10B981) : AppColors.primaryBlue)
                        : AppColors.borderLight,
                    width: _selectedFile != null ? 2 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: _selectedFile != null
                            ? (isSpreadsheet
                                ? const Color(0xFFD1FAE5)
                                : AppColors.selectedBlueLight)
                            : AppColors.cardFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedFile != null
                            ? (isSpreadsheet
                                ? Icons.table_chart_rounded
                                : Icons.picture_as_pdf_rounded)
                            : Icons.cloud_upload_outlined,
                        size: 30,
                        color: isSpreadsheet
                            ? const Color(0xFF10B981)
                            : AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedFile != null
                          ? _selectedFile!.name
                          : 'Tap to upload Tech Pack (Excel, CSV, or PDF)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedFile != null
                          ? (isSpreadsheet
                              ? '⚡ 100% Accurate Offline Sheet · ${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB'
                              : '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB · $_totalPages ${totalPagesLabel(_totalPages)}')
                          : 'Supports Excel (.xlsx, .csv) & Buyer PDF Tech Packs',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSpreadsheet
                            ? const Color(0xFF047857)
                            : AppColors.slateNavy.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Multi-Page Selector (Only if PDF has multiple pages)
            if (_selectedFile != null && !isSpreadsheet && _totalPages > 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: AppColors.primaryBlue, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Page to Scan:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepNavy,
                            ),
                          ),
                          Text(
                            'Scanning 1 page keeps extraction fast & prevents timeouts',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.slateNavy.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Decrement
                    IconButton.filledTonal(
                      onPressed: (_isProcessing || _selectedPage <= 1)
                          ? null
                          : () => setState(() => _selectedPage--),
                      icon: const Icon(Icons.remove, size: 18),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$_selectedPage / $_totalPages',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    // Increment
                    IconButton.filledTonal(
                      onPressed: (_isProcessing || _selectedPage >= _totalPages)
                          ? null
                          : () => setState(() => _selectedPage++),
                      icon: const Icon(Icons.add, size: 18),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Percentage Loading Card or Scan Button
            if (_isProcessing)
              _buildProgressCard()
            else if (_selectedFile != null)
              Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: isSpreadsheet
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [AppColors.primaryBlue, const Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isSpreadsheet ? const Color(0xFF10B981) : AppColors.primaryBlue)
                          .withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _processFile(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSpreadsheet
                              ? Icons.table_view_rounded
                              : Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isSpreadsheet
                                ? 'Import Spreadsheet (100% Accurate)'
                                : (_totalPages > 1
                                    ? 'Scan Page $_selectedPage of $_totalPages'
                                    : 'Scan & Extract Data'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: Divider(color: AppColors.borderLight)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR TEST WITH SAMPLE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slateNavy),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.borderLight)),
              ],
            ),
            const SizedBox(height: 16),

            // Quick 1-Click Load Wrangler Spec
            Material(
              color: AppColors.surfaceWhite,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.selectedBlueLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlue, size: 24),
                  ),
                  title: const Text(
                    'Load Wrangler 10E7621SW Spec',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.deepNavy),
                  ),
                  subtitle: const Text(
                    'Loads the 14 POMs, 11 sizes & sample readings from your PDF/photo',
                    style: TextStyle(fontSize: 12, color: AppColors.slateNavy),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primaryBlue),
                  onTap: _isProcessing ? null : () => _processFile(useExample: true),
                ),
              ),
              const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String totalPagesLabel(int count) => count == 1 ? 'page' : 'pages';

  Widget _buildProgressCard() {
    final percent = (_progress * 100).clamp(0, 100).toInt();
    final isDone = _progress >= 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone ? AppColors.inTolGreen : AppColors.primaryBlue.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDone ? AppColors.inTolGreen : AppColors.primaryBlue).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isDone)
                      const Icon(Icons.check_circle_rounded, color: AppColors.inTolGreen, size: 22)
                    else
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.primaryBlue,
                          strokeWidth: 2.5,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isDone ? 'Scan Completed!' : 'Scanning Page $_selectedPage...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDone ? AppColors.inTolLight : AppColors.selectedBlueLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: isDone ? AppColors.inTolGreen : AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Percentage Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? AppColors.inTolGreen : AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            _statusMessage.isNotEmpty ? _statusMessage : 'Processing measurement data...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDone ? AppColors.inTolGreen : AppColors.slateNavy.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
