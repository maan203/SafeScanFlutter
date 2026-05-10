import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/assets_provider.dart';
import '../models/asset_model.dart';

class MyQrsScreen extends StatefulWidget {
  const MyQrsScreen({super.key});

  @override
  State<MyQrsScreen> createState() => _MyQrsScreenState();
}

class _MyQrsScreenState extends State<MyQrsScreen> {
  String _filter = 'All';
  final List<String> _filters = ['All', 'Active', 'Inactive'];

  List<AssetModel> _filtered(List<AssetModel> assets) {
    if (_filter == 'Active') return assets.where((a) => a.isActive).toList();
    if (_filter == 'Inactive') return assets.where((a) => !a.isActive).toList();
    return assets;
  }

  @override
  Widget build(BuildContext context) {
    final assetsP = context.watch<AssetsProvider>();
    final filtered = _filtered(assetsP.assets);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: Text('My QRs', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF0F172A))),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF22C55E), size: 26),
            onPressed: () => context.push('/add-asset'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: assetsP.loading && assetsP.assets.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: _filters.map((f) {
                    final selected = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(f, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF64748B))),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.qr_code_2_rounded, size: 48, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text('No ${_filter == 'All' ? '' : _filter.toLowerCase()} assets', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 6),
                        if (_filter == 'All')
                          ElevatedButton.icon(
                            onPressed: () => context.push('/add-asset'),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Asset'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 24)),
                          ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final asset = filtered[index];
                      return GestureDetector(
                        onTap: () => context.push('/qr-detail/${asset.id}'),
                        child: _QrCard(asset: asset),
                      );
                    },
                  ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order physical stickers', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text('Get weatherproof QR stickers delivered. Starting at ₹99.', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          minimumSize: const Size(130, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text('Order now', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final AssetModel asset;
  const _QrCard({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: asset.color.withValues(alpha: 0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Icon(asset.icon, color: asset.color, size: 28),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: QrImageView(
                data: 'https://safescan.app/scan/${asset.id}',
                version: QrVersions.auto,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Column(
              children: [
                Text(asset.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: asset.isActive ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    asset.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: asset.isActive ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
