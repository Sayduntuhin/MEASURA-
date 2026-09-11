import 'measurement_point.dart';

/// Kontoor Global Tolerance Categories
enum ToleranceCategory {
  adultMaleStretch,
  adultMaleNonStretch,
  adultFemale,
  standard;

  String get label {
    switch (this) {
      case ToleranceCategory.adultMaleStretch:
        return 'Adult Male (Stretch)';
      case ToleranceCategory.adultMaleNonStretch:
        return 'Adult Male (Non-Stretch)';
      case ToleranceCategory.adultFemale:
        return 'Adult Female (Stretch & Non-Stretch)';
      case ToleranceCategory.standard:
        return 'Standard / Custom';
    }
  }

  String get shortLabel {
    switch (this) {
      case ToleranceCategory.adultMaleStretch:
        return 'Male Stretch';
      case ToleranceCategory.adultMaleNonStretch:
        return 'Male Non-Stretch';
      case ToleranceCategory.adultFemale:
        return 'Female (All)';
      case ToleranceCategory.standard:
        return 'Standard';
    }
  }

  static ToleranceCategory fromString(String? val) {
    if (val == null) return ToleranceCategory.adultMaleStretch;
    return ToleranceCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() || e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => ToleranceCategory.adultMaleStretch,
    );
  }
}

/// A specific positive and negative tolerance range for a POM.
class PomTolerance {
  final double posTol; // positive allowed deviation (always positive >= 0)
  final double negTol; // negative allowed deviation magnitude (positive >= 0, meaning allowed down to -negTol)

  const PomTolerance({
    required this.posTol,
    required this.negTol,
  });

  const PomTolerance.symmetric(double tol)
      : posTol = tol,
        negTol = tol;

  /// Returns true if deviation falls within [-negTol, +posTol]
  bool isWithin(double deviation) {
    const epsilon = 0.0001;
    return deviation <= (posTol + epsilon) && deviation >= (-negTol - epsilon);
  }

  /// Formatted string, e.g. "±1/4"", "+1" / -1/2"", "+1 1/4" / -3/4""
  String get displayString {
    if ((posTol - negTol).abs() < 0.001) {
      return '±${formatDeviation(posTol)}"';
    }
    return '+${formatDeviation(posTol)}" / -${formatDeviation(negTol)}"';
  }

  Map<String, dynamic> toMap() {
    return {
      'posTol': posTol,
      'negTol': negTol,
    };
  }

  factory PomTolerance.fromMap(Map<String, dynamic> map) {
    return PomTolerance(
      posTol: (map['posTol'] as num?)?.toDouble() ?? 0.25,
      negTol: (map['negTol'] as num?)?.toDouble() ?? 0.25,
    );
  }

  PomTolerance copyWith({double? posTol, double? negTol}) {
    return PomTolerance(
      posTol: posTol ?? this.posTol,
      negTol: negTol ?? this.negTol,
    );
  }
}

/// Engine implementing the "NEW KONTOOR GLOBAL TOLERANCE FOR BOTTOMS" rules.
class KontoorToleranceEngine {
  /// Check whether a size or spec measurement string represents a 38" or above spec.
  /// For instance: size "38/30", "40/32", or nominal measurement "38", "38 1/2", "39".
  static bool isSizeOrSpec38OrAbove({required String size, String? specValue}) {
    // 1. Check specValue if available (e.g. "38", "38 1/2", "39 1/4")
    if (specValue != null && specValue.trim().isNotEmpty && specValue != '-') {
      final clean = specValue.trim();
      final parts = clean.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        final whole = double.tryParse(parts[0]);
        if (whole != null) {
          return whole >= 38.0;
        }
      }
    }

    // 2. Check waist prefix in size (e.g. "38/30", "38", "40/32", "42", "44")
    final sizeTrimmed = size.trim();
    final waistPart = sizeTrimmed.split(RegExp(r'[/xX\s-]')).first;
    final waistNum = double.tryParse(waistPart);
    if (waistNum != null) {
      return waistNum >= 38.0;
    }

    return false;
  }

  /// Classifies a POM description or code into standard Kontoor POM keys
  static String normalizePomType(String pomCode, String description) {
    final lower = '${pomCode.toLowerCase()} ${description.toLowerCase()}';

    if (lower.contains('waist') || lower.contains('wst') || pomCode.toUpperCase() == 'B1') {
      return 'waist';
    }
    if (lower.contains('seat') || lower.contains('hip') || pomCode.toUpperCase() == 'B2') {
      return 'seat';
    }
    if (lower.contains('inseam') || lower.contains('back length') || lower.contains('insm') || pomCode.toUpperCase() == 'B4') {
      return 'inseam';
    }
    if (lower.contains('thigh') || pomCode.toUpperCase() == 'B3') {
      return 'thigh';
    }
    if (lower.contains('knee')) {
      return 'knee';
    }
    if (lower.contains('leg open') || lower.contains('bottom hem') || lower.contains('leg opn') || lower.contains('hem')) {
      return 'leg_opening';
    }
    if (lower.contains('calf')) {
      return 'calf';
    }
    if (lower.contains('mid thigh') || lower.contains('mid-thigh')) {
      return 'mid_thigh';
    }
    if (lower.contains('front rise') || lower.contains('frnt rise') || pomCode.toUpperCase() == 'B5') {
      return 'front_rise';
    }
    if (lower.contains('back rise')) {
      return 'back_rise';
    }
    if (lower.contains('fly') || lower.contains('zipper')) {
      return 'fly_opening';
    }

    return 'other';
  }

  /// Gets the Kontoor standard tolerance for a specific POM given category and whether spec is >= 38".
  static PomTolerance getStandardTolerance({
    required ToleranceCategory category,
    required String pomCode,
    required String description,
    required bool is38OrAbove,
    double defaultTolerance = 0.25,
  }) {
    if (category == ToleranceCategory.standard) {
      return PomTolerance.symmetric(defaultTolerance);
    }

    final pomType = normalizePomType(pomCode, description);

    switch (category) {
      case ToleranceCategory.adultMaleStretch:
        switch (pomType) {
          case 'waist':
            return is38OrAbove
                ? const PomTolerance.symmetric(1.0) // ±1"
                : const PomTolerance.symmetric(0.75); // ±3/4"
          case 'seat':
            return is38OrAbove
                ? const PomTolerance(posTol: 1.0, negTol: 1.25) // +1", -1 1/4"
                : const PomTolerance.symmetric(1.0); // ±1"
          case 'inseam':
            return const PomTolerance(posTol: 1.0, negTol: 0.5); // +1", -1/2"
          case 'thigh':
            return const PomTolerance(posTol: 0.75, negTol: 0.5); // +3/4", -1/2"
          case 'knee':
            return const PomTolerance.symmetric(0.5); // ±1/2"
          case 'leg_opening':
            return const PomTolerance.symmetric(0.5); // ±1/2"
          case 'calf':
            return const PomTolerance.symmetric(0.5); // ±1/2"
          case 'mid_thigh':
            return const PomTolerance(posTol: 0.75, negTol: 0.5); // +3/4", -1/2"
          case 'front_rise':
            return const PomTolerance(posTol: 0.5, negTol: 0.375); // +1/2", -3/8"
          case 'back_rise':
            return const PomTolerance(posTol: 0.5, negTol: 0.375); // +1/2", -3/8"
          case 'fly_opening':
            return const PomTolerance.symmetric(0.25); // ±1/4"
          default:
            return PomTolerance.symmetric(defaultTolerance);
        }

      case ToleranceCategory.adultMaleNonStretch:
        switch (pomType) {
          case 'waist':
            return is38OrAbove
                ? const PomTolerance(posTol: 1.25, negTol: 0.75) // +1 1/4", -3/4"
                : const PomTolerance(posTol: 1.0, negTol: 0.5); // +1", -1/2"
          case 'seat':
            return is38OrAbove
                ? const PomTolerance.symmetric(1.0) // ±1"
                : const PomTolerance(posTol: 1.0, negTol: 0.75); // +1", -3/4"
          case 'inseam':
            return const PomTolerance(posTol: 1.0, negTol: 0.5); // +1", -1/2"
          case 'thigh':
            return const PomTolerance(posTol: 0.75, negTol: 0.5); // +3/4", -1/2"
          case 'knee':
            return const PomTolerance.symmetric(0.5); // ±1/2"
          case 'leg_opening':
            return const PomTolerance.symmetric(0.5); // ±1/2"
          case 'calf':
            return const PomTolerance.symmetric(0.5); // ±1/2"
          case 'mid_thigh':
            return const PomTolerance(posTol: 0.75, negTol: 0.5); // +3/4", -1/2"
          case 'front_rise':
            return const PomTolerance(posTol: 0.5, negTol: 0.375); // +1/2", -3/8"
          case 'back_rise':
            return const PomTolerance(posTol: 0.5, negTol: 0.375); // +1/2", -3/8"
          case 'fly_opening':
            return const PomTolerance.symmetric(0.25); // ±1/4"
          default:
            return PomTolerance.symmetric(defaultTolerance);
        }

      case ToleranceCategory.adultFemale:
        switch (pomType) {
          case 'waist':
            return is38OrAbove
                ? const PomTolerance.symmetric(1.0) // ±1"
                : const PomTolerance.symmetric(0.75); // ±3/4"
          case 'seat':
            return is38OrAbove
                ? const PomTolerance(posTol: 1.0, negTol: 1.25) // +1", -1 1/4"
                : const PomTolerance.symmetric(0.75); // ±3/4"
          case 'inseam':
            return const PomTolerance(posTol: 1.0, negTol: 0.5); // +1", -1/2"
          case 'thigh':
            return const PomTolerance(posTol: 0.75, negTol: 0.5); // +3/4", -1/2"
          case 'knee':
            return const PomTolerance.symmetric(0.5); // ±1/2"
          case 'leg_opening':
            return const PomTolerance.symmetric(0.5); // ±1/2"
          case 'calf':
            return const PomTolerance.symmetric(0.5); // ±1/2"
          case 'mid_thigh':
            return const PomTolerance(posTol: 0.75, negTol: 0.5); // +3/4", -1/2"
          case 'front_rise':
            return const PomTolerance(posTol: 0.5, negTol: 0.375); // +1/2", -3/8"
          case 'back_rise':
            return const PomTolerance(posTol: 0.5, negTol: 0.375); // +1/2", -3/8"
          case 'fly_opening':
            return const PomTolerance.symmetric(0.25); // ±1/4"
          default:
            return PomTolerance.symmetric(defaultTolerance);
        }

      case ToleranceCategory.standard:
        return PomTolerance.symmetric(defaultTolerance);
    }
  }
}
