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
import '../view_model/analysis_view_model.dart';

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

    // Refresh AnalysisViewModel as requested to prevent "Fake Refresh" bug
    if (mounted) {
      try {
        await context.read<AnalysisViewModel>().loadParentAnalyses(widget.parentId);
      } catch (_) {}
    }

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

    // Take only the last 20 items (most recent 20 completed sessions)
    final chartSessions = validSessions.length > 20
        ? validSessions.skip(validSessions.length - 20).toList()
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
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '#${session.index}',
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
                    return Padding(
                      key: ValueKey('session_${session.id}'),
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
                            'جلسة #${session.index}',
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
                          onTap: () => _handleSessionTap(session, session.index),
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

