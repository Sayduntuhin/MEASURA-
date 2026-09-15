import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'web/web_qr_login_screen.dart';

import 'web/web_inspection_workspace.dart';
import '../services/qr_auth_service.dart';

/// Shows the login screen or home screen depending on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) {
          if (kIsWeb) {
            return const WebQrLoginScreen();
          }
          return const LoginScreen();
        }

        if (kIsWeb) {
          return WebInspectionWorkspace(
            session: QrAuthSession(
              sessionId: 'web_${snapshot.data!.uid}',
              secretToken: 'web_token_${snapshot.data!.uid}',
              status: QrSessionStatus.approved,
              createdAt: DateTime.now(),
              expiresAt: DateTime.now().add(const Duration(days: 30)),
              userId: snapshot.data!.uid,
              userEmail: snapshot.data!.email ?? 'Inspector',
            ),
          );
        }

        return const HomeScreen();
      },
    );
  }
}
