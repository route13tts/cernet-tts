unit Setwin;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FileCtrl;

type
  TForm2 = class(TForm)
    btnPathset: TButton;
    btnQuit: TButton;
    Label1: TLabel;
    DirectoryListBox1: TDirectoryListBox;
    Label2: TLabel;
    edtServerIPv6: TEdit;
    DriveComboBox1: TDriveComboBox;
    Label3: TLabel;
    edtServerIPv4: TEdit;
    procedure btnQuitClick(Sender: TObject);
    procedure btnPathsetClick(Sender: TObject);
    procedure DirectoryListBox1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form2: TForm2;

implementation

{$R *.dfm}

procedure TForm2.btnQuitClick(Sender: TObject);
begin
    Close;
end;

procedure TForm2.btnPathsetClick(Sender: TObject);
var iString:String;
    spath:String;
    listFilename:String;
    fStream1:TFileStream;
    pstr:Pchar;    
begin
//  showmessage(DirectoryListBox1.Directory);
//  ShowMessage(ExtractFilePath(Application.Exename));

    spath :=DirectoryListBox1.Directory;
    if spath[Length(spath)]<>'\' then spath:=spath+'\';
    iString:='TTsOutputDir_'+spath;

    if trim(edtServerIPv6.Text)<>'' then
    begin
      iString:=iString+','+'IPv6ServerAdd_'+edtServerIPv6.Text;
      iString:=iString+','+'IPv4ServerAdd_'+edtServerIPv4.Text;
      listFilename := ExtractFilePath(Application.Exename)+'SVINI.WHF';

      try
        fStream1:=TFileStream.Create(listFilename,fmCreate );
        pstr:=Pchar(iString);//把字符串转成字符指针
        fStream1.Writebuffer(pstr^,Length(pstr));//把字符串写入流中
      finally
        fStream1.Free;
        ShowMessage('配置保存成功');
      end;
    end
    else
      ShowMessage('服务器IPv6地址不能为空');
end;

procedure TForm2.DirectoryListBox1Click(Sender: TObject);
begin
//    showmessage( DirectoryListBox1.Directory);
end;

procedure TForm2.FormCreate(Sender: TObject);
var s1,s2:String;
    filename:String;
    fStream0: TFileStream;
    pstr:Pchar;
    tmpTxt:String;
    i,fsize:Integer;
    fF : Textfile;
begin
    filename := ExtractFilePath(Application.Exename)+'SVINI.WHF';

    try
      AssignFile(fF, FileName);
      Reset(fF);
      Readln(fF, tmpTxt);

      i := pos(',',tmpTxt);
      s1:=copy(tmpTxt,1,i-1);

      s1:=copy(s1,14,length(s1)-13);
      DirectoryListBox1.Directory:=s1;

      tmpTxt:=copy(tmpTxt,i+1,length(tmpTxt)-i);

      i:= pos(',',tmpTxt);
      //位置需要重新计算
      edtServerIPv6.Text := copy(tmpTxt,15,i-15);//获得IPv6地址
      if trim(edtServerIPv6.Text)='' then edtServerIPv6.Text:='::1';
      s2:=copy(tmpTxt,i+1,length(tmpTxt)-i);
      s2:=copy(s2,15,length(s2)-14);
      edtServerIPv4.Text:=s2;
      if trim(edtServerIPv4.Text)='' then edtServerIPv4.Text:='127.0.0.1';

    finally
//      fStream0.free;
      closeFile(fF);
    end;
end;

end.
