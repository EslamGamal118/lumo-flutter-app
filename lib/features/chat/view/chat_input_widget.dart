import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Chat Input Widget - Matches React ChatScreen input area
///
/// React: bg-white border-t border-[#E3F2FD] px-6 py-4
/// Paperclip icon + rounded-full E3F2FD input + gradient send button
class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final ValueChanged<String>? onTextChanged;
  final bool isLoading;

  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.onTextChanged,
    this.isLoading = false,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleTextChange() {
    widget.onTextChanged?.call(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    // React: bg-white border-t border-[#E3F2FD] px-6 py-4
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // React: flex-1 h-12 rounded-full border-[#E3F2FD] bg-[#E3F2FD] px-5
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: TextField(
                  controller: widget.controller,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.body,
                  enabled: !widget.isLoading,
                  decoration: InputDecoration(
                    hintText: (isAr ? 'اكتب رسالة...' : 'Type a message...'),
                    hintStyle: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // React: w-12 h-12 rounded-full bg-gradient-to-r shadow-lg
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF2196F3).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: widget.isLoading ? null : widget.onSend,
                icon: widget.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(Icons.send_rounded,
                        size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
