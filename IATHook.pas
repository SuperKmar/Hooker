unit IATHook;

interface

uses
  Windows, JwaTlHelp32, SysUtils, psapi; //PSAPI, was used here, can't find anymore :(

type
  TTHREADENTRY32 = packed record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ThreadID: DWORD;
    th32OwnerProcessID: DWORD;
    tpBasePri: Longint;
    tpDeltaPri: Longint;
    dwFlags: DWORD;
  end;

  ///////////////////////////////////////////////////////////////////////////////////

  TImageImportDescriptor=packed record
    OriginalFirstThunk    : DWORD;
    TimeDateStamp         : DWORD;
    ForwarderChain        : DWORD;
    Name                  : DWORD;
    FirstThunk            : DWORD;
  end;
  PImageImportDescriptor=^TImageImportDescriptor;

  PIMAGE_IMPORT_BY_NAME = ^IMAGE_IMPORT_BY_NAME;
  {$EXTERNALSYM PIMAGE_IMPORT_BY_NAME}
  _IMAGE_IMPORT_BY_NAME = record
    Hint: Word;
    Name: array [0..0] of Char;
  end;
  {$EXTERNALSYM _IMAGE_IMPORT_BY_NAME}
  IMAGE_IMPORT_BY_NAME = _IMAGE_IMPORT_BY_NAME;
  {$EXTERNALSYM IMAGE_IMPORT_BY_NAME}
  TImageImportByName = IMAGE_IMPORT_BY_NAME;
  PImageImportByName = PIMAGE_IMPORT_BY_NAME;

  ////////////////////////////////////////////////////////////////////////////////////////////

  //TModuleInfo = packed record
  //  OverlayNumber: Word;  // Overlay number
  //  LibraryIndex: Word;   // Index into sstLibraries subsection
  //                                          // if this module was linked from a library
  //  SegmentCount: Word;   // Count of the number of code segments
  //                        // this module contributes to
  //  DebuggingStyle: Word; // Debugging style  for this  module.
  //  NameIndex: DWORD;     // Name index of module.
  //  TimeStamp: DWORD;     // Time stamp from the OBJ file.
  //  Reserved: array[0..2] of DWORD; // Set to 0.
  //  Segments: array[0..0] of TSegmentInfo;
  //                        // Detailed information about each segment
  //                        // that code is contributed to.
  //                        // This is an array of cSeg count segment
  //                        // information descriptor structures.
  //end;


  /////////////////////////////////////////////////////////////////////////////////////////////


  //class MODULEINFO(Structure):
  //     _fields_ = [
  //         ("lpBaseOfDll",     LPVOID),    # remote pointer
  //         ("SizeOfImage",     DWORD),
  //         ("EntryPoint",      LPVOID),    # remote pointer
  // ]
 // # typedef struct _MODULEINFO {
 //53  #   LPVOID lpBaseOfDll;
 //54  #   DWORD  SizeOfImage;
 //55  #   LPVOID EntryPoint;
 //56  # } MODULEINFO, *LPMODULEINFO;
 TModuleInfo = record
   lpBaseOfDLL: pointer;
   SizeOfImage: DWord;
   EntryPoint: Pointer;
 end;



var
  message:String;


const
  IMPORTED_NAME_OFFSET   = $00000002;
  IMAGE_ORDINAL_FLAG32   = $80000000;
  IMAGE_ORDINAL_MASK32   = $0000FFFF;
  THREAD_ALL_ACCESS      = $001F03FF;
  THREAD_SUSPEND_RESUME  = $00000002;
  TH32CS_SNAPTHREAD      = $00000004;
  TH32CS_SNAPPROCESS     = $00000002;

function CreateToolhelp32Snapshot(dwFlags, th32ProcessID: DWORD): dword stdcall;
                                  external 'kernel32.dll';
function Thread32First(hSnapshot: THandle; var lpte: TThreadEntry32): BOOL stdcall;
                                  external 'kernel32.dll';
function Thread32Next(hSnapshot: THandle; var lpte: TThreadENtry32): BOOL stdcall;
                                  external 'kernel32.dll';
function OpenThread(dwDesiredAccess: dword;
                    bInheritHandle: bool;
                    dwThreadId: dword): dword; stdcall;
                                  external 'kernel32.dll';

function PatchIAT(Module: HMODULE; LibraryName, ProcName: PAnsiChar; HookProc: Pointer; var SaveProc: Pointer): Boolean;
function StopThreads(): boolean;
function RunThreads(): boolean;

function placeholder():boolean; //this might be called "DLLMain" - try to rename later


//Function FileWrite (Handle : THandle; const Buffer; Count : Longint) : Longint;
function my_FileWrite(Handle : THandle; const Buffer; Count : Longint) : Longint;
//Function FileRead (Handle : THandle; out Buffer; Count : longint) : Longint;
function my_FileRead (Handle : THandle; out Buffer; Count : longint) : Longint;

implementation
function my_FileWrite(Handle : THandle; const Buffer; Count : Longint) : Longint;
begin
  result := FileWrite(Handle, Buffer,  Count );
//  message:= 'File is being written';
  messagebox(0,'File is being written!', 'Some program is doing something', 0);
end;

function my_FileRead (Handle : THandle; out Buffer; Count : longint) : Longint;
begin
  result := FileRead(Handle, Buffer, Count);
  messagebox(0, 'File is being read!', 'Some program is doing something', 0);
end;


function placeholder():boolean;
var
  SaveProcWrite, SaveProcRead: PCardinal;
  Module:HMODULE;
  temp:string;

function quickres:string;
begin
  if placeholder then result:= 'Success' else result := 'failure';
end;

begin
  result:=true;

  //stop proc - there's an app for that
  result:= result and StopThreads();
  temp := 'Threads have stopped: '+quickres;
  messagebox(0, PChar(temp), 'Library police', 0);
  ////StopProcess( TTHREADENTRY32.th32OwnerProcessID );   //assume thix will fix itself when psapi gets fixed

  /////////////////////////////////////////////////////////////////////////////////////////////////////////////
  ////start hooking - what we need is...
  /////////////////////////////////////////////////////////////////////////////////////////////////////////////

  //function PatchIAT(Module: HMODULE; LibraryName, ProcName: PAnsiChar; HookProc: Pointer; var SaveProc: Pointer): Boolean;
  Module := GetModuleHandle('Kernel32'); // what module? what to write here?
  temp := 'Module has beed identified: ' + quickres + ' - '+ inttostr(integer(Module));
  messagebox(0, PChar(temp) , 'Library police', 0);
  result:= result and   PatchIAT(Module, PAnsiChar('Kernel32'), PAnsiChar('FileWrite'), @My_FileWrite, SaveProcWrite);
  temp := 'Filewrite has been patched: ' + quickres + inttostr(integer(SaveProcWrite));
  messagebox(0, PChar(temp) , 'Library police', 0);
  result:= result and   PatchIAT(Module, 'Kernel32', 'FileRead' , @My_FileRead , SaveProcRead ); //i have no idea if this will just work -_- fingers crossed
  temp:= 'File read has been patched: ' + quickres;
  messagebox(0, PChar(temp) , 'Library police', 0);


  /////////////////////////////////////////////////////////////////////////////////////////////////////
  //set transfer method (i guess by pipe? virtual mem should work as well...)
  /////////////////////////////////////////////////////////////////////////////////////////////////////
  //i'll do it after message box shows something

  //resume proc - there's an app for that
  //RunProcess( TTHREADENTRY32.th32OwnerProcessID );
  result:= result and   RunThreads();
  temp := 'Threads have resumed' + quickres;
  messagebox(0, PChar(temp) , 'Library police', 0);

  //  result is true if everything is ok, else false;
end;

////////////////////////////////////////////////////////////////////////////////////////////////////
//BOOL WINAPI GetModuleInformation(
//327  #   __in   HANDLE hProcess,
//328  #   __in   HMODULE hModule,
//329  #   __out  LPMODULEINFO lpmodinfo,
//330  #   __in   DWORD cb
//331  # );
//332 -def GetModuleInformation(hProcess, hModule, lpmodinfo = None):
//333      _GetModuleInformation = windll.psapi.GetModuleInformation
//334      _GetModuleInformation.argtypes = [HANDLE, HMODULE, LPMODULEINFO, DWORD]
//335      _GetModuleInformation.restype = bool
//336      _GetModuleInformation.errcheck = RaiseIfZero
//337
//338      if lpmodinfo is None:
//339          lpmodinfo = MODULEINFO()
//340      _GetModuleInformation(hProcess, hModule, byref(lpmodinfo), sizeof(lpmodinfo))
//341      return lpmodinfo

//BOOL WINAPI K32GetModuleInformation(HANDLE process, HMODULE module,
//                                    MODULEINFO *modinfo, DWORD cb)
//{
//    LDR_MODULE ldr_module;
//
//    if (cb < sizeof(MODULEINFO))
//    {
//        SetLastError(ERROR_INSUFFICIENT_BUFFER);
//        return FALSE;
//    }
//
//    if (!get_ldr_module(process, module, &ldr_module))
//        return FALSE;
//
//    modinfo->lpBaseOfDll = ldr_module.BaseAddress;
//    modinfo->SizeOfImage = ldr_module.SizeOfImage;
//    modinfo->EntryPoint  = ldr_module.EntryPoint;
//    return TRUE;
//}


//
//Function GetModuleInformation(hProcess,hModule:THandle; lpmodinfo: pointer; cb:Dword):pointer; //type
//begin
//  //if lpModInfo = nil then lpmodInfo := MODULEINFO(); //no such function - not even in example
//  //_GetModuelInformation(hProcess, hModule, byref(lpmodinfo),sizeof(lpmodinfo));
//
//  ldr_module: LDR_MODULE; // no friggen way this will work
//  if cd < sizeof(MODULEINFO) then
//  begin
//    SetLastError( ERROR_INSUFFICIENT_BUFFER );
//    result  := false;
//    exit;
//  end;
//
//  if ( not get_ldr_module(process, module, @ldr_module)) then //check what it returns - might not be a bool
//  begin
//    result:= false;
//    exit;
//  end;
//
//  lpmodinfo.lpBaseOfDll := ldr_module.BaseAddress;
//  lpmodinfo.SizeOfImage := ldr_module.SizeOfImage;
//  lpmodinfo.EntryPoint  := ldr_module.EntryPoint;
//  result   :=  true;
//end;
//
//  result:=lpModInfo;
//end;
//
//////////////////////////////////////////////////////////////////////////////////////////////////////
////BOOL get_ldr_module(HANDLE process, HMODULE module, LDR_MODULE *ldr_module)
////{
////    MODULE_ITERATOR iter;
////    INT ret;
////
////    if (!init_module_iterator(&iter, process))
////        return FALSE;
////
////    while ((ret = module_iterator_next(&iter)) > 0)
////        /* When hModule is NULL we return the process image - which will be
////         * the first module since our iterator uses InLoadOrderModuleList */
////        if (!module || module == iter.ldr_module.BaseAddress)
////        {
////            *ldr_module = iter.ldr_module;
////            return TRUE;
////        }
////
////    if (ret == 0)
////        SetLastError(ERROR_INVALID_HANDLE);
////
////    return FALSE;
////}
//
//get_ldr_module(process: THandle; module HModule; ^ldr_module: LDR_MODULE) //totally worng - fix later
//var
//  iter: MODULE_ITERATOR;
//  ret: integer;
//begin
//
//  if (not init_module_iterator(@iter, process))
//  begin
//    result:= false;
//    exit;
//  end
//
//  while ((ret) > 0) do
//  begin
//    ret := module_iterator_next(@iter);
//
//    if (not (module or module = iter.iidl_module.BaseAdress) ) //why does this look like i'm drunk
//    begin
//      ^ldr_module := iter.idr_module;
//      result:= true;
//      exit;
//    end;
//
//    if ret = 0 then setlasterror(ERROR_INVALID_HANDLE);
//
//    result:=false;
//  end;
//
//end;

///////////////////////////////////////////////////////////////////////////////////////////////////

function StopProcess(ProcessId: dword): boolean;
var
 Snap: dword;
 CurrTh: dword;
 ThrHandle: dword;
 Thread:TThreadEntry32;
begin
  Result := false;
  CurrTh := GetCurrentThreadId;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if Snap <> INVALID_HANDLE_VALUE then
     begin
     Thread.dwSize := SizeOf(TThreadEntry32);
     if Thread32First(Snap, Thread) then
     repeat
     if (Thread.th32ThreadID <> CurrTh) and (Thread.th32OwnerProcessID = ProcessId) then
        begin
        ThrHandle := OpenThread(THREAD_SUSPEND_RESUME, false, Thread.th32ThreadID);
        if ThrHandle = 0 then Exit;
        SuspendThread(ThrHandle);
        CloseHandle(ThrHandle);
        end;
     until not Thread32Next(Snap, Thread);
     CloseHandle(Snap);
     Result := true;
     end;
end;

function RunProcess(ProcessId: dword): boolean;
var
 Snap: dword;
 CurrTh: dword;
 ThrHandle: dword;
 Thread:TThreadEntry32;
begin
  Result := false;
  CurrTh := GetCurrentThreadId;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if Snap <> INVALID_HANDLE_VALUE then
     begin
     Thread.dwSize := SizeOf(TThreadEntry32);
     if Thread32First(Snap, Thread) then
     repeat
     if (Thread.th32ThreadID <> CurrTh) and (Thread.th32OwnerProcessID = ProcessId) then
        begin
        ThrHandle := OpenThread(THREAD_SUSPEND_RESUME, false, Thread.th32ThreadID);
        if ThrHandle = 0 then Exit;
        ResumeThread(ThrHandle);
        CloseHandle(ThrHandle);
        end;
     until not Thread32Next(Snap, Thread);
     CloseHandle(Snap);
     Result := true;
     end;
end;

function SearchProcessThread(ProcessId: dword): dword;
var
 Snap: dword;
 Thread:TThreadEntry32;
begin
  Result := 0;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if Snap <> INVALID_HANDLE_VALUE then
     begin
     Thread.dwSize := SizeOf(TThreadEntry32);
     if Thread32First(Snap, Thread) then
     repeat
     if Thread.th32OwnerProcessID = ProcessId then
        begin
         Result := Thread.th32ThreadID;
         CloseHandle(Snap);
         Exit;
        end;
     until not Thread32Next(Snap, Thread);
     CloseHandle(Snap);
     end;
end;

function StopThreads(): boolean;
begin
  Result := StopProcess(GetCurrentProcessId());
end;

function RunThreads(): boolean;
begin
  Result := RunProcess(GetCurrentProcessId());
end;


function ScanImportDirectory(Image: Pointer; ModuleName: PAnsiChar; ProcName: PAnsiChar): PCardinal;
var
  Base: Cardinal;
//  BadPointer: Boolean;
  PEHeader: PImageNtHeaders;

  DirBaseRVA, DirSize: Cardinal;
  IATDirBaseRVA, IATDirSize: Cardinal;
  SectionsNumber: Cardinal;
  SectionHeader: PImageSectionHeader;

  PID: PImageImportDescriptor;

  Thunk: PCardinal;

  i, Index: Integer;

  ImportRec: PImageImportByName;
begin
  Result := nil;
  Base := Cardinal(Image);
  PEHeader := PImageNtHeaders(Integer(Image)+PImageDosHeader(Base)^._lfanew);
  if PEHeader = nil then Exit;
  if PEHeader^.Signature <> IMAGE_NT_SIGNATURE then Exit;

  DirBaseRVA    := PEHeader^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress;
  DirSize       := PEHeader^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].Size;
  IATDirBaseRVA := PEHeader^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IAT].VirtualAddress;
  IATDirSize    := PEHeader^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IAT].Size;

  if (DirBaseRVA = 0) or (DirSize = 0) or (IATDirBaseRVA = 0) or (IATDirSize = 0) then Exit;

  SectionsNumber := PEHeader^.FileHeader.NumberOfSections;
  SectionHeader  := PImageSectionHeader(Cardinal(PEHeader)+24{field offset of optional headers}+PEHeader^.FileHeader.SizeOfOptionalHeader);

  Index := -1;
  for i := 0 to SectionsNumber - 1 do
    begin
      if IsBadReadPtr(SectionHeader, sizeof(TImageSectionHeader)) then
        Break;
      if (DirBaseRVA >= SectionHeader^.VirtualAddress) and (DirBaseRVA < SectionHeader^.VirtualAddress+SectionHeader^.SizeOfRawData) then
        begin
          Index := i;
          Break;
        end;
//      Inc(SectionHeader, sizeof(TImageSectionHeader));
      Inc(SectionHeader);
    end;
  if (Index > -1) and (Index < SectionsNumber) then
    begin
//      BadPointer := false;
      PID := PImageImportDescriptor(DirBaseRVA + Base);
      repeat
        if IsBadReadPtr(PID, sizeof(TImageImportDescriptor)) then
          Break;
        if PID^.OriginalFirstThunk = 0 then
          Break;
        if IsBadReadPtr(Pointer(Base+PID^.Name), strlen(ModuleName)+1) then
          Break;

        if AnsiStrIComp(PAnsiChar(Base + PID^.Name), ModuleName) = 0 then
          begin
            i := 0;
            Thunk := PCardinal(Base + PID^.OriginalFirstThunk);
            while (Thunk <> nil) and not IsBadReadPtr(Thunk, sizeof(Cardinal)) do
              begin
                if Thunk^ and IMAGE_ORDINAL_FLAG32 = 0 then // was IMAGE_ORDINAL_FLAG (without the 32)
                  begin
                    ImportRec := PImageImportByName(Base + Thunk^);
                    if IsBadReadPtr(ImportRec, sizeof(TImageImportByName)) then
                      Break;
                    if AnsiStrIComp(@ImportRec^.Name, ProcName) = 0 then
                      begin
                        Thunk := PCardinal(Base+PID^.FirstThunk+Cardinal(i*sizeof(Cardinal)));
                        if (Cardinal(Thunk) >= Base + IATDirBaseRVA) and (Cardinal(Thunk) < Base + IATDirBaseRVA + IATDirSize) then
                          Result := Thunk;
                        Break;
                      end;
                  end;
                Inc(i);
                Inc(Thunk);
              end;
          end;
        Inc(PID);
      until Result <> nil;
    end;
end;

function PatchIAT(Module: HMODULE; LibraryName, ProcName: PAnsiChar; HookProc: Pointer; var SaveProc: Pointer): Boolean;
var
  ModInfo: TModuleInfo;    // this is a problem
  Stub: PCardinal;
  OldProtect: Cardinal;
begin
  Result := false;
  Stub := nil;
  if GetModuleInformation(GetCurrentProcess, Module, @ModInfo, sizeof(ModInfo)) then
    Stub := ScanImportDirectory(ModInfo.lpBaseOfDll, LibraryName, ProcName);

  if Stub <> nil then
    begin
//      StopThreads;
      if @SaveProc <> nil then
        SaveProc := Pointer(Stub^);
      VirtualProtect(Stub, sizeof(Pointer), PAGE_WRITECOPY, OldProtect);
      Stub^ := Cardinal(HookProc);
      VirtualProtect(Stub, sizeof(Pointer), OldProtect, OldProtect);
//      RunThreads;
      Result := true;
    end;
end;

end.
