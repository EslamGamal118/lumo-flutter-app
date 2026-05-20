import 'dart:async';
import 'package:flutter/material.dart';

import '../../../data/repositories/ai_repository.dart';
import '../../../data/models/ai_message_model.dart';

class AIViewModel extends ChangeNotifier {
  final AIRepository _aiRepository;

  AIViewModel(this._aiRepository);

  final List<AIMessageModel> _messages = [];
  bool _isSending = false;
  String? _errorMessage;

  /// The child name used for the chatbot session context.
  String? _childName;

  List<AIMessageModel> get messages => _messages;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  bool get isSessionStarted => _aiRepository.isSessionStarted;

  // ── Session Start ─────────────────────────────────────────────────────

  /// Initialises the chatbot session with the child's name.
  /// Should be called once when the chat screen opens.
  Future<void> startSession(String childName) async {
    _childName = childName;
    await _aiRepository.startSession(childName);
    notifyListeners();
  }

  // ── Load chat history ─────────────────────────────────────────────────

  Future<void> loadChatHistory(int userId) async {
    try {
      final history = await _aiRepository.getChatHistory(userId);
      _messages.clear();

      if (history.isEmpty) {
        // Add welcome message if history is empty
        _messages.add(
          AIMessageModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: 0,
            content: 'مرحباً! أنا مساعد Lumo AI الذكي. يمكنني مساعدتك في الإجابة عن أسئلتك المتعلقة بصحة الأطفال والرعاية الطبية. كيف يمكنني مساعدتك اليوم؟',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      } else {
        _messages.addAll(history);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ── Send message ──────────────────────────────────────────────────────

  Future<void> sendMessage(int userId, String content) async {
    if (content.trim().isEmpty) return;

    // Add user message
    final userMessage = AIMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      content: content.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);
    notifyListeners();

    // Add loading message
    final loadingMessage = AIMessageModel(
      id: '${DateTime.now().millisecondsSinceEpoch + 1}',
      userId: 0,
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    _messages.add(loadingMessage);
    _isSending = true;
    notifyListeners();

    try {
      // Send to AI with child name context
      final aiResponse = await _aiRepository.sendMessage(
        userId,
        content,
        childName: _childName,
      );

      // Remove loading message
      _messages.removeLast();

      // Add AI response
      _messages.add(aiResponse);
      _isSending = false;
      notifyListeners();
    } catch (e) {
      // Remove loading message
      _messages.removeLast();

      // Strip the 'Exception: ' prefix so custom Arabic messages from
      // AIRepository (ISP redirect / 500 / timeout) display cleanly.
      final friendlyError =
          e.toString().replaceFirst('Exception: ', '');

      // Add error message with the specific error from the network layer
      final errorMessage = AIMessageModel(
        id: '${DateTime.now().millisecondsSinceEpoch + 2}',
        userId: 0,
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        error: friendlyError,
      );
      _messages.add(errorMessage);
      _errorMessage = friendlyError;
      _isSending = false;
      notifyListeners();
    }
  }

  // ── Clear chat history ────────────────────────────────────────────────

  Future<void> clearChatHistory(int userId) async {
    await _aiRepository.clearChatHistory(userId);
    _messages.clear();
    await loadChatHistory(userId); // Add welcome message again
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetState() {
    _messages.clear();
    _isSending = false;
    _errorMessage = null;
    _childName = null;
    notifyListeners();
  }
}
