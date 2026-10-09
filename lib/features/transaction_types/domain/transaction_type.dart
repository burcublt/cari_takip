enum TransactionTypeStatusFilter { active, inactive, all }

class TransactionType {
  const TransactionType({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}
