enum PeriodScope {
  day,
  month,
  year;

  String get label => switch (this) {
        PeriodScope.day => 'Day',
        PeriodScope.month => 'Month',
        PeriodScope.year => 'Year',
      };
}
