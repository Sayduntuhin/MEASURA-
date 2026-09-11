import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/job.dart';
import '../models/reading.dart';
import '../models/measurement_point.dart';
import '../models/spec_sheet_model.dart';

/// Firestore layout:
///   jobs/{jobId}                       -> Job fields (with userId and createdBy)
///   jobs/{jobId}/readings/{readingId}  -> Reading fields
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _jobs =>
      _db.collection('jobs');

  Future<Job> createJob({
    String userId = '',
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
    final effectiveUid = userId.isNotEmpty
        ? userId
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    final job = Job(
      id: id,
      userId: effectiveUid,
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

  Future<void> updateJob({
    required String jobId,
    required String style,
    required String po,
    required String patternNo,
    required String sampleUnit,
    required String sizeSet,
    required DateTime date,
    required double tolerance,
  }) async {
    await _jobs.doc(jobId).update({
      'style': style,
      'po': po,
      'patternNo': patternNo,
      'sampleUnit': sampleUnit,
      'sizeSet': sizeSet,
      'date': Timestamp.fromDate(date),
      'tolerance': tolerance,
    });
  }

  Future<void> deleteJob(String jobId) async {
    try {
      final readings = await _jobs
          .doc(jobId)
          .collection('readings')
          .get()
          .timeout(const Duration(seconds: 4));
      for (final doc in readings.docs) {
        await doc.reference.delete().timeout(const Duration(seconds: 2));
      }
    } catch (_) {}
    await _jobs.doc(jobId).delete().timeout(const Duration(seconds: 4));
  }

  /// Live list of jobs, scoped to the current user.
  Stream<List<Job>> watchJobs({String? userId, String? userEmail}) {
    return _jobs.orderBy('createdAt', descending: true).snapshots().map(
      (snap) {
        final currentUid = userId ?? FirebaseAuth.instance.currentUser?.uid;
        final currentEmail =
            userEmail ?? FirebaseAuth.instance.currentUser?.email;

        return snap.docs
            .map((d) => Job.fromMap(d.id, d.data()))
            .where((job) {
              // If not authenticated (e.g. mock mode), show all
              if ((currentUid == null || currentUid.isEmpty) &&
                  (currentEmail == null || currentEmail.isEmpty)) {
                return true;
              }

              // 1. Matches user UID
              if (currentUid != null && currentUid.isNotEmpty) {
                if (job.userId.isNotEmpty && job.userId == currentUid) {
                  return true;
                }
                if (job.createdBy == currentUid) {
                  return true;
                }
              }

              // 2. Matches user email (case-insensitive for legacy jobs)
              if (currentEmail != null && currentEmail.isNotEmpty) {
                if (job.createdBy.isNotEmpty &&
                    job.createdBy.trim().toLowerCase() ==
                        currentEmail.trim().toLowerCase()) {
                  return true;
                }
                if (job.userId.isNotEmpty &&
                    job.userId.trim().toLowerCase() ==
                        currentEmail.trim().toLowerCase()) {
                  return true;
                }
              }

              return false;
            })
            .toList();
      },
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

  /// Saves a complete GarmentSpecSheet to Firestore
  static Future<void> saveSpecSheet(GarmentSpecSheet sheet) async {
    await FirebaseFirestore.instance.collection('spec_sheets').doc(sheet.id).set(sheet.toMap());
  }

  /// Retrieves all spec sheets belonging to a user
  static Future<List<GarmentSpecSheet>> getUserSpecSheets({String userId = ''}) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('spec_sheets');
    if (userId.isNotEmpty) {
      query = query.where('userId', isEqualTo: userId);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => GarmentSpecSheet.fromMap(doc.id, doc.data())).toList();
  }

  /// Real-time stream of a specific spec sheet
  static Stream<GarmentSpecSheet?> watchSpecSheet(String id) {
    return FirebaseFirestore.instance.collection('spec_sheets').doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return GarmentSpecSheet.fromMap(doc.id, doc.data()!);
    });
  }
}
