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

    test('Wrangler/Kontoor tech pack stream format parses 100% locally from raw user log', () {
      const userRawPdfText = '''Description|Variation30/3030/3232/30[32/32]32/3434/3034/3234/3436/3036/3236/343131333333353535Waist Relaxed373737WAST 141 1/843 3/841 5/843 7/846 1/842 1/844 3/846 5/8OUTSEAM42 5/844 7/847 1/8OTST 215 3/415 3/416 1/416 1/416 1/416 3/416 3/416 3/4Leg Bottom171717WOBH 34040424242444444SEAT - STRAIGHT ACROSS464646SEAT 423 1/823 1/824 1/424 1/424 1/425 1/425 1/425 1/4THIGH 1" DOWN FROM CROTCH26 3/826 3/826 3/8THIX 517 1/217 1/218 1/418 1/418 1/418 3/418 3/418 3/4KNEE @ MID POINT OF INSEAM19 1/419 1/419 1/4KNEE 610 3/41111 1/411 1/211 3/411 3/41212 1/4FRONT RISE12 1/412 1/212 3/4FTRS 714 1/414 1/214 3/41515 1/415 1/415 1/215 3/4BACK RISE15 3/41616 1/4BKRS 83032303234303234INSEAM303234INSM 966 1/26 1/27777 1/27 1/2ZIPPER LENGTH7 1/288FYSZ 1055555777NUMBER OF LOOPS777LOOP 1122222111WHITE POCKET111WPKT 12
No.
POM
Description|Variation38/3038/3240/3042/3044/3046/3046/3239394143454747Waist RelaxedWAST 143 1/845 3/843 5/844 1/844 5/845 1/847 3/8OUTSEAMOTST 217 1/417 1/417 1/217 3/41818 1/418 1/4Leg BottomWOBH 348485052535454SEAT - STRAIGHT ACROSSSEAT 427 1/227 1/228 5/829 5/830 1/830 5/830 5/8THIGH 1" DOWN FROM CROTCHTHIX 519 3/419 3/420 1/420 3/421 1/421 3/421 3/4KNEE @ MID POINT OF INSEAMKNEE 612 3/41313 1/413 3/414 1/414 3/415FRONT RISEFTRS 716 1/416 1/216 3/417 1/417 3/418 1/418 1/2BACK RISEBKRS 830323030303032INSEAMINSM 9888 1/299 1/21010ZIPPER LENGTHFYSZ 107777999NUMBER OF LOOPSLOOP 111111111WHITE POCKETWPKT 12Page Comments:6/20/22: CAPS- NEW PER 72378
04-Sep-2026 06:46PM
Page 34 of 41''';

      final sheet = GarmentTableParser.parse(userRawPdfText);

      // Verify all 18 sizes across both tables were merged in order
      expect(sheet.sizes.length, equals(18));
      expect(sheet.sizes, equals([
        '30/30', '30/32', '32/30', '32/32', '32/34',
        '34/30', '34/32', '34/34', '36/30', '36/32', '36/34',
        '38/30', '38/32', '40/30', '42/30', '44/30', '46/30', '46/32',
      ]));

      // Verify all 12 POM rows
      expect(sheet.poms.length, equals(12));

      // Check WAST
      final wast = sheet.poms.firstWhere((p) => p.pomCode == 'WAST');
      expect(wast.description, equals('Waist Relaxed'));
      expect(wast.sizeSpecs['30/30'], equals('31'));
      expect(wast.sizeSpecs['36/34'], equals('37'));
      expect(wast.sizeSpecs['38/30'], equals('39'));
      expect(wast.sizeSpecs['46/32'], equals('47'));

      // Check OUTSEAM
      final otst = sheet.poms.firstWhere((p) => p.pomCode == 'OTST');
      expect(otst.description, equals('OUTSEAM'));
      expect(otst.sizeSpecs['30/30'], equals('41 1/8'));
      expect(otst.sizeSpecs['36/34'], equals('47 1/8'));
      expect(otst.sizeSpecs['38/30'], equals('43 1/8'));
      expect(otst.sizeSpecs['46/32'], equals('47 3/8'));

      // Check INSEAM
      final insm = sheet.poms.firstWhere((p) => p.pomCode == 'INSM');
      expect(insm.description, equals('INSEAM'));
      expect(insm.sizeSpecs['30/30'], equals('30'));
      expect(insm.sizeSpecs['30/32'], equals('32'));
      expect(insm.sizeSpecs['38/30'], equals('30'));
      expect(insm.sizeSpecs['46/32'], equals('32'));

      // Check ZIPPER LENGTH
      final fysz = sheet.poms.firstWhere((p) => p.pomCode == 'FYSZ');
      expect(fysz.description, equals('ZIPPER LENGTH'));
      expect(fysz.sizeSpecs['30/30'], equals('6'));
      expect(fysz.sizeSpecs['30/32'], equals('6 1/2'));
      expect(fysz.sizeSpecs['38/30'], equals('8'));
      expect(fysz.sizeSpecs['46/32'], equals('10'));

      // Check WHITE POCKET
      final wpkt = sheet.poms.firstWhere((p) => p.pomCode == 'WPKT');
      expect(wpkt.description, equals('WHITE POCKET'));
      expect(wpkt.sizeSpecs['30/30'], equals('2'));
      expect(wpkt.sizeSpecs['38/30'], equals('1'));
    });
  });
}
