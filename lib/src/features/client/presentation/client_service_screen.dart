import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/client_providers.dart';

class ClientServiceScreen extends ConsumerStatefulWidget {
  const ClientServiceScreen({super.key});

  @override
  ConsumerState<ClientServiceScreen> createState() =>
      _ClientServiceScreenState();
}

class _ClientServiceScreenState extends ConsumerState<ClientServiceScreen> {
  final description = TextEditingController();
  int rentalId = 0;
  bool sending = false;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (rentalId == 0 || description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz sprzęt i opisz problem.')),
      );
      return;
    }
    setState(() => sending = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(clientRepositoryProvider)
          .requestService(token, rentalId, description.text.trim());
      description.clear();
      if (mounted) {
        setState(() => sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${response['message'] ?? 'Zgłoszenie wysłane.'}'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(clientHomeProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) {
          final rentals = (data['service_rentals'] as List? ?? const [])
              .whereType<Map>()
              .map((row) => row.cast<String, dynamic>())
              .toList();
          if (rentals.isEmpty) {
            return const Center(child: Text('Brak aktywnej dzierżawy.'));
          }
          if (rentalId == 0) {
            rentalId = int.tryParse('${rentals.first['id']}') ?? 0;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Zamów serwis',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Zgłoś problem ze sprzętem znajdującym się u Ciebie w dzierżawie.',
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: rentalId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sprzęt'),
                items: rentals
                    .map(
                      (rental) => DropdownMenuItem<int>(
                        value: int.tryParse('${rental['id']}') ?? 0,
                        child: Text(
                          '${rental['name']} - ${rental['location'] ?? 'Główna lokalizacja'} (${rental['quantity']} szt.)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => rentalId = value ?? 0),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: description,
                minLines: 4,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Opis problemu',
                  alignLabelWithHint: true,
                  hintText: 'Opisz usterkę i objawy...',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: sending ? null : send,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Wyślij zgłoszenie'),
              ),
            ],
          );
        },
      );
}
