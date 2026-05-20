import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/enums/user_role.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/parent_model.dart';
import '../../../data/models/chat_room_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/patient_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../view_model/chat_view_model.dart';
import 'chat_room_screen.dart';
import '../../ai_helper/view/ai_chat_screen.dart';
import '../../community/view_model/community_view_model.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../core/router/route_names.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id;

      context.read<ChatViewModel>().loadChatRooms(userId);

      if (auth.currentUser?.role == UserRole.doctor) {
        context.read<PatientProvider>().fetchPatients();
      } else if (auth.currentUser is ParentModel) {
        final parent = auth.currentUser as ParentModel;
        if (parent.connectedDoctorIds.isNotEmpty) {
          context
              .read<PatientProvider>()
              .fetchDoctors(parent.connectedDoctorIds);
        }
      }
    });
  }

  List<dynamic> _buildDisplayItems(
    List<ChatRoomModel> rooms,
    UserModel currentUser,
    List<UserModel> patients,
  ) {
    final List<dynamic> items = [];
    final currentUserIdStr = currentUser.id.toString();

    // Helper: sort rooms newest-first by lastMessageTimestamp
    List<ChatRoomModel> sortedNewest(List<ChatRoomModel> list) {
      final sorted = List<ChatRoomModel>.from(list);
      sorted.sort((a, b) {
        final aTime = a.lastMessageTimestamp ?? a.updatedAt;
        final bTime = b.lastMessageTimestamp ?? b.updatedAt;
        return bTime.compareTo(aTime);
      });
      return sorted;
    }

    if (currentUser.role == UserRole.doctor) {
      final activePatientIds = rooms
          .map((r) => r.getOtherParticipantId(currentUserIdStr))
          .where((id) => id.isNotEmpty)
          .toList();

      items.add('AI_BOT'); // pinned at top
      items.addAll(sortedNewest(rooms));

      for (final patient in patients) {
        if (!activePatientIds.contains(patient.id.toString())) {
          items.add(patient);
        }
      }
    } else {
      final parent = currentUser is ParentModel ? currentUser : null;
      final connectedDoctorIds = parent?.connectedDoctorIds ?? [];

      final doctorRooms = <ChatRoomModel>[];
      final otherRooms = <ChatRoomModel>[];

      for (final room in rooms) {
        final otherId = room.getOtherParticipantId(currentUserIdStr);
        if (otherId.isEmpty) continue;
        if (connectedDoctorIds.contains(otherId)) {
          doctorRooms.add(room);
        } else {
          otherRooms.add(room);
        }
      }

      items.add('AI_BOT'); // always pinned first
      items.addAll(sortedNewest(doctorRooms));
      items.addAll(sortedNewest(otherRooms));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Text(
          l10n.chatTitle,
          style: AppTextStyles.h1.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.textTheme.headlineMedium?.color,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: theme.dividerColor,
          ),
        ),
      ),
      body: Consumer3<ChatViewModel, AuthProvider, PatientProvider>(
        builder:
            (context, chatViewModel, authProvider, patientProvider, child) {
          final currentUser = authProvider.currentUser;
          if (currentUser == null) return SizedBox.shrink();

          if (chatViewModel.isLoading && chatViewModel.chatRooms.isEmpty) {
            return Center(child: CircularProgressIndicator());
          }

          final items = _buildDisplayItems(
            chatViewModel.chatRooms,
            currentUser,
            patientProvider.patients,
          );

          if (items.isEmpty ||
              (items.length == 1 &&
                  items[0] == 'AI_BOT' &&
                  chatViewModel.chatRooms.isEmpty)) {
            if (items.length == 1 && items[0] == 'AI_BOT') {
              return ListView(
                children: [
                  _buildAiChatTile(context, theme, l10n),
                  SizedBox(height: 100),
                  _buildEmptyState(l10n, theme),
                ],
              );
            }
            return _buildEmptyState(l10n, theme);
          }

          return RefreshIndicator(
            onRefresh: () async {
              final userId = authProvider.currentUser?.id;
              await context.read<ChatViewModel>().loadChatRooms(userId);
            },
            child: ListView.separated(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 72),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.dividerColor,
                ),
              ),
              itemBuilder: (context, index) {
                final item = items[index];

                if (item is String && item == 'AI_BOT') {
                  return _buildAiChatTile(context, theme, l10n);
                }

                if (item is ChatRoomModel) {
                  return _buildChatRoomTile(context, item, currentUser, theme);
                }

                if (item is UserModel) {
                  return _buildUserContactTile(context, item, currentUser, theme);
                }

                return SizedBox.shrink();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewChatBottomSheet(context, theme, l10n);
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildAiChatTile(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/images/ai_avatar.png',
          fit: BoxFit.cover,
        ),
      ),
      title: Text(l10n.aiHelper, style: AppTextStyles.label),
      subtitle: Text((isAr ? 'مساعدك الذكي دائم الاستعداد' : 'Your smart assistant is always ready'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AIChatScreen()),
        );
      },
    );
  }

  Widget _buildChatRoomTile(BuildContext context, ChatRoomModel room,
      UserModel currentUser, ThemeData theme) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final otherName = room.getOtherParticipantName(currentUser.id.toString());
    final otherAvatar =
        room.getOtherParticipantAvatar(currentUser.id.toString());

    final otherId = room.getOtherParticipantId(currentUser.id.toString());

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: () {
          final uid = int.tryParse(otherId);
          if (uid != null && uid != 0) {
            final fallbackUser = ParentModel(
              id: uid,
              name: otherName,
              email: '',
              childName: '',
              childAge: 0,
              avatarUrl: otherAvatar,
            );
            Navigator.pushNamed(
              context,
              RouteNames.profile,
              arguments: {'userId': uid, 'user': fallbackUser},
            );
          }
        },
        child: AvatarWidget(
          name: otherName,
          imageUrl: otherAvatar,
          size: 50,
        ),
      ),
      title: GestureDetector(
        onTap: () {
          final uid = int.tryParse(otherId);
          if (uid != null && uid != 0) {
            final fallbackUser = ParentModel(
              id: uid,
              name: otherName,
              email: '',
              childName: '',
              childAge: 0,
              avatarUrl: otherAvatar,
            );
            Navigator.pushNamed(
              context,
              RouteNames.profile,
              arguments: {'userId': uid, 'user': fallbackUser},
            );
          }
        },
        child: Text(otherName, style: AppTextStyles.label),
      ),
      subtitle: Text(
        room.lastMessage ?? (isAr ? 'إبدأ المحادثة الآن' : 'Start the conversation now'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: room.getUnreadCount(currentUser.id.toString()) > 0
              ? FontWeight.bold
              : FontWeight.normal,
          color: room.getUnreadCount(currentUser.id.toString()) > 0
              ? theme.textTheme.bodyLarge?.color
              : theme.textTheme.bodySmall?.color,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (room.lastMessageTimestamp != null)
            Text(
              "${room.lastMessageTimestamp!.hour}:${room.lastMessageTimestamp!.minute.toString().padLeft(2, '0')}",
              style: AppTextStyles.caption,
            ),
          if (room.getUnreadCount(currentUser.id.toString()) > 0)
            Container(
              margin: EdgeInsets.only(top: 4),
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                room.getUnreadCount(currentUser.id.toString()).toString(),
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
        ],
      ),
      onTap: () {
        final chatViewModel = context.read<ChatViewModel>();
        final userId = context.read<AuthProvider>().currentUser?.id;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: chatViewModel,
              child: ChatRoomScreen(
                chatRoomId: room.id,
                otherUserName: otherName,
                otherUserAvatar: otherAvatar,
                otherUserId: otherId,
              ),
            ),
          ),
        ).then((_) {
          if (userId != null) {
            chatViewModel.loadChatRooms(userId);
          }
        });
      },
    );
  }

  Widget _buildUserContactTile(BuildContext context, UserModel user,
      UserModel currentUser, ThemeData theme) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: () {
          if (user.id != 0) {
            Navigator.pushNamed(
              context,
              RouteNames.profile,
              arguments: {'userId': user.id, 'user': user},
            );
          }
        },
        child: AvatarWidget(
          name: user.name,
          imageUrl: user.profileImage ?? user.avatarUrl,
          size: 50,
        ),
      ),
      title: GestureDetector(
        onTap: () {
          if (user.id != 0) {
            Navigator.pushNamed(
              context,
              RouteNames.profile,
              arguments: {'userId': user.id, 'user': user},
            );
          }
        },
        child: Text(user.name, style: AppTextStyles.label),
      ),
      subtitle: Text((isAr ? 'إبدأ المحادثة الآن' : 'Start the conversation now'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () async {
        // ✅ FIX C-1 + C-2: استدعي POST /chat/start لتجيب chatRoomId ثابت من الـ backend
        try {
          final chatViewModel = context.read<ChatViewModel>();
          final chatRoomId = await chatViewModel.startChat(user.id);

          if (context.mounted) {
            final userId = context.read<AuthProvider>().currentUser?.id;
            Navigator.push(
              context,
              MaterialPageRoute(
                // ✅ FIX C-4: مرر الـ ChatViewModel الموجود بدل إنشاء واحد جديد
                builder: (_) => ChangeNotifierProvider.value(
                  value: chatViewModel,
                  child: ChatRoomScreen(
                    chatRoomId: chatRoomId,
                    otherUserName: user.name,
                    otherUserAvatar: user.profileImage ?? user.avatarUrl,
                    otherUserId: user.id.toString(),
                  ),
                ),
              ),
            ).then((_) {
              if (userId != null) {
                chatViewModel.loadChatRooms(userId);
              }
            });
          }
        } catch (e) {
          debugPrint('❌❌❌ FAIL CHAT START: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    (isAr ? 'فشل بدء المحادثة، راجع الـ Console لمعرفة الخطأ' : 'Failed to start conversation, check with Console for error')),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, ThemeData theme) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64, color: theme.dividerColor),
          SizedBox(height: 16),
          Text(
            (isAr ? "لا توجد رسائل بعد" : "No messages"),
            style: AppTextStyles.h3.copyWith(color: theme.disabledColor),
          ),
          SizedBox(height: 8),
          Text(
            (isAr ? "ابدأ التواصل مع الأطباء أو المرضى الآن" : "Start connecting with doctors or patients now"),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  void _showNewChatBottomSheet(
      BuildContext parentContext, ThemeData theme, AppLocalizations l10n) {
    final isAr = Localizations.localeOf(parentContext).languageCode == 'ar';
    final authProvider = parentContext.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;

    // Trigger data loading before showing the sheet so filters are populated
    if (currentUser.role == UserRole.doctor) {
      parentContext.read<PatientProvider>().fetchPatients();
    } else if (currentUser is ParentModel) {
      final parent = currentUser;
      if (parent.connectedDoctorIds.isNotEmpty) {
        parentContext.read<PatientProvider>().fetchDoctors(parent.connectedDoctorIds);
      }
    }
    // Ensure following list is loaded for the (isAr ? "أتابعهم" : "Following") filter
    parentContext.read<CommunityViewModel>().loadFollowingIfNeeded();

    // Variables declared OUTSIDE builder so they persist across setModalState rebuilds
    String searchQuery = "";
    int activeTab = 0; // 0: All, 1: Connected, 2: Following, 3: Recent

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setModalState) {

            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          (isAr ? "رسالة جديدة" : "One new message."),
                          style: AppTextStyles.h2
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  // Search Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.light
                            ? Colors.grey[100]
                            : theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        onChanged: (value) =>
                            setModalState(() => searchQuery = value),
                        decoration: InputDecoration(
                          hintText: (isAr ? "ابحث عن الاسم..." : "Search for the name..."),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Categories
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildCategoryChip(context, (isAr ? "الكل" : "ALL"), activeTab == 0,
                            () => setModalState(() => activeTab = 0)),
                        _buildCategoryChip(context, (isAr ? "مرتبط" : "related, linked, attached, united"), activeTab == 1,
                            () => setModalState(() => activeTab = 1)),
                        _buildCategoryChip(context, (isAr ? "أتابعهم" : "Following"), activeTab == 2,
                            () => setModalState(() => activeTab = 2)),
                        _buildCategoryChip(context, (isAr ? "الأخيرة" : "Crucial phase/critical stage)"), activeTab == 3,
                            () => setModalState(() => activeTab = 3)),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: Consumer3<PatientProvider, CommunityViewModel,
                        ChatViewModel>(
                      builder:
                          (context, patientProv, commProv, chatProv, child) {
                        // Aggregate Contacts
                        final connected = currentUser.role == UserRole.doctor
                            ? patientProv.patients
                            : patientProv.doctors;
                        final following = commProv.followingUsers;

                        // Extract recent participants from chat rooms
                        final Map<String, UserModel> recentMap = {};
                        for (final room in chatProv.chatRooms) {
                          final otherId = room
                              .getOtherParticipantId(currentUser.id.toString());
                          final otherName = room.getOtherParticipantName(
                              currentUser.id.toString());
                          final otherAvatar = room.getOtherParticipantAvatar(
                              currentUser.id.toString());

                          if (!recentMap.containsKey(otherId)) {
                            recentMap[otherId] = UserModel(
                              id: int.tryParse(otherId) ?? 0,
                              name: otherName,
                              avatarUrl: otherAvatar,
                              email: '',
                              role: UserRole.parent, // Placeholder role
                            );
                          }
                        }
                        final recent = recentMap.values.toList();

                        // Filter by tab
                        List<UserModel> pool = [];
                        if (activeTab == 0) {
                          final Map<int, UserModel> allMap = {};
                          for (final u in connected) {
                            allMap[u.id] = u;
                          }
                          for (final u in following) {
                            allMap[u.id] = u;
                          }
                          for (final u in recent) {
                            allMap[u.id] = u;
                          }
                          pool = allMap.values.toList();
                        } else if (activeTab == 1) {
                          pool = connected;
                        } else if (activeTab == 2) {
                          pool = following;
                        } else if (activeTab == 3) {
                          pool = recent;
                        }

                        // Filter by search
                        if (searchQuery.isNotEmpty) {
                          pool = pool
                              .where((u) => u.name
                                  .toLowerCase()
                                  .contains(searchQuery.toLowerCase()))
                              .toList();
                        }

                        if (pool.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_search_rounded,
                                    size: 64, color: theme.dividerColor),
                                SizedBox(height: 16),
                                Text((isAr ? "لا يوجد نتائج" : "No results"),
                                    style:
                                        TextStyle(color: theme.disabledColor)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: pool.length,
                          itemBuilder: (context, index) {
                            final user = pool[index];
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              leading: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context); // close bottom sheet
                                  Navigator.pushNamed(
                                    parentContext,
                                    RouteNames.profile,
                                    arguments: {'userId': user.id, 'user': user},
                                  );
                                },
                                child: AvatarWidget(
                                  name: user.name,
                                  imageUrl: user.avatarUrl,
                                  size: 44,
                                ),
                              ),
                              title: Text(user.name,
                                  style: AppTextStyles.label
                                      .copyWith(fontWeight: FontWeight.w600)),
                              subtitle: Text(user.role == UserRole.doctor
                                  ? (isAr ? "طبيب" : "DOCTOR")
                                  : ""),
                              onTap: () async {
                                Navigator.pop(context); // أقفل الـ bottom sheet

                                // ✅ FIX C-1 + C-2: استدعي POST /chat/start لتجيب chatRoomId ثابت من الـ backend
                                try {
                                  final chatViewModel =
                                      parentContext.read<ChatViewModel>();
                                  final chatRoomId =
                                      await chatViewModel.startChat(user.id);

                                  if (parentContext.mounted) {
                                    final userId = parentContext.read<AuthProvider>().currentUser?.id;
                                    Navigator.push(
                                      parentContext,
                                      MaterialPageRoute(
                                        // ✅ FIX C-4: مرر الـ ChatViewModel الموجود بدل إنشاء واحد جديد
                                        builder: (_) =>
                                            ChangeNotifierProvider.value(
                                          value: chatViewModel,
                                          child: ChatRoomScreen(
                                            chatRoomId: chatRoomId,
                                            otherUserName: user.name,
                                            otherUserAvatar: user.avatarUrl,
                                            otherUserId: user.id.toString(),
                                          ),
                                        ),
                                      ),
                                    ).then((_) {
                                      if (userId != null) {
                                        chatViewModel.loadChatRooms(userId);
                                      }
                                    });
                                  }
                                } catch (e) {
                                  debugPrint('FAIL CHAT START: $e');
                                  if (parentContext.mounted) {
                                    ScaffoldMessenger.of(parentContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            (isAr ? 'فشل بدء المحادثة، راجع الـ Console لمعرفة الخطأ' : 'Failed to start conversation, check with Console for error')),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
      BuildContext context, String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.primary.withValues(alpha: 0.1),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: isSelected
                  ? AppColors.primary
                  : Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}
