import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../datasources/local_data_source.dart';
import '../models/ai_message_model.dart';
import '../models/parent_model.dart';
import '../repositories/patient_repository.dart';
import '../repositories/session_repository.dart';

/// Handles the AI chat flow.
///
/// Sends questions to the Autism Chatbot API (v4.1.0) running at
/// http://20.230.160.202:8000 and persists the conversation locally
/// for offline history access.
class AIRepository {
  final LocalDataSource _localDataSource;
  final PatientRepository _patientRepository;
  final SessionRepository _sessionRepository;

  /// Dedicated Dio instance pointing at the chatbot micro-service.
  late final Dio _chatbotDio;

  /// Base URL for the chatbot API.
  static const String _chatbotBaseUrl = 'http://20.230.160.202:8000';

  /// Tracks per-user/per-patient started sessions instead of a single global flag.
  final Set<String> _startedSessions = {};
  bool get isSessionStarted {
    final currentUserId = _localDataSource.getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty) {
      return _startedSessions.isNotEmpty;
    }
    return _startedSessions.any((key) => key == currentUserId || key.startsWith('${currentUserId}_'));
  }

  AIRepository(this._localDataSource, this._patientRepository, this._sessionRepository) {
    _chatbotDio = Dio(BaseOptions(
      baseUrl: _chatbotBaseUrl,
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120),
      followRedirects: true,
      validateStatus: (status) => true,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  // ==================== RESPONSE VALIDATION ====================

  /// Inspects every chatbot response **before** JSON parsing.
  ///
  /// Catches two real-world edge-cases on Egyptian ISPs:
  /// 1. The ISP (WE / tedata) intercepts unencrypted HTTP and returns a
  ///    `307 → text/html` redirect page when the user's data quota is
  ///    exhausted.  Dio happily follows the redirect and hands us HTML
  ///    instead of JSON, causing a parse crash.
  /// 2. The FastAPI backend returns 500 when the HuggingFace LLM times
  ///    out or the API token is revoked.
  void _validateResponse(Response response) {
    // ── ISP HTML interception ──────────────────────────────────────────
    final contentType = response.headers.value('content-type') ?? '';
    if (contentType.contains('text/html')) {
      throw Exception(
        'يرجى التحقق من باقة الإنترنت. الشبكة تقوم بتحويل مسار الاتصال.',
      );
    }
    final body = response.data;
    if (body is String && body.trimLeft().startsWith('<')) {
      throw Exception(
        'يرجى التحقق من باقة الإنترنت. الشبكة تقوم بتحويل مسار الاتصال.',
      );
    }

    // ── Backend 500 (LLM timeout / token failure) ──────────────────────
    if (response.statusCode == 500) {
      throw Exception(
        'عذراً، حدث خطأ في الخادم (500). يرجى المحاولة بعد قليل.',
      );
    }

    // ── Any other HTTP error ──────────────────────────────────────────
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw Exception(
        'حدث خطأ (${response.statusCode}). يرجى المحاولة مرة أخرى.',
      );
    }
  }

  // ==================== SESSION START ====================

  String _sessionKey({
    required String userId,
    required String userRole,
    String? patientId,
    String? childName,
  }) {
    if (userRole == 'doctor' && patientId != null && patientId.trim().isNotEmpty) {
      return '${userId}_${patientId.trim()}';
    }
    final suffix = (childName ?? '').trim();
    return suffix.isNotEmpty ? '${userId}_$suffix' : userId.toString();
  }

  Map<String, dynamic> _resolveSessionContext({
    required String userId,
    String? childName,
    String? userRole,
    String? patientId,
  }) {
    final currentUser = _localDataSource.getCurrentUser();
    final resolvedRole = (userRole ?? currentUser?['role']?.toString() ?? 'parent').toString();
    final resolvedChildName = (childName ?? currentUser?['child_name']?.toString() ?? '').toString();
    final resolvedPatientId = (patientId ?? currentUser?['patient_id']?.toString()).toString();

    return {
      'user_id': userId.toString(),
      'user_role': resolvedRole.isNotEmpty ? resolvedRole : 'parent',
      'child_name': resolvedChildName,
      'patient_id': resolvedPatientId == 'null' || resolvedPatientId.trim().isEmpty ? null : resolvedPatientId,
    };
  }

  /// Initialises the chatbot session with the child's name.
  /// Must be called once before the first /chat request.
  Future<void> startSession(
    String childName, {
    int? userId,
    String userRole = 'parent',
    String? patientId,
  }) async {
    final currentUser = _localDataSource.getCurrentUser();
    final resolvedUserId = (userId ?? int.tryParse(_localDataSource.getCurrentUserId() ?? '') ?? currentUser?['id'] ?? 0).toString();
    final key = _sessionKey(
      userId: resolvedUserId,
      userRole: userRole,
      patientId: patientId,
      childName: childName,
    );
    if (_startedSessions.contains(key)) return;

    final payload = _resolveSessionContext(
      userId: resolvedUserId,
      childName: childName,
      userRole: userRole,
      patientId: patientId,
    );

    try {
      await _chatbotDio.post('/session/start', data: payload);
      _startedSessions.add(key);
      debugPrint('✅ Chatbot session started for child: $childName');
    } catch (e) {
      debugPrint('⚠️ Chatbot /session/start failed: $e');
      // Don't block the user — they can still chat; the API will handle
      // a missing session gracefully (or we retry on next send).
    }
  }

  String? _cachedDoctorContext;
  DateTime? _lastDoctorContextFetch;
  String? _cachedParentContext;
  DateTime? _lastParentContextFetch;

  // ==================== DYNAMIC CONTEXT BUILDER ====================

  /// Builds a rich context string from real app data (patients, sessions,
  /// child info) so the LLM can answer domain-specific questions.
  Future<String> _buildDynamicContext({
    required String resolvedRole,
    required String childName,
  }) async {
    final parts = <String>[];

    try {
      if (resolvedRole == 'doctor') {
        if (_cachedDoctorContext != null &&
            _lastDoctorContextFetch != null &&
            DateTime.now().difference(_lastDoctorContextFetch!).inMinutes < 5) {
          parts.add(_cachedDoctorContext!);
          return parts.join('\n');
        }

        final doctorParts = <String>[];
        // ── Doctor: fetch patients and their recent sessions ──
        final patients = await _patientRepository.getDoctorPatients();
        if (patients.isNotEmpty) {
          doctorParts.add('المرضى المرتبطون بهذا الطبيب (${patients.length} مريض):');
          for (final patient in patients) {
            String patientLabel = patient.name;
            if (patient is ParentModel && patient.childName.isNotEmpty) {
              patientLabel = 'الطفل: ${patient.childName} (ولي الأمر: ${patient.name})';
            }
            doctorParts.add('- $patientLabel');

            // Fetch patient profile/insights
            try {
              final insights = await _patientRepository.getPatientInsights(patient.id.toString());
              if (insights.isNotEmpty) {
                final excludedKeys = ['id', 'user_id', 'created_at', 'updated_at', 'doctor_id'];
                bool hasInsights = false;
                for (final entry in insights.entries) {
                  if (excludedKeys.contains(entry.key.toLowerCase())) continue;
                  if (entry.value != null && entry.value.toString().isNotEmpty && entry.value.toString() != 'null') {
                    if (!hasInsights) {
                      doctorParts.add('  ملف الحالة:');
                      hasInsights = true;
                    }
                    doctorParts.add('    ${entry.key}: ${entry.value}');
                  }
                }
              }
            } catch (e) {
              debugPrint('⚠️ Failed to fetch insights for patient ${patient.id}: $e');
            }

            // Fetch last 5 sessions for each patient
            try {
              final sessions = await _sessionRepository.getPatientSessions(patient.id);
              if (sessions.isNotEmpty) {
                // Ensure ascending order (oldest/Session 1 first)
                sessions.sort((a, b) {
                  final dateA = DateTime.tryParse(a.startedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final dateB = DateTime.tryParse(b.startedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return dateA.compareTo(dateB);
                });
                
                final recentSessions = sessions.length > 5
                    ? sessions.sublist(sessions.length - 5)
                    : sessions;
                doctorParts.add('  آخر ${recentSessions.length} جلسات:');
                for (final session in recentSessions) {
                  final status = session.isComplete ? 'مكتملة' : (session.status ?? 'قيد التنفيذ');
                  final date = session.date ?? session.startedAt?.split('T').first ?? 'غير محدد';
                  doctorParts.add('  • التاريخ: $date | الحالة: $status');
                  if (session.duration.isNotEmpty) {
                    doctorParts.add('    المدة: ${session.duration}');
                  }
                  if (session.engagementLevel.isNotEmpty) {
                    doctorParts.add('    التفاعل: ${session.engagementLevel}');
                  }
                  if (session.summary.isNotEmpty) {
                    doctorParts.add('    الملخص: ${session.summary}');
                  }
                  if (session.focusedPercentage > 0) {
                    doctorParts.add('    التركيز: ${(session.focusedPercentage * 100).toStringAsFixed(0)}%');
                  }
                  if (session.emotionDistribution.isNotEmpty) {
                    final significant = session.emotionDistribution
                        .where((e) => e.percentage > 0.05)
                        .toList();
                    if (significant.isNotEmpty) {
                      significant.sort((a, b) => b.percentage.compareTo(a.percentage));
                      final emotions = significant
                          .map((e) => '${e.label} (${(e.percentage * 100).toInt()}%)')
                          .join(', ');
                      doctorParts.add('    المشاعر البارزة: $emotions');
                    } else {
                      doctorParts.add('    المشاعر: هادئ/محايد');
                    }
                  }
                  if (session.recommendations.isNotEmpty) {
                    doctorParts.add('    التوصيات: ${session.recommendations.join("، ")}');
                  }
                }
              } else {
                doctorParts.add('  لا توجد جلسات مسجلة بعد.');
              }
            } catch (e) {
              debugPrint('⚠️ Failed to fetch sessions for patient ${patient.id}: $e');
            }
          }
        } else {
          doctorParts.add('لا يوجد مرضى مرتبطون بهذا الطبيب حالياً.');
        }
        
        _cachedDoctorContext = doctorParts.join('\n');
        _lastDoctorContextFetch = DateTime.now();
        parts.add(_cachedDoctorContext!);
        
      } else {
        if (_cachedParentContext != null &&
            _lastParentContextFetch != null &&
            DateTime.now().difference(_lastParentContextFetch!).inMinutes < 5) {
          parts.add(_cachedParentContext!);
          return parts.join('\n');
        }

        final parentParts = <String>[];
        // ── Parent: include child name and own sessions ──
        if (childName.isNotEmpty) {
          parentParts.add('معلومات الطفل الحالي: $childName');
        }
        try {
          final sessions = await _sessionRepository.getMySessions();
          if (sessions.isNotEmpty) {
            // Ensure ascending order (oldest/Session 1 first)
            sessions.sort((a, b) {
              final dateA = DateTime.tryParse(a.startedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
              final dateB = DateTime.tryParse(b.startedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
              return dateA.compareTo(dateB);
            });
            
            final recentSessions = sessions.length > 5
                ? sessions.sublist(sessions.length - 5)
                : sessions;
            parentParts.add('آخر ${recentSessions.length} جلسات:');
            for (final session in recentSessions) {
              final status = session.isComplete ? 'مكتملة' : (session.status ?? 'قيد التنفيذ');
              final date = session.date ?? session.startedAt?.split('T').first ?? 'غير محدد';
              parentParts.add('• التاريخ: $date | الحالة: $status');
              if (session.duration.isNotEmpty) {
                parentParts.add('  المدة: ${session.duration}');
              }
              if (session.summary.isNotEmpty) {
                parentParts.add('  الملخص: ${session.summary}');
              }
              if (session.focusedPercentage > 0) {
                parentParts.add('  التركيز: ${(session.focusedPercentage * 100).toStringAsFixed(0)}%');
              }
              if (session.emotionDistribution.isNotEmpty) {
                final significant = session.emotionDistribution
                    .where((e) => e.percentage > 0.05)
                    .toList();
                if (significant.isNotEmpty) {
                  significant.sort((a, b) => b.percentage.compareTo(a.percentage));
                  final emotions = significant
                      .map((e) => '${e.label} (${(e.percentage * 100).toInt()}%)')
                      .join(', ');
                  parentParts.add('  المشاعر البارزة: $emotions');
                } else {
                  parentParts.add('  المشاعر: هادئ/محايد');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to fetch parent sessions: $e');
        }
        
        _cachedParentContext = parentParts.join('\n');
        _lastParentContextFetch = DateTime.now();
        parts.add(_cachedParentContext!);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to build dynamic context: $e');
    }

    return parts.join('\n');
  }

  // ==================== AI CHAT ====================

  /// Sends [content] to the chatbot API and persists both sides of the
  /// conversation to local storage. Returns the AI [AIMessageModel].
  Future<AIMessageModel> sendMessage(
    int userId,
    String content, {
    String? childName,
    String? userRole,
    String? patientId,
  }) async {
    final userMessage = AIMessageModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final currentUser = _localDataSource.getCurrentUser();
    final resolvedRole = (userRole ?? currentUser?['role']?.toString() ?? 'parent').toString();
    final resolvedChildName = childName?.trim().isNotEmpty == true
        ? childName!.trim()
        : (currentUser?['child_name']?.toString() ?? currentUser?['data']?['child_name']?.toString() ?? '').toString();
    final resolvedPatientId = patientId ?? currentUser?['patient_id']?.toString();

    // ── Try /session/start if not yet done ──
    if (resolvedRole != 'doctor' || (resolvedPatientId != null && resolvedPatientId.trim().isNotEmpty)) {
      await startSession(
        resolvedChildName.isNotEmpty ? resolvedChildName : 'الطفل',
        userId: userId,
        userRole: resolvedRole,
        patientId: resolvedPatientId,
      );
    }

    // ── Real API call ────────────────────────────────────────────────────
    String aiResponse = "عذراً، حدث خطأ في معالجة طلبك.";
    String? categoryLabel;
    String? urgency;
    bool needsClarification = false;
    String? clarificationQuestion;

    try {
      String savedChildName = resolvedChildName;
      if (savedChildName.isEmpty) {
        savedChildName = currentUser?['child_name']?.toString() ?? '';
        if (savedChildName.isEmpty) {
          savedChildName = currentUser?['data']?['child_name']?.toString() ?? '';
        }
      }

      // ── Resolve user display name for the AI prompt ──
      final resolvedUserName = (currentUser?['name']?.toString()
              ?? currentUser?['data']?['name']?.toString()
              ?? currentUser?['full_name']?.toString()
              ?? 'المستخدم')
          .toString();

      // ── Map role to Arabic for the backend prompt ──
      final arabicRole = resolvedRole == 'doctor' ? 'طبيب' : 'ولي أمر';

      // ── Build chat_history from local storage (last 20 messages) ──
      final localHistory = await getChatHistory(userId);
      final chatHistory = <Map<String, String>>[];
      final historySlice = localHistory.length > 20
          ? localHistory.sublist(localHistory.length - 20)
          : localHistory;
      for (final msg in historySlice) {
        chatHistory.add({
          'role': msg.isUser ? 'user' : 'assistant',
          'content': msg.content,
        });
      }

      // ── Build dynamic context from real app data ──
      final dynamicContext = await _buildDynamicContext(
        resolvedRole: resolvedRole,
        childName: savedChildName,
      );
      debugPrint('📋 Dynamic context built (${dynamicContext.length} chars)');

      Future<Response<dynamic>> postChat() {
        return _chatbotDio.post('/ask', data: {
          "question": content,
          "user_name": resolvedUserName,
          "user_role": arabicRole,
          "chat_history": chatHistory,
          "context": dynamicContext,
        });
      }

      Response<dynamic> response = await postChat();
      if (response.statusCode == 404) {
        final detail = response.data is Map ? response.data['detail']?.toString().toLowerCase() ?? '' : response.data?.toString().toLowerCase() ?? '';
        final looksLikeMissingSession = detail.contains('session') || detail.contains('لم تبدأ') || detail.contains('no session');
        if (looksLikeMissingSession) {
          await startSession(
            savedChildName.isNotEmpty ? savedChildName : 'الطفل',
            userId: userId,
            userRole: resolvedRole,
            patientId: resolvedRole == 'doctor' ? resolvedPatientId : null,
          );
          response = await postChat();
        }
      }

      _validateResponse(response);

      final data = response.data;
      debugPrint('🤖 RAW BACKEND RESPONSE: $data');

      // ✅ Guard: empty or null response
      if (data == null || (data is String && data.trim().isEmpty)) {
        throw Exception(
          'الخادم لم يُرجع استجابة. تأكد أن النموذج تم تحميله وأن الجلسة بدأت.',
        );
      }

      if (data is Map<String, dynamic>) {
        // Guard the 'answer' field specifically
        final answer = data['answer']?.toString() ?? '';
        if (answer.trim().isEmpty) {
          throw Exception('الاستجابة فارغة من الخادم. حاول مرة أخرى.');
        }
        aiResponse = answer;
        categoryLabel = data['category_label']?.toString();
        urgency = data['urgency']?.toString();
        needsClarification = data['needs_clarification'] == true;
        clarificationQuestion = data['clarification_question']?.toString();
        debugPrint('🤖 EXTRACTED aiResponse: $aiResponse');
      } else {
        // If backend returned non-map (string) but non-empty, use it
        final text = data?.toString() ?? '';
        if (text.trim().isEmpty) {
          throw Exception('الاستجابة فارغة من الخادم. حاول مرة أخرى.');
        }
        aiResponse = text;
        debugPrint('🤖 EXTRACTED (from string) aiResponse: $aiResponse');
      }
    } on DioException catch (e) {
      debugPrint('❌ Chatbot /chat DioException: $e');
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          aiResponse =
              'عذراً، السيرفر يستغرق وقتاً طويلاً. يرجى المحاولة مرة أخرى.';
          break;
        case DioExceptionType.connectionError:
          aiResponse = 'لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة.';
          break;
        default:
          aiResponse = 'عذراً، لم نتمكن من الوصول إلى المساعد الذكي حالياً.';
      }
    } catch (e) {
      debugPrint('❌ Chatbot /chat error: $e');
      aiResponse = e.toString().replaceFirst('Exception: ', '');
    }
    // ─────────────────────────────────────────────────────────────────────

    final aiMessage = AIMessageModel(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      content: aiResponse,
      isUser: false,
      timestamp: DateTime.now(),
      categoryLabel: categoryLabel,
      urgency: urgency,
      needsClarification: needsClarification,
      clarificationQuestion: clarificationQuestion,
    );

    // Persist both messages to local cache.
    final history = await getChatHistory(userId);
    history.add(userMessage);
    history.add(aiMessage);
    await _localDataSource.saveAiHistory(
      userId.toString(),
      history.map((e) => e.toJson()).toList(),
    );

    return aiMessage;
  }

  // ==================== PROFILE (SESSION SUMMARY) ====================

  /// Fetches the session summary / child profile from the chatbot API.
  Future<Map<String, dynamic>?> getProfile({
    required int userId,
    String userRole = 'parent',
    String? patientId,
  }) async {
    try {
      final response = await _chatbotDio.get('/profile', queryParameters: {
        'user_id': userId.toString(),
        'user_role': userRole,
        if (patientId != null && patientId.trim().isNotEmpty) 'patient_id': patientId.trim(),
      });
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ Chatbot /profile failed: $e');
    }
    return null;
  }

  // ==================== LOCAL HISTORY ====================

  /// Returns persisted chat history for [userId] from local cache.
  Future<List<AIMessageModel>> getChatHistory(int userId) async {
    final cachedData = _localDataSource.getAiHistory(userId.toString());
    if (cachedData != null) {
      return cachedData.map((data) => AIMessageModel.fromJson(data)).toList();
    }
    return [];
  }

  /// Clears all chat history for [userId] from local cache.
  Future<void> clearChatHistory(int userId) async {
    await _localDataSource.clearAiHistory(userId.toString());
    _startedSessions.removeWhere((key) => key.startsWith('${userId}_') || key == userId.toString());
  }

  Future<List<Map<String, dynamic>>> fetchPatients(int doctorId) async {
    final response = await _chatbotDio.get('/patients', queryParameters: {
      'user_id': doctorId.toString(),
    });
    _validateResponse(response);
    final data = response.data;
    if (data is Map && data['patients'] is List) {
      return List<Map<String, dynamic>>.from(data['patients']);
    }
    return [];
  }
}
