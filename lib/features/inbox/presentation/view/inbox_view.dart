import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/inbox/presentation/view/chat_view.dart';

class InboxView extends StatefulWidget {
  const InboxView({super.key});

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  static const int _pageSize = 30;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isUserLoggedIn => _currentUserId.isNotEmpty;

  String _getChatId(String userId1, String userId2) {
    final List<String> ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openChat(String chatId, String otherUserId) async {
    if (!_isUserLoggedIn || otherUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to chat')),
        );
      }
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(otherUserId).get();
      final displayName = userDoc.data()?['displayName'] ?? 'User';
      final profilePic = userDoc.data()?['profilePicUrl'] ?? '';
      
      try {
        await _firestore.collection('chats').doc(chatId).update({
          'participantData.${otherUserId}.displayName': displayName,
          'participantData.${otherUserId}.profilePic': profilePic,
          'unreadCount.${_currentUserId}': 0,
        });
      } catch (_) {}

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatView(
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserDisplayName: displayName,
              otherUserProfilePic: profilePic,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening chat: $e')),
        );
      }
    }
  }

  Future<void> _startNewChat(String otherUserId) async {
    if (!_isUserLoggedIn || otherUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to start a chat')),
        );
      }
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(otherUserId).get();
      final displayName = userDoc.data()?['displayName'] ?? 'User';
      final profilePic = userDoc.data()?['profilePicUrl'] ?? '';
      
      final chatId = _getChatId(_currentUserId, otherUserId);
      
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (chatDoc.exists) {
        await _openChat(chatId, otherUserId);
        return;
      }

      final currentUserData = await _firestore.collection('users').doc(_currentUserId).get();
      final currentDisplayName = currentUserData.data()?['displayName'] ?? 
          FirebaseAuth.instance.currentUser?.displayName ?? 'You';
      final currentProfilePic = currentUserData.data()?['profilePicUrl'] ?? 
          FirebaseAuth.instance.currentUser?.photoURL ?? '';

      await _firestore.collection('chats').doc(chatId).set({
        'participants': [_currentUserId, otherUserId],
        'participantData': {
          _currentUserId: {
            'displayName': currentDisplayName,
            'profilePic': currentProfilePic,
          },
          otherUserId: {
            'displayName': displayName,
            'profilePic': profilePic,
          },
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': '',
        'unreadCount': {
          _currentUserId: 0,
          otherUserId: 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatView(
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserDisplayName: displayName,
              otherUserProfilePic: profilePic,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }

  int _getUnreadCount(Map<String, dynamic> chat) {
    final unread = chat['unreadCount']?[_currentUserId];
    if (unread is num) {
      return unread.toInt();
    }
    return 0;
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Now';
  }

  Widget _buildProfileImage(String imageUrl, double radius) {
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: NGColors.surfaceLight,
        child: Icon(Icons.person, color: NGColors.textMuted, size: radius * 1.2),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: NGColors.surfaceLight,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: NGColors.accent,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: NGColors.surfaceLight,
          child: Icon(Icons.person, color: NGColors.textMuted, size: radius * 1.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        elevation: 0,
        title: const Text(
          '💬 Inbox',
          style: TextStyle(
            color: NGColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: NGColors.textPrimary),
            onPressed: _isUserLoggedIn ? () => _showNewChatDialog() : null,
          ),
        ],
      ),
      body: !_isUserLoggedIn
          ? const Center(
              child: Text(
                'Please login to view messages',
                style: TextStyle(color: NGColors.textSecondary),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: NGColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      hintStyle: TextStyle(color: NGColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: NGColors.textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: NGColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: NGColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('chats')
                        .where('participants', arrayContains: _currentUserId)
                        .orderBy('lastMessageTime', descending: true)
                        .limit(_pageSize)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        final error = snapshot.error.toString();
                        if (error.contains('index')) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline, color: NGColors.textMuted, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  'Creating index...',
                                  style: TextStyle(color: NGColors.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Firestore is setting up the index.\nPlease wait a moment.',
                                  style: TextStyle(color: NGColors.textMuted),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }
                        return Center(
                          child: Text(
                            'Error loading chats: $error',
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
                        return _buildEmptyState();
                      }

                      final chatList = docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        data['id'] = doc.id;
                        return data;
                      }).toList();

                      final filteredChats = _searchQuery.isEmpty
                          ? chatList
                          : chatList.where((chat) {
                              final participants = chat['participantData'] as Map<String, dynamic>? ?? {};
                              final otherUserId = (chat['participants'] as List).firstWhere(
                                (id) => id != _currentUserId,
                                orElse: () => '',
                              );
                              final otherUserData = participants[otherUserId] as Map<String, dynamic>? ?? {};
                              final name = (otherUserData['displayName'] ?? '').toString().toLowerCase();
                              return name.contains(_searchQuery);
                            }).toList();

                      if (filteredChats.isEmpty && _searchQuery.isNotEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, color: NGColors.textMuted, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'No results for "$_searchQuery"',
                                style: TextStyle(color: NGColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemCount: filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = filteredChats[index];
                          final chatId = chat['id'];
                          final participants = List<String>.from(chat['participants'] ?? []);
                          final otherUserId = participants.firstWhere(
                            (id) => id != _currentUserId,
                            orElse: () => '',
                          );

                          if (otherUserId.isEmpty) return const SizedBox.shrink();

                          final participantData = chat['participantData'] as Map<String, dynamic>? ?? {};
                          final otherUserData = participantData[otherUserId] as Map<String, dynamic>? ?? {};
                          final displayName = otherUserData['displayName'] ?? 'User';
                          final profilePic = otherUserData['profilePic'] ?? '';
                          final lastMessage = chat['lastMessage'] ?? 'Start chatting...';
                          final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
                          
                          final unreadCount = _getUnreadCount(chat);

                          return GestureDetector(
                            onTap: () => _openChat(chatId, otherUserId),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: unreadCount > 0
                                    ? NGColors.surface
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: NGColors.divider.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildProfileImage(profilePic, 26),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                displayName,
                                                style: TextStyle(
                                                  color: NGColors.textPrimary,
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              _formatTime(lastMessageTime),
                                              style: TextStyle(
                                                color: NGColors.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                lastMessage,
                                                style: TextStyle(
                                                  color: unreadCount > 0
                                                      ? NGColors.textPrimary
                                                      : NGColors.textMuted,
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (unreadCount > 0)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(
                                                  color: NGColors.accent,
                                                  shape: BoxShape.circle,
                                                ),
                                                constraints: const BoxConstraints(
                                                  minWidth: 20,
                                                  minHeight: 20,
                                                ),
                                                child: Text(
                                                  unreadCount.toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: NGColors.accent,
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: _isUserLoggedIn ? () => _showNewChatDialog() : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: NGColors.textMuted,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              color: NGColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with someone!',
            style: TextStyle(
              color: NGColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isUserLoggedIn ? () => _showNewChatDialog() : null,
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('Find People'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NGColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog() {
    if (!_isUserLoggedIn) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _NewChatSheet(
        onUserSelected: _startNewChat,
      ),
    );
  }
}

// ============================================================
// _NewChatSheet - Dedicated widget with proper disposal
// ============================================================
class _NewChatSheet extends StatefulWidget {
  final void Function(String userId) onUserSelected;

  const _NewChatSheet({
    required this.onUserSelected,
  });

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isUserLoggedIn => _currentUserId.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildProfileImage(String imageUrl, double radius) {
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: NGColors.surfaceLight,
        child: Icon(Icons.person, color: NGColors.textMuted, size: radius * 1.2),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: NGColors.surfaceLight,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: NGColors.accent,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: NGColors.surfaceLight,
          child: Icon(Icons.person, color: NGColors.textMuted, size: radius * 1.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: NGColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NGColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'New Conversation',
            style: TextStyle(
              color: NGColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: NGColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name...',
              hintStyle: TextStyle(color: NGColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: NGColors.textMuted),
              filled: true,
              fillColor: NGColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .orderBy('displayName')
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: NGColors.accent),
                  );
                }

                final docs = snapshot.data!.docs;
                
                final filteredDocs = _searchQuery.isEmpty
                    ? docs
                    : docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['displayName'] ?? '').toString().toLowerCase();
                        final username = (data['username'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) || username.contains(_searchQuery);
                      }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, color: NGColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No users found'
                              : 'No results for "$_searchQuery"',
                          style: TextStyle(color: NGColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = doc.id;
                    
                    if (userId == _currentUserId) return const SizedBox.shrink();

                    final displayName = data['displayName'] ?? 'User';
                    final username = data['username'] ?? 'user';
                    final profilePic = data['profilePicUrl'] ?? '';

                    return ListTile(
                      leading: _buildProfileImage(profilePic, 22),
                      title: Text(
                        displayName,
                        style: const TextStyle(color: NGColors.textPrimary),
                      ),
                      subtitle: Text(
                        '@$username',
                        style: TextStyle(color: NGColors.textMuted, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onUserSelected(userId);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
