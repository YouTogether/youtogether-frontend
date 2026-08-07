import 'package:either_dart/either.dart';

import '../error/failures.dart';

/// Base contract for use cases exposing a live [Stream] rather than a
/// single [Future] result — the stream-returning counterpart to
/// [UseCase].
///
/// Introduced for [SubscribeToPlaybackStateUseCase]: the
/// first use case in the application whose natural shape is "a stream
/// of updates" rather than "one request, one response". Every value
/// emitted on the stream is itself an `Either<Failure, T>`, so a
/// mid-stream error (e.g. Firebase connectivity lost) surfaces as a
/// `Left(FirebaseFailure)` event rather than a stream error/exception —
/// consuming code (`VideoSyncBloc`) listens with a plain `onData`
/// callback and never needs an `onError` handler for domain-level
/// failures.
///
/// @see UseCase — the Future-returning equivalent
abstract class StreamUseCase<T, Params> {
  Stream<Either<Failure, T>> call(Params params);
}
