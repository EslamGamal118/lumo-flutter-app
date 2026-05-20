import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/message_model.dart';

/// Message Bubble - Matches React ChatScreen message bubbles
///
/// React user message: bg-gradient-to-r from-[#2196F3] to-[#1565C0] text-white rounded-[20px] rounded-tr-sm
/// React doctor message: bg-white text-[#1a1a2e] rounded-[20px] rounded-tl-sm shadow-md
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      // React: px-6 py-2 (space-y-4 / 2)
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Container(
                // React: px-5 py-3
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  // React user: bg-gradient-to-r from-[#2196F3] to-[#1565C0]
                  // React doctor: bg-white shadow-md
                  gradient: isMe ? AppColors.primaryGradient : null,
                  color: isMe ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    // React user (RTL): rounded-tr-sm → bottomRight small
                    // React doctor (RTL): rounded-tl-sm → bottomLeft small
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: !isMe
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image/File attachments
                    if (message.hasImage || message.hasFile) ...[
                      if (message.hasImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: message.imageUrl!,
                            width: 200,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                width: 200,
                                height: 150,
                                color: Theme.of(context).colorScheme.surface,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 200,
                              height: 150,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      if (message.hasFile)
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.2)
                                : Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insert_drive_file_rounded,
                                size: 20,
                                color: isMe
                                    ? Colors.white
                                    : Color(0xFF2196F3),
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  message.fileName ?? (isAr ? 'ملف' : 'File'),
                                  style: AppTextStyles.caption.copyWith(
                                    color: isMe
                                        ? Colors.white
                                        : Color(0xFF1A1A2E),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (message.content.isNotEmpty) SizedBox(height: 8),
                    ],
                    // Message text - React: mb-1
                    if (message.content.isNotEmpty)
                      Text(
                        message.content,
                        style: AppTextStyles.body.copyWith(
                          color: isMe ? Colors.white : Color(0xFF1A1A2E),
                        ),
                      ),
                    SizedBox(height: 4),
                    // Time - React: text-xs text-white/70 or text-[#64748b]
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormatter.formatTime(message.timestamp),
                          style: AppTextStyles.caption.copyWith(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                        if (isMe) ...[
                          SizedBox(width: 4),
                          Icon(
                            message.isSending
                                ? Icons.schedule_rounded
                                : message.isFailed
                                    ? Icons.error_outline_rounded
                                    : message.isRead
                                        ? Icons.done_all_rounded
                                        : message.isDelivered
                                            ? Icons.done_all_rounded
                                            : Icons.done_rounded,
                            size: 14,
                            color: message.isFailed
                                ? Colors.redAccent
                                : message.isRead
                                    ? Color(0xFF80DEEA) // blue ticks
                                    : Colors.white.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
