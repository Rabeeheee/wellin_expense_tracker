import 'client_item.dart';
import 'enums.dart';

class ProjectItem {
  const ProjectItem({
    required this.id,
    required this.clientId,
    required this.title,
    required this.status,
    required this.contractValue,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.startDate,
    this.dueDate,
    this.client,
    this.received = 0,
    this.spent = 0,
  });

  final String id;
  final String clientId;
  final String title;
  final String? description;
  final ProjectStatus status;
  final double contractValue;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String createdBy;
  final DateTime createdAt;
  final ClientItem? client;
  final double received;
  final double spent;

  String get clientName => client?.name ?? 'Unknown Client';

  double get pending {
    final value = contractValue - received;
    return value < 0 ? 0 : value;
  }

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    ClientItem? client;
    final rawClient = json['clients'] ?? json['client'];
    if (rawClient is Map<String, dynamic>) {
      client = ClientItem.fromJson(rawClient);
    }

    return ProjectItem(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: ProjectStatus.fromString(json['status'] as String),
      contractValue: (json['contract_value'] as num?)?.toDouble() ?? 0,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      client: client,
      received: (json['received'] as num?)?.toDouble() ?? 0,
      spent: (json['spent'] as num?)?.toDouble() ?? 0,
    );
  }

  ProjectItem copyWithTotals({double? received, double? spent}) {
    return ProjectItem(
      id: id,
      clientId: clientId,
      title: title,
      description: description,
      status: status,
      contractValue: contractValue,
      startDate: startDate,
      dueDate: dueDate,
      createdBy: createdBy,
      createdAt: createdAt,
      client: client,
      received: received ?? this.received,
      spent: spent ?? this.spent,
    );
  }

  Map<String, dynamic> toInsertJson({required String createdBy}) => {
        'client_id': clientId,
        'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'status': status.value,
        'contract_value': contractValue,
        if (startDate != null)
          'start_date': startDate!.toIso8601String().split('T').first,
        if (dueDate != null)
          'due_date': dueDate!.toIso8601String().split('T').first,
        'created_by': createdBy,
      };

  Map<String, dynamic> toUpdateJson() => {
        'client_id': clientId,
        'title': title,
        'description': description,
        'status': status.value,
        'contract_value': contractValue,
        'start_date': startDate?.toIso8601String().split('T').first,
        'due_date': dueDate?.toIso8601String().split('T').first,
      };
}
