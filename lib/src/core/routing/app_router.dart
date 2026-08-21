import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/recover_password_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/role_home_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/recover',
        builder: (context, state) => const RecoverPasswordScreen(),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => const RoleHomeScreen(),
      ),
    ],
    redirect: (context, state) {
      final authPath = {'/login', '/register', '/recover'};
      final path = state.matchedLocation;
      if (auth.status == AuthStatus.checking) {
        return path == '/start' ? null : '/start';
      }
      if (auth.status == AuthStatus.signedOut) {
        return authPath.contains(path) ? null : '/login';
      }
      return path == '/app' ? null : '/app';
    },
  );
});
