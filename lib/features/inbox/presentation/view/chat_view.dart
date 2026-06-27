// lib/features/inbox/presentation/view/chat_view.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
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

  bool _isSendingImage = false;
  bool _isOtherUserTyping = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _markAsRead();
    _listenToTypingStatus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _setTypingStatus(false);
    super.dispose();
  }

  void _listenToTypingStatus() {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      final typingMap = data['typing'] as Map<String, dynamic>? ?? {};
      final isTyping = typingMap[widget.otherUserId] == true;
      if (isTyping != _isOtherUserTyping) {
        setState(() {
          _isOtherUserTyping = isTyping;
        });
      }
    });
  }

  void _setTypingStatus(bool isTyping) {
    if (_isTyping == isTyping) return;
    _isTyping = isTyping;
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'typing.${_currentUserId}': isTyping,
    }).catchError((_) {});
  }

  void _onTextChanged(String text) {
    if (!_isTyping) {
      _setTypingStatus(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTypingStatus(false);
    });
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
    _setTypingStatus(false);

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
        'typing.${_currentUserId}': false,
      });

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isSendingImage = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bytes = await File(picked.path).readAsBytes();
      final fileName =
          'chat_images/${widget.chatId}_${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';

      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(fileName, bytes, fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ));

      final imageUrl = Supabase.instance.client.storage
          .from('images')
          .getPublicUrl(fileName);

      await _sendImageMessage(imageUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send image: ${e.toString()}'),
          backgroundColor: NGColors.error,
        ),
      );
    } finally {
      setState(() => _isSendingImage = false);
    }
  }

  Future<void> _sendImageMessage(String imageUrl) async {
    final messageRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'senderId': _currentUserId,
      'text': '',
      'type': 'image',
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [_currentUserId],
      'deliveredTo': [_currentUserId],
      'isDeleted': false,
    });

    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'lastMessage': '📷 Image',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': _currentUserId,
      'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
    });

    _scrollToBottom();
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: EdgeInsets.zero,
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: NGColors.accent),
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.broken_image,
                color: NGColors.textMuted,
                size: 60,
              ),
            ),
          ),
        ),
      ),
    );
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

  void _navigateToProfile() {
    context.push('/profile/${widget.otherUserId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        elevation: 0,
        title: GestureDetector(
          onTap: _navigateToProfile,
          child: Row(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserDisplayName,
                    style: const TextStyle(
                      color: NGColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_isOtherUserTyping)
                    Text(
                      'Typing...',
                      style: TextStyle(
                        color: NGColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
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
                    final type = data['type'] ?? 'text';

                    Widget messageWidget;
                    if (type == 'image') {
                      final imageUrl = data['imageUrl'] ?? '';
                      messageWidget = GestureDetector(
                        onTap: () => _showFullImage(imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 200,
                              height: 200,
                              color: NGColors.surfaceLight,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: NGColors.accent,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 200,
                              height: 200,
                              color: NGColors.surfaceLight,
                              child: const Icon(
                                Icons.broken_image,
                                color: NGColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    } else {
                      final text = data['text'] ?? '';
                      messageWidget = Text(
                        text,
                        style: TextStyle(
                          color: isMe ? Colors.white : NGColors.textPrimary,
                          fontSize: 14,
                        ),
                      );
                    }

                    final timestamp = data['timestamp'] as Timestamp?;
                    final date = timestamp?.toDate();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment:
                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            GestureDetector(
                              onTap: _navigateToProfile,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundImage: widget.otherUserProfilePic.isNotEmpty
                                    ? CachedNetworkImageProvider(widget.otherUserProfilePic)
                                    : null,
                                child: widget.otherUserProfilePic.isEmpty
                                    ? Icon(Icons.person, color: NGColors.textMuted, size: 16)
                                    : null,
                              ),
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
                                  messageWidget,
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
                  icon: _isSendingImage
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: NGColors.accent,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.photo_camera, color: NGColors.textMuted),
                  onPressed: _isSendingImage ? null : _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: NGColors.textPrimary),
                    onChanged: _onTextChanged,
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
