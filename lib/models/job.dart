import 'package:cloud_firestore/cloud_firestore.dart';

/// A single measurement job — one row of header info from the
/// paper tally form (Style / PO / Pattern No. / Sample Unit /
/// Size Set / Date), plus a single global tolerance applied to
/// every measurement point in the job.
class Job {
  final String id;
  final String style;
  final String po;
  final String patternNo;
  final String sampleUnit;
  final String sizeSet;
  final DateTime date;

  /// Global tolerance in inches, e.g. 0.25 for ± 1/4".
  final double tolerance;

  final String createdBy;
  final DateTime createdAt;

  Job({
    required this.id,
    required this.style,
    required this.po,
    required this.patternNo,
    required this.sampleUnit,
    required this.sizeSet,
    required this.date,
    required this.tolerance,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'style': style,
      'po': po,
      'patternNo': patternNo,
      'sampleUnit': sampleUnit,
      'sizeSet': sizeSet,
      'date': Timestamp.fromDate(date),
      'tolerance': tolerance,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Job.fromMap(String id, Map<String, dynamic> map) {
    return Job(
      id: id,
      style: map['style'] ?? '',
      po: map['po'] ?? '',
      patternNo: map['patternNo'] ?? '',
      sampleUnit: map['sampleUnit'] ?? '',
      sizeSet: map['sizeSet'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      tolerance: (map['tolerance'] as num).toDouble(),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
