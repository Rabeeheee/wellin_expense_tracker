import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/transaction_item.dart';
import '../../../shared/utils/formatters.dart';

class TransactionRepository {
  TransactionRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  static const _select =
      '*, profiles!created_by(id, name, email, role, status, avatar_url, created_at), '
      'spent_by_profile:profiles!spent_by(id, name, email, role, status, avatar_url, created_at)';

  void _log(String message, [Object? error, StackTrace? stack]) {
    debugPrint('[Txn] $message${error == null ? '' : ' | $error'}');
    if (error is PostgrestException) {
      debugPrint(
        '[Txn] postgrest code=${error.code} details=${error.details} hint=${error.hint}',
      );
    }
    if (error is StorageException) {
      debugPrint(
        '[Txn] storage status=${error.statusCode} error=${error.error} message=${error.message}',
      );
    }
    if (stack != null) {
      debugPrint('[Txn] $stack');
    }
  }

  Future<List<TransactionItem>> fetchMonth({
    required int year,
    required int month,
    TxnType? type,
    String? createdBy,
  }) async {
    final start = monthStart(year, month);
    final end = monthEnd(year, month);
    return fetchRange(
      start: start,
      end: end,
      type: type,
      createdBy: createdBy,
    );
  }

  Future<List<TransactionItem>> fetchYear({
    required int year,
    TxnType? type,
    String? createdBy,
  }) {
    return fetchRange(
      start: yearStart(year),
      end: yearEnd(year),
      type: type,
      createdBy: createdBy,
    );
  }

  Future<List<TransactionItem>> fetchRange({
    required DateTime start,
    required DateTime end,
    TxnType? type,
    String? createdBy,
  }) async {
    _log(
      'fetchRange start=${start.toIso8601String().split('T').first} '
      'end=${end.toIso8601String().split('T').first} type=${type?.value} '
      'createdBy=$createdBy',
    );
    try {
      var query = _client
          .from('transactions')
          .select(_select)
          .gte('txn_date', start.toIso8601String().split('T').first)
          .lte('txn_date', end.toIso8601String().split('T').first);

      if (type != null) {
        query = query.eq('type', type.value);
      }
      if (createdBy != null) {
        query = query.eq('created_by', createdBy);
      }

      final rows = await query.order('txn_date', ascending: false);
      final items = (rows as List)
          .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _log('fetchRange ok count=${items.length}');
      return items;
    } catch (e, stack) {
      _log('fetchRange failed', e, stack);
      rethrow;
    }
  }

  Future<String> uploadReceipt({
    required String userId,
    required List<int> bytes,
    required String contentType,
  }) async {
    final ext = contentType.contains('png')
        ? 'png'
        : contentType.contains('webp')
            ? 'webp'
            : 'jpg';
    final path = '$userId/${_uuid.v4()}.$ext';
    _log('uploadReceipt path=$path bytes=${bytes.length} type=$contentType');
    try {
      await _client.storage.from('receipts').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );
      final publicUrl = _client.storage.from('receipts').getPublicUrl(path);
      final url = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      _log('uploadReceipt ok url=$url');
      return url;
    } catch (e, stack) {
      _log('uploadReceipt failed', e, stack);
      rethrow;
    }
  }

  Future<TransactionItem> create({
    required TxnType type,
    required TxnCategory category,
    required double amount,
    required DateTime txnDate,
    required String createdBy,
    String? note,
    String? receiptUrl,
    String? projectId,
    bool isEmployeeExpense = false,
    bool employeeExpenseSettled = false,
    bool employeeChargeCompany = false,
    String? spentBy,
  }) async {
    final item = TransactionItem(
      id: '',
      type: type,
      category: category,
      amount: amount,
      txnDate: txnDate,
      note: note,
      receiptUrl: receiptUrl,
      projectId: projectId,
      isEmployeeExpense: isEmployeeExpense,
      employeeExpenseSettled: employeeExpenseSettled,
      employeeChargeCompany: employeeChargeCompany,
      spentBy: spentBy,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    final payload = item.toInsertJson();
    _log('create payload=$payload');
    try {
      final row = await _client
          .from('transactions')
          .insert(payload)
          .select(_select)
          .single();
      final created = TransactionItem.fromJson(row);
      _log('create ok id=${created.id}');
      return created;
    } catch (e, stack) {
      _log('create failed', e, stack);
      rethrow;
    }
  }

  Future<TransactionItem> update({
    required String id,
    required TxnType type,
    required TxnCategory category,
    required double amount,
    required DateTime txnDate,
    String? note,
    String? receiptUrl,
    bool clearReceipt = false,
    String? projectId,
    bool clearProject = false,
    bool isEmployeeExpense = false,
    bool employeeExpenseSettled = false,
    bool employeeChargeCompany = false,
    String? spentBy,
  }) async {
    final payload = <String, dynamic>{
      'type': type.value,
      'category': category.value,
      'amount': amount,
      'txn_date': txnDate.toIso8601String().split('T').first,
      'note': note,
      'is_employee_expense': isEmployeeExpense,
      'employee_expense_settled':
          isEmployeeExpense ? employeeExpenseSettled : false,
      'employee_charge_company': isEmployeeExpense &&
              employeeExpenseSettled &&
              employeeChargeCompany
          ? true
          : false,
      'spent_by': isEmployeeExpense ? spentBy : null,
    };
    if (clearReceipt) {
      payload['receipt_url'] = null;
    } else if (receiptUrl != null) {
      payload['receipt_url'] = receiptUrl;
    }
    if (clearProject) {
      payload['project_id'] = null;
    } else if (projectId != null) {
      payload['project_id'] = projectId;
    }

    _log('update id=$id payload=$payload');
    try {
      final row = await _client
          .from('transactions')
          .update(payload)
          .eq('id', id)
          .select(_select)
          .single();
      final updated = TransactionItem.fromJson(row);
      _log('update ok id=$id');
      return updated;
    } catch (e, stack) {
      _log('update failed', e, stack);
      rethrow;
    }
  }

  Future<TransactionItem> setEmployeeExpenseSettled({
    required String id,
    required bool settled,
    bool chargeCompany = false,
  }) async {
    _log(
      'setEmployeeExpenseSettled id=$id settled=$settled '
      'chargeCompany=$chargeCompany',
    );
    try {
      final row = await _client
          .from('transactions')
          .update({
            'employee_expense_settled': settled,
            'employee_charge_company': settled && chargeCompany,
          })
          .eq('id', id)
          .eq('is_employee_expense', true)
          .select(_select)
          .single();
      final updated = TransactionItem.fromJson(row);
      _log('setEmployeeExpenseSettled ok id=$id');
      return updated;
    } catch (e, stack) {
      _log('setEmployeeExpenseSettled failed', e, stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    _log('delete id=$id');
    try {
      await _client.from('transactions').delete().eq('id', id);
      _log('delete ok id=$id');
    } catch (e, stack) {
      _log('delete failed', e, stack);
      rethrow;
    }
  }
}
