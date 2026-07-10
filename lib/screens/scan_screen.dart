import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/assets_provider.dart';
import '../models/asset_model.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final assetsP = context.watch<AssetsProvider>();
    final assets = assetsP.assets;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Scan & Register', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF16A34A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('Scan a SafeScan QR Code', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Text(
                    'Point your camera at a SafeScan sticker to view asset details and contact the owner.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScannerPage())),
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text('Open Camera Scanner'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My QR Codes', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                GestureDetector(
                  onTap: () => context.push('/my-qrs'),
                  child: Text('View all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF22C55E))),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (assetsP.loading && assets.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF22C55E))))
            else if (assets.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 48, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      Text('No QR codes yet', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Text('Add an asset to generate your first QR code', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              )
            else
              ...assets.take(3).map((asset) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QrCodeCard(asset: asset, onTap: () => context.push('/qr-detail/${asset.id}')),
              )),
          ],
        ),
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  MobileScannerController controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan QR Code', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_hasScanned) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final value = barcodes.first.rawValue;
              if (value == null) return;
              _hasScanned = true;
              controller.stop();
              _handleScanned(value);
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF22C55E), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text('Align QR code within the frame', textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _handleScanned(String value) {
    Navigator.pop(context);
    // If it's a SafeScan URL, extract the asset ID and open the public
    // "found this item" view — works whether you own the asset or not.
    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'found') {
      final assetId = uri.pathSegments[1];
      context.push('/found/$assetId');
    } else {
      // Show raw QR value
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('QR Code Scanned', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Text(value, style: GoogleFonts.inter()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('OK', style: GoogleFonts.inter())),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _QrCodeCard extends StatelessWidget {
  final AssetModel asset;
  final VoidCallback onTap;

  const _QrCodeCard({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            QrImageView(
              data: 'https://safescan-cfe7e.web.app/found/${asset.id}',
              version: QrVersions.auto,
              size: 72,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E293B)),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1E293B)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(asset.type, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: asset.isActive ? const Color(0xFF22C55E).withOpacity(0.1) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      asset.isActive ? 'ACTIVE' : 'INACTIVE',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: asset.isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
                    ),
                  ),
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
