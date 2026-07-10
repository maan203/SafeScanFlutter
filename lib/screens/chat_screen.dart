import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/chat_model.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = ChatService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late Future<ChatModel?> _chatFuture;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _chatFuture = _service.getChat(widget.chatId);
  }

  Future<void> _send(String uid, String name) async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textCtrl.clear();
    try {
      await _service.sendMessage(widget.chatId, uid, name, text);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Close this chat?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Once closed, neither of you can send new messages. Use this once the item has been returned or the issue is resolved.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Close Chat', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.closeChat(widget.chatId);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid ?? '';
    final myName = auth.user?.name ?? 'Me';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
        titleSpacing: 0,
        title: FutureBuilder<ChatModel?>(
          future: _chatFuture,
          builder: (context, snapshot) {
            final chat = snapshot.data;
            if (chat == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(chat.otherPartyName(uid), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF0F172A))),
                Text('About: ${chat.assetName}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              ],
            );
          },
        ),
        centerTitle: false,
        actions: [
          FutureBuilder<ChatModel?>(
            future: _chatFuture,
            builder: (context, snapshot) {
              final chat = snapshot.data;
              if (chat == null || chat.isClosed) return const SizedBox.shrink();
              return TextButton(
                onPressed: _confirmClose,
                child: Text('Resolve', style: GoogleFonts.inter(color: const Color(0xFF22C55E), fontWeight: FontWeight.w700, fontSize: 13)),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: FutureBuilder<ChatModel?>(
        future: _chatFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load this chat:\n${snapshot.error}', textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFFEF4444))),
              ),
            );
          }
          final chat = snapshot.data;
          if (chat == null) {
            return Center(child: Text('Chat not found', style: GoogleFonts.inter()));
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(chat.assetIcon, color: const Color(0xFF22C55E), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(chat.assetName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A))),
                          Text(chat.assetType, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    if (chat.isClosed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                        child: Text('RESOLVED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<List<ChatMessageModel>>(
                  stream: _service.watchMessages(widget.chatId),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Could not load messages:\n${snap.error}', textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFFEF4444))),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)));
                    }
                    final messages = snap.data!;
                    if (messages.isEmpty) {
                      return Center(child: Text('No messages yet', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))));
                    }
                    return ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final msg = messages[messages.length - 1 - i];
                        final isMe = msg.senderId == uid;
                        return _MessageBubble(message: msg, isMe: isMe);
                      },
                    );
                  },
                ),
              ),

              if (!chat.isClosed)
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _send(uid, myName),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                          child: _sending
                              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
                  child: Text('This chat is resolved and closed.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  String _time(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF22C55E) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(message.senderName, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF22C55E))),
              ),
            Text(message.text, style: GoogleFonts.inter(fontSize: 14, color: isMe ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 3),
            Text(_time(message.createdAt), style: GoogleFonts.inter(fontSize: 10, color: isMe ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}
