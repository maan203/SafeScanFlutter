import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/assets_provider.dart';
import '../models/asset_model.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();

  String _selectedType = 'Vehicle';
  bool _showPhone = true;
  bool _showEmail = true;

  final List<_AssetType> _types = [
    _AssetType(label: 'Vehicle', icon: Icons.directions_car_outlined),
    _AssetType(label: 'Bicycle', icon: Icons.pedal_bike_outlined),
    _AssetType(label: 'Laptop', icon: Icons.laptop_outlined),
    _AssetType(label: 'Bag', icon: Icons.backpack_outlined),
    _AssetType(label: 'Pet', icon: Icons.pets_outlined),
    _AssetType(label: 'Other', icon: Icons.inventory_2_outlined),
  ];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final assetsP = context.read<AssetsProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    final asset = AssetModel(
      id: '',
      name: _nameCtrl.text.trim(),
      type: _selectedType,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      rewardMessage: _rewardCtrl.text.trim().isEmpty ? null : _rewardCtrl.text.trim(),
      showPhone: _showPhone,
      showEmail: _showEmail,
      isActive: true,
      scanCount: 0,
      createdAt: DateTime.now(),
      userId: uid,
    );

    await assetsP.addAsset(uid, asset);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Asset added! QR code generated.', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetsP = context.watch<AssetsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Add New Asset', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 18)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asset Type', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF1E293B))),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final t = _types[i];
                    final isSelected = _selectedType == t.label;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = t.label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          boxShadow: isSelected
                              ? [BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(t.icon, color: isSelected ? Colors.white : const Color(0xFF64748B), size: 24),
                            const SizedBox(height: 6),
                            Text(t.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              _SectionCard(
                title: 'Asset Information',
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Asset name *',
                      prefixIcon: Icon(Icons.label_outlined, color: Color(0xFF94A3B8)),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Please enter the asset name' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: Icon(Icons.description_outlined, color: Color(0xFF94A3B8)),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _SectionCard(
                title: 'Contact Information',
                children: [
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ToggleRow(
                    label: 'Show phone number when scanned',
                    value: _showPhone,
                    onChanged: (v) => setState(() => _showPhone = v),
                  ),
                  const SizedBox(height: 8),
                  _ToggleRow(
                    label: 'Show email when scanned',
                    value: _showEmail,
                    onChanged: (v) => setState(() => _showEmail = v),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _SectionCard(
                title: 'Reward (Optional)',
                children: [
                  TextFormField(
                    controller: _rewardCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reward message',
                      prefixIcon: Icon(Icons.card_giftcard_outlined, color: Color(0xFF94A3B8)),
                      hintText: 'e.g. Reward for returning my bike',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              ElevatedButton.icon(
                onPressed: assetsP.loading ? null : _save,
                icon: assetsP.loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.qr_code_2_rounded, size: 20),
                label: Text(assetsP.loading ? 'Saving...' : 'Generate QR Code'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _rewardCtrl.dispose();
    super.dispose();
  }
}

class _AssetType {
  final String label;
  final IconData icon;
  const _AssetType({required this.label, required this.icon});
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF1E293B))),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)))),
        Switch.adaptive(value: value, onChanged: onChanged, activeColor: const Color(0xFF22C55E)),
      ],
    );
  }
}
