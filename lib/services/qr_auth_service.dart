import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum QrSessionStatus { pending, approved, expired, revoked }

class QrAuthSession {
  final String sessionId;
  final String secretToken;
  final QrSessionStatus status;
  final String? userId;
  final String? userEmail;
  final String? displayName;
  final String deviceInfo;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? approvedAt;

  QrAuthSession({
    required this.sessionId,
    required this.secretToken,
    required this.status,
    this.userId,
    this.userEmail,
    this.displayName,
    this.deviceInfo = 'Desktop Browser',
    required this.createdAt,
    required this.expiresAt,
    this.approvedAt,
  });

  /// The URI encoded inside the QR code
  String get qrPayload => 'measura://auth?session=$sessionId&token=$secretToken';

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'secretToken': secretToken,
      'status': status.name,
      'userId': userId,
      'userEmail': userEmail,
      'displayName': displayName,
      'deviceInfo': deviceInfo,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
    };
  }

  factory QrAuthSession.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final statusStr = data['status'] as String? ?? 'pending';
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    QrSessionStatus resolvedStatus = QrSessionStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => QrSessionStatus.pending,
    );

    if (resolvedStatus == QrSessionStatus.pending && DateTime.now().isAfter(expiresAt)) {
      resolvedStatus = QrSessionStatus.expired;
    }

    return QrAuthSession(
      sessionId: doc.id,
      secretToken: data['secretToken'] as String? ?? '',
      status: resolvedStatus,
      userId: data['userId'] as String?,
      userEmail: data['userEmail'] as String?,
      displayName: data['displayName'] as String?,
      deviceInfo: data['deviceInfo'] as String? ?? 'Desktop Browser',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: expiresAt,
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class QrAuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'qr_auth_sessions';

  /// Generates a new 2-minute pairing session for the Web client
  static Future<QrAuthSession> createWebSession({String? deviceInfo}) async {
    const uuid = Uuid();
    final sessionId = uuid.v4();
    final secretToken = uuid.v4().substring(0, 12);
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 2));

    final session = QrAuthSession(
      sessionId: sessionId,
      secretToken: secretToken,
      status: QrSessionStatus.pending,
      deviceInfo: deviceInfo ?? 'MEASURA Web (Desktop)',
      createdAt: now,
      expiresAt: expiresAt,
    );

    await _firestore.collection(collectionName).doc(sessionId).set(session.toMap());
    return session;
  }

  /// Real-time stream of the session document for Web login
  static Stream<QrAuthSession?> listenToSession(String sessionId) {
    return _firestore.collection(collectionName).doc(sessionId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return QrAuthSession.fromFirestore(doc);
    });
  }

  /// Called by the Mobile app when scanning the QR code
  static Future<bool> approveSession({
    required String sessionId,
    required String secretToken,
    required String userId,
    required String userEmail,
    String? displayName,
  }) async {
    final docRef = _firestore.collection(collectionName).doc(sessionId);
    final doc = await docRef.get();

    if (!doc.exists) return false;
    final session = QrAuthSession.fromFirestore(doc);

    // Verify token and validity
    if (session.secretToken != secretToken) return false;
    if (session.isExpired || session.status != QrSessionStatus.pending) return false;

    await docRef.update({
      'status': QrSessionStatus.approved.name,
      'userId': userId,
      'userEmail': userEmail,
      'displayName': displayName ?? userEmail,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Revokes an active web session (from mobile logout or web logout)
  static Future<void> revokeSession(String sessionId) async {
    await _firestore.collection(collectionName).doc(sessionId).update({
      'status': QrSessionStatus.revoked.name,
    });
  }

  /// Stream of all active linked web devices for a given mobile user
  static Stream<List<QrAuthSession>> listenToUserLinkedDevices(String userId) {
    return _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: QrSessionStatus.approved.name)
        .snapshots()
        .map((query) => query.docs.map((d) => QrAuthSession.fromFirestore(d)).toList());
  }

  /// Remote log out of all active web sessions
  static Future<void> logoutAllWebSessions(String userId) async {
    final query = await _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: QrSessionStatus.approved.name)
        .get();

    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'status': QrSessionStatus.revoked.name});
    }
    await batch.commit();
  }
}
