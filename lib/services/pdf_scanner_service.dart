import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../models/spec_sheet_model.dart';
import 'excel_spec_parser.dart';
import 'garment_table_parser.dart';

class ScannedPdfNeedsVisionException implements Exception {
  final String message;
  ScannedPdfNeedsVisionException([this.message = 'Scanned image PDF detected.']);
  @override
  String toString() => message;
}

class PdfScannerService {
  static const Uuid _uuid = Uuid();

  /// Default Gemini Vision API key (can be supplied via --dart-define=GEMINI_API_KEY=xxx)
  static const String kDefaultGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static String _memoryApiKey = '';

  /// Retrieves user-saved Gemini API key (from disk or memory)
  static Future<String> getSavedApiKey() async {
    if (_memoryApiKey.isNotEmpty) return _memoryApiKey;
    if (kIsWeb) return kDefaultGeminiApiKey;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/gemini_key.txt');
      if (await file.exists()) {
        final key = (await file.readAsString()).trim();
        _memoryApiKey = key;
        return key;
      }
    } catch (_) {}
    return kDefaultGeminiApiKey;
  }

  /// Saves user Gemini API key to disk for future scans
  static Future<void> saveApiKey(String key) async {
    _memoryApiKey = key.trim();
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/gemini_key.txt');
      await file.writeAsString(key.trim());
    } catch (_) {}
  }

  /// Picks a document (PDF, Excel, CSV, or image) from the device.
  Future<PlatformFile?> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'tsv', 'txt', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        return result.files.first;
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
    return null;
  }

  /// Helper to get bytes across all platforms (web, mobile, desktop)
  static Future<Uint8List?> getFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }
    if (!kIsWeb && file.path != null) {
      try {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          return await ioFile.readAsBytes();
        }
      } catch (e) {
        debugPrint('Error reading file from path: $e');
      }
    }
    return null;
  }

  /// Parses the user-provided spec sheet document with page isolation & percentage progress
  Future<GarmentSpecSheet> parseSpecSheet({
    required PlatformFile file,
    int targetPageIndex = 0,
    String? geminiApiKey,
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.10, 'Reading document from storage (10%)...');
    final bytes = await getFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Unable to read file data from "${file.name}". Please re-select the file.');
    }

    final ext = (file.extension ?? '').toLowerCase();
    final fallbackName = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

    // 0. Direct 100% Accurate & Free Offline Excel / CSV Parser (No AI, zero latency, 100% accuracy)
    if (ext == 'xlsx' || ext == 'xls' || ext == 'csv' || ext == 'tsv' || ext == 'txt') {
      onProgress?.call(0.40, 'Parsing spreadsheet measurements (100% accurate, offline)...');
      final parsed = ExcelSpecParser.parse(
        bytes: bytes,
        fileName: file.name,
        fallbackStyle: fallbackName,
      );
      onProgress?.call(1.0, 'Spreadsheet import complete! (100%)');
      return parsed;
    }

    Uint8List bytesToScan = bytes;

    // 1. If PDF, check text and isolate the selected page
    if (ext == 'pdf') {
      try {
        onProgress?.call(0.20, 'Analyzing PDF page ${targetPageIndex + 1} (20%)...');
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final int totalPages = document.pages.count;
        final int safePageIndex = targetPageIndex.clamp(0, totalPages - 1);

        // Try text extraction on the selected page
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final pageText = extractor.extractText(startPageIndex: safePageIndex, endPageIndex: safePageIndex);
        debugPrint('--- Extracted Page ${safePageIndex + 1} Text (${pageText.length} chars) ---');
        debugPrint('=== RAW PAGE TEXT ===\n$pageText\n=== END RAW PAGE TEXT ===');

        if (pageText.trim().length > 30) {
          final parsed = GarmentTableParser.parse(pageText, fallbackStyle: fallbackName);
          // ONLY trust local text parsing if it extracted REAL sizes and real POM rows with specs!
          if (parsed.sizes.length >= 2 &&
              parsed.poms.length >= 2 &&
              parsed.poms.any((p) => p.sizeSpecs.isNotEmpty)) {
            debugPrint('Local digital table parser succeeded on page ${safePageIndex + 1} with ${parsed.poms.length} POMs and ${parsed.sizes.length} sizes: ${parsed.sizes}');
            document.dispose();
            onProgress?.call(1.0, 'Complete! (100%)');
            return parsed;
          }
        }

        // If the selected page didn't contain a measurement table, automatically check other pages!
        if (totalPages > 1) {
          onProgress?.call(0.28, 'Searching other pages for measurement specs... (28%)');
          for (int p = 0; p < totalPages; p++) {
            if (p == safePageIndex) continue;
            try {
              final altText = extractor.extractText(startPageIndex: p, endPageIndex: p);
              if (altText.trim().length > 30) {
                final altParsed = GarmentTableParser.parse(altText, fallbackStyle: fallbackName);
                if (altParsed.sizes.length >= 2 &&
                    altParsed.poms.length >= 2 &&
                    altParsed.poms.any((pom) => pom.sizeSpecs.isNotEmpty)) {
                  debugPrint('Auto-detected measurement table on Page ${p + 1} of $totalPages with ${altParsed.poms.length} POMs and ${altParsed.sizes.length} sizes: ${altParsed.sizes}');
                  document.dispose();
                  onProgress?.call(1.0, 'Measurement specs auto-detected on Page ${p + 1}! (100%)');
                  return altParsed;
                }
              }
            } catch (_) {}
          }
        }

        // If local text parsing did not find a complete table, isolate ONLY the target page for Gemini Vision
        onProgress?.call(0.35, 'Optimizing page ${safePageIndex + 1} of $totalPages for fast AI scan (35%)...');
        for (int i = document.pages.count - 1; i >= 0; i--) {
          if (i != safePageIndex) {
            document.pages.removeAt(i);
          }
        }
        bytesToScan = Uint8List.fromList(document.saveSync());
        document.dispose();
        debugPrint('Optimized single-page PDF size: ${(bytesToScan.length / 1024).toStringAsFixed(1)} KB (down from ${(bytes.length / 1024).toStringAsFixed(1)} KB)');
      } catch (e) {
        debugPrint('PDF page isolation note: $e');
      }
    }

    // 2. Scan the isolated page with Gemini Vision (Fast & lightweight)
    final savedKey = await getSavedApiKey();
    final effectiveApiKey = (geminiApiKey != null && geminiApiKey.trim().isNotEmpty)
        ? geminiApiKey.trim()
        : savedKey;

    if (effectiveApiKey.isNotEmpty) {
      try {
        onProgress?.call(0.60, 'AI Vision scanning measurement table (60%)...');
        debugPrint('Starting Gemini Vision parse with high-speed models on single page...');
        final parsed = await _parseWithGemini(bytesToScan, ext, effectiveApiKey, fallbackName);
        if (parsed != null) {
          onProgress?.call(0.95, 'Formatting 5-sample inspection sheet (95%)...');
          return parsed;
        }
      } catch (e) {
        debugPrint('Gemini parsing failed: $e');
        rethrow;
      }
    }

    // 3. Fallback if no digital text streams available
    if (ext == 'pdf') {
      throw ScannedPdfNeedsVisionException(
        'Scanned or vector-outlined PDF detected. This PDF does not contain digital text streams. Please upload the original digital tech pack PDF or Excel (.xlsx / .csv) sheet.',
      );
    } else {
      throw ScannedPdfNeedsVisionException(
        'Image files (PNG/JPG) do not contain digital text streams. Please upload the original digital tech pack PDF or Excel (.xlsx / .csv) sheet.',
      );
    }
  }

  /// Supported high-availability Gemini models in order of priority
  static const List<String> kGeminiVisionModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash',
    'gemini-3.1-flash-lite',
    'gemini-3.7-flash',
    'gemini-flash-lite-latest',
  ];

  /// Parse document using Google Gemini Vision API with automatic multi-model failover
  Future<GarmentSpecSheet?> _parseWithGemini(
    Uint8List bytes,
    String extension,
    String apiKey,
    String fallbackStyle,
  ) async {
    final mimeType = extension.toLowerCase() == 'pdf' ? 'application/pdf' : 'image/jpeg';
    final base64Data = base64Encode(bytes);

    const promptText = '''
You are an expert Garment Tech Pack and Measurement Specification Table parser.
Analyze this measurement specification document page carefully.

CRITICAL INSTRUCTIONS:
1. Examine ONLY the provided document. Extract the EXACT Style name/number, PO, Brand, Stage, Tolerance, Sizes, and POM measurements that appear in THIS document.
2. DO NOT invent, hallucinate, or output any dummy placeholder or sample values.
3. Extract EVERY size column present in the measurement chart (e.g. S, M, L, XL or numeric waist/length sizes like 30/30, 32/30, 34/30 or 28, 30, 32).
4. For each Point of Measure (POM) row, extract its actual code (or generate P1, P2 if no code column exists), description, and the exact fraction or decimal spec values for each size.
5. Return ONLY a valid JSON object (no markdown, no backticks):
{
  "style": "string (Style name or code extracted from document, or empty)",
  "po": "string (Purchase Order or empty)",
  "brand": "string (Brand or buyer name from document, or empty)",
  "stage": "string (Inspection stage if mentioned, else Initial Inspection)",
  "tolerance": 0.25,
  "sizes": ["size1", "size2", "size3"],
  "poms": [
    {
      "no": 1,
      "pomCode": "code from doc",
      "description": "description from doc",
      "variation": "",
      "sizeSpecs": {
        "size1": "spec value",
        "size2": "spec value"
      }
    }
  ]
}
''';

    final requestBody = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": promptText},
            {
              "inline_data": {
                "mime_type": mimeType,
                "data": base64Data,
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.1,
        "response_mime_type": "application/json"
      }
    });

    String lastErrorMessage = 'AI service temporarily unavailable. Please try again in a few moments.';

    int timeoutCount = 0;
    for (final modelName in kGeminiVisionModels) {
      if (timeoutCount >= 2) {
        throw Exception(
          'Network connection timed out. Please check your Wi-Fi or mobile data, or import an Excel (.xlsx / .csv) file for 100% offline scanning.',
        );
      }
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
      );

      try {
        debugPrint('Scanning with AI Vision model: $modelName...');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: requestBody,
        ).timeout(const Duration(seconds: 40));

        if (response.statusCode == 200) {
          debugPrint('AI Vision model $modelName completed successfully (200 OK)');
          final jsonResponse = jsonDecode(response.body);
          final candidate = jsonResponse['candidates']?[0];
          final content = candidate?['content'];
          List<dynamic> parts = [];
          if (content is Map && content['parts'] is List) {
            parts = content['parts'];
          } else if (content is List && content.isNotEmpty && content[0]['parts'] is List) {
            parts = content[0]['parts'];
          }

          String text = '';
          for (final p in parts) {
            if (p is Map && p.containsKey('text') && p['thought'] != true) {
              text += (p['text'] ?? '').toString();
            }
          }

          final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
          final cleanJson = match != null ? match.group(0)! : text;
          final data = jsonDecode(cleanJson);

          final sizes = List<String>.from(data['sizes'] ?? []);
          final rawPoms = data['poms'] as List<dynamic>? ?? [];
          final poms = rawPoms.map((p) {
            final map = Map<String, dynamic>.from(p);
            return SpecPomRow(
              no: (map['no'] as num?)?.toInt() ?? 0,
              pomCode: map['pomCode'] ?? '',
              description: map['description'] ?? '',
              variation: map['variation'] ?? '',
              sizeSpecs: Map<String, String>.from(map['sizeSpecs'] ?? {}),
            );
          }).toList();

          return GarmentSpecSheet(
            id: _uuid.v4(),
            style: data['style'] ?? fallbackStyle,
            po: data['po'] ?? '',
            brand: data['brand'] ?? '',
            stage: data['stage'] ?? 'Before Wash',
            date: DateTime.now(),
            tolerance: (data['tolerance'] as num?)?.toDouble() ?? 0.25,
            sizes: sizes,
            poms: poms,
          );
        } else if (response.statusCode == 503 || response.statusCode == 429 || response.statusCode == 404) {
          debugPrint('Model $modelName returned status ${response.statusCode}. Auto-failing over to next candidate model...');
          try {
            final errJson = jsonDecode(response.body);
            if (errJson is Map &&
                errJson['error'] is Map &&
                errJson['error']['message'] != null) {
              lastErrorMessage = errJson['error']['message'].toString();
            }
          } catch (_) {}
          continue; // Try next model in fallback list
        } else {
          // Other status (e.g. 400 Bad Request, 403 Invalid Key)
          try {
            final errJson = jsonDecode(response.body);
            if (errJson is Map &&
                errJson['error'] is Map &&
                errJson['error']['message'] != null) {
              lastErrorMessage = errJson['error']['message'].toString();
            }
          } catch (_) {
            if (response.body.isNotEmpty) {
              lastErrorMessage = response.body;
            }
          }
          throw Exception(lastErrorMessage);
        }
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('SocketException') ||
            errStr.contains('Failed host lookup') ||
            errStr.contains('No address associated with hostname') ||
            errStr.contains('Network is unreachable') ||
            errStr.contains('ClientException')) {
          throw Exception(
            'No internet connection detected. Please check your Wi-Fi or mobile data to scan PDFs with AI Vision, or import an Excel (.xlsx / .csv) file for 100% offline scanning.',
          );
        }
        if (errStr.contains('TimeoutException') ||
            errStr.contains('Future not completed') ||
            errStr.contains('timed out')) {
          timeoutCount++;
          debugPrint('Model $modelName timed out ($timeoutCount/2 timeout failures). Switching to fallback model...');
          lastErrorMessage = 'Processing timed out. The tech pack took longer than expected to process. Please retry or import an Excel (.xlsx / .csv) file for instant offline parsing.';
          continue;
        }
        if (errStr.contains('503') ||
            errStr.contains('429') ||
            errStr.contains('high demand') ||
            errStr.contains('UNAVAILABLE')) {
          debugPrint('Transient demand spike on $modelName ($errStr). Switching to fallback model...');
          continue;
        }
        rethrow;
      }
    }

    throw Exception(lastErrorMessage);
  }

  /// Returns the pre-loaded Wrangler Rustler Basic Jean dataset matching the provided PDF
  static GarmentSpecSheet getExampleWranglerSpecSheet() {
    final sizes = [
      '30/30',
      '30/32',
      '32/30',
      '32/32',
      '32/34',
      '34/30',
      '34/32',
      '34/34',
      '36/30',
      '36/32',
      '36/34',
    ];

    final poms = [
      SpecPomRow(
        no: 1,
        pomCode: 'WAST',
        description: 'Waist Relaxed',
        sizeSpecs: {
          '30/30': '32 1/4',
          '30/32': '32 1/4',
          '32/30': '34 3/8',
          '32/32': '34 3/8',
          '32/34': '34 3/8',
          '34/30': '36 1/2',
          '34/32': '36 1/2',
          '34/34': '36 1/2',
          '36/30': '38 1/2',
          '36/32': '38 1/2',
          '36/34': '38 1/2',
        },
      ),
      SpecPomRow(
        no: 2,
        pomCode: 'OTST',
        description: 'OUTSEAM',
        sizeSpecs: {
          '30/30': '41 1/8',
          '30/32': '44 5/8',
          '32/30': '42 7/8',
          '32/32': '45 1/8',
          '32/34': '47 3/8',
          '34/30': '43 3/8',
          '34/32': '45 5/8',
          '34/34': '47 7/8',
          '36/30': '43 7/8',
          '36/32': '46 1/8',
          '36/34': '48 3/8',
        },
      ),
      SpecPomRow(
        no: 3,
        pomCode: 'WOBH',
        description: 'Leg Bottom',
        sizeSpecs: {
          '30/30': '16 1/4',
          '30/32': '16 1/4',
          '32/30': '16 3/4',
          '32/32': '16 3/4',
          '32/34': '16 3/4',
          '34/30': '17 1/4',
          '34/32': '17 1/4',
          '34/34': '17 1/4',
          '36/30': '17 1/2',
          '36/32': '17 1/2',
          '36/34': '17 1/2',
        },
      ),
      SpecPomRow(
        no: 4,
        pomCode: 'SEAT',
        description: 'SEAT - STRAIGHT ACROSS',
        sizeSpecs: {
          '30/30': '41 1/8',
          '30/32': '41 1/8',
          '32/30': '43 1/4',
          '32/32': '43 1/4',
          '32/34': '43 1/4',
          '34/30': '45 1/4',
          '34/32': '45 1/4',
          '34/34': '45 1/4',
          '36/30': '47 3/8',
          '36/32': '47 3/8',
          '36/34': '47 3/8',
        },
      ),
      SpecPomRow(
        no: 5,
        pomCode: 'THIX',
        description: 'THIGH 1" DOWN FROM CROTCH',
        sizeSpecs: {
          '30/30': '23 3/4',
          '30/32': '23 3/4',
          '32/30': '25',
          '32/32': '25',
          '32/34': '25',
          '34/30': '26',
          '34/32': '26',
          '34/34': '26',
          '36/30': '27 1/4',
          '36/32': '27 1/4',
          '36/34': '27 1/4',
        },
      ),
      SpecPomRow(
        no: 6,
        pomCode: 'KNEE',
        description: 'KNEE @ MID POINT OF INSEAM',
        sizeSpecs: {
          '30/30': '18 1/8',
          '30/32': '18 1/8',
          '32/30': '18 7/8',
          '32/32': '18 7/8',
          '32/34': '18 7/8',
          '34/30': '19 3/8',
          '34/32': '19 3/8',
          '34/34': '19 3/8',
          '36/30': '19 7/8',
          '36/32': '19 7/8',
          '36/34': '19 7/8',
        },
      ),
      SpecPomRow(
        no: 7,
        pomCode: 'FTRS',
        description: 'FRONT RISE',
        sizeSpecs: {
          '30/30': '11 1/4',
          '30/32': '11 1/4',
          '32/30': '11 3/4',
          '32/32': '11 3/4',
          '32/34': '11 3/4',
          '34/30': '12',
          '34/32': '12 1/4',
          '34/34': '12 1/2',
          '36/30': '12 1/2',
          '36/32': '12 3/4',
          '36/34': '13',
        },
      ),
      SpecPomRow(
        no: 8,
        pomCode: 'BKRS',
        description: 'BACK RISE',
        sizeSpecs: {
          '30/30': '15',
          '30/32': '15 1/4',
          '32/30': '15 1/2',
          '32/32': '15 3/4',
          '32/34': '16',
          '34/30': '16',
          '34/32': '16 1/4',
          '34/34': '16 1/2',
          '36/30': '16 1/2',
          '36/32': '16 3/4',
          '36/34': '17',
        },
      ),
      SpecPomRow(
        no: 9,
        pomCode: 'INSM',
        description: 'INSEAM',
        sizeSpecs: {
          '30/30': '31',
          '30/32': '33',
          '32/30': '31',
          '32/32': '33',
          '32/34': '35',
          '34/30': '31',
          '34/32': '33',
          '34/34': '35',
          '36/30': '31',
          '36/32': '33',
          '36/34': '35',
        },
      ),
      SpecPomRow(
        no: 10,
        pomCode: 'FYSZ',
        description: 'ZIPPER LENGTH',
        sizeSpecs: {
          '30/30': '6',
          '30/32': '6 1/2',
          '32/30': '6 1/2',
          '32/32': '7',
          '32/34': '7',
          '34/30': '7',
          '34/32': '7 1/2',
          '34/34': '7 1/2',
          '36/30': '7 1/2',
          '36/32': '8',
          '36/34': '8',
        },
      ),
      SpecPomRow(
        no: 11,
        pomCode: 'LOOP',
        description: 'NUMBER OF LOOPS',
        sizeSpecs: {
          '30/30': '5',
          '30/32': '5',
          '32/30': '7',
          '32/32': '7',
          '32/34': '7',
          '34/30': '7',
          '34/32': '7',
          '34/34': '7',
          '36/30': '7',
          '36/32': '7',
          '36/34': '7',
        },
      ),
      SpecPomRow(
        no: 12,
        pomCode: 'WPKT',
        description: 'WHITE POCKET',
        sizeSpecs: {
          '30/30': '2',
          '30/32': '2',
          '32/30': '2',
          '32/32': '2',
          '32/34': '2',
          '34/30': '1',
          '34/32': '1',
          '34/34': '1',
          '36/30': '1',
          '36/32': '1',
          '36/34': '1',
        },
      ),
      SpecPomRow(
        no: 13,
        pomCode: 'FPTW',
        description: 'FRONT POCKET TOP WIDTH',
        sizeSpecs: {
          '30/30': '4 1/2',
          '30/32': '4 1/2',
          '32/30': '4 1/2',
          '32/32': '4 1/2',
          '32/34': '4 1/2',
          '34/30': '5',
          '34/32': '5',
          '34/34': '5',
          '36/30': '5',
          '36/32': '5',
          '36/34': '5',
        },
      ),
      SpecPomRow(
        no: 14,
        pomCode: 'FPSL',
        description: 'FRONT POCKET SIDE LENGTH',
        sizeSpecs: {
          '30/30': '4',
          '30/32': '4',
          '32/30': '4',
          '32/32': '4',
          '32/34': '4',
          '34/30': '4 1/4',
          '34/32': '4 1/4',
          '34/34': '4 1/4',
          '36/30': '4 1/4',
          '36/32': '4 1/4',
          '36/34': '4 1/4',
        },
      ),
    ];

    // Pre-populate handwritten sample measurements from the provided physical sheet image
    final sampleReadings = <String, SampleReading>{};
    void addReading(String pom, String size, int sample, double dev, String text) {
      final key = GarmentSpecSheet.cellKey(pom, size, sample);
      sampleReadings[key] = SampleReading(
        pomCode: pom,
        size: size,
        sampleIndex: sample,
        deviation: dev,
        deviationText: text,
        recordedAt: DateTime.now(),
      );
    }

    // Hand-written sample readings from the user's photo for 30/30:
    addReading('WAST', '30/30', 1, -0.5, '-1/2');
    addReading('WAST', '30/30', 2, 0.0, '0');
    addReading('WAST', '30/30', 3, -0.25, '-1/4');
    addReading('WAST', '30/30', 4, -0.25, '-1/4');
    addReading('WAST', '30/30', 5, 0.0, '0');

    addReading('SEAT', '30/30', 1, -0.5, '-1/2');
    addReading('SEAT', '30/30', 2, -0.5, '-1/2');
    addReading('SEAT', '30/30', 3, 0.0, '0');
    addReading('SEAT', '30/30', 4, -0.25, '-1/4');
    addReading('SEAT', '30/30', 5, 0.0, '0');

    addReading('THIX', '30/30', 1, -0.125, '-1/8');
    addReading('THIX', '30/30', 2, -0.375, '-3/8');
    addReading('THIX', '30/30', 3, 0.0, '0');
    addReading('THIX', '30/30', 4, 0.25, '+1/4');
    addReading('THIX', '30/30', 5, -0.125, '-1/8');

    addReading('FTRS', '30/30', 1, 0.0, '0');
    addReading('FTRS', '30/30', 2, 0.0, '0');
    addReading('FTRS', '30/30', 3, -0.125, '-1/8');
    addReading('FTRS', '30/30', 4, -0.125, '-1/8');

    addReading('BKRS', '30/30', 1, 0.0, '0');
    addReading('BKRS', '30/30', 2, 0.0, '0');
    addReading('BKRS', '30/30', 3, -0.25, '-1/4');
    addReading('BKRS', '30/30', 4, 0.0, '0');

    addReading('INSM', '30/30', 1, -0.125, '-1/8');
    addReading('INSM', '30/30', 2, -0.5, '-1/2');
    addReading('INSM', '30/30', 3, -0.25, '-1/4');
    addReading('INSM', '30/30', 4, 0.0, '0');

    return GarmentSpecSheet(
      id: 'spec_10E7621SW',
      style: '10E7621SW',
      po: 'PO-89201',
      brand: 'Wrangler',
      stage: 'Before Wash',
      date: DateTime.now(),
      tolerance: 0.25,
      sampleCountPerSize: 5,
      sizes: sizes,
      poms: poms,
      readings: sampleReadings,
    );
  }
}
