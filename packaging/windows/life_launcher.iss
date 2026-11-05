; Inno Setup — LifeOS Windows 安装程序（由 desktop.yml 传入 /DAppVersion=）
#define MyAppName "LifeOS"
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#define MyAppExeName "life_launcher.exe"
#define MyAppPublisher "ZH Cloud"
#define MyAppURL "https://zh04.com"
#define MyOutputBase "lifeos-flutter-{#AppVersion}-x86_64"

[Setup]
AppId={{7C2E9A4B-1D3F-4E58-9B6A-8E0D2F7C5A11}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\LifeOS
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename={#MyOutputBase}
OutputDir=..\..\.gha-dist\desktop
Compression=lzma2
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\apps\life_launcher\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
