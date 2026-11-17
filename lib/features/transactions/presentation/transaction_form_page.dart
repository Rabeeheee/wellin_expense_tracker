import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/project_item.dart';
import '../../../shared/models/transaction_item.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/design/app_confirm_dialog.dart';
import '../../../shared/widgets/design/premium_select_field.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../projects/bloc/projects_cubit.dart';
import '../../users/bloc/users_cubit.dart';
import '../bloc/transactions_cubit.dart';

class TransactionFormPage extends StatefulWidget {
  const TransactionFormPage({
    super.key,
    this.existing,
    this.initialType,
    this.initialProjectId,
  });

  final TransactionItem? existing;
  final TxnType? initialType;
  final String? initialProjectId;

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  static const _noProject = '';

  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late TxnType _type;
  late TxnCategory _category;
  late DateTime _date;
  bool _saving = false;
  String _projectId = _noProject;
  bool _isEmployeeExpense = false;
  late String _spentBy;

  String? _receiptUrl;
  Uint8List? _receiptBytes;
  String? _receiptContentType;
  bool _clearReceipt = false;

  @override
  void initState() {
    super.initState();
    context.read<ProjectsCubit>().load();
    final profile = context.read<AuthBloc>().state.profile;
    final e = widget.existing;
    _type = e?.type ?? widget.initialType ?? TxnType.expense;
    _date = e?.txnDate ?? DateTime.now();
    _receiptUrl = e?.receiptUrl;
    _projectId = e?.projectId ?? widget.initialProjectId ?? _noProject;
    _isEmployeeExpense = e?.isEmployeeExpense ?? false;
    _spentBy = e?.spentBy ?? profile?.id ?? '';
    if (e != null) {
      _category = e.category;
      _amount.text = e.amount.toStringAsFixed(2);
      _note.text = e.note ?? '';
    } else {
      _category = _defaultCategoryFor(_type, _projectId);
    }
    if (profile?.isSuperAdmin == true) {
      context.read<UsersCubit>().load();
    }
  }

  TxnCategory _defaultCategoryFor(TxnType type, String projectId) {
    if (projectId.isNotEmpty) {
      return type == TxnType.income
          ? TxnCategory.projectIncome
          : TxnCategory.projectExpenses;
    }
    return TxnCategory.forType(type).first;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _hasReceiptPreview =>
      _receiptBytes != null ||
      (!_clearReceipt && _receiptUrl != null && _receiptUrl!.isNotEmpty);

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ??
        (file.path.toLowerCase().endsWith('.png')
            ? 'image/png'
            : file.path.toLowerCase().endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg');
    setState(() {
      _receiptBytes = bytes;
      _receiptContentType = mime;
      _clearReceipt = false;
    });
  }

  void _removeReceipt() {
    setState(() {
      _receiptBytes = null;
      _receiptContentType = null;
      _clearReceipt = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = context.read<AuthBloc>().state.profile;
    if (profile == null) {
      debugPrint('[Txn] save aborted: profile is null');
      return;
    }

    setState(() => _saving = true);
    debugPrint(
      '[Txn] save start edit=${widget.existing != null} user=${profile.id} '
      'type=${_type.value} category=${_category.value} amount=${_amount.text.trim()} '
      'project=${_projectId.isEmpty ? null : _projectId} '
      'hasReceiptBytes=${_receiptBytes != null} clearReceipt=$_clearReceipt',
    );
    try {
      final cubit = context.read<TransactionsCubit>();
      final amount = double.parse(_amount.text.trim());
      String? receiptUrl = _clearReceipt ? null : _receiptUrl;

      if (_receiptBytes != null && _receiptContentType != null) {
        debugPrint('[Txn] uploading receipt...');
        receiptUrl = await cubit.repository.uploadReceipt(
          userId: profile.id,
          bytes: _receiptBytes!,
          contentType: _receiptContentType!,
        );
      }

      final projectId = _projectId.isEmpty ? null : _projectId;
      final spentBy = _isEmployeeExpense
          ? (profile.isSuperAdmin
              ? (_spentBy.isEmpty ? profile.id : _spentBy)
              : profile.id)
          : null;
      if (widget.existing == null) {
        await cubit.add(
          type: _type,
          category: _category,
          amount: amount,
          txnDate: _date,
          createdBy: profile.id,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          receiptUrl: receiptUrl,
          projectId: projectId,
          isEmployeeExpense: _isEmployeeExpense,
          employeeExpenseSettled:
              _isEmployeeExpense && (widget.existing?.employeeExpenseSettled ?? false),
          spentBy: spentBy,
        );
      } else {
        await cubit.updateItem(
          id: widget.existing!.id,
          type: _type,
          category: _category,
          amount: amount,
          txnDate: _date,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          receiptUrl: receiptUrl,
          clearReceipt: _clearReceipt && _receiptBytes == null,
          projectId: projectId,
          clearProject: projectId == null,
          isEmployeeExpense: _isEmployeeExpense,
          employeeExpenseSettled:
              _isEmployeeExpense && widget.existing!.employeeExpenseSettled,
          spentBy: spentBy,
        );
      }
      debugPrint('[Txn] save ok');
      if (!mounted) return;
      context.pop();
    } catch (e, stack) {
      debugPrint('[Txn] save failed type=${e.runtimeType} error=$e');
      debugPrint('[Txn] $stack');
      if (e is PostgrestException) {
        debugPrint(
          '[Txn] postgrest code=${e.code} details=${e.details} hint=${e.hint}',
        );
      }
      if (e is StorageException) {
        debugPrint(
          '[Txn] storage status=${e.statusCode} error=${e.error} message=${e.message}',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Expense?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      tone: AppConfirmTone.danger,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<TransactionsCubit>().delete(widget.existing!.id);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  List<ProjectItem> _projectOptions(List<ProjectItem> all) {
    return all
        .where(
          (p) =>
              p.status == ProjectStatus.active ||
              p.status == ProjectStatus.upcoming ||
              p.id == _projectId,
        )
        .toList();
  }

  List<Profile> _spentByOptions(List<Profile> active, Profile? self) {
    final map = <String, Profile>{
      for (final u in active) u.id: u,
    };
    if (self != null) map.putIfAbsent(self.id, () => self);
    final existingId = widget.existing?.spentBy;
    final existingSpender = widget.existing?.spender;
    if (existingId != null && existingSpender != null) {
      map.putIfAbsent(existingId, () => existingSpender);
    }
    final list = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final profile = context.watch<AuthBloc>().state.profile;
    final categories = TxnCategory.forType(_type);
    final projects = _projectOptions(context.watch<ProjectsCubit>().state.items);
    final users = context.watch<UsersCubit>().state.users
        .where((u) => u.status == UserStatus.active)
        .toList();
    final existing = widget.existing;
    final canDelete = existing != null &&
        (existing.createdBy == profile?.id || profile?.isSuperAdmin == true);
    final showSpentBy = _isEmployeeExpense && profile?.isSuperAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: WellinAppBarTitle(
          title: widget.existing == null
              ? (_type == TxnType.income ? 'Add Income' : 'Add Expense')
              : (_type == TxnType.income ? 'Edit Income' : 'Edit Expense'),
        ),
        actions: [
          if (canDelete)
            IconButton(
              onPressed: _delete,
              tooltip: 'Delete',
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.expense,
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Added as: ${profile?.name ?? 'You'}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TxnType>(
                segments: const [
                  ButtonSegment(
                    value: TxnType.expense,
                    label: Text('Expense'),
                  ),
                  ButtonSegment(
                    value: TxnType.income,
                    label: Text('Income'),
                  ),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  setState(() {
                    _type = s.first;
                    _category = _defaultCategoryFor(_type, _projectId);
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            PremiumSelectField<String>(
              label: 'Project (optional)',
              value: _projectId,
              options: [
                const PremiumSelectOption(value: _noProject, label: 'No Project'),
                ...projects.map(
                  (p) => PremiumSelectOption(
                    value: p.id,
                    label: '${p.title} · ${p.clientName}',
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _projectId = v;
                  _category = _defaultCategoryFor(_type, _projectId);
                });
              },
            ),
            const SizedBox(height: 12),
            PremiumSelectField<TxnCategory>(
              label: 'Category',
              value: categories.contains(_category)
                  ? _category
                  : categories.first,
              options: categories
                  .map(
                    (c) => PremiumSelectOption(value: c, label: c.label),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(formatDate(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextFormField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Employee Expense'),
              subtitle: const Text(
                'Track for reimbursement (transport, petrol, etc.)',
              ),
              value: _isEmployeeExpense,
              onChanged: (v) {
                setState(() {
                  _isEmployeeExpense = v;
                  if (v && _spentBy.isEmpty) {
                    _spentBy = profile?.id ?? '';
                  }
                });
              },
            ),
            if (showSpentBy) ...[
              const SizedBox(height: 4),
              PremiumSelectField<String>(
                label: 'Spent By',
                value: _spentByOptions(users, profile).any((u) => u.id == _spentBy)
                    ? _spentBy
                    : (profile?.id ?? _spentBy),
                options: _spentByOptions(users, profile)
                    .map(
                      (u) => PremiumSelectOption(
                        value: u.id,
                        label: u.name,
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _spentBy = v),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Receipt (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (_hasReceiptPreview)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: _receiptBytes != null
                          ? Image.memory(_receiptBytes!, fit: BoxFit.cover)
                          : Image.network(
                              _receiptUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppColors.surface,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: AppColors.surface,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Remove Receipt',
                        onPressed: _removeReceipt,
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppColors.expense,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickReceipt,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Attach Receipt'),
              ),
            if (_hasReceiptPreview) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _pickReceipt,
                child: const Text('Replace Receipt'),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.existing == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }
}
