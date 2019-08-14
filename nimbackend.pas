unit nimbackend;
{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

const
  backend_dll = {$I nimbackend.inc};

type
  Int32 = LongInt;
  UInt32 = LongWord;
{$if sizeof(Integer) = sizeof(Pointer)}
  ByteAddress = type Integer;
  ByteAddressComp = type Cardinal;
{$else}
  ByteAddress = type Int64;
  ByteAddressComp = type UInt64;
{$ifend}
{$if sizeof(Pointer) = 4}
  {$Message Warn 'Int is 4 bytes'}
  Int = Integer;
  UInt = Cardinal;
{$ifend}
{$if sizeof(Pointer) = 8}
  {$Message Warn 'Int is 8 bytes'}
  Int = Int64;
  UInt = UInt64;
{$ifend}
CInt = Integer;
{$IFNDEF FPC}
  {$if CompilerVersion<=18.5}
    CSize = Int;
  {$else}
    CSize = NativeInt;
  {$ifend}
{$ELSE}
  CSize = NativeInt;
{$ENDIF}
{$if sizeof(ByteAddress) <> sizeof(Pointer)}
  {$Message Error 'wrong size for ByteAddress'}
{$ifend}
{$if sizeof(ByteAddressComp) <> sizeof(Pointer)}
  {$Message Error 'wrong size for ByteAddressComp'}
{$ifend}
  MemoryMangerRec = record
    GetMem: function(Size: CSize): Pointer; register;
    FreeMem: function (P: Pointer): CInt; register;
    ReallocMem: function (P: Pointer; Size: CSize): Pointer; register;
    AllocMem: function (Size: CSize): Pointer; register;
  end;
  RootObj = record
    _internal: Pointer;
  end;


procedure initForeignThread(); register;

procedure doneForeignThread(); register;

implementation

var
  memManger: MemoryMangerRec;

procedure setMemoryManager(var mem: MemoryMangerRec); register; external backend_dll;

procedure initForeignThread(); register; external backend_dll;

procedure doneForeignThread(); register; external backend_dll;

var
  OldSystemThreadFuncProc: TSystemThreadFuncProc = nil;
  OldSystemThreadEndProc: TSystemThreadEndProc = nil;

type
  PThreadRec = ^TThreadRec;
  TThreadRec = record
    Func: TThreadFunc;
    Parameter: Pointer;
  end;

function MyThreadFunc(Parameter: Pointer): Integer;
var
  func: TThreadFunc;
  P: Pointer;
begin
  initForeignThread;
  func:= PThreadRec(Parameter).Func;
  P:= PThreadRec(Parameter).Parameter;
  FreeMem(Parameter);
  Func(P);
end;

function MyTSystemThreadFuncProc(ThreadFunc: TThreadFunc; Parameter: Pointer): Pointer;
var
  PLink: PThreadRec;
begin
  if not Assigned(OldSystemThreadFuncProc) then begin
    new(PLink);
    pLink.Func:= ThreadFunc;
    PLink.Parameter:= Parameter;
  end else begin
    pLink:= OldSystemThreadFuncProc(ThreadFunc, Parameter)
  end;
  new(PThreadRec(Result));
  PThreadRec(Result).Parameter:= PLink;
  PThreadRec(Result).Func:= MyThreadFunc;
end;

procedure MyTSystemThreadEndProc(ExitCode: Integer);
begin
  doneForeignThread;
  if Assigned(OldSystemThreadEndProc) then OldSystemThreadEndProc(ExitCode);
end;


procedure hookThread;
begin
  OldSystemThreadFuncProc:= SystemThreadFuncProc;
  OldSystemThreadEndProc:= SystemThreadEndProc;
  SystemThreadFuncProc:= MyTSystemThreadFuncProc;
  SystemThreadEndProc:= MyTSystemThreadEndProc;
end;

function DefaultRegisterAndUnregisterExpectedMemoryLeak(P: Pointer): boolean;
begin
  Result := False;
end;

procedure init;
var
  memx: TMemoryManagerEx;
  useCustomManager: Boolean;
begin
  useCustomManager:= System.IsMemoryManagerSet;
  if useCustomManager then begin // nimbackend should use our mem manager
    System.GetMemoryManager(memx);
    memManger.GetMem:= memx.GetMem;
    memManger.FreeMem:= memx.FreeMem;
    memManger.ReallocMem:= memx.ReallocMem;
    memManger.AllocMem:= Pointer(@memx.AllocMem);
  end else begin
    memManger.GetMem:= nil;
    memManger.FreeMem:= nil;
    memManger.ReallocMem:= nil;
    memManger.AllocMem:= nil;
  end;
  setMemoryManager(memManger);
  if not useCustomManager then begin // we use the nim mem manager
    memx.GetMem:= memManger.GetMem;
    memx.FreeMem:= memManger.FreeMem;
    memx.ReallocMem:= memManger.ReallocMem;
    memx.AllocMem:= Pointer(@memManger.AllocMem);
    memx.RegisterExpectedMemoryLeak:= DefaultRegisterAndUnregisterExpectedMemoryLeak;
    memx.UnregisterExpectedMemoryLeak:= DefaultRegisterAndUnregisterExpectedMemoryLeak;
    System.SetMemoryManager(memx);
  end;
  hookThread;
end;

initialization
  init;

end.
