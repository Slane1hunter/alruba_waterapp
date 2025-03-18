class Location {
  final String id;
  final String name;

  Location({required this.id, required this.name});

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}
