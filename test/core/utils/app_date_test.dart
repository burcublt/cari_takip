import 'package:cari_takip/core/utils/app_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toDbDate YYYY-MM-DD üretir', () {
    expect(AppDate.toDbDate(DateTime(2026, 9, 29)), '2026-09-29');
    expect(AppDate.toDbDate(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
  });

  test('parseDbDate geçerli ve geçersiz girdiler', () {
    expect(AppDate.parseDbDate('2026-09-29'), DateTime(2026, 9, 29));
    expect(AppDate.parseDbDate('2024-02-29'), DateTime(2024, 2, 29));
    expect(AppDate.parseDbDate('2026-02-30'), isNull);
    expect(AppDate.parseDbDate('2026-13-01'), isNull);
    expect(AppDate.parseDbDate('29.09.2026'), isNull);
    expect(AppDate.parseDbDate(''), isNull);
    expect(AppDate.parseDbDate(null), isNull);
  });

  test('formatDisplay gg.aa.yyyy üretir', () {
    expect(AppDate.formatDisplay(DateTime(2026, 9, 29)), '29.09.2026');
    expect(AppDate.formatDisplay(DateTime(2026, 1, 5)), '05.01.2026');
  });

  test('parseDisplay geçerli ve geçersiz girdiler', () {
    expect(AppDate.parseDisplay('29.09.2026'), DateTime(2026, 9, 29));
    expect(AppDate.parseDisplay('1.2.2026'), DateTime(2026, 2, 1));
    expect(AppDate.parseDisplay(' 05.01.2026 '), DateTime(2026, 1, 5));
    expect(AppDate.parseDisplay('31.02.2026'), isNull);
    expect(AppDate.parseDisplay('2026-09-29'), isNull);
    expect(AppDate.parseDisplay('29.09.26'), isNull);
    expect(AppDate.parseDisplay(null), isNull);
  });

  test('display ve db biçimleri gidiş dönüş yapar', () {
    final date = DateTime(2026, 12, 31);
    expect(AppDate.parseDbDate(AppDate.toDbDate(date)), date);
    expect(AppDate.parseDisplay(AppDate.formatDisplay(date)), date);
  });

  test('today saat bilgisini atar', () {
    expect(
      AppDate.today(DateTime(2026, 9, 29, 18, 45)),
      DateTime(2026, 9, 29),
    );
  });

  test('ay başı ve ay sonu', () {
    expect(AppDate.startOfMonth(DateTime(2026, 9, 29)), DateTime(2026, 9));
    expect(AppDate.endOfMonth(DateTime(2026, 9, 10)), DateTime(2026, 9, 30));
    expect(AppDate.endOfMonth(DateTime(2024, 2, 10)), DateTime(2024, 2, 29));
    expect(AppDate.endOfMonth(DateTime(2026, 12, 1)), DateTime(2026, 12, 31));
  });

  test('nowTimestamp UTC ISO-8601 üretir', () {
    final text = AppDate.nowTimestamp(DateTime.utc(2026, 9, 29, 12));
    expect(text, '2026-09-29T12:00:00.000Z');
  });

  test('ay adı ve ay-yıl biçimi', () {
    expect(AppDate.monthName(1), 'Ocak');
    expect(AppDate.monthName(9), 'Eylül');
    expect(AppDate.monthName(12), 'Aralık');
    expect(AppDate.formatMonthYear(DateTime(2026, 9, 15)), 'Eylül 2026');
  });

  test('formatDateTime gg.aa.yyyy ss:dd üretir', () {
    expect(
      AppDate.formatDateTime(DateTime(2026, 9, 29, 18, 5)),
      '29.09.2026 18:05',
    );
  });
}
