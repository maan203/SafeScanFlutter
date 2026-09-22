import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../services/sos_service.dart';
import '../services/sms_util.dart';
import '../models/contact_model.dart';
import '../widgets/tappable.dart';

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
  String _statusText = 'Sending SOS...';
  SosResult? _result;
  bool _resolving = false;
  bool _resolved = false;
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
    if (_sosSent || _sending) return;
    setState(() => _isHolding = false);
    _progressController.reset();
    _holdTimer?.cancel();
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = false;
      _sending = true;
      _statusText = 'Sending SOS...';
    });

    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid ?? '';

    final result = await _sosService.triggerSos(
      uid,
      onStatus: (status) {
        if (mounted) setState(() => _statusText = status);
      },
    );

    if (mounted) {
      setState(() {
        _sosSent = true;
        _sending = false;
        _result = result;
      });
    }
  }

  Future<void> _resolveSos() async {
    final result = _result;
    if (result == null || _resolving) return;
    setState(() => _resolving = true);
    final auth = context.read<AuthProvider>();
    try {
      await _sosService.resolveSos(result.sosId, auth.user?.uid ?? '');
      if (mounted) setState(() => _resolved = true);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
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
              child: Tappable(
                onTap: _close,
                borderRadius: BorderRadius.circular(18),
                semanticLabel: 'Close',
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

            Positioned.fill(
              top: 70,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _sosSent
                    ? _SosActionsView(
                        key: const ValueKey('sent'),
                        result: _result!,
                        resolving: _resolving,
                        resolved: _resolved,
                        onResolve: _resolveSos,
                        onDone: _close,
                      )
                    : _sending
                        ? Center(
                            key: const ValueKey('sending'),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4)),
                                const SizedBox(height: 24),
                                Text(_statusText, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          )
                        : Center(
                            key: const ValueKey('hold'),
                            child: _HoldView(
                              pulseAnim: _pulseAnim,
                              isHolding: _isHolding,
                              progressController: _progressController,
                              onHoldStart: _onHoldStart,
                              onHoldEnd: _onHoldEnd,
                            ),
                          ),
              ),
            ),

            if (!_sosSent && !_sending)
              Positioned(
                bottom: 40,
                left: 32,
                right: 32,
                child: Text(
                  'Your live location and emergency message will be sent to all emergency contacts.',
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

/// Shown once the SOS event is logged: lets the user actually deliver the
/// pre-filled alert via WhatsApp or SMS (one tap away from Send in either
/// case) per contact, and mark the situation resolved once it's over.
class _SosActionsView extends StatelessWidget {
  final SosResult result;
  final bool resolving;
  final bool resolved;
  final VoidCallback onResolve;
  final VoidCallback onDone;

  const _SosActionsView({
    super.key,
    required this.result,
    required this.resolving,
    required this.resolved,
    required this.onResolve,
    required this.onDone,
  });

  Future<void> _sendSmsToAll(BuildContext context) async {
    final numbers = result.contacts.map((c) => c.phone).where((p) => p.isNotEmpty).toList();
    final opened = await openSmsComposer(numbers, result.message);
    if (!opened && context.mounted) {
      _showSnack(context, 'Could not open your messaging app.');
    }
  }

  Future<void> _sendWhatsApp(BuildContext context, ContactModel contact) async {
    final opened = await openWhatsAppComposer(contact.phone, result.message);
    if (!opened && context.mounted) {
      _showSnack(context, 'Could not open WhatsApp.');
    }
  }

  Future<void> _sendSmsToContact(BuildContext context, ContactModel contact) async {
    final opened = await openSmsComposer([contact.phone], result.message);
    if (!opened && context.mounted) {
      _showSnack(context, 'Could not open your messaging app.');
    }
  }

  Future<void> _call(BuildContext context, ContactModel contact) async {
    await launchUrl(Uri(scheme: 'tel', path: contact.phone));
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (resolved) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: const Icon(Icons.check_rounded, size: 56, color: Color(0xFF16A34A)),
              ),
              const SizedBox(height: 24),
              Text('You\'re marked safe', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Your emergency alert has been resolved.', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFB91C1C)),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (result.contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_outlined, color: Colors.white, size: 56),
              const SizedBox(height: 16),
              Text('No emergency contacts to alert', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Add one so SOS has someone to notify next time.', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/emergency-contacts'),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white), foregroundColor: Colors.white),
                  child: const Text('Add Emergency Contact'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Text('Alert sent — choose how to notify each contact', textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.4)),
          const SizedBox(height: 6),
          Text('Your message is pre-filled with your location — just tap Send.', textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
          const SizedBox(height: 20),

          if (result.contacts.length > 1) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _sendSmsToAll(context),
                icon: const Icon(Icons.sms_rounded, size: 18),
                label: const Text('Send SMS to all contacts'),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white), foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: result.contacts.asMap().entries.map((e) {
                final i = e.key;
                final c = e.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFFEF2F2),
                            child: Text(c.initials, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFFB91C1C))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A))),
                                Text(c.relation, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          _RoundIconButton(icon: Icons.chat_rounded, color: const Color(0xFF25D366), onTap: () => _sendWhatsApp(context, c), semanticLabel: 'WhatsApp ${c.name}'),
                          _RoundIconButton(icon: Icons.sms_rounded, color: const Color(0xFF3B82F6), onTap: () => _sendSmsToContact(context, c), semanticLabel: 'SMS ${c.name}'),
                          _RoundIconButton(icon: Icons.call_rounded, color: const Color(0xFF64748B), onTap: () => _call(context, c), semanticLabel: 'Call ${c.name}'),
                        ],
                      ),
                    ),
                    if (i < result.contacts.length - 1) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: resolving ? null : onResolve,
              icon: resolving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB91C1C)))
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(resolving ? 'Marking safe...' : 'I\'m Safe — Resolve'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;
  const _RoundIconButton({required this.icon, required this.color, required this.onTap, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    // Tap target is a full 44x44dp for an easy hit even under stress, even
    // though the visible colored circle stays the original 34dp size.
    return Tappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
