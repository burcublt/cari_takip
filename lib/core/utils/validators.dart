import 'package:cari_takip/core/utils/currency.dart';

/// Merkezi doğrulama kuralları. Her metod `FormField.validator` ile uyumludur:
/// geçerliyse `null`, değilse kullanıcıya gösterilecek mesajı döndürür.
///
/// İşlem tipi adının benzersizliği burada değil, repository katmanında
/// (veritabanı unique index'i + hata eşleme) kontrol edilir.
abstract final class Validators {
  static String? customerName(String? value) =>
      _required(value, 'Ad / Unvan zorunludur.');

  static String? transactionTypeName(String? value) =>
      _required(value, 'İşlem tipi adı zorunludur.');

  static String? customer(int? customerId) =>
      customerId == null ? 'Cari seçiniz.' : null;

  static String? transactionType(int? transactionTypeId) =>
      transactionTypeId == null ? 'İşlem tipi seçiniz.' : null;

  static String? transactionDate(DateTime? date) =>
      date == null ? 'Tarih seçiniz.' : null;

  /// Form girdisi (ör. `"1.250,50"`).
  static String? amount(String? input) {
    if (input == null || input.trim().isEmpty) return 'Tutar giriniz.';
    final kurus = Currency.parseTlToKurus(input);
    if (kurus == null) return 'Geçerli bir tutar giriniz (örn. 1.250,50).';
    return amountKurus(kurus);
  }

  /// Domain/repository seviyesi: kuruş cinsinden tutar.
  static String? amountKurus(int? kurus) {
    if (kurus == null) return 'Tutar giriniz.';
    if (kurus <= 0) return "Tutar 0'dan büyük olmalıdır.";
    return null;
  }

  static String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;
}
