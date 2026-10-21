/// A terminal the player owns in a city.
class Terminal {
  Terminal({
    required this.id,
    required this.location,
    required DateTime purchasedAt,
  }) : purchasedAt = purchasedAt.toUtc();

  final String id;

  /// City name, as it appears in the route endpoints in the config.
  final String location;
  final DateTime purchasedAt;

  @override
  bool operator ==(Object other) =>
      other is Terminal &&
      other.id == id &&
      other.location == location &&
      other.purchasedAt == purchasedAt;

  @override
  int get hashCode => Object.hash(id, location, purchasedAt);

  @override
  String toString() => 'Terminal($id, $location)';
}
