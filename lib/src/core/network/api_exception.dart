class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.errors = const {},
    this.payload = const {},
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>> errors;
  final Map<String, dynamic> payload;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
