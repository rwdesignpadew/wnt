import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/client_providers.dart';

class ClientAccountScreen extends ConsumerStatefulWidget {
  const ClientAccountScreen({super.key});

  @override
  ConsumerState<ClientAccountScreen> createState() =>
      _ClientAccountScreenState();
}

class _ClientAccountScreenState extends ConsumerState<ClientAccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _invoiceName = TextEditingController();
  final _invoiceNip = TextEditingController();
  final _invoiceAddress = TextEditingController();
  final _recipientName = TextEditingController();
  final _recipientNip = TextEditingController();
  final _recipientAddress = TextEditingController();
  final _recipientEmail = TextEditingController();
  bool _recipientEnabled = false;
  bool _invoiceJst = false;
  bool _recipientJst = false;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _address,
      _invoiceName,
      _invoiceNip,
      _invoiceAddress,
      _recipientName,
      _recipientNip,
      _recipientAddress,
      _recipientEmail,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> response) {
    if (_initialized || response['client'] is! Map) return;
    final client = (response['client'] as Map).cast<String, dynamic>();
    _name.text = client['name']?.toString() ?? '';
    _email.text = client['email']?.toString() ?? '';
    _phone.text = client['phone']?.toString() ?? '';
    _address.text = client['delivery_address']?.toString() ?? '';
    _invoiceName.text = client['invoice_name']?.toString() ?? '';
    _invoiceNip.text = client['invoice_nip']?.toString() ?? '';
    _invoiceAddress.text = client['invoice_address']?.toString() ?? '';
    _recipientEnabled = client['invoice_recipient_enabled'] == true;
    _invoiceJst = client['invoice_jst_enabled'] == true;
    _recipientJst = client['invoice_recipient_jst'] == true;
    _recipientName.text = client['invoice_recipient_name']?.toString() ?? '';
    _recipientNip.text = client['invoice_recipient_nip']?.toString() ?? '';
    _recipientAddress.text =
        client['invoice_recipient_address']?.toString() ?? '';
    _recipientEmail.text = client['invoice_recipient_email']?.toString() ?? '';
    _initialized = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(clientRepositoryProvider)
          .updateProfile(token, {
            'name': _name.text.trim(),
            'email': _email.text.trim(),
            'phone': _phone.text.trim(),
            'delivery_address': _address.text.trim(),
            'invoice_name': _invoiceName.text.trim(),
            'invoice_nip': _invoiceNip.text.trim(),
            'invoice_address': _invoiceAddress.text.trim(),
            'invoice_recipient_enabled': _recipientEnabled,
            'invoice_jst_enabled': _invoiceJst,
            'invoice_recipient_jst': _recipientEnabled && _recipientJst,
            'invoice_recipient_name': _recipientEnabled
                ? _recipientName.text.trim()
                : null,
            'invoice_recipient_nip': _recipientEnabled
                ? _recipientNip.text.trim()
                : null,
            'invoice_recipient_address': _recipientEnabled
                ? _recipientAddress.text.trim()
                : null,
            'invoice_recipient_email': _recipientEnabled
                ? _recipientEmail.text.trim()
                : null,
          });
      ref.invalidate(clientHomeProvider);
      _snack(response['message']?.toString() ?? 'Dane zostały zapisane.');
    } catch (error) {
      _snack(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final password = TextEditingController();
    final confirm = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zmień hasło'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Aktualne hasło'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nowe hasło'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Powtórz nowe hasło',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zmień hasło'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    if (password.text.length < 8 || password.text != confirm.text) {
      _snack(
        'Hasła muszą być takie same i mieć minimum 8 znaków.',
        error: true,
      );
      return;
    }
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final message = await ref
          .read(clientRepositoryProvider)
          .changePassword(
            token: token,
            currentPassword: current.text,
            password: password.text,
          );
      _snack(message);
    } catch (error) {
      _snack(error.toString(), error: true);
    } finally {
      current.dispose();
      password.dispose();
      confirm.dispose();
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń konto'),
        content: const Text(
          'Konto zostanie trwale usunięte i nie będzie można się ponownie zalogować. Dokumenty księgowe mogą pozostać przechowywane przez okres wymagany prawem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WntColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń konto trwale'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(error.toString(), error: true);
      }
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? WntColors.error : WntColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(clientHomeProvider);
    return home.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView(
        error: error,
        onRetry: () => ref.invalidate(clientHomeProvider),
      ),
      data: (data) {
        _fill(data);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Konto', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _Section(
              title: 'Dane kontaktowe',
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nazwa klienta'),
                ),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Adres e-mail'),
                ),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon odbiorcy',
                  ),
                ),
                TextField(
                  controller: _address,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Adres dostawy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Dane do faktury',
              children: [
                TextField(
                  controller: _invoiceName,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa do faktury',
                  ),
                ),
                TextField(
                  controller: _invoiceNip,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'NIP'),
                ),
                TextField(
                  controller: _invoiceAddress,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Adres do faktury',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Faktura dotyczy jednostki samorządowej'),
                  value: _invoiceJst,
                  onChanged: (value) => setState(() => _invoiceJst = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Odbiorca',
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Inny odbiorca faktury'),
                  value: _recipientEnabled,
                  onChanged: (value) =>
                      setState(() => _recipientEnabled = value),
                ),
                if (_recipientEnabled) ...[
                  TextField(
                    controller: _recipientName,
                    decoration: const InputDecoration(
                      labelText: 'Nazwa odbiorcy',
                    ),
                  ),
                  TextField(
                    controller: _recipientNip,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'NIP odbiorcy',
                    ),
                  ),
                  TextField(
                    controller: _recipientAddress,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Adres odbiorcy',
                    ),
                  ),
                  TextField(
                    controller: _recipientEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail odbiorcy',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Odbiorca jest jednostką samorządową'),
                    value: _recipientJst,
                    onChanged: (value) => setState(() => _recipientJst = value),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Zapisywanie...' : 'Zapisz dane'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Zmień hasło'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _deleteAccount,
              style: OutlinedButton.styleFrom(foregroundColor: WntColors.error),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Usuń konto'),
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
