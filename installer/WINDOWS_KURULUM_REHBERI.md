# Cari Takip – Windows Derleme, Kurulum ve Teslim Rehberi

Bu rehber (Faz 12) Windows bilgisayarında uygulamayı derlemeyi, kurulum dosyası üretmeyi, test etmeyi ve müşteriye teslim etmeyi anlatır.

## A. Windows bilgisayarına bir kerelik hazırlık
1. **Visual Studio 2022** (Community yeterli) veya *Build Tools 2022* kur. Kurulumda **"Desktop development with C++"** iş yükünü seç (MSVC v143, Windows 10/11 SDK ve CMake dahil).
2. **Flutter 3.47.5** kur ve `flutter doctor -v` çalıştır. "Visual Studio – develop Windows apps" satırı ✓ olmalı.
3. **Git** (Flutter bunu ister).
4. **Inno Setup 6**: https://jrsoftware.org/isdl.php (varsayılan ayarlarla kur).
5. Proje klasörünü (zip'i açarak) örn. `C:\dev\cari_takip` altına koy. Yolda Türkçe karakter/boşluk olmasın.

## B. İlk deneme (kurulum dosyası üretmeden önce)
```powershell
cd C:\dev\cari_takip
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```
- **Derleme hatası alırsan** (özellikle `windows\runner\*.cpp`) çıktının tamamını bana gönder. Windows'a özel C++ değişikliklerini (aşağıdaki "Bu fazda ne değişti") burada derleyemediğim için ilk deneme onlarla ilgili olabilir.
- `flutter test` Windows'ta bazı testleri **atlar** (klasör izni testleri `chmod` kullandığı için). Bu normaldir.
- Uygulama açılınca **QA kontrol listesindeki** (`CARI_TAKIP_QA_KONTROL_LISTESI.md`) bölüm 0‑6'yı Windows sütunu için yap. Özellikle:
  - Veri klasörü: **Ayarlar → Sistem Bilgileri** bölümünde `C:\Users\<kullanıcı>\AppData\Local\CariTakip` görünmeli.
  - "Konum Seçerek Yedekle" ve "Yedekten Geri Yükle" klasör/dosya pencereleri açılmalı ve çalışmalı.
  - Uygulama tam ekran (büyütülmüş) açılmalı; pencere 920x660'tan küçültülememeli.
  - Uygulamayı **ikinci kez** açmayı dene: yeni pencere açılmamalı, mevcut pencere öne gelmeli.

## C. Kurulum dosyasını üret
```powershell
.\installer\build_windows.ps1
```
Betik sırasıyla: sürümü `pubspec.yaml`'dan okur → `flutter analyze` + `flutter test` → `flutter build windows --release` → Visual C++ çalışma zamanı DLL'lerini ekler → Inno Setup ile kurulum dosyası üretir.

Çıktı: **`installer\Output\CariTakip_Kurulum_1.0.0.exe`**

Betik, analiz veya test başarısızsa sürüm üretmeden durur. Zorunluysa `-SkipTests` verilebilir ama önerilmez.

## D. Kurulum testi (temiz bilgisayar/VM'de yap)
1. Kurulum dosyasını çalıştır: Türkçe sihirbaz, yönetici izni istemez, `%LOCALAPPDATA%\Programs\Cari Takip` altına kurar, masaüstü kısayolu seçeneği sunar.
2. **Windows SmartScreen uyarısı:** İmzasız uygulama için "Windows bilgisayarınızı korudu" çıkar → **Daha fazla bilgi → Yine de çalıştır**. Bu normaldir; müşteriye baştan söyle. (İleride kod imzalama sertifikası alınırsa kalkar.)
3. Uygulamayı aç, QA bölüm 0‑5'i hızlıca tekrarla, birkaç cari ve hareket gir.

## E. Güncelleme testi (müşteriye vermeden mutlaka yap)
1. Sürüm 1.0.0'ı kur, birkaç cari/hareket gir, bir yedek al.
2. `pubspec.yaml`'da sürümü artır: `version: 1.0.1+2`.
3. `.\installer\build_windows.ps1` ile 1.0.1 kurulum dosyasını üret.
4. 1.0.1'i **eskisinin üstüne** kur (önce kaldırma). Çalışan uygulama varsa sihirbaz kapatılmasını önerir.
5. Doğrula: **tüm veriler duruyor mu?** (QA 7.1) Sonra uygulamayı kaldırıp tekrar kur: veri klasörü silinmemiş olmalı (QA 7.2).

Güncelleme güvenliği: Sürüm şemayı değiştirirse uygulama, değişiklikten **önce** otomatik `…pre-migration…db` yedeği alır. Yedek alınamazsa şemayı değiştirmez ve veriye dokunmaz.

## F. Müşteriye teslim
- Kurulumu **kendin yap** (ilk kurulum, ilk hafta destek).
- Müşteriye şunları göster:
  1. **Yedek:** Ayarlar → *Konum Seçerek Yedekle* ile haftada en az bir kez **USB belleğe veya bulut klasörüne** yedek almalı. Otomatik yedekler aynı diskte durur; disk bozulursa onlar da gider.
  2. **Geri yükleme:** Ayarlar → *Yedekten Geri Yükle* (önce bir güvenlik yedeği alınır).
  3. Veriler yalnızca bu bilgisayarda saklanır; başka bilgisayara taşımak için yedek → geri yükleme kullanılır.
  4. Yedek dosyaları vergi no, telefon ve finans verisi içerir; güvenli saklanmalı.
- Teslim edilecekler: kurulum dosyası (`CariTakip_Kurulum_x.y.z.exe`), bu bilgilerin kısa bir özeti.

## G. Sonraki sürümler için kurallar
- Her yeni sürümde `pubspec.yaml` içindeki `version:` değerini artır (`1.0.1+2`, `1.1.0+3` …).
- `installer\cari_takip.iss` içindeki **`AppId` değerini asla değiştirme**; değişirse yeni sürüm eskisinin üstüne kurulmaz.
- Veritabanı dosya adını (`cari_takip.db`) ve veri klasörünü (`CariTakip`) değiştirme.
- Şema değişikliği her zaman `DatabaseMigrations`'a **yeni bir migration** eklenerek yapılır; mevcut migration'lar düzenlenmez.
- Sürüm üretmeden önce QA kontrol listesinin ilgili bölümlerini yeniden çalıştır.

## H. Bu fazda ne değişti (hepsi geri alınabilir)
| Dosya | Değişiklik |
|---|---|
| `windows/runner/main.cpp` | Pencere başlığı "Cari Takip"; **tek örnek koruması** (uygulama ikinci kez açılırsa mevcut pencere öne gelir). |
| `windows/runner/win32_window.cpp` | Pencere **büyütülmüş** açılır; **en küçük boyut** 920x660 (DPI'a göre ölçeklenir). |
| `windows/runner/Runner.rc` | Şirket/ürün/dosya açıklaması "Cari Takip" (örnek `com.example` kaldırıldı). |
| `macos/Runner/MainFlutterWindow.swift` | macOS'ta da en küçük pencere boyutu 920x660. |
| `installer/` | Inno Setup betiği, derleme betiği, bu rehber. |

Tek örnek koruması istemezsen `main.cpp` başındaki `single_instance` bloğunu sil.

## Sorun giderme
- **Uygulama açılmıyor / "dll eksik":** Release klasöründe `msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll` var mı bak (betik ekler). Yoksa hedef bilgisayara *Visual C++ Redistributable (x64)* kur.
- **Antivirüs uyarısı:** İmzasız uygulamalarda görülebilir; kurulum dosyasını istisnaya ekle.
- **Veriler nerede?** Ayarlar → Sistem Bilgileri → Veri klasörü. Gerekirse bu klasörü kopyalayarak manuel yedek alınabilir.
- **Bir şey ters giderse** veri klasöründeki `backups` içindeki en yeni yedeği (veya `…pre-restore…` / `…pre-migration…` dosyalarını) *Yedekten Geri Yükle* ile yükle.
