

// lib/features/profile/presentation/view/profile_view.dart
//
// ╔══════════════════════════════════════════════════════════╗
// ║  NIGERGRAM PROFILE — THE ULTIMATE SOCIAL PROFILE      ║
// ║  Better Than TikTok • Better Than Douyin              ║
// ║  Built For Nigeria • Ready For The World             ║
// ╚══════════════════════════════════════════════════════════╝

import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Helper utilities for image uploads
String _extensionOrDefault(String path) {
  final p = path.toLowerCase();
  if (p.endsWith('.png')) return 'png';
  if (p.endsWith('.webp')) return 'webp';
  if (p.endsWith('.gif')) return 'gif';
  if (p.endsWith('.heic')) return 'heic';
  // default to jpeg
  return 'jpg';
}

String _mimeForExt(String ext) {
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'heic':
      return 'image/heic';
    case 'jpg':
    default:
      return 'image/jpeg';
  }
}

String _uniqueUserImagePath(String userId, String prefix, String ext) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final rnd = (DateTime.now().microsecond % 1000000).toString().padLeft(6, '0');
  return 'users/$userId/$prefix\_$ts\_$rnd.$ext';
}

// ────────────────────────────────────────────────────────────────�[...] 
// DESIGN SYSTEM
// ────────────────────────────────────────────────────────────────�[...] 

class NGColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0F0F14);
  static const surfaceLight = Color(0xFF1A1A24);
  static const accent = Color(0xFFFF0050);
  static const accentGold = Color(0xFFFFD700);
  static const accentBlue = Color(0xFF0088FF);
  static const accentPurple = Color(0xFF8B00FF);
  static const accentGreen = Color(0xFF00C853);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0B8);
  static const textMuted = Color(0xFF6A6A74);
  static const divider = Color(0xFF1E1E28);
  static const success = Color(0xFF00C853);
  static const error = Color(0xFFFF1744);
  static const warning = Color(0xFFFFD600);
}

// ────────────────────────────────────────────────────────────────�[...] 
// MAIN WIDGET
// ────────────────────────────────────────────────────────────────�[...] 

class ProfileView extends StatefulWidget {
  final String? userId;
  const ProfileView({super.key, this.userId});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with TickerProviderStateMixin {
  
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  late AnimationController _storyPulseController;
  late Animation<double> _storyPulseAnimation;
  late AnimationController _storyRotateController;
  late Animation<double> _storyRotateAnimation;
  
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _walletData;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isCurrentUser = true;
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _isFollowLoading = false;
  bool _isUploadingContent = false;
  double _uploadProgress = 0.0;
  String _uploadLabel = '';
  bool _isTabLoading = false;
  bool _hasActiveStory = false;
  int _storyCount = 0;
  double _walletBalance = 0.0;
  String _walletCurrency = 'NGN';
  String _profileTheme = 'default';
  Color _accentColor = NGColors.accent;
  List<Map<String, dynamic>> _achievements = [];
  bool _allowDuet = true;
  bool _allowStitch = true;
  bool _allowDownload = true;
  
  List<Map<String, dynamic>> _pinnedVideos = [];
  List<Map<String, dynamic>> _userVideos = [];
  List<Map<String, dynamic>> _privateVideos = [];
  List<Map<String, dynamic>> _bookmarkedVideos = [];
  List<Map<String, dynamic>> _likedVideos = [];
  List<Map<String, dynamic>> _draftVideos = [];
  List<Map<String, dynamic>> _qaItems = [];
  
  static const int _pageSize = 18;
  DocumentSnapshot? _lastVideoDoc;
  bool _hasMoreVideos = true;
  bool _isLoadingMore = false;
  
  // 🔥 FIX: Null-safe current user
  String get _targetUserId {
    final user = FirebaseAuth.instance.currentUser;
    return widget.userId ?? user?.uid ?? '';
  }
  
  String get _currentUid {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }
  
  final _supabase = Supabase.instance.client;

  // rest of file unchanged...
