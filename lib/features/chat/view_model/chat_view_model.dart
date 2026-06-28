import 'dart:async';
import 'package:flutter/material.dart';

import '../../../data/repositories/chat_repository.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/models/chat_room_model.dart';
import '../../../data/models/message_model.dart';
import '../../../core/enums/message_status.dart';
import '../../../core/services/firebase_auth_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatRepository _chatRepository;
  final FirebaseAuthService _firebaseAuthService;
  final LocalDataSource _localDataSource;

  ChatViewModel(this._chatRepository, this._firebaseAuthService, this._localDataSource);

  bool _isDisposed = false;

  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  StreamSubscription<ChatRoomModel?>? _roomSubscription;
  StreamSubscription<List<ChatRoomModel>>? _roomsSubscription;
  Timer? _typingTimer;
  bool _currentlyTyping = false;

  @override
  void dispose() {
    _isDisposed = true;
    _typingTimer?.cancel();
    _messagesSubscription?.cancel();
    _roomSubscription?.cancel();
    _roomsSubscription?.cancel();
    super.dispose();
  }

  int? _userId;

  int get totalUnreadCount {
    // Fallback: if _userId wasn't set yet, try reading from local cache
    final uid = _userId ?? int.tryParse(_localDataSource.getCurrentUserId() ?? '');
    final currentUserId = uid?.toString();
    if (currentUserId == null) return 0;
    return _chatRooms.fold(0, (sum, room) => sum + room.getUnreadCount(currentUserId));
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  final List<ChatRoomModel> _chatRooms = [];
  final List<MessageModel> _messages = [];
  ChatRoomModel? _currentChatRoom;
  String? _currentChatRoomId; // Tracks active room to guard stale stream events
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  List<ChatRoomModel> get chatRooms => _chatRooms;
  List<MessageModel> get messages => _messages;
  ChatRoomModel? get currentChatRoom => _currentChatRoom;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  bool get isFirebaseAuthenticated =>
      _firebaseAuthService.currentUser != null;

  Future<bool> authenticateFirebase() async {
    // On platforms where Firebase is not initialized (Linux, Windows),
    // skip Firebase auth entirely and let chat work via REST + cache.
    if (!_firebaseAuthService.isAvailable) {
      debugPrint('ℹ️ Firebase Auth skipped: not available on this platform. Chat will use REST fallback.');
      return true;
    }

    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final token = await _chatRepository.getFirebaseToken();
      debugPrint('🔑 Firebase Custom Token Received: $token');
      await _firebaseAuthService.signInWithCustomToken(token);
      debugPrint('✅ Firebase Auth Success. UID: ${_firebaseAuthService.currentUserId}');
      _isLoading = false;
      _safeNotifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Firebase Auth Failed in ViewModel: $e');
      // Don't block chat on Firebase auth failure — fall through to REST
      _errorMessage = null;
      _isLoading = false;
      _safeNotifyListeners();
      return true;
    }
  }

  Future<String> startChat(int receiverId, {String? receiverName, String? receiverAvatar}) async {
    try {
      final chatRoom = await _chatRepository.startChat(receiverId);
      final chatRoomId = chatRoom.id;
      debugPrint('✅ chatRoomId from API: $chatRoomId');

      // ✅ إثراء ChatRoom ببيانات Receiver لو أنت عندك
      ChatRoomModel enrichedRoom = chatRoom;
      if ((receiverName != null && receiverName.isNotEmpty) || 
          (receiverAvatar != null && receiverAvatar.isNotEmpty)) {
        final receiverIdStr = receiverId.toString();
        
        // بناء Maps للمشاركين المحدثة
        Map<String, String> updatedNames = Map.from(chatRoom.participantNames);
        Map<String, String?> updatedAvatars = Map.from(chatRoom.participantAvatars);
        
        if (receiverName != null && receiverName.isNotEmpty) {
          updatedNames[receiverIdStr] = receiverName;
        }
        if (receiverAvatar != null && receiverAvatar.isNotEmpty) {
          updatedAvatars[receiverIdStr] = receiverAvatar;
        }
        
        enrichedRoom = chatRoom.copyWith(
          participantNames: updatedNames,
          participantAvatars: updatedAvatars,
        );
      }

      // Pre-populate the room in _chatRooms so Inbox shows it immediately
      final existingIndex = _chatRooms.indexWhere((r) => r.id == chatRoomId);
      if (existingIndex == -1) {
        _chatRooms.add(enrichedRoom);
        _chatRooms.sort((a, b) {
          final aTime = a.lastMessageTimestamp ?? a.updatedAt;
          final bTime = b.lastMessageTimestamp ?? b.updatedAt;
          return bTime.compareTo(aTime);
        });
      } else {
        // تحديث الـ room الموجود بالبيانات المثرية
        _chatRooms[existingIndex] = enrichedRoom;
      }

      await loadMessages(chatRoomId);
      _safeNotifyListeners();
      return chatRoomId;
    } catch (e) {
      _errorMessage = 'فشل بدء المحادثة: $e';
      _safeNotifyListeners();
      rethrow;
    }
  }

  Future<void> loadChatRooms([int? userId]) async {
    _isLoading = true;
    if (userId != null) _userId = userId;
    
    // 1. First, load from local cache for instant UI response
    final cachedRooms = _chatRepository.getCachedChats();
    if (cachedRooms.isNotEmpty) {
      _chatRooms.clear();
      _chatRooms.addAll(cachedRooms);
      _chatRooms.sort((a, b) {
        final aTime = a.lastMessageTimestamp ?? a.updatedAt;
        final bTime = b.lastMessageTimestamp ?? b.updatedAt;
        return bTime.compareTo(aTime);
      });
      _isLoading = false;
      _safeNotifyListeners();
    }

    try {
      final rooms = await _chatRepository.getMyChats();
      // Patch rooms that have null lastMessage if we have cached messages
      final patchedRooms = rooms.map((room) {
        // ✅ إصلاح: ملء بيانات المشاركين الناقصة
        Map<String, String> updatedNames = Map.from(room.participantNames);
        Map<String, String?> updatedAvatars = Map.from(room.participantAvatars);
        
        // لو أسماء المشاركين فاضية، جرب الـ cache أو participants list
        for (final id in room.participantIds) {
          if ((updatedNames[id]?.isEmpty ?? true)) {
            final cachedMsgs = _chatRepository.getCachedMessages(room.id);
            for (final msg in cachedMsgs) {
              if (msg.senderId.toString() == id && msg.senderName.isNotEmpty) {
                updatedNames[id] = msg.senderName;
                if (msg.senderAvatarUrl != null && msg.senderAvatarUrl!.isNotEmpty) {
                  updatedAvatars[id] = msg.senderAvatarUrl;
                }
                break;
              }
            }
          }
        }
        
        var patchedRoom = room;
        
        // ملء آخر رسالة لو فاضية
        if (room.lastMessage == null || room.lastMessage!.isEmpty) {
          final cachedMsgs = _chatRepository.getCachedMessages(room.id);
          if (cachedMsgs.isNotEmpty) {
            cachedMsgs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            patchedRoom = room.copyWith(
              lastMessage: cachedMsgs.first.content,
              lastMessageSenderId: cachedMsgs.first.senderId.toString(),
              lastMessageTimestamp: cachedMsgs.first.timestamp,
            );
          }
        }
        
        // تطبيق البيانات المحدثة
        if (updatedNames.values.any((n) => n.isNotEmpty)) {
          patchedRoom = patchedRoom.copyWith(
            participantNames: updatedNames,
            participantAvatars: updatedAvatars,
          );
        }
        
        return patchedRoom;
      }).toList();

      _chatRooms.clear();
      _chatRooms.addAll(patchedRooms);
      
      _chatRooms.sort((a, b) {
        final aTime = a.lastMessageTimestamp ?? a.updatedAt;
        final bTime = b.lastMessageTimestamp ?? b.updatedAt;
        return bTime.compareTo(aTime);
      });
      
      _isLoading = false;
      _safeNotifyListeners();

      if (userId != null) {
        await _roomsSubscription?.cancel();
        _roomsSubscription = _chatRepository.streamUserChats(userId).listen(
          (updatedRooms) {
            // Prevent Firebase from wiping out Laravel/Cache rooms when Firebase fails on desktop
            if (updatedRooms.isEmpty && _chatRooms.isNotEmpty) {
              debugPrint('Firebase returned empty rooms list, ignoring to preserve local state.');
              return;
            }

            final patchedStreamRooms = updatedRooms.map((room) {
              if (room.lastMessage == null || room.lastMessage!.isEmpty) {
                final cachedMsgs = _chatRepository.getCachedMessages(room.id);
                if (cachedMsgs.isNotEmpty) {
                  cachedMsgs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                  return room.copyWith(
                    lastMessage: cachedMsgs.first.content,
                    lastMessageSenderId: cachedMsgs.first.senderId.toString(),
                    lastMessageTimestamp: cachedMsgs.first.timestamp,
                  );
                }
              }
              return room;
            }).toList();

            _chatRooms.clear();
            _chatRooms.addAll(patchedStreamRooms);
            _chatRooms.sort((a, b) {
              final aTime = a.lastMessageTimestamp ?? a.updatedAt;
              final bTime = b.lastMessageTimestamp ?? b.updatedAt;
              return bTime.compareTo(aTime);
            });
            _safeNotifyListeners();
          },
          onError: (e) {
            _errorMessage = 'Stream error: $e';
            _safeNotifyListeners();
          },
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> loadMessages(String chatRoomId) async {
    _isLoading = true;
    _errorMessage = null;
    _currentChatRoomId = chatRoomId;

    if (_messages.isNotEmpty && _messages.first.chatRoomId != chatRoomId) {
      _messages.clear();
      _messages.addAll(_chatRepository.getCachedMessages(chatRoomId));
    } else if (_messages.isEmpty) {
      _messages.addAll(_chatRepository.getCachedMessages(chatRoomId));
    }
    
    _safeNotifyListeners();

    // 🚀 NEW: Fetch from API to ensure we have messages on Linux without Firebase
    final room = _chatRooms.firstWhere((r) => r.id == chatRoomId, orElse: () => ChatRoomModel(id: chatRoomId, participantIds: [], participantNames: {}, participantAvatars: {}, createdAt: DateTime.now(), updatedAt: DateTime.now()));
    final receiverIdStr = room.getOtherParticipantId(_userId?.toString() ?? '');
    final receiverId = int.tryParse(receiverIdStr);
    
    _chatRepository.getChatHistoryFromApi(chatRoomId, receiverId).then((history) {
      if (history.isNotEmpty && _currentChatRoomId == chatRoomId) {
        final existingIds = _messages.map((m) => m.id).toSet();
        final newMessages = history.where((m) => !existingIds.contains(m.id)).toList();
        if (newMessages.isNotEmpty) {
          _messages.addAll(newMessages);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }
      }
      _isLoading = false;
      _safeNotifyListeners();
    }).catchError((e) {
      _isLoading = false;
      _safeNotifyListeners();
    });

    try {
      await _roomSubscription?.cancel();
      _roomSubscription = _chatRepository.streamChatRoom(chatRoomId).listen(
        (room) {
          _currentChatRoom = room;
          final index = _chatRooms.indexWhere((r) => r.id == chatRoomId);
          if (index != -1 && room != null) {
            _chatRooms[index] = room;
          }
          _safeNotifyListeners();
        },
        onError: (e) {
          _errorMessage = 'Room stream error: $e';
          _safeNotifyListeners();
        },
      );

      await _messagesSubscription?.cancel();
      _messagesSubscription = _chatRepository.streamMessages(chatRoomId).listen(
        (messagesList) {
          // Guard: ignore stream updates for a room we've already navigated away from
          if (_currentChatRoomId != chatRoomId) return;

          // Prevent Firebase from wiping out cached messages when Firebase fails on desktop/Linux
          if (messagesList.isEmpty && _messages.isNotEmpty) {
             debugPrint('Firebase returned empty messages for $chatRoomId, ignoring to preserve local cache.');
             _isLoading = false;
             _safeNotifyListeners();
             return;
          }

          _messages.clear();
          _messages.addAll(messagesList);
          // Ascending: oldest -> newest (UI shows newest at bottom)
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _isLoading = false;
          _safeNotifyListeners();

          // Mark incoming messages from OTHER user as read (per-message receipts)
          final uid = _userId;
          if (uid != null && messagesList.isNotEmpty) {
            _chatRepository.markVisibleMessagesAsRead(
                  chatRoomId, messagesList, uid).catchError((e) {
              debugPrint('Failed to mark visible messages as read: $e');
            });
          }
        },
        onError: (e) {
          _errorMessage = e.toString();
          _isLoading = false;
          _safeNotifyListeners();
        },
      );

      // When opening the room: mark it as read for current user (unread_counts -> 0).
      final uid = _userId;
      if (uid != null) {
        _chatRepository.markChatAsRead(chatRoomId, uid).catchError((e) {
          debugPrint('Failed to mark chat as read: $e');
        });
      } else {
        debugPrint('markChatAsRead skipped: userId is null for chatRoomId=$chatRoomId');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> sendMessage({
    required String chatRoomId,
    required int senderId,
    required String senderName,
    required String content,
    required int receiverId,
    String? receiverName,
    String? receiverAvatarUrl,
    String? senderAvatarUrl,
  }) async {
    _isSending = true;
    _errorMessage = null;

    // Optimistic UI Update: Add the message immediately
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = MessageModel(
      id: tempId,
      chatRoomId: chatRoomId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    _messages.add(tempMessage);
    
    // --- OPTIMISTIC UI UPDATE FOR CHATS LIST (SUBTITLE) ---
    final roomIndex = _chatRooms.indexWhere((r) => r.id == chatRoomId);
    if (roomIndex != -1) {
      _chatRooms[roomIndex] = _chatRooms[roomIndex].copyWith(
        lastMessage: content,
        lastMessageSenderId: senderId.toString(),
        lastMessageTimestamp: DateTime.now(),
      );
    } else {
      // If the room doesn't exist locally yet (e.g. started from a user contact),
      // create a virtual room optimistically so it instantly shows in the chats list!
      final newRoom = ChatRoomModel(
        id: chatRoomId,
        participantIds: [senderId.toString(), receiverId.toString()],
        participantNames: {
          senderId.toString(): senderName,
          if (receiverName != null) receiverId.toString(): receiverName,
        },
        participantAvatars: {
          if (senderAvatarUrl != null) senderId.toString(): senderAvatarUrl,
          if (receiverAvatarUrl != null) receiverId.toString(): receiverAvatarUrl,
        },
        lastMessage: content,
        lastMessageSenderId: senderId.toString(),
        lastMessageTimestamp: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        unreadCounts: {},
        typingStatus: {},
        isActive: true,
      );
      _chatRooms.add(newRoom);
    }

    _chatRooms.sort((a, b) {
      final aTime = a.lastMessageTimestamp ?? a.updatedAt;
      final bTime = b.lastMessageTimestamp ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });

    _scrollToBottomOptimistically();
    _safeNotifyListeners();

    try {
      debugPrint("Current Room ID is: $chatRoomId");
      final message = await _chatRepository.sendMessage(
        chatRoomId: chatRoomId,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        content: content,
        receiverId: receiverId,
      );

      if (!_messages.any((m) => m.id == message.id)) {
        // Replace temp message with actual message
        final tempIdx = _messages.indexWhere((m) => m.id == tempId);
        if (tempIdx != -1) {
          _messages[tempIdx] = message;
        } else {
          _messages.add(message);
        }
      }

      _isSending = false;
      _safeNotifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('❌❌❌ SEND MESSAGE FAILED: $e');
      debugPrint('❌❌❌ SEND MESSAGE STACK: $stack');
      _errorMessage = e.toString();
      _isSending = false;
      
      // Remove optimistic message on failure
      _messages.removeWhere((m) => m.id == tempId);
      
      _safeNotifyListeners();
      return false;
    }
  }

  void _scrollToBottomOptimistically() {
    // We notify listeners, so the UI will rebuild. 
    // This is handled by ChatRoomScreen's auto-scroll logic natively.
  }

  void clearError() {
    _errorMessage = null;
    _safeNotifyListeners();
  }

  /// Cleanly leave the current chat room: cancel stream subscriptions
  /// WITHOUT clearing the message cache. Call from ChatRoomScreen.dispose().
  /// Also triggers a chat-list refresh so the last message preview is accurate.
  void leaveRoom() {
    _currentChatRoomId = null;
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _currentChatRoom = null;
  }

  /// Call when the user types in the chat input. Debounces typing status:
  /// sets typing=true immediately, then auto-resets to false after 3s of inactivity.
  void setTyping(String chatRoomId, int userId) {
    if (!_currentlyTyping) {
      _currentlyTyping = true;
      _chatRepository.updateTypingStatus(chatRoomId, userId, true).catchError((e) {
        debugPrint('Typing status update failed (unsupported platform?): $e');
      });
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _currentlyTyping = false;
      _chatRepository.updateTypingStatus(chatRoomId, userId, false).catchError((e) {
        debugPrint('Typing status update failed (unsupported platform?): $e');
      });
    });
  }

  /// Force stop typing (e.g. on send).
  void stopTyping(String chatRoomId, int userId) {
    _typingTimer?.cancel();
    if (_currentlyTyping) {
      _currentlyTyping = false;
      _chatRepository.updateTypingStatus(chatRoomId, userId, false).catchError((e) {
        debugPrint('Typing status force stop failed (unsupported platform?): $e');
      });
    }
  }

  void resetState() {
    _typingTimer?.cancel();
    _currentlyTyping = false;
    _chatRooms.clear();
    _messages.clear();
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _roomsSubscription?.cancel();
    _roomsSubscription = null;
    _errorMessage = null;
    _isLoading = false;
    _isSending = false;
    _safeNotifyListeners();
  }
}
