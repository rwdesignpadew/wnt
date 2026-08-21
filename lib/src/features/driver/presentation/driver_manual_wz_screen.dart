import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/driver_providers.dart';
import 'driver_service_screen.dart';

class DriverManualWzScreen extends ConsumerStatefulWidget {
  const DriverManualWzScreen({super.key});

  @override
  ConsumerState<DriverManualWzScreen> createState() =>
      _DriverManualWzScreenState();
}

class _DriverManualWzScreenState extends ConsumerState<DriverManualWzScreen> {
  late final Future<Map<String, dynamic>> _future;
  int? _clientId;
  int? _locationId;
  bool _saving = false;

  Future<void> _selectClient(List<Map<String, dynamic>> clients) async {
    FocusManager.instance.primaryFocus?.unfocus();
    var query = '';
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final results = clients
              .where((item) {
                final haystack = '${item['name']} ${item['address']}'
                    .toLowerCase();
                return haystack.contains(query.toLowerCase());
              })
              .take(50)
              .toList();
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
              child: Column(
                children: [
                  AppBar(
                    automaticallyImplyLeading: false,
                    title: const Text('Wybierz klienta'),
                    actions: [
                      IconButton(
                        tooltip: 'Zamknij',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Szukaj po nazwie lub adresie',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) =>
                          setDialogState(() => query = value.trim()),
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(child: Text('Brak pasujących klientów'))
                        : ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = results[index];
                              return ListTile(
                                leading: const Icon(Icons.business_outlined),
                                title: Text('${item['name']}'),
                                subtitle: '${item['address'] ?? ''}'.isEmpty
                                    ? null
                                    : Text('${item['address']}'),
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Navigator.pop(dialogContext, item);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _clientId = _int(selected['id']);
      final selectedLocations = _maps(selected['locations']);
      _locationId = selectedLocations.isEmpty
          ? null
          : _int(selectedLocations.first['id']);
    });
  }

  @override
  void initState() {
    super.initState();
    final token = ref.read(authControllerProvider).session!.token;
    _future = ref.read(driverRepositoryProvider).manualOptions(token);
  }

  Future<void> _continue(Map<String, dynamic> data) async {
    if (_clientId == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(driverRepositoryProvider)
          .createManualDocument(token, _clientId!, _locationId);
      final document = (response['document'] as Map).cast<String, dynamic>();
      final products = _maps(data['products']);
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              DriverServiceScreen(document: document, products: products),
        ),
      );
      if (saved == true && mounted) {
        Navigator.pop(context, true);
      } else {
        await ref
            .read(driverRepositoryProvider)
            .discardManualDocument(token, _int(document['id']));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ręczne WZ')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AsyncErrorView(error: snapshot.error!, onRetry: () {});
        }
        final data = snapshot.data!;
        final clients = _maps(data['clients']);
        final client = clients
            .where((item) => _int(item['id']) == _clientId)
            .firstOrNull;
        final locations = _maps(client?['locations']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('1. Klient', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _selectClient(clients),
              icon: const Icon(Icons.search),
              label: Text(
                client == null
                    ? 'Wyszukaj i wybierz klienta'
                    : '${client['name']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            if (locations.isNotEmpty)
              DropdownButtonFormField<int>(
                initialValue: _locationId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lokalizacja'),
                items: locations
                    .map(
                      (item) => DropdownMenuItem(
                        value: _int(item['id']),
                        child: Text(
                          '${item['name']} — ${item['address']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _locationId = value),
              ),
            const SizedBox(height: 20),
            Text(
              '2. Produkty, rozliczenie i podpis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _clientId == null || _saving
                  ? null
                  : () => _continue(data),
              icon: const Icon(Icons.description_outlined),
              label: Text(_saving ? 'Otwieranie...' : 'Dalej'),
            ),
          ],
        );
      },
    ),
  );
}

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : const [];
int _int(dynamic value) => int.tryParse('$value') ?? 0;
