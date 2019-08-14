when defined(useWinim):
  import winim
  export winim
else:
  type
    HRESULT* = int32
    BYTE* = uint8
    WORD* = uint16
    DWORD* = uint32
    ULONG* = uint32
    BOOL* = int32
    GUID* {.final, pure.} = object
      Data1*: DWORD
      Data2*: WORD
      Data3*: WORD
      Data4*: array[8, BYTE]
    UUID* = GUID
    IID* = GUID
    InterfaceData* [V:object] = object
      lpVtbl*: ptr V
    IInterface* {.pure.} [V:object]  = object
      ip*: ptr InterfaceData[V]
    ComInterface* [V] = concept c
      var vv: V # to make compiler happy that V is used
      c.ip[].lpVtbl[] is V
    IUnknownVtbl* {.pure, inheritable.} = object
      QueryInterface*: proc(self: IInterface[IUnknownVtbl], riid: ptr IID, pvObject: ptr pointer): HRESULT {.stdcall.}
      AddRef*: proc(self: IInterface[IUnknownVtbl]): ULONG {.stdcall.}
      Release*: proc(self: IInterface[IUnknownVtbl]): ULONG {.stdcall.}
    IUnknown* = IInterface[IUnknownVtbl]
    IClassFactoryVtbl* = object of IUnknownVtbl
      CreateInstance*: proc(self: IInterface[IClassFactoryVtbl], UnkOuter: IUnknown, riid: ptr IID, pvObject: ptr pointer): HRESULT {.stdcall.}
      LockServer*: proc(self: IInterface[IClassFactoryVtbl], fLock: BOOL): HRESULT {.stdcall.}
    IClassFactory* = IInterface[IClassFactoryVtbl]
      

  template QueryInterface* (self: IUnknown, riid: ptr IID, pvObject: ptr pointer): HRESULT = self.ip[].lpVtbl[].QueryInterface(self, riid, pvObject)
  template AddRef* (self: IUnknown): ULONG = self.ip[].lpVtbl[].AddRef(self)
  template Release* (self: IUnknown): ULONG = self.ip[].lpVtbl[].Release(self)
  converter toIUnknown* (intf: ComInterface[IUnknownVtbl]): IUnknown {.inline.} = cast[IUnknown](intf)
  proc isNil* [V](intf: IInterface[V]): bool {.inline.} = intf.ip.isNil
  
  when isMainModule:

    static:
      type 
          IfDataPtr[V] = ptr V

      echo IClassFactory is IInterface[IUnknownVtbl]
      echo InterfaceData[IClassFactoryVtbl] is InterfaceData[IUnknownVtbl]
      echo IClassFactoryVtbl is IUnknownVtbl
      echo IfDataPtr[IClassFactoryVtbl] is IfDataPtr[IUnknownVtbl]
      echo IClassFactory is ComInterface[IUnknownVtbl]

    var ic: IClassFactory

    discard AddRef(ic)
    discard ic.Release

    static:
      type 
        SomeOtherVtbl = object
          discard
        SomeOtherInterface = IInterface[SomeOtherVtbl]

      var some: SomeOtherInterface

      when compiles(some.AddRef):
        {.fatal: "this should not compile".}

      echo SomeOtherInterface is ComInterface[SomeOtherVtbl]

      echo some.isNil
