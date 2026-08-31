/// Fixed list of measurement points, matching the paper
/// "Measurement Findings Summary" tally form.
enum MeasurementPoint {
  waist,
  seat,
  thigh,
  inseam,
  frontRise,
  backRise,
  bottom,
  outSeam,
  knee,
}

extension MeasurementPointX on MeasurementPoint {
  /// Display label as shown on the tally form / app.
  String get label {
    switch (this) {
      case MeasurementPoint.waist:
        return 'Waist';
      case MeasurementPoint.seat:
        return 'Seat';
      case MeasurementPoint.thigh:
        return 'Thigh';
      case MeasurementPoint.inseam:
        return 'Inseam';
      case MeasurementPoint.frontRise:
        return 'Front Rise';
      case MeasurementPoint.backRise:
        return 'Back Rise';
      case MeasurementPoint.bottom:
        return 'Bottom';
      case MeasurementPoint.outSeam:
        return 'Out Seam';
      case MeasurementPoint.knee:
        return 'Knee';
    }
  }

  /// Stable key used for Firestore field/document names.
  String get key => toString().split('.').last;

  static MeasurementPoint fromKey(String key) {
    return MeasurementPoint.values.firstWhere(
      (e) => e.key == key,
      orElse: () => MeasurementPoint.waist,
    );
  }
}

/// The fixed set of allowed deviation values, in inches,
/// from -1" to +1" in 1/8" steps (17 buckets) — matches
/// both the paper form and the "Pattern Sizer" mockup.
const List<double> kDeviationBuckets = [
  -1.0, -0.875, -0.75, -0.625, -0.5, -0.375, -0.25, -0.125,
  0.0,
  0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0,
];

/// Formats a decimal deviation value as an eighths-fraction
/// label, e.g. 0.375 -> "3/8", -0.5 -> "-1/2", 0 -> "0", 1 -> "1".
String formatDeviation(double value) {
  if (value == 0) return '0';
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  if (abs == 1.0) return '$sign 1';
  final eighths = (abs * 8).round();
  final whole = eighths ~/ 8;
  final remainder = eighths % 8;
  // Reduce the fraction (e.g. 4/8 -> 1/2, 2/8 -> 1/4).
  int num = remainder;
  int den = 8;
  int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
  final g = gcd(num, den);
  if (g > 0) {
    num ~/= g;
    den ~/= g;
  }
  final fraction = whole > 0 ? '$whole $num/$den' : '$num/$den';
  return '$sign$fraction';
}
