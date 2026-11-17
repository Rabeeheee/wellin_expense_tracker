import 'enums.dart';
import 'profile.dart';

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.title,
    required this.preset,
    required this.dueDate,
    required this.isRecurringMonthly,
    required this.isDone,
    required this.createdBy,
    required this.createdAt,
    this.amount,
    this.creator,
  });

  final String id;
  final String title;
  final ReminderPreset preset;
  final double? amount;
  final DateTime dueDate;
  final bool isRecurringMonthly;
  final bool isDone;
  final String createdBy;
  final DateTime createdAt;
  final Profile? creator;

  bool get isOverdue => !isDone && dueDate.isBefore(DateTime.now());

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    Profile? creator;
    final rawCreator = json['profiles'] ?? json['creator'];
    if (rawCreator is Map<String, dynamic>) {
      creator = Profile.fromJson(rawCreator);
    }

    return ReminderItem(
      id: json['id'] as String,
      title: json['title'] as String,
      preset: ReminderPreset.fromString(json['preset'] as String? ?? 'custom'),
      amount:
          json['amount'] == null ? null : (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['due_date'] as String).toLocal(),
      isRecurringMonthly: json['is_recurring_monthly'] as bool? ?? false,
      isDone: json['is_done'] as bool? ?? false,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      creator: creator,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'title': title,
        'preset': preset.value,
        if (amount != null) 'amount': amount,
        'due_date': dueDate.toUtc().toIso8601String(),
        'is_recurring_monthly': isRecurringMonthly,
        'is_done': isDone,
        'created_by': createdBy,
      };
}
