import 'package:flutter/material.dart';

class SessionPart {
  final String type;
  final int durationMinutes;

  SessionPart({required this.type, required this.durationMinutes});

  Map<String, dynamic> toJson() => {
        'type': getBackendType(type),
        'duration_minutes': durationMinutes,
      };

  String getBackendType(String input) {
    final trimmed = input.trim();
    final lower = trimmed.toLowerCase();

    // English keys (already normalized — fast path)
    if (lower == 'games' || lower == 'stories' || lower == 'study' || lower == 'drawing') {
      return lower;
    }

    // Substring fallbacks for English variants
    if (lower.contains('game')) return 'games';
    if (lower.contains('stor')) return 'stories';
    if (lower.contains('stud') || lower.contains('educ') || lower.contains('learn')) return 'study';
    if (lower.contains('draw')) return 'drawing';

    // Arabic fallbacks (trim only — toLowerCase is a no-op on Arabic)
    if (trimmed.contains('ألعاب') || trimmed.contains('العاب')) return 'games';
    if (trimmed.contains('قصص') || trimmed.contains('قصة') || trimmed.contains('قصه')) return 'stories';
    if (trimmed.contains('تعلم') || trimmed.contains('تعليم') || trimmed.contains('دراسة')) return 'study';
    if (trimmed.contains('رسم')) return 'drawing';

    // Last-resort: return the trimmed lowercase so it's at least clean
    return lower;
  }

  String typeLabel(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    switch (getBackendType(type)) {
      case 'games':
        return isAr ? 'ألعاب' : 'Games';
      case 'stories':
        return isAr ? 'قصص' : 'Stories';
      case 'study':
        return isAr ? 'تعلم' : 'Study';
      case 'drawing':
        return isAr ? 'رسم' : 'Drawing';
      default:
        return type.isEmpty ? (isAr ? 'غير محدد' : 'Unknown') : type;
    }
  }
}
