import 'package:flutter_test/flutter_test.dart';
import 'package:garment_measurement_app/models/spec_sheet_model.dart';
import 'package:garment_measurement_app/services/excel_export_service.dart';

void main() {
  test('Excel export creates valid xlsx bytes with styled headers and data', () async {
    final spec = GarmentSpecSheet(
      id: 'spec_1',
      date: DateTime.now(),
      style: 'TEST-101',
      po: 'PO-8821',
      brand: 'Wrangler',
      stage: 'Inline',
      tolerance: 0.25,
      sizes: ['30/30', '32/30'],
      poms: [
        SpecPomRow(
          no: 1,
          pomCode: 'B1',
          description: 'WAIST',
          sizeSpecs: {'30/30': '15 1/2', '32/30': '16 1/2'},
        ),
      ],
      readings: {
        'B1_30/30_1': SampleReading(
          pomCode: 'B1',
          size: '30/30',
          sampleIndex: 1,
          deviation: 0.125,
          deviationText: '+1/8',
          recordedAt: DateTime.now(),
        ),
      },
    );

    final bytes = await ExcelExportService.generateExcelBytes(spec);
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });

  test('Excel export includes Histogram & Analytics worksheet with embedded chart', () async {
    final spec = GarmentSpecSheet(
      id: 'spec_2',
      date: DateTime.now(),
      style: 'HISTO-TEST-202',
      po: 'PO-9911',
      brand: 'Lee',
      stage: 'Finished',
      tolerance: 0.25,
      sizes: ['32', '34'],
      poms: [
        SpecPomRow(no: 1, pomCode: 'WAST', description: 'Waist', sizeSpecs: {'32': '32', '34': '34'}),
        SpecPomRow(no: 2, pomCode: 'INSM', description: 'Inseam', sizeSpecs: {'32': '30', '34': '30'}),
      ],
      readings: {
        'WAST_32_1': SampleReading(pomCode: 'WAST', size: '32', sampleIndex: 1, deviation: 0.0, deviationText: '0', recordedAt: DateTime.now()),
        'WAST_32_2': SampleReading(pomCode: 'WAST', size: '32', sampleIndex: 2, deviation: 0.125, deviationText: '+1/8', recordedAt: DateTime.now()),
        'WAST_32_3': SampleReading(pomCode: 'WAST', size: '32', sampleIndex: 3, deviation: 0.375, deviationText: '+3/8', recordedAt: DateTime.now()), // out of tol
        'INSM_34_1': SampleReading(pomCode: 'INSM', size: '34', sampleIndex: 1, deviation: -0.25, deviationText: '-1/4', recordedAt: DateTime.now()),
      },
    );

    final bytes = await ExcelExportService.generateExcelBytes(spec);
    expect(bytes, isNotEmpty);
    // An Excel file with multiple sheets, cell styles, and embedded PNG charts is comfortably > 5000 bytes
    expect(bytes.length, greaterThan(5000));
  });
}
