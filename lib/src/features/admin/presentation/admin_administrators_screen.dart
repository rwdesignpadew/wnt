import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';

class AdminAdministratorsScreen extends ConsumerStatefulWidget {
  const AdminAdministratorsScreen({super.key});
  @override
  ConsumerState<AdminAdministratorsScreen> createState() => _State();
}

class _State extends ConsumerState<AdminAdministratorsScreen> {
  Map<String, dynamic>? data;
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final token = ref.read(authControllerProvider).session!.token;
      data = await ref.read(adminRepositoryProvider).administrators(token);
    } catch (e) {
      error = e;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final options = (data?['permission_options'] as Map? ?? const {})
        .cast<String, dynamic>();
    final name = TextEditingController(text: item?['name']?.toString());
    final email = TextEditingController(text: item?['email']?.toString());
    final phone = TextEditingController(text: item?['phone']?.toString());
    final password = TextEditingController();
    final Iterable<dynamic> initialPermissions =
        (item?['permissions'] as List?) ?? options.keys;
    final selected = initialPermissions.map((e) => '$e').toSet();
    var active = item?['is_active'] != false;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(
            item == null ? 'Nowy administrator' : 'Edytuj administratora',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Imię i nazwisko',
                    ),
                  ),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: item == null
                          ? 'Hasło'
                          : 'Nowe hasło (opcjonalnie)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Uprawnienia',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final entry in options.entries)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(entry.key),
                      title: Text('${entry.value}'),
                      onChanged: (value) => setDialog(
                        () => value == true
                            ? selected.add(entry.key)
                            : selected.remove(entry.key),
                      ),
                    ),
                  if (item != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      title: const Text('Konto aktywne'),
                      onChanged: (v) => setDialog(() => active = v),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
    if (save != true || !mounted) return;
    try {
      final token = ref.read(authControllerProvider).session!.token;
      await ref
          .read(adminRepositoryProvider)
          .saveAdministrator(token, item?['id'] as int?, {
            'name': name.text.trim(),
            'email': email.text.trim(),
            'phone': phone.text.trim(),
            'password': password.text,
            'permissions': selected.toList(),
            'is_active': active,
          });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: WntColors.error),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (item['is_current'] == true) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć administratora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final token = ref.read(authControllerProvider).session!.token;
    await ref
        .read(adminRepositoryProvider)
        .deleteAdministrator(token, item['id'] as int);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administratorzy')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _edit(),
      child: const Icon(Icons.add),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(child: Text('$error'))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: (data?['items'] as List? ?? const []).length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = ((data!['items'] as List)[index] as Map)
                    .cast<String, dynamic>();
                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: item['is_active'] == true
                          ? WntColors.brand
                          : WntColors.muted,
                    ),
                    title: Text('${item['name']}'),
                    subtitle: Text(
                      '${item['email']}\n${item['is_main'] == true ? 'Pełny dostęp' : '${(item['permissions'] as List? ?? const []).length} uprawnień'}',
                    ),
                    isThreeLine: true,
                    onTap: () => _edit(item),
                    trailing: item['is_current'] == true
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(item),
                          ),
                  ),
                );
              },
            ),
          ),
  );
}
