import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/providers/auth_provider.dart';
import '../view_model/chat_view_model.dart';
import '../../session/view_model/session_view_model.dart';
import '../../analysis/view/session_config_bottom_sheet.dart';
import 'message_bubble.dart';
import 'chat_input_widget.dart';
import '../widgets/typing_indicator.dart';
import '../../../core/router/route_names.dart';
import '../../../data/models/user_model.dart';
import '../../../core/enums/user_role.dart';
class ChatRoomScreen extends StatefulWidget {
  final String chatRoomId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? otherUserId;

  const ChatRoomScreen({
    super.key,
    required this.chatRoomId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.otherUserId,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late ChatViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<ChatViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initChat();
      }
    });
  }

  Future<void> _initChat() async {
    // Authenticate Firebase if available — on unsupported platforms this is a no-op
    if (!_viewModel.isFirebaseAuthenticated) {
      await _viewModel.authenticateFirebase();
      if (!mounted) return;
    }
    await _viewModel.loadMessages(widget.chatRoomId);
    _scrollToBottom();
  }

  @override
  void dispose() {
    // leaveRoom() cancels subscriptions WITHOUT clearing the message cache.
    // Chat list refresh is handled by Navigator.push(...).then() at the call site.
    _viewModel.leaveRoom();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }



  /// BUG FIX #9: Safe scroll with mounted check and hasClients validation
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      try {
        _scrollController.animateTo(
          0.0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (e) {
        debugPrint('Scroll error: $e');
      }
    });
  }

  void _handleSend() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    final receiverId = int.tryParse(widget.otherUserId ?? '') ?? 0;
    if (receiverId == 0) {
      debugPrint('Invalid receiverId — cannot send message');
      return;
    }

    // Stop typing indicator immediately on send
    _viewModel.stopTyping(widget.chatRoomId, currentUser.id);

    _messageController.clear();

    _viewModel.sendMessage(
      chatRoomId: widget.chatRoomId,
      senderId: currentUser.id,
      senderName: currentUser.name,
      senderAvatarUrl: currentUser.avatarUrl,
      content: content,
      receiverId: receiverId,
      receiverName: widget.otherUserName,
      receiverAvatarUrl: widget.otherUserAvatar,
    );

    _scrollToBottom();
  }

  void _handleTextChanged(String text) {
    if (text.trim().isEmpty) return;
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;
    _viewModel.setTyping(widget.chatRoomId, currentUser.id);
  }

  void _navigateToProfile() {
    final uid = int.tryParse(widget.otherUserId ?? '');
    if (uid != null && uid != 0) {
      // Provide a fallback user so ProfileScreen can load even if the API fails
      final fallbackUser = UserModel(
        id: uid,
        name: widget.otherUserName,
        email: '',
        role: UserRole.parent, // Fallback role
        avatarUrl: widget.otherUserAvatar,
      );
      Navigator.pushNamed(
        context,
        RouteNames.profile,
        arguments: {'userId': uid, 'user': fallbackUser},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.currentUser?.id.toString() ?? '';

    final messagesBackground = theme.brightness == Brightness.light
        ? Color(0xFFF1F5F9)
        : theme.colorScheme.surfaceContainerLow;

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back,
                      size: 24, color: Colors.white),
                ),
                SizedBox(width: 16),
                GestureDetector(
                  onTap: _navigateToProfile,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: AvatarWidget(
                      imageUrl: widget.otherUserAvatar,
                      name: widget.otherUserName,
                      size: 40,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _navigateToProfile,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.otherUserName,
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Consumer2<SessionViewModel, ChatViewModel>(
                          builder: (context, sessionVM, chatVM, child) {
                            if (sessionVM.isActive) {
                              return Text(
                                'جلسة نشطة: ${sessionVM.formattedTime}',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }

                            final room = chatVM.currentChatRoom;
                            final isTyping =
                                room?.isOtherParticipantTyping(currentUserId) ??
                                    false;

                            if (isTyping) {
                              return Text(
                                (isAr ? 'يكتب الآن...' : 'Is writing:'),
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }

                            return SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // RBAC: Only doctors can create/control sessions
                if (authProvider.currentUser?.role.isDoctor == true)
                  Consumer<SessionViewModel>(
                    builder: (context, sessionVM, child) {
                      if (sessionVM.isActive) {
                        return IconButton(
                          icon: Icon(Icons.stop_circle_rounded,
                              color: Colors.redAccent, size: 32),
                          onPressed: () => sessionVM.endSession(),
                          tooltip: (isAr ? 'إنهاء الجلسة' : 'Terminating the session'),
                        );
                      }
                      return IconButton(
                        icon: Icon(Icons.play_circle_fill_rounded,
                            color: Colors.white, size: 32),
                        onPressed: () {
                          SessionConfigBottomSheet.show(
                            context,
                            receiverId:
                                int.tryParse(widget.otherUserId ?? '') ?? 0,
                          );
                        },
                        tooltip: (isAr ? 'بدء جلسة' : 'Start a session'),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Messages Area - BUG FIX #8, #9: Proper stream listening and auto-scroll
          Expanded(
            child: Consumer<ChatViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.isLoading && viewModel.messages.isEmpty) {
                  return ColoredBox(
                    color: messagesBackground,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (viewModel.messages.isEmpty) {
                  return ColoredBox(
                    color: messagesBackground,
                    child: EmptyState(
                      icon: Icons.chat_outlined,
                      title: (isAr ? 'لا توجد رسائل بعد' : 'No messages'),
                      message: (isAr ? 'ابدأ المحادثة الآن' : 'Start the conversation now'),
                    ),
                  );
                }

                // ✅ Auto-scroll عند كل تحديث للرسايل
                if (viewModel.messages.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                }

                final room = viewModel.currentChatRoom;
                final isOtherTyping =
                    room?.isOtherParticipantTyping(currentUserId) ?? false;
                final itemCount = viewModel.messages.length +
                    (isOtherTyping ? 1 : 0);

                return ColoredBox(
                  color: messagesBackground,
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      // Show typing indicator as the first item when reversed
                      if (isOtherTyping) {
                        if (index == 0) {
                          return Padding(
                            padding: EdgeInsets.only(
                                left: 24, right: 64, top: 4, bottom: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TypingIndicator(
                                dotColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          );
                        }
                        index -= 1;
                      }
                      
                      final messageIndex = viewModel.messages.length - 1 - index;
                      final message = viewModel.messages[messageIndex];
                      final isMe = message.senderId.toString() == currentUserId;
                      return MessageBubble(message: message, isMe: isMe);
                    },
                  ),
                );
              },
            ),
          ),

          Consumer<ChatViewModel>(
            builder: (context, viewModel, child) {
              return ChatInputWidget(
                controller: _messageController,
                onSend: _handleSend,
                onAttach: null,
                onTextChanged: _handleTextChanged,
                isLoading: viewModel.isSending,
              );
            },
          ),
        ],
      ),
    );
  }
}
