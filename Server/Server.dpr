program Server;

uses
  Forms,
  Unit1 in 'Unit1.pas' {MyForm},
  Setwin in 'Setwin.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := '语音转换云服务任务服务器';
  Application.CreateForm(TMyForm, MyForm);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
