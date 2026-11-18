import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/period_scope.dart';
import '../../../shared/models/transaction_item.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/utils/transactions_export.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/design/app_confirm_dialog.dart';
import '../../../shared/widgets/design/filter_chips_row.dart';
import '../../../shared/widgets/design/premium_card.dart';
import '../../../shared/widgets/design/premium_select_field.dart';
import '../../../shared/widgets/design/txn_icon.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/month_year_filter.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../projects/bloc/projects_cubit.dart';
import '../bloc/transactions_cubit.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  static const _allProjects = '__all__';
  static const _noProject = '';

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _exportButtonKey = GlobalKey();
  bool _exporting = false;
  bool _byUser = false;
  bool _searchOpen = false;
  String? _selectedUserId;
  String? _selectedUserName;

  @override
  void initState() {
    super.initState();
    context.read<TransactionsCubit>().load();
    context.read<ProjectsCubit>().load();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  int _chipIndex(TxnType? type) {
    if (_byUser) return 3;
    if (type == TxnType.income) return 1;
    if (type == TxnType.expense) return 2;
    return 0;
  }

  void _onModeChip(int i) {
    setState(() {
      _byUser = i == 3;
      _selectedUserId = null;
      _selectedUserName = null;
    });
    context.read<TransactionsCubit>().setUserFilter(null);
    final type = switch (i) {
      1 => TxnType.income,
      2 => TxnType.expense,
      _ => null, // All + By User: income and expense
    };
    context.read<TransactionsCubit>().setTypeFilter(type);
  }

  void _openUser(String userId, String name) {
    setState(() {
      _selectedUserId = userId;
      _selectedUserName = name;
    });
  }

  void _closeUser() {
    setState(() {
      _selectedUserId = null;
      _selectedUserName = null;
    });
  }

  void _toggleSearch() {
    final opening = !_searchOpen;
    setState(() {
      _searchOpen = opening;
      if (!opening) {
        _search.clear();
        context.read<TransactionsCubit>().setSearchQuery('');
        _searchFocus.unfocus();
      }
    });
    if (opening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  void _logExport(String message, [Object? error, StackTrace? stack]) {
    debugPrint('[Txn Export] $message${error == null ? '' : ' | $error'}');
    developer.log(
      message,
      name: 'Txn Export',
      error: error,
      stackTrace: stack,
    );
  }

  Rect? _shareOrigin() {
    final box =
        _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _exportCsv(List<TransactionItem> items, String period) async {
    _logExport(
      'start items=${items.length} exporting=$_exporting period="$period"',
    );
    if (items.isEmpty || _exporting) {
      _logExport('aborted empty=${items.isEmpty} busy=$_exporting');
      return;
    }

    setState(() => _exporting = true);
    try {
      final bytes = Uint8List.fromList(buildTransactionsExcelBytes(items));
      _logExport('excel built period="$period" bytes=${bytes.length}');

      final safe = period.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
      final fileName = 'wellin_$safe.xls';
      final origin = _shareOrigin();
      _logExport('shareOrigin=$origin kIsWeb=$kIsWeb');

      try {
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'application/vnd.ms-excel',
                name: fileName,
              ),
            ],
            subject: 'Wellin Export $period',
            title: 'Wellin Export $period',
            sharePositionOrigin: origin,
            downloadFallbackEnabled: true,
          ),
        );
        _logExport(
          'file share done status=${result.status} raw=${result.raw}',
        );
      } catch (fileShareError, fileShareStack) {
        _logExport(
          'file share failed, falling back to csv text',
          fileShareError,
          fileShareStack,
        );
        final csv = buildTransactionsCsv(items);
        final result = await SharePlus.instance.share(
          ShareParams(
            text: csv,
            subject: 'Wellin Export $period',
            title: 'Wellin Export $period',
            sharePositionOrigin: origin,
          ),
        );
        _logExport(
          'text share done status=${result.status} raw=${result.raw}',
        );
      }
    } catch (e, stack) {
      _logExport('export failed', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
      _logExport('finished');
    }
  }

  List<_UserSummary> _userSummaries(List<TransactionItem> items) {
    final map = <String, _UserSummary>{};
    for (final item in items) {
      final existing = map[item.createdBy];
      if (existing == null) {
        map[item.createdBy] = _UserSummary(
          userId: item.createdBy,
          name: item.creatorName,
          expenseTotal: item.type == TxnType.expense ? item.amount : 0,
          incomeTotal: item.type == TxnType.income ? item.amount : 0,
          expenseCount: item.type == TxnType.expense ? 1 : 0,
          incomeCount: item.type == TxnType.income ? 1 : 0,
        );
      } else {
        map[item.createdBy] = existing.add(item);
      }
    }
    final list = map.values.toList()
      ..sort((a, b) {
        final byExpense = b.expenseTotal.compareTo(a.expenseTotal);
        if (byExpense != 0) return byExpense;
        final byIncome = b.incomeTotal.compareTo(a.incomeTotal);
        if (byIncome != 0) return byIncome;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final profile = context.watch<AuthBloc>().state.profile;
    final myId = profile?.id;
    final isSuperAdmin = profile?.isSuperAdmin == true;
    final drilling = _byUser && _selectedUserId != null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<TransactionsCubit, TransactionsState>(
          builder: (context, state) {
            final base = state.filteredItems;
            final visible = drilling
                ? base
                    .where((e) => e.createdBy == _selectedUserId)
                    .toList()
                : base;
            final summaries =
                _byUser && !drilling ? _userSummaries(base) : const <_UserSummary>[];
            final maxUserTotal = summaries.isEmpty
                ? 0.0
                : summaries
                    .map((e) => e.expenseTotal + e.incomeTotal)
                    .fold<double>(0, (a, b) => a > b ? a : b);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                  child: Row(
                    children: [
                      if (drilling) ...[
                        IconButton(
                          tooltip: 'Back',
                          onPressed: _closeUser,
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _selectedUserName ?? 'User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Entries',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: _searchOpen ? 'Hide Search' : 'Search',
                        onPressed: _toggleSearch,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Icon(
                            _searchOpen || state.searchQuery.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.search_rounded,
                            key: ValueKey(
                              _searchOpen || state.searchQuery.isNotEmpty,
                            ),
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        key: _exportButtonKey,
                        tooltip: 'Export',
                        onPressed: visible.isEmpty || _exporting
                            ? null
                            : () => _exportCsv(visible, state.periodLabel),
                        icon: _exporting
                            ? const AppLoader.inline(size: 18)
                            : Icon(
                                Icons.ios_share_rounded,
                                color: AppColors.textPrimary,
                              ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: (_searchOpen || state.searchQuery.isNotEmpty)
                      ? Padding(
                          key: const ValueKey('search-open'),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: TextField(
                            controller: _search,
                            focusNode: _searchFocus,
                            onChanged: context
                                .read<TransactionsCubit>()
                                .setSearchQuery,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search note, category, amount…',
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: AppColors.textTertiary,
                              ),
                              suffixIcon: state.searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear',
                                      onPressed: () {
                                        _search.clear();
                                        context
                                            .read<TransactionsCubit>()
                                            .setSearchQuery('');
                                      },
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                            ),
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('search-closed'),
                          width: double.infinity,
                        ),
                ),
                if (!drilling) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: PeriodScopeChips(
                      scope: state.scope,
                      onChanged: (v) =>
                          context.read<TransactionsCubit>().setScope(v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: MonthYearFilter(
                      year: state.year,
                      month: state.month,
                      day: state.day,
                      scope: state.scope,
                      onChanged: (y, m, d) =>
                          context.read<TransactionsCubit>().setDate(y, m, d),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: FilterChipsRow(
                      labels: const ['All', 'Income', 'Expense', 'By User'],
                      selectedIndex: _chipIndex(state.typeFilter),
                      onSelected: _onModeChip,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: Builder(
                      builder: (context) {
                        final projects =
                            context.watch<ProjectsCubit>().state.items;
                        final selected = state.projectFilter == null
                            ? _allProjects
                            : state.projectFilter!;
                        return PremiumSelectField<String>(
                          label: 'Project',
                          value: selected,
                          options: [
                            const PremiumSelectOption(
                              value: _allProjects,
                              label: 'All Projects',
                            ),
                            const PremiumSelectOption(
                              value: _noProject,
                              label: 'No Project',
                            ),
                            ...projects.map(
                              (p) => PremiumSelectOption(
                                value: p.id,
                                label: '${p.title} · ${p.clientName}',
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            context.read<TransactionsCubit>().setProjectFilter(
                                  v == _allProjects ? null : v,
                                );
                          },
                        );
                      },
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      () {
                        final expenses = visible
                            .where((e) => e.type == TxnType.expense)
                            .fold<double>(0, (s, e) => s + e.amount);
                        final income = visible
                            .where((e) => e.type == TxnType.income)
                            .fold<double>(0, (s, e) => s + e.amount);
                        return '${visible.length} entr${visible.length == 1 ? 'y' : 'ies'}'
                            ' · Exp ${formatMoney(expenses)}'
                            ' · Inc ${formatMoney(income)}';
                      }(),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state.loading && state.items.isEmpty) {
                        return const AppLoader.page();
                      }

                      if (_byUser && !drilling) {
                        if (summaries.isEmpty) {
                          return _emptyBody(context, state);
                        }
                        return RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          onRefresh: () =>
                              context.read<TransactionsCubit>().load(),
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(20, 4, 20, 120),
                            itemCount: summaries.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final expenseTotal = summaries.fold<double>(
                                  0,
                                  (s, e) => s + e.expenseTotal,
                                );
                                final incomeTotal = summaries.fold<double>(
                                  0,
                                  (s, e) => s + e.incomeTotal,
                                );
                                return PremiumCard(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    18,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        formatMoney(expenseTotal),
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.expense,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'By Contributor · Tap a person',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Income ${formatMoney(incomeTotal)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.income,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final user = summaries[index - 1];
                              final color = AppColors.chartColor(index - 1);
                              final barValue =
                                  user.expenseTotal + user.incomeTotal;
                              final parts = <String>[
                                if (user.expenseCount > 0)
                                  '${user.expenseCount} expense${user.expenseCount == 1 ? '' : 's'}',
                                if (user.incomeCount > 0)
                                  '${user.incomeCount} income${user.incomeCount == 1 ? '' : 's'}',
                              ];
                              return PremiumCard(
                                onTap: () =>
                                    _openUser(user.userId, user.name),
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  12,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              color.withValues(alpha: 0.18),
                                          child: Text(
                                            user.name.isEmpty
                                                ? '?'
                                                : user.name
                                                    .characters
                                                    .first
                                                    .toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                parts.isEmpty
                                                    ? 'No entries'
                                                    : parts.join(' · '),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors
                                                      .textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            if (user.expenseTotal > 0)
                                              Text(
                                                formatMoney(
                                                  user.expenseTotal,
                                                ),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.expense,
                                                ),
                                              ),
                                            if (user.incomeTotal > 0)
                                              Text(
                                                formatMoney(
                                                  user.incomeTotal,
                                                ),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.income,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.textTertiary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: maxUserTotal == 0
                                            ? 0
                                            : barValue / maxUserTotal,
                                        minHeight: 7,
                                        backgroundColor:
                                            AppColors.primaryMuted,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      }

                      if (visible.isEmpty) {
                        return _emptyBody(context, state);
                      }

                      return RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        onRefresh: () =>
                            context.read<TransactionsCubit>().load(),
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 120),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            return _TxnTile(
                              item: item,
                              showCreator: !_byUser,
                              canManage:
                                  item.createdBy == myId || isSuperAdmin,
                              onEdit: () => context.push(
                                '/transactions/${item.id}/edit',
                                extra: item,
                              ),
                              onDelete: () {
                                final cubit =
                                    context.read<TransactionsCubit>();
                                cubit.delete(item.id).catchError((e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Could not delete: $e'),
                                    ),
                                  );
                                });
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyBody(BuildContext context, TransactionsState state) {
    final searching = state.searchQuery.trim().isNotEmpty;
    final periodWord = switch (state.scope) {
      PeriodScope.day => 'Day',
      PeriodScope.month => 'Month',
      PeriodScope.year => 'Year',
    };
    final emptyPeriod = _byUser
        ? 'No Entries By User.'
        : switch (state.typeFilter) {
            TxnType.income => 'No Income This $periodWord.',
            TxnType.expense => 'No Expenses This $periodWord.',
            null => 'No Entries This $periodWord.',
          };
    final actionLabel = switch (state.typeFilter) {
      TxnType.income => 'Add Income',
      TxnType.expense => 'Add Expense',
      null => 'Add Entry',
    };

    return EmptyState(
      message: searching ? 'No Matches For This Search.' : emptyPeriod,
      actionLabel: searching ? null : actionLabel,
      onAction: searching
          ? null
          : () {
              final type = state.typeFilter;
              final path = type == null
                  ? '/transactions/new'
                  : '/transactions/new?type=${type.value}';
              context.push(path);
            },
    );
  }
}

class _UserSummary {
  const _UserSummary({
    required this.userId,
    required this.name,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.expenseCount,
    required this.incomeCount,
  });

  final String userId;
  final String name;
  final double expenseTotal;
  final double incomeTotal;
  final int expenseCount;
  final int incomeCount;

  _UserSummary add(TransactionItem item) {
    return _UserSummary(
      userId: userId,
      name: name,
      expenseTotal:
          expenseTotal + (item.type == TxnType.expense ? item.amount : 0),
      incomeTotal:
          incomeTotal + (item.type == TxnType.income ? item.amount : 0),
      expenseCount: expenseCount + (item.type == TxnType.expense ? 1 : 0),
      incomeCount: incomeCount + (item.type == TxnType.income ? 1 : 0),
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({
    required this.item,
    required this.showCreator,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionItem item;
  final bool showCreator;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final hasReceipt =
        item.receiptUrl != null && item.receiptUrl!.isNotEmpty;
    final card = PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: canManage ? onEdit : null,
      child: Row(
        children: [
          TxnIconWell(category: item.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  '${formatDate(item.txnDate)}'
                  '${showCreator ? ' · ${item.creatorName}' : ''}'
                  '${item.note != null && item.note!.isNotEmpty ? '\n${item.note}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (hasReceipt) ...[
            Icon(
              Icons.attach_file_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
          ],
          AmountText(amount: item.amount, type: item.type),
        ],
      ),
    );

    if (!canManage) return card;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expenseSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: AppColors.expense,
        ),
      ),
      confirmDismiss: (_) => showAppConfirmDialog(
        context,
        title: 'Delete Entry?',
        message:
            'Remove "${item.category.label}"? This cannot be undone.',
        confirmLabel: 'Delete',
        tone: AppConfirmTone.danger,
      ),
      onDismissed: (_) => onDelete(),
      child: card,
    );
  }
}
