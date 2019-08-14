# include nbcommon
import delphi32

type
  TClassRec{.final, pure.} = object
    fVtable: int # just a dummy for now
  TObjectRec{.final, pure.} = object
    fClassPtr: ptr TClassRec
  TObject* = ptr TObjectRec
  TStringList* = distinct TObject
  DImportRec* {.final, pure.} = object
    test1* : proc(a: cint): cint {.delphiCall.}
    test2* : proc(a,b: cint): cint {.delphiCall.}
    test3* : proc(a,b,c: cint): cint {.delphiCall.}
    TStringList_Create* : proc(): TStringList {.delphiCall.}
    TStringList_Add* : pointer 

var imports* : DImportRec

proc initImports (data: ptr DImportRec, size: cint) {.expDelphi.} =
  assert(size == sizeof(DImportRec), "size mismatch " & $size & " != " & $(sizeof(DImportRec)))
  imports = data[]

proc add* (self: TStringList; s: AnsiString): int32 {.discardable, inline.} =
  cast[proc(self: TStringList; s: AnsiString): int32 {.delphiCall.}](imports.TStringList_Add)(self, s)
