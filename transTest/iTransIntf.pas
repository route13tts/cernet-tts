{ Invokable interface IiTrans }

unit iTransIntf;

interface

uses InvokeRegistry, Types, XSBuiltIns;

type

  { Invokable interfaces must derive from IInvokable }
  IiTrans = interface(IInvokable)
  ['{17E2E261-86FB-423B-B8A1-739A9B59707B}']

    { Methods of Invokable interface must not use the default }
    { calling convention; stdcall is recommended }
  end;

implementation

initialization
  { Invokable interfaces must be registered }
  InvRegistry.RegisterInterface(TypeInfo(IiTrans));

end.
 