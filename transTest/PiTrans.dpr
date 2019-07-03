library PiTrans;

uses
  ActiveX,
  ComObj,
  WebBroker,
  ISAPIThreadPool,
  ISAPIApp,
  iTrans in 'iTrans.pas' {WebModule1: TWebModule},
  iTransImpl in 'iTransImpl.pas',
  iTransIntf in 'iTransIntf.pas',
  util_utf8 in 'util_utf8.pas',
  AES in 'AES.pas',
  ElAES in 'ElAES.pas';

{$R *.res}

exports
  GetExtensionVersion,
  HttpExtensionProc,
  TerminateExtension;

begin
  CoInitFlags := COINIT_MULTITHREADED;
  Application.Initialize;
  Application.CreateForm(TWebModule1, WebModule1);
  Application.Run;
end.
