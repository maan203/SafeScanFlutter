import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/asset_model.dart';
import '../models/chat_model.dart';
import '../services/asset_service.dart';
import '../services/chat_service.dart';
import '../services/location_service.dart';
import '../providers/auth_provider.dart';

enum _EmergencyState { idle, sending, sent }

/// Shown to whoever scans an asset's QR code — the owner testing their own
/// sticker, or a stranger who found it. Does not require the viewer to be
/// logged in or to own the asset.
class FoundItemScreen extends StatefulWidget {
  final String assetId;
  const FoundItemScreen({super.key, required this.assetId});

  @override
  State<FoundItemScreen> createState() => _FoundItemScreenState();
}

enum _ScanRecordState { pending, done, failed }

class _FoundItemScreenState extends State<FoundItemScreen> {
  final _service = AssetService();
  final _locationService = LocationService();
  late Future<AssetModel?> _future;
  _ScanRecordState _scanState = _ScanRecordState.pending;
  bool _scanRecordStarted = false;
  bool _reportingIssue = false;
  _EmergencyState _emergencyState = _EmergencyState.idle;
  int _emergencyContactsMessaged = 0;

  @override
  void initState() {
    super.initState();
    _future = _service.getPublicAsset(widget.assetId);
  }

  /// Every genuine view of this screen by someone other than the owner
  /// counts as a scan: bumps the owner's Total Scans stat and sends them
  /// a real "your QR was scanned" alert, automatically — no extra tap
  /// needed, so it can't be silently skipped by going straight to chat.
  Future<void> _recordScanOnce(AssetModel asset) async {
    if (_scanRecordStarted) return;
    _scanRecordStarted = true;

    String? location;
    try {
      final pos = await _locationService.getCurrentPosition().timeout(const Duration(seconds: 6));
      location = pos != null ? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}' : null;
    } catch (_) {
      location = null;
    }

    try {
      await _service.recordScan(asset, location);
      if (mounted) setState(() => _scanState = _ScanRecordState.done);
    } catch (_) {
      if (mounted) setState(() => _scanState = _ScanRecordState.failed);
    }
  }

  Future<void> _reportIssue(AuthProvider auth, AssetModel asset) async {
    setState(() => _reportingIssue = true);
    try {
      if (auth.user == null) {
        final ok = await auth.continueAsGuest('Guest');
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(auth.error ?? 'Could not continue. Please try again.', style: GoogleFonts.inter()),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }
      }
      if (mounted) context.push('/report-incident?assetId=${asset.id}');
    } finally {
      if (mounted) setState(() => _reportingIssue = false);
    }
  }

  void _showEmergencyContactPicker(BuildContext context, AssetModel asset) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Call an emergency contact', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF0F172A))),
            const SizedBox(height: 12),
            ...asset.emergencyContacts.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.phone_outlined, color: Color(0xFF22C55E)),
                  ),
                  title: Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  subtitle: Text(c.phone, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(Uri(scheme: 'tel', path: c.phone));
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndTriggerEmergency(AssetModel asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Alert emergency contacts?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          'Only use this for a real emergency — an accident, injury, or a lost person. '
          'This will text ${asset.userName}\'s emergency contacts directly with your location, '
          'skipping the owner entirely in case they can\'t respond.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, alert them', style: GoogleFonts.inter(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _emergencyState = _EmergencyState.sending);

    String? location;
    String? mapsLink;
    try {
      final pos = await _locationService.getCurrentPosition().timeout(const Duration(seconds: 6));
      if (pos != null) {
        location = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        mapsLink = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
      }
    } catch (_) {
      location = null;
    }

    try {
      final result = await _service.triggerEmergencyRelay(asset, location, mapsLink);
      if (mounted) {
        setState(() {
          _emergencyState = _EmergencyState.sent;
          _emergencyContactsMessaged = result.contactCount;
        });
        if (!result.smsComposerOpened) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.contactCount == 0
                    ? 'No emergency contacts are set up for this asset. Try calling the owner directly.'
                    : 'Could not open your messaging app automatically.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _emergencyState = _EmergencyState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not alert emergency contacts: $e', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Found Item', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 18)),
        centerTitle: true,
        automaticallyImplyLeading: Navigator.of(context).canPop(),
      ),
      body: FutureBuilder<AssetModel?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)));
          }
          final asset = snapshot.data;
          if (asset == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 56, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 16),
                    Text('This QR code is not registered', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                  ],
                ),
              ),
            );
          }

          if (!asset.isActive) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_off_outlined, size: 56, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 16),
                    Text('This asset is currently inactive', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                  ],
                ),
              ),
            );
          }

          final isOwner = auth.user != null && !auth.isAnonymous && auth.user!.uid == asset.userId;
          if (!isOwner) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _recordScanOnce(asset));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(color: asset.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Icon(asset.icon, color: asset.color, size: 36),
                      ),
                      const SizedBox(height: 16),
                      Text(asset.name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                      Text(asset.type, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
                      if (asset.description != null && asset.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(asset.description!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                      ],
                    ],
                  ),
                ),

                if (!isOwner && asset.emergencyContacts.isNotEmpty && _emergencyState != _EmergencyState.sent) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.emergency_rounded, color: Color(0xFFB91C1C), size: 28),
                        const SizedBox(height: 8),
                        Text('Is this an emergency?', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF991B1B))),
                        const SizedBox(height: 6),
                        Text(
                          'Accident, injury, or a lost person — alert the owner\'s emergency contacts directly.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _emergencyState == _EmergencyState.sending ? null : () => _confirmAndTriggerEmergency(asset),
                            icon: _emergencyState == _EmergencyState.sending
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.emergency_share_rounded, size: 20),
                            label: Text(_emergencyState == _EmergencyState.sending ? 'Alerting...' : 'Alert Emergency Contacts'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_emergencyState == _EmergencyState.sent) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Messaging app opened to alert $_emergencyContactsMessaged emergency contact${_emergencyContactsMessaged == 1 ? '' : 's'} — tap Send there to complete it.',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (isOwner) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
                        const SizedBox(width: 12),
                        Expanded(child: Text('This is your own asset — this is what a finder would see.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E40AF), fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/qr-detail/${asset.id}'),
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Manage This Asset'),
                    ),
                  ),
                ],

                if (asset.rewardMessage != null && asset.rewardMessage!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.card_giftcard_outlined, color: Color(0xFFD97706)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(asset.rewardMessage!, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF92400E), fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                ],

                if (!isOwner && asset.showPhone && asset.phone != null && asset.phone!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ContactTile(
                    icon: Icons.phone_outlined,
                    label: 'Call owner',
                    value: asset.phone!,
                    onTap: () => launchUrl(Uri(scheme: 'tel', path: asset.phone)),
                  ),
                ],

                if (!isOwner && asset.emergencyContacts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ContactTile(
                    icon: Icons.support_agent_rounded,
                    label: asset.emergencyContacts.length == 1 ? 'Call emergency contact' : 'Call an emergency contact',
                    value: asset.emergencyContacts.length == 1
                        ? '${asset.emergencyContacts.first.name} · ${asset.emergencyContacts.first.phone}'
                        : '${asset.emergencyContacts.length} contacts available',
                    onTap: () {
                      if (asset.emergencyContacts.length == 1) {
                        launchUrl(Uri(scheme: 'tel', path: asset.emergencyContacts.first.phone));
                      } else {
                        _showEmergencyContactPicker(context, asset);
                      }
                    },
                  ),
                ],

                if (!isOwner) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _scanState == _ScanRecordState.failed ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _scanState == _ScanRecordState.failed ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        if (_scanState == _ScanRecordState.pending)
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22C55E)))
                        else
                          Icon(
                            _scanState == _ScanRecordState.failed ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                            color: _scanState == _ScanRecordState.failed ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                            size: 20,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _scanState == _ScanRecordState.pending
                                ? 'Notifying the owner you found this...'
                                : _scanState == _ScanRecordState.failed
                                    ? 'Could not notify the owner — you can still call or chat below.'
                                    : 'Owner notified! They\'ve received an alert with your approximate location.',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _ChatStarter(asset: asset),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _reportingIssue ? null : () => _reportIssue(auth, asset),
                      icon: _reportingIssue
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)))
                          : const Icon(Icons.report_gmailerrorred_outlined, size: 18, color: Color(0xFFEF4444)),
                      label: Text('Report an Issue', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFECACA))),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Lets a finder start (or resume) a text conversation with the asset's
/// owner. Signs in anonymously the first time so there's a stable identity
/// to chat from, without requiring a full SafeScan account.
class _ChatStarter extends StatefulWidget {
  final AssetModel asset;
  const _ChatStarter({required this.asset});

  @override
  State<_ChatStarter> createState() => _ChatStarterState();
}

class _ChatStarterState extends State<_ChatStarter> {
  final _chatService = ChatService();
  final _nameCtrl = TextEditingController();
  Future<ChatModel?>? _existingChatFuture;
  bool _starting = false;
  String? _checkedForUid;

  Future<ChatModel?> _checkExisting(String uid) => _chatService.findExistingChat(widget.asset.id, uid);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _startChat(AuthProvider auth) async {
    setState(() => _starting = true);
    try {
      String uid;
      String name;
      if (auth.user != null) {
        uid = auth.user!.uid;
        name = auth.user!.name;
      } else {
        final displayName = _nameCtrl.text.trim().isEmpty ? 'Guest' : _nameCtrl.text.trim();
        final ok = await auth.continueAsGuest(displayName);
        if (!ok || auth.user == null) {
          _showError(auth.error ?? 'Could not sign you in. Make sure Anonymous sign-in is enabled in Firebase Console → Authentication → Sign-in method.');
          return;
        }
        uid = auth.user!.uid;
        name = auth.user!.name;
      }

      final chat = await _chatService.startChat(asset: widget.asset, finderId: uid, finderName: name);
      if (mounted) context.push('/chat/${chat.id}');
    } catch (e) {
      _showError('Could not start chat: $e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid;

    if (uid != null && _checkedForUid != uid) {
      _checkedForUid = uid;
      _existingChatFuture = _checkExisting(uid);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: uid != null
          ? FutureBuilder<ChatModel?>(
              future: _existingChatFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Color(0xFF22C55E), strokeWidth: 2)));
                }
                if (snap.data != null) {
                  return _buildBody(context, auth, existingChatId: snap.data!.id, isClosed: snap.data!.isClosed);
                }
                return _buildBody(context, auth);
              },
            )
          : _buildBody(context, auth),
    );
  }

  Widget _buildBody(BuildContext context, AuthProvider auth, {String? existingChatId, bool isClosed = false}) {
    if (existingChatId != null) {
      return Column(
        children: [
          Icon(isClosed ? Icons.check_circle_outline_rounded : Icons.chat_bubble_outline_rounded, color: const Color(0xFF22C55E), size: 28),
          const SizedBox(height: 10),
          Text(isClosed ? 'This conversation is resolved' : 'You already have a conversation about this', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A)), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/chat/$existingChatId'),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Open Chat'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Want to talk to the owner directly?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF0F172A))),
        const SizedBox(height: 6),
        Text('Chat inside the app to arrange the return — no phone number needed.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
        if (auth.user == null) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Your name (optional)',
              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _starting ? null : () => _startChat(auth),
            icon: _starting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(_starting ? 'Starting...' : 'Start Chat'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _ContactTile({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF22C55E)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
