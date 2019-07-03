unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  ExtCtrls, StdCtrls, ComCtrls, XPMan, SpeechLib_TLB, OleServer,SyncObjs,winsock,IdGlobal,
  Menus, TrayIcon,ShellAPI;

//上行中的winsock是用于获取网卡IP地址引入的

//用于调用操作系统CUP利用率的类型定义
type
_SYSTEM_PERFORMANCE_INFORMATION = record    //获取CUP的使用率相关
    IdleTime: LARGE_INTEGER;
    Reserved: array[0..75] of DWORD;
end;

PSystemPerformanceInformation = ^TSystemPerformanceInformation;    //获取CUP的使用率相关
TSystemPerformanceInformation = _SYSTEM_PERFORMANCE_INFORMATION;

_SYSTEM_BASIC_INFORMATION = record        //获取CUP的使用率相关
    Reserved1: array[0..23] of Byte;
    Reserved2: array[0..3] of Pointer;
    NumberOfProcessors: UCHAR;
end;

PSystemBasicInformation = ^TSystemBasicInformation;  //获取CUP的使用率相关
TSystemBasicInformation = _SYSTEM_BASIC_INFORMATION;

_SYSTEM_TIME_INFORMATION = record                   //获取CUP的使用率相关
    KeBootTime: LARGE_INTEGER;
    KeSystemTime: LARGE_INTEGER;
    ExpTimeZoneBias: LARGE_INTEGER;
    CurrentTimeZoneId: ULONG;
end;
PSystemTimeInformation = ^TSystemTimeInformation;    //获取CUP的使用率相关
TSystemTimeInformation = _SYSTEM_TIME_INFORMATION;

type
  TMyTTSThread = class(TThread) //定义一个用于可将用户客户端传输的多线程服务类
  private
     { Private declarations }
    FLockUser: TCriticalSection;
    TTStr:String;
    TTSFileName:String;
    procedure LockUser;
    procedure UnlockUser;
    procedure Execute; override;
    procedure TTSTxt;   //通过线程随机确定可接收的终端用户后，发送被转译的文件
  public
    constructor Create(const sFilename,TxtStr: string); reintroduce;
    destructor Destroy; override;
//    property  MemMsg: string read Msg write Msg;
  end;


//******************************//
//系统自己创建的窗口类型定义
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
    wayFlag:Short; //保存转换文件来源的信号量，1表示直接接收到后转换，2表示在等待列表中的文件名称
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
  FOldIdleTime: LARGE_INTEGER;    //用于获取系统CPU运行时间的变量
  FOldSystemTime: LARGE_INTEGER;  //用于获取系统时间的变量

  TransSingle:boolean;
  OutputFilePath :String;

implementation

uses TypInfo, Setwin;

{$R *.dfm}

//执行一个外部windows命令
procedure runCMD(cmdStr:String);
begin
  winexec(pchar(cmdStr),sw_hide);
//  sleep(100);
end;

//获得内存使用率
function GetMemoryUsage : Double;
{
返回内存当前使用率 总的是100%，传回的是0-100%间的使用率，可以自己做转换。
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


//获取CUP的使用率
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

function GetDiskInfo(CurrentDriver:char):string;    // 获取硬盘信息
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
//  for i:=0 to 26 do    //尝试获得26个磁盘的大小
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
    //显示结果：C:容量:  30.01 GB,剩余容量: 8.01 GB
//    drivers:=(drivers shr 1);
//    temp:=(1 and Drivers);
//  end;
  result:=ss;
end;

//获取IP地址
function GetLocalIP:string;
type
   TaPInAddr = array [0..10] of PInAddr;   //用于存储活动的ip地址列表
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
  if WSAStartup(wVersion, GInitData)=0 then   //初始化windows socket
  begin
    if GetHostName(Buffer, SizeOf(Buffer))=0 then  //计算机名称
        phe :=GetHostByName(buffer);
    if phe = nil then
       Exit;
    pptr := PaPInAddr(Phe^.h_addr_list);
    I := 0;
    while pptr^[I] <> nil do begin
      result:=StrPas(inet_ntoa(pptr^[I]^));
      Inc(I);
    end;
    WSACleanup;           //关闭、清理windows socket
  end;
  //该源码的不足的地方是如果机器上有2张及以上网卡，得到的是最后一个。
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
  FreeOnTerminate:=True; {加上这句线程用完了会自动注释}
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
  finally  //需要增加错误处理，释放文件操作指针
    Spfilestream1.close;
    Spvoice1.AudioOutputStream:=nil;

  end;
end;

{TMyTTSThread end}
//**********************************//


//程序系统生成的程序段//
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

        Response := IdTCPClient.IOHandler.ReadLn;  //读取链接成功后服务器返回的链接状态

        if SameText(Response, 'LOGINED') then
        begin
          btnDisconect.Enabled := True;
          btnConnect.Enabled := False;
          tmrCheckServerMsg.Enabled := True;
          Caption := '语音转换云服务转换服务器 - ' + UserName;
        end
        else raise Exception.CreateFmt('登录失败: "%s"', [Response]);
      except
        ShowMessage('服务器链接不上，请检查服务器地址正确');
      end;
    end;
  end
  else
    ShowMessage('没有填写服务器IP地址,连接无效');
end;

procedure TForm1.btnDisconectClick(Sender: TObject);
begin
  btnConnect.Enabled := True;
  btnDisconect.Enabled := False;
  tmrCheckServerMsg.Enabled := False;
  Caption := '语音转换云服务转换服务器';
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
      mmoInfo.Lines.Add(Format('发送消息: "%s"', [edtMsg.Text]));
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
  TransSingle :=false; //初始化转换信号量，0代表没有正在转换的数据，1代表有正在转换的数据

    filename := ExtractFilePath(Application.Exename)+'DBINI.WHF';
    try

      AssignFile(fF, FileName);
      Reset(fF);
      Readln(fF, tmpTxt);

//      fStream0 := TFileStream.Create(fileName, fmOpenRead or  fmShareDenyWrite);
//      fsize :=  fStream0.Size;


//      getmem(pstr,fsize);//申请字符指针内存
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
  RSC_BYTE = '字节';
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
  stmp:String;  //要生成wav文件的文本
  ss:String;    //从文本文件中读到的每一行的文字
  txt:TextFile; //待打开的文本文件的句柄
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
          mmoInfo.Lines.Add('准备接收文件....');
          IdTCPClient.IOHandler.WriteLn('SIZE');
          FSize := IdTCPClient.IOHandler.ReadInt64(False);
          if FSize > 0 then
          begin
            pbProgress.Max := FSize;
            pbProgress.Position := 0;
            mmoInfo.Lines.Add('文件大小 =' + FormatFileSize(FSize, stK) + '; 正在接收中...');
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
                mmoInfo.Lines.Add('接收完毕')
            finally
              FStream.Free;
            end;
{
            stmp:='';//'准备生成声音文件';
            AssignFile(txt,sFilename);
            Reset(txt);   //读打开文件，文件指针移到首

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
            //根据是否有被转换的文件正在执行
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
            finally  //需要增加错误处理，释放文件操作指针
              Spfilestream1.close;
              Spvoice1.AudioOutputStream:=nil;
            end;
}
          end
          else begin
            mmoInfo.Lines.Add('取消...');
            IdTCPClient.IOHandler.WriteLn('CANCEL');
          end;
        end
        else
          mmoInfo.Lines.Add('服务器传来消息: ' + CmdStr)
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
      mmoInfo.Lines.Add(Format('发送消息: "%s"', [edtMsg.Text]));

      edtMsg.Clear;
    end;


end;

procedure TForm1.btnTimeStartClick(Sender: TObject);
var
    st:String;
begin
    st:='This is a TTS engine test.这是一个TTS语音引擎测试';
//    Timer1.Enabled:=not timer1.Enabled;
    try
      SpVoice1.speak(st, 1);
      SpVoice1.WaitUntilDone(-1); //停顿
      MessageDlg('语音转换服务功能正常。', mtInformation, [mbOK], 0);
    except
      MessageDlg('不能提供有效的语音转换服务，请核查系统服务是否安装或配置正确！', mtError, [mbOK], 0);
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
    txt:TextFile; //待打开的文本文件的句柄
    wavFilename:String;
begin
    stmp:='';//'准备生成声音文件';
    AssignFile(txt,sFilename);
    Reset(txt);   //读打开文件，文件指针移到首

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
        TTSFinished:=false;  //当前没有完成转换时的信号量为false
        checkTTSFinishTimer.Enabled := true;

        SpFileStream1.Format.Type_:=SAFT32KHz8BitMono;
        SpFileStream1.Open(wavFilename,SSFMCreateForWrite,False);
        SpVoice1.AllowAudioOutputFormatChangesOnNextSet:=false;
        Spvoice1.AudioOutputStream:=SpFilestream1.defaultInterface;

        Spvoice1.Speak(stmp,1);
        SpVoice1.WaitUntilDone(-1);
        TTSFinished:=true;   //当前完成转换后的信号量设置为true
//        checkTTSFinishTimer.Enabled:=true;

      finally
        Spfilestream1.close;
        Spvoice1.AudioOutputStream:=nil;
        cmdStr:='lame '+wavFilename+' '+OutputFilepath+copy(sFilename,length(sFilename)-22+1,18)+'.mp3';

        runCMD(cmdStr);
        deletefile(ss);  //删除转换原文本文件
//        deletefile(wavFilename);  //删除转换语音.wav文件
      end;
    end
    else
    begin
      sFilename:=copy(sFilename,1,length(sFilename)-4)+'.txt';
//      waitFileList.Lines.Add(sFilename);
      Application.ProcessMessages;
    end;

//  finally  //需要增加错误处理，释放文件操作指针
//    Spfilestream1.close;
//    Spvoice1.AudioOutputStream:=nil;
//  end;
end;


procedure TForm1.checkTTSFinishTimerTimer(Sender: TObject);
var sPath:String;
begin
    if TTSFinished then //根据当前文件是否转换完成，尝试性在等待列表中选择待转换的文件
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
    if Application.MessageBox('是否真的退出？','语音转换云服务转换服务器',mb_OKcancel +
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

