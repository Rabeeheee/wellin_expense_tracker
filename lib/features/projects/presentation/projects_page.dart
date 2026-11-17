import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/design/filter_chips_row.dart';
import '../../../shared/widgets/design/premium_card.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../bloc/projects_cubit.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  @override
  void initState() {
    super.initState();
    context.read<ProjectsCubit>().load();
  }

  int _chipIndex(ProjectStatus status) => switch (status) {
        ProjectStatus.active => 0,
        ProjectStatus.upcoming => 1,
        ProjectStatus.completed => 2,
      };

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Scaffold(
      appBar: AppBar(
        title: const WellinAppBarTitle(title: 'Projects'),
        actions: [
          IconButton(
            tooltip: 'Add Project',
            onPressed: () => context.push('/projects/new'),
            icon: Icon(Icons.add_rounded, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: BlocBuilder<ProjectsCubit, ProjectsState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: FilterChipsRow(
                  labels: const ['Active', 'Upcoming', 'Completed'],
                  selectedIndex: _chipIndex(state.statusFilter),
                  onSelected: (i) {
                    final status = switch (i) {
                      1 => ProjectStatus.upcoming,
                      2 => ProjectStatus.completed,
                      _ => ProjectStatus.active,
                    };
                    context.read<ProjectsCubit>().setStatusFilter(status);
                  },
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state.loading && state.items.isEmpty) {
                      return const AppLoader.page();
                    }
                    final visible = state.filteredItems;
                    if (visible.isEmpty) {
                      return EmptyState(
                        message: 'No ${state.statusFilter.label} Projects.',
                        actionLabel: 'Add Project',
                        onAction: () => context.push('/projects/new'),
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onRefresh: () => context.read<ProjectsCubit>().load(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        itemCount: visible.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return PremiumCard(
                            onTap: () => context.push('/projects/${item.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.clientName,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _Stat(
                                        label: 'Contract',
                                        value: formatMoney(item.contractValue),
                                      ),
                                    ),
                                    Expanded(
                                      child: _Stat(
                                        label: 'Received',
                                        value: formatMoney(item.received),
                                        color: AppColors.income,
                                      ),
                                    ),
                                    Expanded(
                                      child: _Stat(
                                        label: 'Pending',
                                        value: formatMoney(item.pending),
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
