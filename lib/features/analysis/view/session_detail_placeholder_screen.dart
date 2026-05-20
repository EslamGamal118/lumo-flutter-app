import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/session_analysis_model.dart';
import '../../session/view_model/session_view_model.dart';


class SessionDetailPlaceholderScreen extends StatefulWidget {
  final int? displayIndex;
  const SessionDetailPlaceholderScreen({super.key, this.displayIndex});

  @override
  State<SessionDetailPlaceholderScreen> createState() =>
      _SessionDetailPlaceholderScreenState();
}

class _SessionDetailPlaceholderScreenState
    extends State<SessionDetailPlaceholderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _chartType = 0; // 0 = Bars, 1 = Pie

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  // Fallback data when API data is not yet loaded or empty
  SessionAnalysisModel get _fallbackData => SessionAnalysisModel(
    id: '',
    title: _isAr ? 'جاري التحميل...' : 'Loading...',
    summary: _isAr ? 'لا توجد بيانات متاحة حالياً.' : 'No data available.',
    duration: _isAr ? '-- دقيقة' : '-- mins',
    engagementLevel: '--',
    recommendations: [],
    emotionDistribution: [
      EmotionData('happy', '😊', _isAr ? 'سعيد' : 'Happy', 0.0, const Color(0xFF22C55E)),
      EmotionData('neutral', '😐', _isAr ? 'محايد' : 'Neutral', 0.0, const Color(0xFF94A3B8)),
      EmotionData('sad', '😢', _isAr ? 'حزين' : 'Sad', 0.0, const Color(0xFFEF4444)),
      EmotionData('angry', '😠', _isAr ? 'غاضب' : 'Angry', 0.0, const Color(0xFFEAB308)),
      EmotionData('surprise', '😲', _isAr ? 'متفاجئ' : 'Surprised', 0.0, const Color(0xFFA855F7)),
      EmotionData('fear', '😨', _isAr ? 'خائف' : 'Fear', 0.0, const Color(0xFFF97316)),
    ],
    focusedPercentage: 0.0,
    notFocusedPercentage: 1.0,
  );

  SessionAnalysisModel get _sessionData {
    try {
      return context.read<SessionViewModel>().sessionDetails ?? _fallbackData;
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.displayIndex != null 
            ? (_isAr ? 'جلسة #${widget.displayIndex}' : 'Session #${widget.displayIndex}') 
            : _sessionData.title,
          style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.mutedForeground,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
          unselectedLabelStyle: AppTextStyles.body,
          tabs: [
            Tab(text: _isAr ? "التحليل السلوكي والانفعالي" : "Behavioral Analysis", icon: const Icon(Icons.analytics_outlined)),
            Tab(
                text: _isAr ? "التقرير الطبي" : "Medical Report",
                icon: const Icon(Icons.medical_information_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Behavioral & Emotional Analysis
          _buildVisualSummaryTab(),

          // TAB 2: Clinical Report
          _buildClinicalReportTab(),
        ],
      ),
    );
  }

  // ================= TAB 1: BEHAVIORAL & EMOTIONAL ANALYSIS =================

  Widget _buildVisualSummaryTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
    final focusPct = ((_sessionData.averageFocus ?? _sessionData.focusedPercentage) * 100).toInt();
    final notFocusPct = 100 - focusPct;

    // Determine dominant gaze direction
    String dominantGaze = _isAr ? 'المنتصف' : 'Center';
    if (_sessionData.gazeDistribution.isNotEmpty) {
      String topKey = '';
      double topVal = -1;
      _sessionData.gazeDistribution.forEach((key, val) {
        if (val > topVal) {
          topVal = val;
          topKey = key;
        }
      });
      switch (topKey.toUpperCase()) {
        case 'CENTER': dominantGaze = _isAr ? 'المنتصف' : 'Center'; break;
        case 'UP': dominantGaze = _isAr ? 'أعلى' : 'Up'; break;
        case 'DOWN': dominantGaze = _isAr ? 'أسفل' : 'Down'; break;
        case 'LEFT': dominantGaze = _isAr ? 'يسار' : 'Left'; break;
        case 'RIGHT': dominantGaze = _isAr ? 'يمين' : 'Right'; break;
        default: dominantGaze = topKey;
      }
    }

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
                _isAr ? 'تحليل التركيز' : 'Focus Analysis',
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '$focusPct%',
                    style: AppTextStyles.h1.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    _isAr ? 'مُركز' : 'Focused',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: const [
                        Color(0xFF10B981),
                        Color(0xFF94A3B8),
                      ],
                      stops: [
                        (_sessionData.averageFocus ?? _sessionData.focusedPercentage),
                        (_sessionData.averageFocus ?? _sessionData.focusedPercentage),
                      ],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcATop,
                  child: const Icon(Icons.psychology_rounded,
                      size: 100, color: Colors.white),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '$notFocusPct%',
                    style: AppTextStyles.h1.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    _isAr ? 'مشتت' : 'Distracted',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // ── Gaze Integration ──────────────────────────────
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.center_focus_strong_rounded, size: 18, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Text(
                  _isAr ? 'اتجاه النظر الغالب: $dominantGaze' : 'Dominant Gaze: $dominantGaze',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
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
                _isAr ? 'توزيع المشاعر' : 'Emotion Distribution',
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.bar_chart_rounded),
                    label: Text(_isAr ? 'أشرطة' : 'Bars')),
                ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.pie_chart_rounded),
                    label: Text(_isAr ? 'دائري' : 'Pie')),
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
                child: Text(_getEmotionLabel(e.id, e.label), style: AppTextStyles.bodySmall),
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
                    topEmotion != null ? _getEmotionLabel(topEmotion.id, topEmotion.label) : (_isAr ? 'تفاعل' : 'Interaction'),
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
                  _getEmotionLabel(e.id, e.label),
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
    final emotions = _sessionData.emotionDistribution;
    EmotionData? topEmotion;
    if (emotions.isNotEmpty) {
      topEmotion = emotions[0];
      for (final e in emotions) {
        if (e.percentage > topEmotion!.percentage) topEmotion = e;
      }
    }

    // Dynamic Voice Text
    final speechText = _sessionData.analytics?['speech_text']?.toString().trim() ?? '';
    final storyTrait = _sessionData.analytics?['story_trait']?.toString().trim() ?? '';
    final isCorrect = _sessionData.analytics?['is_correct'] as bool?;
    
    // The backend might return the keys with empty strings, nulls, or default booleans
    // even for image-only sessions. So we check if there's actual text.
    final bool hasValidSpeech = speechText.isNotEmpty && speechText.toLowerCase() != 'null';
    final bool hasValidTrait = storyTrait.isNotEmpty && storyTrait.toLowerCase() != 'null';
    final hasVoiceData = hasValidSpeech || hasValidTrait;

    // Focus metrics
    final focusPct = ((_sessionData.averageFocus ?? _sessionData.focusedPercentage) * 100).toInt();
    final focusStatus = focusPct > 70 
        ? (_isAr ? 'مستقر' : 'Stable') 
        : focusPct > 40 ? (_isAr ? 'متوسط' : 'Average') : (_isAr ? 'ضعيف' : 'Weak');
    final focusStatusColor = focusPct > 70 ? const Color(0xFF22C55E) : focusPct > 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

    // Emotion status
    final emotionLabel = topEmotion != null ? _getEmotionLabel(topEmotion.id, topEmotion.label) : (_isAr ? 'غير محددة' : 'Not specified');
    final emotionPct = ((topEmotion?.percentage ?? 0.0) * 100).toInt();

    // Voice status
    String voiceStatus;
    Color voiceStatusColor;
    if (hasVoiceData) {
      voiceStatus = _isAr ? 'تفاعل صوتي' : 'Vocal Interaction';
      voiceStatusColor = const Color(0xFF3B82F6);
    } else {
      voiceStatus = _isAr ? 'بصري فقط' : 'Visual Only';
      voiceStatusColor = const Color(0xFF94A3B8);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Report Header ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.medical_information_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayIndex != null 
                          ? (_isAr ? 'تقرير جلسة #${widget.displayIndex}' : 'Session Report #${widget.displayIndex}') 
                          : (_isAr ? 'التقرير الطبي' : 'Medical Report'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (_sessionData.date != null)
                        Text(
                          _sessionData.date!,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Clinical Items ──────────────────────────────────
          _buildReportItem(
            icon: Icons.sentiment_satisfied_alt_rounded,
            title: _isAr ? 'الحالة المزاجية الغالبة' : 'Dominant Mood',
            subtitle: 'Emotional Intelligence Model',
            trailing: _buildStatusChip(emotionLabel, topEmotion?.color ?? const Color(0xFF22C55E)),
            content: _isAr 
                ? 'الحالة المزاجية الغالبة: $emotionLabel بنسبة $emotionPct%.'
                : 'Dominant Mood: $emotionLabel at $emotionPct%.',
          ),
          _buildReportItem(
            icon: Icons.record_voice_over_rounded,
            title: _isAr ? 'التدفق الصوتي والقصص' : 'Voice Flow & Stories',
            subtitle: 'Educational Voice Flow Model',
            trailing: _buildStatusChip(voiceStatus, voiceStatusColor),
            content: hasVoiceData
                ? _buildVoiceContent(hasValidSpeech, speechText, hasValidTrait, storyTrait, isCorrect)
                : (_isAr ? 'لم يتم التقاط أي تفاعل صوتي خلال هذه الجلسة.' : 'No vocal interaction captured during this session.'),
          ),
          _buildReportItem(
            icon: Icons.visibility_rounded,
            title: _isAr ? 'التواصل البصري' : 'Eye Contact',
            subtitle: 'Eye Tracking Model',
            trailing: _buildStatusChip(focusStatus, focusStatusColor),
            content: _isAr 
                ? 'تمركزت نقاط النظر نحو الروبوت بنسبة $focusPct%.'
                : 'Gaze was focused on the robot at $focusPct%.',
          ),

          // ── Recommendations ──────────────────────────────────
          if (_sessionData.recommendations.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildReportItem(
              icon: Icons.lightbulb_outline_rounded,
              title: _isAr ? 'التوصيات' : 'Recommendations',
              subtitle: 'AI-Generated Recommendations',
              trailing: _buildStatusChip('${_sessionData.recommendations.length}', const Color(0xFF8B5CF6)),
              content: _sessionData.recommendations.map((r) => '• $r').join('\n'),
            ),
          ],

          // ── PDF Export Button ──────────────────────────────
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        _isAr ? 'جاري تجهيز ميزة الطباعة' : 'Print feature is being prepared',
                        style: const TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_isAr ? 'تصدير التقرير كـ PDF' : 'Export Report as PDF',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildVoiceContent(bool hasValidSpeech, String speechText, bool hasValidTrait, String storyTrait, bool? isCorrect) {
    if (!_isAr) {
      String content = 'The patient showed vocal interaction.';
      if (hasValidSpeech) {
        content += ' Said: "$speechText".';
      }
      if (hasValidTrait) {
        content += ' Story trait: $storyTrait.';
      }
      if (isCorrect != null) {
        content += ' Interaction was ${(isCorrect ? "correct" : "incorrect")}.';
      }
      return content;
    }

    String content = 'أظهر المريض تفاعلاً صوتياً.';
    if (hasValidSpeech) {
      content += ' حيث ذكر: "$speechText".';
    }
    if (hasValidTrait) {
      content += ' السمة القصصية: $storyTrait.';
    }
    if (isCorrect != null) {
      content += ' وكانت استجابته للأسئلة التفاعلية ${(isCorrect ? "صحيحة" : "خاطئة")}.';
    }
    return content;
  }

  String _getEmotionLabel(String id, String defaultLabel) {
    if (_isAr) return defaultLabel;
    switch (id.toLowerCase()) {
      case 'happy': return 'Happy';
      case 'sad': return 'Sad';
      case 'angry': return 'Angry';
      case 'fear':
      case 'fearful': return 'Fear';
      case 'surprise':
      case 'surprised': return 'Surprised';
      case 'disgust':
      case 'disgusted': return 'Disgust';
      case 'neutral': return 'Neutral';
      case 'calm': return 'Calm';
      default: return defaultLabel;
    }
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildReportItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(icon, color: AppColors.primary, size: 26),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
            trailing: trailing,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                content,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.7,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
