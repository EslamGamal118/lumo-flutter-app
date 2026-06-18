import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/parent_model.dart';
import '../../../data/models/session_analysis_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/patient_provider.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../session/view_model/session_view_model.dart';
import 'session_detail_placeholder_screen.dart';


class ParentAnalysisScreen extends StatefulWidget {
  const ParentAnalysisScreen({super.key});

  @override
  State<ParentAnalysisScreen> createState() => _ParentAnalysisScreenState();
}

class _ParentAnalysisScreenState extends State<ParentAnalysisScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      await Future.wait([
        context.read<SessionViewModel>().loadMySessions(),
        if (currentUser is ParentModel)
          context
              .read<PatientProvider>()
              .fetchParentConnectedDoctors(currentUser.id),
      ]);
    }
  }

  String _resolveImageUrl(String url) {
    if (url.startsWith('http')) return url;
    if (!url.startsWith('/')) url = '/$url';
    return 'https://app2.clickexpress.delivery$url';
  }

  String _formatSessionDate(SessionAnalysisModel session) {
    final dateToFormat = session.date ?? session.startedAt;
    if (dateToFormat == null || dateToFormat.isEmpty) return 'تاريخ غير معروف';
    final datePart = dateToFormat.split('T').first;
    return datePart.isEmpty ? dateToFormat : datePart;
  }

  Widget _buildChildHeader(ParentModel parent) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final hasImage =
        parent.avatarUrl != null && parent.avatarUrl!.isNotEmpty;

    // Fetch doctor info if available
    final patientProvider = context.watch<PatientProvider>();
    final doctor = patientProvider.doctors.isNotEmpty
        ? patientProvider.doctors.first
        : null;
    final hasDoctorImage =
        doctor?.avatarUrl != null && doctor!.avatarUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ── Child Side ──
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      image: hasImage
                          ? DecorationImage(
                              image: NetworkImage(
                                  _resolveImageUrl(parent.avatarUrl!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color:
                          hasImage ? null : Colors.white.withValues(alpha: 0.2),
                    ),
                    child: hasImage
                        ? null
                        : const Icon(Icons.face_retouching_natural_rounded,
                            color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          parent.childName.isNotEmpty
                              ? parent.childName
                              : (isAr ? 'الطفل' : 'Child'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.cake_rounded,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              parent.childAgeText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Vertical Divider ──
            if (doctor != null) ...[
              const VerticalDivider(
                color: Colors.white24,
                thickness: 1,
                width: 24,
                indent: 4,
                endIndent: 4,
              ),

              // ── Doctor Side ──
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        image: hasDoctorImage
                            ? DecorationImage(
                                image: NetworkImage(
                                    _resolveImageUrl(doctor.avatarUrl!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: hasDoctorImage
                            ? null
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                      child: hasDoctorImage
                          ? null
                          : const Icon(Icons.medical_services_rounded,
                              color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            doctor.name.isNotEmpty
                                ? doctor.name
                                : (isAr ? 'الطبيب المعالج' : 'Doctor'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.verified_user_rounded,
                                  color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                (isAr ? 'الطبيب المعالج' : 'Doctor'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(List<SessionAnalysisModel> completedSessions,
      List<SessionAnalysisModel> allSessions) {
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

  Widget _buildFocusTrendChart(List<SessionAnalysisModel> completedSessions,
      List<SessionAnalysisModel> allSessions) {
    final validSessions =
        allSessions.where((s) => s.isComplete).toList().reversed.toList();
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
        final focusPct =
            (session.averageFocus ?? session.focusedPercentage) * 100;
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
                    final idx = value.toInt() - 1;
                    if (idx < 0 || idx >= chartSessions.length) {
                      return const SizedBox.shrink();
                    }
                    final session = chartSessions[idx];
                    final globalIndex = allSessions.indexOf(session);
                    final displayIndex = allSessions.length - globalIndex;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '#$displayIndex',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
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
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              Icon(Icons.trending_up_rounded,
                  color: AppColors.primary, size: 22),
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
    final theme = Theme.of(context);
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final parent = (currentUser is ParentModel) ? currentUser : null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          parent != null && parent.childName.isNotEmpty
              ? 'أداء ${parent.childName} في الجلسات'
              : 'أداء الطفل',
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: Consumer<SessionViewModel>(
        builder: (context, viewModel, child) {
          final allSessions = viewModel.patientSessions;

          if (viewModel.isLoading && allSessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.errorMessage != null && allSessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    viewModel.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('إعادة المحاولة',
                        style: TextStyle(fontFamily: 'Cairo')),
                  ),
                ],
              ),
            );
          }

          final completedSessions =
              allSessions.where((s) => s.isComplete).toList();

          if (completedSessions.isEmpty) {
            return const EmptyState(
              icon: Icons.analytics_outlined,
              title: 'لا توجد تحليلات بعد',
              message: 'ستظهر تقارير الجلسات هنا فور إتمامها.',
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (parent != null) _buildChildHeader(parent),

                _buildKpiRow(completedSessions, allSessions),
                const SizedBox(height: 16),

                _buildFocusTrendChart(completedSessions, allSessions),

                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    'سجل الجلسات المكتملة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                // Session List
                ...completedSessions.asMap().entries.map((entry) {
                  final session = entry.value;
                  final globalIndex = allSessions.indexOf(session);
                  final displayIndex = allSessions.length - globalIndex;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      elevation: 0,
                      color: theme.colorScheme.surface,
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
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 14,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Text(
                                _formatSessionDate(session),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 13,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'مكتملة',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () async {
                          final sessionId = int.tryParse(session.id);
                          if (sessionId != null) {
                            await viewModel.loadSessionDetails(sessionId);
                          }
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: viewModel,
                                child: SessionDetailPlaceholderScreen(
                                    displayIndex: displayIndex),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
