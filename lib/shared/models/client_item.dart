class ClientItem {
  const ClientItem({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.company,
    this.email,
    this.phone,
    this.notes,
  });

  final String id;
  final String name;
  final String? company;
  final String? email;
  final String? phone;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;

  factory ClientItem.fromJson(Map<String, dynamic> json) {
    return ClientItem(
      id: json['id'] as String,
      name: json['name'] as String,
      company: json['company'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toInsertJson({required String createdBy}) => {
        'name': name,
        if (company != null && company!.isNotEmpty) 'company': company,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'created_by': createdBy,
      };

  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'company': company,
        'email': email,
        'phone': phone,
        'notes': notes,
      };
}
