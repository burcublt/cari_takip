; Cari Takip - Inno Setup 6 kurulum betiği
;
; Derleme: installer\build_windows.ps1 betiği bunu otomatik çalıştırır.
; Elle derlemek için: Inno Setup'ta bu dosyayı açıp Build > Compile (F9).
;
; ÖNEMLİ: AppId bir kez belirlendi ve ASLA DEĞİŞTİRİLMEMELİDİR. Windows,
; "aynı uygulamanın yeni sürümü" olduğunu bu kimlikten anlar; değişirse yeni
; sürüm eskisinin üstüne kurulmaz, yan yana ayrı bir uygulama olarak kurulur.

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppName "Cari Takip"
#define MyAppExeName "cari_takip.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{692B4042-827B-4C7E-8727-16FCCB14BD6E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppName}
; Yönetici izni gerektirmeden, kullanıcının kendi profiline kurulur
; (%LOCALAPPDATA%\Programs\Cari Takip).
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\windows\runner\resources\app_icon.ico
OutputDir=Output
OutputBaseFilename=CariTakip_Kurulum_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Güncelleme sırasında çalışan uygulama varsa kapatılıp yeniden başlatılır.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

; Kaldırma yalnızca kurulum klasöründeki dosyaları siler. Müşterinin verisi
; (%LOCALAPPDATA%\CariTakip: veritabanı ve yedekler) bilerek SİLİNMEZ.
