import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:garment_measurement_app/models/spec_sheet_model.dart';
import 'package:garment_measurement_app/services/excel_export_service.dart';
import 'package:garment_measurement_app/services/excel_spec_parser.dart';

void main() {
  test('Test parsing sharedStrings and worksheet xml', () async {
    final spec = GarmentSpecSheet(
      id: 'spec_1',
      date: DateTime.now(),
      style: 'WRANGLER-TEST',
      po: 'PO-9911',
      brand: 'Wrangler',
      stage: 'Inline',
      tolerance: 0.25,
      sizes: ['30/30', '32/30', '34/30'],
      poms: [
        SpecPomRow(
          no: 1,
          pomCode: 'B1',
          description: 'WAIST RELAXED',
          sizeSpecs: {'30/30': '15 1/2', '32/30': '16 1/2', '34/30': '17 1/2'},
        ),
        SpecPomRow(
          no: 2,
          pomCode: 'B2',
          description: 'HIP MEASUREMENT',
          sizeSpecs: {'30/30': '20', '32/30': '21', '34/30': '22'},
        ),
      ],
    );

    final bytes = await ExcelExportService.generateExcelBytes(spec);
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Parse sharedStrings
    final sharedStrings = <String>[];
    final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedStringsFile != null) {
      final xmlDoc = XmlDocument.parse(utf8.decode(sharedStringsFile.content as List<int>));
      for (final si in xmlDoc.findAllElements('si')) {
        final t = si.findAllElements('t').map((e) => e.innerText).join();
        sharedStrings.add(t);
      }
    }
    expect(sharedStrings.isNotEmpty, isTrue);

    // 2. Parse sheet1.xml
    final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    expect(sheetFile, isNotNull);
    final sheetXml = XmlDocument.parse(utf8.decode(sheetFile!.content as List<int>));
    final rows = sheetXml.findAllElements('row');
    expect(rows.isNotEmpty, isTrue);

    for (final row in rows.take(8)) {
      final cellValues = <String>[];
      for (final c in row.findElements('c')) {
        final type = c.getAttribute('t');
        final v = c.findElements('v').firstOrNull?.innerText ?? '';
        if (type == 's' && v.isNotEmpty) {
          final sIdx = int.tryParse(v);
          if (sIdx != null && sIdx < sharedStrings.length) {
            cellValues.add(sharedStrings[sIdx]);
          } else {
            cellValues.add(v);
          }
        } else {
          cellValues.add(v);
        }
      }
      expect(cellValues, isNotNull);
    }
  });

  test('Test ExcelSpecParser round-trip parsing from XLSX bytes', () async {
    final originalSpec = GarmentSpecSheet(
      id: 'spec_1',
      date: DateTime.now(),
      style: 'WRANGLER-TEST',
      po: 'PO-9911',
      brand: 'Wrangler',
      stage: 'Inline',
      tolerance: 0.25,
      sizes: ['30/30', '32/30', '34/30'],
      poms: [
        SpecPomRow(
          no: 1,
          pomCode: 'B1',
          description: 'WAIST RELAXED',
          sizeSpecs: {'30/30': '15 1/2', '32/30': '16 1/2', '34/30': '17 1/2'},
        ),
        SpecPomRow(
          no: 2,
          pomCode: 'B2',
          description: 'HIP MEASUREMENT',
          sizeSpecs: {'30/30': '20', '32/30': '21', '34/30': '22'},
        ),
      ],
    );

    final bytes = await ExcelExportService.generateExcelBytes(originalSpec);
    final parsed = ExcelSpecParser.parse(
      bytes: bytes,
      fileName: 'techpack.xlsx',
    );

    expect(parsed.style, 'WRANGLER-TEST');
    expect(parsed.po, 'PO-9911');
    expect(parsed.brand, 'Wrangler');
    expect(parsed.tolerance, 0.25);
    expect(parsed.sizes, containsAll(['30/30', '32/30', '34/30']));

    expect(parsed.poms.length, 2);
    expect(parsed.poms[0].pomCode, 'B1');
    expect(parsed.poms[0].description, 'WAIST RELAXED');
    expect(parsed.poms[0].sizeSpecs['30/30'], '15 1/2');
    expect(parsed.poms[0].sizeSpecs['32/30'], '16 1/2');
    expect(parsed.poms[0].sizeSpecs['34/30'], '17 1/2');

    expect(parsed.poms[1].pomCode, 'B2');
    expect(parsed.poms[1].description, 'HIP MEASUREMENT');
    expect(parsed.poms[1].sizeSpecs['30/30'], '20');
    expect(parsed.poms[1].sizeSpecs['32/30'], '21');
    expect(parsed.poms[1].sizeSpecs['34/30'], '22');
  });

  test('Test ExcelSpecParser parsing CSV content with 100% accuracy', () {
    const csvData = '''
STYLE,HOODIE-2026,PO,PO-5544,BRAND,Levis
STAGE,Inline,TOLERANCE,0.50

POM,DESCRIPTION,S,M,L,XL
B1,CHEST WIDTH,20,21,22,23
B2,BODY LENGTH,28,29,30,31
B3,SLEEVE LENGTH,33 1/2,34 1/2,35 1/2,36 1/2
''';

    final bytes = utf8.encode(csvData);
    final parsed = ExcelSpecParser.parse(
      bytes: bytes,
      fileName: 'spec.csv',
    );

    expect(parsed.style, 'HOODIE-2026');
    expect(parsed.po, 'PO-5544');
    expect(parsed.brand, 'Levis');
    expect(parsed.tolerance, 0.50);
    expect(parsed.sizes, ['S', 'M', 'L', 'XL']);

    expect(parsed.poms.length, 3);
    expect(parsed.poms[0].pomCode, 'B1');
    expect(parsed.poms[0].description, 'CHEST WIDTH');
    expect(parsed.poms[0].sizeSpecs['S'], '20');
    expect(parsed.poms[0].sizeSpecs['XL'], '23');

    expect(parsed.poms[2].pomCode, 'B3');
    expect(parsed.poms[2].description, 'SLEEVE LENGTH');
    expect(parsed.poms[2].sizeSpecs['S'], '33 1/2');
    expect(parsed.poms[2].sizeSpecs['XL'], '36 1/2');
  });
}
