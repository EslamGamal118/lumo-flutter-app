import 'package:flutter/material.dart';

import '../../../data/models/post_model.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../core/di/dependency_injection.dart';

class CommunityViewModel extends ChangeNotifier {
  final CommunityRepository _repository;

  CommunityViewModel(this._repository);

  bool _isDisposed = false;

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  List<PostModel> _posts = [];
  List<PostModel> _explorePosts = [];
  List<PostModel> _followingPosts = [];
  List<PostModel> _myPosts = [];
  List<CommentModel> _comments = [];
  List<UserModel> _searchResults = [];
  List<int> _followedUserIds = [];
  List<UserModel> _followingUsers = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  CommentModel? _replyingToComment;
  int? _currentUserId;

  List<PostModel> get posts => _posts;
  List<PostModel> get explorePosts => _explorePosts;
  List<PostModel> get followingPosts => _followingPosts;
  List<PostModel> get myPosts => _myPosts;
  List<CommentModel> get comments => _comments;
  List<UserModel> get searchResults => _searchResults;
  List<UserModel> get followingUsers => _followingUsers;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  CommentModel? get replyingToComment => _replyingToComment;

  void setReplyingTo(CommentModel? comment) {
    _replyingToComment = comment;
    _safeNotify();
  }

  bool isFollowing(int userId) => _followedUserIds.contains(userId);
  int get followingCount => _followedUserIds.length;

  void resetState() {
    _posts = [];
    _explorePosts = [];
    _followingPosts = [];
    _myPosts = [];
    _comments = [];
    _searchResults = [];
    _followedUserIds = [];
    _followingUsers = [];
    _isLoading = false;
    _isInitialized = false;
    _errorMessage = null;
    _replyingToComment = null;
    _currentUserId = null;
    _safeNotify();
  }

  PostModel? findPostById(int id) {
    for (var list in [_explorePosts, _posts, _followingPosts, _myPosts]) {
      final index = list.indexWhere((p) => p.id == id);
      if (index != -1) return list[index];
    }
    return null;
  }

  Future<void> fetchPostById(int postId) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final post = await _repository.getPostById(postId);
      _updatePostEverywhere(post);
    } catch (e) {
      _errorMessage = 'فشل تحميل المنشور: ${e.toString()}';
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> fetchPosts({bool force = false, int? userId}) async {
    if (userId != null && userId != _currentUserId) {
      _currentUserId = userId;
      _isInitialized = false;
      _posts = [];
      _explorePosts = [];
      _followingPosts = [];
      _myPosts = [];
      _followedUserIds = [];
      force = true;
    } else if (userId != null) {
      _currentUserId = userId;
    }

    if (_isInitialized && !force && _posts.isNotEmpty) {
      _loadAllFeeds(rethrowError: false);
      return;
    }

    if (force) _isInitialized = false;

    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await _loadAllFeeds(rethrowError: true);
      _isInitialized = true;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socketexception') ||
          errorStr.contains('connection') ||
          errorStr.contains('network') ||
          errorStr.contains('timeout')) {
        _errorMessage = 'لا يوجد اتصال بالإنترنت، يرجى التحقق من اتصالك';
      } else {
        _errorMessage = 'فشل تحميل المنشورات: ${e.toString()}';
      }
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> _loadAllFeeds({bool rethrowError = false}) async {
    try {
      await _loadMyPostsInternal(page: 1);
      
      await _loadFollowingIdsInternal(); // Must happen before following feed
      
      await Future.wait([
        _loadHomeFeedInternal(page: 1),
        _loadExploreFeedInternal(page: 1),
        _loadFollowingFeedInternal(page: 1),
      ]);
    } catch (e) {
      if (rethrowError) rethrow;
    }
  }

  Future<void> _loadFollowingIdsInternal() async {
    try {
      _followingUsers = await _repository.getFollowingUsers();
      _followedUserIds = _followingUsers.map((u) => u.id).toList();
      _safeNotify();
    } catch (e) {
      debugPrint('Error loading following IDs: $e');
    }
  }

  /// Fetches the following list only if it hasn't been loaded yet.
  /// Safe to call from any screen without triggering redundant API calls.
  Future<void> loadFollowingIfNeeded() async {
    if (_followingUsers.isNotEmpty) return;
    await _loadFollowingIdsInternal();
  }

  Future<void> _loadHomeFeedInternal({int page = 1}) async {
    final feed = await _repository.getHomeFeed(page: page);
    if (page == 1) {
      final List<PostModel> merged = [...feed];
      for (var myPost in _myPosts) {
        if (!merged.any((p) => p.id == myPost.id)) {
          merged.insert(0, myPost);
        }
      }
      _posts = merged;
    } else {
      _posts.addAll(feed);
    }
  }

  Future<void> _loadExploreFeedInternal({int page = 1}) async {
    final feed = await _repository.getExploreFeed(page: page);
    if (page == 1) {
      _explorePosts = feed;
      _posts = feed;
    } else {
      _explorePosts.addAll(feed);
      _posts.addAll(feed);
    }
  }

  Future<void> _loadFollowingFeedInternal({int page = 1}) async {
    final feed = await _repository.getHomeFeed(page: page);
    if (page == 1) {
      _followingPosts = feed
          .where((post) => _followedUserIds.contains(post.userId))
          .toList();
    } else {
      _followingPosts.addAll(
        feed.where((post) => _followedUserIds.contains(post.userId)).toList(),
      );
    }
    _safeNotify();
  }

  Future<void> _loadMyPostsInternal({int page = 1}) async {
    final posts = await _repository.getMyPosts(page: page);
    if (page == 1) {
      _myPosts = posts;
    } else {
      _myPosts.addAll(posts);
    }
  }

  Future<void> initCommunity(int? userId, {bool force = false}) async {
    return fetchPosts(force: force, userId: userId);
  }

  Future<void> loadExploreFeed({int page = 1, bool rethrowError = false}) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await _loadExploreFeedInternal(page: page);
      _isLoading = false;
      _safeNotify();
    } catch (e) {
      _errorMessage = 'فشل تحميل الاستكشاف: ${e.toString()}';
      _isLoading = false;
      _safeNotify();
      if (rethrowError) rethrow;
    }
  }

  Future<void> fetchExplorePosts() => loadExploreFeed();

  Future<void> loadHomeFeed({int page = 1, bool rethrowError = false}) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await _loadHomeFeedInternal(page: page);
      _isLoading = false;
      _safeNotify();
    } catch (e) {
      _errorMessage = 'فشل تحميل الخلاصة: ${e.toString()}';
      _isLoading = false;
      _safeNotify();
      if (rethrowError) rethrow;
    }
  }

  Future<void> loadFollowingFeed({int page = 1, bool rethrowError = false}) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await _loadFollowingFeedInternal(page: page);
      _isLoading = false;
      _safeNotify();
    } catch (e) {
      _errorMessage = 'فشل تحميل منشورات المتابعة: ${e.toString()}';
      _isLoading = false;
      _safeNotify();
      if (rethrowError) rethrow;
    }
  }

  Future<void> loadMyPosts({int page = 1, bool rethrowError = false}) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await _loadMyPostsInternal(page: page);
      _isLoading = false;
      _safeNotify();
    } catch (e) {
      _errorMessage = 'فشل تحميل منشوراتي: ${e.toString()}';
      _isLoading = false;
      _safeNotify();
      if (rethrowError) rethrow;
    }
  }

  Future<bool> createPost({
    required String content,
    required String? imagePath,
    String? currentUserName,
    String? currentUserAvatar,
    int? currentUserId,
  }) async {
    _currentUserId = currentUserId;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();
    try {
      final postResponse = await _repository.createPost(
        content: content,
        imagePath: imagePath,
      );

      String? finalName = currentUserName;
      String? finalAvatar = currentUserAvatar;
      int? finalId = currentUserId;

      if (finalName == null || finalId == null) {
        try {
          final authProvider = getIt<AuthProvider>();
          final user = authProvider.currentUser;
          if (user != null) {
            finalName ??= user.name;
            finalAvatar ??= user.avatarUrl;
            finalId ??= user.id;
          }
        } catch (e) {
          debugPrint('Could not get AuthProvider for post injection: $e');
        }
      }

      final post = postResponse.copyWith(
        userName: (finalName != null && finalName.isNotEmpty) 
            ? finalName 
            : (postResponse.userName.isEmpty ? 'مستخدم' : postResponse.userName),
        userAvatarUrl: finalAvatar ?? postResponse.userAvatarUrl,
        userId: finalId ?? postResponse.userId,
      );

      _posts.insert(0, post);
      _explorePosts.insert(0, post);
      _myPosts.insert(0, post);
      _followingPosts.insert(0, post);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  void updateAuthorInfoInPosts(int userId, String name, String? avatarUrl) {
    void updateList(List<PostModel> list) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].userId == userId) {
          list[i] = list[i].copyWith(userName: name, userAvatarUrl: avatarUrl);
        }
      }
    }

    updateList(_posts);
    updateList(_followingPosts);
    updateList(_myPosts);
    _safeNotify();
  }

  Future<void> deletePost(int postId) async {
    try {
      await _repository.deletePost(postId);
      _removePostEverywhere(postId);
    } catch (e) {
      _errorMessage = 'فشل حذف المنشور';
      _safeNotify();
    }
  }

  Future<void> updatePost(int postId, String newContent, {String? imagePath}) async {
    try {
      final updated = await _repository.updatePost(postId, content: newContent, imagePath: imagePath);
      _updatePostEverywhere(updated);
    } catch (e) {
      _errorMessage = 'فشل تحديث المنشور';
      _safeNotify();
    }
  }

  Future<void> toggleLike(int postId) async {
    final post = findPostById(postId);
    if (post == null) return;

    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final isLiked = post.isLikedBy(currentUserId);
    
    final updatedLikedByIds = List<int>.from(post.likedByUserIds);
    if (isLiked) {
      updatedLikedByIds.remove(currentUserId);
    } else {
      updatedLikedByIds.add(currentUserId);
    }

    final updatedPost = post.copyWith(
      isLiked: !isLiked,
      likesCount: !isLiked ? post.likesCount + 1 : post.likesCount - 1,
      likedByUserIds: updatedLikedByIds,
    );

    _updatePostEverywhere(updatedPost);

    try {
      await _repository.toggleLike(postId);
    } catch (e) {
      _updatePostEverywhere(post);
      _errorMessage = 'فشل التفاعل مع المنشور: ${e.toString()}';
      _safeNotify();
    }
  }

  Future<void> fetchComments(int postId) async {
    _isLoading = true;
    _errorMessage = null;
    _comments = [];
    _safeNotify();

    try {
      _comments = await _repository.getComments(postId);
    } catch (e) {
      _errorMessage = 'فشل تحميل التعليقات: ${e.toString()}';
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> addComment(int postId, String content, {int? parentId}) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await _repository.addComment(postId, content, parentId: parentId);
      // Refresh comments after adding
      _comments = await _repository.getComments(postId);
      
      // Update comment count in posts
      final post = findPostById(postId);
      if (post != null) {
        _updatePostEverywhere(post.copyWith(
          commentsCount: post.commentsCount + 1,
        ));
      }
    } catch (e) {
      _errorMessage = 'فشل إضافة التعليق: ${e.toString()}';
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> toggleCommentLike(int commentId, {int? currentUserId}) async {
    final index = _comments.indexWhere((c) => c.id == commentId);
    if (index == -1) return;

    final comment = _comments[index];
    final isLiked = comment.isLikedBy(currentUserId);
    
    // Optimistic Update
    final newLikesCount = isLiked ? comment.likesCount - 1 : comment.likesCount + 1;
    
    final newLikedByUserIds = List<int>.from(comment.likedByUserIds);
    if (currentUserId != null) {
      if (isLiked) {
        newLikedByUserIds.remove(currentUserId);
      } else {
        if (!newLikedByUserIds.contains(currentUserId)) {
          newLikedByUserIds.add(currentUserId);
        }
      }
    }

    final updatedComment = comment.copyWith(
      isLiked: !isLiked,
      likesCount: newLikesCount >= 0 ? newLikesCount : 0,
      likedByUserIds: newLikedByUserIds,
    );
    
    _comments[index] = updatedComment;
    _safeNotify();

    try {
      await _repository.toggleCommentLike(commentId);
    } catch (e) {
      _errorMessage = 'فشل التفاعل مع التعليق: ${e.toString()}';
      _comments[index] = comment; // Revert
      _safeNotify();
    }
  }

  void _updatePostEverywhere(PostModel updatedPost) {
    void updateList(List<PostModel> list) {
      final index = list.indexWhere((p) => p.id == updatedPost.id);
      if (index != -1) {
        list[index] = updatedPost;
      }
    }

    updateList(_posts);
    updateList(_explorePosts);
    updateList(_followingPosts);
    updateList(_myPosts);
    _safeNotify();
  }

  void _removePostEverywhere(int postId) {
    void removeFromList(List<PostModel> list) {
      list.removeWhere((p) => p.id == postId);
    }

    removeFromList(_posts);
    removeFromList(_explorePosts);
    removeFromList(_followingPosts);
    removeFromList(_myPosts);
    _safeNotify();
  }

  // Social
  Future<void> toggleFollow(int userId, {int? currentUserId, Function(bool isNowFollowing)? onFollowingCountChanged}) async {
    // Cannot follow self
    if (userId == _currentUserId || userId == currentUserId) return;

    final wasFollowing = _followedUserIds.contains(userId);

    // 1. Optimistic UI Update
    if (wasFollowing) {
      _followedUserIds.remove(userId);
      _followingPosts.removeWhere((p) => p.userId == userId);
    } else {
      _followedUserIds.add(userId);
    }
    
    _safeNotify();
    onFollowingCountChanged?.call(!wasFollowing);

    try {
      // 2. Call API
      await _repository.toggleFollow(userId,
          currentUserId: currentUserId, isFollowing: wasFollowing);

      // 3. Background sync — server truth after delay
      Future.delayed(const Duration(seconds: 2), () async {
        if (_isDisposed) return;
        try {
          final followingUsers = await _repository.getFollowingUsers();
          if (_isDisposed) return;
          _followedUserIds = followingUsers.map((u) => u.id).toList();
          _followingUsers = followingUsers;
          _safeNotify();
        } catch (_) {}
      });
    } catch (e) {
      // 4. Rollback
      if (wasFollowing) {
        _followedUserIds.add(userId);
      } else {
        _followedUserIds.remove(userId);
      }
      onFollowingCountChanged?.call(wasFollowing);
      _errorMessage = 'فشل تحديث المتابعة';
      _safeNotify();
    }
  }

  void setFollowingState(int userId, bool isNowFollowing) {
    if (isNowFollowing) {
      if (!_followedUserIds.contains(userId)) {
        _followedUserIds.add(userId);
      }
    } else {
      _followedUserIds.remove(userId);
    }
    _safeNotify();
  }

  Future<void> searchUsers(String query, {String? role}) async {
    _isLoading = true;
    _safeNotify();
    try {
      _searchResults = await _repository.searchUsers(query, role: role);
      _isLoading = false;
      _safeNotify();
    } catch (e) {
      _errorMessage = 'فشل البحث: ${e.toString()}';
      _isLoading = false;
      _safeNotify();
    }
  }

  void clearError() {
    _errorMessage = null;
    _safeNotify();
  }
}
