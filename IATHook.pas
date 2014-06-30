unit IATHook;

interface

uses
  Windows, {JwaTlHelp32, }SysUtils, psapi, dirtyhook; //PSAPI, was used here, can't find anymore :(

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

 TModuleInfo = record
   lpBaseOfDLL: pointer;
   SizeOfImage: DWord;
   EntryPoint: Pointer;
 end;



var
//  message:String;
  dodirtyhook: boolean;
  MessageHasChanged: longint;
  Restore_WriteFile, Restore_ReadFile: pointer;
  terminated:boolean = false;
  DangerAllAroundUs: TCRITICALSECTION;

  pipehandle: THandle;
  pipename:string;


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

function restoreHooks():boolean;


//Function FileWrite (Handle : THandle; const Buffer; Count : Longint) : Longint;
function my_FileWrite(AFile: THandle; Buffer: Pointer; BytesToWrite: Cardinal; var BytesWritten: Cardinal; Overlapped: POverlapped): LongBool; stdcall;
//Function FileRead (Handle : THandle; out Buffer; Count : longint) : Longint;
function my_FileRead (AFile: THandle; Buffer: Pointer; BytesToRead: Cardinal; var BytesRead: Cardinal; Overlapped: POverlapped): LongBool; stdcall;

procedure setmsg(msg:string);

type
  TWriteFileProc= function(AFile: THandle; Buffer: Pointer; BytesToWrite: Cardinal; var BytesWritten: Cardinal; Overlapped: POverlapped): LongBool; stdcall;
  TReadFileProc = function(AFile: THandle; Buffer: Pointer; BytesToRead:  Cardinal; var BytesRead:    Cardinal; Overlapped: POverlapped): LongBool; stdcall;

implementation /////////////////////////////////////////////////////////////////

function MsgSize(Message:String):integer;
begin
    Result := Length(Message)*SizeOf(Char) + 1;
end;

procedure setmsg(msg:string);
var
  message:string;
  Len :integer;
  BytesWritten: longword;
  res:boolean;
begin
 // exit;

  EnterCriticalSection(DangerAllAroundUs);

  message := msg;

  //messagebox(0, PChar(msg), 'sending', 0);

    Len :=MsgSize(Message);

    if Restore_WriteFile = nil then
    begin
    res := WriteFile( PipeHandle,
                      Len,
                      SizeOf(len),
                      BytesWritten,
                      nil); //}


    res := WriteFile( PipeHandle,
                      PChar(Message)^,
                      Len,
                      BytesWritten,
                      nil); //}

    end else
    begin
      res := TWriteFileProc(Restore_WriteFile)( PipeHandle,
                                                @Len,
                                                SizeOf(len),
                                                BytesWritten,
                                                nil); //}

      res := TWriteFileProc(Restore_WriteFile)( PipeHandle,
                                                PChar(Message),
                                                Len,
                                                BytesWritten,
                                                nil); //}

    end;
  //figure out how to not spam the shit out of the system... not that it's resisting though
  ///sleep(10);
  LeaveCriticalSection(DangerAllAroundUs);
end;



function my_FileWrite(AFile : THandle; Buffer: Pointer;  BytesToWrite: Cardinal; var BytesWritten: Cardinal; Overlapped: POverlapped): LongBool; stdcall;
begin

  if Restore_WriteFile=nil then
  begin
    result := WriteFile(AFile, Buffer,  BytesToWrite, BytesWritten, Overlapped );
  end else
  begin
    TWriteFileProc(Restore_WriteFile)(AFile, Buffer, BytesToWrite, BytesWritten, Overlapped);
  end;

  setmsg('FileWrite ('+ inttohex(AFile,8)+', '+ inttohex(integer(buffer),8)+', '+ inttostr(BytesToWrite)+', '+ inttostr(BytesWritten)+', '+ inttohex(Cardinal(Overlapped) ,8)+')');
  //messagebox(0,'write','',0);
  //setmsg('FileWrite');
end;

function my_FileRead (AFile: THandle; Buffer: Pointer; BytesToRead: Cardinal; var BytesRead: Cardinal; Overlapped: POverlapped): LongBool; stdcall;
begin

  if Restore_ReadFile = nil then
  begin
    result := ReadFile(AFile, Buffer, BytesToRead, BytesRead, Overlapped);
  end else
  begin
    try
    result := TReadFileProc(Restore_ReadFile)(AFile, Buffer, BytesToRead, BytesRead, Overlapped);
    Except
      on E: Exception do
        MessageBox(0, PAnsiChar(AnsiString(E.Message)), 'error', 0);
    end;
  end;
  setmsg('FileRead (' + inttohex(AFile,8)+', '+ inttohex(integer(buffer),8)+', '+ inttostr(BytesToRead)+', '+ inttostr(BytesRead)+', '+ inttohex(Cardinal(Overlapped),8)+ ')');

  //messagebox(0, 'File is being read!', 'Some program is doing something', 0);
end;


function placeholder():boolean;
var
  SaveProcWrite, SaveProcRead: PCardinal;
  Module:HMODULE;
  KernelMod: HMODULE;
  FuncPtr: Pointer;

begin
  result:=true;
  //stop proc - there's an app for that
  result:= StopThreads();
  if not result then exit;
  try
    try
  /////////////////////////////////////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////START HOOKING///////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////////////////////////////////////

      Module := GetModuleHandle(nil);
      KernelMod := GetModuleHandle('Kernel32.dll');

      //function PatchIAT(Module: HMODULE; LibraryName, ProcName: PAnsiChar; HookProc: Pointer; var SaveProc: Pointer): Boolean;
      result := PatchIAT(Module, PAnsiChar('kernel32.dll'), PAnsiChar('WriteFile'), @My_FileWrite, SaveProcWrite);

      if not result then
      begin
        setmsg('Patch IAT has failed at WriteFile - attempting DirtyHook');
      end else setmsg('PatchIAT succesful at WriteFile');

      if (not result) and (dodirtyhook) then
        begin
          FuncPtr := GetProcAddress(KernelMod, 'WriteFile');
          result := HookCode(FuncPtr, @My_FileWrite, Restore_WriteFile);
        end;
      if not result then
      begin
        setmsg('DirtyHook Has Failed at writefile');
      end else setmsg('Dirty Hook succesful at WriteFile');
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////
      result := PatchIAT(Module, 'kernel32.dll', 'ReadFile' , @My_FileRead , SaveProcRead ); //i have no idea if this will just work -_- fingers crossed
      if not result then
      begin
        setmsg('PatchIAT has failed at ReadFile - atempting DirtyHook');
      end else setmsg('PatchIAT succesful at ReadFile');

      if (not result) and (dodirtyhook) then
      begin
        FuncPtr := GetProcAddress(KernelMod, 'ReadFile');
        result := HookCode(FuncPtr, @My_FileRead, Restore_ReadFile);
      end;
      if not result then
      begin
        setmsg('DirtyHook Has Failed at ReadFile');
      end else setmsg('DirtyHook successful at ReadFile');


  /////////////////////////////////////////////////////////////////////////////////////////////////////
  ///////////set transfer method (i guess by pipe? virtual mem should work as well...)/////////////////
  /////////////////////////////////////////////////////////////////////////////////////////////////////
    finally
      RunThreads();
    end;
  except
    messagebox(0, 'try-except case', ',' , 0);
  end;
end;

function restoreHooks():boolean;
begin
  result:=true;


  If Restore_WriteFile <> nil then
    UnHookCode(Restore_WriteFile);

  if Restore_ReadFile <> nil then;
    UnhookCode(Restore_ReadFile);

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

  if (DirBaseRVA = 0) or (DirSize = 0) or (IATDirBaseRVA = 0) or (IATDirSize = 0) then
  begin
    dodirtyhook := true;
    Exit;
  end;

  SectionsNumber := PEHeader^.FileHeader.NumberOfSections;
  SectionHeader  := PImageSectionHeader(Cardinal(PEHeader)+24{field offset of optional headers}+PEHeader^.FileHeader.SizeOfOptionalHeader);

  Index := -1;
  for i := 0 to SectionsNumber - 1 do
    begin
      if IsBadReadPtr(SectionHeader, sizeof(TImageSectionHeader)) then
      begin
        Break;
      end;
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
        begin
          Break;
        end;
        if PID^.OriginalFirstThunk = 0 then
        begin
          Break;
        end;
        if IsBadReadPtr(Pointer(Base+PID^.Name), strlen(ModuleName)+1) then
        begin
          Break;
        end;

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
  ModInfo: TModuleInfo;
  Stub: PCardinal;
  OldProtect: Cardinal;
begin
  Result := false;
  Stub := nil;
  dodirtyhook:=false;

  if GetModuleInformation(GetCurrentProcess, Module, @ModInfo, sizeof(ModInfo)) then
  begin
    Stub := ScanImportDirectory(ModInfo.lpBaseOfDll, LibraryName, ProcName);
  end;

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
