import 'dart:async';
import 'package:flutter/material.dart';
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

  /// The currently selected session's full details (from /sessions/{id}).
  SessionAnalysisModel? _sessionDetails;

  /// List of sessions for a patient (from /sessions/list/{id} or /sessions/list).
  List<SessionAnalysisModel> _patientSessions = [];

  /// The session ID of the currently created/active session.
  int? _activeSessionId;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SessionAnalysisModel? get sessionDetails => _sessionDetails;
  List<SessionAnalysisModel> get patientSessions => _patientSessions;
  int? get activeSessionId => _activeSessionId;
  bool get hasSessionDetails => _sessionDetails != null;

  // ── Fetch Session Details ──────────────────────────────────────────────

  /// Loads full session details (emotion/gaze charts, summary, etc.)
  /// by calling GET /sessions/{id}.
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

  /// Loads all sessions for a patient (doctor's view).
  /// Calls GET /sessions/list/{patientId}.
  Future<void> loadPatientSessions(int patientId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _patientSessions = await _sessionRepository.getPatientSessions(patientId);
      _isLoading = false;
      notifyListeners();
      _fetchFullDetailsForChart();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the logged-in patient's own sessions.
  /// Calls GET /sessions/list.
  Future<void> loadMySessions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _patientSessions = await _sessionRepository.getMySessions();
      _isLoading = false;
      notifyListeners();
      _fetchFullDetailsForChart();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lazily fetches full details for the most recent completed sessions
  /// to ensure the Focus Trend Chart has accurate data (as the list API often omits it).
  Future<void> _fetchFullDetailsForChart() async {
    if (_patientSessions.isEmpty) return;

    final completedSessions = _patientSessions.where((s) => s.isComplete).toList();
    if (completedSessions.isEmpty) return;

    // Get up to the 20 most recent completed sessions (the ones used in the chart)
    final recentCompleted = completedSessions.take(20).toList();

    for (int i = 0; i < recentCompleted.length; i++) {
      final session = recentCompleted[i];
      // Only fetch if focus is exactly 0.0 (meaning it was missing from the list API)
      if (session.focusedPercentage == 0.0 && session.averageFocus == null) {
        try {
          final fullSession = await _sessionRepository.getSessionDetails(int.parse(session.id));
          // Replace the summary session with the full session in our list
          final index = _patientSessions.indexWhere((s) => s.id == session.id);
          if (index != -1) {
            _patientSessions[index] = fullSession.copyWith(index: session.index);
            notifyListeners(); // Update the UI immediately so the chart redraws
          }
        } catch (e) {
          debugPrint('Failed to lazy load session details for chart: $e');
        }
      }
    }
  }

  // ── Create Session ─────────────────────────────────────────────────────

  /// Creates a new session on the server with segments, then starts the local timer.
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
      // 1. Create session on server
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

      // 2. Start session on server
      if (_activeSessionId != null) {
        await _sessionRepository.startSession(_activeSessionId!);
      }

      // 3. Start local timer
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

  /// Creates a new session on the server without starting it.
  /// The embedded device is responsible for starting the session later.
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

  // ── Legacy Aliases (Backwards Compatibility) ───────────────────────────

  /// Alias for createAndStartSession to support existing UI calls.
  Future<void> startSession({
    required int receiverId,
    required List<SessionPart> parts,
  }) async {
    return createSession(patientId: receiverId, parts: parts);
  }

  /// Alias for endCurrentSession to support existing UI calls.
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
          // Move to next part
          if (_currentPartIndex < _parts.length - 1) {
            _currentPartIndex++;
            _secondsRemainingInPart = _parts[_currentPartIndex].durationMinutes * 60;
            _partStartTime = DateTime.now();
            _initialSecondsRemaining = _secondsRemainingInPart;
            notifyListeners();
          } else {
            endCurrentSession(); // All parts completed
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

  // ── Cleanup ────────────────────────────────────────────────────────────

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
