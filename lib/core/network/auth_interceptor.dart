import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../features/auth/data/datasources/i_auth_local_data_source.dart';
import '../../../features/auth/domain/entities/user_entity.dart';
import '../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../features/auth/presentation/bloc/auth_state.dart';

/// Dio interceptor attaching the cached access token to every outgoing
/// request, and silently refreshing the session on an intercepted 401.
///
/// Closes gaps 5 and 6 of `ADR-001-authentication-infrastructure-deferral`:
/// before this class existed, `AuthRemoteDataSourceImpl.getCurrentUser()`
/// and `.logout()` each required the access token as an explicit method
/// parameter, and every future authenticated endpoint (Room, Video
/// Synchronisation) would have had to repeat that manual threading. Room
/// endpoints (`RoomRemoteDataSourceImpl`, forthcoming)
/// rely on this interceptor rather than re-implementing token attachment.
///
/// Collaboration with [AuthBloc]: rather than calling
/// `RefreshTokenUseCase` a second time (it already ran once inside
/// `AuthBloc.checkStatusRequested`'s own fallback, and refresh tokens
/// are rotated server-side on each use — calling it independently here
/// would race that rotation), this interceptor dispatches
/// `AuthEvent.tokenRefreshRequested()` and awaits the *next* terminal
/// state [AuthBloc] emits, then reads the freshly persisted token back
/// out of [IAuthLocalDataSource] for the retry. This keeps token
/// rotation single-owned by [AuthBloc] / `RefreshTokenUseCase` /
/// `AuthRepositoryImpl.refreshToken`, with this class only observing the
/// outcome.
///
/// The refresh-decision and retry-construction logic is exposed via
/// `@visibleForTesting` methods (see each method's own doc comment) so
/// tests can exercise this class's actual logic directly, rather than
/// coupling to Dio's internal `RequestInterceptorHandler`/
/// `ErrorInterceptorHandler` completion machinery.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required IAuthLocalDataSource localDataSource,
    required AuthBloc authBloc,
    required Dio dio,
  }) : _localDataSource = localDataSource,
       _authBloc = authBloc,
       _dio = dio;

  final IAuthLocalDataSource _localDataSource;
  final AuthBloc _authBloc;
  final Dio _dio;

  /// Marks a request as already having gone through one refresh-and-retry
  /// cycle, via `RequestOptions.extra`. Prevents an infinite loop if the
  /// retried request itself comes back 401 again (e.g. the refreshed
  /// token was immediately invalidated server-side).
  @visibleForTesting
  static const String retriedFlag = 'auth_interceptor_retried';

  /// Endpoints exempt from the refresh-and-retry flow: a 401 on any of
  /// these means the credentials/token *presented in that same request*
  /// were rejected outright (wrong password, an already-expired or
  /// replayed refresh token), not that a previously-valid session has
  /// since expired — attempting a refresh here would either loop
  /// (`/auth/refresh` itself) or make no sense (`/auth/login`,
  /// `/auth/register` carry no session to refresh yet).
  static const List<String> _refreshExemptPaths = [
    '/auth/refresh',
    '/auth/login',
    '/auth/register',
  ];

  /// Guards against dispatching `AuthEvent.tokenRefreshRequested()`
  /// multiple times for concurrent 401s (e.g. several authenticated
  /// requests in flight when the token expires) — every caller still
  /// awaits the same underlying refresh via [refreshSession]'s shared
  /// `Future`, only the first caller triggers the actual dispatch.
  Future<UserEntity?>? _pendingRefresh;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _localDataSource.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!shouldAttemptRefresh(err)) {
      handler.next(err);
      return;
    }

    final refreshedUser = await refreshSession();

    if (refreshedUser == null) {
      handler.next(err);
      return;
    }

    try {
      final retryRequestOptions = await buildRetryOptions(err.requestOptions);
      final response = await _dio.fetch<dynamic>(retryRequestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Determines whether a 401 warrants a refresh-and-retry attempt.
  ///
  /// @visibleForTesting — the core branch of this interceptor's logic,
  /// tested directly without booting Dio's interceptor pipeline.
  @visibleForTesting
  bool shouldAttemptRefresh(DioException err) {
    if (err.response?.statusCode != 401) return false;
    if (err.requestOptions.extra[retriedFlag] == true) return false;

    final path = err.requestOptions.path;
    return !_refreshExemptPaths.any(path.startsWith);
  }

  /// Triggers (or joins an already-in-flight) session refresh via
  /// [AuthBloc], returning the refreshed user on success or `null` on
  /// failure.
  ///
  /// @visibleForTesting — verifies the dispatch, the awaited outcome,
  /// and the de-duplication of concurrent callers, independently of any
  /// Dio machinery.
  @visibleForTesting
  Future<UserEntity?> refreshSession() {
    return _pendingRefresh ??= _refreshSession().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<UserEntity?> _refreshSession() async {
    _authBloc.add(const AuthEvent.tokenRefreshRequested());

    final resultState = await _authBloc.stream.firstWhere(
      (state) =>
          state is AuthAuthenticated ||
          state is AuthUnauthenticated ||
          state is AuthOperationFailure,
    );

    return switch (resultState) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
  }

  /// Builds the [RequestOptions] for retrying a failed request after a
  /// successful refresh: re-reads the (now rotated) access token from
  /// storage and marks the request via [retriedFlag], preserving every
  /// other field of the original request (method, path, body, query
  /// parameters, etc.) via `RequestOptions.copyWith`.
  ///
  /// Returns a [RequestOptions], not an [Options]: [Dio.fetch] (used by
  /// [onError] to actually replay the request) takes a full
  /// [RequestOptions], not the lighter [Options] object used when
  /// issuing a *new* request via `dio.get`/`dio.post`/etc.
  ///
  /// @visibleForTesting — verifies the header and the flag independently
  /// of Dio's own retry plumbing.
  @visibleForTesting
  Future<RequestOptions> buildRetryOptions(RequestOptions original) async {
    final newToken = await _localDataSource.getAccessToken();

    return original.copyWith(
      headers: {
        ...original.headers,
        if (newToken != null) 'Authorization': 'Bearer $newToken',
      },
      extra: {...original.extra, retriedFlag: true},
    );
  }
}
