import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../data/models/parent_model.dart';
import '../view_model/ai_view_model.dart';
import 'ai_message_bubble.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late AIViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<AIViewModel>();

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final userId = user?.id;
    String? childName;
    if (user is ParentModel) {
      childName = user.childName;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (userId != null) {
        _viewModel.loadChatHistory(userId);
      }
      if (childName != null && childName.isNotEmpty) {
        _viewModel.startSession(childName);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ إصلاح: mounted check بدل Future.delayed
  void _scrollToBottom() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // ✅ إصلاح: لو مفيش user — مش بنبعت
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;

    _messageController.clear();
    await _viewModel.sendMessage(userId, message);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    final currentUser = context.watch<AuthProvider>().currentUser;
    final userAvatarUrl = currentUser?.avatarUrl ?? currentUser?.profileImage;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: 'المساعد الطبي الذكي',
        showBackButton: true, // ✅ إصلاح: true عشان المستخدم يقدر يرجع
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'clear') _showClearDialog();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded),
                    SizedBox(width: 8),
                    Text((isAr ? 'مسح المحادثة' : 'Clear chat')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AIViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.messages.isEmpty) {
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/ai_avatar.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 24),
                        // ✅ إصلاح: AppColors بدل hardcoded color
                        Text(
                          'كونكت',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary, // ✅ من الـ theme
                            letterSpacing: 4,
                          ),
                        ),
                        SizedBox(height: 6),
                        // ✅ إصلاح: نص عربي بدل English
                        Text(
                          'مساعدك الطبي الذكي',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildInputArea(viewModel, theme),
              ],
            );
          }

          // ✅ Auto-scroll عند كل تحديث للرسايل
          if (viewModel.messages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  itemCount: viewModel.messages.length,
                  itemBuilder: (context, index) {
                    return AIMessageBubble(
                      message: viewModel.messages[index],
                      userAvatarUrl: userAvatarUrl,
                    );
                  },
                ),
              ),
              _buildInputArea(viewModel, theme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputArea(AIViewModel viewModel, ThemeData theme) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 120),
                child: AppTextField(
                  controller: _messageController,
                  hint: (isAr ? 'اسأل عن أي شيء' : 'About anything.'),
                  maxLines: null,
                  enabled: !viewModel.isSending,
                ),
              ),
            ),
            SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: viewModel.isSending ? null : _handleSend,
                icon: viewModel.isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(Icons.send_rounded),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDialog() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text((isAr ? 'مسح المحادثة' : 'Clear chat')),
        content: Text((isAr ? 'هل أنت متأكد من مسح جميع الرسائل؟' : 'Are you sure you want to delete all messages?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text((isAr ? 'إلغاء' : 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              // ✅ إصلاح: تحقق من userId قبل المسح
              final userId = context.read<AuthProvider>().currentUser?.id;
              if (userId != null) {
                _viewModel.clearChatHistory(userId);
              }
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.destructive,
            ),
            child: Text((isAr ? 'مسح' : 'Delete')),
          ),
        ],
      ),
    );
  }
}
