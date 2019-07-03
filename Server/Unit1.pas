unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, SyncObjs, IdBaseComponent, IdComponent, IdCustomTCPServer, IdTCPServer,
  IdSocketHandle, IdGlobal, IdContext, StdCtrls, ComCtrls, XPMan, Menus,
  IdScheduler, IdSchedulerOfThread, IdSchedulerOfThreadPool, ExtCtrls,
  IdTCPConnection, IdTCPClient,HttpApp, EncdDecd, TrayIcon, SetWin;

type
  TUser = class(TObject)
  private
    FIP,FUserName: string;
    FPort: Integer;
    FSelected: Boolean;
    FContext: TIdContext;
    FLock: TCriticalSection;
    FCommandQueues: TThreadList;
    FListItem: TListItem;
    FWorkSize: Int64;
    procedure SetContext(const Value: TIdContext);
    procedure SetListItem(const Value: TListItem);
  protected
    procedure DoWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
  public
    constructor Create(const AIP, AUserName: string; APort: Integer; AContext: TIdContext); reintroduce;
    destructor Destroy; override;
    procedure Lock;
    procedure Unlock;
    property IP: string read FIP;
    property Port: Integer read FPort;
    property UserName: string read FUserName;
    property Selected: Boolean read FSelected write FSelected;
    property Context: TIdContext read FContext write SetContext;
    property CommandQueues: TThreadList read FCommandQueues;
    property ListItem: TListItem read FListItem write SetListItem;
  end;

const
   SplitNum=500;      //�������±���ֵĻ����ֽ���

const
  WM_REFRESH_USERS = WM_USER + 330; //WinSocket�ͻ��˷�����Ϣ�ı�����

type                                //WinSocket�ͻ��˷�����Ϣ���ҳ����²�������
  TRefreshParam = (rpRefreshAll, rpAppendItem, rpDeleteItem);

  PCmdRec = ^TCmdRec;
  TCmdRec = record
    Cmd: string;
  end;

  TMyForm = class(TForm)
    IdTCPServer: TIdTCPServer;
    lvUsers: TListView;
    InfoMemo: TMemo;
    btnSendFileToClient: TButton;
    XPManifest1: TXPManifest;
    dlgOpenSendingFile: TOpenDialog;
    edtMsg: TEdit;
    pmRefresh: TPopupMenu;
    mmiRefresh: TMenuItem;
    pmClearMemo: TPopupMenu;
    miClearLog: TMenuItem;
    IdSchedulerOfThreadPool1: TIdSchedulerOfThreadPool;
    IdTCPServerLocal: TIdTCPServer;
    Label1: TLabel;
    edtServerIPv6: TEdit;
    Button1: TButton;
    Button2: TButton;
    Label2: TLabel;
    Label3: TLabel;
    Button3: TButton;
    TrayIcon1: TTrayIcon;
    PopupMenu1: TPopupMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    IdTCPServerV4: TIdTCPServer;
    Label4: TLabel;
    edtServerIPv4: TEdit;
    procedure btnSendFileToClientClick(Sender: TObject);
    procedure edtMsgKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure IdTCPServerConnect(AContext: TIdContext);
    procedure IdTCPServerDisconnect(AContext: TIdContext);
    procedure IdTCPServerExecute(AContext: TIdContext);
    procedure lvUsersChange(Sender: TObject; Item: TListItem; Change: TItemChange);
    procedure miClearLogClick(Sender: TObject);
    procedure mmiRefreshClick(Sender: TObject);
    procedure IdTCPServerLocalExecute(AContext: TIdContext);
    procedure IdTCPServerLocalConnect(AContext: TIdContext);
    procedure Button1Click(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure N3Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    Procedure ShowForm(AFormClass:TFormClass);
    procedure Button2Click(Sender: TObject);
    procedure N1Click(Sender: TObject);
    procedure N2Click(Sender: TObject);
  private
    { Private declarations }
    FUsers: TThreadList;
    FLockUI: TCriticalSection;
    procedure ClearUsers;
    procedure RefreshUsersInListView;
    procedure DeleteUserInListView(AClient: TUser);
    procedure AddUserInListView(AClient: TUser);
    procedure SendFileToUser(AUser: TUser; const FileName: string);
    procedure SendTextToUser(AUser: TUSer; const Text: string);
    function  SelectUserSend( var MsgString: String):Boolean;   //ͨ���߳����ȷ���ɽ��յ��ն��û��󣬷��ͱ�ת����ļ�
    procedure LockUI;
    procedure UnlockUI;
    procedure WMRefreshUsers(var Msg: TMessage); message WM_REFRESH_USERS;
    function SplitFile(fileName:String; iLen:integer):Integer;
  public
    { Public declarations }
  end;

  TMyThread = class(TThread) //����һ�����ڿɽ��û��ͻ��˴���Ķ��̷߳�����
  private
     { Private declarations }
    FLockUser: TCriticalSection;
    Msg:String;
    procedure LockUser;
    procedure UnlockUser;
    procedure Execute; override;
    procedure RunSelectUserSend( var MsgString: String);   //ͨ���߳����ȷ���ɽ��յ��ն��û��󣬷��ͱ�ת����ļ�
  public
    constructor Create(const TransMsg: string); reintroduce;
    destructor Destroy; override;
//    property  MemMsg: string read Msg write Msg;
  end;

var
  MyForm: TMyForm;
  systemFilepath:String;  //�����͵��ı��ļ���·������Ҫ����
  systemFileName:String;  //����һ��ϵͳ�������ļ���
implementation

{$R *.dfm}

function GetGUID: string;  //ȫ��Ψһ�����ַ���16λ
var
 LTep: TGUID;
 sGUID: string;
begin
 CreateGUID(LTep);
 sGUID := GUIDToString(LTep);
 sGUID := StringReplace(sGUID, '-', '', [rfReplaceAll]);
 sGUID := Copy(sGUID, 2, Length(sGUID) - 2);
 Result := sGUID;
end;

var  MyThread:TMyThread; //�ı�������̷߳�����

{ TMyThread }
procedure TMyThread.LockUser;
begin
  FLockUser.Enter;
end;

procedure TMyThread.UnlockUser;
begin
  FLockUser.Leave;
end;

constructor TMyThread.Create(const TransMsg: string);
begin
  Msg:= TransMsg;
  FLockUser := TCriticalSection.Create;
  FreeOnTerminate:=True; {��������߳������˻��Զ�ע��}
  inherited Create(False);
end;

destructor TMyThread.Destroy;
begin
  FLockUser.Free;
  inherited;
end;

procedure TMyThread.Execute;
begin
  RunSelectUserSend(Msg);
end;

procedure TMyThread.RunSelectUserSend( var MsgString: String );
var
  I: Integer;
  Client: TUser;
  cmds: TList;
  CmdRec: PCmdRec;
  SendUserCount: Integer;
  iFileNumber:Integer; //���汻����ļ�����
  sFile:String[255];//��ȡ������ļ����ļ���
  ss:String;
begin
  //�����ļ����б����ܹ��ṩת�������Client�������ļ���С��ѡ�е�Client���д����ı�
  ss:=MsgString;  //�����Ϣ
  i:=length(ss);
  sFile:=copy(ss,1,16);
  iFileNumber:=StrToInt(copy(ss,18,i-17));
//    showMessage(sfile+','+copy(ss,18,i-17));
  if  MyForm.lvUsers.Items.Count>0 then //�пɽ��յĿͻ��˲�������ͻ��˷����ı�
  begin
    SendUserCount := 0;
    Randomize;
    while SendUserCount < iFileNumber do
    begin
      ss:= systemFilepath+sFile+'_'+IntToStr(SendUserCount)+'.txt';   //ȷ��Ҫ���͵ķ�Ƭ�ļ�
      i:=random(MyForm.lvUsers.Items.Count);                                 //���ѡ��Ҫ���͵Ŀͻ���
      MyForm.lvUsers.Enabled := False;
      try
//        LockUser;      //���ﲻȷ���ڶ�����µ�������������һ���б��еļ�¼������ֱ���������б���Ҫ����̲��ԣ����ݲ��Խ�������Ƿ��������
        if MyForm.lvUsers.Items[I].Checked then
        begin
          Client := TUser(MyForm.lvUsers.Items[I].Data);
          cmds := Client.CommandQueues.LockList;
          try
            New(CmdRec);
            CmdRec^.Cmd := Format('SENDF %s', [ss]);
            cmds.Add(CmdRec);
//            Inc(SendUserCount);
          finally
            Client.CommandQueues.UnlockList;
          end;
        end;
      finally
//        UnLockUser;
        MyForm.lvUsers.Items[I].Checked := true;  //ǿ�����øÿͻ��˳�Ϊ���ṩ����
        MyForm.lvUsers.Enabled := True;
      end;
    end;
  end
  else
    MessageDlg('û�п��ṩת������Ŀͻ��ˡ�', mtError, [mbOK], 0);
end;


{ TUser }

constructor TUser.Create(const AIP, AUserName: string; APort: Integer; AContext: TIdContext);
begin
  FLock := TCriticalSection.Create;
  FIP := AIP;
  FPort := APort;
  FUserName := AUserName;
  Context := AContext;
  FCommandQueues := TThreadList.Create;
end;

destructor TUser.Destroy;
begin
  FCommandQueues.Free;
  FLock.Free;
  inherited;
end;

procedure TUser.SetContext(const Value: TIdContext);
begin
  if FContext <> nil then FContext.Data := nil;
  if Value <> nil then Value.Data := Self;
  FContext := Value;
end;

procedure TUser.Lock;
begin
  FLock.Enter;
end;

procedure TUser.Unlock;
begin
  FLock.Leave;
end;

procedure TUser.SetListItem(const Value: TListItem);
begin
  if FListItem <> Value then
    FListItem := Value;
  if Value <> nil then Value.Data := Self;
end;

function GetPercentFrom(Int, Total: Int64): Double;
begin
  if (Int = 0) or (Total = 0) then
    Result := 0
  else if Int = Total then
    Result := 100
  else begin
    Result := Int / (Total / 100);
  end;
end;

procedure TUser.DoWork(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
var
  NewPercent: string;
begin
  if ListItem <> nil then
  begin
    NewPercent := IntToStr(Trunc(GetPercentFrom(AWorkCount,
      FWorkSize))) + '%';
    if ListItem.SubItems[1] <> NewPercent then ListItem.SubItems[1] := NewPercent;
  end;
end;

{ TForm1 }

var
  FormHanlde: HWND = 0;

procedure TMyForm.btnSendFileToClientClick(Sender: TObject);
var
  I: Integer;
  Client: TUser;
  cmds: TList;
  CmdRec: PCmdRec;
  SendUserCount: Integer;
begin
  if dlgOpenSendingFile.Execute then
  begin
    lvUsers.Enabled := False;
    try
      SendUserCount := 0;
      for I := 0 to lvUsers.Items.Count - 1 do
        if lvUsers.Items[I].Checked then
        begin
          Client := TUser(lvUsers.Items[I].Data);
          cmds := Client.CommandQueues.LockList;
          try
            New(CmdRec);
            CmdRec^.Cmd := Format('SENDF %s', [dlgOpenSendingFile.FileName]);
            cmds.Add(CmdRec);
            Inc(SendUserCount);
          finally
            Client.CommandQueues.UnlockList;
          end;
        end;
    finally
      lvUsers.Enabled := True;
    end;
    if SendUserCount <= 0 then
      MessageDlg('û��ѡ���û��������û��б��и�Ŀ���û�ѡ�϶Թ���Ȼ��������ť��',
        mtError, [mbOK], 0);
  end;
end;

procedure TMyForm.FormCreate(Sender: TObject);
var s1,s2:String;
    filename:String;
    fStream0: TFileStream;
    pstr:Pchar;
    tmpTxt:String;
    i,fsize:Integer;
    fF : Textfile;
begin
    FormHanlde := Self.Handle;
    FUsers := TThreadList.Create;
    FLockUI := TCriticalSection.Create;

    filename := ExtractFilePath(Application.Exename)+'SVINI.WHF';

    try
      AssignFile(fF, FileName);
      Reset(fF);
      Readln(fF, tmpTxt);

      i := pos(',',tmpTxt);
      s1:=copy(tmpTxt,1,i-1);

      s1:=copy(s1,14,length(s1)-13);
      systemFilepath:=s1;

      tmpTxt:=copy(tmpTxt,i+1,length(tmpTxt)-i);

      i:= pos(',',tmpTxt);
      //λ����Ҫ���¼���
      edtServerIPv6.Text := copy(tmpTxt,15,i-15);//���IPv6��ַ
      s2:=copy(tmpTxt,i+1,length(tmpTxt)-i);
      s2:=copy(s2,15,length(s2)-14);
      edtServerIPv4.Text:=s2;


    finally
//      fStream0.free;
      closeFile(fF);
    end;
end;

procedure TMyForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FormHanlde := 0;
  if IdTCPServer.Active then IdTCPServer.Active := False;
  if IdTCPServerV4.Active then IdTCPServerV4.Active := False;
  if IdTCPServerLocal.Active then IdTCPServerLocal.Active := False;

  ClearUsers;
  FUsers.Free; 
  FLockUI.Free;
//  MyThread.Free;
end;

procedure TMyForm.ClearUsers;
var
  lst: TList;
  I: Integer;
  User: TUser;
begin
  lst := FUsers.LockList;
  try
    for I := 0 to lst.Count - 1 do
    begin
      User := lst[I];
      if User <> nil then User.Context := nil;
      User.Free;
    end;
    FUsers.Clear;
  finally
    FUsers.UnlockList;
  end;
end;

function DecodeUtf8Str(const S:UTF8String): String;
var lenSrc,lenDst : Integer;
begin
  lenSrc  := Length(S);
  if (lenSrc=0) then Exit;
  lenDst  := MultiByteToWideChar(CP_UTF8, 0, Pointer(S),lenSrc, nil, 0);
  SetLength(Result, lenDst);
  MultiByteToWideChar(CP_UTF8, 0, Pointer(S),lenSrc, Pointer(Result), lenDst);
end;

//Server���Զ���
procedure TMyForm.IdTCPServerConnect(AContext: TIdContext);
var
  Client: TUser;
  AUserName: string;
  lst: TList;
  I: Integer;
begin
  AUserName := AContext.Connection.IOHandler.ReadLn;
  if AUserName = '' then
  begin
    AContext.Connection.IOHandler.WriteLn('NO_USER_NAME');
    AContext.Connection.Disconnect;
    Exit;
  end;
  lst := FUsers.LockList;
  try
    for I := 0 to lst.Count - 1 do
      if SameText(TUser(lst[I]).UserName, AUserName) then
      begin
        AContext.Connection.IOHandler.WriteLn('USER_ALREADY_LOGINED');
        AContext.Connection.Disconnect;
        Exit;
      end;

    Client := TUser.Create(AContext.Binding.PeerIP, AUserName,
      AContext.Binding.PeerPort, AContext);
    lst.Add(Client);
    Client.Lock;
    try
      Client.Context.Connection.IOHandler.WriteLn('LOGINED');
    finally
      Client.Unlock;
    end;
  finally
    FUsers.UnlockList;
  end;
  SendMessage(FormHanlde, WM_REFRESH_USERS, Ord(rpAppendItem), Integer(Client));
end;

procedure TMyForm.IdTCPServerDisconnect(AContext: TIdContext);
var
  Client: TUser;
begin
  Client := TUser(AContext.Data);
  if Client <> nil then
  begin
    Client.Lock;
    try
      Client.Context := nil;
    finally
      Client.Unlock;
    end;

    FUsers.Remove(Client);
    SendMessage(FormHanlde, WM_REFRESH_USERS, Ord(rpDeleteItem), Integer(Client));
    Client.Free;
  end;
end;

procedure TMyForm.IdTCPServerExecute(AContext: TIdContext);
var
  Client: TUser;
  Msg, Cmd: string;
  cmds: TList;
  CmdRec: PCmdRec;
begin
  Client := TUser(AContext.Data);
  if Client <> nil then
  begin
    Client.Lock;
    try
      AContext.Connection.IOHandler.CheckForDataOnSource(250);
      if not AContext.Connection.IOHandler.InputBufferIsEmpty then
      begin
        Msg := AContext.Connection.IOHandler.ReadLn;
        if FormHanlde <> 0 then
        begin
          LockUI;
          try
            InfoMemo.Lines.Add(Format('IP: %s �� %s �û�˵����%s��',
              [Client.IP, Client.UserName, Msg]));
          finally
            UnlockUI;
          end;
        end;
      end;

      cmds := Client.CommandQueues.LockList;
      try
        if cmds.Count > 0 then
        begin
          CmdRec := cmds[0];
          Cmd := CmdRec.Cmd;
          cmds.Delete(0);
          Dispose(CmdRec);
        end
        else Cmd := '';
      finally
        Client.CommandQueues.UnlockList;
      end;

      if Cmd = '' then Exit;
      if Pos('SENDF', Cmd) = 1 then
      begin
        if FormHanlde <> 0 then
        begin
          LockUI;
          try
            InfoMemo.Lines.Add(Format('�����ļ��� %s��IP: %s��',
              [Client.UserName, CLient.IP]));
          finally
            UnlockUI;
          end;
        end;
        SendFileToUser(Client, Trim(Copy(Cmd, 6, Length(Cmd))));
      end
      else if Pos('SENDT', Cmd) = 1 then
      begin
        if FormHanlde <> 0 then
        begin
          LockUI;
          try
            InfoMemo.Lines.Add(Format('�����ı���Ϣ�� %s��IP: %s�����ı�����: "%s"',
              [Client.UserName, Client.IP, Trim(Copy(Cmd, 6, Length(Cmd)))]));
          finally
            UnlockUI;
          end;
        end;
        SendTextToUser(Client, Trim(Copy(Cmd, 6, Length(Cmd))));
      end;
    finally
      Client.Unlock;
    end;
  end;
end;

//���������ļ����ݷ���ģ��
procedure TMyForm.SendFileToUser(AUser: TUser; const FileName: string);
var
  FStream: TFileStream;
  Str: string;
begin
  if AUser.Context <> nil then
    with AUser.Context do
    begin
      Connection.IOHandler.WriteLn(Format('FILE %s', [ExtractFileName(FileName)]));
      Str := Connection.IOHandler.ReadLn;
      if SameText(Str, 'SIZE') then
      begin
        FStream := TFileStream.Create(FileName, fmOpenRead or
          fmShareDenyWrite);
        try
          Connection.IOHandler.Write(ToBytes(FStream.Size));
          Str := Connection.IOHandler.ReadLn;
          if SameText(Str, 'READY') then
          begin
            Connection.IOHandler.LargeStream := True;
            Connection.OnWork := AUser.DoWork;
            AUser.FWorkSize := FStream.Size;
            Connection.IOHandler.Write(FStream, FStream.Size);
            Connection.OnWork := nil;
            Connection.IOHandler.LargeStream := False;
            Str := Connection.IOHandler.ReadLn;
            if FormHanlde <> 0 then
            begin
              LockUI;
              try
                if SameText(Str, 'OK') then
                  InfoMemo.Lines.Add(Format('�û�: %s ��IP: %s���ѳɹ������ļ���',
                    [AUser.UserName, AUser.IP]))
                else
                  InfoMemo.Lines.Add(Format('������ֹ���û��� %s ��IP: %s',
                    [AUser.UserName, AUser.IP]));
              finally
                UnlockUI;
              end;
            end;
            Connection.IOHandler.WriteLn('DONE');
          end;
        finally
          FStream.Free;
          DeleteFile(FileName);
        end;
      end;
    end;
end;

//Server�б�״̬�����仯
procedure TMyForm.WMRefreshUsers(var Msg: TMessage);
begin
  if Msg.Msg = WM_REFRESH_USERS then
  begin
    case TRefreshParam(Msg.WParam) of
      rpRefreshAll: begin
          RefreshUsersInListView;
        end;
      rpAppendItem: begin
          AddUserInListView(TUser(Msg.LParam));
        end;
      rpDeleteItem: begin
          DeleteUserInListView(TUser(Msg.LParam));
        end;
    end;
  end;
end;

procedure TMyForm.DeleteUserInListView(AClient: TUser);
begin
  if AClient.ListItem <> nil then
    AClient.ListItem.Delete;
end;

procedure TMyForm.edtMsgKeyDown(Sender: TObject; var Key: Word; Shift:
  TShiftState);
var
  I: Integer;
  Client: TUser;
  cmds: TList;
  CmdRec: PCmdRec;
begin
  if Key = VK_RETURN then
  begin
    lvUsers.Enabled := False;
    try
      for I := 0 to lvUsers.Items.Count - 1 do
      begin
        if I = 0 then InfoMemo.Lines.Add('');
        if lvUsers.Items[I].Checked then
        begin
          Client := TUser(lvUsers.Items[I].Data);
          if Client <> nil then
          begin
            cmds := Client.CommandQueues.LockList;
            try
              New(CmdRec);
              CmdRec^.Cmd := Format('SENDT %s', [edtMsg.Text]);
              cmds.Add(CmdRec);
            finally
              Client.CommandQueues.UnlockList;
            end;
          end;
        end;
      end;
      edtMsg.Clear;
    finally
      lvUsers.Enabled := True;
    end;
    Key := 0;
  end;
end;

procedure TMyForm.RefreshUsersInListView;
var
  lst: TList;
  I: Integer;
begin
  lvUsers.Items.BeginUpdate;
  try
    lvUsers.Clear;
    lst := FUsers.LockList;
    try
      for I := 0 to lst.Count - 1 do
        SendMessage(FormHanlde, WM_REFRESH_USERS, Ord(rpAppendItem),
          Integer(lst[I]));
    finally
      FUsers.UnlockList;
    end;
  finally
    lvUsers.Items.EndUpdate;
  end;
end;

procedure TMyForm.LockUI;
begin
  FLockUI.Enter;
end;

procedure TMyForm.UnlockUI;
begin
  FLockUI.Leave;
end;

procedure TMyForm.SendTextToUser(AUser: TUSer; const Text: string);
begin
  if AUser.Context <> nil then
    with AUser.Context do
    begin
      Connection.IOHandler.WriteLn(Text);
    end;
end;

procedure TMyForm.AddUserInListView(AClient: TUser);
var
  Item: TListItem;
begin
  Item := lvUsers.Items.Add;
  Item.Caption := AClient.UserName;
  AClient.ListItem := Item;
  Item.SubItems.Add(Format('%s[%d]', [AClient.IP, AClient.Port]));
  Item.SubItems.Add('N/A');
  Item.Checked := true;//AClient.Selected;
end;

procedure TMyForm.lvUsersChange(Sender: TObject; Item: TListItem; Change:
    TItemChange);
begin
  if (Change = ctState) and (Item.Data <> nil) then
    TUser(Item.Data).Selected := Item.Checked;
end;

procedure TMyForm.miClearLogClick(Sender: TObject);
begin
  LockUI;
  try
    InfoMemo.Lines.Clear;
  finally
    UnlockUI;
  end;
end;

procedure TMyForm.mmiRefreshClick(Sender: TObject);
begin
  SendMessage(FormHanlde, WM_REFRESH_USERS, Ord(rpRefreshAll), 0);
end;

function TMyForm.SelectUserSend( var MsgString: String ):Boolean;
var
  I: Integer;
  Client: TUser;
  cmds: TList;
  CmdRec: PCmdRec;
  SendUserCount: Integer;
  iFileNumber:Integer; //���汻����ļ�����
  sFile:String[255];//��ȡ������ļ����ļ���
  ss:String[255];
  ipAdd:String[128];
  pstr:Pchar;
  ttsListStr,tmp:String;
  listFilename:String;
  fStream1:TFileStream;
begin
  //�����ļ����б����ܹ��ṩת�������Client�������ļ���С��ѡ�е�Client���д����ı�
  ss:=String(MsgString);  //�����Ϣ
  i:=length(ss);
  sFile:=copy(ss,1,16);
  iFileNumber:=StrToInt(copy(ss,18,i-17));
//    showMessage(sfile+','+copy(ss,18,i-17));
  result:=false;
  if lvUsers.Items.Count>0 then   //�пɽ��յĿͻ��˲�������ͻ��˷����ı�
  begin
    SendUserCount := 0;
    Randomize;
//    ttsListStr:='';
    ttsListStr:='#EXTM3U'#13#10;
    while SendUserCount < iFileNumber do
    begin
      ss:= systemFilepath+sFile+'_'+IntToStr(SendUserCount)+'.txt';   //ȷ��Ҫ���͵ķ�Ƭ�ļ�
      i:=random(lvUsers.Items.Count);                                 //���ѡ��Ҫ���͵Ŀͻ���

      lvUsers.Enabled := False;
      try
        if lvUsers.Items[I].Checked then
        begin
          Client := TUser(lvUsers.Items[I].Data);
          ipAdd := client.IP;  //���ת����������IP��ַ
          cmds := Client.CommandQueues.LockList;
          try
            New(CmdRec);
            CmdRec^.Cmd := Format('SENDF %s', [ss]);
            cmds.Add(CmdRec);
            Inc(SendUserCount);
          finally
            if pos(':',ipAdd)>0 then
              ttsListStr :=ttsListStr+'http://['+ipAdd+']/ttswav/'+sFile+'_'+IntToStr(SendUserCount-1)+'.mp3'+#13#10
            else
              ttsListStr :=ttsListStr+'http://'+ipAdd+'/ttswav/'+sFile+'_'+IntToStr(SendUserCount-1)+'.mp3'+#13#10;

//            ttsListStr :=ttsListStr+'http://['+ipAdd+']/ttswav/'+sFile+'_'+IntToStr(SendUserCount-1)+'.wav'+#13#10;
            Client.CommandQueues.UnlockList;
          end;
        end;
      finally
        lvUsers.Items[I].Checked := true;  //ǿ�����øÿͻ��˳�Ϊ���ṩ����
        lvUsers.Enabled := True;
      end;
    end;

    //����ת���б��ļ�
    try
      systemFileName := getGUID;
      listFilename:= systemFilepath+systemFileName+'.m3u';
      fStream1:=TFileStream.Create(listFilename,fmCreate );
      pstr:=Pchar(ttsListStr);//���ַ���ת���ַ�ָ��
      fStream1.Writebuffer(pstr^,Length(pstr));//���ַ���д������
    finally
      fStream1.Free;
    end;
    result:=true;
  end
  else
  begin
    MessageDlg('û�п��ṩת������Ŀͻ��ˡ�', mtError, [mbOK], 0);
  end;
end;

function TMyForm.SplitFile(fileName:String;iLen:integer):Integer; //�����ļ����ָ������
var
  fStream0,fStream1: TFileStream; //fStream0���ڴ�ȡԭ�ļ���fStream1�����������ļ�
  sStm:TStringStream;
  i,n:integer;
  fsize:Integer; //�ļ���С
  pstr:Pchar;
  strtxt,tmp:String;
  iPos:Integer;
  subFilename:String;
  j:integer;
  fF : Textfile;
begin
  result:=999;
  try
    fStream0 := TFileStream.Create(fileName, fmOpenRead or fmShareDenyWrite);
    fsize :=  fStream0.Size;
    sStm:=TStringStream.Create('');

    sStm.CopyFrom(fStream0, fsize);
    strTxt := sStm.DataString;

    iPos:=1;
    n :=trunc( fsize/ iLen );

    for i:=0 to n do
    begin
//      if fsize< ilen then 
      iPos := iLen;
      if ByteType(strtxt,iLen) = mbLeadByte then  iPos := iLen - 1;
      tmp := copy(strtxt,1,iPos);

      try
        subFilename:= copy(fileName,1,Length(fileName)-4)+'_'+IntToStr(i)+'.txt';
        fStream1:=TFileStream.Create(subFilename,fmCreate );
        pstr:=Pchar(tmp);//���ַ���ת���ַ�ָ��
        j:= Length(pstr);
        fStream1.Writebuffer(pstr^,j);//���ַ���д������
        strtxt := copy(strtxt,iPos+1,Length(strtxt)-ipos);
      finally
        fStream1.Free;
      end;
    end;

    result:=n+1; //�����ļ�����ֵ�����
  finally
//    closeFile(fF);
    fStream0.free;
    sStm.Free;
    deletefile(fileName);
  end;
end;


procedure TMyForm.IdTCPServerLocalExecute(AContext: TIdContext);
var
  Msg: String;
  ttsMsg: String;
  i:integer;
  sFileName,tmp:String;
  bOK:Boolean;
begin
      AContext.Connection.IOHandler.CheckForDataOnSource(250);
      if not AContext.Connection.IOHandler.InputBufferIsEmpty then
      begin
        Msg := AContext.Connection.IOHandler.ReadLn;
        if SameText(Copy(Msg, 1, 6), 'FILESN') then
          sFileName:=systemFilepath+Copy(Msg,7,16)+'.TXT';

        i:=SplitFile(sFileName,80); //����ļ�

        LockUI;
        try
          InfoMemo.Lines.Add(Format('�������û����͵�TTS��"%s,,����ļ�����%s"',[Msg,IntToStr(i)]));
        finally
          UnlockUI;
        end;

        ttsMsg:=Copy(Msg,7,16)+','+IntToStr(i);
        bOK := SelectUserSend(ttsMsg);
//        bok:=true;
        if bOk then  AContext.Connection.IOHandler.WriteLn('TTSOK'+systemFileName)
        else AContext.Connection.IOHandler.WriteLn('TTSERROR');
//        AContext.Connection.Disconnect;
      end;
end;

procedure TMyForm.IdTCPServerLocalConnect(AContext: TIdContext);
//var
//  aStr: string;
begin

//  btnSendFileToClient.Caption :='Local IIS Working';
end;

Procedure TMyForm.ShowForm(AFormClass:TFormClass);
begin
  With AFormClass.Create(Self) do
  try
    ShowModal;
  finally
    Free;
  end;
End;


procedure TMyForm.Button1Click(Sender: TObject);
begin
  with IdTCPServer.Bindings.Add do
  begin

    IPVersion := Id_IPv6;
    if trim(edtServerIPv6.Text)<>'' then
      IP:=trim(edtServerIPv6.Text);
    Port := 30303;
  end;

  with IdTCPServerV4.Bindings.Add do
  begin

    IPVersion := Id_IPv4;
    IP := '127.0.0.1';//'202.201.140.169';

    if trim(edtServerIPv4.Text)<>'' then
      IP:=trim(edtServerIPv4.Text);
    Port := 30304;
  end;

//��Ҫ�����缰�����������ã���÷�����IPv6��ַ�����������ַ��������
  try
    IdTCPServer.Active := True;
    Button1.Caption:='����OK';
  except
    ShowMessage('�������������в����������ܽ�������ͨ��!');
    Application.Terminate;
  end;

//��Ҫ�����缰�����������ã���÷�����IPv4��ַ�����������ַ��������
  try
    IdTCPServerV4.Active := True;
//    Button1.Caption:='����OK';
  except
    ShowMessage('����������IPv4��ַ���в����������ܽ�������ͨ��!����Ӱ��IPv6��ַ������');
  end;


  //���ڽ��ձ���IIS���������������Լ����û��ύ���ı��ļ�                      
  with IdTCPServerLocal.Bindings.Add do
  begin
    IPVersion := Id_IPv6;
    IP:='::1';
//      IP:='fe80::455:ce5d:2c2a:d2a4';
    Port := 30305;  //45999;
  end;

  try
    IdTCPServerLocal.Active := True;
  except
    ShowMessage('�����������в�����2�����ܽ�������ͨ��!');
    Application.Terminate;
  end;

end;

procedure TMyForm.TrayIcon1DblClick(Sender: TObject);
begin
  TrayIcon1.ShowBalloonHint;
end;

procedure TMyForm.N3Click(Sender: TObject);
begin
    if Application.MessageBox('�Ƿ�����˳���','����ת���Ʒ������������',mb_OKcancel +
                                  mb_DefButton1 + mb_ICONQUESTION )= IDOK then

       Close;

end;

procedure TMyForm.Button3Click(Sender: TObject);
begin
  WindowState := wsMinimized;
  MyForm.Visible := false;
end;

procedure TMyForm.Button2Click(Sender: TObject);
begin
  ShowForm( Tform2 );
end;

procedure TMyForm.N1Click(Sender: TObject);
begin
  MyForm.Visible := true;
  WindowState := wsNormal;
end;

procedure TMyForm.N2Click(Sender: TObject);
begin
  WindowState := wsMinimized;
  MyForm.Visible := false;
end;

end.

