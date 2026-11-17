import 'enums.dart';
import 'profile.dart';

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.txnDate,
    required this.createdBy,
    required this.createdAt,
    this.note,
    this.receiptUrl,
    this.projectId,
    this.isEmployeeExpense = false,
    this.employeeExpenseSettled = false,
    this.spentBy,
    this.creator,
    this.spender,
  });

  final String id;
  final TxnType type;
  final TxnCategory category;
  final double amount;
  final DateTime txnDate;
  final String? note;
  final String? receiptUrl;
  final String? projectId;
  final bool isEmployeeExpense;
  final bool employeeExpenseSettled;
  final String? spentBy;
  final String createdBy;
  final DateTime createdAt;
  final Profile? creator;
  final Profile? spender;

  String get creatorName => creator?.name ?? 'Unknown';

  String get spenderName =>
      spender?.name ?? creatorName;

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    Profile? creator;
    final rawCreator = json['profiles'] ?? json['creator'];
    if (rawCreator is Map<String, dynamic>) {
      creator = Profile.fromJson(rawCreator);
    }

    Profile? spender;
    final rawSpender = json['spent_by_profile'] ?? json['spender'];
    if (rawSpender is Map<String, dynamic>) {
      spender = Profile.fromJson(rawSpender);
    }

    return TransactionItem(
      id: json['id'] as String,
      type: TxnType.fromString(json['type'] as String),
      category: TxnCategory.fromString(json['category'] as String),
      amount: (json['amount'] as num).toDouble(),
      txnDate: DateTime.parse(json['txn_date'] as String),
      note: json['note'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      projectId: json['project_id'] as String?,
      isEmployeeExpense: json['is_employee_expense'] as bool? ?? false,
      employeeExpenseSettled: json['employee_expense_settled'] as bool? ?? false,
      spentBy: json['spent_by'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      creator: creator,
      spender: spender,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'type': type.value,
        'category': category.value,
        'amount': amount,
        'txn_date': txnDate.toIso8601String().split('T').first,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (receiptUrl != null && receiptUrl!.isNotEmpty)
          'receipt_url': receiptUrl,
        if (projectId != null) 'project_id': projectId,
        'is_employee_expense': isEmployeeExpense,
        'employee_expense_settled':
            isEmployeeExpense ? employeeExpenseSettled : false,
        if (isEmployeeExpense && spentBy != null) 'spent_by': spentBy,
        if (!isEmployeeExpense) 'spent_by': null,
        'created_by': createdBy,
      };

  TransactionItem copyWith({
    bool? isEmployeeExpense,
    bool? employeeExpenseSettled,
    String? spentBy,
    bool clearSpentBy = false,
    Profile? spender,
  }) {
    return TransactionItem(
      id: id,
      type: type,
      category: category,
      amount: amount,
      txnDate: txnDate,
      note: note,
      receiptUrl: receiptUrl,
      projectId: projectId,
      isEmployeeExpense: isEmployeeExpense ?? this.isEmployeeExpense,
      employeeExpenseSettled:
          employeeExpenseSettled ?? this.employeeExpenseSettled,
      spentBy: clearSpentBy ? null : (spentBy ?? this.spentBy),
      createdBy: createdBy,
      createdAt: createdAt,
      creator: creator,
      spender: spender ?? this.spender,
    );
  }
}
