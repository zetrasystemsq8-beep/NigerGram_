// lib/features/video_feed/presentation/view/discover_feed_view.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';

class DiscoverFeedView extends StatefulWidget {
  final String tag;
  const DiscoverFeedView({required this.tag, super.key});

  @override
  State<DiscoverFeedView> createState() => _DiscoverFeedViewState();
}

class _DiscoverFeedViewState extends State<DiscoverFeedView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<VideoEntity> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadByTag();
  }

  Future<void> _loadByTag() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _firestore.collection('videos').where('tags', arrayContains: widget.tag).limit(50).get();
      final videos = snap.docs.map((d) {
        final data = d.data();
        return VideoEntity(
          id: d.id,
          username: data['username'] ?? '',
          description: data['description'] ?? '',
          videoUrl: data['videoUrl'] ?? '',
          profileImageUrl: data['profileImageUrl'] ?? '',
          likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
          commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
          shareCount: (data['shareCount'] as num?)?.toInt() ?? 0,
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.tag}')),
      body: ListView.builder(
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          final v = _videos[index];
          return ListTile(
            leading: v.profileImageUrl.isNotEmpty ? CircleAvatar(backgroundImage: NetworkImage(v.profileImageUrl)) : const CircleAvatar(child: Icon(Icons.person)),
            title: Text('@${v.username}'),
            subtitle: Text(v.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () {
              // navigate to video detail or play
            },
          );
        },
      ),
    );
  }
}
