import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_colors.dart';
import '../../../core/theme_rebuild_scope.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/design/premium_card.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../../../shared/widgets/wellin_logo.dart';
import '../bloc/users_cubit.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  @override
  void initState() {
    super.initState();
    context.read<UsersCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    return Scaffold(
      appBar: AppBar(title: const WellinAppBarTitle(title: 'Users')),
      body: BlocBuilder<UsersCubit, UsersState>(
        builder: (context, state) {
          if (state.loading) {
            return const AppLoader.page();
          }
          if (state.users.isEmpty) {
            return const EmptyState(message: 'No users found.');
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () => context.read<UsersCubit>().load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.users.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final user = state.users[index];
                return PremiumCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      ProfileAvatar(profile: user, size: 44),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${user.email}\n${user.role.label} · ${user.status.value}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        color: AppColors.surfaceElevated,
                        onSelected: (value) async {
                          final cubit = context.read<UsersCubit>();
                          switch (value) {
                            case 'approve':
                              await cubit.approve(user.id);
                            case 'disable':
                              await cubit.disable(user.id);
                            case 'admin':
                              await cubit.setRole(user.id, UserRole.admin);
                            case 'super':
                              await cubit.setRole(
                                user.id,
                                UserRole.superAdmin,
                              );
                          }
                        },
                        itemBuilder: (context) => [
                          if (user.status == UserStatus.pending)
                            const PopupMenuItem(
                              value: 'approve',
                              child: Text('Approve'),
                            ),
                          const PopupMenuItem(
                            value: 'disable',
                            child: Text('Disable'),
                          ),
                          const PopupMenuItem(
                            value: 'admin',
                            child: Text('Make Admin'),
                          ),
                          const PopupMenuItem(
                            value: 'super',
                            child: Text('Make Super Admin'),
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
    );
  }
}
