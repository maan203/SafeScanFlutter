import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/contacts_provider.dart';
import '../services/sos_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnim;

  bool _isHolding = false;
  bool _sosSent = false;
  bool _sending = false;
  int _contactsAlerted = 0;
  Timer? _holdTimer;

  final SosService _sosService = SosService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  void _onHoldStart() {
    if (_sosSent || _sending) return;
    setState(() => _isHolding = true);
    HapticFeedback.heavyImpact();
    _progressController.forward();
    _holdTimer = Timer(const Duration(seconds: 3), _triggerSOS);
  }

  void _onHoldEnd() {
    if (_sosSent) return;
    setState(() => _isHolding = false);
    _progressController.reset();
    _holdTimer?.cancel();
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = false;
      _sending = true;
    });

    final auth = context.read<AuthProvider>();
    final contactsP = context.read<ContactsProvider>();
    final uid = auth.user?.uid ?? '';

    await _sosService.triggerSos(uid);

    if (mounted) {
      setState(() {
        _sosSent = true;
        _sending = false;
        _contactsAlerted = contactsP.contacts.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _sosSent ? const Color(0xFFB91C1C) : const Color(0xFFEF4444),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 12,
              left: 16,
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),

            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: Text('Emergency SOS', textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            ),

            Center(
              child: _sosSent
                  ? _SosSentView(contactsAlerted: _contactsAlerted)
                  : _sending
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4)),
                            const SizedBox(height: 24),
                            Text('Sending SOS...', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                          ],
                        )
                      : _HoldView(
                          pulseAnim: _pulseAnim,
                          isHolding: _isHolding,
                          progressController: _progressController,
                          onHoldStart: _onHoldStart,
                          onHoldEnd: _onHoldEnd,
                        ),
            ),

            Positioned(
              bottom: 40,
              left: 32,
              right: 32,
              child: Text(
                _sosSent
                    ? 'SOS sent! Your emergency contacts have been alerted with your live location.'
                    : 'Your live location and emergency message will be sent to all emergency contacts.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }
}

class _HoldView extends StatelessWidget {
  final Animation<double> pulseAnim;
  final bool isHolding;
  final AnimationController progressController;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  const _HoldView({required this.pulseAnim, required this.isHolding, required this.progressController, required this.onHoldStart, required this.onHoldEnd});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('HOLD TO SEND SOS', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text('Press & Hold', style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 48),
        GestureDetector(
          onLongPressStart: (_) => onHoldStart(),
          onLongPressEnd: (_) => onHoldEnd(),
          onLongPressCancel: onHoldEnd,
          child: AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) => Transform.scale(scale: isHolding ? 1.05 : pulseAnim.value, child: child),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15))),
                Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: Icon(Icons.warning_rounded, size: 72, color: isHolding ? const Color(0xFFB91C1C) : const Color(0xFFEF4444)),
                ),
                if (isHolding)
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: AnimatedBuilder(
                      animation: progressController,
                      builder: (_, __) => CircularProgressIndicator(
                        value: progressController.value,
                        strokeWidth: 5,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SosSentView extends StatelessWidget {
  final int contactsAlerted;
  const _SosSentView({required this.contactsAlerted});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: const Icon(Icons.check_rounded, size: 64, color: Color(0xFFEF4444)),
        ),
        const SizedBox(height: 24),
        Text('SOS Sent!', style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('$contactsAlerted contact${contactsAlerted == 1 ? '' : 's'} alerted',
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 16)),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () => context.pop(),
          child: Text('Close', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: Colors.white)),
        ),
      ],
    );
  }
}
