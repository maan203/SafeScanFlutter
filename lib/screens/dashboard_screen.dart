import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/assets_provider.dart';
import '../providers/alerts_provider.dart';
import '../providers/chats_provider.dart';
import '../models/asset_model.dart';
import '../models/alert_model.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning 👋';
    if (h < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final assetsP = context.watch<AssetsProvider>();
    final alertsP = context.watch<AlertsProvider>();
    final chatsP = context.watch<ChatsProvider>();

    final assets = assetsP.assets;
    final recentAlerts = alertsP.alerts.take(3).toList();
    final userName = auth.user?.name ?? 'User';
    final unreadCount = alertsP.unreadCount;
    final openChatCount = chatsP.openCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: const Color(0xFF1E293B),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_greeting(), style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13)),
                                Text(userName, style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => context.push('/inbox'),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                                      ),
                                      if (openChatCount > 0)
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                                            child: Center(
                                              child: Text(
                                                openChatCount > 9 ? '9+' : '$openChatCount',
                                                style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => context.push('/alerts'),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                                      ),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                                            child: Center(
                                              child: Text(
                                                unreadCount > 9 ? '9+' : '$unreadCount',
                                                style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Protection Active', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                  Text('${assets.length} asset${assets.length == 1 ? '' : 's'} monitored', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // SOS banner
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => context.push('/sos'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.warning_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Emergency SOS', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                          Text('Hold to alert your contacts', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
                  ],
                ),
              ),
            ),
          ),

          // Quick actions
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _QuickBtn(icon: Icons.add_rounded, label: 'Add QR', onTap: () => context.push('/add-asset')),
                  _QuickBtn(icon: Icons.phone_outlined, label: 'Contacts', onTap: () => context.push('/emergency-contacts')),
                  _QuickBtn(icon: Icons.location_on_outlined, label: 'Location', onTap: () => context.push('/live-location')),
                ],
              ),
            ),
          ),

          // Assets header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Assets', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                  GestureDetector(
                    onTap: () => context.push('/my-qrs'),
                    child: Text('View all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF22C55E))),
                  ),
                ],
              ),
            ),
          ),

          // Assets list or empty state
          if (assetsP.loading && assets.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFF22C55E)),
                ),
              ),
            )
          else if (assets.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 48, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 12),
                    Text('No assets yet', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Text('Add your first asset to start protecting it', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/add-asset'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Asset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AssetCard(
                      asset: assets[i],
                      onTap: () => context.push('/qr-detail/${assets[i].id}'),
                    ),
                  ),
                  childCount: assets.take(3).length,
                ),
              ),
            ),

          // Recent Activity header
          if (recentAlerts.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Activity', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    GestureDetector(
                      onTap: () => context.push('/alerts'),
                      child: Text('All', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF22C55E))),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ActivityCard(alert: recentAlerts[i]),
                  ),
                  childCount: recentAlerts.length,
                ),
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: const Color(0xFF1E293B), size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        ],
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  final AssetModel asset;
  final VoidCallback onTap;
  const _AssetCard({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: asset.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(asset.icon, color: asset.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A))),
                  Text(asset.type, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${asset.scanCount} scans', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: asset.isActive ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    asset.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: asset.isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final AlertModel alert;
  const _ActivityCard({required this.alert});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: alert.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(alert.icon, color: alert.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF0F172A))),
                Text(
                  alert.location != null ? '${alert.location} · ${_timeAgo(alert.createdAt)}' : _timeAgo(alert.createdAt),
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (!alert.isRead)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
