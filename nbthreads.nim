
# include nbcommon

proc initForeignThread*() {.expDelphi.} =
  setupForeignThreadGc()

proc doneForeignThread*() {.expDelphi.} =
  tearDownForeignThreadGc()
  

