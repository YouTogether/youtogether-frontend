import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_local_data_source_impl.dart';
import '../../features/auth/data/datasources/auth_remote_data_source_impl.dart';
import '../../features/auth/data/datasources/i_auth_local_data_source.dart';
import '../../features/auth/data/datasources/i_auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/refresh_token_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/video_sync/domain/usecases/create_video_session_usecase.dart';
import '../network/auth_interceptor.dart';
import '../../features/room/data/datasources/i_room_remote_data_source.dart';
import '../../features/room/data/datasources/room_remote_data_source_impl.dart';
import '../../features/room/data/repositories/room_repository_impl.dart';
import '../../features/room/domain/repositories/i_room_repository.dart';
import '../../features/room/domain/usecases/create_room_usecase.dart';
import '../../features/room/domain/usecases/delete_room_usecase.dart';
import '../../features/room/domain/usecases/get_public_rooms_usecase.dart';
import '../../features/room/domain/usecases/get_room_by_id_usecase.dart';
import '../../features/room/domain/usecases/join_room_usecase.dart';
import '../../features/room/domain/usecases/leave_room_usecase.dart';
import '../../features/room/domain/usecases/update_room_usecase.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../features/video_sync/data/datasources/i_presence_remote_data_source.dart';
import '../../features/video_sync/data/datasources/i_sync_barrier_remote_data_source.dart';
import '../../features/video_sync/data/datasources/i_video_session_remote_data_source.dart';
import '../../features/video_sync/data/datasources/i_video_sync_remote_data_source.dart';
import '../../features/video_sync/data/datasources/presence_remote_data_source_impl.dart';
import '../../features/video_sync/data/datasources/sync_barrier_remote_data_source_impl.dart';
import '../../features/video_sync/data/datasources/video_session_remote_data_source_impl.dart';
import '../../features/video_sync/data/datasources/video_sync_remote_data_source_impl.dart';
import '../../features/video_sync/data/repositories/presence_repository_impl.dart';
import '../../features/video_sync/data/repositories/sync_barrier_repository_impl.dart';
import '../../features/video_sync/data/repositories/video_session_repository_impl.dart';
import '../../features/video_sync/data/repositories/video_sync_repository_impl.dart';
import '../../features/video_sync/domain/repositories/i_presence_repository.dart';
import '../../features/video_sync/domain/repositories/i_sync_barrier_repository.dart';
import '../../features/video_sync/domain/repositories/i_video_session_repository.dart';
import '../../features/video_sync/domain/repositories/i_video_sync_repository.dart';
import '../../features/video_sync/domain/usecases/create_sync_barrier_usecase.dart';
import '../../features/video_sync/domain/usecases/delete_sync_barrier_usecase.dart';
import '../../features/video_sync/domain/usecases/get_current_playback_state_usecase.dart';
import '../../features/video_sync/domain/usecases/get_video_session_usecase.dart';
import '../../features/video_sync/domain/usecases/increment_ready_count_usecase.dart';
import '../../features/video_sync/domain/usecases/remove_presence_usecase.dart';
import '../../features/video_sync/domain/usecases/set_all_ready_usecase.dart';
import '../../features/video_sync/domain/usecases/set_presence_usecase.dart';
import '../../features/video_sync/domain/usecases/subscribe_to_playback_state_usecase.dart';
import '../../features/video_sync/domain/usecases/subscribe_to_presence_usecase.dart';
import '../../features/video_sync/domain/usecases/subscribe_to_sync_barrier_usecase.dart';
import '../../features/video_sync/domain/usecases/update_barrier_total_count_usecase.dart';
import '../../features/video_sync/domain/usecases/update_playback_state_usecase.dart';

/// Application-wide service locator.
///
/// Closes gap 1 of `ADR-001-authentication-infrastructure-deferral`:
/// every concrete class built across Authentication takes its
/// dependencies via constructor injection and is fully unit-testable in
/// isolation, but nothing previously constructed and wired the full
/// object graph at application startup. This file is that wiring.
///
/// ## Why plain `get_it`, not `injectable`
/// This file uses `get_it` directly, with explicit manual registration,
/// deliberately without adopting `injectable`'s annotation-driven code
/// generation: doing so would require running `build_runner` to produce
/// `injection_container.config.dart`, which cannot be executed or
/// verified in this delivery environment — shipping annotations whose
/// generated output was never actually built and run would be a
/// non-functional deliverable dressed up as a working one. Manual
/// registration is equally correct, equally testable, and mirrors the
/// directness already used on the backend (NestJS's explicit
/// `{ provide, useClass }` providers, no auto-wiring magic there
/// either). Adopting `injectable` later is a compatible, additive change
/// — nothing here would need to be redesigned, only regenerated.
final GetIt sl = GetIt.instance;

/// Registers every dependency in the Authentication bounded context.
///
/// Call once, before `runApp` — see `main.dart`.
///
/// [apiBaseUrl] is read from a build-time `--dart-define` in `main.dart`,
/// never hardcoded here (gap 7's remediation, and OWASP A05 —
/// environment-specific values must not be baked into source).
///
/// ## Registration order and the Dio <-> AuthInterceptor cycle
/// Most registrations below use `registerLazySingleton(() => ...)`,
/// resolving their own dependencies via further `sl<T>()` calls inside
/// the factory — this works cleanly because the dependency graph is a
/// DAG for every one of them.
///
/// [Dio] and [AuthInterceptor] are the one exception: the interceptor
/// needs a reference to the very [Dio] instance it will be attached to
/// (to replay a request after a successful refresh — see
/// `AuthInterceptor.onError`), so each needs the other. Registering both
/// as ordinary lazy factories that call `sl<T>()` on each other would
/// recurse infinitely the first time either is resolved, before either
/// singleton is ever cached. Instead, both are constructed directly as
/// local variables, in order, and only *then* registered as
/// already-built singletons — sidestepping GetIt's factory resolution
/// for this one pair rather than fighting it.
Future<void> initDependencies({required String apiBaseUrl}) async {
  // --- External packages ---

  const secureStorage = FlutterSecureStorage(aOptions: AndroidOptions());
  sl.registerSingleton<FlutterSecureStorage>(secureStorage);

  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ),
  );
  // TODO(security, OWASP A05): certificate pinning for this Dio instance
  // is required and is intentionally NOT
  // implemented here. Pinning needs the production API host's actual
  // certificate (or public key) fingerprint, which must come from
  // whoever operates that infrastructure — fabricating a placeholder
  // fingerprint would be either a no-op (if wrong, pinning silently
  // fails open on most implementations) or would brick every request
  // (if enforced against a cert that doesn't match reality). Add via
  // e.g. the `dio_certificate_pinning` package or a custom
  // `HttpClientAdapter`, once that fingerprint is available.
  sl.registerSingleton<Dio>(dio);

  // --- Data sources ---

  sl.registerLazySingleton<IAuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<IAuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl()),
  );

  // --- Repository ---

  sl.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
  );

  // --- Use cases ---

  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => RefreshTokenUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));

  // --- AuthBloc ---
  //
  // Registered as a singleton, not a factory: this is the application's
  // single, global source of session truth (see AuthBloc's own doc
  // comment) — every consumer (the router's redirect logic, the
  // interceptor, any future profile menu) must observe the exact same
  // instance, never one each.
  sl.registerLazySingleton(
    () => AuthBloc(
      getCurrentUserUseCase: sl(),
      refreshTokenUseCase: sl(),
      logoutUseCase: sl(),
    ),
  );

  // --- Wiring the interceptor onto Dio (see this function's own doc
  // comment for why this happens imperatively, last, rather than via
  // two more registerLazySingleton factories) ---

  final authInterceptor = AuthInterceptor(
    localDataSource: sl(),
    authBloc: sl(),
    dio: dio,
  );
  dio.interceptors.add(authInterceptor);

  // --- Room bounded context ---
  //
  // Reuses the same `Dio` singleton constructed above — already carrying
  // the `AuthInterceptor`, so every Room request gets its Authorization
  // header attached automatically, with no manual token threading (the
  // problem gap 5 of ADR-001 solved for Authentication applies here for
  // free). `RoomBloc` itself is deliberately NOT registered here — see
  // its own class doc for why it is scoped to the `/` route instead of
  // being an app-wide singleton like `AuthBloc`.

  sl.registerLazySingleton<IRoomRemoteDataSource>(
    () => RoomRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<IRoomRepository>(
    () => RoomRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetPublicRoomsUseCase(sl()));
  sl.registerLazySingleton(() => CreateRoomUseCase(sl()));
  sl.registerLazySingleton(() => GetRoomByIdUseCase(sl()));
  sl.registerLazySingleton(() => UpdateRoomUseCase(sl()));
  sl.registerLazySingleton(() => DeleteRoomUseCase(sl()));
  sl.registerLazySingleton(() => JoinRoomUseCase(sl()));
  sl.registerLazySingleton(() => LeaveRoomUseCase(sl()));

  // --- Video Synchronisation bounded context ---
  //
  // Two backends, deliberately: the metadata side (video session title,
  // thumbnail, durationSeconds) is REST, reusing the same `Dio` singleton
  // as Room and therefore the same `AuthInterceptor`; the live side
  // (playback state, presence, ready gate) is Firebase Realtime Database
  // and never touches Dio at all. Neither knows about the other — see
  // `VideoSessionMetadataEntity`'s own doc comment for why the two are
  // modelled as separate entities rather than merged.
  //
  // `FirebaseDatabase.instance` is resolved lazily, inside the factory
  // rather than eagerly here: it requires `Firebase.initializeApp()` to
  // have completed, which happens in `main.dart`. Registering it lazily
  // means the ordering constraint is satisfied by construction, not by
  // remembering to call things in the right order.
  sl.registerLazySingleton<FirebaseDatabase>(() => FirebaseDatabase.instance);

  // Data sources
  sl.registerLazySingleton<IVideoSyncRemoteDataSource>(
    () => VideoSyncRemoteDataSourceImpl(database: sl()),
  );
  sl.registerLazySingleton<IPresenceRemoteDataSource>(
    () => PresenceRemoteDataSourceImpl(database: sl()),
  );
  sl.registerLazySingleton<ISyncBarrierRemoteDataSource>(
    () => SyncBarrierRemoteDataSourceImpl(database: sl()),
  );
  sl.registerLazySingleton<IVideoSessionRemoteDataSource>(
    () => VideoSessionRemoteDataSourceImpl(sl()),
  );

  // Repositories
  sl.registerLazySingleton<IVideoSyncRepository>(
    () => VideoSyncRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<IPresenceRepository>(
    () => PresenceRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ISyncBarrierRepository>(
    () => SyncBarrierRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<IVideoSessionRepository>(
    () => VideoSessionRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases — video session metadata
  sl.registerLazySingleton(() => GetVideoSessionUseCase(sl()));
  sl.registerLazySingleton(() => CreateVideoSessionUseCase(sl()));

  // Use cases — playback state
  sl.registerLazySingleton(() => GetCurrentPlaybackStateUseCase(sl()));
  sl.registerLazySingleton(() => SubscribeToPlaybackStateUseCase(sl()));
  sl.registerLazySingleton(() => UpdatePlaybackStateUseCase(sl()));

  // Use cases — presence
  sl.registerLazySingleton(() => SetPresenceUseCase(sl()));
  sl.registerLazySingleton(() => RemovePresenceUseCase(sl()));
  sl.registerLazySingleton(() => SubscribeToPresenceUseCase(sl()));

  // Use cases — ready gate
  sl.registerLazySingleton(() => CreateSyncBarrierUseCase(sl()));
  sl.registerLazySingleton(() => SubscribeToSyncBarrierUseCase(sl()));
  sl.registerLazySingleton(() => IncrementReadyCountUseCase(sl()));
  sl.registerLazySingleton(() => UpdateBarrierTotalCountUseCase(sl()));
  sl.registerLazySingleton(() => SetAllReadyUseCase(sl()));
  sl.registerLazySingleton(() => DeleteSyncBarrierUseCase(sl()));

  // `VideoSyncBloc` and `PresenceCubit` are deliberately NOT registered
  // here, for the same reason as `RoomBloc`: both are scoped to a single
  // room's page and must be constructed fresh per visit. `PresenceCubit`
  // in particular relies on being disposed when the page's provider is —
  // that disposal is what ends the participant's presence (see its own
  // doc comment). An app-wide singleton would never be disposed, and the
  // participant would appear to be watching forever.
}
