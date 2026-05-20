import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/enums/user_role.dart';
import '../../../shared/providers/notification_provider.dart';
import '../view_model/community_view_model.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../home/view_model/main_layout_view_model.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final bool isOwnProfile;
  final bool hideFollowButton;

  const PostCard({
    super.key,
    required this.post,
    this.isOwnProfile = false,
    this.hideFollowButton = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    final currentUser = authProvider.currentUser;
    final currentUserId = currentUser?.id ?? 0;
    final isOwner = currentUserId != 0 && post.userId == currentUserId;

    String displayName = post.userName;
    if (isOwner && currentUser != null && currentUser.name.isNotEmpty) {
      displayName = currentUser.name;
    }

    final String? displayAvatar =
        (isOwner && (post.userAvatarUrl == null || post.userAvatarUrl!.isEmpty))
            ? currentUser?.avatarUrl
            : post.userAvatarUrl;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(context, RouteNames.postDetail, arguments: post);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    AvatarWidget(
                      size: 40,
                      imageUrl: displayAvatar,
                      onTap: () => _navigateToProfile(context, post),
                    ),
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _navigateToProfile(context, post),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: AppTextStyles.label.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (post.userRole != null)
                                  Container(
                                    margin: const EdgeInsetsDirectional.only(start: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: post.userRole?.isDoctor == true
                                          ? Colors.blue.withValues(alpha: 0.1)
                                          : Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: post.userRole?.isDoctor == true ? Colors.blue : Colors.green,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      post.userRole?.isDoctor == true ? l10n.roleDoctor : l10n.roleParent,
                                      style: AppTextStyles.caption.copyWith(
                                        color: post.userRole?.isDoctor == true ? Colors.blue : Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              DateFormatter.formatRelativeTime(
                                post.createdAt,
                                isArabic: Localizations.localeOf(context).languageCode == 'ar',
                              ),
                              style: AppTextStyles.caption.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (isOwner)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            Navigator.pushNamed(context, RouteNames.editPost, arguments: post);
                          } else if (value == 'delete') {
                            final confirmed = await DeleteConfirmationDialog.show(
                              context,
                              title: l10n.deletePostTitle,
                              message: l10n.deletePostConfirm,
                            );
                            if (!context.mounted) return;
                            if (confirmed == true) {
                              context.read<CommunityViewModel>().deletePost(post.id);
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'edit', child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(l10n.edit),
                            ],
                          )),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (!widget.hideFollowButton && post.userId != 0 && post.userId != currentUserId)
                      Consumer<CommunityViewModel>(
                        builder: (context, viewModel, child) {
                          final isFollowing = viewModel.isFollowing(post.userId);

                          return Container(
                            margin: const EdgeInsetsDirectional.only(start: 8),
                            child: TextButton(
                              onPressed: () async {
                                try {
                                  final wasFollowing = viewModel.isFollowing(post.userId);
                                  await viewModel.toggleFollow(
                                    post.userId,
                                    currentUserId: currentUserId,
                                    onFollowingCountChanged: (isNowFollowing) {
                                      if (context.mounted) {
                                        final auth = context.read<AuthProvider>();
                                        auth.updateFollowingCount(isNowFollowing);
                                        auth.updateFollowersCount(isNowFollowing);
                                      }
                                    },
                                  );
                                  // Refresh notifications on new follow
                                  if (!wasFollowing && context.mounted) {
                                    context.read<NotificationProvider>().fetchNotifications();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.errorUpdateFollow),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                isFollowing ? l10n.followingStatus : l10n.follow,
                                style: TextStyle(
                                  color: isFollowing ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextContent(post.content, l10n),
                    if (post.hasImage && post.imageUrl != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: post.imageUrl!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(height: 200, color: theme.colorScheme.surface),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _ActionButton(
                      icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: post.isLiked ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      label: post.likesCount.toString(),
                      onTap: () => context.read<CommunityViewModel>().toggleLike(post.id),
                    ),
                    _ActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      label: post.commentsCount.toString(),
                      onTap: () {
                        Navigator.pushNamed(context, RouteNames.postDetail, arguments: post);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(String content, AppLocalizations l10n) {
    final isLong = content.length > 150;
    final displayContent = isLong && !_isExpanded ? '${content.substring(0, 150)}...' : content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayContent, style: AppTextStyles.body),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _isExpanded ? l10n.showLess : l10n.showMore,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToProfile(BuildContext context, PostModel post) {
    final l10n = AppLocalizations.of(context)!;
    if (post.userId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorUserNotFound)),
      );
      return;
    }

    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    if (currentUserId != null && currentUserId == post.userId) {
      // It's our own profile, switch the bottom nav to the Profile tab (index 4)
      context.read<MainLayoutViewModel>().setIndex(4);
    } else {
      // It's another user's profile, push the generic profile screen
      Navigator.pushNamed(
        context,
        RouteNames.profile,
        arguments: {
          'userId': post.userId,
          // Pass what we have so the profile can render immediately even on desktop.
          'user': UserModel(
            id: post.userId,
            name: post.userName,
            avatarUrl: post.userAvatarUrl,
            email: '',
            role: post.userRole ?? UserRole.parent,
          ),
        },
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
