import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/firebase_session_entity.dart';
import '../cubit/firebase_session_cubit.dart';
import '../cubit/firebase_session_state.dart';

/// Renders [builder] only once a Firebase session is established,
/// showing a loading indicator or a retry affordance until then.
///
/// Any screen touching the Realtime Database must sit behind this
/// widget. Without a session, `auth` is null on every request, and once
/// the strict security rules are deployed the first presence write
/// fails with `permission_denied` — a failure that surfaces as an empty
/// participant list rather than as anything a user could interpret.
///
/// ## Why this is a widget and not a condition in `RoomDetailPage`
/// The gate carries three states, a trigger, and a retry path. Inlining
/// that into a page which already provides seven blocs would bury it,
/// and it would have to be repeated by the next screen that needs the
/// database. As a widget it is testable on its own, which is where the
/// interesting assertions live: that it triggers exactly once, and that
/// it does not build its subtree early.
///
/// The second matters more than it looks. `builder` constructs
/// `PresenceCubit` with the session's uid; calling it before the uid
/// exists is precisely the bug this widget prevents, and no page-level
/// test would catch it.
///
/// ## Trigger placement
/// [initState] triggers [FirebaseSessionCubit.synchronise] when no
/// session is ready. Emitting from a cubit during `initState` is safe —
/// it is not a build phase — and doing it here rather than in `build`
/// guarantees exactly one trigger per mount regardless of how often the
/// widget rebuilds.
///
/// @see FirebaseSessionCubit — the state this widget consumes
class FirebaseSessionGate extends StatefulWidget {
  const FirebaseSessionGate({
    super.key,
    required this.appUserId,
    required this.builder,
  });

  /// The signed-in user's application UUID, or `null` for a visitor.
  ///
  /// Decides whether the gate asks for a named or an anonymous session.
  /// Not an identity assertion: the backend resolves the real one from
  /// the bearer token.
  final String? appUserId;

  /// Builds the gated subtree. Called only with an established session.
  final Widget Function(BuildContext context, FirebaseSessionEntity session)
  builder;

  @override
  State<FirebaseSessionGate> createState() => _FirebaseSessionGateState();
}

class _FirebaseSessionGateState extends State<FirebaseSessionGate> {
  @override
  void initState() {
    super.initState();
    _synchroniseIfNeeded();
  }

  @override
  void didUpdateWidget(FirebaseSessionGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A user signing in while this screen is mounted must not keep
    // acting under the anonymous session the gate established for them.
    if (oldWidget.appUserId != widget.appUserId) {
      _synchronise();
    }
  }

  void _synchroniseIfNeeded() {
    if (context.read<FirebaseSessionCubit>().state is FirebaseSessionReady) {
      return;
    }
    _synchronise();
  }

  void _synchronise() {
    context.read<FirebaseSessionCubit>().synchronise(
      appUserId: widget.appUserId,
    );
  }

  String _errorMessage(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      NetworkFailure() => l10n.firebaseSessionNetworkMessage,
      _ => l10n.firebaseSessionFailureMessage,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<FirebaseSessionCubit, FirebaseSessionState>(
      builder: (context, state) {
        return switch (state) {
          FirebaseSessionReady(:final session) => widget.builder(
            context,
            session,
          ),
          FirebaseSessionFailure(:final failure) => _GateMessage(
            key: const Key('firebaseSessionGateFailure'),
            message: _errorMessage(l10n, failure),
            onRetry: _synchronise,
            retryLabel: l10n.firebaseSessionRetryButtonLabel,
          ),
          FirebaseSessionInitial() ||
          FirebaseSessionEstablishing() => _GateMessage(
            key: const Key('firebaseSessionGateEstablishing'),
            message: l10n.firebaseSessionEstablishingMessage,
            showIndicator: true,
          ),
        };
      },
    );
  }
}

/// Centred message with an optional spinner or retry button.
class _GateMessage extends StatelessWidget {
  const _GateMessage({
    super.key,
    required this.message,
    this.showIndicator = false,
    this.onRetry,
    this.retryLabel,
  });

  final String message;
  final bool showIndicator;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIndicator) ...[
              const CircularProgressIndicator(
                key: Key('firebaseSessionGateIndicator'),
              ),
              const SizedBox(height: 16),
            ],
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('firebaseSessionGateRetryButton'),
                onPressed: onRetry,
                child: Text(retryLabel ?? ''),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
