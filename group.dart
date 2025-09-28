class Group {
  final int? id;
  final String name;
  final String? description;

  const Group({
    this.id,
    required this.name,
    this.description,
  });

  factory Group.fromMap(Map<String, dynamic> data) {
    return Group(
      id: data['id'],
      name: data['name'],
      description: data['description'],
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description ?? '',
    };
  }

  // 🔧 BU YERNI QO‘SHING:
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Group &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}
