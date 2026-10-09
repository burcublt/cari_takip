/// Şema v1 indexleri (CARI_TAKIP_CODEX.md §5.2 ve §6).
abstract final class DatabaseIndexes {
  static const v1 = <String>[
    'CREATE UNIQUE INDEX idx_transaction_types_name '
        'ON transaction_types(name)',
    'CREATE INDEX idx_transactions_customer '
        'ON financial_transactions(customer_id)',
    'CREATE INDEX idx_transactions_date '
        'ON financial_transactions(transaction_date)',
    'CREATE INDEX idx_transactions_type '
        'ON financial_transactions(transaction_type_id)',
    'CREATE INDEX idx_transactions_customer_date '
        'ON financial_transactions(customer_id, transaction_date)',
  ];
}
