import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
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
      final session = AppSession(
        token: saved.token,
        user: user,
        adminToken: saved.adminToken,
        adminUser: saved.adminUser,
      );
      await _store.write(session);
      return session;
    } on ApiException catch (error) {
      // No network is not an authentication failure. Keep the last verified
      // session so the driver can open the cached route and work offline.
      if (error.statusCode == null) return saved;
      await _store.clear();
      return null;
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

  Future<void> deleteAccount(AppSession session) async {
    try {
      await _api.delete('/mobile/account', token: session.token);
    } finally {
      await _store.clear();
    }
  }

  Future<AppSession> switchToDriver(
    AppSession adminSession,
    int driverId,
  ) async {
    final response = await _api.post(
      '/mobile/admin/switch-to-driver/$driverId',
      token: adminSession.token,
    );
    final driverSession = _sessionFromResponse(response);
    final session = AppSession(
      token: driverSession.token,
      user: driverSession.user,
      adminToken: adminSession.adminToken ?? adminSession.token,
      adminUser: adminSession.adminUser ?? adminSession.user,
    );
    await _store.write(session);
    return session;
  }

  Future<AppSession> switchToAdmin(AppSession driverSession) async {
    if (!driverSession.canReturnToAdmin) {
      throw const FormatException('Brak zapisanej sesji administratora.');
    }
    final session = AppSession(
      token: driverSession.adminToken!,
      user: driverSession.adminUser!,
    );
    await _store.write(session);
    return session;
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
