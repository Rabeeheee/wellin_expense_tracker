import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/profile.dart';

class UsersRepository {
  UsersRepository(this._client);

  final SupabaseClient _client;

  Future<List<Profile>> fetchAll() async {
    final rows = await _client.from('profiles').select().order('created_at');
    return (rows as List)
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setStatus(String id, UserStatus status) async {
    await _client.from('profiles').update({'status': status.value}).eq('id', id);
  }

  Future<void> setRole(String id, UserRole role) async {
    await _client.from('profiles').update({'role': role.value}).eq('id', id);
  }

  Future<void> approve(String id) async {
    await setStatus(id, UserStatus.active);
  }
}
