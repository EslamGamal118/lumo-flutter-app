import 'package:flutter/material.dart';
import '../../core/enums/user_role.dart';
import '../../data/datasources/local_data_source.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/models/user_model.dart';
import '../../data/models/parent_model.dart';
import '../../data/models/connection_request_model.dart';

class PatientProvider with ChangeNotifier {
  final LocalDataSource _localDataSource;
  final PatientRepository _patientRepository;
  final ProfileRepository _profileRepository;

  List<UserModel> _patients = [];
  List<UserModel> _doctors = [];
  List<ConnectionRequestModel> _joinRequests = [];
  List<ConnectionRequestModel> _sentRequests = [];
  bool _isLoading = false;
  String? _error;

  PatientProvider(
    this._localDataSource,
    this._patientRepository,
    this._profileRepository,
  ) {
    _loadLocalData();
  }

  // Getters
  List<UserModel> get patients => _patients;
  List<UserModel> get doctors => _doctors;
  List<ConnectionRequestModel> get joinRequests => _joinRequests;
  /// Requests the current doctor sent (includes pending, accepted, rejected)
  List<ConnectionRequestModel> get sentRequests => _sentRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalPatients => _patients.length;
  int get pendingRequestsCount => _joinRequests.length;
  double get patientsTrend => 0.0; // Simplified for now

  void _loadLocalData() {
    final cachedPatients = _localDataSource.getPatients();
    if (cachedPatients != null) {
      _patients = cachedPatients.map((e) => UserModel.fromJson(e)).toList();
    }
    notifyListeners();
  }

  Future<void> fetchParentConnectedDoctors(int parentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<int, UserModel> doctorMap = {};

      // Source 1: network API (doctor + social follows)
      try {
        final networkList = await _profileRepository.getUserNetwork();
        for (final u in networkList) {
          if (u.role == UserRole.doctor) {
            doctorMap[u.id] = u;
          }
        }
        debugPrint('🔍 fetchParentConnectedDoctors: ${doctorMap.length} doctors from network');
      } catch (e) {
        debugPrint('🔍 network fetch failed: $e');
      }

      // Source 2: fetch doctors from connectedDoctorIds stored in the ParentModel
      // (We fetch a fresh profile to ensure we have the latest accepted connections)
      try {
        List<dynamic> connIds = [];
        try {
          final freshProfile = await _profileRepository.getUserProfile(parentId);
          if (freshProfile is ParentModel) {
            connIds = freshProfile.connectedDoctorIds;
            // Update local cache with fresh data
            await _localDataSource.saveCurrentUser(freshProfile.toJson());
          }
        } catch (e) {
          debugPrint('🔍 fresh profile fetch failed, falling back to cache: $e');
          final cachedUser = _localDataSource.getCurrentUser();
          if (cachedUser != null) {
            connIds = (cachedUser['connected_doctor_ids'] as List<dynamic>?) ?? [];
          }
        }

        for (final idStr in connIds) {
          final id = int.tryParse(idStr.toString());
          if (id != null && !doctorMap.containsKey(id)) {
            final doctor = await _profileRepository.getUserProfile(id);
            if (doctor != null) {
              doctorMap[id] = doctor;
            }
          }
        }
        debugPrint('🔍 fetchParentConnectedDoctors: ${doctorMap.length} total after connectedDoctorIds');
      } catch (e) {
        debugPrint('🔍 connectedDoctorIds fetch failed: $e');
      }

      _doctors = doctorMap.values.toList();
      debugPrint('🔍 fetchParentConnectedDoctors: final ${_doctors.length} doctors');
    } catch (e) {
      debugPrint('❌ fetchParentConnectedDoctors error: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDoctors(List<String> doctorIds) async {
    if (doctorIds.isEmpty) {
      _doctors = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final List<UserModel> fetchedDoctors = [];
      for (final idStr in doctorIds) {
        final id = int.tryParse(idStr);
        if (id != null) {
          final doctor = await _profileRepository.getUserProfile(id);
          if (doctor != null) {
            fetchedDoctors.add(doctor);
          }
        }
      }
      _doctors = fetchedDoctors;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime? _lastFetchTime;

  Future<void> fetchPatients({bool forceRefresh = false}) async {
    if (_isLoading) return;

    // Prevent redundant requests if data was fetched recently (within 30 seconds)
    if (!forceRefresh && _lastFetchTime != null) {
      final diff = DateTime.now().difference(_lastFetchTime!);
      if (diff.inSeconds < 30 && _patients.isNotEmpty) {
        return; // Use cached data
      }
    }

    _isLoading = true;
    _error = null;
    // Only notify if we are actually starting a network request
    notifyListeners();

    try {
      _patients = await _patientRepository.getDoctorPatients();
      _lastFetchTime = DateTime.now();
      await _localDataSource.savePatients(_patients.map((p) => p.toJson()).toList());
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRequests() async {
    _setLoading(true);
    try {
      // Fetch pending incoming requests (parent POV) / all requests (doctor POV)
      final requests = await _patientRepository.getPendingRequests();
      _joinRequests = requests;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Fetches all requests sent BY the doctor (pending, accepted, rejected).
  Future<void> fetchSentRequests() async {
    _setLoading(true);
    try {
      final requests = await _patientRepository.getSentRequests();
      _sentRequests = requests;
      _error = null;
    } catch (e) {
      // Silently fail — not all backends support this endpoint
      debugPrint('fetchSentRequests failed: $e');
      _sentRequests = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendPatientRequest(int patientId) async {
    _setLoading(true);
    try {
      await _patientRepository.sendPatientRequest(patientId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> disconnectPatient(int patientId) async {
    _setLoading(true);
    try {
      await _patientRepository.disconnectPatient(patientId);
      // Immediately remove the disconnected patient from local cache
      _patients.removeWhere((p) => p.id == patientId);
      notifyListeners();
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> acceptPatientRequest(ConnectionRequestModel request) async {
    _setLoading(true);
    try {
      await _patientRepository.acceptRequest(int.parse(request.id));

      // Local updates for immediate UI feedback
      _joinRequests.removeWhere((r) => r.id == request.id);

      // Re-fetch patients to update the list
      await fetchPatients();

      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> rejectPatientRequest(ConnectionRequestModel request) async {
    _setLoading(true);
    try {
      await _patientRepository.rejectRequest(int.parse(request.id));

      // Local update
      _joinRequests.removeWhere((r) => r.id == request.id);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void resetState() {
    _patients = [];
    _joinRequests = [];
    _sentRequests = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<List<UserModel>> searchPatients(String query) async {
    _setLoading(true);
    try {
      final results = await _patientRepository.searchUsers(query);
      _error = null;
      return results;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
