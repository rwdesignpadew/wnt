bool rentalProductRequiresSanitization(Object? rawName) {
  final name = '$rawName'.trim().toLowerCase();

  return name.contains('dystrybutor') ||
      (name.contains('mis') && name.contains('ceramiczn'));
}
