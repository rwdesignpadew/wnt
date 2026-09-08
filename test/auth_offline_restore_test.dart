import 'package:flutter_test/flutter_test.dart';
import 'package:woda_na_telefon/src/core/network/api_client.dart';
import 'package:woda_na_telefon/src/core/network/api_exception.dart';
import 'package:woda_na_telefon/src/core/storage/session_store.dart';
import 'package:woda_na_telefon/src/features/auth/data/auth_repository.dart';
import 'package:woda_na_telefon/src/features/auth/domain/app_session.dart';

void main() {
  const saved = AppSession(
    token: 'saved-token',
    user: AppUser(
      id: 7,
      name: 'Kierowca',
      email: 'driver@example.test',
      role: UserRole.driver,
    ),
  );

  test('network outage keeps the last verified session', () async {
    final store = _MemorySessionStore(saved);
    final repository = AuthRepository(_OfflineApiClient(), store);

    final restored = await repository.restore();

    expect(restored?.token, saved.token);
    expect(store.cleared, isFalse);
  });

  test('server rejection clears an invalid session', () async {
    final store = _MemorySessionStore(saved);
    final repository = AuthRepository(_RejectedApiClient(), store);

    expect(await repository.restore(), isNull);
    expect(store.cleared, isTrue);
  });
}

class _MemorySessionStore extends SessionStore {
  _MemorySessionStore(this.session);

  AppSession? session;
  bool cleared = false;

  @override
  Future<AppSession?> read() async => session;

  @override
  Future<void> write(AppSession value) async => session = value;

  @override
  Future<void> clear() async {
    cleared = true;
    session = null;
  }
}

class _OfflineApiClient extends ApiClient {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Map<String, String>? query,
  }) => throw const ApiException('Brak połączenia.');
}

class _RejectedApiClient extends ApiClient {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Map<String, String>? query,
  }) => throw const ApiException('Sesja wygasła.', statusCode: 401);
}
