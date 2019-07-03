{ Invokable implementation File for TiTrans which implements IiTrans }

unit iTransImpl;

interface

uses InvokeRegistry, Types, XSBuiltIns, iTransIntf;

type

  { TiTrans }
  TiTrans = class(TInvokableClass, IiTrans)
  public
  end;

implementation

initialization
  { Invokable classes must be registered }
  InvRegistry.RegisterInvokableClass(TiTrans);

end.
 