/// Merkezi tarih yardımcıları.
///
/// İşlem tarihi SQLite'ta `YYYY-MM-DD` metni olarak tutulur (saat/saat dilimi
/// yok). `created_at` / `updated_at` ise UTC ISO-8601 timestamp'tir.
abstract final class AppDate {
  static final _displayPattern = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$');
  static final _dbPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Testlerde sabit zaman vermek için [now] parametresi kullanılır.
  static DateTime today([DateTime? now]) => dateOnly(now ?? DateTime.now());

  static DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0);

  /// `2026-09-29`
  static String toDbDate(DateTime date) =>
      '${_pad(date.year, 4)}-${_pad(date.month, 2)}-${_pad(date.day, 2)}';

  /// Geçersiz veya gerçek olmayan tarihte (ör. 2026-02-30) `null` döner.
  static DateTime? parseDbDate(String? value) =>
      _parse(_dbPattern, value?.trim(), yearFirst: true);

  /// `29.09.2026`
  static String formatDisplay(DateTime date) =>
      '${_pad(date.day, 2)}.${_pad(date.month, 2)}.${_pad(date.year, 4)}';

  /// `29.09.2026 18:25`
  static String formatDateTime(DateTime date) =>
      '${formatDisplay(date)} ${_pad(date.hour, 2)}:${_pad(date.minute, 2)}';

  /// `29.09.2026` veya `1.2.2026` -> tarih; geçersizse `null`.
  static DateTime? parseDisplay(String? value) =>
      _parse(_displayPattern, value?.trim(), yearFirst: false);

  /// Sistem timestamp'i (UTC, ISO-8601).
  static String nowTimestamp([DateTime? now]) =>
      (now ?? DateTime.now()).toUtc().toIso8601String();

  static DateTime? _parse(RegExp pattern, String? value,
      {required bool yearFirst}) {
    if (value == null) return null;
    final match = pattern.firstMatch(value);
    if (match == null) return null;

    final a = int.parse(match.group(1)!);
    final b = int.parse(match.group(2)!);
    final c = int.parse(match.group(3)!);
    final year = yearFirst ? a : c;
    final day = yearFirst ? c : a;
    final month = b;

    final parsed = DateTime(year, month, day);
    final real =
        parsed.year == year && parsed.month == month && parsed.day == day;
    return real ? parsed : null;
  }

  static const _monthNames = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  /// 1-12 -> `Ocak` ... `Aralık`
  static String monthName(int month) => _monthNames[month - 1];

  /// `Eylül 2026`
  static String formatMonthYear(DateTime date) =>
      '${monthName(date.month)} ${date.year}';

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');
}
