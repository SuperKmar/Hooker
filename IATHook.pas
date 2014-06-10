unit IATHook;

interface

uses
  Windows, PSAPI, SysUtils; //PSAPI, was used here, can't find anymore :(

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
begin
//  TTHREADENTRY32.th32OwnerProcessID := getProcessID();


  //stop proc - there's an app for that
  StopThreads();
  ////StopProcess( TTHREADENTRY32.th32OwnerProcessID );   //assume thix will fix itself when psapi gets fixed

  /////////////////////////////////////////////////////////////////////////////////////////////////////////////
  ////start hooking - what we need is...
  /////////////////////////////////////////////////////////////////////////////////////////////////////////////

  //function PatchIAT(Module: HMODULE; LibraryName, ProcName: PAnsiChar; HookProc: Pointer; var SaveProc: Pointer): Boolean;
  Module := 0; // what module? what to write here?
  PatchIAT(Module, 'Kernel32', 'FileWrite', @My_FileWrite, SaveProcWrite);
  PatchIAT(Module, 'Kernel32', 'FileRead' , @My_FileRead , SaveProcRead ); //i have no idea if this will jsut work -_- fingers crossed


  /////////////////////////////////////////////////////////////////////////////////////////////////////
  //set transfer method (i guess by pipe? virtual mem should work as well...)
  /////////////////////////////////////////////////////////////////////////////////////////////////////
  //i'll do it after message box shows something





  //resume proc - there's an app for that
  //RunProcess( TTHREADENTRY32.th32OwnerProcessID );
  RunThreads();
end;

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
      if (DirBaseRVA >= SectionHeader.VirtualAddress) and (DirBaseRVA < SectionHeader.VirtualAddress+SectionHeader.SizeOfRawData) then
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
        if PID.OriginalFirstThunk = 0 then
          Break;
        if IsBadReadPtr(Pointer(Base+PID^.Name), strlen(ModuleName)+1) then
          Break;

        if AnsiStrIComp(PAnsiChar(Base + PID^.Name), ModuleName) = 0 then
          begin
            i := 0;
            Thunk := PCardinal(Base + PID^.OriginalFirstThunk);
            while (Thunk <> nil) and not IsBadReadPtr(Thunk, sizeof(Cardinal)) do
              begin
                if Thunk^ and IMAGE_ORDINAL_FLAG = 0 then
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
  ModInfo: TModuleInfo;
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
