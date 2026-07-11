import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../services/asset_service.dart';
import '../models/asset_model.dart';

class ReportIncidentScreen extends StatefulWidget {
  final String? assetId;
  const ReportIncidentScreen({super.key, this.assetId});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  String? _selectedType;
  final _descCtrl = TextEditingController();
  bool _isLoading = false;
  bool _loadingLocation = false;
  String _address = 'Detecting location...';
  List<File> _photos = [];
  AssetModel? _asset;
  bool _loadingAsset = false;

  final ImagePicker _picker = ImagePicker();
  final LocationService _locationService = LocationService();
  final AssetService _assetService = AssetService();

  final List<_IncidentType> _types = const [
    _IncidentType(label: 'Accident', icon: Icons.car_crash_outlined, color: Color(0xFFEF4444)),
    _IncidentType(label: 'Wrong Parking', icon: Icons.no_crash_outlined, color: Color(0xFFF59E0B)),
    _IncidentType(label: 'Flat Tire', icon: Icons.report_problem_outlined, color: Color(0xFF8B5CF6)),
    _IncidentType(label: 'Lights/Alarm On', icon: Icons.flash_on_outlined, color: Color(0xFF3B82F6)),
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    if (widget.assetId != null) _fetchAsset();
  }

  Future<void> _fetchAsset() async {
    setState(() => _loadingAsset = true);
    final asset = await _assetService.getPublicAsset(widget.assetId!);
    if (mounted) setState(() { _asset = asset; _loadingAsset = false; });
  }

  Future<void> _fetchLocation() async {
    setState(() => _loadingLocation = true);
    final pos = await _locationService.getCurrentPosition();
    if (pos != null && mounted) {
      final addr = await _locationService.getAddressFromPosition(pos);
      setState(() {
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

  Future<void> _pickPhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF22C55E))),
              title: Text('Take Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                if (img != null && mounted) setState(() => _photos.add(File(img.path)));
              },
            ),
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xFF3B82F6))),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (img != null && mounted) setState(() => _photos.add(File(img.path)));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an incident type', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to submit a report.', style: GoogleFonts.inter()), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }

    setState(() => _isLoading = true);
    bool ownerNotified = false;

    try {
      await FirebaseFirestore.instance.collection('incidents').add({
        'type': _selectedType,
        'description': _descCtrl.text.trim(),
        'location': _address,
        'reportedBy': uid,
        'reportedAt': Timestamp.now(),
        'photoCount': _photos.length,
        'assetId': _asset?.id,
        'ownerId': _asset?.userId,
      });

      if (_asset != null) {
        await FirebaseFirestore.instance.collection('users').doc(_asset!.userId).collection('alerts').add({
          'title': 'Incident reported for ${_asset!.name}',
          'body': '$_selectedType reported: ${_descCtrl.text.trim().isEmpty ? "No description" : _descCtrl.text.trim()} ($_address)',
          'type': 'incident',
          'assetId': _asset!.id,
          'location': _address,
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
        ownerNotified = true;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit report: $e', style: GoogleFonts.inter()), backgroundColor: const Color(0xFFEF4444)),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccessDialog(ownerNotified);
    }
  }

  void _showSuccessDialog(bool ownerNotified) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 32, color: Color(0xFF22C55E)),
            ),
            const SizedBox(height: 16),
            Text('Report Submitted', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(
              ownerNotified
                  ? 'Your report has been sent. The owner of ${_asset?.name ?? "this asset"} has been notified.'
                  : 'Your report has been saved to your incident history.',
              textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), height: 1.5)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); context.pop(); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Report Incident', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF0F172A))),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.assetId != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car_outlined, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _loadingAsset
                            ? 'Loading asset...'
                            : _asset != null
                                ? 'Reporting about: ${_asset!.name} — the owner will be notified'
                                : 'This asset could not be found. Your report will still be saved without notifying an owner.',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Incident type', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B))),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _types.map((t) {
                final isSelected = _selectedType == t.label;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t.label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 2),
                      boxShadow: isSelected
                          ? [BoxShadow(color: const Color(0xFF1E293B).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.icon, color: isSelected ? Colors.white : t.color, size: 20),
                        const SizedBox(width: 8),
                        Text(t.label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : const Color(0xFF1E293B))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            Text('Describe what happened', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B))),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g. Car blocking the driveway at...',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF22C55E), width: 2)),
              ),
            ),

            const SizedBox(height: 16),

            // Location card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.location_on_rounded, color: Color(0xFF22C55E), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_loadingLocation ? 'Detecting...' : _address,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A))),
                        Text('Auto-detected location', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  if (_loadingLocation)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22C55E)))
                  else
                    GestureDetector(
                      onTap: _fetchLocation,
                      child: const Icon(Icons.refresh_rounded, color: Color(0xFF3B82F6), size: 20),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Photos section
            Text('Photo evidence', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B))),
            const SizedBox(height: 12),

            if (_photos.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    if (i == _photos.length) {
                      return GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, color: Color(0xFF94A3B8), size: 24),
                            ],
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_photos[i], width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: Color(0xFF94A3B8), size: 28),
                      const SizedBox(height: 8),
                      Text('Tap to add photos', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      Text('Camera or gallery', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Submit Report', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }
}

class _IncidentType {
  final String label;
  final IconData icon;
  final Color color;
  const _IncidentType({required this.label, required this.icon, required this.color});
}
