object MyForm: TMyForm
  Left = 363
  Top = 148
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = #35821#38899#36716#25442#20113#26381#21153#20219#21153#26381#21153#22120
  ClientHeight = 480
  ClientWidth = 631
  Color = clBtnFace
  Font.Charset = GB2312_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  DesignSize = (
    631
    480)
  PixelsPerInch = 96
  TextHeight = 12
  object Label1: TLabel
    Left = 8
    Top = 410
    Width = 84
    Height = 12
    Caption = #26381#21153#22120'IPv6'#22320#22336
    FocusControl = btnSendFileToClient
  end
  object Label2: TLabel
    Left = 16
    Top = 240
    Width = 72
    Height = 12
    Caption = #31995#32479#36816#34892#26085#24535
  end
  object Label3: TLabel
    Left = 8
    Top = 376
    Width = 72
    Height = 12
    Caption = #31995#32479#28040#24687#36755#20837
  end
  object Label4: TLabel
    Left = 8
    Top = 442
    Width = 84
    Height = 12
    Caption = #26381#21153#22120'IPv4'#22320#22336
    FocusControl = btnSendFileToClient
  end
  object lvUsers: TListView
    Left = 8
    Top = 8
    Width = 614
    Height = 225
    Hint = #29992#25143#21015#34920
    Anchors = [akLeft, akTop, akRight, akBottom]
    Checkboxes = True
    Columns = <
      item
        Caption = #29992#25143
        Width = 150
      end
      item
        Caption = 'IP&'#31471#21475
        Width = 300
      end
      item
        AutoSize = True
        Caption = #24037#20316#36827#24230
      end>
    ReadOnly = True
    ParentShowHint = False
    PopupMenu = pmRefresh
    ShowHint = True
    TabOrder = 0
    ViewStyle = vsReport
    OnChange = lvUsersChange
  end
  object InfoMemo: TMemo
    Left = 8
    Top = 259
    Width = 614
    Height = 99
    Anchors = [akLeft, akRight, akBottom]
    ParentShowHint = False
    PopupMenu = pmClearMemo
    ReadOnly = True
    ScrollBars = ssVertical
    ShowHint = True
    TabOrder = 1
  end
  object btnSendFileToClient: TButton
    Left = 536
    Top = 368
    Width = 81
    Height = 25
    Anchors = [akLeft, akRight, akBottom]
    Caption = #21457#36865#25991#20214
    TabOrder = 2
    OnClick = btnSendFileToClientClick
  end
  object edtMsg: TEdit
    Left = 96
    Top = 369
    Width = 433
    Height = 20
    Hint = #36755#20837#25991#26412#65292#25353#22238#36710#21457#36865#32473#36873#20013#30340#29992#25143
    Anchors = [akLeft, akRight, akBottom]
    ParentShowHint = False
    ShowHint = True
    TabOrder = 3
    OnKeyDown = edtMsgKeyDown
  end
  object edtServerIPv6: TEdit
    Left = 96
    Top = 408
    Width = 249
    Height = 20
    TabOrder = 4
    Text = 'fe80::455:ce5d:2c2a:d2a4'
  end
  object Button1: TButton
    Left = 360
    Top = 408
    Width = 75
    Height = 25
    Caption = #26381#21153#22120#19978#32447
    TabOrder = 5
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 448
    Top = 408
    Width = 75
    Height = 25
    Caption = #26381#21153#22120#37197#32622
    TabOrder = 6
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 536
    Top = 408
    Width = 81
    Height = 25
    Caption = #31995#32479#26368#23567#21270
    TabOrder = 7
    OnClick = Button3Click
  end
  object edtServerIPv4: TEdit
    Left = 96
    Top = 440
    Width = 249
    Height = 20
    TabOrder = 8
    Text = '127.0.0.1'
  end
  object IdTCPServer: TIdTCPServer
    Bindings = <>
    DefaultPort = 0
    OnConnect = IdTCPServerConnect
    OnDisconnect = IdTCPServerDisconnect
    Scheduler = IdSchedulerOfThreadPool1
    OnExecute = IdTCPServerExecute
    Left = 456
    Top = 40
  end
  object XPManifest1: TXPManifest
    Left = 416
    Top = 40
  end
  object dlgOpenSendingFile: TOpenDialog
    Filter = 'All file(*.)|*.txt'
    Title = 'Open a file to send'
    Left = 384
    Top = 40
  end
  object pmRefresh: TPopupMenu
    Left = 352
    Top = 40
    object mmiRefresh: TMenuItem
      Caption = 'Refresh'
      OnClick = mmiRefreshClick
    end
  end
  object pmClearMemo: TPopupMenu
    Left = 320
    Top = 40
    object miClearLog: TMenuItem
      Caption = 'Clear Log'
      OnClick = miClearLogClick
    end
  end
  object IdSchedulerOfThreadPool1: TIdSchedulerOfThreadPool
    MaxThreads = 0
    PoolSize = 10
    Left = 488
    Top = 40
  end
  object IdTCPServerLocal: TIdTCPServer
    Bindings = <>
    DefaultPort = 0
    OnConnect = IdTCPServerLocalConnect
    OnExecute = IdTCPServerLocalExecute
    Left = 456
    Top = 136
  end
  object TrayIcon1: TTrayIcon
    BalloonHint = #35821#38899#36716#25442#20113#26381#21153#20219#21153#26381#21153#22120#36816#34892#20013#65292#21491#20987#25176#30424#36824#21407
    BalloonFlags = bfInfo
    PopupMenu = PopupMenu1
    Visible = True
    OnDblClick = TrayIcon1DblClick
    Left = 392
    Top = 400
  end
  object PopupMenu1: TPopupMenu
    Left = 440
    Top = 400
    object N1: TMenuItem
      Caption = #36824#21407
      OnClick = N1Click
    end
    object N2: TMenuItem
      Caption = #26368#23567#21270
      OnClick = N2Click
    end
    object N3: TMenuItem
      Caption = #36864#20986
      OnClick = N3Click
    end
  end
  object IdTCPServerV4: TIdTCPServer
    Bindings = <>
    DefaultPort = 0
    OnConnect = IdTCPServerConnect
    OnDisconnect = IdTCPServerDisconnect
    Scheduler = IdSchedulerOfThreadPool1
    OnExecute = IdTCPServerExecute
    Left = 456
    Top = 72
  end
end
