import 'package:uuid/uuid.dart';
import '../models/spec_sheet_model.dart';

class GarmentTableParser {
  static const Uuid _uuid = Uuid();

  /// Regex matching garment measurement values:
  /// e.g. "32 1/4", "44 5/8", "16 3/4", "23", "6 1/2", "0.5", "1/2"
  static final RegExp measurementRegex = RegExp(
    r'\b(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)\b',
  );

  /// Regex matching garment size labels:
  /// e.g. "30/30", "30/32", "[32/32]", "S", "M", "L", "XL", "28", "30", "32"
  static final RegExp sizeTokenRegex = RegExp(
    r'\[?(\d{1,2}/\d{1,2}|XXS|XS|S|M|L|XL|XXL|2XL|3XL|\b\d{2}\b)\]?',
    caseSensitive: false,
  );

  /// Parses raw extracted PDF text into a structured GarmentSpecSheet
  static GarmentSpecSheet parse(String rawText, {String fallbackStyle = 'Uploaded Spec'}) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String style = _extractStyle(lines) ?? fallbackStyle;
    String po = _extractPo(lines) ?? '';
    String brand = _extractBrand(lines) ?? '';
    String stage = _extractStage(lines) ?? 'Before Wash';

    // Parse tables: may contain one or multiple size blocks (e.g. 30/30-36/34 then 38/30-46/32)
    final allSizes = <String>[];
    final pomsMap = <String, SpecPomRow>{}; // key: pomCode or normalized description

    List<String> currentSizes = [];
    int pomCounter = 1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // If we have an active size block, check first if this line is a POM row
      if (currentSizes.isNotEmpty) {
        final parsedPom = _parsePomRow(line, currentSizes, pomCounter);
        if (parsedPom != null) {
          final pomKey = parsedPom.pomCode.isNotEmpty
              ? parsedPom.pomCode
              : parsedPom.description.toLowerCase();

          if (pomsMap.containsKey(pomKey)) {
            // Merge additional size specs (from subsequent tables/pages)
            final existing = pomsMap[pomKey]!;
            final mergedSpecs = Map<String, String>.from(existing.sizeSpecs);
            mergedSpecs.addAll(parsedPom.sizeSpecs);
            pomsMap[pomKey] = existing.copyWith(sizeSpecs: mergedSpecs);
          } else {
            pomsMap[pomKey] = parsedPom;
            pomCounter++;
          }
          continue;
        }
      }

      // Check if line is a Size Header line
      final detectedSizes = _detectSizeHeaderLine(line);
      if (detectedSizes.length >= 2) {
        currentSizes = detectedSizes;
        for (final s in currentSizes) {
          if (!allSizes.contains(s)) {
            allSizes.add(s);
          }
        }
        continue;
      }
    }

    // Only return poms if real sizes and real POM rows were matched
    final pomsList = pomsMap.values.toList();
    pomsList.sort((a, b) => a.no.compareTo(b.no));

    return GarmentSpecSheet(
      id: _uuid.v4(),
      style: style,
      po: po,
      brand: brand,
      stage: stage,
      date: DateTime.now(),
      tolerance: 0.25,
      sampleCountPerSize: 5,
      sizes: allSizes,
      poms: pomsList,
    );
  }

  /// Extracts Style name or code from document lines
  static String? _extractStyle(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(r'Style\s*[:#]?\s*([A-Za-z0-9\-_]+)', caseSensitive: false).firstMatch(line);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    // Search for alphanumeric style codes like 10E7621SW
    for (final line in lines.take(15)) {
      final match = RegExp(r'\b([0-9]{2}[A-Z0-9]{5,10}[A-Z]?)\b').firstMatch(line);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Extracts PO number from document lines
  static String? _extractPo(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(r'(?:PO|P\.O\.|Purchase Order)\s*[:#]?\s*([A-Za-z0-9\-_]+)', caseSensitive: false).firstMatch(line);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    return null;
  }

  /// Extracts Brand or Customer name
  static String? _extractBrand(List<String> lines) {
    const knownBrands = ['Wrangler', 'Lee', "Levi's", 'Levi', 'H&M', 'Zara', 'Gap', 'Old Navy', 'Target', 'Nike'];
    for (final line in lines.take(10)) {
      for (final b in knownBrands) {
        if (line.toLowerCase().contains(b.toLowerCase())) {
          return b;
        }
      }
    }
    return null;
  }

  /// Extracts Stage (Before Wash / Finished Product / After Wash)
  static String? _extractStage(List<String> lines) {
    for (final line in lines) {
      if (RegExp(r'Before\s*Wash', caseSensitive: false).hasMatch(line)) {
        return 'Before Wash';
      }
      if (RegExp(r'After\s*Wash', caseSensitive: false).hasMatch(line)) {
        return 'After Wash';
      }
      if (RegExp(r'Finished\s*Product', caseSensitive: false).hasMatch(line)) {
        return 'Finished Product';
      }
    }
    return null;
  }

  /// Detects if a line is a Size Header line, and returns the sizes
  static List<String> _detectSizeHeaderLine(String line) {
    // Exclude obvious non-header lines or lines containing fractional measurement specs
    final lower = line.toLowerCase();
    if (lower.contains('created by') ||
        lower.contains('page type') ||
        lower.contains('approved by') ||
        lower.contains('tech pack') ||
        lower.contains('1/2') ||
        lower.contains('1/4') ||
        lower.contains('3/4') ||
        lower.contains('3/8') ||
        lower.contains('5/8') ||
        lower.contains('7/8') ||
        lower.contains('1/8')) {
      return [];
    }

    final tokens = line.split(RegExp(r'\s+'));
    final sizes = <String>[];

    for (final token in tokens) {
      final clean = token.replaceAll(RegExp(r'[\[\]\(\):,\.]'), '').trim();
      if (_isSizeToken(clean)) {
        if (!sizes.contains(clean)) {
          sizes.add(clean);
        }
      }
    }

    return sizes;
  }

  static bool _isSizeToken(String raw) {
    final t = raw.toUpperCase();
    if (t.isEmpty) return false;

    // Reject non-size words
    const nonSizes = {
      'POM', 'CODE', 'NO', 'NO.', 'DESCRIPTION', 'DESC', 'TOL', 'TOLERANCE',
      'SPEC', 'SPECS', 'GRADE', 'SAMPLE', 'SMP', 'COMMENTS', 'MIN', 'MAX',
      'DIFF', 'NAME', 'TOTAL', 'QTY', 'QUANTITY', 'BUYER', 'BRAND', 'STYLE',
      'COLOR', 'SEASON', 'DATE', 'PAGE', 'OF', 'INCH', 'INCHES', 'CM', 'MM',
      'ITEM', 'FIT', 'FABRIC', 'WASH', 'STATUS', 'VERSION', 'POINT'
    };
    if (nonSizes.contains(t)) return false;

    // Waist/Inseam combinations: 30/30, 32x30, 34-32, 30X30, 32/34
    if (RegExp(r'^\d{2}[/xX\-]\d{2}$').hasMatch(t)) return true;

    // Standard Alpha sizes: XXS, XS, S, M, L, XL, XXL, 1X..5X, 1XL..5XL, 2XL..5XL
    if (RegExp(r'^(XXS|XS|S|M|L|XL|XXL|[1-5]XL|[1-5]X)$').hasMatch(t)) return true;

    // Dual sizes: XS/S, S/M, M/L, L/XL
    if (RegExp(r'^(XS/S|S/M|M/L|L/XL|XL/XXL|XL/2XL)$').hasMatch(t)) return true;

    // Children / Toddler sizes: 2T, 3T, 4T, 5T, 4R, 6R, 8R, 10R
    if (RegExp(r'^\d{1,2}[TR]$').hasMatch(t)) return true;

    // Numeric sizes: waist sizes 24 to 56, or women's even sizes 0 to 22
    final n = int.tryParse(t);
    if (n != null) {
      if ((n >= 24 && n <= 56) || (n >= 0 && n <= 22 && n % 2 == 0)) {
        return true;
      }
    }

    return false;
  }

  /// Parses a single POM row given the current active sizes
  static SpecPomRow? _parsePomRow(String line, List<String> currentSizes, int currentNo) {
    // Exclude metadata/header rows
    final upper = line.toUpperCase();
    if (upper.contains('QA INSPECTION') ||
        upper.contains('APPROVED BY') ||
        upper.contains('COMMENTS') ||
        upper.contains('BUYER:') ||
        upper.contains('STYLE:')) {
      return null;
    }

    // Must contain measurements
    final matches = measurementRegex.allMatches(line).toList();
    if (matches.isEmpty) return null;

    // Filter matches that are from the measurement values (right side)
    // Take up to currentSizes.length values from the end
    final values = <String>[];
    int firstMeasurementIndex = line.length;

    for (int k = matches.length - 1; k >= 0 && values.length < currentSizes.length; k--) {
      final m = matches[k];
      values.insert(0, m.group(0)!.trim());
      firstMeasurementIndex = m.start;
    }

    if (values.isEmpty) return null;

    // The text before the measurements contains row number, POM code, and description
    final leftPart = line.substring(0, firstMeasurementIndex).trim();
    if (leftPart.isEmpty) return null;

    final parts = leftPart.split(RegExp(r'\s+'));
    int no = currentNo;
    int codeIndex = 0;

    // If first token is a row number
    if (parts.isNotEmpty && int.tryParse(parts[0]) != null) {
      no = int.parse(parts[0]);
      codeIndex = 1;
    }

    String pomCode = '';
    String description = '';

    if (codeIndex < parts.length) {
      final candidateCode = parts[codeIndex];
      // Codes are usually 2 to 6 alphanumeric characters (e.g. WAST, OTST, SEAT, FTRS, B1, P1)
      if (RegExp(r'^[A-Z0-9]{2,6}$').hasMatch(candidateCode) && candidateCode != 'TOL' && candidateCode != 'SPEC') {
        pomCode = candidateCode;
        description = parts.skip(codeIndex + 1).join(' ').trim();
      } else {
        pomCode = 'P$no';
        description = parts.skip(codeIndex).join(' ').trim();
      }
    }

    if (description.isEmpty) {
      description = pomCode;
    }

    // Clean description: strip trailing tolerance like "+/- 1/4" or "1/4"
    description = description.replaceAll(RegExp(r'[\+\/\-]+\s*\d*(?:\s*\d+/\d+|\.\d+)?$'), '').trim();

    // Map extracted values to sizes
    final sizeSpecs = <String, String>{};
    for (int i = 0; i < values.length && i < currentSizes.length; i++) {
      sizeSpecs[currentSizes[i]] = values[i];
    }

    return SpecPomRow(
      no: no,
      pomCode: pomCode,
      description: description,
      sizeSpecs: sizeSpecs,
    );
  }
}
