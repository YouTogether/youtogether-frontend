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
}
