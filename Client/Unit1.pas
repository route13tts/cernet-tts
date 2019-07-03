unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  ExtCtrls, StdCtrls, ComCtrls, XPMan, SpeechLib_TLB, OleServer,SyncObjs,winsock,IdGlobal,
  Menus, TrayIcon,ShellAPI;

//�����е�winsock�����ڻ�ȡ����IP��ַ�����

//���ڵ��ò���ϵͳCUP�����ʵ����Ͷ���
type
_SYSTEM_PERFORMANCE_INFORMATION = record    //��ȡCUP��ʹ�������
    IdleTime: LARGE_INTEGER;
    Reserved: array[0..75] of DWORD;
end;

PSystemPerformanceInformation = ^TSystemPerformanceInformation;    //��ȡCUP��ʹ�������
TSystemPerformanceInformation = _SYSTEM_PERFORMANCE_INFORMATION;

_SYSTEM_BASIC_INFORMATION = record        //��ȡCUP��ʹ�������
    Reserved1: array[0..23] of Byte;
    Reserved2: array[0..3] of Pointer;
    NumberOfProcessors: UCHAR;
end;

PSystemBasicInformation = ^TSystemBasicInformation;  //��ȡCUP��ʹ�������
TSystemBasicInformation = _SYSTEM_BASIC_INFORMATION;

_SYSTEM_TIME_INFORMATION = record                   //��ȡCUP��ʹ�������
    KeBootTime: LARGE_INTEGER;
    KeSystemTime: LARGE_INTEGER;
    ExpTimeZoneBias: LARGE_INTEGER;
    CurrentTimeZoneId: ULONG;
end;
PSystemTimeInformation = ^TSystemTimeInformation;    //��ȡCUP��ʹ�������
TSystemTimeInformation = _SYSTEM_TIME_INFORMATION;

type
  TMyTTSThread = class(TThread) //����һ�����ڿɽ��û��ͻ��˴���Ķ��̷߳�����
  private
     { Private declarations }
    FLockUser: TCriticalSection;
    TTStr:String;
    TTSFileName:String;
    procedure LockUser;
    procedure UnlockUser;
    procedure Execute; override;
    procedure TTSTxt;   //ͨ���߳����ȷ���ɽ��յ��ն��û��󣬷��ͱ�ת����ļ�
  public
    constructor Create(const sFilename,TxtStr: string); reintroduce;
    destructor Destroy; override;
//    property  MemMsg: string read Msg write Msg;
  end;


//******************************//
//ϵͳ�Լ������Ĵ������Ͷ���
type
  TForm1 = class(TForm)
    IdTCPClient: TIdTCPClient;
    btnConnect: TButton;
    tmrCheckServerMsg: TTimer;
    btnDisconect: TButton;
    edtMsg: TEdit;
    pbProgress: TProgressBar;
    mmoInfo: TMemo;
    XPManifest1: TXPManifest;
    ipEdit: TEdit;
    Timer1: TTimer;
    btnTimeStart: TButton;
    Label1: TLabel;
    SpVoice1: TSpVoice;
    SpFileStream1: TSpFileStream;
    Button1: TButton;
    checkTTSFinishTimer: TTimer;
    TTSTimer: TTimer;
    Label3: TLabel;
    Label4: TLabel;
    Button2: TButton;
    TrayIcon1: TTrayIcon;
    PopupMenu1: TPopupMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    Label2: TLabel;
    Label5: TLabel;
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconectClick(Sender: TObject);
    procedure edtMsgKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure IdTCPClientWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount:
      Int64);
    procedure tmrCheckServerMsgTimer(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure btnTimeStartClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ShowForm(AFormClass:TFormClass);
    procedure checkTTSFinishTimerTimer(Sender: TObject);
    procedure myTTS(sFilename:String);
    procedure N2Click(Sender: TObject);
    procedure N1Click(Sender: TObject);
    procedure N3Click(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure Button2Click(Sender: TObject);//;wayFlag:Short);
  private
    { Private declarations }
    wayFlag:Short; //����ת���ļ���Դ���ź�����1��ʾֱ�ӽ��յ���ת����2��ʾ�ڵȴ��б��е��ļ�����
    TTSFinished:Boolean;

  public
    { Public declarations }
  end;

function NtQuerySystemInformation(
    SystemInformationClass: UINT;
    SystemInformation: Pointer;
    SystemInformationLength: ULONG;
    ReturnLength: PULONG): Integer; stdcall; external 'ntdll.dll'

var
  Form1: TForm1;
  FOldIdleTime: LARGE_INTEGER;    //���ڻ�ȡϵͳCPU����ʱ��ı���
  FOldSystemTime: LARGE_INTEGER;  //���ڻ�ȡϵͳʱ��ı���

  TransSingle:boolean;
  OutputFilePath :String;

implementation

uses TypInfo, Setwin;

{$R *.dfm}

//ִ��һ���ⲿwindows����
procedure runCMD(cmdStr:String);
begin
  winexec(pchar(cmdStr),sw_hide);
//  sleep(100);
end;

//����ڴ�ʹ����
function GetMemoryUsage : Double;
{
�����ڴ浱ǰʹ���� �ܵ���100%�����ص���0-100%���ʹ���ʣ������Լ���ת����
}
Var
     msMemory : TMemoryStatus;
begin
     try
       msMemory.dwLength := SizeOf(msMemory);
       GlobalMemoryStatus(msMemory);
       Result := msMemory.dwMemoryLoad;
     except
       Result := 0;
     end;
end;


//��ȡCUP��ʹ����
function GetCPURate: Byte;
var
  PerfInfo: TSystemPerformanceInformation;
  TimeInfo: TSystemTimeInformation;
  BaseInfo: TSystemBasicInformation;
  IdleTime: INT64;
  SystemTime: INT64;
begin
  Result := 0;
  if NtQuerySystemInformation(3, @TimeInfo, SizeOf(TimeInfo), nil) <> NO_ERROR then
    Exit;
  if NtQuerySystemInformation(2, @PerfInfo, SizeOf(PerfInfo), nil) <> NO_ERROR then
    Exit;
  if NtQuerySystemInformation(0, @BaseInfo, SizeOf(BaseInfo), nil) <> NO_ERROR then
    Exit;
  if (FOldIdleTime.QuadPart <> 0) and (BaseInfo.NumberOfProcessors <> 0) then
  begin
    IdleTime := PerfInfo.IdleTime.QuadPart - FOldIdleTime.QuadPart;
    SystemTime := TimeInfo.KeSystemTime.QuadPart - FOldSystemTime.QuadPart;
    if SystemTime <> 0 then
      Result := Trunc(100.0 - (IdleTime / SystemTime) * 100.0 / BaseInfo.NumberOfProcessors);
  end;
  FOldIdleTime := PerfInfo.IdleTime;
  FOldSystemTime := TimeInfo.KeSystemTime;
end;

function GetDiskInfo(CurrentDriver:char):string;    // ��ȡӲ����Ϣ
var str:string;
//    Drivers:Integer;
//    driver:char;
//    i,temp:integer;
    d1,d2,d3,d4: DWORD;       //
    ss:string;
begin
  ss:='';
//  Drivers:=GetLogicalDrives;
//  temp:=(1 and Drivers);
//  for i:=0 to 26 do    //���Ի��26�����̵Ĵ�С
//  begin
//    if temp=1 then
//    begin
//      driver:=char(i+integer('A'));
      result:='';
      if CurrentDriver ='' then exit;
      str:=CurrentDriver+':';
      if (CurrentDriver<>'') and (getdrivetype(pchar(str))<>drive_cdrom) and (getdrivetype(pchar(str))<>DRIVE_REMOVABLE) then
      begin
        GetDiskFreeSpace(pchar(str),d1,d2,d3,d4);
        ss:=ss+str+Format('capacity: %f GB,',[d4/1024/1024/1024*d2*d1])+Format('Last capacity: %f GB',[d3/1024/1024/1024*d2*d1])+#13#10;
      end;
//    end;
    //��ʾ�����C:����:  30.01 GB,ʣ������: 8.01 GB
//    drivers:=(drivers shr 1);
//    temp:=(1 and Drivers);
//  end;
  result:=ss;
end;

//��ȡIP��ַ
function GetLocalIP:string;
type
   TaPInAddr = array [0..10] of PInAddr;   //���ڴ洢���ip��ַ�б�
   PaPInAddr = ^TaPInAddr;
var
  phe  : PHostEnt;
  pptr : PaPInAddr;
  Buffer : array [0..63] of char;    //store hostname
  I: Integer;
  GInitData: TWSADATA;
  wVersion:word;
begin
  wVersion:=MAKEWORD(1,1);     //winsock dll version
  Result :=''; phe:=nil;
  if WSAStartup(wVersion, GInitData)=0 then   //��ʼ��windows socket
  begin
    if GetHostName(Buffer, SizeOf(Buffer))=0 then  //���������
        phe :=GetHostByName(buffer);
    if phe = nil then
       Exit;
    pptr := PaPInAddr(Phe^.h_addr_list);
    I := 0;
    while pptr^[I] <> nil do begin
      result:=StrPas(inet_ntoa(pptr^[I]^));
      Inc(I);
    end;
    WSACleanup;           //�رա�����windows socket
  end;
  //��Դ��Ĳ���ĵط��������������2�ż������������õ��������һ����
end;

procedure Delay(msecs:integer);
var
  FirstTickCount:longint;
begin
  FirstTickCount:=GetTickCount;
  repeat
    Application.ProcessMessages;
  until ((GetTickCount-FirstTickCount) >= Longint(msecs));
end;


{TMyTTSThread Start}
procedure TMyTTSThread.LockUser;
begin
  FLockUser.Enter;
end;

procedure TMyTTSThread.UnlockUser;
begin
  FLockUser.Leave;
end;

constructor TMyTTSThread.Create(const sFilename,TxtStr: string);
begin
  TTStr:= txtStr;
  TTSFileName := sFilename;
  FLockUser := TCriticalSection.Create;
  FreeOnTerminate:=True; {��������߳������˻��Զ�ע��}
  inherited Create(False);
end;

destructor TMyTTSThread.Destroy;
begin
  FLockUser.Free;
  inherited;
end;

procedure TMyTTSThread.Execute;
begin
  TTSTxt;
end;

procedure TMyTTSThread.TTSTxt;//( var sFileName,txtStr: String);
var sFilename:String;
    SpVoice1: TSpVoice;
    SpFileStream1: TSpFileStream;
begin
  sFilename:=copy(TTSFileName,1,length(TTSFileName)-4)+'.wav';
  try
    SpFileStream1.Format.Type_:=SAFT32KHz8BitMono;
    SpFileStream1.Open(sFilename,SSFMCreateForWrite,False);
    SpVoice1.AllowAudioOutputFormatChangesOnNextSet:=false;
    Spvoice1.AudioOutputStream:=SpFilestream1.defaultInterface;

    Spvoice1.Speak(TTStr,1);
    SpVoice1.waitUntilDone(-1);
  finally  //��Ҫ���Ӵ������ͷ��ļ�����ָ��
    Spfilestream1.close;
    Spvoice1.AudioOutputStream:=nil;

  end;
end;

{TMyTTSThread end}
//**********************************//


//����ϵͳ���ɵĳ����//
procedure TForm1.btnConnectClick(Sender: TObject);
var
  Response: string;
  UserName: string;
begin
  IdTCPClient.ConnectTimeout := 5000;

  if trim(ipEdit.Text)<>'' then
  begin
    if Pos(':',ipEdit.Text)>0 then
    begin
      IdTCPClient.IPVersion := Id_IPv6;
      IdTCPClient.Host := Trim(ipEdit.Text);
      IdTCPClient.Port := 30303;
    end
    else
    begin
      IdTCPClient.IPVersion := Id_IPv4;
      IdTCPClient.Host := ipEdit.Text;
      IdTCPClient.Port := 30304;
    end;
//  IdTCPClient.Host:=ipEdit.Text;
    if not idTCPClient.Connected then
    begin
      try
        IdTCPClient.Connect;
        UserName := Format('U%.5d', [Random(99999)]);
        IdTCPClient.IOHandler.WriteLn(UserName);

        Response := IdTCPClient.IOHandler.ReadLn;  //��ȡ���ӳɹ�����������ص�����״̬

        if SameText(Response, 'LOGINED') then
        begin
          btnDisconect.Enabled := True;
          btnConnect.Enabled := False;
          tmrCheckServerMsg.Enabled := True;
          Caption := '����ת���Ʒ���ת�������� - ' + UserName;
        end
        else raise Exception.CreateFmt('��¼ʧ��: "%s"', [Response]);
      except
        ShowMessage('���������Ӳ��ϣ������������ַ��ȷ');
      end;
    end;
  end
  else
    ShowMessage('û����д������IP��ַ,������Ч');
end;

procedure TForm1.btnDisconectClick(Sender: TObject);
begin
  btnConnect.Enabled := True;
  btnDisconect.Enabled := False;
  tmrCheckServerMsg.Enabled := False;
  Caption := '����ת���Ʒ���ת��������';
  IdTCPClient.Disconnect;
  checkTTSFinishTimer.Enabled:=false;
end;

procedure TForm1.edtMsgKeyDown(Sender: TObject; var Key: Word; Shift:
  TShiftState);
begin
  if Key = VK_RETURN then
  begin
    if not IdTCPClient.Connected then Exit;
    if edtMsg.Text <> '' then
    begin
      IdTCPClient.IOHandler.WriteLn(edtMsg.Text);
      mmoInfo.Lines.Add(Format('������Ϣ: "%s"', [edtMsg.Text]));
      edtMsg.Clear;
    end;
    Key := 0;
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  try
    if IdTCPClient.Connected then
      btnDisconect.Click;
  except
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var s1,s2:String;
    filename:String;
//    fStream0: TFileStream;
//    pstr:Pchar;
    tmpTxt:String;
    i,fsize:Integer;
    fF : Textfile;
begin
  Randomize;
//  IdTCPClient.IPVersion := Id_IPv4;
//  IdTCPClient.Host := '127.0.0.1';//'202.201.140.169';//'127.0.0.1';

  IdTCPClient.IPVersion := Id_IPv6;
  IdTCPClient.Host := 'fe80::455:ce5d:2c2a:d2a4';//'202.201.140.169';//'127.0.0.1';
  IdTCPClient.Port := 3030;
  TransSingle :=false; //��ʼ��ת���ź�����0����û������ת�������ݣ�1����������ת��������

    filename := ExtractFilePath(Application.Exename)+'DBINI.WHF';
    try

      AssignFile(fF, FileName);
      Reset(fF);
      Readln(fF, tmpTxt);

//      fStream0 := TFileStream.Create(fileName, fmOpenRead or  fmShareDenyWrite);
//      fsize :=  fStream0.Size;


//      getmem(pstr,fsize);//�����ַ�ָ���ڴ�
//      tmpTxt := strPas(pStr);
      i := pos(',',tmpTxt);
      s1:=copy(tmpTxt,1,i-1);

      s1:=copy(s1,14,length(s1)-13);
      OutputFilePath:=s1;
      Label5.Caption := OutputFilepath;
      s2:=copy(tmpTxt,i+1,length(tmpTxt)-i);

      s2:=copy(s2,15,length(s2)-14);
      ipEdit.Text:=s2;
    finally
//      fStream0.free;
      CloseFile(fF);
    end;

end;

procedure TForm1.IdTCPClientWork(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
begin
  pbProgress.Position := AWorkCount;
  Application.ProcessMessages;
end;

type
  TSizeType = (stB, stK, stM, stG, stT);

function FormatFileSize(Size: Extended; MaxSizeType: TSizeType; var ReturnSizeType: TSizeType;
  const IncludeComma: Boolean = True): string; overload;
const
  FormatStr: array[Boolean] of string = ('0.##', '#,##0.##'); {do not localize}
var
  DivCount: Integer;
begin
  ReturnSizeType := stB;
  DivCount := 0;
  while (Size >= 1024) and (ReturnSizeType <> MaxSizeType) do
  begin
    Size := Size / 1024;
    Inc(DivCount);
    case DivCount of
      1: ReturnSizeType := stK;
      2: ReturnSizeType := stM;
      3: ReturnSizeType := stG;
      4: ReturnSizeType := stT;
    end;
  end;
  Result := FormatFloat(FormatStr[IncludeComma], Size);
end;

function FormatFileSize(Size: Extended; MaxSizeType: TSizeType;
  const IncludeComma: Boolean = True): string; overload;
resourcestring
  RSC_BYTE = '�ֽ�';
var
  ReturnSt: TSizeType;
begin
  Result := FormatFileSize(Size, stT, ReturnSt, True) + ' ' +
    Copy(GetEnumName(TypeInfo(TSizeType), Ord(ReturnSt)), 3, 1);
  if ReturnSt = stB then
  begin
    Delete(Result, Length(Result), 1);
    Result := Result + RSC_BYTE;
  end
  else
    Result := Result + 'B'; {do not localize}
end;

procedure TForm1.tmrCheckServerMsgTimer(Sender: TObject);
var
  CmdStr: string;
  FSize: Int64;
  FStream: TFileStream;
  SaveFileName: string;
  sFilename:String;
  stmp:String;  //Ҫ����wav�ļ����ı�
  ss:String;    //���ı��ļ��ж�����ÿһ�е�����
  txt:TextFile; //���򿪵��ı��ļ��ľ��
  wayOne:Short;
//  clientTTS:TMyTTSThread;
//  fStream:TFileStream:
begin
  CmdStr := '';sFilename:='';ss:='';
  if IdTCPClient.Connected then
  begin
    IdTCPClient.IOHandler.CheckForDataOnSource(250);
    if not IdTCPClient.IOHandler.InputBufferIsEmpty then
    begin
      tmrCheckServerMsg.Enabled := False;
      try
        CmdStr := IdTCPClient.IOHandler.ReadLn;
        if SameText(Copy(CmdStr, 1, 4), 'FILE') then
        begin
          SaveFileName := Trim(Copy(CmdStr, 5, Length(CmdStr)));
          mmoInfo.Lines.Add('׼�������ļ�....');
          IdTCPClient.IOHandler.WriteLn('SIZE');
          FSize := IdTCPClient.IOHandler.ReadInt64(False);
          if FSize > 0 then
          begin
            pbProgress.Max := FSize;
            pbProgress.Position := 0;
            mmoInfo.Lines.Add('�ļ���С =' + FormatFileSize(FSize, stK) + '; ���ڽ�����...');
            IdTCPClient.IOHandler.WriteLn('READY');
            while True do
            begin
              if FileExists(ExtractFilePath(ParamStr(0)) + SaveFileName) then
                 SaveFileName := '~' + SaveFileName
              else Break;
            end;
            FStream := TFileStream.Create(ExtractFilePath(ParamStr(0))
              + SaveFileName,
              fmCreate);

            sFilename:= ExtractFilePath(ParamStr(0))+ SaveFileName;
//            mmoInfo.Lines.Add('lala'+sFilename);
            try
              IdTCPClient.IOHandler.LargeStream := True;
              IdTCPClient.IOHandler.ReadStream(FStream, FSize);
              IdTCPClient.IOHandler.LargeStream := False;
              IdTCPClient.IOHandler.WriteLn('OK');
              if IdTCPClient.IOHandler.ReadLn = 'DONE' then
                mmoInfo.Lines.Add('�������')
            finally
              FStream.Free;
            end;
{
            stmp:='';//'׼�����������ļ�';
            AssignFile(txt,sFilename);
            Reset(txt);   //�����ļ����ļ�ָ���Ƶ���

            while not Eof(txt) do
            begin
              Readln(txt,ss);
              stmp:=stmp+ss;  //Memo1.Lines.Add(ss);
            end;
            CloseFile(txt);
}

//            TTSTimer.Enabled:=true;
            wayFlag:=1;

            tmrCheckServerMsg.Enabled := True;
            myTTS(sFilename);//,wayOne);
            //�����Ƿ��б�ת�����ļ�����ִ��
{
            sFilename:=copy(sFilename,1,length(sFilename)-4)+'.wav';
            try
              SpFileStream1.Format.Type_:=SAFT32KHz8BitMono;
              SpFileStream1.Open(sFilename,SSFMCreateForWrite,False);
              SpVoice1.AllowAudioOutputFormatChangesOnNextSet:=false;
              Spvoice1.AudioOutputStream:=SpFilestream1.defaultInterface;

              Spvoice1.Speak(stmp,1);
//              showmessage(stmp);
              WaitForSingleObject(SpVoice1.SpeakCompleteEvent,1000);
              timer2.Enabled:=true;
//              SpVoice1.waitUntilDone(5000);
//              SpVoice1.SpeakCompleteEvent;
            finally  //��Ҫ���Ӵ������ͷ��ļ�����ָ��
              Spfilestream1.close;
              Spvoice1.AudioOutputStream:=nil;
            end;
}
          end
          else begin
            mmoInfo.Lines.Add('ȡ��...');
            IdTCPClient.IOHandler.WriteLn('CANCEL');
          end;
        end
        else
          mmoInfo.Lines.Add('������������Ϣ: ' + CmdStr)
      finally
        tmrCheckServerMsg.Enabled := True;
      end;
    end;
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
    Timer1.Interval:=Random(1000);
    edtMsg.Text:=Form1.Caption+IntToStr(Timer1.Interval)+'CPU:'+IntToStr(GetCPURate)+Format('RAM: %f',[GetMemoryUsage]);

    if not IdTCPClient.Connected then Exit;
    if edtMsg.Text <> '' then
    begin
      IdTCPClient.IOHandler.WriteLn(edtMsg.Text);
      mmoInfo.Lines.Add(Format('������Ϣ: "%s"', [edtMsg.Text]));

      edtMsg.Clear;
    end;


end;

procedure TForm1.btnTimeStartClick(Sender: TObject);
var
    st:String;
begin
    st:='This is a TTS engine test.����һ��TTS�����������';
//    Timer1.Enabled:=not timer1.Enabled;
    try
      SpVoice1.speak(st, 1);
      SpVoice1.WaitUntilDone(-1); //ͣ��
      MessageDlg('����ת��������������', mtInformation, [mbOK], 0);
    except
      MessageDlg('�����ṩ��Ч������ת��������˲�ϵͳ�����Ƿ�װ��������ȷ��', mtError, [mbOK], 0);
    end;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  ShowForm( Tform2 );
end;

Procedure TForm1.ShowForm(AFormClass:TFormClass);
begin
  With AFormClass.Create(Self) do
  try
    ShowModal;
  finally
    Free;
  end;
End;

procedure TForm1.myTTS(sFilename:String);//;wayFlag:Short);
//var SpVoice1: TSpVoice;
//    SpFileStream1: TSpFileStream;
var
    stmp,ss,cmdStr:String;
    txt:TextFile; //���򿪵��ı��ļ��ľ��
    wavFilename:String;
begin
    stmp:='';//'׼�����������ļ�';
    AssignFile(txt,sFilename);
    Reset(txt);   //�����ļ����ļ�ָ���Ƶ���

    while not Eof(txt) do
    begin
      Readln(txt,ss);
      stmp:=stmp+ss;  //Memo1.Lines.Add(ss);
    end;
    CloseFile(txt);
    ss:= sFilename;
    sFilename:=copy(sFilename,1,length(sFilename)-4)+'.wav';
    wavFilename:=OutputFilepath + copy(sFilename,length(sFilename)-22+1,18)+'.wav';
//    TTSTimer.Enabled:=false;

    if not checkTTSFinishTimer.Enabled then
    begin
      try
        TTSFinished:=false;  //��ǰû�����ת��ʱ���ź���Ϊfalse
        checkTTSFinishTimer.Enabled := true;

        SpFileStream1.Format.Type_:=SAFT32KHz8BitMono;
        SpFileStream1.Open(wavFilename,SSFMCreateForWrite,False);
        SpVoice1.AllowAudioOutputFormatChangesOnNextSet:=false;
        Spvoice1.AudioOutputStream:=SpFilestream1.defaultInterface;

        Spvoice1.Speak(stmp,1);
        SpVoice1.WaitUntilDone(-1);
        TTSFinished:=true;   //��ǰ���ת������ź�������Ϊtrue
//        checkTTSFinishTimer.Enabled:=true;

      finally
        Spfilestream1.close;
        Spvoice1.AudioOutputStream:=nil;
        cmdStr:='lame '+wavFilename+' '+OutputFilepath+copy(sFilename,length(sFilename)-22+1,18)+'.mp3';

        runCMD(cmdStr);
        deletefile(ss);  //ɾ��ת��ԭ�ı��ļ�
//        deletefile(wavFilename);  //ɾ��ת������.wav�ļ�
      end;
    end
    else
    begin
      sFilename:=copy(sFilename,1,length(sFilename)-4)+'.txt';
//      waitFileList.Lines.Add(sFilename);
      Application.ProcessMessages;
    end;

//  finally  //��Ҫ���Ӵ������ͷ��ļ�����ָ��
//    Spfilestream1.close;
//    Spvoice1.AudioOutputStream:=nil;
//  end;
end;


procedure TForm1.checkTTSFinishTimerTimer(Sender: TObject);
var sPath:String;
begin
    if TTSFinished then //���ݵ�ǰ�ļ��Ƿ�ת����ɣ��������ڵȴ��б���ѡ���ת�����ļ�
    begin
     checkTTSFinishTimer.Enabled :=false;
//     tmrCheckServerMsg.Enabled:=true;
//     if waitFileList.Lines.Count>0 then
//     begin
//       if wayFlag=2 then waitFileList.Lines.Delete(0);
//       sPath:=waitFileList.Lines[0];
//       wayFlag:=2;
//       myTTS(sPath);//,oneWay);
//     end;
  end;
end;

procedure TForm1.N2Click(Sender: TObject);
begin
    if Application.MessageBox('�Ƿ�����˳���','����ת���Ʒ���ת��������',mb_OKcancel +
                                  mb_DefButton1 + mb_ICONQUESTION )= IDOK then

       Close;
end;

procedure TForm1.N1Click(Sender: TObject);
begin
  Form1.Visible := true;
  WindowState := wsNormal;
end;

procedure TForm1.N3Click(Sender: TObject);
begin
  WindowState := wsMinimized;
  Form1.Visible := false;
end;

procedure TForm1.TrayIcon1DblClick(Sender: TObject);
begin
  TrayIcon1.ShowBalloonHint;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  WindowState := wsMinimized;
  Form1.Visible := false;
end;

end.

