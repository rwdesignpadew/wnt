import 'package:flutter_test/flutter_test.dart';
import 'package:woda_na_telefon/src/features/auth/domain/app_session.dart';

void main() {
  for (final role in UserRole.values) {
    test('rozpoznaje rolę ${role.name}', () {
      final user = AppUser.fromJson({
        'id': 1,
        'name': 'Test',
        'email': 'test@example.com',
        'role': role.name,
      });
      expect(user.role, role);
    });
  }

  test('odrzuca nieznaną rolę', () {
    expect(() => UserRole.parse('superuser'), throwsFormatException);
  });
}
