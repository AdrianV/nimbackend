unit DExport;

interface

implementation
uses nimbackend, Classes;

type
  DExportRec = record
    test1 : function(a: cint): cint;
    test2 : function(a,b: cint): cint;
    test3 : function(a,b,c: cint): cint;
    TStringList_Create: function(): TStringList;
    TStringList_Add: Pointer;
  end;

function dotest1(a: cint): cint;
begin
  result:= 2 * a;
end;

function dotest2(a,b: cint): cint;
begin
  result:= 2 * a - 3 * b;
end;

function dotest3(a,b,c: cint): cint;
begin
  result:= 2 * a - 3*b + 4*c;
end;

function TStringList_Create(): TStringList;
begin
  Result:= TStringList.Create;
end;

const
  exp: DExportRec =  (
    test1: dotest1;
    test2: dotest2;
    test3: dotest3;
    TStringList_Create: TStringList_Create;
    TStringList_Add: @TStringList.Add;
  );
  
procedure initImports(const exp: DExportRec; size: CInt); register; external backend_dll;

initialization
  initImports(exp, sizeof(exp));

end.
