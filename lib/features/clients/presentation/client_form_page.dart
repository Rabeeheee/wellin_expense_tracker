import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/client_item.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/design/app_confirm_dialog.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/clients_cubit.dart';

class ClientFormPage extends StatefulWidget {
  const ClientFormPage({super.key, this.existing});

  final ClientItem? existing;

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _company.text = e.company ?? '';
      _email.text = e.email ?? '';
      _phone.text = e.phone ?? '';
      _notes.text = e.notes ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _email.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = context.read<AuthBloc>().state.profile;
    if (profile == null) {
      debugPrint('[Clients] save aborted: profile is null');
      return;
    }
    setState(() => _saving = true);
    debugPrint(
      '[Clients] save start edit=${widget.existing != null} '
      'user=${profile.id} name=${_name.text.trim()}',
    );
    try {
      final cubit = context.read<ClientsCubit>();
      final existing = widget.existing;
      if (existing == null) {
        await cubit.create(
          name: _name.text.trim(),
          createdBy: profile.id,
          company: _company.text.trim().isEmpty ? null : _company.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      } else {
        await cubit.update(
          ClientItem(
            id: existing.id,
            name: _name.text.trim(),
            company:
                _company.text.trim().isEmpty ? null : _company.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            createdBy: existing.createdBy,
            createdAt: existing.createdAt,
          ),
        );
      }
      debugPrint('[Clients] save ok');
      if (!mounted) return;
      context.pop();
    } catch (e, stack) {
      debugPrint('[Clients] save failed type=${e.runtimeType} error=$e');
      debugPrint('[Clients] $stack');
      if (e is PostgrestException) {
        debugPrint(
          '[Clients] postgrest code=${e.code} details=${e.details} hint=${e.hint}',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Client?',
      message: 'Projects linked to this client must be removed first.',
      confirmLabel: 'Delete',
      tone: AppConfirmTone.danger,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<ClientsCubit>().delete(existing.id);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: WellinAppBarTitle(title: isEdit ? 'Edit Client' : 'Add Client'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: Icon(Icons.delete_outline, color: AppColors.expense),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  v != null && v.trim().isNotEmpty ? null : 'Enter a name',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _company,
              decoration: const InputDecoration(labelText: 'Company (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const AppLoader.inline(size: 22)
                  : Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
