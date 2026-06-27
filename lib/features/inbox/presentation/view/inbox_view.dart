// lib/features/inbox/presentation/view/inbox_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
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

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isUserLoggedIn => _currentUserId.isNotEmpty;

  // ===================== HELPER METHODS =====================

  String _getChatId(String userId1, String userId2) {
    final List<String> ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  int _getUnreadCount(Map<String, dynamic> chat) {
    final unread = chat['unreadCount']?[_currentUserId];
    if (unread is num) return unread.toInt();
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
            child: CircularProgressIndicator(color: NGColors.accent, strokeWidth: 2),
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

  // ===================== INBOX METHODS =====================

  Future<void> _openChat(String chatId, String otherUserId) async {
    if (!_isUserLoggedIn || otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to chat')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening chat: $e')),
      );
    }
  }

  Future<void> _startNewChat(String otherUserId) async {
    if (!_isUserLoggedIn || otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to start a chat')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $e')),
      );
    }
  }

  // ===================== NEW CHAT DIALOG =====================

  void _showNewChatDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NGColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final TextEditingController searchCtrl = TextEditingController();
        String searchQuery = '';

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
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
                  Text(
                    'New Conversation',
                    style: TextStyle(
                      color: NGColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    style: TextStyle(color: NGColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: TextStyle(color: NGColors.textMuted),
                      prefixIcon: Icon(Icons.search, color: NGColors.textMuted),
                      filled: true,
                      fillColor: NGColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setSheetState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .where('uid', isNotEqualTo: _currentUserId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading users',
                              style: TextStyle(color: NGColors.textMuted),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: NGColors.accent,
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        final users = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = (data['displayName'] ?? '').toString().toLowerCase();
                          final username = (data['username'] ?? '').toString().toLowerCase();
                          return name.contains(searchQuery) || username.contains(searchQuery);
                        }).toList();

                        if (users.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  color: NGColors.textMuted,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  searchQuery.isEmpty
                                      ? 'No other users found'
                                      : 'No results for "$searchQuery"',
                                  style: TextStyle(color: NGColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: users.length,
                          builder: (ctx, index) {
                            final doc = users[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final userId = doc.id;
                            final displayName = data['displayName'] ?? 'User';
                            final username = data['username'] ?? '';
                            final profilePic = data['profilePicUrl'] ?? '';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: NGColors.surfaceLight,
                                backgroundImage: profilePic.isNotEmpty
                                    ? CachedNetworkImageProvider(profilePic)
                                    : null,
                                child: profilePic.isEmpty
                                    ? Icon(Icons.person, color: NGColors.textMuted)
                                    : null,
                              ),
                              title: Text(
                                displayName,
                                style: TextStyle(color: NGColors.textPrimary),
                              ),
                              subtitle: username.isNotEmpty
                                  ? Text(
                                      '@$username',
                                      style: TextStyle(color: NGColors.textMuted),
                                    )
                                  : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                _startNewChat(userId);
                              },
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: NGColors.textMuted,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===================== NOTIFICATIONS SECTION =====================

  int _getNotificationCount() {
    // Simple count from Firestore
    // We'll build this properly in the UI
    return 0;
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

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: TabBar(
            indicatorColor: NGColors.accent,
            indicatorWeight: 3,
            labelColor: NGColors.textPrimary,
            unselectedLabelColor: NGColors.textMuted,
            tabs: const [
              Tab(text: '💬 Chats'),
              Tab(text: '🔔 Notifications'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add, color: NGColors.textPrimary),
              onPressed: _isUserLoggedIn ? _showNewChatDialog : null,
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
            : TabBarView(
                children: [
                  // ==================== CHATS TAB ====================
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: NGColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search conversations...',
                            hintStyle: const TextStyle(color: NGColors.textMuted),
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
                        child: _buildChatsList(),
                      ),
                    ],
                  ),
                  // ==================== NOTIFICATIONS TAB ====================
                  _buildNotificationsTab(),
                ],
              ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 80.0),
          child: FloatingActionButton(
            backgroundColor: NGColors.accent,
            child: const Icon(Icons.chat, color: Colors.white),
            onPressed: _isUserLoggedIn ? _showNewChatDialog : null,
          ),
        ),
      ),
    );
  }

  // ==================== CHATS LIST ====================

  Widget _buildChatsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading chats: ${snapshot.error}',
              style: const TextStyle(color: NGColors.textMuted),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: NGColors.accent),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyChatsState();

        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['lastMessageTime'] as Timestamp?;
          final bTime = bData['lastMessageTime'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        final chatList = sortedDocs.map((doc) {
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
                final username = (otherUserData['username'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || username.contains(_searchQuery);
              }).toList();

        if (filteredChats.isEmpty && _searchQuery.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, color: NGColors.textMuted, size: 48),
                const SizedBox(height: 16),
                Text(
                  'No results for "$_searchQuery"',
                  style: const TextStyle(color: NGColors.textSecondary),
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
                  color: unreadCount > 0 ? NGColors.surface : Colors.transparent,
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
                                style: const TextStyle(
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyChatsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            color: NGColors.textMuted,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              color: NGColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to start a new chat',
            style: TextStyle(
              color: NGColors.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showNewChatDialog,
            icon: const Icon(Icons.chat, color: Colors.white),
            label: const Text('Start Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NGColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== NOTIFICATIONS TAB ====================

  Widget _buildNotificationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading notifications',
              style: TextStyle(color: NGColors.textMuted),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: NGColors.accent),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _buildEmptyNotificationsState();
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final read = data['read'] ?? false;
            final actorUsername = data['actorUsername'] ?? 'Someone';
            final actorProfilePic = data['actorProfilePic'] ?? '';
            final type = data['type'] ?? 'like';
            final postType = data['postType'] ?? 'video';
            final content = data['content'] ?? '';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            String getDisplayText() {
              switch (type) {
                case 'like':
                  return 'liked your $postType';
                case 'comment':
                  return 'commented on your $postType';
                case 'follow':
                  return 'started following you';
                case 'mention':
                  return 'mentioned you in a $postType';
                case 'repost':
                  return 'reposted your $postType';
                default:
                  return 'interacted with you';
              }
            }

            String getEmoji() {
              switch (type) {
                case 'like':
                  return '❤️';
                case 'comment':
                  return '💬';
                case 'follow':
                  return '👤';
                case 'mention':
                  return '@';
                case 'repost':
                  return '🔁';
                default:
                  return '📌';
              }
            }

            String _timeAgo(DateTime? date) {
              if (date == null) return '';
              final now = DateTime.now();
              final diff = now.difference(date);
              if (diff.inDays > 0) return '${diff.inDays}d ago';
              if (diff.inHours > 0) return '${diff.inHours}h ago';
              if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
              return 'Just now';
            }

            return GestureDetector(
              onTap: () async {
                // Mark as read
                if (!read) {
                  await _firestore.collection('notifications').doc(docId).update({'read': true});
                }
                // Navigate (simplified)
                // Add navigation logic if needed
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: read ? Colors.transparent : NGColors.surface.withOpacity(0.5),
                  border: Border(
                    bottom: BorderSide(
                      color: NGColors.divider.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: NGColors.surfaceLight,
                      backgroundImage: actorProfilePic.isNotEmpty
                          ? CachedNetworkImageProvider(actorProfilePic)
                          : null,
                      child: actorProfilePic.isEmpty
                          ? Icon(Icons.person, color: NGColors.textMuted, size: 24)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '$actorUsername ',
                                  style: TextStyle(
                                    color: NGColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: getDisplayText(),
                                  style: TextStyle(
                                    color: read ? NGColors.textMuted : NGColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (content.isNotEmpty)
                            Text(
                              content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: NGColors.textMuted,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          Text(
                            _timeAgo(createdAt),
                            style: TextStyle(
                              color: NGColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: NGColors.surfaceLight,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        getEmoji(),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyNotificationsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_rounded,
            color: NGColors.textMuted,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: NGColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you when something happens',
            style: TextStyle(
              color: NGColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
