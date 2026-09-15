import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/qr_auth_service.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import 'web_inspection_workspace.dart';

class WebQrLoginScreen extends StatefulWidget {
  const WebQrLoginScreen({super.key});

  @override
  State<WebQrLoginScreen> createState() => _WebQrLoginScreenState();
}

class _WebQrLoginScreenState extends State<WebQrLoginScreen> {
  QrAuthSession? _currentSession;
  StreamSubscription<QrAuthSession?>? _sessionSubscription;
  Timer? _countdownTimer;
  int _secondsRemaining = 120;
  bool _isLoading = true;
  bool _isSuccess = false;
  bool _keepMeSignedIn = true;

  @override
  void initState() {
    super.initState();
    _startNewSession();
  }

  Future<void> _startNewSession() async {
    setState(() {
      _isLoading = true;
      _isSuccess = false;
      _secondsRemaining = 120;
    });

    _sessionSubscription?.cancel();
    _countdownTimer?.cancel();

    try {
      final session = await QrAuthService.createWebSession(
        deviceInfo: 'Chrome on Desktop (${DateTime.now().toLocal().toString().substring(0, 16)})',
      );

      if (!mounted) return;
      setState(() {
        _currentSession = session;
        _isLoading = false;
      });

      // Start 2-minute countdown
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
        } else {
          timer.cancel();
          setState(() {});
        }
      });

      // Listen for mobile scan approval in real-time
      _sessionSubscription = QrAuthService.listenToSession(session.sessionId).listen((updated) {
        if (!mounted || updated == null) return;

        if (updated.status == QrSessionStatus.approved && !_isSuccess) {
          _countdownTimer?.cancel();
          setState(() {
            _isSuccess = true;
          });

          // Small delay for smooth visual feedback
          Future.delayed(const Duration(milliseconds: 900), () {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => WebInspectionWorkspace(
                  session: updated,
                  keepSignedIn: _keepMeSignedIn,
                ),
              ),
            );
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize session: $e')),
      );
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;
    final isExpired = _secondsRemaining <= 0 || _currentSession?.status == QrSessionStatus.expired;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1329), // Deep Navy
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Brand Bar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryBlue, Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.straighten_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MEASURA WEB',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Digital Garment QA Inspection Workspace',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Main WhatsApp Web Style Box
                Container(
                  constraints: const BoxConstraints(maxWidth: 960),
                  padding: EdgeInsets.all(isDesktop ? 40 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 5, child: _buildInstructionsPanel()),
                            const SizedBox(width: 48),
                            Container(width: 1, height: 320, color: const Color(0xFFE2E8F0)),
                            const SizedBox(width: 48),
                            Expanded(flex: 4, child: _buildQrPanel(isExpired)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildInstructionsPanel(),
                            const SizedBox(height: 28),
                            const Divider(color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 28),
                            _buildQrPanel(isExpired),
                          ],
                        ),
                ),

                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'End-to-End Real-Time Device Sync via Firebase',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Log in with QR Code',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'View your garment specs, full-width inspection matrices, and real-time histograms on the big screen.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        _stepItem(1, 'Open the MEASURA app on your mobile phone'),
        _stepItem(2, 'Tap the "Link Web" button in the top bar'),
        _stepItem(3, 'Point your phone at this screen to scan the QR code'),

        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: _keepMeSignedIn,
              activeColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) => setState(() => _keepMeSignedIn = val ?? true),
            ),
            const Text(
              'Keep me signed in on this computer',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFFE2E8F0)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('Sign In with Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.laptop_chromebook_rounded, size: 16),
                label: const Text('Launch Full Suite', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => WebInspectionWorkspace(
                        session: QrAuthSession(
                          sessionId: 'web_direct_${DateTime.now().millisecondsSinceEpoch}',
                          secretToken: 'token_${DateTime.now().millisecondsSinceEpoch}',
                          status: QrSessionStatus.approved,
                          createdAt: DateTime.now(),
                          expiresAt: DateTime.now().add(const Duration(days: 30)),
                          userId: 'web_user',
                          userEmail: 'Web Inspector',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepItem(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPanel(bool isExpired) {
    if (_isLoading) {
      return const SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }

    if (_isSuccess) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inTolLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.inTolGreen, width: 2),
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.inTolGreen, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pairing Approved!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Opening your wide workspace...',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // QR Code Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
              ),
              child: QrImageView(
                data: _currentSession?.qrPayload ?? 'measura://invalid',
                version: QrVersions.auto,
                size: 210,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F172A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),

            // Expired Overlay
            if (isExpired)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 36, color: AppColors.primaryBlue),
                      const SizedBox(height: 10),
                      const Text(
                        'QR Code Expired',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _startNewSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Reload QR Code', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Countdown Timer
        if (!isExpired)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  value: _secondsRemaining / 120.0,
                  strokeWidth: 2,
                  color: _secondsRemaining > 30 ? AppColors.primaryBlue : AppColors.outTolRed,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Expires in ${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _secondsRemaining > 30 ? const Color(0xFF64748B) : AppColors.outTolRed,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
