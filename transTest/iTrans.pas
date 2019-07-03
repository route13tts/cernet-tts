unit iTrans;

interface

uses
  SysUtils, Classes, HTTPApp, InvokeRegistry, WSDLIntf, TypInfo,
  WebServExp, WSDLBind, XMLSchema, WSDLPub, SOAPPasInv, SOAPHTTPPasInv,
  SOAPHTTPDisp, WebBrokerSOAP, SpeechLib_TLB, OleServer, Windows, Dialogs,
  Messages, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,IdGlobal,
  Rio, SOAPHTTPClient, EncdDecd, AES;

const
  WM_DATA = WM_USER + 1024;
type
  PShareMem = ^TShareMem;
  TShareMem = record
    Data: array[0..255] of char;
  end;

type
  TBytes = array of Byte;

type
  TTextFormat = (tfAnsi, tfUnicode, tfUnicodeBigEndian, tfUtf8);

const
  TextFormatFlag: array [tfAnsi .. tfUtf8] of word = ($0000, $FFFE, $FEFF,
    $EFBB);
type
  TWebModule1 = class(TWebModule)
    HTTPSoapDispatcher1: THTTPSoapDispatcher;
    HTTPSoapPascalInvoker1: THTTPSoapPascalInvoker;
    WSDLHTMLPublish1: TWSDLHTMLPublish;
    IdTCPClient: TIdTCPClient;
    HTTPRIO: THTTPRIO;
    procedure WebModule1DefaultHandlerAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1ttsAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
    procedure WebModuleCreate(Sender: TObject);
    procedure WebModule1testAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
  private
    { Private declarations }
  public
    { Public declarations }
//    procedure getShareInfo(var Msg: TMessage); message WM_DATA; {����WM_DATA}    
    function GetDllPath:string;stdcall;
  end;

var
  WebModule1: TWebModule1;
//  sn:String;
//  tt:WideString;  //0418
//  tt:String;
  myitrans:Integer;
  Masterkey:String;
  SecondKey:String;
  TestStr1,TestStr2,TestStr3:String;
  
implementation

{$R *.dfm}


function DecodeUtf8Str(const S:UTF8String): WideString;
var lenSrc,lenDst : Integer;
begin
  lenSrc  := Length(S);
  if (lenSrc=0) then Exit;
  lenDst := MultiByteToWideChar(CP_UTF8, 0, Pointer(S),lenSrc, nil, 0);
  SetLength(Result, lenDst);
  MultiByteToWideChar(CP_UTF8, 0, Pointer(S),lenSrc, Pointer(Result), lenDst);
end;

//��ȡdll�ļ�����Ŀ¼
function TWebModule1.GetDllPath:string;stdcall;
var
  ModuleName:string;
begin
   SetLength(ModuleName, 255);
   //ȡ��Dll����·��
   GetModuleFileName(HInstance, PChar(ModuleName), Length(ModuleName));
   Result := PChar(ModuleName);
end;


function IsUtf8Format(buffer: PChar; size: Int64): Boolean;
var
  ii: Integer;
  tmp: Byte;
begin
  Result := True;
  ii := 0;
  while ii < size do
  begin
    tmp := Byte(buffer[ii]);
    if tmp < $80 then        //ֵС��0x80��ΪASCII�ַ�
      Inc(ii)
    else if tmp < $C0 then   //ֵ����0x80��0xC0֮���Ϊ��ЧUTF-8�ַ�
    begin
      Result := False;
      Break;
    end
    else if tmp < $E0 then   //�˷�Χ��Ϊ2�ֽ�UTF-8�ַ�
    begin
      if ii >= size - 1 then
        Break;
      if (Byte(buffer[ii + 1]) and $C0) <> $80 then
      begin
        Result := False;
        Break;
      end;
      Inc(ii, 2);
    end
    else if tmp < $F0 then  //�˷�Χ��Ϊ3�ֽ�UTF-8�ַ�
    begin
      if ii >= size - 2 then
        Break;
      if ((Byte(buffer[ii + 1]) and $C0) <> $80) or ((Byte(buffer[ii + 2]) and $C0) <> $80) then
      begin
        Result := False;
        Break;
      end;
      Inc(ii, 3);
    end
    else
    begin
      Result := False;
      Break;
    end;
  end;
end;

//�ж����ļ��Ƿ�ΪUTF-8���ļ�
//����TTS�Ĳ���
procedure TWebModule1.WebModule1DefaultHandlerAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
    Response.Content :='<H1>'+' ����һ��Web���ò��Գ���'+'</H1>';
end;

procedure TWebModule1.WebModule1ttsAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var sDllpath:String;
    pstr0:Pchar;
    FS:TFilestream;
    CmdStr:String;
    i:integer;
    sn,tt,sid,psdkey:String;
    sUserAgent:String;
    bstrExist:Boolean;
begin

  FS:=nil;

  sUserAgent := request.UserAgent;
  //True��ʾ���������ΪIE���ϴ�������Ĭ��ΪGBK��FalseΪ������������ϴ�����Ĭ�ϵ�UTF-8
  if pos('MSIE', sUserAgent)>0 then bstrExist := true
  else bstrExist := false;                      //ȷ��Ϊ����������磺chrome��fireforx

  case Request.MethodType of
    mtGet:begin
            sn:=Request.QueryFields.Values['SN'];
            if  bstrExist then
              tt:=Request.QueryFields.Values['TT']
            else
              tt:=DecodeUtf8Str(Request.QueryFields.Values['TT']);

            sid:=Request.QueryFields.Values['SID'];
          end;
    mtPost:
          begin
            sn:=Request.ContentFields.Values['SN'];
            if  bstrExist then
              tt:=Request.ContentFields.Values['TT']
            else
              tt:=DecodeUtf8Str(Request.ContentFields.Values['TT']);

            sid:= Request.ContentFields.Values['SID'];
          end;
    else
    begin
      tt:='';
      sn:='';
    end;
  end;

  //�жϰ�ȫ��Ȩ
//  if trim(sid)<>'' then
//  begin
//    psdkey:=DecryptString(sid,MasterKey);
//    i:=pos(#0,psdkey);
//    psdkey:=copy(psdkey,1,i-1);
//  end;
  psdkey:=sid;
  if psdkey<>secondkey then
  begin
    Response.Content:='ERRORͨ�Ű�ȫ�ֲ���ȷ,���ܸ���ת������Ƶ�ļ���Ϣ';
    tt:='';
  end;

  sDllpath := GetDllPath;
  sDllpath:= copy(sDllpath,5,length(sDllpath)-4);
  sDllpath:= copy(sDllpath,1,length(sDllpath)-11);

  myitrans:=999;
  if length(sn)<>16 then
  begin
    Response.Content:='�����ļ���ʽ���Ȳ���ȷ,����ת������ȷ.';
  end
  else
  if trim(tt)<>'' then
  begin
//    Response.Content := Response.Content+'<p>'+'Referer TT End Txt:'+tt+'</P>';
    try
      if not IDTCPClient.Connected then IdTCPClient.Connect;
      try
        FS:=TFileStream.Create((Extractfilepath(sDllpath)+'ttsfile\'+sn+'.txt'),fmCreate );
        response.Content:=Response.Content+'Create File:'+ Extractfilepath(sDllpath)+'ttsfile\'+sn+'.txt';
        pstr0:=PChar(tt);//���ַ���ת���ַ�ָ��
        FS.Writebuffer(pstr0^,Length(pstr0));//���ַ���д������
      finally
        FS.Free;
        response.Content:=Response.Content+'<p>'+'Words be written'+'</p>';
      end;
      //����Լ���ļ����ƣ�����������ת��
      IdTCPClient.IOHandler.Writeln('FILESN'+sn);

      //��ȡ������ת���Ƿ�ɹ��Ľ����Ϣ
      CmdStr := IdTCPClient.IOHandler.ReadLn;
      if SameText(Copy(CmdStr, 1, 5), 'TTSOK') then
      begin
        CmdStr := Copy(CmdStr,6,32);
        idTCPClient.IOHandler.WriteBufferClear;
        Response.content:=CmdStr;//'TransOk';
      end
      else
         Response.Content:=Response.Content+'ϵͳ�������û���ṩ��ת���ķ�����';

    except
      Response.Content :=Response.Content+'<H1>'+' TTSת��������û������'+'</H1>';
    end;
  end;
end;


procedure TWebModule1.WebModuleCreate(Sender: TObject);
var
   filename:String;
   fF : Textfile;
   tmpTxt,sDllpath,keyStr:String;
   i:integer;
begin
  IdTCPClient.ConnectTimeout := 1000;

  IdTCPClient.IPVersion := Id_IPv6;
  IdTCPClient.Host := '::1';         //'202.201.140.169';//'127.0.0.1';
  IdTCPClient.Port := 30305;

    sDllpath := GetDllPath;  //������Ϣ��\\?\C:\inetpub\wwwroot\PiTrans.dll
//    Response.Content:=sDllpath;
    sDllpath:= copy(sDllpath,5,length(sDllpath)-4-11);
    filename := sDllpath+'KDB.WHF';
//    filename := 'KBD.WHF';
    try
      AssignFile(fF, FileName);
      Reset(fF);
      Readln(fF, tmpTxt);  //
      TestStr1:=tmpTxt;
      MasterKey:=DecryptString(tmpTxt,'NGII20170203TTS.');
      Readln(fF, keyStr);
      TestStr2:= keyStr;
      SecondKey:=DecryptString(keyStr,MasterKey);
      TestStr3:=SecondKey;
    finally
      CloseFile(fF);
    end;
    i:=pos(#0,MasterKey);
    if i>0 then
      MasterKey:=copy(MasterKey,1,i-1);

    i:=pos(#0,SecondKey);
    if i>0 then
      SecondKey:=copy(SecondKey,1,i-1);
end;

procedure TWebModule1.WebModule1testAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
   filename:String;
   sn,sid:String;
begin
    sn:=Request.QueryFields.Values['SN'];
    sid:=Request.QueryFields.Values['SID'];

//    filename:=DecryptString(sid,MasterKey);
    Response.Content :='<H1>'+' ����һ��Web���ò��Գ���'+'</H1><p>Masterkey:'+MasterKey+'</p>';
    Response.Content :=response.Content+'<p>sn:'+sn+'</p>';
    Response.Content :=response.Content+'<p>sid:'+sid+'</p>';

    Response.Content :=response.Content+'<p>MasterStr:'+TestStr1+'</p>';
    Response.Content :=response.Content+'<p>SecondStr:'+TestStr2+'</p>';
    Response.Content :=response.Content+'<p>DeCrySecondStr:'+TestStr3+'</p>';

    Response.Content :=response.Content+'<p>Secondkey:'+Secondkey+'</p>';
    filename:=DecryptString(sid,masterkey);
    Response.Content :=response.Content+'<p>Userkey:'+filename+'</p>';
end;

end.
