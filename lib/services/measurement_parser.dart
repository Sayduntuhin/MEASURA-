/// Comprehensive parser and formatter for apparel measurements, fractions, and deviations.
class MeasurementParser {
  /// Converts common fraction unicode characters to standard ASCII strings
  static String normalizeFractions(String input) {
    return input
        .replaceAll('½', ' 1/2')
        .replaceAll('¼', ' 1/4')
        .replaceAll('¾', ' 3/4')
        .replaceAll('⅛', ' 1/8')
        .replaceAll('⅜', ' 3/8')
        .replaceAll('⅝', ' 5/8')
        .replaceAll('⅞', ' 7/8')
        .replaceAll('⅐', ' 1/7')
        .replaceAll('⅑', ' 1/9')
        .replaceAll('⅒', ' 1/10')
        .replaceAll('⅓', ' 1/3')
        .replaceAll('⅔', ' 2/3')
        .replaceAll('⅕', ' 1/5')
        .replaceAll('⅖', ' 2/5')
        .replaceAll('⅗', ' 3/5')
        .replaceAll('⅘', ' 4/5')
        .replaceAll('⅙', ' 1/6')
        .replaceAll('⅚', ' 5/6');
  }

  /// Parses any user-entered string into a double value.
  /// Supports:
  /// - "+2", "2", "-2", "+2\"", "2\"" -> 2.0, -2.0
  /// - "+2 1/4", "2 1/4", "2-1/4" -> 2.25
  /// - "-1 1/2", "-1 1/2\"" -> -1.5
  /// - "3/8", "+3/8", "-5/8" -> 0.375, -0.625
  /// - "1/16", "3/16", "5/16" -> 0.0625, etc.
  /// - "0", "+0", "-0" -> 0.0
  /// - "2.5", "+2.5", "-1.25", "2,5" -> 2.5, -1.25
  /// Returns null if string cannot be parsed.
  static double? parse(String? input) {
    if (input == null) return null;
    String raw = normalizeFractions(input).trim();
    if (raw.isEmpty) return null;

    // Strip inch quotes and common text
    raw = raw.replaceAll('"', '').replaceAll("'", '');
    raw = raw.replaceAll(RegExp(r'(?:inch|inches|in)\b', caseSensitive: false), '');
    // Standardize comma decimal to dot
    raw = raw.replaceAll(',', '.');
    raw = raw.trim();

    if (raw.isEmpty) return null;

    // Check sign
    bool isNegative = false;
    if (raw.startsWith('-')) {
      isNegative = true;
      raw = raw.replaceFirst(RegExp(r'^\-+\s*'), '');
    } else if (raw.startsWith('+')) {
      raw = raw.replaceFirst(RegExp(r'^\++\s*'), '');
    }

    raw = raw.trim();
    if (raw.isEmpty) return null;

    // Check for exact zero
    if (raw == '0' || raw == '0.0' || raw == '0/1') {
      return 0.0;
    }

    // 1. Simple decimal or integer (e.g. "2", "2.5", "0.75")
    final simpleNum = double.tryParse(raw);
    if (simpleNum != null) {
      return isNegative ? -simpleNum : simpleNum;
    }

    // 2. Simple fraction (e.g. "3/4", "1/8", "5/16")
    if (raw.contains('/') && !raw.contains(' ') && !raw.contains('-')) {
      final parts = raw.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0].trim());
        final den = double.tryParse(parts[1].trim());
        if (num != null && den != null && den != 0) {
          final val = num / den;
          return isNegative ? -val : val;
        }
      }
    }

    // 3. Mixed fraction (e.g. "2 1/4", "2-1/4", "1 1/2", "3 5/8")
    final mixedMatch = RegExp(r'^(\d+)(?:[\s\-]+)(\d+)\s*\/\s*(\d+)$').firstMatch(raw);
    if (mixedMatch != null) {
      final whole = double.tryParse(mixedMatch.group(1)!);
      final num = double.tryParse(mixedMatch.group(2)!);
      final den = double.tryParse(mixedMatch.group(3)!);
      if (whole != null && num != null && den != null && den != 0) {
        final val = whole + (num / den);
        return isNegative ? -val : val;
      }
    }

    // 4. Fallback: try regex splitting on space or hyphen
    final spaceParts = raw.split(RegExp(r'[\s\-]+'));
    if (spaceParts.length == 2) {
      final whole = double.tryParse(spaceParts[0]);
      if (whole != null && spaceParts[1].contains('/')) {
        final fracParts = spaceParts[1].split('/');
        if (fracParts.length == 2) {
          final num = double.tryParse(fracParts[0].trim());
          final den = double.tryParse(fracParts[1].trim());
          if (num != null && den != null && den != 0) {
            final val = whole + (num / den);
            return isNegative ? -val : val;
          }
        }
      }
    }

    return null;
  }

  /// Formats a deviation or measurement value into a clean, conventional apparel fraction string.
  /// Examples:
  /// - 0.0 -> "0"
  /// - 2.0 -> "+2" (or "2" if [explicitPlus] is false)
  /// - -2.0 -> "-2"
  /// - 2.25 -> "+2 1/4"
  /// - -1.5 -> "-1 1/2"
  /// - 0.125 -> "+1/8"
  /// - -0.375 -> "-3/8"
  /// - 0.0625 -> "+1/16"
  /// - 2.3 -> "+2.3"
  static String formatDeviation(double val, {bool explicitPlus = true}) {
    if (val.abs() < 0.0001) return '0';
    final sign = val < 0 ? '-' : (explicitPlus ? '+' : '');
    final abs = val.abs();

    // Check if integer (or practically integer)
    final roundInt = abs.round();
    if ((abs - roundInt).abs() < 0.001) {
      return '$sign$roundInt';
    }

    // Check 8ths (most common in apparel)
    final eighths = (abs * 8).round();
    if ((abs - (eighths / 8.0)).abs() < 0.002) {
      final whole = eighths ~/ 8;
      final rem = eighths % 8;
      if (rem == 0) return '$sign$whole';
      final fracStr = _reduceFraction(rem, 8);
      return whole > 0 ? '$sign$whole $fracStr' : '$sign$fracStr';
    }

    // Check 16ths
    final sixteenths = (abs * 16).round();
    if ((abs - (sixteenths / 16.0)).abs() < 0.002) {
      final whole = sixteenths ~/ 16;
      final rem = sixteenths % 16;
      if (rem == 0) return '$sign$whole';
      final fracStr = _reduceFraction(rem, 16);
      return whole > 0 ? '$sign$whole $fracStr' : '$sign$fracStr';
    }

    // Check 32nds
    final thirtyseconds = (abs * 32).round();
    if ((abs - (thirtyseconds / 32.0)).abs() < 0.002) {
      final whole = thirtyseconds ~/ 32;
      final rem = thirtyseconds % 32;
      if (rem == 0) return '$sign$whole';
      final fracStr = _reduceFraction(rem, 32);
      return whole > 0 ? '$sign$whole $fracStr' : '$sign$fracStr';
    }

    // Fallback: clean decimal
    String decStr = abs.toStringAsFixed(2);
    if (decStr.endsWith('.00')) {
      decStr = decStr.substring(0, decStr.length - 3);
    } else if (decStr.endsWith('0')) {
      decStr = decStr.substring(0, decStr.length - 1);
    }
    return '$sign$decStr';
  }

  static String _reduceFraction(int num, int den) {
    int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
    final g = gcd(num, den);
    if (g > 0) {
      num ~/= g;
      den ~/= g;
    }
    return '$num/$den';
  }
}
