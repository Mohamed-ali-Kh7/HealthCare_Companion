class Speciality {
  const Speciality({required this.id, required this.name, this.description});

  final int id;
  final String name;
  final String? description;

  factory Speciality.fromJson(Map<String, dynamic> json) => Speciality(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toRequest() => {'name': name, 'description': description};
}
