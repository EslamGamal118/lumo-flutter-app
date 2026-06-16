import 'dart:convert';
import 'package:flutter/material.dart';

class EmotionData {
  final String id;
  final String emoji;
  final String label;
  final double percentage; // 0.0 to 1.0
  final Color color;

  EmotionData(this.id, this.emoji, this.label, this.percentage, this.color);

  factory EmotionData.fromJson(Map<String, dynamic> json) {
    return EmotionData(
      json['id'] as String,
      json['emoji'] as String,
      json['label'] as String,
      (json['percentage'] as num).toDouble(),
      Color(int.parse(json['color'].toString().replaceFirst('#', '0xFF'))),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emoji': emoji,
      'label': label,
      'percentage': percentage,
      'color': '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    };
  }
}

/// Represents a single gaze direction entry with its percentage.
class GazeData {
  final String direction;
  final String label;
  final double percentage; // 0.0 to 1.0
  final Color color;
  final IconData icon;

  GazeData(this.direction, this.label, this.percentage, this.color, this.icon);
}

class SessionAnalysisModel {
  final String id;
  final String title;
  final String summary;
  final String duration;
  final String engagementLevel;
  final bool isComplete;
  final List<String> recommendations;
  final List<EmotionData> emotionDistribution;
  final Map<String, double> gazeDistribution;
  final double focusedPercentage;
  final double notFocusedPercentage;
  final String? notes;
  final String? status;
  final String? startedAt;
  final String? endedAt;
  final String? date; // Date from session list API (e.g., "2026-05-13")
  final double? averageFocus; // maps from `average_focus` (backend pre-calculated)
  final Map<String, dynamic>? analytics; // raw analytic fields from API

  SessionAnalysisModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.duration,
    required this.engagementLevel,
    this.isComplete = false,
    required this.recommendations,
    required this.emotionDistribution,
    this.gazeDistribution = const {},
    required this.focusedPercentage,
    required this.notFocusedPercentage,
    this.notes,
    this.status,
    this.startedAt,
    this.endedAt,
    this.date,
    this.averageFocus,
    this.analytics,
  });

  // ─── Factory for Session List API Response ──────────────────────────────
  /// Maps the session list response where:
  ///   - `session_id` → id
  ///   - `date` → date
  ///   - `is_completed` → isComplete
  factory SessionAnalysisModel.fromJson(Map<String, dynamic> json) {
    // Try session_id first (from session list API), fall back to id
    final sessionId = json['session_id'] ?? json['id'];
    
    // Try date field (from session list API)
    final dateStr = json['date'] as String?;
    
    // Try is_completed first (from session list API), fall back to is_complete
    final isCompleted = json['is_completed'] ?? json['is_complete'] ?? false;

    return SessionAnalysisModel(
      id: sessionId.toString(),
      title: json['title'] as String? ?? 'جلسة #$sessionId',
      summary: json['summary'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      engagementLevel: json['engagement_level'] as String? ?? '',
      isComplete: isCompleted as bool,
      recommendations: List<String>.from(json['recommendations'] as List? ?? []),
      emotionDistribution: (json['emotion_distribution'] as List?)
              ?.map((e) => EmotionData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      gazeDistribution: {},
      focusedPercentage: (json['focused_percentage'] as num?)?.toDouble() ?? 0.0,
      notFocusedPercentage: (json['not_focused_percentage'] as num?)?.toDouble() ?? 0.0,
      date: dateStr,
      averageFocus: (json['average_focus'] is num)
        ? (json['average_focus'] as num).toDouble()
        : (json['average_focus'] is String ? double.tryParse(json['average_focus']) : null),
      analytics: json['analytic'] as Map<String, dynamic>? ?? json['analytics'] as Map<String, dynamic>?,
    );
  }

  // ─── API factory (for Islam's backend /sessions/{id}) ──────────────────────

  /// Parses the new API response where:
  ///   - `emotion_distribution` is `Map<String, double>` (e.g. {"Happy": 35.0})
  ///   - Also handles session list response with `session_id`, `date`, `is_completed`
  factory SessionAnalysisModel.fromApiJson(Map<String, dynamic> json) {
    // ── Parse ID ────────────────────────────────────────────────────────────
    final sessionId = json['session_id'] ?? json['id'];
    
    // ── Parse date ──────────────────────────────────────────────────────────
    final dateStr = json['date'] as String? ?? json['created_at'] as String?;

    // ── Parse average_focus from top level ──────────────────────────────────
    // API might return 'average_focus', 'focused_percentage', 'focus_score', or it might be inside 'analytic'
    final topAnalyticFocus = json['analytic'] is Map ? (json['analytic']['average_focus'] ?? json['analytic']['focus_score'] ?? json['analytic']['focused_percentage']) : null;
    final topAnalyticsFocus = json['analytics'] is Map ? (json['analytics']['average_focus'] ?? json['analytics']['focus_score'] ?? json['analytics']['focused_percentage']) : null;
    
    final rawAvgFocus = json['average_focus'] ?? json['focused_percentage'] ?? json['focus_score'] ?? topAnalyticFocus ?? topAnalyticsFocus;
    double? avgFocus;
    if (rawAvgFocus is num) {
      avgFocus = rawAvgFocus.toDouble();
    } else if (rawAvgFocus is String) {
      avgFocus = double.tryParse(rawAvgFocus.replaceAll('%', '').trim());
    }

    // ── Extract analytics from segments[] ───────────────────────────────────
    // The emotion_distribution and gaze_distribution live inside each
    // segment's 'analytic' field. We aggregate across all segments.
    final Map<String, double> aggregatedEmotions = {};
    final Map<String, double> aggregatedGaze = {};
    double segmentFocusPctSum = 0.0;
    int segmentFocusCount = 0;
    int segmentsWithEmotions = 0;
    Map<String, dynamic>? firstAnalytic;

    final segments = json['segments'];
    if (segments is List) {
      for (final seg in segments) {
        if (seg is! Map<String, dynamic>) continue;
        
        final segAnalytic = seg['analytic'] ?? seg['analytics'];
        if (segAnalytic is Map<String, dynamic>) {
          if (firstAnalytic == null) {
            firstAnalytic = Map<String, dynamic>.from(segAnalytic);
            // Defensively clean literal "null" strings
            for (final key in ['speech_text', 'story_trait']) {
              final val = firstAnalytic[key];
              if (val is String && val.trim().toLowerCase() == 'null') {
                firstAnalytic[key] = null;
              }
            }
          }

          // Accumulate emotions (Exact AI Key: 'emotion_distribution' or fallback 'emotions')
          dynamic rawEmo = segAnalytic['emotion_distribution'] ?? segAnalytic['emotions'];
          if (rawEmo is String) {
            try { rawEmo = jsonDecode(rawEmo); } catch (_) {}
          }
          if (rawEmo is Map<String, dynamic>) {
            segmentsWithEmotions++;
            for (final e in rawEmo.entries) {
              aggregatedEmotions[e.key] = (aggregatedEmotions[e.key] ?? 0.0) + ((e.value as num?)?.toDouble() ?? 0.0);
            }
          }

          // Accumulate gaze (Exact AI Key: 'gaze_distribution' or fallback 'gaze')
          dynamic rawGz = segAnalytic['gaze_distribution'] ?? segAnalytic['gaze'];
          if (rawGz is String) {
            try { rawGz = jsonDecode(rawGz); } catch (_) {}
          }
          if (rawGz is Map<String, dynamic>) {
            for (final e in rawGz.entries) {
              aggregatedGaze[e.key] = (aggregatedGaze[e.key] ?? 0.0) + ((e.value as num?)?.toDouble() ?? 0.0);
            }
          }

          // Accumulate focus (Exact AI Key: 'focus_percentage' or fallback 'focus_score')
          final rawFocusScore = segAnalytic['focus_percentage'] ?? segAnalytic['focus_score'];
          double? segFocus;
          if (rawFocusScore is num) {
            segFocus = rawFocusScore.toDouble();
          } else if (rawFocusScore is String) {
            segFocus = double.tryParse(rawFocusScore.replaceAll('%', '').trim());
          }
          if (segFocus != null) {
            segmentFocusPctSum += segFocus;
            segmentFocusCount++;
          }
        }
      }
    }

    // Fallback: check top-level analytic (non-segmented responses)
    final topAnalytic = json['analytic'] ?? json['analytics'];
    if (topAnalytic is Map<String, dynamic> && firstAnalytic == null) {
      firstAnalytic = Map<String, dynamic>.from(topAnalytic);
      // Defensively clean literal "null" strings
      for (final key in ['speech_text', 'story_trait']) {
        final val = firstAnalytic[key];
        if (val is String && val.trim().toLowerCase() == 'null') {
          firstAnalytic[key] = null;
        }
      }
      
      dynamic rawEmo = topAnalytic['emotions'] ?? topAnalytic['emotion_distribution'];
      if (rawEmo is String) { try { rawEmo = jsonDecode(rawEmo); } catch (_) {} }
      if (rawEmo is Map<String, dynamic>) {
        for (final e in rawEmo.entries) {
          aggregatedEmotions[e.key] = (e.value as num?)?.toDouble() ?? 0.0;
        }
        segmentsWithEmotions = 1;
      }

      dynamic rawGz = topAnalytic['gaze'] ?? topAnalytic['gaze_distribution'];
      if (rawGz is String) { try { rawGz = jsonDecode(rawGz); } catch (_) {} }
      if (rawGz is Map<String, dynamic>) {
        for (final e in rawGz.entries) {
          aggregatedGaze[e.key] = (e.value as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    // Fallback: check top-level direct fields
    if (aggregatedEmotions.isEmpty) {
      dynamic rawEmo = json['emotions'] ?? json['emotion_distribution'];
      if (rawEmo is String) { try { rawEmo = jsonDecode(rawEmo); } catch (_) {} }
      if (rawEmo is Map<String, dynamic>) {
        for (final e in rawEmo.entries) {
          aggregatedEmotions[e.key] = (e.value as num?)?.toDouble() ?? 0.0;
        }
        segmentsWithEmotions = 1;
      }
    }
    if (aggregatedGaze.isEmpty) {
      dynamic rawGz = json['gaze'] ?? json['gaze_distribution'];
      if (rawGz is String) { try { rawGz = jsonDecode(rawGz); } catch (_) {} }
      if (rawGz is Map<String, dynamic>) {
        for (final e in rawGz.entries) {
          aggregatedGaze[e.key] = (e.value as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    // ── Average emotions if from multiple segments ──────────────────────────
    final Map<String, double> avgEmotions = {};
    if (segmentsWithEmotions > 1) {
      for (final e in aggregatedEmotions.entries) {
        avgEmotions[e.key] = e.value / segmentsWithEmotions;
      }
    } else {
      avgEmotions.addAll(aggregatedEmotions);
    }

    // ── Convert to EmotionData list ─────────────────────────────────────────
    List<EmotionData> emotions = avgEmotions.entries.map((e) {
      final key = e.key.toLowerCase();
      final pct = e.value;
      return EmotionData(
        key,
        _emojiFor(key),
        _labelAr(key),
        pct > 1.0 ? pct / 100.0 : pct,
        _colorFor(key),
      );
    }).toList();

    // Fallback: if emotion_distribution was missing or null
    if (emotions.isEmpty) {
      emotions = [
        EmotionData('happy', _emojiFor('happy'), _labelAr('happy'), 0.0, _colorFor('happy')),
        EmotionData('sad', _emojiFor('sad'), _labelAr('sad'), 0.0, _colorFor('sad')),
        EmotionData('neutral', _emojiFor('neutral'), _labelAr('neutral'), 0.0, _colorFor('neutral')),
        EmotionData('angry', _emojiFor('angry'), _labelAr('angry'), 0.0, _colorFor('angry')),
        EmotionData('surprise', _emojiFor('surprise'), _labelAr('surprise'), 0.0, _colorFor('surprise')),
        EmotionData('fear', _emojiFor('fear'), _labelAr('fear'), 0.0, _colorFor('fear')),
      ];
    }

    // ── Convert gaze ────────────────────────────────────────────────────────
    final Map<String, double> gazeMap = {};
    for (final e in aggregatedGaze.entries) {
      gazeMap[e.key.toUpperCase()] = e.value;
    }

    // ── Calculate focus percentage ──────────────────────────────────────────
    double finalFocusPct = 0.0;
    double finalNotFocusPct = 0.0;

    // Helper: calculate focus from gaze data (CENTER = focused)
    double? gazeFocus() {
      if (gazeMap.isEmpty) return null;
      final centerPct = gazeMap['CENTER'] ?? 0.0;
      final totalGaze = gazeMap.values.fold(0.0, (a, b) => a + b);
      if (totalGaze <= 0) return null;
      return centerPct / totalGaze;
    }

    debugPrint('🔍 [FOCUS CALC] avgFocus: $avgFocus, segmentFocusCount: $segmentFocusCount, gazeMap: $gazeMap');

    if (avgFocus != null && avgFocus > 0) {
      // Backend provided a non-zero average_focus — trust it
      finalFocusPct = avgFocus > 1.0 ? avgFocus / 100.0 : avgFocus;
      finalNotFocusPct = 1.0 - finalFocusPct;
      debugPrint('🔍 [FOCUS CALC] Using avgFocus > 0: $finalFocusPct');
    } else if (segmentFocusCount > 0) {
      final avg = segmentFocusPctSum / segmentFocusCount;
      finalFocusPct = avg > 1.0 ? avg / 100.0 : avg;
      finalNotFocusPct = 1.0 - finalFocusPct;
      debugPrint('🔍 [FOCUS CALC] Using segment avg: $finalFocusPct');
    } else {
      // Fallback: derive focus from gaze data (CENTER = focused)
      final gazeDerived = gazeFocus();
      debugPrint('🔍 [FOCUS CALC] gazeDerived: $gazeDerived');
      if (gazeDerived != null) {
        finalFocusPct = gazeDerived;
        finalNotFocusPct = 1.0 - finalFocusPct;
        debugPrint('🔍 [FOCUS CALC] Using gazeDerived: $finalFocusPct');
      } else if (avgFocus != null) {
        // avgFocus is 0 and no gaze data — use it as-is
        finalFocusPct = 0.0;
        finalNotFocusPct = 1.0;
        debugPrint('🔍 [FOCUS CALC] Using avgFocus=0 fallback: $finalFocusPct');
      }
    }

    // ── Parse summary / recommendations ────────────────────────────────────
    final summaryData = json['session_summary'] ?? (firstAnalytic?['session_summary']);
    String summary = '';
    List<String> recommendations = [];
    String engagementLevel = '';

    if (summaryData is Map<String, dynamic>) {
      summary = summaryData['overall_summary'] as String? ?? '';
      recommendations = List<String>.from(summaryData['recommendations'] as List? ?? []);
      engagementLevel = summaryData['engagement_level'] as String? ?? '';
    } else {
      summary = json['summary'] as String? ?? json['doctor_notes'] as String? ?? json['notes'] as String? ?? '';
      recommendations = List<String>.from(json['recommendations'] as List? ?? []);
      engagementLevel = json['engagement_level'] as String? ?? '';
    }

    // ── Parse duration ─────────────────────────────────────────────────────
    String duration = '';
    final durationMins = json['duration_mins'];
    if (durationMins is num) {
      duration = '${durationMins.toInt()} دقيقة';
    } else if (json['duration'] is String) {
      duration = json['duration'] as String;
    }
    final startTime = json['start_time'] ?? json['started_at'];
    final endTime = json['end_time'] ?? json['ended_at'];
    if (duration.isEmpty && startTime != null && endTime != null) {
      try {
        final start = DateTime.parse(startTime.toString());
        final end = DateTime.parse(endTime.toString());
        duration = '${end.difference(start).inMinutes} دقيقة';
      } catch (_) {}
    }

    // ── Parse isComplete ────────────────────────────────────────────────────
    final rawComplete = json['is_completed'] ?? json['is_complete'];
    bool isComplete;
    if (rawComplete is bool) {
      isComplete = rawComplete;
    } else if (rawComplete is int) {
      isComplete = rawComplete == 1;
    } else {
      isComplete = json['status']?.toString().toLowerCase() == 'completed' ||
          json['status']?.toString() == 'مكتملة';
    }

    return SessionAnalysisModel(
      id: sessionId.toString(),
      title: json['title'] as String? ?? 'جلسة #$sessionId',
      summary: summary,
      duration: duration,
      engagementLevel: engagementLevel,
      isComplete: isComplete,
      recommendations: recommendations,
      emotionDistribution: emotions,
      gazeDistribution: gazeMap,
      focusedPercentage: finalFocusPct,
      notFocusedPercentage: finalNotFocusPct,
      notes: json['doctor_notes'] as String? ?? json['notes'] as String?,
      status: json['status'] as String?,
      startedAt: startTime?.toString(),
      endedAt: endTime?.toString(),
      date: dateStr,
      averageFocus: avgFocus != null ? (avgFocus > 1.0 ? avgFocus / 100.0 : avgFocus) : null,
      analytics: firstAnalytic,
    );
  }

  // ─── Gaze Data for Charts ────────────────────────────────────────────────

  /// Converts [gazeDistribution] to a list of [GazeData] for chart rendering.
  List<GazeData> get gazeDataForChart {
    if (gazeDistribution.isEmpty) {
      // Fallback to simple focused/not-focused
      return [
        GazeData('CENTER', 'مركّز', focusedPercentage, const Color(0xFF10B981), Icons.center_focus_strong),
        GazeData('OTHER', 'مشتت', notFocusedPercentage, const Color(0xFF94A3B8), Icons.visibility_off),
      ];
    }
    return gazeDistribution.entries.map((e) {
      final key = e.key.toUpperCase();
      return GazeData(
        key,
        _gazeLabelAr(key),
        e.value / 100.0,
        _gazeColor(key),
        _gazeIcon(key),
      );
    }).toList();
  }

  // ─── Serialization ───────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'duration': duration,
      'engagement_level': engagementLevel,
      'is_complete': isComplete,
      'recommendations': recommendations,
      'emotion_distribution': emotionDistribution.map((e) => e.toJson()).toList(),
      'gaze_distribution': gazeDistribution,
      'focused_percentage': focusedPercentage,
      'not_focused_percentage': notFocusedPercentage,
      'notes': notes,
      'status': status,
      'started_at': startedAt,
      'ended_at': endedAt,
      'date': date,
    };
  }

  // ─── Static Helpers ──────────────────────────────────────────────────────

  static String _emojiFor(String key) {
    switch (key) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'fear':
      case 'fearful':
        return '😨';
      case 'surprise':
      case 'surprised':
        return '😲';
      case 'disgust':
      case 'disgusted':
        return '🤢';
      case 'neutral':
        return '😐';
      case 'calm':
        return '😌';
      default:
        return '🙂';
    }
  }

  static String _labelAr(String key) {
    switch (key) {
      case 'happy':
        return 'سعيد';
      case 'sad':
        return 'حزين';
      case 'angry':
        return 'غاضب';
      case 'fear':
      case 'fearful':
        return 'خائف';
      case 'surprise':
      case 'surprised':
        return 'متفاجئ';
      case 'disgust':
      case 'disgusted':
        return 'مشمئز';
      case 'neutral':
        return 'محايد';
      case 'calm':
        return 'هادئ';
      default:
        return key;
    }
  }

  static Color _colorFor(String key) {
    switch (key) {
      case 'happy':
        return const Color(0xFF22C55E);
      case 'sad':
        return const Color(0xFFEF4444);
      case 'angry':
        return const Color(0xFFF97316);
      case 'fear':
      case 'fearful':
        return const Color(0xFF6366F1);
      case 'surprise':
      case 'surprised':
        return const Color(0xFFA855F7);
      case 'disgust':
      case 'disgusted':
        return const Color(0xFF84CC16);
      case 'neutral':
        return const Color(0xFF94A3B8);
      case 'calm':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF64748B);
    }
  }

  static String _gazeLabelAr(String key) {
    switch (key) {
      case 'CENTER':
        return 'مركّز';
      case 'LEFT':
        return 'يسار';
      case 'RIGHT':
        return 'يمين';
      case 'UP':
        return 'أعلى';
      case 'DOWN':
        return 'أسفل';
      default:
        return key;
    }
  }

  static Color _gazeColor(String key) {
    switch (key) {
      case 'CENTER':
        return const Color(0xFF10B981);
      case 'LEFT':
        return const Color(0xFF3B82F6);
      case 'RIGHT':
        return const Color(0xFFF59E0B);
      case 'UP':
        return const Color(0xFF8B5CF6);
      case 'DOWN':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  static IconData _gazeIcon(String key) {
    switch (key) {
      case 'CENTER':
        return Icons.center_focus_strong;
      case 'LEFT':
        return Icons.arrow_back;
      case 'RIGHT':
        return Icons.arrow_forward;
      case 'UP':
        return Icons.arrow_upward;
      case 'DOWN':
        return Icons.arrow_downward;
      default:
        return Icons.remove_red_eye;
    }
  }
}
