# warning: fastcall changed to delphi register call here !!

when defined(bcc):
  static: echo "bcc"
  {.pragma: expDelphi, fastcall, exportc: "$1", dynlib.}
elif false and defined(gcc) and defined(registerCalling):
  {.pragma: expDelphi, exportc: "__attribute__((regparm(3))) $1", dynlib.}
else:
  {.pragma: expDelphi, fastcall, exportc: "$1", dynlib.}
  {.pragma: expDelphiCdecl, cdecl, exportc: "$1", dynlib.}


{.emit: """/*TYPESECTION*/
#  undef N_FASTCALL
#  define N_FASTCALL(rettype, name) rettype (__attribute__((regparm(3))) name)
#  undef N_FASTCALL_PTR
#  define N_FASTCALL_PTR(rettype, name) rettype (__attribute__((regparm(3))) *name)
""".}

{.pragma: delphiCall, fastcall.}
  
