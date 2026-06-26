import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nigergram/core/design_system/colors.dart';

class ChatView extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserDisplayName;
  final String otherUserProfilePic;

  const ChatView({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserDisplayName,
    required this.otherUserProfilePic,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  void _markAsRead() async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'unreadCount.${_currentUserId}': 0,
      });
    } catch (_) {}
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'senderId': _currentUserId,
        'text': text,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [_currentUserId],
        'deliveredTo': [_currentUserId],
        'isDeleted': false,
      });

      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': _currentUserId,
        'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
      });

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: NGColors.surfaceLight,
              backgroundImage: widget.otherUserProfilePic.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherUserProfilePic)
                  : null,
              child: widget.otherUserProfilePic.isEmpty
                  ? Icon(Icons.person, color: NGColors.textMuted, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherUserDisplayName,
              style: const TextStyle(
                color: NGColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: NGColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages',
                      style: TextStyle(color: NGColors.textMuted),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: NGColors.accent),
                  );
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: NGColors.textMuted,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: NGColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Say hello! 👋',
                          style: TextStyle(
                            color: NGColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUserId;
                    final text = data['text'] ?? '';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final date = timestamp?.toDate();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment:
                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: widget.otherUserProfilePic.isNotEmpty
                                  ? CachedNetworkImageProvider(widget.otherUserProfilePic)
                                  : null,
                              child: widget.otherUserProfilePic.isEmpty
                                  ? Icon(Icons.person, color: NGColors.textMuted, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? NGColors.accent
                                    : NGColors.surface,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft:
                                      isMe ? const Radius.circular(12) : Radius.zero,
                                  bottomRight:
                                      isMe ? Radius.zero : const Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    text,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : NGColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(date),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white.withOpacity(0.7)
                                          : NGColors.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: NGColors.surface,
              border: Border(
                top: BorderSide(
                  color: NGColors.divider.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: NGColors.textMuted),
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: NGColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: NGColors.textMuted),
                      filled: true,
                      fillColor: NGColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: NGColors.accent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
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
