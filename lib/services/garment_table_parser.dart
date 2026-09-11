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
    // 1. Check for stream-formatted tech pack tables (Wrangler / Kontoor / Gerber PLM)
    if (rawText.contains(RegExp(r'Description\|Variation', caseSensitive: false)) ||
        (rawText.contains('WAST 1') && (rawText.contains('INSM') || rawText.contains('OTST')))) {
      final streamSheet = _parseStreamTechPack(rawText, fallbackStyle: fallbackStyle);
      if (streamSheet != null && streamSheet.sizes.length >= 2 && streamSheet.poms.length >= 2) {
        return streamSheet;
      }
    }

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
    final trimmed = line.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('created by') ||
        lower.startsWith('page type') ||
        lower.startsWith('approved by') ||
        lower.startsWith('qa inspection') ||
        lower.startsWith('comments') ||
        lower.startsWith('buyer:') ||
        lower.startsWith('style:')) {
      return [];
    }

    // A size header line NEVER has mixed fraction measurements like "29 1/2" or "41 1/8"
    if (RegExp(r'\d+\s+(?:[1-9]|1[0-5])/(?:16|32|[248])\b').hasMatch(trimmed)) {
      return [];
    }

    // A size header line NEVER starts with a row number and POM code like "1 WAST" or "2 SEAT"
    if (RegExp(r'^\d+\s+[A-Z]{2,6}\b').hasMatch(trimmed)) {
      return [];
    }

    // Split on whitespace, pipes, tabs, commas, semicolons
    final tokens = trimmed.split(RegExp(r'[\s\|\t,;]+'));
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
    final t = raw.toUpperCase().trim();
    if (t.isEmpty) return false;

    // Reject non-size words and common header labels
    const nonSizes = {
      'POM', 'CODE', 'NO', 'NO.', 'DESCRIPTION', 'DESC', 'TOL', 'TOLERANCE',
      'SPEC', 'SPECS', 'GRADE', 'SAMPLE', 'SMP', 'COMMENTS', 'MIN', 'MAX',
      'DIFF', 'NAME', 'TOTAL', 'QTY', 'QUANTITY', 'BUYER', 'BRAND', 'STYLE',
      'COLOR', 'SEASON', 'DATE', 'PAGE', 'OF', 'INCH', 'INCHES', 'CM', 'MM',
      'ITEM', 'FIT', 'FABRIC', 'WASH', 'STATUS', 'VERSION', 'POINT', 'SIZE', 'SIZES',
      'RANGE', 'CRITICAL', 'METHOD', 'REMARKS', 'NOTES', 'STAGE'
    };
    if (nonSizes.contains(t)) return false;

    // Fractions like 1/2, 1/4, 3/8, 5/8 are tolerance/measurements, not sizes
    // (Apparel fraction denominators are 2, 4, 8, 16, 32 with numerators < 16)
    if (RegExp(r'^(?:[1-9]|1[0-5])/(?:16|32|[248])$').hasMatch(t)) return false;

    // Waist/Inseam combinations: 30/30, 32x30, 34-32, 30X30, 32/34
    if (RegExp(r'^\d{2}[/xX\-]\d{2}$').hasMatch(t)) return true;

    // Standard Alpha sizes: XXS, XS, S, M, L, XL, XXL, 1X..5X, 1XL..6XL, 2XL..6XL
    if (RegExp(r'^(XXS|XS|S|M|L|XL|XXL|[1-6]XL|[1-6]X)$').hasMatch(t)) return true;

    // Dual sizes: XS/S, S/M, M/L, L/XL, XL/XXL
    if (RegExp(r'^(XS/S|S/M|M/L|L/XL|XL/XXL|XL/2XL)$').hasMatch(t)) return true;

    // Sizes with fit/length suffix: 30W, 32W, 30L, 32L, 30R, 32R, 30S, 32S
    if (RegExp(r'^\d{2}[WRLST]$').hasMatch(t)) return true;

    // Children / Toddler sizes: 2T, 3T, 4T, 5T, 4R, 6R, 8R, 10R
    if (RegExp(r'^\d{1,2}[TR]$').hasMatch(t)) return true;

    // Numeric sizes: 0, 00, 2..22 (women's), or 20..60 (men's waist/unisex), or 92..176 (EUR heights)
    if (t == '0' || t == '00') return true;
    final n = int.tryParse(t);
    if (n != null) {
      if ((n >= 2 && n <= 22 && n % 2 == 0) || (n >= 20 && n <= 60) || (n >= 92 && n <= 176 && n % 6 == 2)) {
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

  /// Specialized parser for Wrangler / Kontoor / Gerber PLM stream-extracted PDF tables
  static GarmentSpecSheet? _parseStreamTechPack(String raw, {String fallbackStyle = 'Uploaded Spec'}) {
    try {
      final headerRegex = RegExp(r'Description\|Variation', caseSensitive: false);
      final headerMatches = headerRegex.allMatches(raw).toList();
      if (headerMatches.isEmpty && !raw.contains('WAST 1')) return null;

      final allSizes = <String>[];
      final pomsMap = <String, SpecPomRow>{};
      List<String> knownPomCodes = [];

      // If no Description|Variation marker, treat the whole text as 1 section
      final sections = <String>[];
      if (headerMatches.isNotEmpty) {
        for (int t = 0; t < headerMatches.length; t++) {
          final start = headerMatches[t].end;
          final end = (t + 1 < headerMatches.length) ? headerMatches[t + 1].start : raw.length;
          sections.add(raw.substring(start, end));
        }
      } else {
        sections.add(raw);
      }

      final sizeRegex = RegExp(r'\[?(\d{1,2}/\d{1,2}|XXS|XS|S|M|L|XL|XXL|[1-5]XL|\b\d{2}\b)\]?', caseSensitive: false);

      for (final section in sections) {
        // 1. Extract sizes immediately at the start of section
        final sizes = <String>[];
        int scanCursor = 0;
        while (scanCursor < section.length) {
          final m = sizeRegex.matchAsPrefix(section, scanCursor);
          if (m != null && m.group(1) != null) {
            final s = m.group(1)!.trim();
            sizes.add(s);
            scanCursor = m.end;
          } else {
            break;
          }
        }

        if (sizes.isEmpty) continue;

        for (final s in sizes) {
          if (!allSizes.contains(s)) {
            allSizes.add(s);
          }
        }

        final pomStream = section.substring(scanCursor);

        // 2. Find POM markers with sequential row numbers 1, 2, 3...
        int nextRowNo = 1;
        int searchCursor = 0;

        while (searchCursor < pomStream.length) {
          RegExp directRegex;
          if (knownPomCodes.length >= nextRowNo) {
            final code = knownPomCodes[nextRowNo - 1];
            directRegex = RegExp('($code)\\s+($nextRowNo)');
          } else {
            directRegex = RegExp('([A-Z]{3,6})\\s+($nextRowNo)');
          }

          final m = directRegex.allMatches(pomStream.substring(searchCursor)).firstOrNull;
          if (m == null) break;

          final actualStart = searchCursor + m.start;
          final actualEnd = searchCursor + m.end;
          final pomCode = m.group(1)!;

          final rowContent = pomStream.substring(searchCursor, actualStart).trim();
          searchCursor = actualEnd;
          final rowNo = nextRowNo;
          nextRowNo++;

          final descRegex = RegExp(r'([A-Za-z][A-Za-z0-9\s\-–"@]+[A-Za-z])');
          final descMatch = descRegex.firstMatch(rowContent);
          if (descMatch == null) continue;

          final description = descMatch.group(1)!.trim();
          final prefix = rowContent.substring(0, descMatch.start).trim();
          final suffix = rowContent.substring(descMatch.end).trim();

          int suffixCount = 0;
          if (suffix.isNotEmpty) {
            if (suffix.length % 2 == 0 && suffix.length ~/ 2 <= sizes.length) {
              suffixCount = suffix.length ~/ 2;
            } else {
              final fracCount = RegExp(r'/(16|32|[248])').allMatches(suffix).length;
              suffixCount = fracCount > 0 ? fracCount : 3;
            }
            if (suffixCount >= sizes.length) suffixCount = sizes.length ~/ 2;
          }

          final prefixCount = sizes.length - suffixCount;
          final prefixVals = _parseFusedMeasurements(prefix, prefixCount);
          final suffixVals = suffix.isNotEmpty ? _parseFusedMeasurements(suffix, suffixCount) : <String>[];
          final allVals = [...prefixVals, ...suffixVals];

          final specs = <String, String>{};
          for (int si = 0; si < sizes.length && si < allVals.length; si++) {
            specs[sizes[si]] = allVals[si];
          }

          if (pomsMap.containsKey(pomCode)) {
            final existing = pomsMap[pomCode]!;
            final mergedSpecs = Map<String, String>.from(existing.sizeSpecs)..addAll(specs);
            pomsMap[pomCode] = existing.copyWith(sizeSpecs: mergedSpecs);
          } else {
            pomsMap[pomCode] = SpecPomRow(
              no: rowNo,
              pomCode: pomCode,
              description: description,
              sizeSpecs: specs,
            );
          }
        }

        if (knownPomCodes.isEmpty && pomsMap.isNotEmpty) {
          final sorted = pomsMap.values.toList()..sort((a, b) => a.no.compareTo(b.no));
          knownPomCodes = sorted.map((p) => p.pomCode).toList();
        }
      }

      if (allSizes.isEmpty || pomsMap.isEmpty) return null;

      // Extract style name / PO
      String style = fallbackStyle;
      final styleMatch = RegExp(r'\b([0-9]{2}[A-Z0-9]{5,15}[A-Z]?)\b').firstMatch(raw);
      if (styleMatch != null && styleMatch.group(1) != null) {
        style = styleMatch.group(1)!;
      } else {
        final perMatch = RegExp(r'PER\s+(\d{4,8})', caseSensitive: false).firstMatch(raw);
        if (perMatch != null && perMatch.group(1) != null) {
          style = 'Style ${perMatch.group(1)}';
        }
      }

      String brand = 'Wrangler';
      final lowerRaw = raw.toLowerCase();
      if (lowerRaw.contains('rustler')) {
        brand = 'Rustler';
      } else if (lowerRaw.contains('lee')) {
        brand = 'Lee';
      }

      String stage = 'Before Wash';
      if (lowerRaw.contains('after wash')) {
        stage = 'After Wash';
      } else if (lowerRaw.contains('finished product')) {
        stage = 'Finished Product';
      }

      final pomsList = pomsMap.values.toList()..sort((a, b) => a.no.compareTo(b.no));

      return GarmentSpecSheet(
        id: _uuid.v4(),
        style: style,
        po: '',
        brand: brand,
        stage: stage,
        date: DateTime.now(),
        tolerance: 0.25,
        sampleCountPerSize: 5,
        sizes: allSizes,
        poms: pomsList,
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> _parseFusedMeasurements(String raw, int expectedCount) {
    final clean = raw.trim();
    if (clean.isEmpty || expectedCount <= 0) return [];

    final fracRegex = RegExp(r'\s+([1-9]|1[0-5])/(16|32|[248])');
    final matches = fracRegex.allMatches(clean).toList();

    if (matches.isEmpty) {
      if (clean.length % expectedCount == 0) {
        final chunkLen = clean.length ~/ expectedCount;
        final results = <String>[];
        for (int i = 0; i < clean.length; i += chunkLen) {
          results.add(clean.substring(i, i + chunkLen));
        }
        return results;
      }
      return clean.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    }

    final results = <String>[];
    int cursor = 0;

    for (int i = 0; i < matches.length; i++) {
      final m = matches[i];
      final fracText = m.group(0)!.trim();

      int runStart = m.start - 1;
      while (runStart >= cursor && clean[runStart] != ' ' && int.tryParse(clean[runStart]) != null) {
        runStart--;
      }
      runStart++;
      final runDigits = clean.substring(runStart, m.start);

      int wholeNumDigits = 2;
      if (runDigits.length == 1) {
        wholeNumDigits = 1;
      } else if (runDigits.length >= 2) {
        final twoDigits = int.tryParse(runDigits.substring(runDigits.length - 2)) ?? 0;
        if (twoDigits < 10 || twoDigits > 65) {
          wholeNumDigits = 1;
        } else {
          wholeNumDigits = 2;
        }
      } else {
        wholeNumDigits = 0;
      }

      final intStart = m.start - wholeNumDigits;

      if (intStart > cursor) {
        final prefix = clean.substring(cursor, intStart).trim();
        if (prefix.isNotEmpty) {
          results.addAll(_splitIntegerChunk(prefix));
        }
      }

      final wholeNum = clean.substring(intStart, m.start).trim();
      if (wholeNum.isNotEmpty) {
        results.add('$wholeNum $fracText');
      } else {
        results.add(fracText);
      }

      cursor = m.end;
    }

    if (cursor < clean.length) {
      final tail = clean.substring(cursor).trim();
      if (tail.isNotEmpty) {
        results.addAll(_splitIntegerChunk(tail));
      }
    }

    return results;
  }

  static List<String> _splitIntegerChunk(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return [];

    final parts = clean.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.length > 1) return parts;

    if (clean.length >= 4 && clean.length % 2 == 0) {
      final list = <String>[];
      for (int i = 0; i < clean.length; i += 2) {
        list.add(clean.substring(i, i + 2));
      }
      return list;
    }

    if (clean.length == 2) {
      final val = int.tryParse(clean) ?? 0;
      if (val > 65 || val < 10) {
        return [clean.substring(0, 1), clean.substring(1, 2)];
      }
      return [clean];
    }

    return [clean];
  }
}
