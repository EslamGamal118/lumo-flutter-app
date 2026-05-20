import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/firebase_data_source.dart';
import '../../data/datasources/local_data_source.dart';
import '../../data/datasources/mock_data_source.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/repositories/analysis_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/lumo_api_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/notification_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/providers/theme_provider.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/providers/patient_provider.dart';
import '../../shared/providers/community_provider.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/local_storage_service.dart';
import '../services/lumo_api_service.dart';
import '../services/mock_api_service.dart';
import '../services/notification_service.dart';
import '../services/shared_preferences_service.dart';
import '../services/connectivity_service.dart';
import '../../features/home/view_model/home_view_model.dart';
import '../../features/ai_helper/view_model/ai_view_model.dart';
import '../../features/chat/view_model/chat_view_model.dart';
import '../../features/analysis/view_model/analysis_view_model.dart';
import '../../features/analysis/view_model/image_analysis_view_model.dart';
import '../../features/community/view_model/community_view_model.dart';
import '../../features/profile/view_model/profile_view_model.dart';
import '../../features/session/view_model/session_view_model.dart';
import '../../features/home/view_model/main_layout_view_model.dart';

import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../../data/datasources/remote/auth_remote_data_source.dart';
import '../../data/datasources/remote/community_remote_data_source.dart';
import '../../data/datasources/remote/profile_remote_data_source.dart';
import '../../data/datasources/remote/chat_remote_data_source.dart';
import '../../data/datasources/remote/patient_remote_data_source.dart';
import '../../data/datasources/remote/session_remote_data_source.dart';
import '../../data/datasources/remote/notification_remote_data_source.dart';

final getIt = GetIt.instance;

class DependencyInjection {
  static Future<void> init() async {
    // SharedPreferences (async init)
    final sharedPrefs = await SharedPreferences.getInstance();
    getIt.registerLazySingleton<SharedPreferences>(() => sharedPrefs);

    // Services
    getIt.registerLazySingleton<SharedPreferencesService>(
      () => SharedPreferencesService(),
    );

    getIt.registerLazySingleton<LocalStorageService>(
      () => LocalStorageService(getIt<SharedPreferencesService>()),
    );

    getIt.registerLazySingleton<FirebaseAuthService>(
      () => FirebaseAuthService(),
    );

    getIt.registerLazySingleton<FirebaseFirestoreService>(
      () => FirebaseFirestoreService(),
    );

    getIt.registerLazySingleton<FirebaseStorageService>(
      () => FirebaseStorageService(),
    );

    getIt.registerLazySingleton<NotificationService>(
      () => NotificationService(),
    );

    getIt.registerLazySingleton<MockApiService>(
      () => MockApiService(),
    );

    // LUMO Microservices
    getIt.registerLazySingleton<LumoApiService>(
      () => LumoApiService(),
    );

    getIt.registerLazySingleton<ConnectivityService>(
      () => ConnectivityService(),
    );

    getIt.registerLazySingleton<LumoApiRepository>(
      () => LumoApiRepository(getIt<LumoApiService>()),
    );

    // Network & API
    getIt.registerLazySingleton<Dio>(() => Dio());
    getIt.registerLazySingleton<DioClient>(
      () => DioClient(getIt<Dio>(), getIt<SharedPreferences>()),
    );

    getIt.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(getIt<DioClient>()),
    );
    getIt.registerLazySingleton<CommunityRemoteDataSource>(
      () => CommunityRemoteDataSourceImpl(getIt<DioClient>()),
    );
    getIt.registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSourceImpl(getIt<DioClient>()),
    );
    getIt.registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSourceImpl(getIt<DioClient>()),
    );
    getIt.registerLazySingleton<PatientRemoteDataSource>(
      () => PatientRemoteDataSourceImpl(getIt<DioClient>()),
    );
    getIt.registerLazySingleton<SessionRemoteDataSource>(
      () => SessionRemoteDataSourceImpl(getIt<DioClient>()),
    );
    getIt.registerLazySingleton<NotificationRemoteDataSource>(
      () => NotificationRemoteDataSourceImpl(getIt<DioClient>()),
    );

    // Data Sources
    getIt.registerLazySingleton<FirebaseDataSource>(
      () => FirebaseDataSource(
        getIt<FirebaseAuthService>(),
        getIt<FirebaseFirestoreService>(),
        getIt<FirebaseStorageService>(),
      ),
    );

    getIt.registerLazySingleton<LocalDataSource>(
      () => LocalDataSource(getIt<LocalStorageService>()),
    );

    getIt.registerLazySingleton<MockDataSource>(
      () => MockDataSource(getIt<MockApiService>()),
    );

    // Repositories
    getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepository(
        getIt<AuthRemoteDataSource>(),
        getIt<SharedPreferences>(),
      ),
    );

    getIt.registerLazySingleton<ProfileRepository>(
      () => ProfileRepository(
        getIt<FirebaseDataSource>(),
        getIt<LocalDataSource>(),
        getIt<ProfileRemoteDataSource>(),
      ),
    );

    getIt.registerLazySingleton<CommunityRepository>(
      () => CommunityRepository(
        getIt<CommunityRemoteDataSource>(),
      ),
    );

    getIt.registerLazySingleton<ChatRepository>(
      () => ChatRepository(
        getIt<FirebaseDataSource>(),
        getIt<LocalDataSource>(),
        getIt<ChatRemoteDataSource>(),
      ),
    );

    getIt.registerLazySingleton<SessionRepository>(
      () => SessionRepository(getIt<SessionRemoteDataSource>()),
    );

    getIt.registerLazySingleton<AnalysisRepository>(
      () => AnalysisRepository(
        getIt<FirebaseDataSource>(),
        getIt<LocalDataSource>(),
      ),
    );

    getIt.registerLazySingleton<AIRepository>(
      () => AIRepository(
        getIt<LocalDataSource>(),
      ),
    );

    getIt.registerLazySingleton<PatientRepository>(
      () => PatientRepository(getIt<PatientRemoteDataSource>()),
    );

    getIt.registerLazySingleton<NotificationRepository>(
      () => NotificationRepository(getIt<NotificationRemoteDataSource>()),
    );

    // Providers
    getIt.registerLazySingleton<AuthProvider>(
      () => AuthProvider(
        getIt<AuthRepository>(),
        getIt<ProfileRepository>(),
        getIt<LocalDataSource>(),
      ),
    );

    getIt.registerLazySingleton<UserProvider>(
      () => UserProvider(
        getIt<ProfileRepository>(),
      ),
    );

    getIt.registerLazySingleton<ThemeProvider>(
      () => ThemeProvider(getIt<LocalDataSource>()),
    );

    getIt.registerLazySingleton<LocaleProvider>(
      () => LocaleProvider(getIt<LocalDataSource>()),
    );

    getIt.registerLazySingleton<NotificationProvider>(
      () => NotificationProvider(
        getIt<NotificationService>(),
        getIt<NotificationRepository>(),
      ),
    );

    getIt.registerLazySingleton<PatientProvider>(
      () => PatientProvider(
        getIt<LocalDataSource>(),
        getIt<PatientRepository>(),
        getIt<ProfileRepository>(),
      ),
    );

    getIt.registerLazySingleton<CommunityProvider>(
      () => CommunityProvider(),
    );

    // ViewModels
    getIt.registerLazySingleton<MainLayoutViewModel>(
      () => MainLayoutViewModel(),
    );

    getIt.registerFactory<HomeViewModel>(
      () => HomeViewModel(),
    );

    getIt.registerFactory<AIViewModel>(
      () => AIViewModel(getIt<AIRepository>()),
    );

    getIt.registerFactory<ChatViewModel>(
      () => ChatViewModel(
        getIt<ChatRepository>(),
        getIt<FirebaseAuthService>(),
        getIt<LocalDataSource>(),
      ),
    );

    getIt.registerFactory<SessionViewModel>(
      () => SessionViewModel(getIt<SessionRepository>()),
    );

    getIt.registerFactory<AnalysisViewModel>(
      () => AnalysisViewModel(getIt<AnalysisRepository>()),
    );

    getIt.registerFactory<ImageAnalysisViewModel>(
      () => ImageAnalysisViewModel(getIt<LumoApiRepository>()),
    );

    getIt.registerLazySingleton<CommunityViewModel>(
      () => CommunityViewModel(getIt<CommunityRepository>()),
    );

    getIt.registerFactory<ProfileViewModel>(
      () => ProfileViewModel(repository: getIt<ProfileRepository>()),
    );
  }
}
