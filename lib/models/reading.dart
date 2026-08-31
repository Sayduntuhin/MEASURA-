import 'package:cloud_firestore/cloud_firestore.dart';
import 'measurement_point.dart';

/// A single measured piece's deviation from spec, for one
/// measurement point, within a job. Each tap on the deviation
/// grid in the entry screen creates one Reading.
class Reading {
  final String id;
  final MeasurementPoint measurementPoint;
  final double deviation;
  final DateTime recordedAt;

  Reading({
    required this.id,
    required this.measurementPoint,
    required this.deviation,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'measurementPoint': measurementPoint.key,
      'deviation': deviation,
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }

  factory Reading.fromMap(String id, Map<String, dynamic> map) {
    return Reading(
      id: id,
      measurementPoint: MeasurementPointX.fromKey(map['measurementPoint']),
      deviation: (map['deviation'] as num).toDouble(),
      recordedAt: (map['recordedAt'] as Timestamp).toDate(),
    );
  }
}

/// Computed stats for one measurement point within a job.
class MeasurementStats {
  final MeasurementPoint measurementPoint;
  final int count;
  final double meanDeviation;
  final int withinTolerance;
  final int outOfTolerance;

  MeasurementStats({
    required this.measurementPoint,
    required this.count,
    required this.meanDeviation,
    required this.withinTolerance,
    required this.outOfTolerance,
  });

  double get passRate => count == 0 ? 0 : withinTolerance / count;
  bool get passes => outOfTolerance == 0;

  static MeasurementStats fromReadings(
    MeasurementPoint point,
    List<Reading> readings,
    double tolerance,
  ) {
    final matching =
        readings.where((r) => r.measurementPoint == point).toList();
    if (matching.isEmpty) {
      return MeasurementStats(
        measurementPoint: point,
        count: 0,
        meanDeviation: 0,
        withinTolerance: 0,
        outOfTolerance: 0,
      );
    }
    final sum = matching.fold<double>(0, (acc, r) => acc + r.deviation);
    final within =
        matching.where((r) => r.deviation.abs() <= tolerance).length;
    return MeasurementStats(
      measurementPoint: point,
      count: matching.length,
      meanDeviation: sum / matching.length,
      withinTolerance: within,
      outOfTolerance: matching.length - within,
    );
  }
}
