import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Shown for every cold app start while Firebase Auth restores (or fails to
/// find) a saved session. Waits for that AND a minimum display time before
/// deciding where to go — this is what prevents the onboarding screen from
/// flashing for already-logged-in users before landing on the dashboard.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _proceedWhenReady();
  }

  Future<void> _proceedWhenReady() async {
    final minDisplay = Future.delayed(const Duration(milliseconds: 1100));
    final auth = context.read<AuthProvider>();

    if (auth.status == AuthStatus.unknown) {
      final resolved = Completer<void>();
      void listener() {
        if (auth.status != AuthStatus.unknown && !resolved.isCompleted) resolved.complete();
      }

      auth.addListener(listener);
      await resolved.future;
      auth.removeListener(listener);
    }

    await minDisplay;
    if (!mounted) return;

    final isAuth = context.read<AuthProvider>().status == AuthStatus.authenticated;
    context.go(isAuth ? '/dashboard' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: Center(
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: _controller,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.4), blurRadius: 28, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 52),
                ),
                const SizedBox(height: 22),
                Text('SafeScan', style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Smart Safety, Simplified', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                const SizedBox(height: 36),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
