import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/client_item.dart';

class ClientRepository {
  ClientRepository(this._client);

  final SupabaseClient _client;

  void _log(String message, [Object? error, StackTrace? stack]) {
    debugPrint('[Clients] $message${error == null ? '' : ' | $error'}');
    if (error is PostgrestException) {
      debugPrint(
        '[Clients] postgrest code=${error.code} details=${error.details} hint=${error.hint}',
      );
    }
    if (stack != null) {
      debugPrint('[Clients] $stack');
    }
  }

  Future<List<ClientItem>> fetchAll() async {
    _log('fetchAll start');
    try {
      final rows = await _client
          .from('clients')
          .select()
          .order('name', ascending: true);
      final items = (rows as List)
          .map((e) => ClientItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _log('fetchAll ok count=${items.length}');
      return items;
    } catch (e, stack) {
      _log('fetchAll failed', e, stack);
      rethrow;
    }
  }

  Future<ClientItem> create({
    required String name,
    required String createdBy,
    String? company,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final item = ClientItem(
      id: '',
      name: name,
      company: company,
      email: email,
      phone: phone,
      notes: notes,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    final payload = item.toInsertJson(createdBy: createdBy);
    _log('create payload=$payload');
    try {
      final row = await _client
          .from('clients')
          .insert(payload)
          .select()
          .single();
      final created = ClientItem.fromJson(row);
      _log('create ok id=${created.id}');
      return created;
    } catch (e, stack) {
      _log('create failed', e, stack);
      rethrow;
    }
  }

  Future<ClientItem> update(ClientItem item) async {
    final payload = item.toUpdateJson();
    _log('update id=${item.id} payload=$payload');
    try {
      final row = await _client
          .from('clients')
          .update(payload)
          .eq('id', item.id)
          .select()
          .single();
      final updated = ClientItem.fromJson(row);
      _log('update ok id=${updated.id}');
      return updated;
    } catch (e, stack) {
      _log('update failed', e, stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    _log('delete id=$id');
    try {
      await _client.from('clients').delete().eq('id', id);
      _log('delete ok id=$id');
    } catch (e, stack) {
      _log('delete failed', e, stack);
      rethrow;
    }
  }
}
