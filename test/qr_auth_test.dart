import 'package:flutter_test/flutter_test.dart';
import 'package:garment_measurement_app/services/qr_auth_service.dart';

void main() {
  group('QR Auth Session & Pairing Tests', () {
    test('QrAuthSession generates correct measura:// payload', () {
      final now = DateTime.now();
      final session = QrAuthSession(
        sessionId: 'test_session_123',
        secretToken: 'secret_abc_456',
        status: QrSessionStatus.pending,
        deviceInfo: 'Chrome on Windows',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 2)),
      );

      expect(session.qrPayload, equals('measura://auth?session=test_session_123&token=secret_abc_456'));
      expect(session.isExpired, isFalse);
    });

    test('QrAuthSession correctly detects expired session', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      final expiredSession = QrAuthSession(
        sessionId: 'expired_123',
        secretToken: 'secret_abc',
        status: QrSessionStatus.pending,
        deviceInfo: 'Firefox on Mac',
        createdAt: past,
        expiresAt: past.add(const Duration(minutes: 2)), // expired 3 minutes ago
      );

      expect(expiredSession.isExpired, isTrue);
    });

    test('QrAuthSession toMap preserves fields', () {
      final now = DateTime.now();
      final expires = now.add(const Duration(minutes: 2));
      final session = QrAuthSession(
        sessionId: 'session_999',
        secretToken: 'token_888',
        status: QrSessionStatus.approved,
        userId: 'user_xyz',
        userEmail: 'inspector@wrangler.com',
        displayName: 'John Inspector',
        deviceInfo: 'Edge on Windows',
        createdAt: now,
        expiresAt: expires,
        approvedAt: now,
      );

      final map = session.toMap();
      expect(map['sessionId'], 'session_999');
      expect(map['secretToken'], 'token_888');
      expect(map['status'], 'approved');
      expect(map['userId'], 'user_xyz');
      expect(map['userEmail'], 'inspector@wrangler.com');
      expect(map['displayName'], 'John Inspector');
    });
  });
}
