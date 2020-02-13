import nbmemory, nbthreads, delphi32, dimport

proc echoDelphi(data: AnsiString) {.expDelphi.} =
  echo "delphi: ", data

proc someResult(data: AnsiString; result:var  AnsiString) {.expDelphi.} =
  echo "data: ", data
  echo "result: ", result
  result = data & ds" hallo from nim"

proc someArray(n: int32; result: var DynamicArray[int32]) {.expDelphi.} =
  result.setLen(n)
  for i in 1 .. n : result[i - 1] = i 
  
proc someStringArray(n: int32; result: var DynamicArray[AnsiString]) {.expDelphi.} =
  result.setLen(n)
  for i in 1 .. n : result[i - 1] = ds"number: " & ds $i

proc testStringList(a: DynamicArray[AnsiString]): TStringList {.expDelphi.} =
  echo "a has refCount: ", a.refCount
  result = imports.TStringList_Create()
  for s in a : result.add(s)

proc cleanString(a: var AnsiString) {.expDelphi.} =
  echo "a has refCount: ", a.refCount, " and a is '", a, "'"
  a.setLen(0)
  echo "a has refCount: ", a.refCount, " and a is '", a, "'"
  