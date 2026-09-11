import 'package:flutter/foundation.dart';

/// Centralized diagnostic logger for PDF & Document scanning.
/// Maintains an in-memory buffer of diagnostic messages and outputs to [debugPrint].
class PdfDiagnosticLogger {
  static final List<String> _logs = [];
  static String _summary = '';

  /// Clears existing diagnostic logs
  static void clear() {
    _logs.clear();
    _summary = '';
  }

  /// Adds a tagged log line and prints to debug console
  static void log(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final formatted = '[$timestamp][$tag] $message';
    _logs.add(formatted);
    debugPrint(formatted);
  }

  /// Sets high-level diagnosis summary
  static void setSummary(String summary) {
    _summary = summary;
    debugPrint('[DIAGNOSTIC_SUMMARY] $summary');
  }

  /// Returns whether any logs are currently recorded
  static bool get hasLogs => _logs.isNotEmpty;

  /// Returns the complete diagnostic report formatted for viewing
  static String getReport() {
    final sb = StringBuffer();
    if (_summary.isNotEmpty) {
      sb.writeln('=== DIAGNOSIS SUMMARY ===');
      sb.writeln(_summary);
      sb.writeln();
    }
    sb.writeln('=== DETAILED SCAN LOGS (${_logs.length} entries) ===');
    for (final line in _logs) {
      sb.writeln(line);
    }
    return sb.toString();
  }
}
