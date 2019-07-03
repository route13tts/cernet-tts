object Form2: TForm2
  Left = 397
  Top = 299
  Width = 403
  Height = 296
  BorderIcons = []
  Caption = #31995#32479#35774#32622
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 24
    Top = 8
    Width = 345
    Height = 13
    AutoSize = False
    Caption = #36716#25442#36335#24452'('#24212#20026'IIS'#26381#21153#22120#25552#20379'wav'#25991#20214#19979#36733#30340#30446#24405')'
  end
  object Label2: TLabel
    Left = 24
    Top = 168
    Width = 113
    Height = 13
    AutoSize = False
    Caption = #26381#21153#22120'IPv6'#22320#22336
  end
  object btnPathset: TButton
    Left = 24
    Top = 216
    Width = 75
    Height = 25
    Caption = #36335#24452#20445#23384
    TabOrder = 0
    OnClick = btnPathsetClick
  end
  object btnQuit: TButton
    Left = 296
    Top = 216
    Width = 75
    Height = 25
    Caption = #36820#22238
    TabOrder = 1
    OnClick = btnQuitClick
  end
  object DirectoryListBox1: TDirectoryListBox
    Left = 24
    Top = 56
    Width = 345
    Height = 97
    ItemHeight = 16
    TabOrder = 2
    OnClick = DirectoryListBox1Click
    OnDblClick = DirectoryListBox1Click
  end
  object edtServerIpAdd: TEdit
    Left = 24
    Top = 184
    Width = 345
    Height = 21
    TabOrder = 3
    Text = 'fe80::455:ce5d:2c2a:d2a4'
  end
  object DriveComboBox1: TDriveComboBox
    Left = 24
    Top = 32
    Width = 345
    Height = 19
    DirList = DirectoryListBox1
    TabOrder = 4
  end
end
