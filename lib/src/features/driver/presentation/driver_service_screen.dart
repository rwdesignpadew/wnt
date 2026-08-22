import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../../auth/application/auth_controller.dart';
import '../../documents/presentation/pdf_document_screen.dart';
import '../application/driver_providers.dart';
import 'driver_navigation_screen.dart';

class DriverServiceScreen extends ConsumerStatefulWidget {
  const DriverServiceScreen({
    required this.document,
    required this.products,
    super.key,
  });

  final Map<String, dynamic> document;
  final List<Map<String, dynamic>> products;

  @override
  ConsumerState<DriverServiceScreen> createState() =>
      _DriverServiceScreenState();
}

class _DriverServiceScreenState extends ConsumerState<DriverServiceScreen> {
  final _quantities = <int, int>{};
  final _returnQuantities = <int, int>{};
  final _rentalReturns = <int, int>{};
  final _damagedRentalIds = <int>{};
  final _damageNotes = <int, TextEditingController>{};
  final _notes = TextEditingController();
  final _signedBy = TextEditingController();
  final _cash = TextEditingController();
  String? _signatureData;
  bool _showAll = false;
  String _productQuery = '';
  bool _saving = false;
  late String _paymentMethod;

  DriverNavigationDestination? get _clientDestination {
    final client = _map(widget.document['client']) ?? const {};
    final location = _map(widget.document['location']);
    final latitude = double.tryParse(
      '${location?['latitude'] ?? client['latitude'] ?? ''}',
    );
    final longitude = double.tryParse(
      '${location?['longitude'] ?? client['longitude'] ?? ''}',
    );
    if (latitude == null || longitude == null) return null;
    final locationName = location?['name']?.toString().trim() ?? '';
    final clientName = client['name']?.toString().trim() ?? 'Klient';
    return DriverNavigationDestination(
      latitude: latitude,
      longitude: longitude,
      title: locationName.isEmpty ? clientName : '$clientName - $locationName',
    );
  }

  Future<void> _navigateToClient() async {
    final destination = _clientDestination;
    if (destination == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverNavigationScreen(
          destinations: [destination],
          title: destination.title,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _paymentMethod = widget.document['payment_method']?.toString() == 'cash'
        ? 'cash'
        : 'transfer';
    for (final item in _list(widget.document['items'])) {
      _quantities[_int(item['product_id'])] = _int(item['quantity']);
    }
    Map<String, dynamic>? transporter;
    Map<String, dynamic>? bottles;
    for (final product in widget.products) {
      if (_returnKind(product) == _ReturnKind.transporter) transporter = product;
      if (_returnKind(product) == _ReturnKind.smallBottle) bottles = product;
    }
    if (transporter != null) {
      _returnQuantities[_int(transporter['id'])] = _quantities[_int(transporter['id'])] ?? 0;
    }
    if (transporter != null && bottles != null) {
      final expected = (_quantities[_int(transporter['id'])] ?? 0) * 24;
      final charged = _quantities[_int(bottles['id'])] ?? 0;
      _returnQuantities[_int(bottles['id'])] = (expected - charged).clamp(0, expected);
    }
    final existingCash =
        double.tryParse('${widget.document['cash_collected'] ?? ''}') ?? 0;
    if (existingCash > 0) _cash.text = existingCash.toStringAsFixed(2);
    _signedBy.text = widget.document['signed_by']?.toString().trim() ?? '';
  }

  @override
  void dispose() {
    _notes.dispose();
    _signedBy.dispose();
    _cash.dispose();
    for (final controller in _damageNotes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_signedBy.text.trim().isEmpty) {
      _message('Wpisz imię i nazwisko osoby odbierającej.', error: true);
      return;
    }
    if (_signatureData == null) {
      _message('Podpis klienta jest wymagany.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(driverRepositoryProvider)
          .complete(
            token: token,
            documentId: _int(widget.document['id']),
            quantities: _quantities,
            paymentMethod: _paymentMethod,
            signatureData: _signatureData!,
            signedBy: _signedBy.text.trim(),
            notes: _notes.text.trim(),
            cashCollected: double.tryParse(_cash.text.replaceAll(',', '.')),
            correction: widget.document['status']?.toString() == 'completed',
            rentalReturns: [
              for (final entry in _rentalReturns.entries)
                if (entry.value > 0)
                  {
                    'rental_item_id': entry.key,
                    'quantity': entry.value,
                    'damaged': _damagedRentalIds.contains(entry.key),
                    'damage_description': _damageNotes[entry.key]?.text.trim(),
                  },
            ],
          );
      if (!mounted) return;
      ref.invalidate(driverRouteProvider);
      widget.document['status'] = 'completed';
      final savedDocument = _map(response['document']) ?? widget.document;
      final documentId = _int(savedDocument['id'] ?? widget.document['id']);
      final number = savedDocument['number']?.toString() ?? 'WZ';
      final pdf = await ref
          .read(driverRepositoryProvider)
          .documentPdf(token, documentId);
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}WZ-$documentId.pdf',
      );
      await file.writeAsBytes(pdf.bytes, flush: true);
      if (!mounted) return;
      final reviewAction = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (reviewContext) => PdfDocumentScreen(
            path: file.path,
            title: number,
            bottomNavigationBar: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(reviewContext).pop('cancel'),
                      icon: const Icon(Icons.close),
                      label: const Text('Anuluj WZ'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(reviewContext).pop('edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Cofnij i popraw'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(reviewContext).pop('send'),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Wyślij do klienta'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await PdfDocumentScreen.removeTemporary(file.path);
      if (!mounted) return;
      if (reviewAction == 'send') {
        final message = await ref
            .read(driverRepositoryProvider)
            .emailDocument(token, documentId);
        if (!mounted) return;
        _message(message);
        Navigator.of(context).pop(true);
      } else if (reviewAction == 'cancel') {
        Navigator.of(context).pop(false);
      } else {
        _message('Wrócono do edycji WZ. Popraw dane i wygeneruj ponownie.');
      }
    } catch (error) {
      _message('$error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _captureSignature() async {
    final key = GlobalKey();
    final points = <Offset?>[];
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    String? signature;
    try {
      if (!mounted) return;
      signature = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        useSafeArea: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Dialog.fullscreen(
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Podpis klienta',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: RepaintBoundary(
                              key: key,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (details) => setDialogState(
                                  () => points.add(details.localPosition),
                                ),
                                onPanUpdate: (details) => setDialogState(
                                  () => points.add(details.localPosition),
                                ),
                                onPanEnd: (_) =>
                                    setDialogState(() => points.add(null)),
                                child: CustomPaint(
                                  painter: _SignaturePainter(points),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 72,
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filled(
                          tooltip: 'Zatwierdź podpis',
                          iconSize: 30,
                          onPressed: points.whereType<Offset>().length < 2
                              ? null
                              : () async {
                                  final boundary =
                                      key.currentContext!.findRenderObject()!
                                          as RenderRepaintBoundary;
                                  final image = await boundary.toImage(
                                    pixelRatio: 2,
                                  );
                                  final bytes = await image.toByteData(
                                    format: ui.ImageByteFormat.png,
                                  );
                                  if (!dialogContext.mounted) return;
                                  Navigator.pop(
                                    dialogContext,
                                    'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}',
                                  );
                                },
                          icon: const Icon(Icons.check),
                        ),
                        const SizedBox(height: 18),
                        IconButton.outlined(
                          tooltip: 'Wyczyść podpis',
                          iconSize: 28,
                          onPressed: () => setDialogState(points.clear),
                          icon: const Icon(Icons.cleaning_services_outlined),
                        ),
                        const SizedBox(height: 18),
                        IconButton.outlined(
                          tooltip: 'Anuluj',
                          iconSize: 28,
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    if (signature != null && mounted) {
      setState(() => _signatureData = signature);
    }
  }

  Future<void> _setRentalDamaged(
    int id,
    String productName,
    bool damaged,
  ) async {
    if (!damaged) {
      setState(() => _damagedRentalIds.remove(id));
      return;
    }
    final controller = _damageNotes.putIfAbsent(id, TextEditingController.new);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Uszkodzony: $productName'),
        content: TextField(
          controller: controller,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Opis uszkodzenia',
            hintText: 'Opisz dokładnie usterkę',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Zatwierdź opis'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _damagedRentalIds.add(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _map(widget.document['client']) ?? const {};
    final recurringInvoice = client['recurring_invoice_enabled'] == true;
    final location = _map(widget.document['location']);
    final assignedIds = _intSet(widget.document['available_product_ids']);
    final itemsIds = _list(
      widget.document['items'],
    ).map((e) => _int(e['product_id'])).toSet();
    final allReturnProducts = widget.products
        .where((product) => !_isRentalEquipment(product) && _isReturnProduct(product))
        .toList();
    final returnProducts = _returnProductsForDisplay(
      widget.products.where((product) => !_isRentalEquipment(product)).toList(),
    );
    final saleProducts = widget.products
        .where((product) => !_isReturnProduct(product))
        .toList();
    final primary = saleProducts
        .where(
          (product) =>
              assignedIds.contains(_int(product['id'])) ||
              itemsIds.contains(_int(product['id'])),
        )
        .toList();
    final remaining = saleProducts
        .where((product) => !primary.contains(product))
        .toList();
    final productPool = _showAll || _productQuery.isNotEmpty
        ? [...primary, ...remaining]
        : primary;
    final visible = productPool
        .where(
          (product) => '${product['name']}'.toLowerCase().contains(
            _productQuery.toLowerCase(),
          ),
        )
        .toList();
    final rentals = _list(widget.document['rental_items']);
    final locationName = location?['name']?.toString();
    final clientName = client['name']?.toString() ?? 'Klient';
    final title = locationName?.isNotEmpty == true
        ? '$clientName - $locationName'
        : clientName;
    final totalNet = widget.products.fold<double>(0, (sum, product) {
      return sum +
          (_quantities[_int(product['id'])] ?? 0) * _productPrice(product);
    });
    final total = widget.products.fold<double>(0, (sum, product) {
      return sum +
          (_quantities[_int(product['id'])] ?? 0) *
              _productGrossPrice(product);
    });
    final received = double.tryParse(_cash.text.replaceAll(',', '.')) ?? 0;
    final difference = received - total;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.document['delivery_route_id'] == null
              ? 'Ręczne WZ — produkty i rozliczenie'
              : 'Obsługa klienta',
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: WntColors.line)),
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              _saving
                  ? 'Zapisywanie...'
                  : widget.document['status'] == 'completed'
                  ? 'Zapisz korektę WZ'
                  : 'Generuj WZ i sprawdź',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(
            widget.document['delivery_address']?.toString() ?? '',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: WntColors.muted),
          ),
          if (widget.document['delivery_route_id'] != null &&
              widget.document['status'] != 'completed') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clientDestination == null
                    ? null
                    : _navigateToClient,
                icon: const Icon(Icons.navigation_outlined),
                label: Text(
                  _clientDestination == null
                      ? 'Brak współrzędnych klienta'
                      : 'Nawiguj do klienta',
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _Section(
            title: 'Produkty',
            child: Column(
              children: [
                TextField(
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onChanged: (value) => setState(() => _productQuery = value),
                  decoration: const InputDecoration(
                    labelText: 'Szukaj produktu',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < visible.length; index++) ...[
                  _ProductRow(
                    product: visible[index],
                    value: _quantities[_int(visible[index]['id'])] ?? 0,
                    netUnitPrice: _productPrice(visible[index]),
                    recurringInvoice: recurringInvoice,
                    onChanged: (value) => setState(
                      () => _quantities[_int(visible[index]['id'])] = value,
                    ),
                  ),
                  if (index < visible.length - 1) const Divider(),
                ],
                if (!_showAll && remaining.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _showAll = true),
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      'Pokaż wszystkie produkty (${remaining.length})',
                    ),
                  ),
              ],
            ),
          ),
          if (returnProducts.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ReturnSection(
              products: returnProducts,
              quantities: _returnQuantities,
              onChanged: (product, value) {
                setState(() {
                  final id = _int(product['id']);
                  _returnQuantities[id] = value;
                  if (_returnKind(product) == _ReturnKind.damagedGallon) {
                    _quantities[id] = value;
                  }
                  if (_returnKind(product) == _ReturnKind.transporter) {
                    _quantities[id] = value;
                    Map<String, dynamic>? bottles;
                    for (final candidate in returnProducts) {
                      if (_returnKind(candidate) == _ReturnKind.smallBottle) {
                        bottles = candidate;
                        break;
                      }
                    }
                    if (bottles != null) {
                      _returnQuantities[_int(bottles['id'])] = value * 24;
                    }
                  }
                  Map<String, dynamic>? transporter;
                  Map<String, dynamic>? bottles;
                  Map<String, dynamic>? deposit;
                  for (final candidate in allReturnProducts) {
                    switch (_returnKind(candidate)) {
                      case _ReturnKind.transporter:
                        transporter = candidate;
                      case _ReturnKind.smallBottle:
                        bottles = candidate;
                      case _ReturnKind.smallBottleDeposit:
                        deposit = candidate;
                      default:
                        break;
                    }
                  }
                  if (transporter != null && bottles != null && deposit != null) {
                    final expected = (_returnQuantities[_int(transporter['id'])] ?? 0) * 24;
                    final returned = _returnQuantities[_int(bottles['id'])] ?? 0;
                    _quantities[_int(bottles['id'])] = (expected - returned).clamp(0, expected);
                    _quantities[_int(deposit['id'])] = 0;
                  }
                });
              },
            ),
          ],
          if (rentals.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              title: 'Zwrot sprzętu z dzierżawy',
              child: Column(
                children: [
                  for (var index = 0; index < rentals.length; index++) ...[
                    _RentalReturnRow(
                      item: rentals[index],
                      value: _rentalReturns[_int(rentals[index]['id'])] ?? 0,
                      damaged: _damagedRentalIds.contains(
                        _int(rentals[index]['id']),
                      ),
                      damageController: _damageNotes.putIfAbsent(
                        _int(rentals[index]['id']),
                        TextEditingController.new,
                      ),
                      onChanged: (value) => setState(
                        () => _rentalReturns[_int(rentals[index]['id'])] = value
                            .clamp(0, _int(rentals[index]['quantity'])),
                      ),
                      onDamaged: (value) => _setRentalDamaged(
                        _int(rentals[index]['id']),
                        rentals[index]['product_name']?.toString() ?? 'sprzęt',
                        value,
                      ),
                    ),
                    if (index < rentals.length - 1) const Divider(),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _Section(
            title: 'Rozliczenie',
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'transfer',
                      label: Text('Przelew'),
                      icon: Icon(Icons.account_balance_outlined),
                    ),
                    ButtonSegment(
                      value: 'cash',
                      label: Text('Gotówka'),
                      icon: Icon(Icons.payments_outlined),
                    ),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: (value) =>
                      setState(() => _paymentMethod = value.first),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Całkowita wartość WZ: '
                        '${(recurringInvoice ? total : totalNet).toStringAsFixed(2)} zł '
                        '${recurringInvoice ? 'brutto' : 'netto'}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${(recurringInvoice ? totalNet : total).toStringAsFixed(2)} zł '
                        '${recurringInvoice ? 'netto' : 'brutto'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: WntColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_paymentMethod == 'cash') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cash,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Otrzymana gotówka',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      difference > 0.005
                          ? 'Nadpłata klienta: ${difference.toStringAsFixed(2)} zł'
                          : difference < -0.005
                          ? 'Pozostało do zapłaty: ${(-difference).toStringAsFixed(2)} zł'
                          : 'Rozliczono w całości',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Uwagi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Podpis klienta',
            trailing: _signatureData == null
                ? null
                : const Icon(Icons.check_circle, color: WntColors.success),
            child: Column(
              children: [
                TextField(
                  controller: _signedBy,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: const InputDecoration(
                    labelText: 'Imię i nazwisko odbiorcy',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _captureSignature,
                    icon: Icon(
                      _signatureData == null
                          ? Icons.draw_outlined
                          : Icons.check,
                    ),
                    label: Text(
                      _signatureData == null
                          ? 'Dodaj podpis'
                          : 'Podpis zatwierdzony — zmień',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  double _productPrice(Map<String, dynamic> product) {
    final prices = _map(widget.document['product_prices']);
    return double.tryParse(
          '${prices?['${product['id']}'] ?? product['default_price'] ?? 0}',
        ) ??
        0;
  }

  double _productGrossPrice(Map<String, dynamic> product) {
    final vatRate = double.tryParse('${product['vat_rate'] ?? 23}') ?? 23;
    return _productPrice(product) * (1 + vatRate / 100);
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? WntColors.error : WntColors.success,
      ),
    );
  }
}

enum _ReturnKind { transporter, smallBottle, smallBottleDeposit, gallon, damagedGallon, other }

_ReturnKind _returnKind(Map<String, dynamic> product) {
  final name = _normalizedProductName(product);
  if (name.contains('kauc') && name.contains('but')) {
    return _ReturnKind.smallBottleDeposit;
  }
  if (name.contains('uszk') && name.contains('butl')) {
    return _ReturnKind.damagedGallon;
  }
  if (name.contains('transporter')) return _ReturnKind.transporter;
  if (name.contains('18,9') || name.contains('18.9')) {
    return _ReturnKind.gallon;
  }
  if (name.contains('but')) return _ReturnKind.smallBottle;
  return _ReturnKind.other;
}

bool _isReturnProduct(Map<String, dynamic> product) =>
    product['is_return_container'] == true ||
    _returnKind(product) == _ReturnKind.smallBottle ||
    _returnKind(product) == _ReturnKind.damagedGallon ||
    (_normalizedProductName(product).contains('zwrot') &&
        (_normalizedProductName(product).contains('but') ||
            _normalizedProductName(product).contains('transporter')));

bool _isRentalEquipment(Map<String, dynamic> product) {
  final name = _normalizedProductName(product);
  return name.contains('pompk') ||
      name.contains('stojak') ||
      name.contains('dystrybutor');
}

String _normalizedProductName(Map<String, dynamic> product) =>
    product['name']?.toString().trim().toLowerCase() ?? '';

List<Map<String, dynamic>> _returnProductsForDisplay(
  List<Map<String, dynamic>> products,
) {
  final grouped = <_ReturnKind, Map<String, dynamic>>{};
  final other = <Map<String, dynamic>>[];
  for (final product in products.where(_isReturnProduct)) {
    final kind = _returnKind(product);
    if (kind == _ReturnKind.smallBottleDeposit) continue;
    if (kind == _ReturnKind.other) {
      other.add(product);
      continue;
    }
    final current = grouped[kind];
    if (current == null ||
        (!_normalizedProductName(current).contains('wysowianka') &&
            _normalizedProductName(product).contains('wysowianka'))) {
      grouped[kind] = product;
    }
  }
  return [...grouped.values, ...other];
}

class _ReturnSection extends StatelessWidget {
  const _ReturnSection({
    required this.products,
    required this.quantities,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> products;
  final Map<int, int> quantities;
  final void Function(Map<String, dynamic> product, int value) onChanged;

  @override
  Widget build(BuildContext context) {
    final ordered = [...products]
      ..sort(
        (left, right) =>
            _returnKind(left).index.compareTo(_returnKind(right).index),
      );
    return _Section(
      title: 'Zwrot opakowań',
      child: Column(
        children: [
          for (var index = 0; index < ordered.length; index++) ...[
            _ReturnRow(
              product: ordered[index],
              value: quantities[_int(ordered[index]['id'])] ?? 0,
              onChanged: (value) => onChanged(ordered[index], value),
            ),
            if (index < ordered.length - 1) const Divider(),
          ],
          const SizedBox(height: 4),
          Text(
            '1 transporter ustawia 24 butelki. Liczbę butelek można zmniejszyć, jeśli części brakuje.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: WntColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ReturnRow extends StatelessWidget {
  const _ReturnRow({
    required this.product,
    required this.value,
    required this.onChanged,
  });

  final Map<String, dynamic> product;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = switch (_returnKind(product)) {
      _ReturnKind.transporter => 'Transportery',
      _ReturnKind.smallBottle => 'Butelki 0,3 l',
      _ReturnKind.smallBottleDeposit => 'Kaucja za brakujące butelki',
      _ReturnKind.gallon => 'Butle 18,9 l',
      _ReturnKind.damagedGallon => 'Uszkodzone butle 18,9 l',
      _ReturnKind.other => product['name']?.toString() ?? 'Zwrot',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                if (label != product['name'])
                  Text(
                    product['name']?.toString() ?? '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: WntColors.muted),
                  ),
              ],
            ),
          ),
          QuantityStepper(value: value, onChanged: onChanged, compact: true),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        const Divider(),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ],
    ),
  );
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.value,
    required this.netUnitPrice,
    required this.recurringInvoice,
    required this.onChanged,
  });
  final Map<String, dynamic> product;
  final int value;
  final double netUnitPrice;
  final bool recurringInvoice;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final vat = double.tryParse('${product['vat_rate'] ?? 23}') ?? 23;
    final grossUnitPrice = netUnitPrice * (1 + vat / 100);
    final primaryUnitPrice = recurringInvoice ? grossUnitPrice : netUnitPrice;
    final secondaryUnitPrice = recurringInvoice ? netUnitPrice : grossUnitPrice;
    final primaryLabel = recurringInvoice ? 'brutto' : 'netto';
    final secondaryLabel = recurringInvoice ? 'netto' : 'brutto';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                product['name']?.toString() ?? 'Produkt',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                '${primaryUnitPrice.toStringAsFixed(2)} zł $primaryLabel',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${secondaryUnitPrice.toStringAsFixed(2)} zł $secondaryLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WntColors.muted,
                ),
              ),
              if (value > 0)
                Text(
                  'Razem: ${(primaryUnitPrice * value).toStringAsFixed(2)} zł $primaryLabel'
                  '  ·  ${(secondaryUnitPrice * value).toStringAsFixed(2)} zł $secondaryLabel',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          QuantityStepper(value: value, onChanged: onChanged, compact: true),
        ],
      ),
    );
  }
}

class _RentalReturnRow extends StatelessWidget {
  const _RentalReturnRow({
    required this.item,
    required this.value,
    required this.damaged,
    required this.damageController,
    required this.onChanged,
    required this.onDamaged,
  });
  final Map<String, dynamic> item;
  final int value;
  final bool damaged;
  final TextEditingController damageController;
  final ValueChanged<int> onChanged;
  final ValueChanged<bool> onDamaged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${item['product_name']} · u klienta: ${item['quantity']} szt.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            QuantityStepper(value: value, onChanged: onChanged, compact: true),
          ],
        ),
        if (value > 0)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Sprzęt uszkodzony'),
            value: damaged,
            onChanged: onDamaged,
          ),
        if (value > 0 && damaged)
          TextField(
            controller: damageController,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Opis uszkodzenia'),
          ),
      ],
    ),
  );
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);
  final List<Offset?> points;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final line = Paint()
      ..color = WntColors.ink
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      if (current != null && next != null) canvas.drawLine(current, next, line);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = WntColors.inputLine,
    );
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];
Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : null;
Set<int> _intSet(dynamic value) =>
    value is List ? value.map(_int).toSet() : <int>{};
int _int(dynamic value) => int.tryParse('$value') ?? 0;
