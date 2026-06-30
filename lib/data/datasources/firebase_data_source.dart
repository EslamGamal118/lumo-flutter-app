import '../../core/services/firebase_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/firebase_firestore_service.dart';
import '../../core/services/firebase_storage_service.dart';
import '../../core/utils/firebase_collections.dart';
import '../../core/utils/debug_logger.dart';

class FirebaseDataSource {
  final FirebaseAuthService _authService;
  final FirebaseFirestoreService _firestoreService;
  final FirebaseStorageService _storageService;

  FirebaseDataSource(
      this._authService,
      this._firestoreService,
      this._storageService,
      );

  // ==================== AUTHENTICATION ====================

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    final userCredential = await _authService.signUpWithEmailAndPassword(
      email: email,
      password: password,
    );

    final userId = userCredential.user!.uid;
    userData['id'] = userId;

    await _firestoreService.createDocument(
      collection: FirebaseCollections.users,
      docId: userId,
      data: userData,
    );

    return userData;
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final userCredential = await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final userId = userCredential.user!.uid;
    final userData = await _firestoreService.getDocument(
      collection: FirebaseCollections.users,
      docId: userId,
    );

    return userData!;
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  String? get currentUserId => _authService.currentUserId;

  // ==================== USER OPERATIONS ====================

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    return await _firestoreService.getDocument(
      collection: FirebaseCollections.users,
      docId: userId,
    );
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await _firestoreService.updateDocument(
      collection: FirebaseCollections.users,
      docId: userId,
      data: data,
    );
  }

  Future<void> deleteUser(String userId) async {
    await _firestoreService.deleteDocument(
      collection: FirebaseCollections.users,
      docId: userId,
    );
    await _authService.deleteAccount();
  }

  Stream<Map<String, dynamic>?> streamUser(String userId) {
    return _firestoreService.streamDocument(
      collection: FirebaseCollections.users,
      docId: userId,
    );
  }

  // ==================== POST OPERATIONS ====================

  Future<String> createPost(Map<String, dynamic> postData) async {
    final instance = _firestoreService.instance;
    if (instance == null) {
      debugPrint('Firebase skipped: Instance is null (Linux fallback)');
      return 'mock_post_${DateTime.now().millisecondsSinceEpoch}';
    }
    final postsRef = instance.collection(FirebaseCollections.posts);
    final docRef = await postsRef.add(postData);
    return docRef.id;
  }

  Future<Map<String, dynamic>?> getPostById(String postId) async {
    return await _firestoreService.getDocument(
      collection: FirebaseCollections.posts,
      docId: postId,
    );
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await _firestoreService.updateDocument(
      collection: FirebaseCollections.posts,
      docId: postId,
      data: data,
    );
  }

  Future<void> deletePost(String postId) async {
    await _firestoreService.deleteDocument(
      collection: FirebaseCollections.posts,
      docId: postId,
    );
  }

  Stream<List<Map<String, dynamic>>> streamPosts({int limit = 20}) {
    return _firestoreService.streamCollection(
      collection: FirebaseCollections.posts,
      queryBuilder: (ref) => ref
          .where('status', isEqualTo: 'published')
          .orderBy('created_at', descending: true)
          .limit(limit),
    );
  }

  Future<List<Map<String, dynamic>>> getUserPosts(String userId) async {
    return await _firestoreService.getCollectionWhere(
      collection: FirebaseCollections.posts,
      field: 'user_id',
      value: userId,
      limit: 50,
    );
  }

  // ==================== COMMENT OPERATIONS ====================

  Future<String> addComment(String postId, Map<String, dynamic> commentData) async {
    return await _firestoreService.createSubcollectionDocument(
      collection: FirebaseCollections.posts,
      docId: postId,
      subcollection: FirebaseCollections.comments,
      data: commentData,
    );
  }

  Stream<List<Map<String, dynamic>>> streamComments(String postId) {
    return _firestoreService.streamSubcollection(
      collection: FirebaseCollections.posts,
      docId: postId,
      subcollection: FirebaseCollections.comments,
      queryBuilder: (ref) => ref.orderBy('created_at', descending: false),
    );
  }

  Future<void> deleteComment(String postId, String commentId) async {
    final instance = _firestoreService.instance;
    if (instance == null) {
      debugPrint('Firebase skipped: Instance is null (Linux fallback)');
      return;
    }
    await instance
        .collection(FirebaseCollections.posts)
        .doc(postId)
        .collection(FirebaseCollections.comments)
        .doc(commentId)
        .delete();
  }

  // ==================== LIKE OPERATIONS ====================

  Future<void> likePost(String postId, String userId) async {
    await _firestoreService.arrayUnion(
      collection: FirebaseCollections.posts,
      docId: postId,
      field: 'liked_by_user_ids',
      elements: [userId],
    );

    await _firestoreService.incrementField(
      collection: FirebaseCollections.posts,
      docId: postId,
      field: 'likes_count',
    );
  }

  Future<void> unlikePost(String postId, String userId) async {
    await _firestoreService.arrayRemove(
      collection: FirebaseCollections.posts,
      docId: postId,
      field: 'liked_by_user_ids',
      elements: [userId],
    );

    await _firestoreService.decrementField(
      collection: FirebaseCollections.posts,
      docId: postId,
      field: 'likes_count',
    );
  }

  // ==================== CHAT OPERATIONS ====================

  Future<String> createChatRoom(Map<String, dynamic> chatRoomData) async {
    final instance = _firestoreService.instance;
    if (instance == null) {
      debugPrint('Firebase skipped: Instance is null (Linux fallback)');
      return 'mock_room_${DateTime.now().millisecondsSinceEpoch}';
    }
    final chatsRef = instance.collection(FirebaseCollections.chats);
    final docRef = await chatsRef.add(chatRoomData);
    return docRef.id;
  }

  Future<Map<String, dynamic>?> getChatRoom(String chatRoomId) async {
    return await _firestoreService.getDocument(
      collection: FirebaseCollections.chats,
      docId: chatRoomId,
    );
  }

  Stream<Map<String, dynamic>?> streamChatRoom(String chatRoomId) {
    return _firestoreService.streamDocument(
      collection: FirebaseCollections.chats,
      docId: chatRoomId,
    );
  }

  Stream<List<Map<String, dynamic>>> streamUserChats(String userId) {
    final instance = _firestoreService.instance;
    if (instance == null) return Stream.value([]);
    return instance
        .collection(FirebaseCollections.chats)
        .where('participant_ids', arrayContains: userId)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .handleError((error, stackTrace) {
          // Firebase will print a direct URL here to create the missing composite index
          debugPrint('🔥 [Firestore Index Missing] streamUserChats error: $error');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<String> sendMessage({
    required String chatRoomId,
    required Map<String, dynamic> messageData,
    required List<String> participantIds,
    required Map<String, String> participantNames,
    required Map<String, String?> participantAvatars,
    required String receiverId,
  }) async {
    final messageId = await _firestoreService.createSubcollectionDocument(
      collection: FirebaseCollections.chats,
      docId: chatRoomId,
      subcollection: FirebaseCollections.messages,
      data: messageData,
    );

    // Update chat room metadata + unread counts (receiver++).
    final instance = _firestoreService.instance;
    if (instance == null) {
      debugPrint('Firebase skipped: Instance is null (Linux fallback)');
      return messageId;
    }
    final chatDoc = instance
        .collection(FirebaseCollections.chats)
        .doc(chatRoomId);

    try {
      await _firestoreService.runTransaction((tx) async {
        final snap = await tx.get(chatDoc);
        final data = snap.data() ?? <String, dynamic>{};

        final Map<String, dynamic> existingUnread =
            (data['unread_counts'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{};
        final Map<String, int> unreadCounts = {
          for (final e in existingUnread.entries)
            e.key: int.tryParse(e.value.toString()) ?? 0,
        };

        final senderId = messageData['sender_id']?.toString();
        if (senderId != null) {
          unreadCounts[senderId] = 0; // sender has no unread in this room
        }
        unreadCounts[receiverId] = (unreadCounts[receiverId] ?? 0) + 1;
        // #region agent log
        DebugLogger.log(
          runId: 'baseline',
          hypothesisId: 'C',
          location: 'firebase_data_source.dart:sendMessage',
          message: 'Computed unread_counts in transaction',
          data: {
            'chatRoomId': chatRoomId,
            'senderId': senderId,
            'receiverId': receiverId,
            'receiverUnread': unreadCounts[receiverId],
          },
        );
        // #endregion
        // #region agent log
        debugPrint('[ae3196][C] tx unread_counts chatRoomId=$chatRoomId sender=$senderId receiver=$receiverId receiverUnread=${unreadCounts[receiverId]}');
        // #endregion
        // #region agent log
        // ignore: avoid_print
        print('[ae3196][C] tx unread_counts chatRoomId=$chatRoomId sender=$senderId receiver=$receiverId receiverUnread=${unreadCounts[receiverId]}');
        // #endregion

        final Map<String, dynamic> existingTyping =
            (data['typing_status'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{};
        final Map<String, bool> typingStatus = {
          for (final e in existingTyping.entries) e.key: e.value == true,
        };
        for (final pid in participantIds) {
          typingStatus[pid] = false;
        }

        final bool docExists = snap.exists;

        tx.set(
          chatDoc,
          {
            // Only set these on creation (first message)
            if (!docExists) 'created_at': FieldValue.serverTimestamp(),
            if (!docExists) 'is_active': true,

            // Always update these
            'participant_ids': participantIds,
            'participant_names': participantNames,
            'participant_avatars': participantAvatars,
            'last_message': messageData['content'],
            'last_message_sender_id': messageData['sender_id'],
            'last_message_timestamp': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
            'unread_counts': unreadCounts,
            'typing_status': typingStatus,
          },
          SetOptions(merge: true),
        );
      });
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ Firestore Transaction Failed in sendMessage ❌❌❌');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }

    return messageId;
  }

  Stream<List<Map<String, dynamic>>> streamMessages(String chatRoomId) {
    return _firestoreService.streamSubcollection(
      collection: FirebaseCollections.chats,
      docId: chatRoomId,
      subcollection: FirebaseCollections.messages,
      queryBuilder: (ref) => ref.orderBy('timestamp', descending: false),
    );
  }

  Future<void> markMessageAsRead(String chatRoomId, String messageId) async {
    final instance = _firestoreService.instance;
    if (instance == null) {
      debugPrint('Firebase skipped: Instance is null (Linux fallback)');
      return;
    }
    await instance
        .collection(FirebaseCollections.chats)
        .doc(chatRoomId)
        .collection(FirebaseCollections.messages)
        .doc(messageId)
        .update({
      'status': 'read',
      'read_at': DateTime.now().toIso8601String(),
    });
  }

  /// Batch-update visible unread messages to 'read'.
  Future<void> markVisibleMessagesAsRead(
      String chatRoomId, List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    await _firestoreService.batchWrite(
      messageIds.map((id) => {
        'collection': '${FirebaseCollections.chats}/$chatRoomId/${FirebaseCollections.messages}',
        'docId': id,
        'type': 'update',
        'data': <String, dynamic>{
          'status': 'read',
          'read_at': DateTime.now().toIso8601String(),
        },
      }).toList(),
    );
  }

  Future<void> markChatAsRead(String chatRoomId, String userId) async {
    final instance = _firestoreService.instance;
    if (instance == null) {
      debugPrint('Firebase skipped: Instance is null (Linux fallback)');
      return;
    }
    final chatDoc = instance
        .collection(FirebaseCollections.chats)
        .doc(chatRoomId);

    await _firestoreService.runTransaction((tx) async {
      final snap = await tx.get(chatDoc);
      final data = snap.data() ?? <String, dynamic>{};
      final Map<String, dynamic> existingUnread =
          (data['unread_counts'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

      final Map<String, int> unreadCounts = {
        for (final e in existingUnread.entries)
          e.key: int.tryParse(e.value.toString()) ?? 0,
      };

      unreadCounts[userId] = 0;
      // #region agent log
      DebugLogger.log(
        runId: 'baseline',
        hypothesisId: 'D',
        location: 'firebase_data_source.dart:markChatAsRead',
        message: 'markChatAsRead set unread to 0',
        data: {'chatRoomId': chatRoomId, 'userId': userId},
      );
      // #endregion
      // #region agent log
      debugPrint('[ae3196][D] markChatAsRead chatRoomId=$chatRoomId userId=$userId');
      // #endregion
      // #region agent log
      // ignore: avoid_print
      print('[ae3196][D] markChatAsRead chatRoomId=$chatRoomId userId=$userId');
      // #endregion
      tx.set(chatDoc, {'unread_counts': unreadCounts}, SetOptions(merge: true));
    });
  }

  Future<void> updateTypingStatus(
      String chatRoomId, String userId, bool isTyping) async {
    final instance = _firestoreService.instance;
    if (instance == null) {
      debugPrint('Firebase skipped: Instance is null (Linux fallback)');
      return;
    }
    await instance
        .collection(FirebaseCollections.chats)
        .doc(chatRoomId)
        .set(
      {'typing_status': {userId: isTyping ? DateTime.now().millisecondsSinceEpoch : false}},
      SetOptions(merge: true),
    );
  }

  // ==================== ANALYSIS OPERATIONS ====================

  Future<String> createAnalysis(Map<String, dynamic> analysisData) async {
    final instance = _firestoreService.instance;
    if (instance == null) {
      debugPrint('Firebase skipped: Instance is null (Linux fallback)');
      return 'mock_analysis_${DateTime.now().millisecondsSinceEpoch}';
    }
    final analysesRef = instance.collection(FirebaseCollections.analyses);
    final docRef = await analysesRef.add(analysisData);
    return docRef.id;
  }

  Future<void> updateAnalysis(String analysisId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await _firestoreService.updateDocument(
      collection: FirebaseCollections.analyses,
      docId: analysisId,
      data: data,
    );
  }

  Future<void> deleteAnalysis(String analysisId) async {
    await _firestoreService.deleteDocument(
      collection: FirebaseCollections.analyses,
      docId: analysisId,
    );
  }

  Future<List<Map<String, dynamic>>> getParentAnalyses(String parentId) async {
    return await _firestoreService.getCollectionWhere(
      collection: FirebaseCollections.analyses,
      field: 'parent_id',
      value: parentId,
    );
  }

  Future<List<Map<String, dynamic>>> getDoctorPatientAnalyses(String doctorId) async {
    return await _firestoreService.getCollectionWhere(
      collection: FirebaseCollections.analyses,
      field: 'doctor_id',
      value: doctorId,
    );
  }

  Stream<List<Map<String, dynamic>>> streamParentAnalyses(String parentId) {
    return _firestoreService.streamCollection(
      collection: FirebaseCollections.analyses,
      queryBuilder: (ref) => ref
          .where('parent_id', isEqualTo: parentId)
          .orderBy('date', descending: true),
    );
  }

  // ==================== DOCTOR CODE OPERATIONS ====================

  Future<String> createDoctorCode(Map<String, dynamic> codeData) async {
    final instance = _firestoreService.instance;
    if (instance == null) {
      debugPrint('Firebase skipped: Instance is null (Linux fallback)');
      return 'mock_code_${DateTime.now().millisecondsSinceEpoch}';
    }
    final codesRef = instance.collection(FirebaseCollections.doctorCodes);
    final docRef = await codesRef.add(codeData);
    return docRef.id;
  }

  Future<Map<String, dynamic>?> getDoctorCodeByCode(String code) async {
    final results = await _firestoreService.getCollectionWhere(
      collection: FirebaseCollections.doctorCodes,
      field: 'code',
      value: code,
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> incrementCodeUsage(String codeId) async {
    await _firestoreService.incrementField(
      collection: FirebaseCollections.doctorCodes,
      docId: codeId,
      field: 'usage_count',
    );
  }

  // ==================== CONNECTION REQUEST OPERATIONS ====================

  Future<String> createConnectionRequest(Map<String, dynamic> requestData) async {
    final instance = _firestoreService.instance;
    if (instance == null) {
      debugPrint('Firebase skipped: Instance is null (Linux fallback)');
      return 'mock_request_${DateTime.now().millisecondsSinceEpoch}';
    }
    final requestsRef = instance.collection(FirebaseCollections.connectionRequests);
    final docRef = await requestsRef.add(requestData);
    return docRef.id;
  }

  Future<void> updateConnectionRequest(String requestId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await _firestoreService.updateDocument(
      collection: FirebaseCollections.connectionRequests,
      docId: requestId,
      data: data,
    );
  }

  Stream<List<Map<String, dynamic>>> streamDoctorConnectionRequests(String doctorId) {
    return _firestoreService.streamCollection(
      collection: FirebaseCollections.connectionRequests,
      queryBuilder: (ref) => ref
          .where('doctor_id', isEqualTo: doctorId)
          .orderBy('created_at', descending: true),
    );
  }

  // ==================== FOLLOW OPERATIONS ====================

  Future<void> followUser(String followerId, String followingId) async {
    // Add to follower's following list
    await _firestoreService.arrayUnion(
      collection: FirebaseCollections.users,
      docId: followerId,
      field: 'following_ids',
      elements: [followingId],
    );

    // Add to following user's followers list
    await _firestoreService.arrayUnion(
      collection: FirebaseCollections.users,
      docId: followingId,
      field: 'follower_ids',
      elements: [followerId],
    );

    // Increment counts
    await _firestoreService.incrementField(
      collection: FirebaseCollections.users,
      docId: followerId,
      field: 'following_count',
    );

    await _firestoreService.incrementField(
      collection: FirebaseCollections.users,
      docId: followingId,
      field: 'followers_count',
    );
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    // Remove from lists
    await _firestoreService.arrayRemove(
      collection: FirebaseCollections.users,
      docId: followerId,
      field: 'following_ids',
      elements: [followingId],
    );

    await _firestoreService.arrayRemove(
      collection: FirebaseCollections.users,
      docId: followingId,
      field: 'follower_ids',
      elements: [followerId],
    );

    // Decrement counts
    await _firestoreService.decrementField(
      collection: FirebaseCollections.users,
      docId: followerId,
      field: 'following_count',
    );

    await _firestoreService.decrementField(
      collection: FirebaseCollections.users,
      docId: followingId,
      field: 'followers_count',
    );
  }

  // ==================== STORAGE OPERATIONS ====================

  Future<String> uploadImage(String filePath, String storagePath) async {
    return await _storageService.uploadImage(
      filePath: filePath,
      storagePath: storagePath,
    );
  }

  Future<String> uploadUserAvatar(String userId, String filePath) async {
    return await _storageService.uploadUserAvatar(
      userId: userId,
      filePath: filePath,
    );
  }

  Future<String> uploadPostImage(String userId, String postId, String filePath) async {
    return await _storageService.uploadPostImage(
      userId: userId,
      postId: postId,
      filePath: filePath,
    );
  }

  Future<void> deleteFile(String downloadUrl) async {
    await _storageService.deleteFile(downloadUrl);
  }

  // ==================== SEARCH OPERATIONS ====================

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    // Note: This is a basic implementation. For production, use Algolia or similar
    final allUsers = await _firestoreService.getCollection(
      collection: FirebaseCollections.users,
    );

    return allUsers.where((user) {
      final name = (user['name'] as String).toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();
  }
}