import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chats_provider.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context, ChatModel chat) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Delete this conversation?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            content: Text('This will permanently delete your resolved chat about "${chat.assetName}".', style: GoogleFonts.inter()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter())),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chatsP = context.watch<ChatsProvider>();
    final uid = auth.user?.uid ?? '';
    final chats = chatsP.chats;

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
        title: Text('Inbox', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF0F172A))),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: chatsP.loading && chats.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)))
          : chatsP.error != null && chats.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load conversations:\n${chatsP.error}', textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFFEF4444))),
                  ),
                )
              : chats.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text('No conversations yet', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 6),
                        Text('When someone finds your asset and messages you, it\'ll show up here.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final chat = chats[i];
                    final row = GestureDetector(
                      onTap: () => context.push('/chat/${chat.id}'),
                      child: _ChatRow(chat: chat, uid: uid, timeAgo: _timeAgo(chat.lastMessageAt)),
                    );

                    if (!chat.isClosed) return row;

                    return Dismissible(
                      key: ValueKey(chat.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context, chat),
                      onDismissed: (_) async {
                        try {
                          await ChatService().deleteChat(chat.id);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not delete conversation: $e', style: GoogleFonts.inter()),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        }
                      },
                      child: row,
                    );
                  },
                ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final ChatModel chat;
  final String uid;
  final String timeAgo;
  const _ChatRow({required this.chat, required this.uid, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(chat.assetIcon, color: const Color(0xFF22C55E), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(chat.otherPartyName(uid), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(timeAgo, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 2),
                Text('About: ${chat.assetName}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF22C55E), fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(chat.lastMessageText, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          if (chat.isClosed)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: Text('RESOLVED', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
              ),
            ),
        ],
      ),
    );
  }
}
