import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/ai_message_model.dart';
import '../../chat/widgets/typing_indicator.dart';

class AIMessageBubble extends StatelessWidget {
  final AIMessageModel message;
  final String? userAvatarUrl;

  const AIMessageBubble({
    super.key,
    required this.message,
    this.userAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildBotAvatar(),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.isLoading)
                  const TypingIndicator()
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.white : null,
                      gradient: !isUser
                          ? const LinearGradient(
                              colors: [Color(0xFF5E5CE6), Color(0xFF30B0E8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(24),
                        topRight: const Radius.circular(24),
                        bottomLeft: Radius.circular(isUser ? 24 : 0),
                        bottomRight: Radius.circular(isUser ? 4 : 24),
                      ),
                      border: isUser
                          ? Border.all(color: const Color(0xFFE5E7EB), width: 1)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: message.hasError
                        ? _buildErrorMessage()
                        : Text(
                            message.content,
                            style: AppTextStyles.body.copyWith(
                              height: 1.5, // Better readability
                              color: isUser
                                  ? const Color(0xFF1F2937) // Navy/Dark Gray
                                  : Colors.white,
                            ),
                          ),
                  ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    DateFormatter.formatRelativeTime(message.timestamp),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.mutedForeground,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return const CircleAvatar(
      radius: 18,
      backgroundColor: Colors.transparent,
      backgroundImage: AssetImage('assets/images/ai_avatar.png'),
    );
  }

  Widget _buildUserAvatar() {
    final resolvedUrl = userAvatarUrl?.trim();
    final hasImage = resolvedUrl != null && resolvedUrl.isNotEmpty;

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      child: ClipOval(
        child: SizedBox(
          width: 36,
          height: 36,
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: resolvedUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      _buildDefaultUserIcon(),
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : _buildDefaultUserIcon(),
        ),
      ),
    );
  }

  Widget _buildDefaultUserIcon() {
    return const Icon(
      Icons.person,
      color: AppColors.primary,
      size: 20,
    );
  }

  Widget _buildErrorMessage() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.destructive,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message.error ?? 'حدث خطأ في الاتصال',
            style: AppTextStyles.body.copyWith(
              color: AppColors.destructive,
            ),
          ),
        ),
      ],
    );
  }
}
