program Test1;

{$APPTYPE CONSOLE}

uses
  Nimbackend in '..\nimbackend.pas',
  DExport in 'DExport.pas',
  SysUtils,
  Classes;

type
  TDynIntArray = array of Integer;
  TDynStringArray = array of AnsiString;

procedure echoDelphi(const s: AnsiString); external backend_dll;
function someResult(const s: AnsiString): AnsiString; external backend_dll;
function someArray(n: Integer): TDynIntArray; external backend_dll;
function someStringArray(n: Integer): TDynStringArray; external backend_dll;
function testStringList(a: TDynStringArray): TStringList; external backend_dll;
procedure cleanString(var a: AnsiString); external backend_dll;

procedure test;
var
  s, s2: string;
  ar: TDynIntArray;
  ar2: TDynStringArray;
  i: Integer;
  lst: TStringList;
begin
  echoDelphi('Hallo Welt');
  s:= someResult('From Delphi');
  echoDelphi(s);
  ar:= someArray(10);
  for i := 0 to High(ar) do write(ar[i], ', ');
  writeln;
  ar2:= someStringArray(10);
  for i := 0 to High(ar2) do write(ar2[i], ', ');
  writeln;
  lst:= testStringList(ar2);
  writeln(lst.Text);
  lst.Free;
  s2:= s;
  cleanString(s);
  writeln('s: ', s);
  writeln('s2: ', s2);
  cleanString(s2);
  cleanString(s);
  writeln('s: ', s);
  writeln('s2: ', s2);
end;

begin
  try
    test;
  except
    on E:Exception do
      Writeln(E.Classname, ': ', E.Message);
  end;
end.
