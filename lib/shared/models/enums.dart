enum UserRole {
  superAdmin('super_admin'),
  admin('admin');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.admin,
    );
  }

  String get label => switch (this) {
        UserRole.superAdmin => 'Super Admin',
        UserRole.admin => 'Admin',
      };
}

enum UserStatus {
  active('active'),
  pending('pending'),
  disabled('disabled');

  const UserStatus(this.value);
  final String value;

  static UserStatus fromString(String value) {
    return UserStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserStatus.pending,
    );
  }
}

enum TxnType {
  income('income'),
  expense('expense');

  const TxnType(this.value);
  final String value;

  static TxnType fromString(String value) {
    return TxnType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TxnType.expense,
    );
  }

  String get label => switch (this) {
        TxnType.income => 'Income',
        TxnType.expense => 'Expense',
      };
}

enum TxnCategory {
  projectIncome('project_income', TxnType.income, 'Project Income'),
  dayToDay('day_to_day', TxnType.income, 'Day To Day'),
  otherIncome('other_income', TxnType.income, 'Other Income'),
  projectExpenses('project_expenses', TxnType.expense, 'Project Expenses'),
  officeExpenses('office_expenses', TxnType.expense, 'Office Expenses'),
  roomRent('room_rent', TxnType.expense, 'Room Rent'),
  electricity('electricity', TxnType.expense, 'Electricity'),
  otherExpense('other_expense', TxnType.expense, 'Other Expense');

  const TxnCategory(this.value, this.type, this.label);
  final String value;
  final TxnType type;
  final String label;

  static TxnCategory fromString(String value) {
    return TxnCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TxnCategory.otherExpense,
    );
  }

  static List<TxnCategory> forType(TxnType type) =>
      TxnCategory.values.where((c) => c.type == type).toList();
}

enum ReminderPreset {
  electricity('electricity', 'Electricity Bill'),
  projectHost('project_host', 'Project Host'),
  roomRent('room_rent', 'Room Rent'),
  custom('custom', 'Custom');

  const ReminderPreset(this.value, this.label);
  final String value;
  final String label;

  static ReminderPreset fromString(String value) {
    return ReminderPreset.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReminderPreset.custom,
    );
  }
}

enum ProjectStatus {
  active('active', 'Active'),
  upcoming('upcoming', 'Upcoming'),
  completed('completed', 'Completed');

  const ProjectStatus(this.value, this.label);
  final String value;
  final String label;

  static ProjectStatus fromString(String value) {
    return ProjectStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ProjectStatus.upcoming,
    );
  }
}
