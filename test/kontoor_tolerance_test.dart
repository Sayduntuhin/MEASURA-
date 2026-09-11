import 'package:flutter_test/flutter_test.dart';
import 'package:garment_measurement_app/models/spec_sheet_model.dart';
import 'package:garment_measurement_app/models/tolerance_standard.dart';
import 'package:garment_measurement_app/services/excel_export_service.dart';
import 'package:garment_measurement_app/widgets/quick_deviation_sheet.dart';

void main() {
  group('Kontoor Global Tolerance Engine Tests', () {
    test('Adult Male Stretch Waist tolerance rules (<38" vs >=38")', () {
      // Under 38" waist spec -> ±3/4" (0.75)
      final tolUnder38 = KontoorToleranceEngine.getStandardTolerance(
        category: ToleranceCategory.adultMaleStretch,
        pomCode: 'B1',
        description: 'WAIST RELAXED',
        is38OrAbove: false,
      );
      expect(tolUnder38.posTol, 0.75);
      expect(tolUnder38.negTol, 0.75);
      expect(tolUnder38.displayString, '±3/4"');
      expect(tolUnder38.isWithin(0.75), isTrue);
      expect(tolUnder38.isWithin(0.875), isFalse);

      // 38" and above -> ±1" (1.0)
      final tol38OrAbove = KontoorToleranceEngine.getStandardTolerance(
        category: ToleranceCategory.adultMaleStretch,
        pomCode: 'B1',
        description: 'WAIST RELAXED',
        is38OrAbove: true,
      );
      expect(tol38OrAbove.posTol, 1.0);
      expect(tol38OrAbove.negTol, 1.0);
      expect(tol38OrAbove.displayString, '±1"');
      expect(tol38OrAbove.isWithin(1.0), isTrue);
      expect(tol38OrAbove.isWithin(1.125), isFalse);
    });

    test('Adult Male Non-Stretch Waist asymmetric tolerance (+1, -1/2 vs +1 1/4, -3/4)', () {
      // Under 38" -> +1", -1/2"
      final tolUnder38 = KontoorToleranceEngine.getStandardTolerance(
        category: ToleranceCategory.adultMaleNonStretch,
        pomCode: 'WAIST',
        description: 'WAIST MEASUREMENT',
        is38OrAbove: false,
      );
      expect(tolUnder38.posTol, 1.0);
      expect(tolUnder38.negTol, 0.5);
      expect(tolUnder38.displayString, '+1" / -1/2"');
      expect(tolUnder38.isWithin(1.0), isTrue);
      expect(tolUnder38.isWithin(-0.5), isTrue);
      expect(tolUnder38.isWithin(-0.625), isFalse);

      // 38" & above -> +1 1/4", -3/4"
      final tol38OrAbove = KontoorToleranceEngine.getStandardTolerance(
        category: ToleranceCategory.adultMaleNonStretch,
        pomCode: 'WAIST',
        description: 'WAIST MEASUREMENT',
        is38OrAbove: true,
      );
      expect(tol38OrAbove.posTol, 1.25);
      expect(tol38OrAbove.negTol, 0.75);
      expect(tol38OrAbove.displayString, '+1 1/4" / -3/4"');
      expect(tol38OrAbove.isWithin(1.25), isTrue);
      expect(tol38OrAbove.isWithin(-0.75), isTrue);
      expect(tol38OrAbove.isWithin(-0.875), isFalse);
    });

    test('Adult Female Seat tolerance rules (<38" is ±3/4", >=38" is +1, -1 1/4)', () {
      final under = KontoorToleranceEngine.getStandardTolerance(
        category: ToleranceCategory.adultFemale,
        pomCode: 'SEAT',
        description: 'SEAT / HIP',
        is38OrAbove: false,
      );
      expect(under.posTol, 0.75);
      expect(under.negTol, 0.75);

      final above = KontoorToleranceEngine.getStandardTolerance(
        category: ToleranceCategory.adultFemale,
        pomCode: 'SEAT',
        description: 'SEAT / HIP',
        is38OrAbove: true,
      );
      expect(above.posTol, 1.0);
      expect(above.negTol, 1.25);
      expect(above.displayString, '+1" / -1 1/4"');
    });

    test('Detects sizes >= 38" correctly', () {
      expect(KontoorToleranceEngine.isSizeOrSpec38OrAbove(size: '38/30'), isTrue);
      expect(KontoorToleranceEngine.isSizeOrSpec38OrAbove(size: '40/32'), isTrue);
      expect(KontoorToleranceEngine.isSizeOrSpec38OrAbove(size: '30/30', specValue: '38 1/2'), isTrue);
      expect(KontoorToleranceEngine.isSizeOrSpec38OrAbove(size: '32/30', specValue: '34'), isFalse);
    });
  });

  group('Deviation Format & Sequence Tests', () {
    test('Format display string cleans ++1/8 to +1/8 without duplicate plus', () {
      expect(QuickDeviationSheet.formatCleanDisplay(0.125, '+1/8"'), '+1/8');
      expect(QuickDeviationSheet.formatCleanDisplay(0.125, '++1/8"'), '+1/8');
      expect(QuickDeviationSheet.formatCleanDisplay(0.25, '+1/4"'), '+1/4');
      expect(QuickDeviationSheet.formatCleanDisplay(0.0, '0 (Spec)'), '0');
      expect(QuickDeviationSheet.formatCleanDisplay(-0.25, '-1/4"'), '-1/4');
    });

    test('Deviation options contains 7/8 in sequence', () {
      final pos78 = QuickDeviationSheet.deviationOptions.any((o) => o['label'] == '+7/8"');
      final neg78 = QuickDeviationSheet.deviationOptions.any((o) => o['label'] == '-7/8"');
      expect(pos78, isTrue);
      expect(neg78, isTrue);
    });
  });

  group('GarmentSpecSheet & Selective Export Tests', () {
    test('Individual POM tolerance overrides take precedence', () {
      final sheet = GarmentSpecSheet(
        id: '1',
        style: 'TEST',
        date: DateTime.now(),
        tolerance: 0.25,
        sizes: ['30/30'],
        poms: [
          SpecPomRow(no: 1, pomCode: 'B1', description: 'WAIST', sizeSpecs: {'30/30': '32'}),
        ],
        customPomTolerances: {
          'B1': const PomTolerance(posTol: 1.5, negTol: 0.25),
        },
      );

      final tol = sheet.getPomTolerance('B1');
      expect(tol.posTol, 1.5);
      expect(tol.negTol, 0.25);
      expect(sheet.isWithinTolerance(1.5, pomCode: 'B1'), isTrue);
      expect(sheet.isWithinTolerance(1.6, pomCode: 'B1'), isFalse);
    });

    test('Selective size Excel export generates valid bytes', () async {
      final sheet = GarmentSpecSheet(
        id: '1',
        style: 'TEST',
        date: DateTime.now(),
        tolerance: 0.25,
        sizes: ['28/30', '30/30', '32/30', '34/30', '38/30', '40/30'],
        poms: [
          SpecPomRow(no: 1, pomCode: 'B1', description: 'WAIST', sizeSpecs: {'28/30': '29', '38/30': '38'}),
        ],
        readings: {
          'B1_38/30_1': SampleReading(
            pomCode: 'B1',
            size: '38/30',
            sampleIndex: 1,
            deviation: 0.5,
            deviationText: '+1/2',
            recordedAt: DateTime.now(),
          ),
        },
      );

      final fullBytes = await ExcelExportService.generateExcelBytes(sheet);
      expect(fullBytes, isNotEmpty);

      // Export only specific sizes (e.g. ['38/30', '40/30'])
      final selectiveBytes = await ExcelExportService.generateExcelBytes(
        sheet,
        selectedSizes: ['38/30', '40/30'],
      );
      expect(selectiveBytes, isNotEmpty);
      expect(selectiveBytes.length, greaterThan(100));
    });
  });
}
