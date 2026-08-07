import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/stream_usecase.dart';

class _TestStreamUseCase extends StreamUseCase<int, String> {
  @override
  Stream<Either<Failure, int>> call(String params) {
    return Stream.fromIterable([Right(params.length)]);
  }
}

/// Unit tests for [StreamUseCase].
///
/// New base class introduced: no use case in the
/// application returned a `Stream` before
/// `SubscribeToPlaybackStateUseCase`, so no equivalent to [UseCase]
/// existed for the stream-returning shape. Mirrors [UseCase]'s own
/// (untested, trivially simple) contract as closely as a `Stream`
/// return type allows.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  group('StreamUseCase', () {
    test(
      'should expose a call() method returning a Stream<Either<Failure, T>>',
      () async {
        final useCase = _TestStreamUseCase();

        final results = await useCase('abc').toList();

        expect(results, [const Right<Failure, int>(3)]);
      },
    );
  });
}
