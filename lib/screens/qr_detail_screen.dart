import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/auth_provider.dart';
import '../providers/assets_provider.dart';

class QrDetailScreen extends StatefulWidget {
  final String assetId;
  const QrDetailScreen({super.key, required this.assetId});

  @override
  State<QrDetailScreen> createState() => _QrDetailScreenState();
}

class _QrDetailScreenState extends State<QrDetailScreen> {
  bool _working = false;

  Future<Uint8List> _generateQrBytes(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E293B)),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1E293B)),
    );
    final imageData = await painter.toImageData(600, format: ui.ImageByteFormat.png);
    return imageData!.buffer.asUint8List();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _downloadQr(String qrData, String assetName) async {
    setState(() => _working = true);
    try {
      final bytes = await _generateQrBytes(qrData);
      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) throw Exception('Permission to save photos was denied');
      await Gal.putImageBytes(bytes, name: 'safescan_${assetName.replaceAll(' ', '_')}');
      _showSnack('QR code saved to your gallery');
    } catch (e) {
      _showSnack('Could not save QR code: $e', isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _printQr(String qrData, String assetName) async {
    setState(() => _working = true);
    try {
      final bytes = await _generateQrBytes(qrData);
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (pwContext) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(pw.MemoryImage(bytes), width: 280, height: 280),
                pw.SizedBox(height: 16),
                pw.Text(assetName, style: pw.TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
      );
      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } catch (e) {
      _showSnack('Could not open print dialog: $e', isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    final auth = context.watch<AuthProvider>();
    final assetsP = context.watch<AssetsProvider>();
    final asset = assetsP.getById(assetId);
    final uid = auth.user?.uid ?? '';

    if (asset == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: Text('Asset Details', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 18)),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E))),
      );
    }

    final qrData = 'https://safescan-cfe7e.web.app/found/$assetId';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Asset Details', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: asset.color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                    child: Icon(asset.icon, color: asset.color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(asset.name, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                        Text(asset.type, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => assetsP.toggleActive(uid, assetId, !asset.isActive),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: asset.isActive ? const Color(0xFF22C55E).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              asset.isActive ? '● Active — tap to deactivate' : '● Inactive — tap to activate',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: asset.isActive ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Text('QR Code', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Text('Display or print this QR code and stick it on your asset.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(16)),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E293B)),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1E293B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(assetId, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), letterSpacing: 1)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : () => _downloadQr(qrData, asset.name),
                          icon: _working
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Download'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _working ? null : () => _printQr(qrData, asset.name),
                          icon: _working
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.print_outlined, size: 18),
                          label: const Text('Print'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: const Color(0xFF22C55E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan Activity', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StatItem(value: '${asset.scanCount}', label: 'Total Scans'),
                      const _StatDivider(),
                      _StatItem(value: asset.isActive ? 'ON' : 'OFF', label: 'Status'),
                      const _StatDivider(),
                      _StatItem(
                        value: '${DateTime.now().difference(asset.createdAt).inDays}d',
                        label: 'Age',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('QR Code Active', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text(
                          asset.isActive
                              ? 'Anyone who scans this QR sees your details. Turn off to hide them temporarily.'
                              : 'Scanning this QR currently shows "inactive" — no details or chat are visible.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: asset.isActive,
                    activeColor: const Color(0xFF22C55E),
                    onChanged: (v) => assetsP.toggleActive(uid, assetId, v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remove Asset', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
                        Text('This will permanently delete this QR code.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _confirmDelete(context, uid, assetsP),
                    child: Text('Delete', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String uid, AssetsProvider assetsP) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Asset', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to permanently delete this asset and its QR code?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await assetsP.deleteAsset(uid, widget.assetId);
      if (context.mounted) context.pop();
    }
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: const Color(0xFFE2E8F0));
}
