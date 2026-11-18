import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/project_item.dart';
import '../../../shared/models/transaction_item.dart';

class ProjectRepository {
  ProjectRepository(this._client);

  final SupabaseClient _client;

  static const _select = '*, clients(*)';

  void _log(String message, [Object? error, StackTrace? stack]) {
    debugPrint('[Projects] $message${error == null ? '' : ' | $error'}');
    if (error is PostgrestException) {
      debugPrint(
        '[Projects] postgrest code=${error.code} details=${error.details} hint=${error.hint}',
      );
    }
    if (stack != null) {
      debugPrint('[Projects] $stack');
    }
  }

  Future<List<ProjectItem>> fetchAll({ProjectStatus? status}) async {
    _log('fetchAll start status=${status?.value}');
    try {
      var query = _client.from('projects').select(_select);
      if (status != null) {
        query = query.eq('status', status.value);
      }
      final rows = await query.order('created_at', ascending: false);
      final projects = (rows as List)
          .map((e) => ProjectItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final withTotals = await _withTotals(projects);
      _log('fetchAll ok count=${withTotals.length}');
      return withTotals;
    } catch (e, stack) {
      _log('fetchAll failed', e, stack);
      rethrow;
    }
  }

  Future<ProjectItem?> fetchById(String id) async {
    _log('fetchById id=$id');
    try {
      final row = await _client
          .from('projects')
          .select(_select)
          .eq('id', id)
          .maybeSingle();
      if (row == null) {
        _log('fetchById not found id=$id');
        return null;
      }
      final project = ProjectItem.fromJson(row);
      final withTotals = await _withTotals([project]);
      _log('fetchById ok id=$id');
      return withTotals.first;
    } catch (e, stack) {
      _log('fetchById failed', e, stack);
      rethrow;
    }
  }

  Future<List<TransactionItem>> fetchTransactions(String projectId) async {
    _log('fetchTransactions projectId=$projectId');
    try {
      final rows = await _client
          .from('transactions')
          .select(
            '*, profiles!created_by(id, name, email, role, status, avatar_url, created_at)',
          )
          .eq('project_id', projectId)
          .order('txn_date', ascending: false);
      final items = (rows as List)
          .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _log('fetchTransactions ok count=${items.length}');
      return items;
    } catch (e, stack) {
      _log('fetchTransactions failed', e, stack);
      rethrow;
    }
  }

  Future<ProjectItem> create({
    required String clientId,
    required String title,
    required ProjectStatus status,
    required double contractValue,
    required String createdBy,
    String? description,
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    final item = ProjectItem(
      id: '',
      clientId: clientId,
      title: title,
      description: description,
      status: status,
      contractValue: contractValue,
      startDate: startDate,
      dueDate: dueDate,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    final payload = item.toInsertJson(createdBy: createdBy);
    _log('create payload=$payload');
    try {
      final row = await _client
          .from('projects')
          .insert(payload)
          .select(_select)
          .single();
      final created = ProjectItem.fromJson(row);
      _log('create ok id=${created.id}');
      return created;
    } catch (e, stack) {
      _log('create failed', e, stack);
      rethrow;
    }
  }

  Future<ProjectItem> update(ProjectItem item) async {
    final payload = item.toUpdateJson();
    _log('update id=${item.id} payload=$payload');
    try {
      final row = await _client
          .from('projects')
          .update(payload)
          .eq('id', item.id)
          .select(_select)
          .single();
      final project = ProjectItem.fromJson(row);
      final withTotals = await _withTotals([project]);
      _log('update ok id=${item.id}');
      return withTotals.first;
    } catch (e, stack) {
      _log('update failed', e, stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    _log('delete id=$id');
    try {
      await _client.from('projects').delete().eq('id', id);
      _log('delete ok id=$id');
    } catch (e, stack) {
      _log('delete failed', e, stack);
      rethrow;
    }
  }

  Future<List<ProjectItem>> _withTotals(List<ProjectItem> projects) async {
    if (projects.isEmpty) return projects;
    final ids = projects.map((e) => e.id).toList();
    _log('withTotals ids=$ids');
    try {
      final rows = await _client
          .from('transactions')
          .select(
            'project_id, type, amount, is_employee_expense, '
            'employee_expense_settled, employee_charge_company',
          )
          .inFilter('project_id', ids);

      final received = <String, double>{};
      final spent = <String, double>{};
      for (final raw in rows as List) {
        final map = raw as Map<String, dynamic>;
        final projectId = map['project_id'] as String?;
        if (projectId == null) continue;
        final isEmployee = map['is_employee_expense'] as bool? ?? false;
        final settled = map['employee_expense_settled'] as bool? ?? false;
        final chargeCompany = map['employee_charge_company'] as bool? ?? false;
        if (isEmployee && !(settled && chargeCompany)) continue;
        final amount = (map['amount'] as num).toDouble();
        final type = map['type'] as String;
        if (type == TxnType.income.value) {
          received[projectId] = (received[projectId] ?? 0) + amount;
        } else {
          spent[projectId] = (spent[projectId] ?? 0) + amount;
        }
      }

      return projects
          .map(
            (p) => p.copyWithTotals(
              received: received[p.id] ?? 0,
              spent: spent[p.id] ?? 0,
            ),
          )
          .toList();
    } catch (e, stack) {
      _log('withTotals failed (returning zero totals)', e, stack);
      return projects;
    }
  }
}
