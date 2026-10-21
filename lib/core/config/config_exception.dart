/// Thrown when economy.json is malformed or a required field is missing.
class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}
