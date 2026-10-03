import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/token_store.dart';
import '../core/config.dart';
import '../data/models.dart';
import '../data/repository.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(tokenStoreProvider),
    // Read lazily at call time (not at build time) so there is no provider cycle.
    onSessionExpired: () async => ref.read(sessionProvider.notifier).expired(),
  );
});

final repositoryProvider = Provider<StaffRepository>((ref) => StaffRepository(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)));

/* ───────────── session ───────────── */

sealed class SessionState {
  const SessionState();
}

class SessionLoading extends SessionState {
  const SessionLoading();
}

class SignedOut extends SessionState {
  const SignedOut({this.message});
  final String? message;
}

/// Signed in on this device, but the server couldn't be reached at launch — keep the session, offer Retry.
class SessionUnreachable extends SessionState {
  const SessionUnreachable();
}

class SignedIn extends SessionState {
  const SignedIn(this.staff);
  final Staff staff;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(_restore);
    return const SessionLoading();
  }

  StaffRepository get _repo => ref.read(repositoryProvider);

  Future<void> _restore() async {
    if (!await _repo.hasSession()) {
      state = const SignedOut();
      return;
    }
    try {
      state = SignedIn(await _repo.me());
    } on ApiException catch (e) {
      if (e.isNetwork || e.status >= 500) {
        // Network blip or server restart at launch: don't sign the person out over it.
        state = const SessionUnreachable();
      } else {
        await ref.read(tokenStoreProvider).clear();
        state = const SignedOut();
      }
    }
  }

  Future<void> retry() async {
    state = const SessionLoading();
    await _restore();
  }

  Future<void> login(String username, String password) async {
    final device = kIsWeb ? 'Web browser' : '${defaultTargetPlatform.name} app';
    state = SignedIn(await _repo.login(username, password, device));
  }

  Future<void> changePassword(String current, String next) async {
    state = SignedIn(await _repo.changePassword(current, next));
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const SignedOut();
  }

  /// The server ended the session (disabled, password reset, expired).
  Future<void> expired() async {
    if (state is SignedIn) state = const SignedOut(message: 'Your session ended. Please sign in again.');
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

final currentStaffProvider = Provider<Staff?>((ref) {
  final session = ref.watch(sessionProvider);
  return session is SignedIn ? session.staff : null;
});

/* ───────────── order board ───────────── */

class BoardState {
  const BoardState({this.summary, this.error, this.newOrderAlert = 0});
  final BoardSummary? summary;
  final String? error;

  /// Increments whenever new orders arrive — the board shows a banner when it changes.
  final int newOrderAlert;

  BoardState copyWith({BoardSummary? summary, String? error, bool clearError = false, int? newOrderAlert}) =>
      BoardState(summary: summary ?? this.summary, error: clearError ? null : (error ?? this.error), newOrderAlert: newOrderAlert ?? this.newOrderAlert);
}

/// Polls the tiny summary endpoint while the app is open and signed in, and chimes on new orders.
class BoardController extends Notifier<BoardState> with WidgetsBindingObserver {
  Timer? _timer;
  AudioPlayer? _player;
  bool _foreground = true;

  @override
  BoardState build() {
    final signedIn = ref.watch(sessionProvider) is SignedIn;
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
      _player?.dispose();
      _player = null;
    });
    if (signedIn) {
      Future.microtask(refresh);
      _timer = Timer.periodic(AppConfig.boardPoll, (_) {
        if (_foreground) refresh();
      });
    }
    return const BoardState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && ref.read(sessionProvider) is SignedIn) refresh();
  }

  Future<void> refresh() async {
    try {
      final next = await ref.read(repositoryProvider).summary();
      final previous = state.summary;
      final arrived =
          previous != null &&
          (next.count(BoardTab.newOrders) > previous.count(BoardTab.newOrders) ||
              (next.latestPlacedAt != null && previous.latestPlacedAt != null && next.latestPlacedAt!.isAfter(previous.latestPlacedAt!)));
      state = state.copyWith(summary: next, clearError: true, newOrderAlert: arrived ? state.newOrderAlert + 1 : null);
      if (arrived) unawaited(chime());
      if (previous == null || previous.version != next.version) ref.invalidate(orderListRefreshProvider);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.friendly);
    }
  }

  Future<void> chime() async {
    try {
      // Created on first use: no audio resources held until an order actually arrives.
      final player = _player ??= AudioPlayer();
      await player.play(AssetSource('sounds/new_order.wav'));
    } catch (_) {
      // Browsers block sound until the page has been clicked once; the banner still shows.
    }
  }
}

final boardProvider = NotifierProvider<BoardController, BoardState>(BoardController.new);

/// Bumped (invalidated) when the board version changes, so open lists reload.
final orderListRefreshProvider = Provider<int>((ref) => DateTime.now().millisecondsSinceEpoch);

/// On wide screens the board shows the selected order next to the list.
final selectedOrderProvider = StateProvider<String?>((ref) => null);
