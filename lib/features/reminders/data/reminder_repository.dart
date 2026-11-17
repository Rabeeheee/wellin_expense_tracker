import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/reminder_item.dart';

class ReminderRepository {
  ReminderRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, profiles!created_by(id, name, email, role, status, avatar_url, created_at)';

  Future<List<ReminderItem>> fetchAll({bool includeDone = false}) async {
    var query = _client.from('reminders').select(_select);
    if (!includeDone) {
      query = query.eq('is_done', false);
    }
    final rows = await query.order('due_date');
    return (rows as List)
        .map((e) => ReminderItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReminderItem> create({
    required String title,
    required ReminderPreset preset,
    required DateTime dueDate,
    required String createdBy,
    double? amount,
    bool isRecurringMonthly = false,
  }) async {
    final payload = {
      'title': title,
      'preset': preset.value,
      'amount': ?amount,
      'due_date': dueDate.toUtc().toIso8601String(),
      'is_recurring_monthly': isRecurringMonthly,
      'is_done': false,
      'created_by': createdBy,
    };
    final row =
        await _client.from('reminders').insert(payload).select(_select).single();
    return ReminderItem.fromJson(row);
  }

  Future<void> markDone(ReminderItem item) async {
    await _client.from('reminders').update({'is_done': true}).eq('id', item.id);

    if (item.isRecurringMonthly) {
      final next = DateTime(
        item.dueDate.year,
        item.dueDate.month + 1,
        item.dueDate.day,
        item.dueDate.hour,
        item.dueDate.minute,
      );
      await create(
        title: item.title,
        preset: item.preset,
        dueDate: next,
        createdBy: item.createdBy,
        amount: item.amount,
        isRecurringMonthly: true,
      );
    }
  }

  Future<void> delete(String id) async {
    await _client.from('reminders').delete().eq('id', id);
  }
}
