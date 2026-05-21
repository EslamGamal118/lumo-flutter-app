import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// iconly removed — use Flutter `Icons` or FontAwesome instead

import '../../../core/di/dependency_injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/analysis/view_model/analysis_view_model.dart';
import '../../../features/profile/view_model/profile_view_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../community/view/community_screen.dart';
import '../../chat/view/chats_list_screen.dart';
import '../../chat/view/chatbot_screen.dart';
import '../view_model/main_layout_view_model.dart';
import '../../analysis/view/parent_analysis_screen.dart';
import '../../analysis/view/doctor_patients_screen.dart';
import '../../chat/view_model/chat_view_model.dart';
import '../../profile/view/profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;
      if (userId != null) {
        context.read<ChatViewModel>().loadChatRooms(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final navigationProvider = context.watch<MainLayoutViewModel>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final userRole = currentUser.role;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: navigationProvider.currentIndex,
        children: [
          const CommunityScreen(), // 0: Home
          ChangeNotifierProvider(  // 1: Analysis
            create: (_) => getIt<AnalysisViewModel>(),
            child: userRole.isDoctor
                ? const DoctorPatientsScreen()
                : const ParentAnalysisScreen(),
          ),
          const ChatbotScreen(), // 2: AI Assistant (center)
          const ChatsListScreen(), // 3: Chat
          ChangeNotifierProvider(           // 4: Profile
            create: (_) => getIt<ProfileViewModel>(),
            child: const ProfileScreen(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationProvider.currentIndex,
        onDestinationSelected: (index) {
          navigationProvider.setIndex(index);
          // Reload chat rooms when Chat tab is selected
          if (index == 3) {
            final userId = context.read<AuthProvider>().currentUser?.id;
            if (userId != null) {
              context.read<ChatViewModel>().loadChatRooms(userId);
            }
          }
        },
        backgroundColor: theme.bottomAppBarTheme.color ?? theme.cardColor,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded, color: AppColors.primary),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon:
                const Icon(Icons.bar_chart_rounded, color: AppColors.primary),
            label: userRole.isDoctor ? l10n.myPatients : l10n.analysis,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore_rounded, color: AppColors.primary),
            label: l10n.aiHelper,
          ),
          NavigationDestination(
            icon: Consumer<ChatViewModel>(
              builder: (context, chatVM, _) {
                final count = chatVM.totalUnreadCount;
                return Badge.count(
                  count: count,
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                );
              },
            ),
            selectedIcon: Consumer<ChatViewModel>(
              builder: (context, chatVM, _) {
                final count = chatVM.totalUnreadCount;
                return Badge.count(
                  count: count,
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary),
                );
              },
            ),
            label: l10n.chats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon:
                const Icon(Icons.person_rounded, color: AppColors.primary),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }
}
