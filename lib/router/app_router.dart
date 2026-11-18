import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/presentation/analytics_page.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/presentation/complete_profile_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/more_page.dart';
import '../features/auth/presentation/pending_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/reset_password_page.dart';
import '../features/auth/presentation/security_page.dart';
import '../features/auth/presentation/shell_scaffold.dart';
import '../features/auth/presentation/unlock_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/clients/presentation/client_form_page.dart';
import '../features/clients/presentation/clients_page.dart';
import '../features/employee_expenses/presentation/employee_expenses_page.dart';
import '../features/projects/presentation/project_detail_page.dart';
import '../features/projects/presentation/project_form_page.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/reminders/presentation/reminders_page.dart';
import '../features/transactions/presentation/transaction_form_page.dart';
import '../features/transactions/presentation/transactions_page.dart';
import '../features/users/presentation/users_page.dart';
import '../shared/models/client_item.dart';
import '../shared/models/enums.dart';
import '../shared/models/project_item.dart';
import '../shared/models/transaction_item.dart';
import '../shared/widgets/animated_branch_container.dart';
import '../shared/widgets/circular_reveal_page.dart';
import '../shared/widgets/shell_tab_back_scope.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final auth = authBloc.state;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/complete-profile' ||
          loc == '/reset-password';

      if (auth.status == AuthStatus.unknown) {
        return null;
      }

      if (auth.status == AuthStatus.passwordRecovery) {
        return loc == '/reset-password' ? null : '/reset-password';
      }

      if (auth.status == AuthStatus.unauthenticated ||
          (auth.status == AuthStatus.failure && auth.profile == null)) {
        return isAuthRoute ? null : '/login';
      }

      if (auth.status == AuthStatus.needsProfile) {
        return loc == '/complete-profile' ? null : '/complete-profile';
      }

      if (auth.status == AuthStatus.pending) {
        return loc == '/pending' ? null : '/pending';
      }

      if (auth.status == AuthStatus.locked) {
        return loc == '/unlock' ? null : '/unlock';
      }

      if (auth.status == AuthStatus.authenticated) {
        if (loc == '/dashboard') return '/home';
        if (isAuthRoute ||
            loc == '/pending' ||
            loc == '/unlock' ||
            loc == '/complete-profile' ||
            loc == '/reset-password') {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfilePage(),
      ),
      GoRoute(
        path: '/pending',
        builder: (context, state) => const PendingPage(),
      ),
      GoRoute(path: '/unlock', builder: (context, state) => const UnlockPage()),
      GoRoute(
        path: '/security',
        builder: (context, state) => const SecurityPage(),
      ),
      GoRoute(path: '/users', builder: (context, state) => const UsersPage()),
      GoRoute(
        path: '/reminders',
        builder: (context, state) => const RemindersPage(),
      ),
      GoRoute(
        path: '/employee-expenses',
        builder: (context, state) => const EmployeeExpensesPage(),
      ),
      GoRoute(path: '/clients', builder: (context, state) => const ClientsPage()),
      GoRoute(
        path: '/clients/new',
        builder: (context, state) => const ClientFormPage(),
      ),
      GoRoute(
        path: '/clients/:id/edit',
        builder: (context, state) {
          final item = state.extra as ClientItem?;
          return ClientFormPage(existing: item);
        },
      ),
      GoRoute(
        path: '/projects',
        builder: (context, state) => const ProjectsPage(),
      ),
      GoRoute(
        path: '/projects/new',
        builder: (context, state) => const ProjectFormPage(),
      ),
      GoRoute(
        path: '/projects/:id',
        builder: (context, state) => ProjectDetailPage(
          projectId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/projects/:id/edit',
        builder: (context, state) {
          final item = state.extra as ProjectItem?;
          return ProjectFormPage(existing: item);
        },
      ),
      GoRoute(
        path: '/transactions/new',
        pageBuilder: (context, state) {
          final typeParam = state.uri.queryParameters['type'];
          final initialType = typeParam == null
              ? null
              : TxnType.fromString(typeParam);
          final projectId = state.uri.queryParameters['projectId'];
          final form = TransactionFormPage(
            initialType: initialType,
            initialProjectId: projectId,
          );
          final origin = state.extra is Offset ? state.extra as Offset : null;
          if (origin != null) {
            return circularRevealPage(
              state: state,
              origin: origin,
              child: form,
            );
          }
          return _slideUpPage(state: state, child: form);
        },
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        pageBuilder: (context, state) {
          final item = state.extra as TransactionItem?;
          return _slideUpPage(
            state: state,
            child: TransactionFormPage(existing: item),
          );
        },
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return ShellScaffold(navigationShell: navigationShell);
        },
        navigatorContainerBuilder: (context, navigationShell, children) {
          return AnimatedBranchContainer(
            currentIndex: navigationShell.currentIndex,
            children: children,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const ShellTabBackScope(
                  tabPath: '/home',
                  isHome: true,
                  child: HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const ShellTabBackScope(
                  tabPath: '/analytics',
                  child: AnalyticsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const ShellTabBackScope(
                  tabPath: '/transactions',
                  child: TransactionsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const ShellTabBackScope(
                  tabPath: '/more',
                  child: MorePage(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

CustomTransitionPage<void> _slideUpPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
