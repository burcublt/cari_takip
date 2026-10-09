import 'package:cari_takip/core/utils/text_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('key Türkçe büyük/küçük harf ve aksan farkını yok sayar', () {
    expect(TextSearch.key('İlker'), 'ilker');
    expect(TextSearch.key('ILKER'), 'ilker');
    expect(TextSearch.key('ılker'), 'ilker');
    expect(TextSearch.key('Şule ÇAĞLAR'), 'sule caglar');
    expect(TextSearch.key('Ömer Üstün'), 'omer ustun');
  });

  test('key boşlukları sadeleştirir', () {
    expect(TextSearch.key('  Ali    Veli '), 'ali veli');
  });

  test('digits ve isPhoneLike', () {
    expect(TextSearch.digits('0532 111-22 33'), '05321112233');
    expect(TextSearch.isPhoneLike('0532 111'), isTrue);
    expect(TextSearch.isPhoneLike('+90 (532)'), isTrue);
    expect(TextSearch.isPhoneLike('ali1'), isFalse);
    expect(TextSearch.isPhoneLike(''), isFalse);
  });
}
