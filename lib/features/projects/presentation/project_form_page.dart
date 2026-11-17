import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/project_item.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/design/app_confirm_dialog.dart';
import '../../../shared/widgets/design/premium_select_field.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../clients/bloc/clients_cubit.dart';
import '../bloc/projects_cubit.dart';

class ProjectFormPage extends StatefulWidget {
  const ProjectFormPage({super.key, this.existing});

  final ProjectItem? existing;

  @override
  State<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends State<ProjectFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _contract = TextEditingController();
  String? _clientId;
  ProjectStatus _status = ProjectStatus.upcoming;
  DateTime? _startDate;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    context.read<ClientsCubit>().load();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _description.text = e.description ?? '';
      _contract.text = e.contractValue.toStringAsFixed(2);
      _clientId = e.clientId;
      _startDate = e.startDate;
      _dueDate = e.dueDate;
      _status = _statusFromDates(_startDate, _dueDate) ?? e.status;
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Upcoming = before start · Active = started and not past due · Completed = after due.
  ProjectStatus? _statusFromDates(DateTime? start, DateTime? due) {
    if (start == null && due == null) return null;
    final today = _dateOnly(DateTime.now());
    final startDay = start == null ? null : _dateOnly(start);
    final dueDay = due == null ? null : _dateOnly(due);

    if (dueDay != null && today.isAfter(dueDay)) {
      return ProjectStatus.completed;
    }
    if (startDay != null && today.isBefore(startDay)) {
      return ProjectStatus.upcoming;
    }
    return ProjectStatus.active;
  }

  void _applyDates({DateTime? start, DateTime? due, bool clearStart = false, bool clearDue = false}) {
    final nextStart = clearStart ? null : (start ?? _startDate);
    final nextDue = clearDue ? null : (due ?? _dueDate);
    final derived = _statusFromDates(nextStart, nextDue);
    setState(() {
      _startDate = nextStart;
      _dueDate = nextDue;
      if (derived != null) _status = derived;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _contract.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      debugPrint('[Projects] save aborted: clientId is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a client')),
      );
      return;
    }
    final profile = context.read<AuthBloc>().state.profile;
    if (profile == null) {
      debugPrint('[Projects] save aborted: profile is null');
      return;
    }
    setState(() => _saving = true);
    debugPrint(
      '[Projects] save start edit=${widget.existing != null} '
      'user=${profile.id} client=$_clientId title=${_title.text.trim()} '
      'status=${_status.value} contract=${_contract.text.trim()}',
    );
    try {
      final cubit = context.read<ProjectsCubit>();
      final value = double.parse(_contract.text.trim());
      final existing = widget.existing;
      if (existing == null) {
        await cubit.create(
          clientId: _clientId!,
          title: _title.text.trim(),
          status: _status,
          contractValue: value,
          createdBy: profile.id,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          startDate: _startDate,
          dueDate: _dueDate,
        );
      } else {
        await cubit.update(
          ProjectItem(
            id: existing.id,
            clientId: _clientId!,
            title: _title.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            status: _status,
            contractValue: value,
            startDate: _startDate,
            dueDate: _dueDate,
            createdBy: existing.createdBy,
            createdAt: existing.createdAt,
            client: existing.client,
            received: existing.received,
            spent: existing.spent,
          ),
        );
      }
      debugPrint('[Projects] save ok');
      if (!mounted) return;
      context.pop();
    } catch (e, stack) {
      debugPrint('[Projects] save failed type=${e.runtimeType} error=$e');
      debugPrint('[Projects] $stack');
      if (e is PostgrestException) {
        debugPrint(
          '[Projects] postgrest code=${e.code} details=${e.details} hint=${e.hint}',
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
      title: 'Delete Project?',
      message: 'Linked expenses stay, but lose the project link.',
      confirmLabel: 'Delete',
      tone: AppConfirmTone.danger,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<ProjectsCubit>().delete(existing.id);
      if (!mounted) return;
      context.pop();
      if (context.canPop()) context.pop();
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
    final clients = context.watch<ClientsCubit>().state.items;

    return Scaffold(
      appBar: AppBar(
        title:
            WellinAppBarTitle(title: isEdit ? 'Edit Project' : 'Add Project'),
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
            if (clients.isEmpty)
              PremiumHint(
                message: 'Add a client first, then create a project.',
                actionLabel: 'Add Client',
                onAction: () => context.push('/clients/new'),
              )
            else
              PremiumSelectField<String>(
                label: 'Client',
                value: _clientId ?? clients.first.id,
                options: clients
                    .map(
                      (c) => PremiumSelectOption(
                        value: c.id,
                        label: c.company == null || c.company!.isEmpty
                            ? c.name
                            : '${c.name} · ${c.company}',
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _clientId = v),
              ),
            if (_clientId == null && clients.isNotEmpty) ...[
              // Ensure default selected after first build.
              Builder(
                builder: (context) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _clientId == null && clients.isNotEmpty) {
                      setState(() => _clientId = clients.first.id);
                    }
                  });
                  return const SizedBox.shrink();
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  v != null && v.trim().isNotEmpty ? null : 'Enter a title',
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Date'),
              subtitle: Text(
                _startDate == null ? 'Not set' : formatDate(_startDate!),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_startDate != null)
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: () => _applyDates(clearStart: true),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  const Icon(Icons.calendar_today_outlined),
                ],
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) _applyDates(start: picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due Date'),
              subtitle: Text(
                _dueDate == null ? 'Not set' : formatDate(_dueDate!),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_dueDate != null)
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: () => _applyDates(clearDue: true),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  const Icon(Icons.event_outlined),
                ],
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? _startDate ?? DateTime.now(),
                  firstDate: _startDate ?? DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) _applyDates(due: picked);
              },
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              child: Text(
                '${_status.label}'
                '${_startDate != null || _dueDate != null ? '  · from dates' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contract,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Contract Value'),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving || clients.isEmpty ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumHint extends StatelessWidget {
  const PremiumHint({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: AppColors.textSecondary)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
