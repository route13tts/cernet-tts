program Server;

uses
  Forms,
  Unit1 in 'Unit1.pas' {MyForm},
  Setwin in 'Setwin.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := '����ת���Ʒ������������';
  Application.CreateForm(TMyForm, MyForm);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
