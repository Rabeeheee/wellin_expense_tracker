import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_colors.dart';
import 'core/app_theme.dart';
import 'core/notification_service.dart';
import 'core/secure_lock_service.dart';
import 'core/theme_cubit.dart';
import 'core/theme_rebuild_scope.dart';
import 'core/theme_reveal.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/clients/bloc/clients_cubit.dart';
import 'features/clients/data/client_repository.dart';
import 'features/projects/bloc/projects_cubit.dart';
import 'features/projects/data/project_repository.dart';
import 'features/reminders/bloc/reminders_cubit.dart';
import 'features/reminders/data/reminder_repository.dart';
import 'features/transactions/bloc/transactions_cubit.dart';
import 'features/transactions/data/transaction_repository.dart';
import 'features/users/bloc/users_cubit.dart';
import 'features/users/data/users_repository.dart';
import 'router/app_router.dart';

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({
    super.key,
    required this.lockService,
    required this.notificationService,
  });

  final SecureLockService lockService;
  final NotificationService notificationService;

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp>
    with WidgetsBindingObserver {
  late final AuthRepository _authRepository;
  late final AuthBloc _authBloc;
  late final ThemeCubit _themeCubit;
  late final ThemeRevealController _themeReveal;
  late final GoRouter _router;
  late final TransactionRepository _transactionRepository;
  late final ReminderRepository _reminderRepository;
  late final UsersRepository _usersRepository;
  late final ClientRepository _clientRepository;
  late final ProjectRepository _projectRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final client = Supabase.instance.client;
    _authRepository = AuthRepository(client);
    _transactionRepository = TransactionRepository(client);
    _reminderRepository = ReminderRepository(client);
    _usersRepository = UsersRepository(client);
    _clientRepository = ClientRepository(client);
    _projectRepository = ProjectRepository(client);
    _themeCubit = ThemeCubit();
    _themeReveal = ThemeRevealController();
    _authBloc = AuthBloc(
      authRepository: _authRepository,
      lockService: widget.lockService,
    )..add(const AuthStarted());
    _router = createRouter(_authBloc);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _authBloc.add(const AuthLockRequested());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authBloc.close();
    _themeCubit.close();
    _themeReveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _authRepository),
        RepositoryProvider.value(value: widget.lockService),
        RepositoryProvider.value(value: _transactionRepository),
        RepositoryProvider.value(value: _reminderRepository),
        RepositoryProvider.value(value: _usersRepository),
        RepositoryProvider.value(value: _clientRepository),
        RepositoryProvider.value(value: _projectRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authBloc),
          BlocProvider.value(value: _themeCubit),
          BlocProvider(
            create: (_) => TransactionsCubit(_transactionRepository),
          ),
          BlocProvider(
            create: (_) => RemindersCubit(
              _reminderRepository,
              notifications: widget.notificationService,
            ),
          ),
          BlocProvider(
            create: (_) => UsersCubit(_usersRepository),
          ),
          BlocProvider(
            create: (_) => ClientsCubit(_clientRepository),
          ),
          BlocProvider(
            create: (_) => ProjectsCubit(_projectRepository),
          ),
        ],
        child: ThemeRevealScope(
          controller: _themeReveal,
          child: BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, mode) {
              final isLight = mode == ThemeMode.light;
              AppColors.setLight(isLight);
              final theme = isLight ? AppTheme.light : AppTheme.dark;
              return MaterialApp.router(
                title: 'Expense Tracker',
                debugShowCheckedModeBanner: false,
                theme: theme,
                themeMode: ThemeMode.light,
                routerConfig: _router,
                builder: (context, child) {
                  return ThemeRebuildScope(
                    mode: mode,
                    isLight: isLight,
                    child: ThemeRevealLayer(
                      controller: _themeReveal,
                      child: Theme(
                        data: theme,
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
