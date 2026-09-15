import 'package:flutter_test/flutter_test.dart';
import 'package:garment_measurement_app/services/measurement_parser.dart';
import 'package:garment_measurement_app/models/measurement_point.dart';
import 'package:garment_measurement_app/models/tolerance_standard.dart';

void main() {
  group('MeasurementParser.parse tests', () {
    test('parses whole integers with and without signs and quotes', () {
      expect(MeasurementParser.parse('+2'), equals(2.0));
      expect(MeasurementParser.parse('2'), equals(2.0));
      expect(MeasurementParser.parse('-2'), equals(-2.0));
      expect(MeasurementParser.parse('+2"'), equals(2.0));
      expect(MeasurementParser.parse('2"'), equals(2.0));
      expect(MeasurementParser.parse('-2"'), equals(-2.0));
      expect(MeasurementParser.parse('0'), equals(0.0));
      expect(MeasurementParser.parse('+0'), equals(0.0));
      expect(MeasurementParser.parse('-0'), equals(0.0));
    });

    test('parses mixed fractions', () {
      expect(MeasurementParser.parse('+2 1/4'), equals(2.25));
      expect(MeasurementParser.parse('2 1/4"'), equals(2.25));
      expect(MeasurementParser.parse('-1 1/2'), equals(-1.5));
      expect(MeasurementParser.parse('+1 3/4'), equals(1.75));
      expect(MeasurementParser.parse('-2 3/8'), equals(-2.375));
      expect(MeasurementParser.parse('1-1/2'), equals(1.5));
    });

    test('parses simple fractions', () {
      expect(MeasurementParser.parse('1/8'), equals(0.125));
      expect(MeasurementParser.parse('+1/4'), equals(0.25));
      expect(MeasurementParser.parse('-3/8'), equals(-0.375));
      expect(MeasurementParser.parse('+1/2'), equals(0.5));
      expect(MeasurementParser.parse('-3/4'), equals(-0.75));
      expect(MeasurementParser.parse('7/8"'), equals(0.875));
      expect(MeasurementParser.parse('1/16'), equals(0.0625));
    });

    test('parses decimals and unicode fractions', () {
      expect(MeasurementParser.parse('2.5'), equals(2.5));
      expect(MeasurementParser.parse('-1.75'), equals(-1.75));
      expect(MeasurementParser.parse('2,5'), equals(2.5));
      expect(MeasurementParser.parse('2 ½'), equals(2.5));
      expect(MeasurementParser.parse('-1 ¾'), equals(-1.75));
    });

    test('handles invalid inputs gracefully', () {
      expect(MeasurementParser.parse(null), isNull);
      expect(MeasurementParser.parse(''), isNull);
      expect(MeasurementParser.parse('   '), isNull);
      expect(MeasurementParser.parse('abc'), isNull);
    });
  });

  group('MeasurementParser.formatDeviation tests', () {
    test('formats whole numbers properly', () {
      expect(MeasurementParser.formatDeviation(0.0), equals('0'));
      expect(MeasurementParser.formatDeviation(2.0), equals('+2'));
      expect(MeasurementParser.formatDeviation(-2.0), equals('-2'));
      expect(MeasurementParser.formatDeviation(1.0), equals('+1'));
      expect(MeasurementParser.formatDeviation(-1.0), equals('-1'));
    });

    test('formats fractional deviations properly', () {
      expect(MeasurementParser.formatDeviation(2.25), equals('+2 1/4'));
      expect(MeasurementParser.formatDeviation(-1.5), equals('-1 1/2'));
      expect(MeasurementParser.formatDeviation(0.125), equals('+1/8'));
      expect(MeasurementParser.formatDeviation(-0.375), equals('-3/8'));
      expect(MeasurementParser.formatDeviation(0.75), equals('+3/4'));
      expect(MeasurementParser.formatDeviation(0.0625), equals('+1/16'));
    });

    test('measurement_point.dart formatDeviation fixes whole number issue', () {
      expect(formatDeviation(2.0), equals('2'));
      expect(formatDeviation(-2.0), equals('-2'));
      expect(formatDeviation(1.0), equals('1'));
      expect(formatDeviation(0.0), equals('0'));
      expect(formatDeviation(2.5), equals('2 1/2'));
    });

    test('tolerance evaluation for +2" deviation', () {
      const tol = PomTolerance(posTol: 0.75, negTol: 0.75); // ±3/4"
      expect(tol.isWithin(0.0), isTrue);
      expect(tol.isWithin(0.5), isTrue);
      expect(tol.isWithin(0.75), isTrue);
      expect(tol.isWithin(2.0), isFalse); // +2" is OUT OF TOLERANCE
      expect(tol.isWithin(-2.0), isFalse); // -2" is OUT OF TOLERANCE
    });
  });
}
