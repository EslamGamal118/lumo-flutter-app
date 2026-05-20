import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../datasources/local_data_source.dart';
import '../models/ai_message_model.dart';

/// Handles the AI chat flow.
///
/// Sends questions to the Autism Chatbot API (v4.1.0) running at
/// http://172.189.165.242:8080 and persists the conversation locally
/// for offline history access.
class AIRepository {
  final LocalDataSource _localDataSource;

  /// Dedicated Dio instance pointing at the chatbot micro-service.
  late final Dio _chatbotDio;

  /// Base URL for the chatbot API.
  static const String _chatbotBaseUrl = 'http://172.189.165.242:8080';

  /// Whether a /session/start has already been called in this app session.
  bool _sessionStarted = false;
  bool get isSessionStarted => _sessionStarted;

  AIRepository(this._localDataSource) {
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

  /// Initialises the chatbot session with the child's name.
  /// Must be called once before the first /chat request.
  Future<void> startSession(String childName) async {
    if (_sessionStarted) return; // idempotent guard

    try {
      await _chatbotDio.post('/session/start', data: {
        'child_name': childName,
      });
      _sessionStarted = true;
      debugPrint('✅ Chatbot session started for child: $childName');
    } catch (e) {
      debugPrint('⚠️ Chatbot /session/start failed: $e');
      // Don't block the user — they can still chat; the API will handle
      // a missing session gracefully (or we retry on next send).
    }
  }

  // ==================== AI CHAT ====================

  /// Sends [content] to the chatbot API and persists both sides of the
  /// conversation to local storage. Returns the AI [AIMessageModel].
  Future<AIMessageModel> sendMessage(
    int userId,
    String content, {
    String? childName,
  }) async {
    final userMessage = AIMessageModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // ── Try /session/start if not yet done ──
    if (childName != null && childName.isNotEmpty) {
      await startSession(childName);
    }

    // ── Real API call ────────────────────────────────────────────────────
    String aiResponse = "عذراً، حدث خطأ في معالجة طلبك.";
    String? categoryLabel;
    String? urgency;
    bool needsClarification = false;
    String? clarificationQuestion;

    try {
      String savedChildName = '';

      // Priority 1: use the childName passed directly to this method
      if (childName != null && childName.isNotEmpty) {
        savedChildName = childName;
      }

      // Priority 2: fallback to local storage
      if (savedChildName.isEmpty) {
        final userData = _localDataSource.getCurrentUser();
        savedChildName = userData?['child_name']?.toString() ?? '';
        // also check nested under 'data' key (some API responses wrap fields)
        if (savedChildName.isEmpty) {
          savedChildName = userData?['data']?['child_name']?.toString() ?? '';
        }
      }

      final response = await _chatbotDio.post('/chat', data: {
        "question": content,
        if (savedChildName.trim().isNotEmpty) "child_name": savedChildName.trim(),
      });
      _validateResponse(response);

      final data = response.data;
      debugPrint('🤖 RAW BACKEND RESPONSE: $data');
      if (data is Map<String, dynamic>) {
        // Strictly use the backend's provided answer string without modification
        aiResponse = data['answer']?.toString() ??
            data['message']?.toString() ??
            aiResponse;
        categoryLabel = data['category_label']?.toString();
        urgency = data['urgency']?.toString();
        needsClarification = data['needs_clarification'] == true;
        clarificationQuestion =
            data['clarification_question']?.toString();
        debugPrint('🤖 EXTRACTED aiResponse: $aiResponse');
      } else {
        aiResponse = data?.toString() ?? aiResponse;
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
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _chatbotDio.get('/profile');
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
    await _localDataSource.remove('ai_history_$userId');
    _sessionStarted = false; // allow a fresh session on next open
  }
}
