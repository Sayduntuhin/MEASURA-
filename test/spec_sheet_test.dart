import 'package:flutter_test/flutter_test.dart';
import 'package:garment_measurement_app/models/spec_sheet_model.dart';
import 'package:garment_measurement_app/services/garment_table_parser.dart';
import 'package:garment_measurement_app/services/pdf_scanner_service.dart';

void main() {
  group('Garment Spec Sheet Tests', () {
    test('Wrangler example spec sheet loads correctly from PDF dataset', () {
      final spec = PdfScannerService.getExampleWranglerSpecSheet();

      expect(spec.style, equals('10E7621SW'));
      expect(spec.brand, equals('Wrangler'));
      expect(spec.sizes.length, equals(11));
      expect(spec.sizes.first, equals('30/30'));
      expect(spec.sizes.contains('32/32'), isTrue);

      // Verify POMs
      expect(spec.poms.length, equals(14));
      final waist = spec.poms.firstWhere((p) => p.pomCode == 'WAST');
      expect(waist.description, equals('Waist Relaxed'));
      expect(waist.sizeSpecs['30/30'], equals('32 1/4'));
      expect(waist.sizeSpecs['34/30'], equals('36 1/2'));

      final inseam = spec.poms.firstWhere((p) => p.pomCode == 'INSM');
      expect(inseam.description, equals('INSEAM'));
      expect(inseam.sizeSpecs['30/30'], equals('31'));
      expect(inseam.sizeSpecs['30/32'], equals('33'));

      // Verify readings from the paper photo
      expect(spec.recordedCount, greaterThan(0));
      final waistSample1 = spec.getReading('WAST', '30/30', 1);
      expect(waistSample1, isNotNull);
      expect(waistSample1!.deviationText, equals('-1/2'));
      expect(waistSample1.deviation, equals(-0.5));
      // -0.5 is outside ±0.25 tolerance
      expect(spec.isWithinTolerance(waistSample1.deviation), isFalse);

      final waistSample2 = spec.getReading('WAST', '30/30', 2);
      expect(waistSample2, isNotNull);
      expect(waistSample2!.deviationText, equals('0'));
      expect(spec.isWithinTolerance(waistSample2.deviation), isTrue);

      // Verify pass rate
      expect(spec.passRate, inInclusiveRange(0.0, 1.0));
    });

    test('Tolerance calculations and cell keys work as expected', () {
      final sheet = GarmentSpecSheet(
        id: 'test_1',
        style: 'TEST',
        date: DateTime.now(),
        tolerance: 0.25,
        sizes: ['S', 'M'],
        poms: [],
      );

      expect(sheet.isWithinTolerance(0.0), isTrue);
      expect(sheet.isWithinTolerance(0.125), isTrue);
      expect(sheet.isWithinTolerance(-0.25), isTrue);
      expect(sheet.isWithinTolerance(0.25), isTrue);
      expect(sheet.isWithinTolerance(0.375), isFalse);
      expect(sheet.isWithinTolerance(-0.5), isFalse);

      expect(GarmentSpecSheet.cellKey('WAST', '30/30', 3), equals('WAST_30/30_3'));
    });

    test('GarmentTableParser dynamically extracts arbitrary new tech pack data from PDF text', () {
      const rawPdfText = '''
LEVI STRAUSS & CO.
Product Development | Denim
Style: 501-CLASSIC-JEAN
PO: PO-99821
Finished Product
Before Wash
No. POM Description 28/30 30/30 32/30 34/30
1 WAST Waist Band 29 1/2 31 1/2 33 1/2 35 1/2
2 SEAT Hip Across 38 40 42 44
3 INSM Inseam Length 30 30 30 30
4 WOBH Leg Opening 15 15 1/2 16 16 1/2
''';

      final parsed = GarmentTableParser.parse(rawPdfText);

      // Verify it parsed the NEW custom data, NOT the Wrangler sample
      expect(parsed.style, equals('501-CLASSIC-JEAN'));
      expect(parsed.po, equals('PO-99821'));
      expect(parsed.brand, equals('Levi'));
      expect(parsed.sizes, equals(['28/30', '30/30', '32/30', '34/30']));

      expect(parsed.poms.length, equals(4));
      expect(parsed.poms[0].pomCode, equals('WAST'));
      expect(parsed.poms[0].description, equals('Waist Band'));
      expect(parsed.poms[0].sizeSpecs['28/30'], equals('29 1/2'));
      expect(parsed.poms[0].sizeSpecs['34/30'], equals('35 1/2'));

      expect(parsed.poms[3].pomCode, equals('WOBH'));
      expect(parsed.poms[3].description, equals('Leg Opening'));
      expect(parsed.poms[3].sizeSpecs['30/30'], equals('15 1/2'));
    });
  });
}
