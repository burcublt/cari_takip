import 'package:cari_takip/core/utils/text_search.dart';

const duplicateTransactionTypeMessage =
    'Bu isimde bir işlem tipi zaten mevcut.';

final _spaces = RegExp(r'\s+');

/// Başı/sonu boşlukları atar, iç boşlukları tek boşluğa indirir.
String normalizeTransactionTypeName(String name) =>
    name.trim().replaceAll(_spaces, ' ');

/// İki ad Türkçe büyük/küçük harf ve aksan farkı gözetilmeden eşitse `true`.
/// (`Borç`, `BORÇ`, `borc` aynı sayılır; SQLite NOCASE yalnızca ASCII'yi kapsar.)
bool isSameTransactionTypeName(String a, String b) =>
    TextSearch.key(a) == TextSearch.key(b);

int compareTransactionTypeNames(String a, String b) =>
    TextSearch.key(a).compareTo(TextSearch.key(b));
