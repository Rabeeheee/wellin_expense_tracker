import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/reminder_item.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/design/app_confirm_dialog.dart';
import '../../../shared/widgets/design/premium_card.dart';
import '../../../shared/widgets/design/premium_select_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/reminders_cubit.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    context.read<RemindersCubit>().load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _showAddSheet() async {
    final profile = context.read<AuthBloc>().state.profile;
    if (profile == null) return;

    final customCtrl = TextEditingController();
    ReminderPreset preset = ReminderPreset.electricity;
    var due = DateTime.now().add(const Duration(days: 1));
    due = DateTime(due.year, due.month, due.day, 9, 0);
    var recurring = false;
    final amountCtrl = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.borderStrong,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'New Reminder',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PremiumSelectField<ReminderPreset>(
                      label: 'Type',
                      value: preset,
                      options: ReminderPreset.values
                          .map(
                            (p) => PremiumSelectOption(
                              value: p,
                              label: p.label,
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModal(() => preset = v),
                    ),
                    if (preset == ReminderPreset.custom) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: customCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'What Is This For?',
                          hintText: 'e.g. Internet bill, Team lunch',
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount (optional)',
                      ),
                    ),
                    SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                      title: Text('Due Date'),
                      subtitle: Text(formatDate(due)),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: AppColors.textTertiary,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: due,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModal(() {
                            due = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              due.hour,
                              due.minute,
                            );
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.schedule_outlined,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                      title: Text('Time'),
                      subtitle: Text(formatTime(due)),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: AppColors.textTertiary,
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(due),
                        );
                        if (picked != null) {
                          setModal(() {
                            due = DateTime(
                              due.year,
                              due.month,
                              due.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        }
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Repeat Monthly'),
                      value: recurring,
                      onChanged: (v) => setModal(() => recurring = v),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        if (preset == ReminderPreset.custom &&
                            customCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please describe what this reminder is for',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context, true);
                      },
                      child: const Text('Save Reminder'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      final title = preset == ReminderPreset.custom
          ? customCtrl.text.trim()
          : preset.label;
      await context.read<RemindersCubit>().add(
            title: title,
            preset: preset,
            dueDate: due,
            createdBy: profile.id,
            amount: double.tryParse(amountCtrl.text.trim()),
            recurring: recurring,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Scaffold(
      appBar: AppBar(
        title: WellinAppBarTitle(title: 'Reminders'),
        actions: [
          IconButton(
            onPressed: _showAddSheet,
            icon: Icon(Icons.add),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textTertiary,
          tabs: const [
            Tab(text: 'Due'),
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: BlocBuilder<RemindersCubit, RemindersState>(
        builder: (context, state) {
          if (state.loading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = context.watch<AuthBloc>().state.profile;

          return TabBarView(
            controller: _tabs,
            children: [
              _ReminderList(
                items: state.due,
                emptyMessage: 'Nothing Overdue Right Now.',
                onRefresh: () => context.read<RemindersCubit>().load(),
                onAdd: _showAddSheet,
                allowComplete: true,
                accentOverdue: true,
                myId: profile?.id,
                isSuperAdmin: profile?.isSuperAdmin == true,
              ),
              _ReminderList(
                items: state.pending,
                emptyMessage: 'No Upcoming Reminders.',
                emptyActionLabel: 'Add Reminder',
                onRefresh: () => context.read<RemindersCubit>().load(),
                onAdd: _showAddSheet,
                allowComplete: true,
                myId: profile?.id,
                isSuperAdmin: profile?.isSuperAdmin == true,
              ),
              _ReminderList(
                items: state.completed,
                emptyMessage: 'No Completed Reminders Yet.',
                onRefresh: () => context.read<RemindersCubit>().load(),
                onAdd: _showAddSheet,
                allowComplete: false,
                myId: profile?.id,
                isSuperAdmin: profile?.isSuperAdmin == true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReminderList extends StatelessWidget {
  const _ReminderList({
    required this.items,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onAdd,
    required this.allowComplete,
    required this.myId,
    required this.isSuperAdmin,
    this.emptyActionLabel,
    this.accentOverdue = false,
  });

  final List<ReminderItem> items;
  final String emptyMessage;
  final String? emptyActionLabel;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final bool allowComplete;
  final String? myId;
  final bool isSuperAdmin;
  final bool accentOverdue;

  Future<bool> _confirmDelete(BuildContext context, ReminderItem item) {
    return showAppConfirmDialog(
      context,
      title: 'Delete Reminder?',
      message: 'Remove "${item.title}"? This cannot be undone.',
      confirmLabel: 'Delete',
      tone: AppConfirmTone.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    if (items.isEmpty) {
      return EmptyState(
        message: emptyMessage,
        actionLabel: emptyActionLabel,
        onAction: emptyActionLabel == null ? null : onAdd,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final canManage =
              item.createdBy == myId || isSuperAdmin;
          final canComplete = allowComplete && !item.isDone && canManage;
          final canDelete = canManage;

          final card = PremiumCard(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item.isDone
                        ? Icons.check_circle_outline
                        : accentOverdue
                            ? Icons.warning_amber_rounded
                            : Icons.notifications_outlined,
                    color: item.isDone
                        ? AppColors.income
                        : accentOverdue
                            ? AppColors.warning
                            : AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          decoration:
                              item.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${item.isDone ? 'Was due' : 'Due'} ${formatDateTime(item.dueDate)}'
                        '${item.amount != null ? ' · ${formatMoney(item.amount!)}' : ''}'
                        '${item.isRecurringMonthly ? ' · Monthly' : ''}'
                        '\nBy ${item.creator?.name ?? 'Unknown'}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (!canComplete && !canDelete) return card;

          return Dismissible(
            key: ValueKey(item.id),
            direction: canComplete && canDelete
                ? DismissDirection.horizontal
                : canComplete
                    ? DismissDirection.startToEnd
                    : DismissDirection.endToStart,
            background: canComplete
                ? Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(left: 20),
                    decoration: BoxDecoration(
                      color: AppColors.incomeSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.income),
                        SizedBox(width: 8),
                        Text(
                          'Complete',
                          style: TextStyle(
                            color: AppColors.income,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(color: Colors.transparent),
            secondaryBackground: canDelete
                ? Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.expenseSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.expense,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.delete_outline_rounded,
                            color: AppColors.expense),
                      ],
                    ),
                  )
                : Container(color: Colors.transparent),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                // Complete — no dialog.
                return canComplete;
              }
              if (!canDelete) return false;
              return _confirmDelete(context, item);
            },
            onDismissed: (direction) {
              final cubit = context.read<RemindersCubit>();
              if (direction == DismissDirection.startToEnd) {
                cubit.markDone(item).catchError((e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not complete: $e')),
                  );
                });
              } else {
                cubit.delete(item.id).catchError((e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not delete: $e')),
                  );
                });
              }
            },
            child: card,
          );
        },
      ),
    );
  }
}
