import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type_name.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type_repository.dart';

TransactionType makeType({
  int id = 1,
  String name = 'Kira',
  bool isActive = true,
}) {
  return TransactionType(
    id: id,
    name: name,
    isActive: isActive,
    createdAt: DateTime.utc(2026, 9, 29),
    updatedAt: DateTime.utc(2026, 9, 29),
  );
}

/// Bellekte çalışan sahte repository (widget testleri için).
class FakeTransactionTypeRepository implements TransactionTypeRepository {
  FakeTransactionTypeRepository([List<TransactionType>? initial])
      : types = [...?initial];

  final List<TransactionType> types;

  int get _nextId => types.fold(0, (max, t) => t.id > max ? t.id : max) + 1;

  bool _matches(TransactionType t, TransactionTypeStatusFilter status) =>
      switch (status) {
        TransactionTypeStatusFilter.all => true,
        TransactionTypeStatusFilter.active => t.isActive,
        TransactionTypeStatusFilter.inactive => !t.isActive,
      };

  void _ensureUnique(String name, {int? excludeId}) {
    for (final t in types) {
      if (t.id != excludeId && isSameTransactionTypeName(t.name, name)) {
        throw const AppException(
          AppErrorKind.duplicate,
          duplicateTransactionTypeMessage,
        );
      }
    }
  }

  @override
  Future<List<TransactionType>> getTransactionTypes({
    TransactionTypeStatusFilter status = TransactionTypeStatusFilter.active,
  }) async {
    return types.where((t) => _matches(t, status)).toList()
      ..sort((a, b) => compareTransactionTypeNames(a.name, b.name));
  }

  @override
  Future<TransactionType?> getTransactionTypeById(int id) async {
    for (final t in types) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<TransactionType> createTransactionType(String name) async {
    final normalized = normalizeTransactionTypeName(name);
    _ensureUnique(normalized);
    final created = makeType(id: _nextId, name: normalized);
    types.add(created);
    return created;
  }

  @override
  Future<TransactionType> renameTransactionType(int id, String name) async {
    final index = types.indexWhere((t) => t.id == id);
    if (index < 0) {
      throw const AppException(
        AppErrorKind.notFound,
        'İşlem tipi bulunamadı.',
      );
    }
    final normalized = normalizeTransactionTypeName(name);
    _ensureUnique(normalized, excludeId: id);
    final renamed =
        makeType(id: id, name: normalized, isActive: types[index].isActive);
    types[index] = renamed;
    return renamed;
  }

  @override
  Future<void> setTransactionTypeActive(int id, {required bool isActive}) async {
    final index = types.indexWhere((t) => t.id == id);
    if (index < 0) {
      throw const AppException(
        AppErrorKind.notFound,
        'İşlem tipi bulunamadı.',
      );
    }
    types[index] = makeType(
      id: id,
      name: types[index].name,
      isActive: isActive,
    );
  }
}
