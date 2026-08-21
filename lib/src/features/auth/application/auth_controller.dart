import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../data/auth_repository.dart';
import '../domain/app_session.dart';

enum AuthStatus { checking, signedOut, signedIn }

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.busy = false,
    this.error,
  });

  const AuthState.checking() : this(status: AuthStatus.checking);
  const AuthState.signedOut({String? error})
    : this(status: AuthStatus.signedOut, error: error);
  const AuthState.signedIn(AppSession session)
    : this(status: AuthStatus.signedIn, session: session);

  final AuthStatus status;
  final AppSession? session;
  final bool busy;
  final String? error;

  AuthState copyWith({bool? busy, String? error, bool clearError = false}) =>
      AuthState(
        status: status,
        session: session,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider), ref.watch(pushNotificationServiceProvider))..restore(),
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._push) : super(const AuthState.checking());

  final AuthRepository _repository;
  final PushNotificationService _push;

  Future<void> restore() async {
    final session = await _repository.restore();
    state = session == null
        ? const AuthState.signedOut()
        : AuthState.signedIn(session);
    if (session != null) await _push.register(session.token);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await _repository.login(email: email, password: password);
      state = AuthState.signedIn(session);
      await _push.register(session.token);
      return true;
    } catch (error) {
      state = AuthState.signedOut(
        error: error.toString(),
      ).copyWith(busy: false);
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String address,
    required String phone,
    String? nip,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await _repository.register(
          name: name,
          email: email,
          password: password,
          address: address,
          phone: phone,
          nip: nip,
        );
      state = AuthState.signedIn(session);
      await _push.register(session.token);
      return true;
    } catch (error) {
      state = AuthState.signedOut(
        error: error.toString(),
      ).copyWith(busy: false);
      return false;
    }
  }

  Future<String> recoverPassword(String email) =>
      _repository.recoverPassword(email);

  Future<void> logout() async {
    final session = state.session;
    if (session != null) {
      await _push.unregister(session.token);
      await _repository.logout(session);
    }
    state = const AuthState.signedOut();
  }
}
