import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/alerts_provider.dart';
import '../models/alert_model.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final alertsP = context.watch<AlertsProvider>();
    final alerts = alertsP.alerts;
    final uid = auth.user?.uid ?? '';
    final unreadCount = alertsP.unreadCount;

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
        title: Column(
          children: [
            Text('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF0F172A))),
            if (unreadCount > 0)
              Text('$unreadCount unread', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => alertsP.markAllRead(uid),
              child: Text('Mark all read', style: GoogleFonts.inter(color: const Color(0xFF22C55E), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: alertsP.loading && alerts.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)))
          : alerts.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return GestureDetector(
                      onTap: () {
                        if (!alert.isRead) alertsP.markRead(uid, alert.id);
                        final assetId = alert.assetId;
                        if (assetId == null) return;
                        if (alert.type == AlertType.scan || alert.type == AlertType.incident || alert.type == AlertType.emergency) {
                          context.push('/qr-detail/$assetId');
                        }
                      },
                      child: _AlertCard(alert: alert),
                    );
                  },
                ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  const _AlertCard({required this.alert});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: alert.isRead ? null : Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: alert.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(alert.icon, color: alert.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(alert.body, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(_timeAgo(alert.createdAt), style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          if (!alert.isRead)
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.notifications_none_rounded, size: 40, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 16),
          Text("All caught up!", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
          const SizedBox(height: 6),
          Text('No notifications yet', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
