import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges any [Stream] (in practice, `AuthBloc.stream`) to a
/// [Listenable] that `GoRouter`'s `refreshListenable` parameter
/// understands.
///
/// Without this, route guards (`AppRouter.redirect`) only re-evaluate on
/// user-initiated navigation — a token silently expiring while the user
/// sits on a protected page would leave them there until they next
/// navigate somewhere, rather than being redirected to `/login`
/// immediately. This is the standard `flutter_bloc` + `go_router`
/// integration pattern (not project-specific logic).
///
/// @see AppRouter — the sole consumer, via `refreshListenable:
///   GoRouterRefreshStream(authBloc.stream)`
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
