import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../providers/contacts_provider.dart';
import '../services/location_service.dart';
import '../services/sms_util.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> with SingleTickerProviderStateMixin {
  bool _isSharing = false;
  bool _loadingLocation = false;
  String _address = 'Fetching location...';
  Position? _currentPosition;
  late AnimationController _pingController;
  StreamSubscription<Position>? _positionSub;
  Set<int> _selectedContactIndices = {0, 1};

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _pingController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() => _loadingLocation = true);
    final pos = await _locationService.getCurrentPosition();
    if (pos != null && mounted) {
      final addr = await _locationService.getAddressFromPosition(pos);
      setState(() {
        _currentPosition = pos;
        _address = addr ?? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        _loadingLocation = false;
      });
    } else if (mounted) {
      setState(() {
        _address = 'Location unavailable';
        _loadingLocation = false;
      });
    }
  }

  Future<void> _toggleSharing() async {
    final auth = context.read<AuthProvider>();
    final contactsP = context.read<ContactsProvider>();
    final uid = auth.user?.uid ?? '';

    if (_isSharing) {
      _positionSub?.cancel();
      await _locationService.stopSharingLocation(uid);
      setState(() => _isSharing = false);
    } else {
      if (_currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get location. Please enable location permissions.', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final selected = contactsP.contacts
          .asMap()
          .entries
          .where((e) => _selectedContactIndices.contains(e.key))
          .map((e) => e.value)
          .toList();
      final selectedIds = selected.map((c) => c.id).toList();
      final selectedPhones = selected.map((c) => c.phone).where((p) => p.isNotEmpty).toList();

      await _locationService.startSharingLocation(uid, selectedIds);
      setState(() => _isSharing = true);

      if (selectedPhones.isNotEmpty) {
        final mapsLink = 'https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
        final opened = await openSmsComposer(
          selectedPhones,
          'I\'m sharing my location with you: $mapsLink ($_address) — sent via SafeScan.',
        );
        if (mounted && !opened) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open your messaging app to send the location link.', style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }

      _positionSub = _locationService.getPositionStream().listen((pos) async {
        if (!mounted) return;
        final addr = await _locationService.getAddressFromPosition(pos);
        setState(() {
          _currentPosition = pos;
          _address = addr ?? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });
        await _locationService.updateLiveLocation(uid, pos);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsP = context.watch<ContactsProvider>();
    final contacts = contactsP.contacts;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Live Location', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF0F172A))),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text('Text your current location to emergency contacts. Tap Share again anytime to send an updated link.',
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
            ),

            _MapWidget(isSharing: _isSharing, pingController: _pingController),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _loadingLocation ? 'Getting location...' : _address,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF0F172A)),
                              ),
                              if (_currentPosition != null)
                                Text('Accuracy: ±${_currentPosition!.accuracy.toStringAsFixed(0)}m', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        if (_isSharing)
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                        if (_loadingLocation)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22C55E))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text('Share with', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 12),

                  if (contacts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Add emergency contacts first to share location.',
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                          ),
                          TextButton(
                            onPressed: () => context.push('/emergency-contacts'),
                            child: Text('Add', style: GoogleFonts.inter(color: const Color(0xFF22C55E), fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: contacts.asMap().entries.map((e) {
                          final i = e.key;
                          final c = e.value;
                          return Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.08),
                                  child: Text(c.initials, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF1E293B))),
                                ),
                                title: Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF0F172A))),
                                subtitle: Text(c.relation, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                trailing: Checkbox(
                                  value: _selectedContactIndices.contains(i),
                                  activeColor: const Color(0xFF22C55E),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedContactIndices.add(i);
                                      } else {
                                        _selectedContactIndices.remove(i);
                                      }
                                    });
                                  },
                                ),
                              ),
                              if (i < contacts.length - 1)
                                const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: _toggleSharing,
                    icon: Icon(_isSharing ? Icons.stop_rounded : Icons.share_location_outlined, size: 20),
                    label: Text(_isSharing ? 'Stop Sharing' : 'Text My Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSharing ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  if (_isSharing) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A location link was texted to ${_selectedContactIndices.length} contact${_selectedContactIndices.length == 1 ? '' : 's'}. It won\'t update automatically — tap Share again to send a fresh link.',
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF16A34A), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pingController.dispose();
    _positionSub?.cancel();
    super.dispose();
  }
}

class _MapWidget extends StatelessWidget {
  final bool isSharing;
  final AnimationController pingController;

  const _MapWidget({required this.isSharing, required this.pingController});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      color: const Color(0xFFE8F4E8),
      child: Stack(
        children: [
          CustomPaint(size: const Size(double.infinity, 220), painter: _MapGridPainter()),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isSharing)
                  AnimatedBuilder(
                    animation: pingController,
                    builder: (_, __) => Transform.scale(
                      scale: 1.0 + pingController.value * 1.5,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF4444).withValues(alpha: (1 - pingController.value) * 0.3),
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                  child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 26),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFCBD5E1).withValues(alpha: 0.5)..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      final path = Path();
      path.moveTo(0, y);
      for (double x = 0; x < size.width; x += 20) {
        path.quadraticBezierTo(x + 10, y + (i.isEven ? 10 : -10), x + 20, y);
      }
      canvas.drawPath(path, paint);
    }
    final dashPaint = Paint()..color = const Color(0xFFCBD5E1).withValues(alpha: 0.4)..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final x = size.width * i / 4;
      for (double y = 0; y < size.height; y += 10) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 5), dashPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
