DateTime mondayFor(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
).subtract(Duration(days: date.weekday - DateTime.monday));

DateTime monthStartFor(DateTime date) => DateTime(date.year, date.month);

DateTime monthEndFor(DateTime date) => DateTime(date.year, date.month + 1, 0);

String dietExportFilename({
  required bool shoppingList,
  required DateTime start,
  required DateTime end,
  required bool calendarMonth,
}) {
  final prefix = shoppingList ? 'lista_compra' : 'menu';
  if (calendarMonth) {
    return '${prefix}_${start.year}-${start.month.toString().padLeft(2, '0')}.pdf';
  }
  return '${prefix}_${_date(start)}_${_date(end)}.pdf';
}

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
