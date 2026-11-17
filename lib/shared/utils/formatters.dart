import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
final _date = DateFormat('dd MMM yyyy');
final _dateTime = DateFormat('dd MMM yyyy · hh:mm a');
final _time = DateFormat('hh:mm a');
final _monthYear = DateFormat('MMMM yyyy');
final _yearOnly = DateFormat('yyyy');

String formatMoney(num amount) => _currency.format(amount);

String formatDate(DateTime date) => _date.format(date);

String formatDateTime(DateTime date) => _dateTime.format(date);

String formatTime(DateTime date) => _time.format(date);

String formatMonthYear(DateTime date) => _monthYear.format(date);

String formatYear(int year) => _yearOnly.format(DateTime(year));

DateTime monthStart(int year, int month) => DateTime(year, month);

DateTime monthEnd(int year, int month) => DateTime(year, month + 1, 0);

DateTime yearStart(int year) => DateTime(year, 1, 1);

DateTime yearEnd(int year) => DateTime(year, 12, 31);
