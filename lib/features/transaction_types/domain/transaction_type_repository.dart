import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';

/// İşlem tipi erişim sözleşmesi. Hatalar `AppException` olarak fırlatılır.
///
/// Bilinçli olarak silme (delete) işlemi yoktur: tipler yalnızca pasife alınır,
/// böylece eski finans hareketleri ve raporlar bozulmaz.
abstract interface class TransactionTypeRepository {
  Future<List<TransactionType>> getTransactionTypes({
    TransactionTypeStatusFilter status = TransactionTypeStatusFilter.active,
  });

  Future<TransactionType?> getTransactionTypeById(int id);

  /// Aynı isimde (Türkçe/aksan duyarsız) tip varsa `duplicate` hatası verir.
  Future<TransactionType> createTransactionType(String name);

  Future<TransactionType> renameTransactionType(int id, String name);

  Future<void> setTransactionTypeActive(int id, {required bool isActive});
}
