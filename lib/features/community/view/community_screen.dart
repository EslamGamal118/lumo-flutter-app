import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/community_header.dart';
import '../widgets/quick_post_widget.dart';
import '../widgets/post_card.dart';
import '../view_model/community_view_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../shared/widgets/no_internet_widget.dart';


class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // Start fetching data immediately on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        context.read<CommunityViewModel>().fetchPosts(
          userId: authProvider.currentUser?.id
        );
      }
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    
    // If switched to "Following" tab (index 1), refresh it
    if (_tabController.index == 1) {
      context.read<CommunityViewModel>().loadFollowingFeed();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Sticky Header ─────────────────────────────────
            const CommunityHeader(),

            // ── Tab Bar ───────────────────────────────────────
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.textTheme.bodySmall?.color,
              indicatorColor: theme.colorScheme.primary,
              tabs: [
                Tab(text: l10n.explore),
                Tab(text: l10n.following),
              ],
            ),

            // ── Scrollable Feed ───────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const _CommunityFeedWrapper(isExplore: true),
                  const _CommunityFeedWrapper(isExplore: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityFeedWrapper extends StatefulWidget {
  final bool isExplore;
  const _CommunityFeedWrapper({required this.isExplore});

  @override
  State<_CommunityFeedWrapper> createState() => _CommunityFeedWrapperState();
}

class _CommunityFeedWrapperState extends State<_CommunityFeedWrapper> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final viewModel = context.read<CommunityViewModel>();
      if (widget.isExplore) {
        viewModel.fetchMoreExplore();
      } else {
        viewModel.fetchMoreFollowing();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        if (widget.isExplore) {
          await context.read<CommunityViewModel>().loadExploreFeed();
        } else {
          await context.read<CommunityViewModel>().loadFollowingFeed();
        }
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: QuickPostWidget(),
          ),
          Consumer<CommunityViewModel>(
            builder: (context, viewModel, child) {
              final posts = widget.isExplore ? viewModel.explorePosts : viewModel.followingPosts;
              
              final isConnected = context.watch<ConnectivityService>().isConnected;
              
              if (!isConnected && posts.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: NoInternetWidget(
                    onRetry: () => widget.isExplore ? viewModel.loadExploreFeed() : viewModel.loadFollowingFeed(),
                  ),
                );
              }

              // Show shimmer if loading OR if not yet initialized (first load)
              if ((viewModel.isLoading || !viewModel.isInitialized) && posts.isEmpty) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ShimmerCard(),
                    ),
                    childCount: 3,
                  ),
                );
              }

              if (viewModel.errorMessage != null && posts.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            viewModel.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => widget.isExplore ? viewModel.loadExploreFeed() : viewModel.loadFollowingFeed(),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (posts.isEmpty) {
                final isFollowingAnyone = viewModel.followingCount > 0;
                
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: widget.isExplore ? Icons.article_outlined : Icons.people_outline_rounded,
                    title: widget.isExplore 
                        ? 'لا توجد منشورات بعد' 
                        : (isFollowingAnyone ? 'لا توجد منشورات' : 'لا تتابع أحداً بعد'),
                    message: widget.isExplore 
                        ? 'كن أول من ينشر في المجتمع' 
                        : (isFollowingAnyone ? 'الأشخاص الذين تتابعهم لم ينشروا شيئاً بعد' : 'تابع بعض المستخدمين لرؤية منشوراتهم هنا'),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == posts.length) {
                      return viewModel.isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox(height: 32); // Spacer at bottom
                    }
                    return PostCard(post: posts[index]);
                  },
                  childCount: posts.length + 1,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
