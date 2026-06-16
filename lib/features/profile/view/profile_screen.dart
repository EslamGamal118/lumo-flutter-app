import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../community/widgets/post_card.dart';
import '../../community/view_model/community_view_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/doctor_model.dart';
import '../../../shared/providers/notification_provider.dart';
import '../../../core/enums/user_role.dart';
import '../view_model/profile_view_model.dart';
import '../../chat/view_model/chat_view_model.dart';
import '../../../shared/providers/patient_provider.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../shared/widgets/no_internet_widget.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? user;
  final int? userId;

  const ProfileScreen({super.key, this.user, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _followersDelta = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      final targetUserId = widget.userId ?? widget.user?.id;
      final isMyProfile = targetUserId == null || targetUserId == currentUserId;

      if (isMyProfile) {
        context.read<CommunityViewModel>().loadMyPosts();
      }

      if (targetUserId != null) {
        // If we already have a user object (from post/comment payload),
        // load followers/followings lists to power counts on desktop.
        final profileVM = context.read<ProfileViewModel>();
        if (widget.user != null) {
          profileVM.updateUser(widget.user!);
          profileVM.loadFollowers(targetUserId);
          profileVM.loadFollowing(targetUserId);
        }

        profileVM.loadProfile(targetUserId, fallbackUser: widget.user).then((_) {
          if (mounted) {
            setState(() => _followersDelta = 0);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final communityViewModel = context.watch<CommunityViewModel>();
    final profileViewModel = context.watch<ProfileViewModel>();
    final patientProv = context.watch<PatientProvider>();
    final currentUser = authProvider.currentUser;

    final targetUserId = widget.userId ?? widget.user?.id;
    final isMyProfile = (widget.user == null && widget.userId == null) ||
        widget.userId == currentUser?.id ||
        widget.user?.id == currentUser?.id;

    final user =
        isMyProfile ? currentUser : (profileViewModel.user ?? widget.user);
    final isDoctor = user?.role.name == 'doctor';
    final doctorUser = isMyProfile && currentUser is DoctorModel ? currentUser : null;
    
    final isConnectedDoctor = currentUser?.role == UserRole.parent && 
                              isDoctor && 
                              targetUserId != null &&
                              patientProv.doctors.any((d) => d.id == targetUserId);

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final displayPosts = isMyProfile
        ? communityViewModel.myPosts
        : communityViewModel.posts
            .where((p) => p.userId == targetUserId)
            .toList();

    final int baseFollowers = (profileViewModel.user?.id == targetUserId
            ? profileViewModel.user?.followersCount
            : widget.user?.followersCount) ??
        0;
    final followersShow = isMyProfile 
        ? (currentUser?.followersCount ?? 0)
        : (baseFollowers + _followersDelta).clamp(0, 1 << 30);

    final int baseFollowing = isMyProfile
        ? (currentUser?.followingCount ?? 0)
        : ((profileViewModel.user?.id == targetUserId
            ? profileViewModel.user?.followingCount
            : widget.user?.followingCount) ?? 0);

    final followingShow = isMyProfile
        ? baseFollowing
        : baseFollowing;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Builder(
        builder: (context) {
          if (profileViewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final isConnected = context.watch<ConnectivityService>().isConnected;
          if (!isConnected && user == null) {
            return NoInternetWidget(
              onRetry: () {
                if (targetUserId != null) {
                  context.read<ProfileViewModel>().loadProfile(targetUserId);
                }
              },
            );
          }

          if (user == null && !isMyProfile) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_off_rounded,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      profileViewModel.errorMessage ??
                          'لم يتم العثور على المستخدم',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (targetUserId != null) {
                          context
                              .read<ProfileViewModel>()
                              .loadProfile(targetUserId);
                        }
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('رجوع'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final profileVM = context.read<ProfileViewModel>();
              final communityVM = context.read<CommunityViewModel>();
              if (targetUserId != null) {
                await profileVM.loadProfile(targetUserId);
              }
              await communityVM.loadMyPosts();
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    userId: targetUserId,
                    name: user?.name ?? 'User',
                    role: isDoctor ? l10n.roleDoctor : l10n.roleParent,
                    isDoctor: isDoctor,
                    photoUrl: user?.avatarUrl,
                    followers: followersShow,
                    following: followingShow,
                    isMyProfile: isMyProfile,
                    onDisconnect: isConnectedDoctor ? () async {
                      // The API takes the PATIENT's id (current user), not the doctor's id
                      final patientId = currentUser?.id;
                      if (patientId == null) return;
                      try {
                        await patientProv.disconnectPatient(patientId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم إلغاء الارتباط بنجاح'), backgroundColor: Colors.green),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل إلغاء الارتباط: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    } : null,
                    isFollowing: targetUserId != null &&
                        communityViewModel.isFollowing(targetUserId),
                    onToggleFollow: () async {
                      if (targetUserId == null) return;
                      final profileVM = context.read<ProfileViewModel>();
                      final communityVM = context.read<CommunityViewModel>();
                      final notificationProvider =
                          context.read<NotificationProvider>();
                      final messenger = ScaffoldMessenger.of(context);
                      final auth = context.read<AuthProvider>();
                      final currentUserId = auth.currentUser?.id;
                      if (currentUserId == null || targetUserId == currentUserId) return;

                      final wasFollowing = communityVM.isFollowing(targetUserId);

                      // Optimistic update للـ target user followers count
                      setState(() => _followersDelta += wasFollowing ? -1 : 1);
                      // Optimistic update لـ communityVM
                      communityVM.setFollowingState(targetUserId, !wasFollowing);

                      try {
                        // 1. تحديث Firebase (follower_ids, following_ids) + REST API
                        final targetUser = profileVM.user ?? widget.user;
                        if (targetUser != null) {
                          if (!wasFollowing) {
                            await auth.followUser(targetUser);
                          } else {
                            await auth.unfollowUser(targetUser);
                          }
                        } else {
                          // Fallback: REST only
                          await communityVM.toggleFollow(
                            targetUserId,
                            currentUserId: currentUserId,
                          );
                          // Mutual-follow: update current user counts
                          auth.updateFollowingCount(!wasFollowing);
                        }

                        if (!mounted) return;

                        // Reload target user profile counts from backend (source of truth)
                        await profileVM.loadProfile(targetUserId);

                        if (mounted) setState(() => _followersDelta = 0);

                        // Refresh notifications
                        if (!wasFollowing && mounted) {
                          notificationProvider.fetchNotifications();
                        }

                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(!wasFollowing
                                  ? 'تم متابعة ${user?.name}'
                                  : 'تم إلغاء متابعة ${user?.name}'),
                              backgroundColor: !wasFollowing ? Colors.green : null,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        // Rollback optimistic updates
                        setState(() => _followersDelta += wasFollowing ? 1 : -1);
                        communityVM.setFollowingState(targetUserId, wasFollowing);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('فشل تحديث المتابعة، حاول مرة أخرى'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    onMessageTap: () async {
                      if (targetUserId == null) return;
                      try {
                        final chatViewModel = context.read<ChatViewModel>();
                        final chatRoomId = await chatViewModel.startChat(
                          targetUserId,
                          receiverName: user?.name ?? '',
                          receiverAvatar: user?.avatarUrl,
                        );
                        if (!context.mounted) return;
                        Navigator.pushNamed(
                          context,
                          RouteNames.chatRoom,
                          arguments: {
                            'chatRoomId': chatRoomId,
                            'otherUserName': user?.name ?? '',
                            'otherUserAvatar': user?.avatarUrl,
                            'otherUserId': targetUserId.toString(),
                          },
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل فتح المحادثة: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    onEditProfile: () {
                      Navigator.pushNamed(context, RouteNames.editProfile);
                    },
                    onSettings: () {
                      Navigator.pushNamed(context, RouteNames.settings);
                    },
                    onSignOut: () async {
                      await authProvider.logout();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          RouteNames.login,
                          (route) => false,
                        );
                      }
                    },
                  ),
                ),

                if (isMyProfile)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Column(
                        children: isDoctor
                            ? [
                                _buildQuickAction(
                                  icon: Icons.people_alt_rounded,
                                  iconColor: AppColors.primary,
                                  title: l10n.viewPatients,
                                  subtitle: l10n.viewPatientsSubtitle,
                                  onTap: () {
                                    Navigator.pushNamed(
                                        context, RouteNames.doctorPatients);
                                  },
                                ),
                                if (doctorUser != null)
                                  ..._buildDoctorClinicLocation(theme, l10n, doctorUser)

                              ]
                            : [
                                _buildQuickAction(
                                  icon: Icons.child_care_rounded,
                                  iconColor: AppColors.primary,
                                  title: l10n.childProfile,
                                  subtitle: l10n.childProfileSubtitle,
                                  onTap: () {
                                    Navigator.pushNamed(
                                        context, RouteNames.childProfile);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildQuickAction(
                                  icon: Icons.analytics_rounded,
                                  iconColor: Colors.purple,
                                  title: l10n.viewAnalyses,
                                  subtitle: l10n.viewAnalysesSubtitle,
                                  onTap: () {
                                    Navigator.pushNamed(
                                        context, RouteNames.analyses);
                                  },
                                ),
                              ],
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.grid_view_rounded,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          isMyProfile ? l10n.myPosts : l10n.userPosts,
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${displayPosts.length} منشور',
                          style: AppTextStyles.caption.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (displayPosts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.post_add_rounded,
                              size: 64, color: theme.dividerColor),
                          const SizedBox(height: 16),
                          Text(
                            isMyProfile
                                ? 'لم تقم بنشر أي شيء بعد'
                                : 'لا توجد منشورات لهذا المستخدم',
                            style: TextStyle(color: theme.disabledColor),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        var post = displayPosts[index];
                        
                        // Inject user info if the backend excluded it (common in myPosts endpoints)
                        if (post.userName.trim().isEmpty && user != null) {
                          post = post.copyWith(
                            userName: user.name,
                            userAvatarUrl: user.avatarUrl,
                            userRole: user.role,
                          );
                        }

                        return PostCard(
                          post: post,
                          isOwnProfile: isMyProfile,
                          hideFollowButton: true,
                        );
                      },
                      childCount: displayPosts.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildDoctorClinicLocation(ThemeData theme, AppLocalizations l10n, DoctorModel doctor) {
    if (doctor.clinicLocation == null || doctor.clinicLocation!.isEmpty) {
      return [];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.orange, size: 24),
            ),
            title: Text(l10n.clinicLocation,
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(
              doctor.clinicLocation ?? '',
              style: AppTextStyles.caption.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildQuickAction({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title,
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: AppTextStyles.caption.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        )),
        trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final int? userId;
  final String name;
  final String role;
  final bool isDoctor;
  final String? photoUrl;
  final int followers;
  final int following;
  final bool isMyProfile;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onMessageTap;
  final VoidCallback onEditProfile;
  final VoidCallback onSettings;
  final VoidCallback onSignOut;
  final VoidCallback? onDisconnect;

  const _ProfileHeader({
    required this.userId,
    required this.name,
    required this.role,
    required this.isDoctor,
    this.photoUrl,
    required this.followers,
    required this.following,
    required this.isMyProfile,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onMessageTap,
    required this.onEditProfile,
    required this.onSettings,
    required this.onSignOut,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isMyProfile)
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: onSettings,
                )
              else
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              Text(
                isMyProfile ? l10n.profileTitle : name,
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
              ),
              if (isMyProfile)
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  onPressed: onSignOut,
                )
              else if (onDisconnect != null)
                IconButton(
                  icon: const Icon(Icons.person_remove_rounded, color: Colors.red),
                  tooltip: 'إلغاء الارتباط',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('إلغاء الارتباط'),
                        content: const Text('هل أنت متأكد من رغبتك في إنهاء الارتباط بهذا الطبيب؟ لن تتمكن من إرسال رسائل إليه إلا بعد إضافة جديدة.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('إلغاء'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(c);
                              onDisconnect!();
                            },
                            child: const Text('تأكيد', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),
          AvatarWidget(
            imageUrl: photoUrl,
            name: name,
            size: 100,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: (isDoctor ? Colors.blue : Colors.green).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: AppTextStyles.caption.copyWith(
                color: isDoctor ? Colors.blue : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(theme, l10n.following, following),
              Container(width: 1, height: 30, color: theme.dividerColor),
              _buildStatItem(theme, l10n.followers, followers),
            ],
          ),
          const SizedBox(height: 24),
          if (isMyProfile)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onEditProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(l10n.editProfile),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onToggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isFollowing ? theme.dividerColor : AppColors.primary,
                      foregroundColor:
                          isFollowing ? theme.textTheme.bodyLarge?.color : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(isFollowing ? 'متابع' : l10n.follow),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onMessageTap,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: Text(l10n.message),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
