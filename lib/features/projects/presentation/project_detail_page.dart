import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/project_item.dart';
import '../../../shared/models/transaction_item.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/design/premium_card.dart';
import '../../../shared/widgets/design/txn_icon.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/projects_cubit.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  ProjectItem? _project;
  List<TransactionItem> _txns = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cubit = context.read<ProjectsCubit>();
      final project = await cubit.fetchById(widget.projectId);
      final txns = await cubit.fetchTransactions(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _txns = txns;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final profile = context.watch<AuthBloc>().state.profile;
    final myId = profile?.id;
    final isSuperAdmin = profile?.isSuperAdmin == true;
    final project = _project;

    return Scaffold(
      appBar: AppBar(
        title: WellinAppBarTitle(title: project?.title ?? 'Project'),
        actions: [
          if (project != null &&
              (project.createdBy == myId || isSuperAdmin))
            IconButton(
              tooltip: 'Edit',
              onPressed: () async {
                await context.push(
                  '/projects/${project.id}/edit',
                  extra: project,
                );
                if (mounted) _load();
              },
              icon: Icon(Icons.edit_outlined, color: AppColors.textPrimary),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : project == null
                  ? const EmptyState(message: 'Project Not Found.')
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                        children: [
                          PremiumCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.status.label,
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  project.clientName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (project.client?.email != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    project.client!.email!,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                if (project.description != null &&
                                    project.description!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    project.description!,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Contract',
                                  value: formatMoney(project.contractValue),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Received',
                                  value: formatMoney(project.received),
                                  color: AppColors.income,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Pending',
                                  value: formatMoney(project.pending),
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Expenses',
                                  value: formatMoney(project.spent),
                                  color: AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await context.push(
                                      '/transactions/new?type=expense&projectId=${project.id}',
                                    );
                                    if (mounted) _load();
                                  },
                                  icon: const Icon(Icons.remove_rounded),
                                  label: const Text('Add Expense'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final cubit = context.read<ProjectsCubit>();
                                    await context.push(
                                      '/transactions/new?type=income&projectId=${project.id}',
                                    );
                                    if (!mounted) return;
                                    await cubit.load();
                                    _load();
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add Income'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Linked Entries',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_txns.isEmpty)
                            PremiumCard(
                              child: Text(
                                'No Expenses Or Income Linked Yet.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          else
                            ..._txns.map((item) {
                              final canManage =
                                  item.createdBy == myId || isSuperAdmin;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: PremiumCard(
                                  onTap: canManage
                                      ? () async {
                                          final cubit =
                                              context.read<ProjectsCubit>();
                                          await context.push(
                                            '/transactions/${item.id}/edit',
                                            extra: item,
                                          );
                                          if (!mounted) return;
                                          await cubit.load();
                                          _load();
                                        }
                                      : null,
                                  child: Row(
                                    children: [
                                      TxnIconWell(category: item.category),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.category.label,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              formatDate(item.txnDate),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AmountText(
                                        amount: item.amount,
                                        type: item.type,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
