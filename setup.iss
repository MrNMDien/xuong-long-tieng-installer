; Bộ cài Xưởng Lồng Tiếng (Windows, gồm CrawlTool). Build bằng build.ps1, không chạy file này trực tiếp.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef BuildSha
  #define BuildSha "dev"
#endif
#ifndef Stage
  #error "Thiếu /DStage: chạy build.ps1"
#endif

#define AppName "Xưởng Lồng Tiếng"
#define Pyw "{app}\.venv\Scripts\pythonw.exe"
#define Ico "{app}\xuong\tai_nguyen\XuongLongTieng.ico"
#define Aumid "MongCanhTV.XuongLongTieng"

[Setup]
AppId={{8C3E5D7A-4B21-4F0E-9A6C-2D1B7E9F4A10}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion} ({#BuildSha})
AppPublisher=MrNMDien
DefaultDirName={localappdata}\Programs\XuongLongTieng
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=dist
OutputBaseFilename=XuongLongTieng-Setup-{#AppVersion}-{#BuildSha}
SetupIconFile={#Stage}\xuong\tai_nguyen\XuongLongTieng.ico
UninstallDisplayIcon={#Ico}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[InstallDelete]
; Xóa mã cũ trước khi chép bản mới để không sót module đã bỏ. Không đụng .env, .venv, dữ liệu phim.
Type: filesandordirs; Name: "{app}\xuong"

[Files]
Source: "{#Stage}\*"; DestDir: "{app}"; Excludes: ".env"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{userdesktop}\{#AppName}"; Filename: "{#Pyw}"; Parameters: "-m xuong app"; WorkingDir: "{app}"; IconFilename: "{#Ico}"; AppUserModelID: "{#Aumid}"
Name: "{userprograms}\{#AppName}"; Filename: "{#Pyw}"; Parameters: "-m xuong app"; WorkingDir: "{app}"; IconFilename: "{#Ico}"; AppUserModelID: "{#Aumid}"
Name: "{userprograms}\Tìm phim (CrawlTool)"; Filename: "{#Pyw}"; Parameters: "-m xuong crawl"; WorkingDir: "{app}"; IconFilename: "{#Ico}"
Name: "{userprograms}\Cài lại môi trường Xưởng"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\cai_dat\cai_moi_truong.ps1"" -ThuMucApp ""{app}"""; WorkingDir: "{app}"

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\cai_dat\cai_moi_truong.ps1"" -ThuMucApp ""{app}"" -ThuMucPhim ""{code:ThuMucPhim}"""; StatusMsg: "Đang cài Python, thư viện, FFmpeg, VieNeu (lần đầu 10–30 phút, xem cửa sổ PowerShell)..."; Flags: waituntilterminated
Filename: "{#Pyw}"; Parameters: "-m xuong app"; WorkingDir: "{app}"; Description: "Mở {#AppName}"; Flags: postinstall nowait skipifsilent

[UninstallDelete]
; Giữ lại .env (khóa API) và dữ liệu phim; xóa môi trường Python và mã.
Type: filesandordirs; Name: "{app}\.venv"
Type: filesandordirs; Name: "{app}\vieneu-env"
Type: filesandordirs; Name: "{app}\python"
Type: filesandordirs; Name: "{app}\xuong"
Type: filesandordirs; Name: "{app}\cai_dat"

[Code]
var
  TrangDuLieu: TInputDirWizardPage;

procedure InitializeWizard;
begin
  TrangDuLieu := CreateInputDirPage(wpSelectDir,
    'Thư mục dữ liệu phim',
    'Nơi lưu video gốc, sổ câu, giọng đọc và bản xuất (nên còn trống từ 15 GB).',
    'Chọn thư mục rồi bấm Next. Có thể đổi sau trong file .env (XLT_DATA_DIR).',
    False, '');
  TrangDuLieu.Add('');
  TrangDuLieu.Values[0] := GetPreviousData('ThuMucPhim', ExpandConstant('{userdocs}\XuongLongTieng_Phim'));
end;

procedure RegisterPreviousData(PreviousDataKey: Integer);
begin
  SetPreviousData(PreviousDataKey, 'ThuMucPhim', TrangDuLieu.Values[0]);
end;

function ThuMucPhim(Param: String): String;
begin
  Result := RemoveBackslashUnlessRoot(TrangDuLieu.Values[0]);
end;
