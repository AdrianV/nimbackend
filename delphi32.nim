import nbmemory

# include nbcommon

type
  StrRec* {.pure, final, packed.} = object
    when defined(delphiUnicode):
      when sizeof(int) == 8:
        fpadding: int32
      codePage: uint16
      elemSize: uint16
    refCnt*: int32
    length*: int32
  StrRecPtr* = ptr StrRec
  AnsiStringData* = ptr UncheckedArray[char]
  AnsiString* {.pure, final, bycopy.} = object
    data: AnsiStringData
  WeakPartialString* {.pure, final.} = object
    data: AnsiStringData
    delta: int32
    length: int32
  SomeDelphiString = AnsiString | WeakPartialString
  TDynArrayRec {.pure, final, packed.} = object
    when sizeof(int) == 8:
      fpadding: int32
    refCnt*: int32
    length*: int
  PDynArrayRec = ptr TDynArrayRec
  DynamicArrayData[T] = ptr UncheckedArray[T]
  DynamicArray* [T] {.pure, final, packed.} = object
    data: DynamicArrayData[T]
  # UniqueDynamicArray* [T] = distinct DynamicArray* [T]

template needLength(len: int32): int32 =
  let length = len
  length + sizeof(StrRec).int32 + 1 + ((length + 1) and 1)
  
proc newAnsiString(length: int32): AnsiStringData =
  if length > 0 :
    # Alloc an extra null for strings with even length.  This has no actual cost
    # since the allocator will round up the request to an even size anyway.
    # All widestring allocations have even length, and need a double null terminator.
    var p = cast[StrRecPtr](getMemory(needLength(length)))
    result = cast[ptr UncheckedArray[char]](cast[ByteAddress](p) + sizeof(StrRec))
    p.length = length
    p.refCnt = 1
    cast[ptr int16](cast[ByteAddress](result) + (length and not 1))[] = 0'i16  # length guaranteed >= 2

template rec* (s: AnsiStringData): StrRecPtr = 
  cast[StrRecPtr](cast[ByteAddress](s) - sizeof(StrRec))

template rec* (s: AnsiString): StrRecPtr = s.data.rec 

template rec* (s: WeakPartialString): StrRecPtr = 
  cast[StrRecPtr](cast[ByteAddress](s.data) - sizeof(StrRec) - s.delta)

template rec* [T](a: DynamicArrayData[T]): PDynArrayRec =
  cast[PDynArrayRec](cast[ByteAddress](a) - sizeof(TDynArrayRec))

template rec* [T](a: DynamicArray[T]): PDynArrayRec = a.data.rec

template data(rec: StrRecPtr): AnsiStringData = 
  cast[AnsiStringData](cast[ByteAddress](rec) + sizeof(StrRec))

template isNil* (s: SomeDelphiString): bool = s.data == nil

template isNil* [T] (a: DynamicArray[T]): bool = a.data == nil

template arrayMemSize[T] (len: int): int = (len) * sizeof(T) + sizeof(TDynArrayRec)

template data(p: PDynArrayRec, T): DynamicArrayData[T] =
  cast[DynamicArrayData[T]](cast[ByteAddress](p) + sizeof(TDynArrayRec))

proc newDynamicArray [T] (length: int): DynamicArrayData[T] =
  if length > 0 :
    var p = cast[PDynArrayRec](allocMemory(arrayMemSize[T](length)))
    result = p.data(T)
    p.length = length
    p.refCnt = 1

template atomicInc*(memLoc: var int32, x: int32 = 1): int32 =
  when sizeof(int) == sizeof(int32) :
    cast[int32](system.atomicInc(cast[ptr int](addr memLoc)[], cast[int](x)))
  else: 
    {.fatal: "not available for 64bit".}

template atomicDec*(memLoc: var int32, x: int32 = 1): int32 =
  when sizeof(int) == sizeof(int32) :
    cast[int32](system.atomicDec(cast[ptr int](addr memLoc)[], cast[int](x)))
  else: 
    {.fatal: "not available for 64bit".}
  
proc refCount* (s: AnsiString): int {.inline.} =
  if not isNil(s):
    result = s.rec.refCnt.int  

proc refCount* [T] (a: DynamicArray[T]): int {.inline.} =
  if not isNil(a):
    result = a.rec.refCnt.int  

proc len* (s: AnsiString): int32 {.inline.} =
  if not isNil(s):
    result = s.rec.length

template low* (s: AnsiString): int32 = 0

template high* (s: AnsiString): int32 =
  result = s.len - 1
  
proc len* [T] (a: DynamicArray[T]): int {.inline.} =
  if not isNil(a):
    result = a.rec.length

template low* [T] (a: DynamicArray[T]): int = 0

template high* [T] (a: DynamicArray[T]): int =
  result = a.len - 1
    
proc toString* (s: AnsiString): string = 
  let length = s.len
  # echo length
  if length > 0 :
    result = newString(length)
    moveMem(addr result[0], s.data, length)
  else : result = ""  

template `$`* (s: AnsiString): string = toString(s)
  
template incRef(s: AnsiString) =
  let p = s.rec
  if p[].refCnt > 0 : # no string literal
    discard atomicInc(p[].refCnt)

template incRef[T] (a: DynamicArray[T]) =
  let p = a.rec
  if p[].refCnt > 0 : # no string literal
    discard atomicInc(p[].refCnt)

template decRef(s: AnsiString|AnsiStringData) =
  let p = s.rec
  if p[].refCnt > 0 : # no string literal
    if atomicDec(p[].refCnt) == 0:
      freeMemory(p)   

template decRef[T] (a: DynamicArray[T]|DynamicArrayData[T]) =
  let p = a.rec
  if p[].refCnt > 0 : # no string literal
    if atomicDec(p[].refCnt) == 0:
      freeMemory(p)   
      
proc `=destroy`* (s: var AnsiString) =
  echo "delete: ", s, " ", s.refCount
  if not isNil(s):
    decRef(s)
    s.data = nil

proc `=destroy`* [T] (a: var DynamicArray[T]) =
  if not isNil(a):
    decRef(a)
    a.data = nil
    
proc `=sink`*(a: var AnsiString, b: AnsiString) =
  if not isNil(a) : # and a.data != b.data:
    decRef(a)
  a.data = b.data

proc `=sink`* [T] (a: var DynamicArray[T], b: DynamicArray[T]) =
  if not isNil(a) : # and a.data != b.data:
    decRef(a)
  a.data = b.data
  
proc `=`* (dest: var AnsiString, source: AnsiString) = 
  echo "assign: ", source, " to is empty: ", dest.isNil
  var s = source.data
  if not isNil(source) :
    var p = source.rec
    if p[].refCnt < 0 : # string literal
      let length = p.length
      s = newAnsiString(length)
      moveMem(s, source.data, length)
      p = s.rec
    discard atomicInc(p[].refCnt)
  var d = dest.data
  #cast[ptr Pointer](addr dest)[] = s.Pointer
  dest.data = s
  if not isNil(d) : decRef(d)

proc `=`* [T](dest: var DynamicArray[T], source: DynamicArray[T]) = 
  #echo "assign: ", source
  var s = source.data
  if not isNil(source) :
    var p = source.rec
    if p[].refCnt < 0 : # string literal
      let length = p.length
      s = newDynamicArray[T](length)
      moveMem(s, source.data, length)
      p = s.rec
    discard atomicInc(p[].refCnt)
  var d = dest.data
  #cast[ptr Pointer](addr dest)[] = s.Pointer
  dest.data = s
  if not isNil(d) : decRef(d)

proc uniqueStringOfLen* (s: var AnsiString, wantedLen: int32) =
  let data = s.data
  let minLen = if wantedLen > s.len : s.len else : wantedLen
  if data == nil or data.rec.refCnt > 1:
    s.data = newAnsiString(wantedLen)
    if data != nil :
      for i in 0 ..< minLen: 
        s.data[i] = data[i] 
      decRef(data)
  else :
    var p = cast[StrRecPtr](reallocMemory(data.rec, needLength(wantedLen)))
    s.data = p.data
    p.refCnt = 1
    p.length = wantedLen
    cast[ptr int16](cast[ByteAddress](s.data) + (wantedLen and not 1))[] = 0'i16  # length guaranteed >= 2
    
proc uniqueStringImpl(s: var AnsiString, rec: StrRecPtr) =
  # s != nil and s.refCount > 1
  let wantedLen = rec.length
  s.data = newAnsiString(wantedLen)
  moveMem(s.data, rec.data, wantedLen)
  discard atomicDec(rec.refCnt)
  
template uniqueString* (s: var AnsiString) =
  if not s.isNil :
    let res = s.rec
    if res.refCnt > 1 :     
      uniqueStringImpl(s, res)
      
template `[]`* (s: AnsiString, x: int): char = s.data[x]

template `[]`*  [T] (a: DynamicArray[T], x: int): T = a.data[x]

template `[]=`*  [T] (a: var DynamicArray[T], x: int, v: T) = a.data[x] = v

proc uniqueArrayOfLen* [T](a: var DynamicArray[T], wantedLen: int) =
  let data = a.data
  let minLen = if wantedLen > a.len : a.len else : wantedLen
  if data == nil or data.rec.refCnt > 1:
    # echo "need new array of len ", wantedLen
    a.data = newDynamicArray[T](wantedLen)
    if data != nil :
      for i in 0 ..< minLen: 
        a.data[i] = data[i] 
      decRef(data)
  else :
    # echo "realloc array ", a.len, " to new len: ", wantedLen, " minLen: ", minLen
    when not T is SomeNumber : 
      # when shrinking we need to clean up
      for i in minLen ..< a.len : a.data[i] = default
    var p = cast[PDynArrayRec](reallocMemory(data.rec, arrayMemSize[T](wantedLen)))
    a.data = p.data(T)
    for i in minLen ..< wantedLen: reset(a.data[i])
    p.length = wantedLen

proc uniqueArrayImpl [T](a: var DynamicArray[T], rec: PDynArrayRec) =
  # a != nil and a.refCount > 1
  let data = a.data
  a.data = newDynamicArray[T](rec.length)
  for i in 0 ..< rec.length : 
    a[i] = data[i] 
  atomicDec(rec.refCnt)

template uniqueArray* (s: var AnsiString) =
  if not s.isNil :
    let res = s.rec
    if res.refCnt > 1 :     
      uniqueArrayImpl(s, res)      
      
proc toAnsiString* (s: cstring): AnsiString =
  echo "from cstring: ", s
  let length = s.len.int32
  if length > 0 :
    result.data = newAnsiString(length)
    moveMem(result.data, s, length)

proc toAnsiString* (s: string): AnsiString =
  echo "from string: ", s
  let length = s.len.int32
  if length > 0 :
    result.data = newAnsiString(length)
    moveMem(result.data, unsafeAddr s[0], length)

template ds* (s: static[string|cstring]):AnsiString =
  toAnsiString(s)

proc da* [T] (a: openarray[T]): DynamicArray[T] =
  result.data = newDynamicArray[T](a.len)
  for i in 0 ..< a.len: result[i] = a[i]

proc concat (a, b: AnsiString): AnsiStringData =
  let la = a.rec.length
  let lb = b.rec.length
  result = newAnsiString(la+lb)
  moveMem(result, a.data, la)
  moveMem(addr result[la], b.data, lb)

proc concat [T] (a, b: DynamicArray[T]): DynamicArrayData[T] =
  let la = a.rec.length
  let lb = b.rec.length
  result = newDynamicArray[T](la+lb)
  for i in 0 ..< la: result[i] = a[i]
  for i in 0 ..< lb: result[la + i] = b[i]
  
proc `&`* (a, b: AnsiString): AnsiString {.inline.} =
  if not isNil(a) :
    if not isNil(b): result.data = concat(a,b)
    else :
      incRef(a)
      result.data = a.data      
  elif not isNil(b) :
    incRef(b)
    result.data = b.data

proc `&`* [T] (a, b: DynamicArray[T]): DynamicArray[T] =
  if not isNil(a) :
    if not isNil(b): result.data = concat(a,b)
    else :
      incRef(a)
      result.data = a.data      
  elif not isNil(b) :
    incRef(b)
    result.data = b.data

proc setLen* (dest: var AnsiString, newLen: Natural) =
  uniqueStringOfLen(dest, newLen)

proc setLen* [T](dest: var DynamicArray[T], newLen: Natural) =
  uniqueArrayOfLen(dest, newLen)

proc add* [T] (dest: var DynamicArray[T], b: DynamicArray[T]) =
  if not isNil(dest) :
    if not isNil(b) :
      let lena = dest.len 
      uniqueStringOfLen(dest, lena + b.len)
      for i in 0 ..< b.len : dest[lena + i] = b[i]
  elif not isNil(b) :
    incRef(b)
    dest.data = b.data

proc add* [T] (dest: var DynamicArray[T], v: T) =
  if not isNil(dest) :
    let la = dest.len
    uniqueArrayOfLen(dest, la + 1)
    dest[la] = v
  else :
    dest.data = newDynamicArray[T](1)
    dest[0] = v
    

template `&=`* [T] (dest: var DynamicArray[T], b: DynamicArray[T]) =
  add(dest, b)

iterator items* [T](a: DynamicArray[T]): T {.inline.} =
  var i: int
  while i < a.len :
    yield a[i]
    inc(i)
  
iterator pairs* [T](a: DynamicArray[T]): (T, int) {.inline.} =
  var i: int
  while i < a.len :
    yield (a[i], i)
    inc(i)
  
template offset(s: AnsiString): int32 = 0
template offset(s: WeakPartialString): int32 = s.delta

template offset* (s: SomeDelphiString, index: int32) = offset(s) + index
template offset* (s: SomeDelphiString, index: int) = offset(s) + index.int32

proc len* (s: WeakPartialString): int32 {.inline.} = s.length

template `[]`* (s: WeakPartialString, x: int): char = s.data[x]

proc weakSlice* (source: SomeDelphiString, start: int32): WeakPartialString {.inline.} = 
  let max = source.len
  if start >= 0 and start < max : 
    result.data = cast[AnsiStringData](addr source.data[start])
    result.delta = start + source.offset
    result.length = max - start

proc weakSlice* (source: SomeDelphiString, start: int32, length: int32): WeakPartialString {.inline.} = 
  let max = source.len
  if start >= 0 and start < max and length > 0 : 
    result.data = cast[AnsiStringData](addr source.data[start])
    result.delta = start + source.offset
    if start + length <= max : result.length = length
    else : result.length = max - start

proc weakSlice* (source: SomeDelphiString): WeakPartialString {.inline.} = 
  result.data = source.data
  result.delta = source.offset
  result.length = source.len

iterator pairs* (s: SomeDelphiString): (char, int32) {.inline.} =
  var i: int32
  while i < s.len :
    yield (s[i], i)
    inc(i)

proc startsWith* (s: SomeDelphiString; sub: AnsiString | WeakPartialString): bool =
  if sub.len > s.len: return false
  for i in 0'i32 ..< sub.len :
    if s[i] != sub[i] : return false
  return true

proc endsWith* (s: SomeDelphiString; sub: AnsiString | WeakPartialString): bool =
  let m = s.len - 1
  let n = sub.len - 1
  if n > m: return false
  for i in 0'i32 .. n :
    if s[m - i] != sub[n - i] : return false
  return true

proc indexOfBrute* (s: SomeDelphiString; sub: AnsiString | WeakPartialString): int32 =
  let subLen = sub.len  
  let m = s.len - subLen
  for i in 0'i32 .. m.int32 :
    var k = subLen - 1
    while true :
      if k >= 0 : 
        if s[i+k] != sub[k] : break
        dec k
      else : return i
  return -1'i32

proc indexOf* (s: SomeDelphiString; sub: AnsiString | WeakPartialString): int32 =
  let subHigh = sub.len - 1
  if subHigh < 2 : return indexOfBrute(s, sub)
  let m = s.len
  if m > subHigh :      
    var shash: uint = 0
    for i in 0 .. subHigh: 
      shash = shash + sub[i].uint
    var hash: uint = 0 
    for i in 0 ..< subHigh: hash = hash + s[i].uint
    var i = subHigh
    while i < m:
      hash = hash + s[i].uint
      let ii = i - subHigh
      if hash == shash :
        var k = subHigh
        while true:
          if k >= 0:  
            if sub[k] != s[ii + k]: break
            dec k
          else : return ii
      hash -= s[ii].uint # shl subHigh
      inc i
  return -1


proc makeKMPPrefix* (s: SomeDelphiString): seq[int32] =
  let n = s.len
  result.newSeq(n + 1)
  result[0] = -1
  var j = -1'i32
  var i = 0'i32
  while i < n :
    while j >= 0 and s[j] != s[i] : j = result[j]
    inc i
    inc j
    result[i] = j


proc findKMP* (s: SomeDelphiString; sub: AnsiString | WeakPartialString; kmp: var seq[int32]): int32 =
  let m = s.len
  let n = sub.len
  if kmp.len != n + 1: kmp = makeKMPPrefix(sub)
  var i = 0'i32
  var j = 0'i32
  while i < m:
    while j >= 0 and s[i] != sub[j] : j = kmp[j]
    inc i
    inc j
    if j == n : return i - n
  return -1

proc findKMPiter* (s: SomeDelphiString; sub: AnsiString | WeakPartialString): int32 =
  let m = s.len
  let n = sub.len
  var kmp: seq[int32]
  kmp.newSeq(n + 1)
  var pj = -1'i32
  var pi = 0'i32
  kmp[0] = -1
  var i = 0'i32
  var j = 0'i32
  while i < m:
    while j >= 0 and s[i] != sub[j] : 
      while pi < j :
        while pj >= 0 and sub[pj] != sub[pi] : pj = kmp[pj]
        inc pi
        inc pj
        kmp[pi] = pj
      j = kmp[j]
    inc i
    inc j
    if j == n : return i - n
  return -1
  