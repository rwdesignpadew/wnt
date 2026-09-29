import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

class TemporaryPasswordScreen extends ConsumerStatefulWidget {
  const TemporaryPasswordScreen({super.key});

  @override
  ConsumerState<TemporaryPasswordScreen> createState() =>
      _TemporaryPasswordScreenState();
}

class _TemporaryPasswordScreenState
    extends ConsumerState<TemporaryPasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 8 || _password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nowe hasła muszą być takie same i mieć minimum 8 znaków.'),
      ));
      return;
    }
    setState(() => _saving = true);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .changeTemporaryPassword(_current.text, _password.text);
    if (!ok && mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(authControllerProvider).error ?? 'Nie udało się zmienić hasła.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ustaw własne hasło')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Logujesz się hasłem tymczasowym. Zanim przejdziesz dalej, ustaw własne hasło.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Hasło tymczasowe'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nowe hasło'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Powtórz nowe hasło'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Zapisywanie…' : 'Ustaw hasło'),
            ),
          ],
        ),
      ),
    ),
  );
}
