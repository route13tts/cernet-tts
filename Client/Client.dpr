program Client;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  Setwin in 'Setwin.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := '����ת���Ʒ���ת��������';
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
