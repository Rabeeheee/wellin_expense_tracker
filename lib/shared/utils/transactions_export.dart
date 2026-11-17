import 'dart:convert';

import '../models/transaction_item.dart';
import 'formatters.dart';

/// Builds an Excel-friendly SpreadsheetML workbook (.xls) with column widths
/// and dates stored as text so sheets don't show ####.
List<int> buildTransactionsExcelBytes(List<TransactionItem> items) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<?mso-application progid="Excel.Sheet"?>')
    ..writeln(
      '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
      'xmlns:o="urn:schemas-microsoft-com:office:office" '
      'xmlns:x="urn:schemas-microsoft-com:office:excel" '
      'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
    )
    ..writeln('<Styles>')
    ..writeln(
      '<Style ss:ID="Header"><Font ss:Bold="1"/>'
      '<Interior ss:Color="#F2F2F2" ss:Pattern="Solid"/></Style>',
    )
    ..writeln(
      '<Style ss:ID="Date"><NumberFormat ss:Format="@"/></Style>',
    )
    ..writeln(
      '<Style ss:ID="Amount"><NumberFormat ss:Format="#,##0.00"/></Style>',
    )
    ..writeln('</Styles>')
    ..writeln('<Worksheet ss:Name="Expenses">')
    ..writeln('<Table>');

  // Approximate Excel width units (characters * ~7).
  const widths = <double>[100, 70, 130, 90, 160, 110, 220];
  for (final width in widths) {
    buffer.writeln('<Column ss:AutoFitWidth="0" ss:Width="$width"/>');
  }

  buffer
    ..writeln('<Row ss:StyleID="Header">')
    ..write(_stringCell('Date'))
    ..write(_stringCell('Type'))
    ..write(_stringCell('Category'))
    ..write(_stringCell('Amount'))
    ..write(_stringCell('Note'))
    ..write(_stringCell('Added By'))
    ..write(_stringCell('Receipt URL'))
    ..writeln('</Row>');

  for (final item in items) {
    buffer
      ..writeln('<Row>')
      ..write(_stringCell(formatDate(item.txnDate), styleId: 'Date'))
      ..write(_stringCell(item.type.label))
      ..write(_stringCell(item.category.label))
      ..write(_numberCell(item.amount))
      ..write(_stringCell(item.note ?? ''))
      ..write(_stringCell(item.creatorName))
      ..write(_stringCell(item.receiptUrl ?? ''))
      ..writeln('</Row>');
  }

  buffer
    ..writeln('</Table>')
    ..writeln('</Worksheet>')
    ..writeln('</Workbook>');

  // BOM helps Excel detect UTF-8 correctly.
  return <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())];
}

String buildTransactionsCsv(List<TransactionItem> items) {
  final buffer = StringBuffer();
  buffer.writeln('Date,Type,Category,Amount,Note,Added By,Receipt URL');
  for (final item in items) {
    buffer.writeln(
      [
        _csv(formatDate(item.txnDate)),
        _csv(item.type.label),
        _csv(item.category.label),
        item.amount.toStringAsFixed(2),
        _csv(item.note ?? ''),
        _csv(item.creatorName),
        _csv(item.receiptUrl ?? ''),
      ].join(','),
    );
  }
  return buffer.toString();
}

String _csv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _stringCell(String value, {String? styleId}) {
  final style = styleId == null ? '' : ' ss:StyleID="$styleId"';
  return '<Cell$style><Data ss:Type="String">${_escapeXml(value)}</Data></Cell>';
}

String _numberCell(double value) {
  return '<Cell ss:StyleID="Amount">'
      '<Data ss:Type="Number">${value.toStringAsFixed(2)}</Data>'
      '</Cell>';
}
