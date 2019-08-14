
type
  MemoryMangerRec* {.final, pure.} = object 
    getMem*: proc (size: csize): pointer {.delphiCall.}
    freeMem*: proc (p: pointer): csize {.delphiCall.}
    reallocMem*: proc (p: pointer, size: csize): pointer {.delphiCall.}
    allocMem*: proc (size: csize): pointer {.delphiCall.}

var
  memManager* : MemoryMangerRec

# include nbcommon

proc NimMain() {.importc, cdecl.}

proc nimGetMem(size: Natural): pointer {.delphiCall.} = allocShared(size)
proc nimFreeMem(p: pointer): csize {.delphiCall.} = deallocShared(p)
proc nimReallocMem(p: pointer, size: csize): pointer {.delphiCall.} = reallocShared(p, size)
proc nimAllocMem(size: csize): pointer {.delphiCall.} = allocShared0(size)


proc setMemoryManager* (mem: var MemoryMangerRec) {.expDelphi.} =
  NimMain()
  if mem.getMem == nil :
    mem.getMem = nimGetMem
    mem.freeMem = nimFreeMem
    mem.reallocMem = nimReallocMem
    mem.allocMem = nimAllocMem
  memManager = mem

proc getMemory* (size: int): pointer {.inline.} =
  result = memManager.getMem(size)

proc freeMemory* (p: pointer): int {.inline, discardable.} =
  if not isNil(p): 
    result = memManager.freeMem(p).int

proc reallocMemory* (p: pointer, size: int): pointer {.inline.} =
  if isNil(p) :
    result = getMemory(size)
  else :
    result = memManager.reallocMem(p, size)

proc allocMemory* (size: int): pointer {.inline.} =
  result = memManager.allocMem(size)
    