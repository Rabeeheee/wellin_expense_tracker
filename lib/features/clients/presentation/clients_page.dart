import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/widgets/design/premium_card.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/clients_cubit.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  @override
  void initState() {
    super.initState();
    context.read<ClientsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final profile = context.watch<AuthBloc>().state.profile;
    final myId = profile?.id;
    final isSuperAdmin = profile?.isSuperAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: const WellinAppBarTitle(title: 'Clients'),
        actions: [
          IconButton(
            tooltip: 'Add Client',
            onPressed: () => context.push('/clients/new'),
            icon: Icon(Icons.add_rounded, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: BlocBuilder<ClientsCubit, ClientsState>(
        builder: (context, state) {
          if (state.loading && state.items.isEmpty) {
            return const AppLoader.page();
          }
          if (state.items.isEmpty) {
            return EmptyState(
              message: 'No Clients Yet.',
              actionLabel: 'Add Client',
              onAction: () => context.push('/clients/new'),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () => context.read<ClientsCubit>().load(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              itemCount: state.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = state.items[index];
                final canEdit =
                    item.createdBy == myId || isSuperAdmin;
                return PremiumCard(
                  onTap: canEdit
                      ? () => context.push('/clients/${item.id}/edit', extra: item)
                      : null,
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
                          Icons.business_outlined,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (item.company != null &&
                                item.company!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.company!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (item.email != null &&
                                item.email!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.email!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canEdit)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
