import 'package:either_dart/either.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// Base contract implemented by every use case in the application.
///
/// A use case is a single application operation. It takes a [Params]
/// value object as input and returns `Either<Failure, Type>`: [Failure]
/// on the `Left` for any error condition, or the successful [T] on
/// the `Right`.
///
/// Use cases contain no business logic beyond orchestration — they
/// delegate to a repository interface and return its result unchanged.
/// This mirrors the backend's `RegisterUseCase.execute()` pattern
/// (NestJS), keeping both codebases structurally symmetric.
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Marker Params object for use cases that take no input
/// (e.g. `LogoutUseCase`, `GetCurrentUserUseCase`).
///
/// Extends [Equatable] rather than being declared `@freezed`: it carries
/// no fields, so value equality needs no generated boilerplate.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
