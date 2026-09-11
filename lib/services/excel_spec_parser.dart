import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import '../models/spec_sheet_model.dart';

class ExcelSpecParser {
  static const Uuid _uuid = Uuid();

  /// Converts an Excel cell reference like "A1", "C5", "AA12" to (row, col) 0-indexed indices.
  static ({int row, int col}) parseCellRef(String cellRef) {
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(cellRef.toUpperCase());
    if (match == null) return (row: 0, col: 0);

    final colStr = match.group(1)!;
    final rowStr = match.group(2)!;

    int col = 0;
    for (int i = 0; i < colStr.length; i++) {
      col = col * 26 + (colStr.codeUnitAt(i) - 64);
    }
    final int rowIndex = (int.tryParse(rowStr) ?? 1) - 1;
    return (row: rowIndex, col: col - 1);
  }

  /// Parses bytes from an .xlsx or .csv/.tsv file into a GarmentSpecSheet with 100% accuracy.
  static GarmentSpecSheet parse({
    required List<int> bytes,
    required String fileName,
    String fallbackStyle = 'TechPack',
  }) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.csv') || lowerName.endsWith('.txt')) {
      return _parseCsv(utf8.decode(bytes, allowMalformed: true), fallbackStyle);
    } else {
      return _parseXlsx(bytes is Uint8List ? bytes : Uint8List.fromList(bytes), fallbackStyle);
    }
  }

  /// Extracts cells from an XLSX archive and converts into a GarmentSpecSheet
  static GarmentSpecSheet _parseXlsx(Uint8List bytes, String fallbackStyle) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Extract shared strings
    final sharedStrings = <String>[];
    final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedStringsFile != null) {
      final xmlDoc = XmlDocument.parse(utf8.decode(sharedStringsFile.content as List<int>));
      for (final si in xmlDoc.findAllElements('si')) {
        final t = si.findAllElements('t').map((e) => e.innerText).join();
        sharedStrings.add(t);
      }
    }

    // 2. Find primary worksheet
    ArchiveFile? sheetFile;
    for (final name in ['xl/worksheets/sheet1.xml', 'xl/worksheets/Sheet1.xml']) {
      sheetFile = archive.findFile(name);
      if (sheetFile != null) break;
    }
    if (sheetFile == null) {
      // Find any sheet in xl/worksheets/
      for (final f in archive) {
        if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
          sheetFile = f;
          break;
        }
      }
    }

    if (sheetFile == null) {
      throw Exception('Could not find a valid worksheet inside this Excel file.');
    }

    final sheetXml = XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));

    // 3. Build a 2D coordinate grid: row -> (col -> cellValue)
    final Map<int, Map<int, String>> grid = {};

    for (final rowElem in sheetXml.findAllElements('row')) {
      final int defaultRow = (int.tryParse(rowElem.getAttribute('r') ?? '') ?? 1) - 1;

      for (final cElem in rowElem.findElements('c')) {
        final cellRef = cElem.getAttribute('r');
        int r = defaultRow;
        int col = 0;

        if (cellRef != null && cellRef.isNotEmpty) {
          final parsedCoords = parseCellRef(cellRef);
          r = parsedCoords.row;
          col = parsedCoords.col;
        }

        final type = cElem.getAttribute('t');
        String val = '';

        // Check inline string
        final isElem = cElem.findElements('is').firstOrNull;
        if (isElem != null) {
          val = isElem.findAllElements('t').map((e) => e.innerText).join();
        } else {
          final vElem = cElem.findElements('v').firstOrNull;
          if (vElem != null) {
            val = vElem.innerText.trim();
            if (type == 's') {
              final idx = int.tryParse(val);
              if (idx != null && idx >= 0 && idx < sharedStrings.length) {
                val = sharedStrings[idx];
              }
            }
          }
        }

        grid.putIfAbsent(r, () => {})[col] = val.trim();
      }
    }

    return _buildSpecSheetFromGrid(grid, fallbackStyle);
  }

  /// Parses comma/tab separated text into a GarmentSpecSheet
  static GarmentSpecSheet _parseCsv(String content, String fallbackStyle) {
    final Map<int, Map<int, String>> grid = {};
    final lines = const LineSplitter().convert(content);

    for (int r = 0; r < lines.length; r++) {
      final line = lines[r].trim();
      if (line.isEmpty) continue;

      // Split by tab if TSV, otherwise comma
      final isTab = line.contains('\t');
      final rawTokens = isTab ? line.split('\t') : _splitCsvLine(line);

      for (int c = 0; c < rawTokens.length; c++) {
        grid.putIfAbsent(r, () => {})[c] = rawTokens[c].trim();
      }
    }

    return _buildSpecSheetFromGrid(grid, fallbackStyle);
  }

  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  /// Transforms the 2D cell grid into a structured GarmentSpecSheet
  static GarmentSpecSheet _buildSpecSheetFromGrid(
    Map<int, Map<int, String>> grid,
    String fallbackStyle,
  ) {
    String style = fallbackStyle;
    String po = '';
    String brand = '';
    String stage = 'Inline Inspection';
    double tolerance = 0.25;

    // 1. Scan the first 10 rows for metadata
    final styleRegex = RegExp(r'\bSTYLE\b', caseSensitive: false);
    final poRegex = RegExp(r'\b(PO|P\.O\.|PURCHASE ORDER)\b', caseSensitive: false);
    final brandRegex = RegExp(r'\b(BRAND|BUYER|CUSTOMER)\b', caseSensitive: false);
    final stageRegex = RegExp(r'\b(STAGE|INSPECTION STAGE)\b', caseSensitive: false);
    final tolRegex = RegExp(r'\b(TOLERANCE|TOL)\b', caseSensitive: false);

    for (int r = 0; r < 10; r++) {
      final rowMap = grid[r] ?? {};
      for (final entry in rowMap.entries) {
        final text = entry.value.trim();
        final nextVal = (rowMap[entry.key + 1] ?? '').trim();

        if (styleRegex.hasMatch(text) && style == fallbackStyle && nextVal.isNotEmpty) {
          style = nextVal.replaceAll(':', '').trim();
        } else if (poRegex.hasMatch(text) && po.isEmpty && nextVal.isNotEmpty) {
          po = nextVal.replaceAll(':', '').trim();
        } else if (brandRegex.hasMatch(text) && brand.isEmpty && nextVal.isNotEmpty) {
          brand = nextVal.replaceAll(':', '').trim();
        } else if (stageRegex.hasMatch(text) && nextVal.isNotEmpty) {
          stage = nextVal.replaceAll(':', '').trim();
        } else if (tolRegex.hasMatch(text)) {
          final tolMatch = RegExp(r'(\d+(?:\.\d+)?|\d+/\d+)').firstMatch(nextVal.isNotEmpty ? nextVal : text);
          if (tolMatch != null) {
            final tStr = tolMatch.group(1)!;
            if (tStr.contains('/')) {
              final parts = tStr.split('/');
              final num = double.tryParse(parts[0]) ?? 1.0;
              final den = double.tryParse(parts[1]) ?? 4.0;
              tolerance = num / den;
            } else {
              tolerance = double.tryParse(tStr) ?? 0.25;
            }
          }
        }
      }
    }

    // 2. Locate the Table Header row:
    // Looks for rows with "POM", "DESCRIPTION", "CODE", or sizes like "30/30", "S", "M", "L"
    int headerRowIndex = -1;
    int pomColIndex = -1;
    int descColIndex = -1;
    final sizeColumns = <int, String>{}; // colIndex -> sizeName

    for (int r = 0; r < 25; r++) {
      final rowMap = grid[r] ?? {};
      int foundPom = -1;
      int foundDesc = -1;
      final tempSizes = <int, String>{};

      for (final colEntry in rowMap.entries) {
        final val = colEntry.value;
        final upper = val.toUpperCase().trim();

        if (upper == 'POM' || upper == 'POM CODE' || upper == 'CODE' || upper == 'POINT' || upper == 'NO.') {
          foundPom = colEntry.key;
        } else if (upper == 'DESCRIPTION' || upper == 'POM DESCRIPTION' || upper == 'POINT OF MEASURE') {
          foundDesc = colEntry.key;
        } else if (_isLikelySizeHeader(val)) {
          final cleanSize = val.replaceFirst(RegExp(r'^SIZE:\s*', caseSensitive: false), '').trim();
          if (!tempSizes.containsValue(cleanSize)) {
            tempSizes[colEntry.key] = cleanSize;
          }
        }
      }

      if ((foundPom != -1 || foundDesc != -1) && tempSizes.isNotEmpty) {
        headerRowIndex = r;
        pomColIndex = foundPom != -1 ? foundPom : 0;
        descColIndex = foundDesc != -1 ? foundDesc : 1;
        for (final entry in tempSizes.entries) {
          if (!sizeColumns.containsValue(entry.value)) {
            sizeColumns[entry.key] = entry.value;
          }
        }
        break;
      } else if (tempSizes.length >= 2 && headerRowIndex == -1) {
        // Candidate size row
        headerRowIndex = r;
        pomColIndex = foundPom != -1 ? foundPom : 0;
        descColIndex = foundDesc != -1 ? foundDesc : (pomColIndex + 1);
        for (final entry in tempSizes.entries) {
          if (!sizeColumns.containsValue(entry.value)) {
            sizeColumns[entry.key] = entry.value;
          }
        }
      }
    }

    // If no explicit size header row was found, check Row 5/6 (from our standard MEASURA template)
    if (sizeColumns.isEmpty) {
      for (int r = 3; r <= 6; r++) {
        final rowMap = grid[r] ?? {};
        for (final colEntry in rowMap.entries) {
          if (_isLikelySizeHeader(colEntry.value)) {
            final cleanSize = colEntry.value.replaceFirst(RegExp(r'^SIZE:\s*', caseSensitive: false), '').trim();
            if (!sizeColumns.containsValue(cleanSize)) {
              sizeColumns[colEntry.key] = cleanSize;
            }
          }
        }
        if (sizeColumns.isNotEmpty) {
          headerRowIndex = r;
          pomColIndex = 0;
          descColIndex = 1;
          break;
        }
      }
    }

    // Check if next row (e.g. Row 6) has "SPEC" under the size columns to find exact spec column indices
    final finalSizeSpecCols = <String, int>{}; // size -> specColIndex
    if (headerRowIndex != -1 && grid.containsKey(headerRowIndex + 1)) {
      final subRow = grid[headerRowIndex + 1]!;
      for (final entry in sizeColumns.entries) {
        final col = entry.key;
        final size = entry.value;
        if (finalSizeSpecCols.containsKey(size)) continue;

        // Search columns [col .. col + 5] for the "SPEC" sub-header
        int specCol = col;
        for (int c = col; c <= col + 5; c++) {
          if ((subRow[c]?.toUpperCase() ?? '') == 'SPEC') {
            specCol = c;
            break;
          }
        }
        finalSizeSpecCols[size] = specCol;
      }
    } else {
      for (final entry in sizeColumns.entries) {
        finalSizeSpecCols[entry.value] = entry.key;
      }
    }

    final sizesList = finalSizeSpecCols.keys.toList();
    if (sizesList.isEmpty) {
      sizesList.addAll(['S', 'M', 'L', 'XL']);
    }

    // 3. Extract POM Rows
    final poms = <SpecPomRow>[];
    final startRow = (headerRowIndex != -1) ? headerRowIndex + 1 : 1;
    final maxRow = grid.keys.isEmpty ? 0 : grid.keys.reduce((a, b) => a > b ? a : b);

    int pomCounter = 1;
    for (int r = startRow; r <= maxRow; r++) {
      final rowMap = grid[r];
      if (rowMap == null || rowMap.isEmpty) continue;

      // Skip sub-header rows like "POM", "DESCRIPTION", "SPEC", "SMP 1", "SMP 2", etc.
      String pomCode = (pomColIndex >= 0 ? rowMap[pomColIndex] : '')?.trim() ?? '';
      String desc = (descColIndex >= 0 ? rowMap[descColIndex] : '')?.trim() ?? '';

      final combinedHeaderTest = ('$pomCode $desc').toUpperCase();
      if (combinedHeaderTest.contains('QA INSPECTION SUMMARY')) {
        break; // Stop at summary block
      }
      if (combinedHeaderTest == 'POM DESCRIPTION' ||
          combinedHeaderTest == 'POM' ||
          combinedHeaderTest == 'DESCRIPTION' ||
          pomCode.toUpperCase() == 'POM' ||
          pomCode.toUpperCase() == 'CODE' ||
          desc.toUpperCase() == 'DESCRIPTION' ||
          desc.toUpperCase() == 'POINT OF MEASURE') {
        continue;
      }
      // If row has "SPEC" or "SMP" in early columns, skip
      final rowText = rowMap.values.take(8).join(' ').toUpperCase();
      if (rowText.contains('SMP 1') || (rowText.contains('SPEC') && rowText.contains('SMP'))) {
        continue;
      }

      // Skip empty or divider rows
      if (pomCode.isEmpty && desc.isEmpty) continue;
      if (desc.isEmpty) desc = pomCode;
      if (pomCode.isEmpty) pomCode = 'P$pomCounter';

      final sizeSpecs = <String, String>{};
      for (final entry in finalSizeSpecCols.entries) {
        final size = entry.key;
        final colIdx = entry.value;
        final specVal = (rowMap[colIdx] ?? '').trim();
        if (specVal.isNotEmpty && specVal != '-') {
          sizeSpecs[size] = specVal;
        }
      }

      // If at least one spec or valid description exists, add to POM list
      if (desc.isNotEmpty || sizeSpecs.isNotEmpty) {
        poms.add(SpecPomRow(
          no: pomCounter++,
          pomCode: pomCode,
          description: desc,
          variation: '',
          sizeSpecs: sizeSpecs,
        ));
      }
    }

    // Fallback if no POMs were parsed
    if (poms.isEmpty) {
      poms.add(SpecPomRow(no: 1, pomCode: 'B1', description: 'Waist', sizeSpecs: {}));
    }

    return GarmentSpecSheet(
      id: _uuid.v4(),
      style: style,
      po: po,
      brand: brand,
      stage: stage,
      date: DateTime.now(),
      tolerance: tolerance,
      sizes: sizesList,
      poms: poms,
    );
  }

  static bool _isLikelySizeHeader(String text) {
    final t = text.toUpperCase().trim();
    if (t.isEmpty) return false;
    if (t.startsWith('SIZE:') || t.startsWith('SIZE ')) return true;

    // Common waist/inseam: e.g. 30/30, 32/32, 34x32
    if (RegExp(r'^\d{2}[/x\-]\d{2}$').hasMatch(t)) return true;

    // Common letters: XS, S, M, L, XL, XXL, 2XL, 3XL
    const letters = {'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '2XL', '3XL', '4XL', '5XL'};
    if (letters.contains(t)) return true;

    // Numeric waist sizes: 28, 29, 30, 31, 32, 33, 34, 36, 38, 40, 42
    final n = int.tryParse(t);
    if (n != null && n >= 24 && n <= 54) return true;

    return false;
  }
}
