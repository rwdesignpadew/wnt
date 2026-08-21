import '../../../core/network/api_client.dart';
import '../../../core/storage/session_store.dart';
import '../domain/app_session.dart';

class AuthRepository {
  const AuthRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  Future<AppSession?> restore() async {
    final saved = await _store.read();
    if (saved == null) return null;
    try {
      final response = await _api.get('/mobile/me', token: saved.token);
      final user = AppUser.fromJson(
        (response['user'] as Map).cast<String, dynamic>(),
      );
      final session = AppSession(token: saved.token, user: user);
      await _store.write(session);
      return session;
    } catch (_) {
      await _store.clear();
      return null;
    }
  }

  Future<AppSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/mobile/login',
      body: {'email': email.trim(), 'password': password},
    );
    final session = _sessionFromResponse(response);
    await _store.write(session);
    return session;
  }

  Future<AppSession> register({
    required String name,
    required String email,
    required String password,
    required String address,
    required String phone,
    String? nip,
  }) async {
    final response = await _api.post(
      '/mobile/register',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'delivery_address': address.trim(),
        'phone': phone.trim(),
        if (nip?.trim().isNotEmpty == true) 'invoice_nip': nip!.trim(),
      },
    );
    final session = _sessionFromResponse(response);
    await _store.write(session);
    return session;
  }

  Future<String> recoverPassword(String email) async {
    final response = await _api.post(
      '/mobile/password/recover',
      body: {'email': email.trim()},
    );
    return response['message']?.toString() ??
        'Jeśli konto istnieje, wysłaliśmy instrukcję na podany adres e-mail.';
  }

  Future<void> logout(AppSession session) async {
    try {
      await _api.post('/mobile/logout', token: session.token);
    } finally {
      await _store.clear();
    }
  }

  AppSession _sessionFromResponse(Map<String, dynamic> response) {
    final rawUser = response['user'] ?? response['driver'];
    if (rawUser is! Map || response['token'] == null) {
      throw const FormatException(
        'Odpowiedź logowania nie zawiera sesji użytkownika.',
      );
    }
    return AppSession(
      token: response['token'].toString(),
      user: AppUser.fromJson(rawUser.cast<String, dynamic>()),
    );
  }
}
