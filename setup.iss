; Bộ cài Xưởng Lồng Tiếng (Windows, gồm CrawlTool). Build bằng build.ps1, không chạy file này trực tiếp.
; /DLoai=Setup: file cài tổng (máy chưa cài). /DLoai=Patch: chỉ cập nhật mã cho máy đã cài (không gói uv.exe, không hỏi
; thư mục), dùng cho tự cập nhật và cập nhật tay khi tự cập nhật lỗi.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef BuildSha
  #define BuildSha "dev"
#endif
#ifndef Loai
  #define Loai "Setup"
#endif
#ifndef Stage
  #error "Thiếu /DStage: chạy build.ps1"
#endif

#define AppName "Xưởng Lồng Tiếng"
#define AppGuid "8C3E5D7A-4B21-4F0E-9A6C-2D1B7E9F4A10"
#define Pyw "{app}\.venv\Scripts\pythonw.exe"
; Icon tên theo bản: Windows lưu tạm icon theo đường dẫn, đổi tên mới buộc Desktop/taskbar đọc logo mới.
#define Ico "{app}\icon\xlt-" + AppVersion + ".ico"
#define Ghim "{userappdata}\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
#define Aumid "MongCanhTV.XuongLongTieng"

[Setup]
AppId={{{#AppGuid}}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion} ({#BuildSha})
AppPublisher=MrNMDien
DefaultDirName={localappdata}\Programs\XuongLongTieng
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=dist
OutputBaseFilename=XuongLongTieng-{#Loai}-{#AppVersion}-{#BuildSha}
SetupIconFile={#Stage}\xuong\tai_nguyen\XuongLongTieng.ico
UninstallDisplayIcon={#Ico}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
ChangesAssociations=yes
RestartApplications=no
#if Loai == "Patch"
DisableDirPage=yes
DisableReadyPage=yes
DisableWelcomePage=no
#endif

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[InstallDelete]
; Xóa mã cũ trước khi chép bản mới để không sót module đã bỏ. Không đụng .env, .venv, uv\, dữ liệu phim.
Type: filesandordirs; Name: "{app}\xuong"
Type: files; Name: "{app}\icon\*.ico"

[Files]
#if Loai == "Patch"
Source: "{#Stage}\*"; DestDir: "{app}"; Excludes: ".env,\uv\*"; Flags: recursesubdirs createallsubdirs ignoreversion
#else
Source: "{#Stage}\*"; DestDir: "{app}"; Excludes: ".env"; Flags: recursesubdirs createallsubdirs ignoreversion
#endif

[Files]
Source: "{#Stage}\xuong\tai_nguyen\XuongLongTieng.ico"; DestDir: "{app}\icon"; DestName: "xlt-{#AppVersion}.ico"; Flags: ignoreversion

[Icons]
Name: "{userdesktop}\{#AppName}"; Filename: "{#Pyw}"; Parameters: "-m xuong app"; WorkingDir: "{app}"; IconFilename: "{#Ico}"; AppUserModelID: "{#Aumid}"
Name: "{userprograms}\{#AppName}"; Filename: "{#Pyw}"; Parameters: "-m xuong app"; WorkingDir: "{app}"; IconFilename: "{#Ico}"; AppUserModelID: "{#Aumid}"
Name: "{userprograms}\Tìm phim (CrawlTool)"; Filename: "{#Pyw}"; Parameters: "-m xuong crawl"; WorkingDir: "{app}"; IconFilename: "{#Ico}"
; Biểu tượng đã ghim trên taskbar (ghim từ lối tắt Desktop, hoặc lối tắt cũ của windows/tao_loi_tat.ps1): ghi đè để đổi logo
Name: "{#Ghim}\{#AppName}"; Filename: "{#Pyw}"; Parameters: "-m xuong app"; WorkingDir: "{app}"; IconFilename: "{#Ico}"; AppUserModelID: "{#Aumid}"; Check: DaGhim('{#AppName}.lnk')
Name: "{#Ghim}\Xuong Long Tieng"; Filename: "{#Pyw}"; Parameters: "-m xuong app"; WorkingDir: "{app}"; IconFilename: "{#Ico}"; AppUserModelID: "{#Aumid}"; Check: DaGhim('Xuong Long Tieng.lnk')
Name: "{userprograms}\Cài lại môi trường Xưởng"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\cai_dat\cai_moi_truong.ps1"" -ThuMucApp ""{app}"""; WorkingDir: "{app}"

[Run]
; làm mới bộ nhớ icon của Windows để Desktop/taskbar hiện logo mới ngay
Filename: "{sys}\ie4uinit.exe"; Parameters: "-show"; Flags: runhidden nowait skipifdoesntexist
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\cai_dat\cai_moi_truong.ps1"" -ThuMucApp ""{app}"" -ThuMucPhim ""{code:ThuMucPhim}"""; StatusMsg: "Đang cài Python, thư viện, FFmpeg, VieNeu (lần đầu 10–30 phút, xem cửa sổ PowerShell)..."; Flags: waituntilterminated; Check: not WizardSilent
; Tự cập nhật (app chạy bộ cài với /VERYSILENT): cài môi trường không hỏi gì, rồi mở lại app
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\cai_dat\cai_moi_truong.ps1"" -ThuMucApp ""{app}"" -ThuMucPhim ""{code:ThuMucPhim}"" -TuDong"; Flags: waituntilterminated; Check: WizardSilent
Filename: "{#Pyw}"; Parameters: "-m xuong app"; WorkingDir: "{app}"; Description: "Mở {#AppName}"; Flags: postinstall nowait skipifsilent
Filename: "{#Pyw}"; Parameters: "-m xuong app"; WorkingDir: "{app}"; Flags: nowait; Check: WizardSilent

[UninstallDelete]
; Giữ lại .env (khóa API) và dữ liệu phim; xóa môi trường Python và mã.
Type: filesandordirs; Name: "{app}\.venv"
Type: filesandordirs; Name: "{app}\vieneu-env"
Type: filesandordirs; Name: "{app}\python"
Type: filesandordirs; Name: "{app}\xuong"
Type: filesandordirs; Name: "{app}\cai_dat"
Type: filesandordirs; Name: "{app}\uv"

[Code]
var
  TrangDuLieu: TInputDirWizardPage;

function DaGhim(Ten: String): Boolean;
begin
  Result := FileExists(ExpandConstant('{#Ghim}\') + Ten);
end;

function DaCai: Boolean;
begin
  Result := RegKeyExists(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{' + '{#AppGuid}' + '}_is1');
end;

function InitializeSetup: Boolean;
var
  i: Integer;
begin
  Result := True;
#if Loai == "Patch"
  if not DaCai then
  begin
    if Pos('/VERYSILENT', Uppercase(GetCmdTail)) = 0 then
      MsgBox('Máy này chưa cài Xưởng Lồng Tiếng. File patch chỉ để cập nhật máy đã cài.' + #13#10 +
             'Hãy tải và chạy file cài tổng XuongLongTieng-Setup-*.exe.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
#endif
  // App tự cập nhật: chờ cửa sổ app và máy chủ của nó thoát hẳn rồi mới chép mã mới.
  if Pos('/XLTCAPNHAT', Uppercase(GetCmdTail)) > 0 then
  begin
    i := 0;
    while (FindWindowByWindowName('{#AppName}') <> 0) and (i < 60) do
    begin
      Sleep(500);
      i := i + 1;
    end;
    Sleep(3000);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  cu, moi: String;
begin
  // Bản cũ để uv.exe trong xuong\crawl (sẽ bị xóa khi chép mã mới): dời sang <app>\uv trước.
  if CurStep = ssInstall then
  begin
    cu := ExpandConstant('{app}\xuong\crawl\uv.exe');
    moi := ExpandConstant('{app}\uv\uv.exe');
    if FileExists(cu) and not FileExists(moi) then
    begin
      ForceDirectories(ExtractFileDir(moi));
      RenameFile(cu, moi);
    end;
  end;
end;

function ThuMucPhim(Param: String): String;
begin
#if Loai == "Setup"
  Result := RemoveBackslashUnlessRoot(TrangDuLieu.Values[0]);
#else
  Result := GetPreviousData('ThuMucPhim', '');
#endif
end;

procedure RegisterPreviousData(PreviousDataKey: Integer);
begin
  SetPreviousData(PreviousDataKey, 'ThuMucPhim', ThuMucPhim(''));
end;

procedure InitializeWizard;
begin
#if Loai == "Setup"
  TrangDuLieu := CreateInputDirPage(wpSelectDir,
    'Thư mục dữ liệu phim',
    'Nơi lưu video gốc, sổ câu, giọng đọc và bản xuất (nên còn trống từ 15 GB).',
    'Chọn thư mục rồi bấm Next. Có thể đổi sau trong tab Cài đặt.',
    False, '');
  TrangDuLieu.Add('');
  TrangDuLieu.Values[0] := GetPreviousData('ThuMucPhim', ExpandConstant('{userdocs}\XuongLongTieng_Phim'));
#endif
end;

