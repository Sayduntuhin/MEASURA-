import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/job.dart';
import '../models/reading.dart';
import '../models/measurement_point.dart';

/// Firestore layout:
///   jobs/{jobId}                       -> Job fields
///   jobs/{jobId}/readings/{readingId}  -> Reading fields
///
/// Multi-user: every authenticated user reads/writes the same
/// `jobs` collection, so jobs and their readings sync across
/// devices. Lock this down with Firestore security rules once
/// you know who should see/edit what (e.g. by team or role).
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _jobs =>
      _db.collection('jobs');

  Future<Job> createJob({
    required String style,
    required String po,
    required String patternNo,
    required String sampleUnit,
    required String sizeSet,
    required DateTime date,
    required double tolerance,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    final job = Job(
      id: id,
      style: style,
      po: po,
      patternNo: patternNo,
      sampleUnit: sampleUnit,
      sizeSet: sizeSet,
      date: date,
      tolerance: tolerance,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    await _jobs.doc(id).set(job.toMap());
    return job;
  }

  /// Live list of jobs, most recent first.
  Stream<List<Job>> watchJobs() {
    return _jobs.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => Job.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> addReading({
    required String jobId,
    required MeasurementPoint measurementPoint,
    required double deviation,
  }) async {
    final id = _uuid.v4();
    final reading = Reading(
      id: id,
      measurementPoint: measurementPoint,
      deviation: deviation,
      recordedAt: DateTime.now(),
    );
    await _jobs.doc(jobId).collection('readings').doc(id).set(
          reading.toMap(),
        );
  }

  Future<void> deleteReading({
    required String jobId,
    required String readingId,
  }) {
    return _jobs.doc(jobId).collection('readings').doc(readingId).delete();
  }

  /// Live list of readings for a job, in the order recorded.
  Stream<List<Reading>> watchReadings(String jobId) {
    return _jobs
        .doc(jobId)
        .collection('readings')
        .orderBy('recordedAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Reading.fromMap(d.id, d.data()))
              .toList(),
        );
  }
}
