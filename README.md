# idaxex

idaxex is a native loader plugin for IDA Pro 9.4, adding support for loading Xbox 360 XEX and Xbox XBE executables.

Originally started as an [IDAPython loader](https://github.com/emoose/reversing/blob/master/xbox360.py), work was continued as a native DLL to solve the shortcomings of it.

This should have the same features as xorloser's great Xex Loader (for IDA 6 and older), along with additional support for some early non-XEX2 formats, such as XEX1 used on beta-kits.

XBE files are additionally supported, adding a few extra features over the loader included with IDA.

## Supported formats

Includes support for the following Xbox executables:
- XEX2 (>= kernel 1861)
- XEX1 (>= 1838)
- XEX% (>= 1746)
- XEX- (>= 1640)
- XEX? (>= 1529)
- XEX0 (>= 1332)
- XBE (>= XboxOG ~3729)

## Features

- Can handle compressed/uncompressed images, and encrypted/decrypted (with support for retail, devkit & pre-release encryption keys)
- Reads in imports & exports into the appropriate IDA import/export views.
- Automatically names imports that are well-known, such as imports from the kernel & XAM, just like xorloser's loader would.
- PE sections are created & marked with the appropriate permissions as given by the PE headers.
- AES-NI support to help improve load times of larger XEXs.
- Marks functions from .pdata exception directory & allows IDA's eh_parse plugin to read exception information.
- Passes codeview information over to IDA, allowing it to prompt for & load PDBs without warnings/errors.
- Patched bytes can be written back to input file via IDA `Apply patches to input` option (works for all XBEs, XEX must be both uncompressed & decrypted using `xextool -eu -cu input.xex` first)
- XBE: adds kernel imports to IDA imports view
- XBE: tries naming SDK library functions using [XbSymbolDatabase](https://github.com/Cxbx-Reloaded/XbSymbolDatabase) & data from XTLID section

## Install
Prebuilt releases are available for supported IDA Pro 9.x versions.

Copy the loader files into the matching IDA installation's loader/plugin directory, or follow the build steps below and install the resulting binary into your IDA SDK output folder.

For PPC Altivec analysis, the PPCAltivec plugin remains a useful companion: https://github.com/hayleyxyz/PPC-Altivec-IDA

## Building

Make sure to clone repo recursively for excrypt submodule to get pulled in.

This project requires the IDA C++ SDK that matches the target IDA installation. A normal IDA installation is not enough on its own; it does not ship the complete SDK headers and `ida.lib` import library this loader needs.

Starting with IDA 9.2, Hex-Rays publishes the SDK as an open-source GitHub repository. `IDASDK` may point either to the SDK checkout root that contains `src\`, or directly to the `src\` directory. The build scripts normalize both layouts.

**Windows**

- Point `IDASDK` environment variable at your IDA SDK 9.4 checkout root or `src` directory.
- Run `scripts\Check-IdaEnv.ps1 -IdaExe "A:\Program Files\IDA Professional 9.4\idat.exe" -ExpectedIdaVersion 9.4 -ExpectedSdkVersion 940 -ExpectedSdkBranch releases/9.4.0 -RequireOfficialSdk -AllowPublicSdkMacroLag -RequireBuildReady` to verify the IDA install and official SDK checkout layout. The public `releases/9.4.0` SDK branch currently reports `IDA_SDK_VERSION 930`; the helper records that as `official-public-9.4-sdk-macro-lags` instead of hiding it.
- Run CMake to generate a VS solution: `cmake -B build -G "Visual Studio 17 2022" -A x64`
- Build with `cmake --build build` or use the `idaxex.slnx` file.
- idaxex.dll will be built at `$IDASDK\src\bin\loaders\idaxex.dll`

**Linux**

- Use the IDA SDK CMake bootstrap from `src/cmake/bootstrap.cmake` if your SDK tree has it, or the standalone [ida-cmake](https://github.com/allthingsida/ida-cmake) bootstrap if you keep that package separately.
- Make sure `IDASDK` points at the SDK root.
- Run `cmake -S . -B build` from the repo root.
- Run `cmake --build build`.
- To build `xex1tool`, run `cmake -S xex1tool -B xex1tool/build` and `cmake --build xex1tool/build`.

On newer IDA SDKs, `libida.so` may be the correct library name in place of `libida64.so`.

## Credits
Based on work by the Xenia project, XEX2.bt by Anthony, xextool 0.1 by xor37h, Xex Loader & x360_imports.idc by xorloser, xkelib, XeCLI, and probably many others I forgot to name.

Thanks to everyone involved in the Xbox 360 modding/reverse-engineering community!

XTLID parsing supported thanks to the [XboxDev/xtlid project](https://github.com/XboxDev/xtlid).

# xex1tool
Also included is an attempt at recreating xorloser's XexTool, for working with older pre-XEX2 executables.  
(The name is only to differentiate it from the original XexTool - it'll still support XEX2 files fine)

So far it can print info about the various XEX headers via `-l`, and extract the basefile (PE/XUIZ) from inside the XEX.

For XEX files that are both decrypted & decompressed xex1tool can also convert a VA address to a file offset for you, making file patching a little easier.
