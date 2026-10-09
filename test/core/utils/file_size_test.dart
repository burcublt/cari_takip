import 'package:cari_takip/core/utils/file_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatFileSize bayt, KB, MB ve GB biçimleri', () {
    expect(formatFileSize(0), '0 B');
    expect(formatFileSize(1023), '1023 B');
    expect(formatFileSize(1024), '1,0 KB');
    expect(formatFileSize(1536), '1,5 KB');
    expect(formatFileSize(5 * 1024 * 1024), '5,0 MB');
    expect(formatFileSize(3 * 1024 * 1024 * 1024), '3,0 GB');
  });
}
