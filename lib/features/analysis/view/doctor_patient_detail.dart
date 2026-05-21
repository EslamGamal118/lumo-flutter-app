import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/providers/patient_provider.dart';
import '../../session/view_model/session_view_model.dart';
import '../../session/models/session_part.dart';
import '../../../data/models/session_analysis_model.dart';
import 'session_config_bottom_sheet.dart';
import 'session_detail_placeholder_screen.dart';

// EmotionData & SessionAnalysisModel are imported from
// '../../../data/models/session_analysis_model.dart'

class DoctorPatientDetail extends StatefulWidget {
  final int parentId;
  final String parentName;
  final String childName;

  const DoctorPatientDetail({
    super.key,
    required this.parentId,
    required this.parentName,
    required this.childName,
  });

  @override
  State<DoctorPatientDetail> createState() => _DoctorPatientDetailState();
}

class _DoctorPatientDetailState extends State<DoctorPatientDetail> {
  // New State Variable for the Robot Mock Flow
  bool hasSessionData = false;
  String _selectedFilter = 'الكل';
  
  bool _isFabExpanded = false;
  Timer? _fabCollapseTimer;

  @override
  void dispose() {
    _fabCollapseTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatientSessions();
    });
  }

  Future<void> _loadPatientSessions() async {
    final sessionViewModel = context.read<SessionViewModel>();
    await sessionViewModel.loadPatientSessions(widget.parentId);

    if (!mounted || sessionViewModel.errorMessage == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sessionViewModel.errorMessage!,
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: AppColors.destructive,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSessionTap(SessionAnalysisModel session, int displayIndex) async {
    if (!session.isComplete) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الجلسة لم تكتمل بعد لإظهار التحليلات'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final sessionId = int.tryParse(session.id);
    if (sessionId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح تفاصيل الجلسة'),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final sessionViewModel = context.read<SessionViewModel>();
    await sessionViewModel.loadSessionDetails(sessionId);

    if (!mounted) return;

    if (sessionViewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sessionViewModel.errorMessage!,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final details = sessionViewModel.sessionDetails;
    if (details == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر الحصول على تفاصيل الجلسة'),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<SessionViewModel>(),
          child: SessionDetailPlaceholderScreen(displayIndex: displayIndex),
        ),
      ),
    );
  }

  String _formatSessionDate(SessionAnalysisModel session) {
    // Prefer date from session list API
    final dateToFormat = session.date ?? session.startedAt ?? session.endedAt;
    if (dateToFormat == null || dateToFormat.isEmpty) {
      return 'تاريخ غير متوفر';
    }

    // Extract date part if it contains time (ISO format like "2026-05-13T10:00:00")
    final datePart = dateToFormat.split('T').first;
    return datePart.isEmpty ? dateToFormat : datePart;
  }

  Widget _buildStatusChip(SessionAnalysisModel session) {
    final isComplete = session.isComplete;
    final backgroundColor = isComplete
        ? AppColors.success.withValues(alpha: 0.12)
        : AppColors.primary.withValues(alpha: 0.12);
    final foregroundColor = isComplete ? AppColors.success : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isComplete ? 'مكتملة' : 'قيد الانتظار',
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _buildKpiRow(List<SessionAnalysisModel> completedSessions, List<SessionAnalysisModel> allSessions) {
    // Calculate average focus across completed sessions
    double avgFocus = 0;
    if (completedSessions.isNotEmpty) {
      final focusSum = completedSessions.fold<double>(0, (sum, s) {
        return sum + ((s.averageFocus ?? s.focusedPercentage) * 100);
      });
      avgFocus = focusSum / completedSessions.length;
    }

    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            icon: Icons.visibility_rounded,
            label: 'متوسط التركيز',
            value: '${avgFocus.toInt()}%',
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            icon: Icons.event_note_rounded,
            label: 'إجمالي الجلسات',
            value: '${allSessions.length}',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            icon: Icons.check_circle_outline_rounded,
            label: 'مكتملة',
            value: '${completedSessions.length}',
            color: const Color(0xFF22C55E),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFocusTrendChart(List<SessionAnalysisModel> completedSessions, List<SessionAnalysisModel> allSessions) {
    // Strictly filter only completed sessions for the chart data source
    // allSessions comes newest first, so we filter completed and then reverse to get oldest first.
    final validSessions = allSessions.where((s) => s.isComplete).toList().reversed.toList();

    // Take only the last 10 items (most recent 10 completed sessions)
    final chartSessions = validSessions.length > 10
        ? validSessions.skip(validSessions.length - 10).toList()
        : validSessions;

    Widget content;
    
    if (chartSessions.isEmpty) {
      content = const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            "لا توجد بيانات كافية لعرض الرسم البياني",
            style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
          ),
        ),
      );
    } else {
      final spots = chartSessions.asMap().entries.map((entry) {
        final session = entry.value;
        final focusPct = (session.averageFocus ?? session.focusedPercentage) * 100;
        
        // Plot sequentially without visual/numerical gaps (x = 1, 2, 3, 4)
        return FlSpot((entry.key + 1).toDouble(), focusPct.clamp(0, 100));
      }).toList();

      double minX = 1;
      double maxX = chartSessions.length.toDouble();
      if (minX == maxX) {
        minX = 0;
        maxX += 1;
      }

      content = SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minX: minX,
            maxX: maxX,
            minY: 0,
            maxY: 100,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt() - 1; // 0-based index for chartSessions
                    if (idx < 0 || idx >= chartSessions.length) {
                      return const SizedBox.shrink();
                    }
                    
                    final session = chartSessions[idx];
                    // Calculate the actual global session number (e.g., #5)
                    final globalIndex = allSessions.indexOf(session);
                    final displayIndex = allSessions.length - globalIndex;
                    
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '#$displayIndex',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 25,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}%',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.primary,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: Theme.of(context).colorScheme.surface,
                    strokeWidth: 2,
                    strokeColor: AppColors.primary,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'تطور التركيز عبر الجلسات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: widget.childName,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_remove_rounded, color: AppColors.destructive),
            tooltip: 'إلغاء ربط المريض',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).cardColor,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.destructive.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_remove_rounded,
                            color: AppColors.destructive,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'إلغاء ربط المريض',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'هل أنت متأكد أنك تريد إلغاء ربط المريض ${widget.childName}؟ سيتم إزالته من قائمة مرضاك.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(ctx).textTheme.bodySmall?.color,
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'تراجع',
                                  style: TextStyle(
                                    color: Theme.of(ctx).textTheme.bodyLarge?.color,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  try {
                                    await context.read<PatientProvider>().disconnectPatient(widget.parentId);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم إلغاء ربط المريض بنجاح', style: TextStyle(fontFamily: 'Cairo')),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      Navigator.pop(context); // Go back to patients list
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(context.read<PatientProvider>().error ?? 'فشل إلغاء الربط', style: const TextStyle(fontFamily: 'Cairo')),
                                          backgroundColor: AppColors.destructive,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.destructive,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'إلغاء الربط',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        isExtended: _isFabExpanded,
        onPressed: () {
          if (!_isFabExpanded) {
            setState(() => _isFabExpanded = true);
            _fabCollapseTimer?.cancel();
            _fabCollapseTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _isFabExpanded = false);
            });
          } else {
            setState(() => _isFabExpanded = false);
            _fabCollapseTimer?.cancel();
            SessionConfigBottomSheet.show(
              context,
              receiverId: widget.parentId,
              onSubmit: (List<SessionPart> parts) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تم إنشاء الجلسة بنجاح، في انتظار بدء الروبوت',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            );
          }
        },
        icon: const Icon(Icons.timer_rounded),
        label: const Text('إعداد جلسة جديدة',
            style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.primary,
      ),
      body: Consumer<SessionViewModel>(
        builder: (context, sessionViewModel, child) {
          final allSessions = sessionViewModel.patientSessions;

          if (sessionViewModel.isLoading && allSessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (allSessions.isEmpty) {
            return const EmptyState(
              icon: Icons.analytics_outlined,
              title: 'لا توجد تحليلات بعد',
              message: 'ستظهر التحليلات هنا فور انتهاء الروبوت من الجلسة',
            );
          }

          // Apply filter
          final sessions = _selectedFilter == 'الكل'
              ? allSessions
              : _selectedFilter == 'مكتملة'
                  ? allSessions.where((s) => s.isComplete).toList()
                  : allSessions.where((s) => !s.isComplete).toList();

          // Cumulative focus data (completed sessions only, reversed for chronological order)
          final completedSessions = allSessions.where((s) => s.isComplete).toList().reversed.toList();

          return RefreshIndicator(
            onRefresh: _loadPatientSessions,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // ── KPI Summary Cards ──────────────────────────
                _buildKpiRow(completedSessions, allSessions),
                const SizedBox(height: 12),

                // Focus Trend Chart
                _buildFocusTrendChart(completedSessions, allSessions),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['الكل', 'مكتملة', 'قيد الانتظار'].map((label) {
                        final isSelected = _selectedFilter == label;
                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: FilterChip(
                            label: Text(label, style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: isSelected ? Colors.white : AppColors.primary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            )),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedFilter = label),
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Session List
                if (sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('لا توجد جلسات بهذا التصنيف',
                          style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                    ),
                  )
                else
                  ...sessions.asMap().entries.map((entry) {
                    final session = entry.value;
                    // Calculate displayIndex based on position in allSessions
                    final globalIndex = allSessions.indexOf(session);
                    final displayIndex = allSessions.length - globalIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          title: Text(
                            'جلسة #$displayIndex',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _formatSessionDate(session),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                          trailing: _buildStatusChip(session),
                          onTap: () => _handleSessionTap(session, displayIndex),
                        ),
                      ),
                    );
                  }),

                // Bottom padding so FAB doesn't obscure last item
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================= THE INLINE TAB CONTROLLER =================

class _InlineSessionDetails extends StatefulWidget {
  const _InlineSessionDetails();

  @override
  State<_InlineSessionDetails> createState() => _InlineSessionDetailsState();
}

class _InlineSessionDetailsState extends State<_InlineSessionDetails>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _chartType = 0; // 0 = Bars, 1 = Pie

  // Fallback data when API data is not yet loaded or empty
  final SessionAnalysisModel _fallbackData = SessionAnalysisModel(
    id: '',
    title: 'جاري التحميل...',
    summary: 'لا توجد بيانات متاحة حالياً.',
    duration: '-- دقيقة',
    engagementLevel: '--',
    recommendations: [],
    emotionDistribution: [
      EmotionData('happy', '😊', 'سعيد', 0.0, const Color(0xFF22C55E)),
      EmotionData('neutral', '😐', 'محايد', 0.0, const Color(0xFF94A3B8)),
      EmotionData('sad', '😢', 'حزين', 0.0, const Color(0xFFEF4444)),
      EmotionData('angry', '😠', 'غاضب', 0.0, const Color(0xFFEAB308)),
      EmotionData('surprise', '😲', 'متفاجئ', 0.0, const Color(0xFFA855F7)),
      EmotionData('fear', '😨', 'خائف', 0.0, const Color(0xFFF97316)),
    ],
    focusedPercentage: 0.0,
    notFocusedPercentage: 1.0,
  );

  /// Returns API data if available, otherwise fallback.
  SessionAnalysisModel get _sessionData {
    try {
      final vm = context.read<SessionViewModel>();
      return vm.sessionDetails ?? _fallbackData;
    } catch (_) {
      return _fallbackData;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TabBar Strip
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.mutedForeground,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            unselectedLabelStyle: AppTextStyles.body,
            tabs: const [
              Tab(text: "التحليل السلوكي والانفعالي", icon: Icon(Icons.analytics_outlined)),
              Tab(
                  text: "التقرير السريري",
                  icon: Icon(Icons.medical_information_outlined)),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Visual Summary
              _buildVisualSummaryTab(),

              // TAB 2: Clinical Report
              _buildClinicalReportTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ================= TAB 1: VISUAL SUMMARY =================

  Widget _buildVisualSummaryTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFocusAnalysisBar(),
          const SizedBox(height: 24),
          _buildEmotionChart(),
        ],
      ),
    );
  }

  Widget _buildFocusAnalysisBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.remove_red_eye_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'تحليل التركيز',
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(_sessionData.focusedPercentage * 100).toInt()}%',
                    style: AppTextStyles.h1.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    'مُركز',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: const [
                      Color(0xFF10B981),
                      Color(0xFF94A3B8),
                    ],
                    stops: [
                      _sessionData.focusedPercentage,
                      _sessionData.focusedPercentage,
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcATop,
                child: const Icon(Icons.psychology_rounded,
                    size: 100, color: Colors.white),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(_sessionData.notFocusedPercentage * 100).toInt()}%',
                    style: AppTextStyles.h1.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    'مشتت',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'توزيع المشاعر',
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.bar_chart_rounded),
                    label: Text('أشرطة')),
                ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.pie_chart_rounded),
                    label: Text('دائري')),
              ],
              selected: {_chartType},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _chartType = newSelection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: AppColors.primary,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_chartType == 0) _buildBarChart(),
          if (_chartType == 1) _buildPieChart(),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return Column(
      children: _sessionData.emotionDistribution.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(e.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text(e.label, style: AppTextStyles.bodySmall),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: e.percentage,
                    backgroundColor: e.color.withValues(alpha: 0.1),
                    color: e.color,
                    minHeight: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('${(e.percentage * 100).toInt()}%',
                    style: AppTextStyles.caption
                        .copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieChart() {
    final emotions = _sessionData.emotionDistribution;
    EmotionData? topEmotion;
    if (emotions.isNotEmpty) {
      topEmotion =
          emotions.reduce((a, b) => a.percentage > b.percentage ? a : b);
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    topEmotion != null
                        ? '${(topEmotion.percentage * 100).toInt()}٪'
                        : '--٪',
                    style: AppTextStyles.h1.copyWith(
                      color: topEmotion?.color ?? AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                  Text(
                    topEmotion != null ? topEmotion.label : 'تفاعل',
                    style: AppTextStyles.caption
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 60,
                  sections: emotions.map((e) {
                    final isTop = e == topEmotion;
                    return PieChartSectionData(
                      color: e.color,
                      value: e.percentage * 100,
                      title: '',
                      radius: isTop ? 25.0 : 20.0,
                      badgeWidget: isTop
                          ? Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black12, blurRadius: 4)
                                ],
                              ),
                              child: Text(e.emoji,
                                  style: const TextStyle(fontSize: 16)),
                            )
                          : null,
                      badgePositionPercentageOffset: 0.9,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: emotions.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: e.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  e.label,
                  style: AppTextStyles.caption
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // ================= TAB 2: CLINICAL REPORT =================

  Widget _buildClinicalReportTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            "تفاصيل أجزاء الجلسة",
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Part 1: Interactive Games
          _buildSessionPartCard(
            partTitle: "الجزء الأول: الألعاب التفاعلية",
            subTitle: "لعبة تطابق الألوان (Color Matching)",
            performanceText: "حل اللعبة بشكل صحيح (Solved correctly)",
            aiOutputText: "الحالة المزاجية (سعيد)، التركيز (عالي)",
            icon: Icons.extension_rounded,
            themeColor: const Color(0xFF10B981), // Emerald/Green
          ),
          const SizedBox(height: 16),

          // Part 2: Educational Stories
          _buildSessionPartCard(
            partTitle: "الجزء الثاني: القصص التفاعلية",
            subTitle: "قصة تعليمية (Educational Story)",
            performanceText: "استمع للنهاية (Listened to the end)",
            aiOutputText: "الحالة المزاجية (حزين/مشتت)، التركيز (ضعيف)",
            icon: Icons.menu_book_rounded,
            themeColor: const Color(0xFFF59E0B), // Orange/Warning
          ),
          const SizedBox(height: 32),

          // AI Recommendation Card
          _buildAIRecommendationCard(),
        ],
      ),
    );
  }

  Widget _buildSessionPartCard({
    required String partTitle,
    required String subTitle,
    required String performanceText,
    required String aiOutputText,
    required IconData icon,
    required Color themeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: themeColor, size: 28),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partTitle,
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subTitle,
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "الأداء: $performanceText",
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.analytics_outlined, size: 20, color: themeColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "تحليل الذكاء الاصطناعي: $aiOutputText",
                        style: AppTextStyles.body.copyWith(
                          color: themeColor.withValues(alpha: 0.9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.1), // Indigo light
            const Color(0xFFA855F7).withValues(alpha: 0.05), // Purple light
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF6366F1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "توصيات المساعد الذكي",
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4338CA), // Indigo prominent
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "بناءً على تحليل بيانات هذه الجلسة والجلسات السابقة، يُظهر الطفل تفاعلاً وتركيزاً ممتازاً أثناء الألعاب البصرية، بينما يقل تركيزه وتتغير حالته المزاجية للحزن أثناء سرد القصص. نوصي بتقليل مدة القصص إلى 5 دقائق وزيادة الألعاب التفاعلية.",
            style: AppTextStyles.body.copyWith(
              height: 1.8,
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
