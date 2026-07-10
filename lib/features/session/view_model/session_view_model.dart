import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/session_analysis_model.dart';
import '../../../data/repositories/session_repository.dart';
import '../models/session_part.dart';

class SessionViewModel extends ChangeNotifier {
  final SessionRepository _sessionRepository;

  SessionViewModel(this._sessionRepository);

  // ── Timer State (live session) ──────────────────────────────────────────

  bool _isActive = false;
  List<SessionPart> _parts = [];
  int _currentPartIndex = 0;
  int _secondsRemainingInPart = 0;
  Timer? _timer;
  DateTime? _partStartTime;
  int _initialSecondsRemaining = 0;

  bool get isActive => _isActive;
  List<SessionPart> get parts => _parts;
  int get currentPartIndex => _currentPartIndex;
  int get secondsRemainingInPart => _secondsRemainingInPart;

  SessionPart? get currentPart =>
      _parts.isNotEmpty && _currentPartIndex < _parts.length
          ? _parts[_currentPartIndex]
          : null;

  String currentPartLabel(BuildContext context) => currentPart?.typeLabel(context) ?? '';

  String get formattedTime {
    final minutes = (_secondsRemainingInPart ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemainingInPart % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ── API Data State ─────────────────────────────────────────────────────

  bool _isLoading = false;
  String? _errorMessage;

  SessionAnalysisModel? _sessionDetails;
  List<SessionAnalysisModel> _patientSessions = [];
  int? _activeSessionId;
  final Map<String, bool> _previousSessionStates = {};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SessionAnalysisModel? get sessionDetails => _sessionDetails;
  List<SessionAnalysisModel> get patientSessions => _patientSessions;
  int? get activeSessionId => _activeSessionId;
  bool get hasSessionDetails => _sessionDetails != null;

  // ── Fetch Session Details ──────────────────────────────────────────────

  Future<void> loadSessionDetails(int sessionId) async {
    _isLoading = true;
    _errorMessage = null;
    _sessionDetails = null;
    notifyListeners();

    try {
      _sessionDetails = await _sessionRepository.getSessionDetails(sessionId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  List<SessionAnalysisModel> _applyGuiOrdering(List<SessionAnalysisModel> sessions) {
    if (sessions.isEmpty) return sessions;

    final sorted = List<SessionAnalysisModel>.from(sessions);
    sorted.sort((a, b) {
      final idA = int.tryParse(a.id) ?? 0;
      final idB = int.tryParse(b.id) ?? 0;
      return idA.compareTo(idB);
    });

    final indexed = <SessionAnalysisModel>[];
    for (int i = 0; i < sorted.length; i++) {
      final newIndex = i + 1;
      final original = sorted[i];

      // تصليح مشكلة الـ Title زي ما وضحنا
      final isDefaultTitle = RegExp(r'^جلسة #\d+$').hasMatch(original.title);

      indexed.add(original.copyWith(
        index: newIndex,
        title: isDefaultTitle ? 'جلسة #$newIndex' : original.title, 
      ));
    }

    return indexed;
  }

  void _detectNewlyCompletedSessions(List<SessionAnalysisModel> sessions) {
    if (!getIt.isRegistered<SharedPreferences>() || !getIt.isRegistered<AuthProvider>()) {
      return;
    }
    
    final prefs = getIt<SharedPreferences>();
    final authProvider = getIt<AuthProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;
    
    final userId = currentUser.id;
    final notifiedKey = 'notified_completed_sessions_$userId';
    final seededKey = 'has_seeded_completed_sessions_$userId';
    
    final notifiedList = prefs.getStringList(notifiedKey) ?? [];
    final notifiedSet = notifiedList.toSet();
    final hasSeeded = prefs.getBool(seededKey) ?? false;

    if (!hasSeeded) {
      final completedIds = sessions.where((s) => s.isComplete).map((s) => s.id).toList();
      prefs.setStringList(notifiedKey, completedIds);
      prefs.setBool(seededKey, true);
      
      for (final s in sessions) {
        _previousSessionStates[s.id] = s.isComplete;
      }
      return;
    }

    bool updatedPrefs = false;

    for (final session in sessions) {
      if (session.isComplete && !notifiedSet.contains(session.id)) {
        debugPrint('🔔 Session #${session.index} (id=${session.id}) just completed!');
        try {
          final notificationService = getIt<NotificationService>();
          notificationService.showSessionCompletedNotification(
            sessionIndex: session.index,
            sessionId: session.id,
          );
        } catch (e) {
          debugPrint('⚠️ Failed to show completion notification: $e');
        }
        notifiedSet.add(session.id);
        updatedPrefs = true;
      }
    }

    if (updatedPrefs) {
      prefs.setStringList(notifiedKey, notifiedSet.toList());
    }

    _previousSessionStates.clear();
    for (final s in sessions) {
      _previousSessionStates[s.id] = s.isComplete;
    }
  }

  Future<void> loadPatientSessions(int patientId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sessions = await _sessionRepository.getPatientSessions(patientId);
      final ordered = _applyGuiOrdering(sessions);
      _detectNewlyCompletedSessions(ordered);
      _patientSessions = ordered;
      _isLoading = false;
      notifyListeners();
      _fetchFullDetailsForChart();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMySessions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sessions = await _sessionRepository.getMySessions();
      final ordered = _applyGuiOrdering(sessions);
      _detectNewlyCompletedSessions(ordered);
      _patientSessions = ordered;
      _isLoading = false;
      notifyListeners();
      _fetchFullDetailsForChart();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchFullDetailsForChart() async {
    if (_patientSessions.isEmpty) return;

    final completedSessions = _patientSessions.where((s) => s.isComplete).toList();
    if (completedSessions.isEmpty) return;

    final recentCompleted = completedSessions.take(20).toList();

    for (int i = 0; i < recentCompleted.length; i++) {
      final session = recentCompleted[i];
      if (session.focusedPercentage == 0.0 && session.averageFocus == null) {
        try {
          final fullSession = await _sessionRepository.getSessionDetails(int.parse(session.id));
          final index = _patientSessions.indexWhere((s) => s.id == session.id);
          if (index != -1) {
            _patientSessions[index] = fullSession.copyWith(
              index: session.index,
              title: session.title, // الحفاظ على العنوان المحدث
            );
            notifyListeners(); 
          }
        } catch (e) {
          debugPrint('Failed to lazy load session details for chart: $e');
        }
      }
    }
  }

  // ── Create Session ─────────────────────────────────────────────────────

  Future<void> createAndStartSession({
    required int patientId,
    required List<SessionPart> parts,
    String? notes,
  }) async {
    if (parts.isEmpty) {
      _errorMessage = 'الرجاء إضافة جزء واحد على الأقل للجلسة';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final segments = parts.map((p) => {
        'activity_type': p.getBackendType(p.type),
        'planned_duration': p.durationMinutes,
      }).toList();

      final session = await _sessionRepository.createSession(
        patientId: patientId,
        notes: notes,
        segments: segments,
      );

      _activeSessionId = int.tryParse(session.id);

      if (_activeSessionId != null) {
        await _sessionRepository.startSession(_activeSessionId!);
      }

      _parts = List.from(parts);
      _currentPartIndex = 0;
      _secondsRemainingInPart = _parts[0].durationMinutes * 60;
      _isActive = true;
      _startTimer();

      _isLoading = false;
      notifyListeners();
    } catch (e, stack) {
      debugPrint('❌ createSession ERROR: $e');
      debugPrint('❌ createSession STACK: $stack');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createSession({
    required int patientId,
    required List<SessionPart> parts,
    String? notes,
    DateTime? scheduledDate,
  }) async {
    if (parts.isEmpty) {
      _errorMessage = 'الرجاء إضافة جزء واحد على الأقل للجلسة';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final segments = parts.map((p) => {
        'activity_type': p.getBackendType(p.type),
        'planned_duration': p.durationMinutes,
      }).toList();

      final session = await _sessionRepository.createSession(
        patientId: patientId,
        notes: notes,
        segments: segments,
        scheduledDate: scheduledDate,
      );

      _patientSessions = [session, ..._patientSessions];

      _isLoading = false;
      notifyListeners();
    } catch (e, stack) {
      debugPrint('❌ createSession ERROR: $e');
      debugPrint('❌ createSession STACK: $stack');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── End Session ────────────────────────────────────────────────────────

  Future<void> startSession({
    required int receiverId,
    required List<SessionPart> parts,
  }) async {
    return createSession(patientId: receiverId, parts: parts);
  }

  Future<void> endSession() async {
    return endCurrentSession();
  }

  Future<void> endCurrentSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_activeSessionId != null) {
        await _sessionRepository.endSession(_activeSessionId!);
      }
      _finalizeSession();
    } catch (e) {
      _errorMessage = e.toString();
      _finalizeSession();
    }
  }

  // ── Delete Session ─────────────────────────────────────────────────────

  Future<bool> deleteSession(int sessionId) async {
    _errorMessage = null;
    try {
      await _sessionRepository.deleteSession(sessionId);
      _patientSessions.removeWhere((s) => s.id == sessionId.toString());
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Part Management (for session config) ───────────────────────────────

  void addPart(SessionPart part) {
    _parts.add(part);
    notifyListeners();
  }

  void removePart(int index) {
    if (index >= 0 && index < _parts.length) {
      _parts.removeAt(index);
      notifyListeners();
    }
  }

  void clearParts() {
    _parts.clear();
    notifyListeners();
  }

  // ── Timer Logic ────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _partStartTime = DateTime.now();
    _initialSecondsRemaining = _secondsRemainingInPart;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_partStartTime != null) {
        final elapsed = DateTime.now().difference(_partStartTime!).inSeconds;
        _secondsRemainingInPart = _initialSecondsRemaining - elapsed;
        
        if (_secondsRemainingInPart > 0) {
          notifyListeners();
        } else {
          if (_currentPartIndex < _parts.length - 1) {
            _currentPartIndex++;
            _secondsRemainingInPart = _parts[_currentPartIndex].durationMinutes * 60;
            _partStartTime = DateTime.now();
            _initialSecondsRemaining = _secondsRemainingInPart;
            notifyListeners();
          } else {
            endCurrentSession(); 
          }
        }
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _partStartTime = null;
  }

  void _finalizeSession() {
    _isActive = false;
    _stopTimer();
    _isLoading = false;
    _parts = [];
    _currentPartIndex = 0;
    _secondsRemainingInPart = 0;
    _activeSessionId = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSessionDetails() {
    _sessionDetails = null;
    notifyListeners();
  }

  void resetState() {
    _stopTimer();
    _isActive = false;
    _parts = [];
    _currentPartIndex = 0;
    _secondsRemainingInPart = 0;
    _isLoading = false;
    _errorMessage = null;
    _sessionDetails = null;
    _patientSessions = [];
    _activeSessionId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}