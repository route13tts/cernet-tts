program Client;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  Setwin in 'Setwin.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := '语音转换云服务转换服务器';
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
