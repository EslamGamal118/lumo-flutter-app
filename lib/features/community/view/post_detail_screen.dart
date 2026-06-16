import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../view_model/community_view_model.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/router/route_names.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/comment_model.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../../shared/providers/notification_provider.dart';
import 'comment_input_widget.dart';

/// PostDetailScreen (CommentsScreen) - Pixel-perfect match to React CommentsScreen
class PostDetailScreen extends StatefulWidget {
  final int postId;
  final PostModel? initialPost;

  const PostDetailScreen({super.key, required this.postId, this.initialPost});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<CommunityViewModel>();
      viewModel.fetchComments(widget.postId);
      
      // If post is not found locally, fetch it
      if (viewModel.findPostById(widget.postId) == null && widget.initialPost == null) {
        viewModel.fetchPostById(widget.postId);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleAddComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final viewModel = context.read<CommunityViewModel>();
    final auth = context.read<AuthProvider>();
    final replyTo = viewModel.replyingToComment;
    
    final scaffoldContext = ScaffoldMessenger.of(context);
    final notificationProvider = context.read<NotificationProvider>();
    
    await viewModel.addComment(widget.postId, content);
    
    // Since addComment returns void, we check if there's an error message
    if (viewModel.errorMessage == null) {
      // 1. Send Notification
      final postOwnerId = viewModel.findPostById(widget.postId)?.userId ?? 0;
      notificationProvider.sendCommentNotification(
        postId: widget.postId,
        postOwnerId: replyTo?.userId ?? postOwnerId,
        commenterName: auth.currentUser?.name ?? '',
      );

      // 2. Clear state
      _commentController.clear();
      viewModel.setReplyingTo(null);
      
      scaffoldContext.showSnackBar(
        const SnackBar(
          content: Text('تم إضافة التعليق بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      scaffoldContext.showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'فشل إضافة التعليق'),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final int currentUserId = currentUser?.id ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const GradientAppBar(title: 'التعليقات'),
      body: Consumer<CommunityViewModel>(
        builder: (context, viewModel, child) {
          final post = viewModel.findPostById(widget.postId) ?? widget.initialPost;
          
          if (post == null) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      viewModel.errorMessage ?? 'لم يتم العثور على المنشور',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        viewModel.fetchPostById(widget.postId);
                        viewModel.fetchComments(widget.postId);
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          // --- Smart display name logic (same as PostCard) ---
          final bool isPostOwner = currentUserId != 0 && post.userId == currentUserId;
          String displayName = post.userName;
          if (displayName.toLowerCase().contains('null') ||
              displayName.trim().isEmpty ||
              displayName == 'مستخدم') {
            if (isPostOwner && currentUser != null && currentUser.name.isNotEmpty) {
              displayName = currentUser.name;
            } else {
              displayName = 'مستخدم';
            }
          } else if (isPostOwner && currentUser != null && currentUser.name.isNotEmpty) {
            displayName = currentUser.name;
          }
          final String? displayAvatar =
              (isPostOwner && (post.userAvatarUrl == null || post.userAvatarUrl!.isEmpty))
                  ? currentUser?.avatarUrl
                  : post.userAvatarUrl;
          // --- End smart display name ---

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Original Post
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AvatarWidget(
                                    imageUrl: displayAvatar,
                                    name: displayName,
                                    size: 40,
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        RouteNames.profile,
                                        arguments: {
                                        'userId': post.userId,
                                        'user': UserModel(
                                          id: post.userId,
                                          name: displayName,
                                          avatarUrl: displayAvatar,
                                          email: '',
                                          role: UserRole.parent,
                                        ),
                                      },
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          RouteNames.profile,
                                          arguments: {
                                            'userId': post.userId,
                                            'user': UserModel(
                                              id: post.userId,
                                              name: displayName,
                                              avatarUrl: displayAvatar,
                                              email: '',
                                              role: UserRole.parent,
                                            ),
                                          },
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: AppTextStyles.body.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormatter.formatRelativeTime(
                                                post.createdAt),
                                            style: AppTextStyles.caption.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // PopupMenu: edit/delete for owner, report for others
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_horiz_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        Navigator.pushNamed(
                                          context,
                                          RouteNames.editPost,
                                          arguments: post,
                                        );
                                      } else if (value == 'delete') {
                                        final navigator = Navigator.of(context);
                                        final confirmed = await DeleteConfirmationDialog.show(
                                          context,
                                          title: 'حذف المنشور',
                                          message: 'هل أنت متأكد من حذف هذا المنشور؟',
                                        );
                                        if (!mounted) return;
                                        if (confirmed == true) {
                                          await viewModel.deletePost(post.id);
                                          if (!mounted) return;
                                          navigator.pop();
                                        }
                                      } else if (value == 'report') {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('تم إرسال البلاغ للمراجعة')),
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (isPostOwner) ...[
                                        const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('حذف', style: TextStyle(color: Colors.red)),
                                        ),
                                      ] else ...[
                                        const PopupMenuItem(value: 'report', child: Text('إبلاغ عن محتوى')),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                post.content,
                                style: AppTextStyles.body.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (post.hasImage && post.imageUrl != null) ...[
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: post.imageUrl!,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: Colors.grey[300]!,
                                      highlightColor: Colors.grey[100]!,
                                      child: Container(
                                        width: double.infinity,
                                        height: 200,
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      width: double.infinity,
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Actions Row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            _buildActionButton(
                               icon: post.isLikedBy(currentUserId)
                                   ? Icons.favorite_rounded
                                   : Icons.favorite_outline_rounded,
                               label: post.likesCount.toString(),
                               color: post.isLikedBy(currentUserId)
                                   ? const Color(0xFFEF4444)
                                   : const Color(0xFF64748B),
                               onTap: () =>
                                   viewModel.toggleLike(post.id),
                            ),
                            const SizedBox(width: 24),
                            _buildActionButton(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: post.commentsCount.toString(),
                              color: const Color(0xFF64748B),
                              onTap: () {
                                // Already on detail screen, just scroll down to comments
                                Scrollable.ensureVisible(
                                  context,
                                  duration: const Duration(milliseconds: 300),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: Color(0xFFE3F2FD), height: 1),

                      // Comments Section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'التعليقات',
                              style: AppTextStyles.h3.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (viewModel.isLoading &&
                                viewModel.comments.isEmpty)
                              const Center(child: CircularProgressIndicator())
                            else if (viewModel.comments.isEmpty)
                              const Center(child: Text('لا توجد تعليقات بعد'))
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: viewModel.comments.length,
                                itemBuilder: (context, index) {
                                  final comment = viewModel.comments[index];
                                  final isLiked = comment.isLikedBy(currentUserId);
                                  final isReply = comment.isReply;

                                  return Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      bottom: 12,
                                      start: isReply ? 56.0 : 0.0,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isReply) ...[
                                          Container(
                                            margin: const EdgeInsets.only(top: 10, right: 4),
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(color: Colors.grey, width: 1.5),
                                                right: BorderSide(color: Colors.grey, width: 1.5),
                                              ),
                                              borderRadius: BorderRadius.only(bottomRight: Radius.circular(4)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        AvatarWidget(
                                          imageUrl: comment.userAvatarUrl,
                                          name: comment.userName,
                                          size: isReply ? 28 : 32,
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              RouteNames.profile,
                                              arguments: {'userId': comment.userId},
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: GestureDetector(
                                                  onTap: () => _navigateToProfile(context, comment),
                                                  behavior: HitTestBehavior.opaque,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        comment.userName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        comment.content,
                                                        style: const TextStyle(fontSize: 13),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () => viewModel.toggleCommentLike(comment.id, currentUserId: currentUserId),
                                                    child: Text(
                                                      'إعجاب',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                                                        color: isLiked ? Colors.blue : Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  GestureDetector(
                                                    onTap: () {
                                                      viewModel.setReplyingTo(comment);
                                                      _commentFocusNode.requestFocus();
                                                    },
                                                    child: Text(
                                                      'رد',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Text(
                                                    DateFormatter.formatRelativeTime(comment.createdAt),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                                    ),
                                                  ),
                                                  if (comment.likesCount > 0) ...[
                                                    const Spacer(),
                                                    const Icon(Icons.favorite_rounded, size: 12, color: Colors.pink),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${comment.likesCount}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Reply Bar
              if (viewModel.replyingToComment != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Text(
                        'الرد على ${viewModel.replyingToComment!.userName}',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => viewModel.setReplyingTo(null),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              // Comment Input
              if (currentUser != null)
                CommentInputWidget(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  onSend: _handleAddComment,
                  isLoading: viewModel.isLoading,
                  userAvatar: currentUser.avatarUrl,
                  userName: currentUser.name,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context, dynamic model) {
    final userId = model is PostModel ? model.userId : (model as CommentModel).userId;
    final userName = model is PostModel ? model.userName : (model as CommentModel).userName;
    final userAvatarUrl = model is PostModel ? model.userAvatarUrl : (model as CommentModel).userAvatarUrl;

    Navigator.pushNamed(
      context,
      RouteNames.profile,
      arguments: {
        'userId': userId,
        'user': UserModel(
          id: userId,
          name: userName,
          avatarUrl: userAvatarUrl,
          email: '',
          role: UserRole.parent,
        ),
      },
    );
  }
}
