import nbmemory, nbthreads, delphi32, dimport

proc echoDelphi(data: AnsiString) {.expDelphi.} =
  echo "delphi: ", data

proc someResult(data: AnsiString; result:var  AnsiString) {.expDelphi.} =
  echo "data: ", data
  echo "result: ", result
  result = data & ds" hallo from nim"

proc someArray(n: int32; result: var DynamicArray[int32]) {.expDelphi.} =
  for i in 1 .. n : result.add(i) 
  
proc someStringArray(n: int32; result: var DynamicArray[AnsiString]) {.expDelphi.} =
  for i in 1 .. n : result.add(ds"Zahl: " & ds $i) 

proc testStringList(a: DynamicArray[AnsiString]): TStringList {.expDelphi.} =
  result = imports.TStringList_Create()
  for s in a : result.add(s)
  