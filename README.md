# nimbackend

WARNING this a WIP - many bugs expected ! Currently only tested with Delphi 2007 on Win32 !

**nim** backend for delphi. We have to go into the deep because **nim** compiles to C or C++ 
and the interop between Delphi and **nim** and therefore C / C++ is difficult because of many reasons:

- Delphi uses its own calling convention **register**. So calling from C into Delphi is almost impossible.
- One can use the the bcc32c (C++ Compiler from Embarcadero), but it is still not very compliant to Standard C
  and the overall experience together with **nim** is frustrating.
- **nim** does automatic memory management with GC or the --newruntime. Delphi has manual memory management together with some automatic management for
  some types like `strings` and `dynamic arrays` or `Variant`
- Sometimes the size of Delphi `integer` types is inconsistent over different version - `NativeInt` for example. 
- and many more...

After many tests with different approaches, clean and dirty, I have chosen to get my hands dirty. My approach does all, what is recommended not to do !
So be careful and don't trust me.

- As C compiler currently only a actual mingw32 GCC (8.1 +) will work, since it has a calling convention which is compatible with the Delphi register calling convention.    For this to work **nim** must be convinced to use this as its **fastcall** convention. For this all **nim** code must be compiled with `--include:nbcommon`
- Be aware that you will get problems when you include **nim** code which needs the default **fastcall** convention. In reality this should be a rare case, 
  but keep it in mind.
- **nim** and Delphi must use the same memory manager - at least for the shared data. We have the option to use the **nim** memory manager in Delphi or a custom Delphi
  memory manager in **nim**. Both is supported.
- When a thread is created in Delphi this thread must be registered in **nim**. This is done with a hook procedure on the Delphi side.
- For both reasons you must include the `nimbackend` unit into your Delphi project at a very early stage. If you choose to use the **nim** memory manager, 
  it must be the first unit in your project. If you use a custom Delphi memory mananger like FastMM or BrainMM, nimbackend should be imported right after them.
- The behavior of the managed Delphi data types must be mimicked in **nim**. I am currently working on `AnsiString` and `Dynamic Arrays`
- Since it is not possible to static link C (compiled with GCC) and Delphi Code, the **nim** part of an application is compiled into a DLL. 
  But this is not a normal DLL since it's imports and exports are application specific - for two different Delphi applications, you will need two differently 
  named backend DLLs.
- Since a Delphi application can not export symbols (why not ???) we must use a manual generated export table for the Delphi code called from **nim**. 
  I am looking into an (semi) automatic generation for this.
- Care has to be taken how function results are returned. In Delphi for some types like strings, records or dynamic arrays a hidden pointer is passed as the last
  parameter which receives the result.
- Delphi methods pass the `Self` as the first parameter, which matches nicely to **nim**
- Same for Delphi Callbacks `procedure (..) of object`

