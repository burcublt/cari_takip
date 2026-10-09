/// Türkçe'ye duyarlı, aksan ve büyük/küçük harf farkını yok sayan arama anahtarı.
///
/// `İlker`, `ILKER`, `ilker` ve `Şule` / `sule` aynı anahtara iner.
abstract final class TextSearch {
  static const _fold = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
  };

  static final _spaces = RegExp(r'\s+');
  static final _nonDigit = RegExp(r'\D');
  static final _phoneLike = RegExp(r'^[\d\s()+\-]+$');

  static String key(String input) {
    // 'İ' büyük/küçük harfe çevrilmeden önce değiştirilmeli; aksi halde
    // birleşik nokta karakteri üretir.
    var text = input.replaceAll('İ', 'i').replaceAll('I', 'i').toLowerCase();
    _fold.forEach((from, to) => text = text.replaceAll(from, to));
    return text.trim().replaceAll(_spaces, ' ');
  }

  static String digits(String input) => input.replaceAll(_nonDigit, '');

  /// Girdi sadece rakam/telefon karakterlerinden oluşuyorsa `true`.
  static bool isPhoneLike(String input) => _phoneLike.hasMatch(input.trim());
}
