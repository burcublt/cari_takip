enum CustomerStatusFilter { active, inactive, all }

class Customer {
  const Customer({
    required this.id,
    required this.firstName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastName,
    this.phone,
    this.taxNumber,
    this.taxOffice,
    this.address,
    this.note,
  });

  final int id;
  final String firstName;
  final String? lastName;
  final String? phone;

  /// Metin olarak saklanır (baştaki sıfırlar korunur).
  final String? taxNumber;
  final String? taxOffice;
  final String? address;
  final String? note;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Ad/Unvan + soyad (varsa).
  String get displayName {
    final last = lastName;
    return last == null || last.isEmpty ? firstName : '$firstName $last';
  }
}

/// Oluşturma/güncelleme için kullanılan alanlar.
///
/// Boş opsiyonel alanlar tutarlı biçimde `null` saklanır ([fromForm]).
class CustomerDraft {
  const CustomerDraft({
    required this.firstName,
    this.lastName,
    this.phone,
    this.taxNumber,
    this.taxOffice,
    this.address,
    this.note,
  });

  /// Form girdilerini trim eder; boş opsiyonel alanları `null` yapar.
  factory CustomerDraft.fromForm({
    required String firstName,
    String? lastName,
    String? phone,
    String? taxNumber,
    String? taxOffice,
    String? address,
    String? note,
  }) {
    return CustomerDraft(
      firstName: firstName.trim(),
      lastName: _clean(lastName),
      phone: _clean(phone),
      taxNumber: _clean(taxNumber),
      taxOffice: _clean(taxOffice),
      address: _clean(address),
      note: _clean(note),
    );
  }

  final String firstName;
  final String? lastName;
  final String? phone;
  final String? taxNumber;
  final String? taxOffice;
  final String? address;
  final String? note;

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// Cari detayındaki hareket özeti (kuruş cinsinden).
class CustomerSummary {
  const CustomerSummary({
    required this.transactionCount,
    required this.totalKurus,
  });

  final int transactionCount;
  final int totalKurus;
}
