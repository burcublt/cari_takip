/// Merkezi TL <-> kuruş dönüşümü. Tutarlar her yerde kuruş (int) olarak tutulur.
///
/// Girdi biçimi Türkçe'dir: nokta binlik, virgül ondalık ayırıcıdır.
/// Belirsiz girdiler (ör. `12.5`) sessizce yorumlanmaz, geçersiz sayılır.
abstract final class Currency {
  static const unit = 'TL';

  // Tek tutarın tam kısmı en fazla 13 hane: int taşması ve toplam riskini önler.
  static const _maxIntegerDigits = 13;

  static final _plainInt = RegExp(r'^\d+$');
  static final _groupedInt = RegExp(r'^\d{1,3}(\.\d{3})+$');
  static final _fraction = RegExp(r'^\d{1,2}$');
  static final _trailingUnit = RegExp(r'\s*TL\s*$', caseSensitive: false);

  /// `"1.250,50"`, `"1250,5"`, `"12.450,75 TL"`, `"₺100"` -> kuruş.
  /// Geçersiz girdide `null` döner. Negatif girdi negatif kuruş döner;
  /// "0'dan büyük" kontrolü validator'un işidir.
  static int? parseTlToKurus(String? input) {
    if (input == null) return null;

    var body = input
        .replaceAll('₺', '')
        .trim()
        .replaceFirst(_trailingUnit, '')
        .replaceAll(RegExp(r'\s'), '');

    var negative = false;
    if (body.startsWith('-')) {
      negative = true;
      body = body.substring(1);
    }
    if (body.isEmpty) return null;

    final parts = body.split(',');
    if (parts.length > 2) return null;

    final integerPart = parts[0];
    final fractionPart = parts.length == 2 ? parts[1] : '';
    if (parts.length == 2 && !_fraction.hasMatch(fractionPart)) return null;
    if (!_plainInt.hasMatch(integerPart) &&
        !_groupedInt.hasMatch(integerPart)) {
      return null;
    }

    final digits = integerPart.replaceAll('.', '');
    if (digits.length > _maxIntegerDigits) return null;

    final lira = int.parse(digits);
    final kurus =
        fractionPart.isEmpty ? 0 : int.parse(fractionPart.padRight(2, '0'));
    final total = lira * 100 + kurus;
    return negative ? -total : total;
  }

  /// `125050` -> `"1.250,50 TL"`. Form alanı için [includeUnit] `false` verilir.
  static String formatKurusToTl(int kurus, {bool includeUnit = true}) {
    final sign = kurus < 0 ? '-' : '';
    final abs = kurus.abs();
    final lira = (abs ~/ 100).toString();
    final remainder = (abs % 100).toString().padLeft(2, '0');

    final grouped = StringBuffer();
    for (var i = 0; i < lira.length; i++) {
      if (i > 0 && (lira.length - i) % 3 == 0) grouped.write('.');
      grouped.write(lira[i]);
    }

    final text = '$sign$grouped,$remainder';
    return includeUnit ? '$text $unit' : text;
  }
}
