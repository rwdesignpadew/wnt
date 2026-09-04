String normalizedDriverProductName(Object? value) =>
    value?.toString().trim().toLowerCase() ?? '';

bool isDriverRentalEquipment(Map<String, dynamic> item) {
  final name = normalizedDriverProductName(
    item['product_name'] ?? item['name'],
  );
  return name.contains('pompk') ||
      name.contains('stojak') ||
      name.contains('dystrybutor');
}

bool isDriverReturnItem(Map<String, dynamic> item) {
  if (item['is_return_container'] == true) return true;

  final name = normalizedDriverProductName(
    item['product_name'] ?? item['name'],
  );

  if (name.contains('transporter wysowianka') ||
      name.contains('transtorter wysowianka') ||
      name.contains('butelka wysowianka 0,3') ||
      name.contains('butelka wysowianka 0.3')) {
    return true;
  }

  if (!name.contains('zwrot')) return false;

  return const [
    'butl',
    'butel',
    'transporter',
    'pojemnik',
    'skrzyn',
    'dystrybutor',
    'stojak',
    'pomp',
    'palet',
  ].any(name.contains);
}
