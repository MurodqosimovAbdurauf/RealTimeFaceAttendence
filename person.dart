import 'dart:typed_data';

class Person {
  final int? id;
  final String name;
  final String surname;
  final String contact;
  final Uint8List faceJpg;
  final Uint8List templates;
  final int groupId;

  const Person({
    this.id,
    required this.name,
    required this.surname,
    required this.contact,
    required this.faceJpg,
    required this.templates,
    required this.groupId,
  });

  factory Person.fromMap(Map<String, dynamic> data) {
    return Person(
      id: data['id'],
      name: data['name'],
      surname: data['surname'],
      contact: data['contact'],
      faceJpg: data['faceJpg'],
      templates: data['templates'],
      groupId: data['groupId'],
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'contact': contact,
      'faceJpg': faceJpg,
      'templates': templates,
      'groupId': groupId,
    };
  }

  /// ✅ copyWith metodi: faqat o'zgartirmoqchi bo'lgan fieldlarni kiriting
  Person copyWith({
    int? id,
    String? name,
    String? surname,
    String? contact,
    Uint8List? faceJpg,
    Uint8List? templates,
    int? groupId,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      contact: contact ?? this.contact,
      faceJpg: faceJpg ?? this.faceJpg,
      templates: templates ?? this.templates,
      groupId: groupId ?? this.groupId,
    );
  }
}
