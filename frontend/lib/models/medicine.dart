/// Formes galéniques (enum MedicineForm côté API).
const medicineForms = <String, String>{
  'TABLET': 'Comprimé',
  'CAPSULE': 'Gélule',
  'SYRUP': 'Sirop',
  'INJECTION': 'Injection',
  'CREAM': 'Crème',
  'DROPS': 'Gouttes',
  'INHALER': 'Inhalateur',
  'SACHET': 'Sachet',
  'SUPPOSITORY': 'Suppositoire',
  'OTHER': 'Autre',
};

/// Entrée du référentiel central des médicaments.
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.activeIngredient,
    required this.form,
    required this.strength,
    this.manufacturer,
  });

  final int id;
  final String name;
  final String activeIngredient;
  final String form;
  final String strength;
  final String? manufacturer;

  String get formLabel => medicineForms[form] ?? form;

  /// Ex : "Paracétamol 500 mg — Comprimé"
  String get displayName => '$name $strength — $formLabel';

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as int,
        name: json['name'] as String,
        activeIngredient: json['activeIngredient'] as String,
        form: json['form'] as String,
        strength: json['strength'] as String,
        manufacturer: json['manufacturer'] as String?,
      );

  Map<String, dynamic> toRequest() => {
        'name': name,
        'activeIngredient': activeIngredient,
        'form': form,
        'strength': strength,
        'manufacturer': manufacturer,
      };
}
