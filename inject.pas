
type
  TInjectStruct = packed record
    iLoadLibrary    : function (lpLibFileName: PWideChar): HMODULE; stdcall;
    iGetProcAddress : function (hModule: HMODULE; lpProcName: PAnsiChar): FARPROC; stdcall;
    iGetModuleHandle: function (lpModuleName: PWideChar): HMODULE; stdcall;
    kernel32name    : array[0..15] of WideChar;
    ExitThread_Name : array[0..31] of AnsiChar;
    GetModuleHandle_Name: array[0..31] of AnsiChar;
    InjLibraryPath  : array[0..MAX_PATH] of WideChar;
  end;


function InjectProc(ThreadArg: Pointer): DWORD; stdcall;
var
  Kernel32: HMODULE;
  iExitThread: procedure(uExitCode: UINT); stdcall;
begin
  with TInjectStruct(ThreadArg^) do
    begin
      Kernel32 := iLoadLibrary(Kernel32name);
      @iGetModuleHandle     := iGetProcAddress(Kernel32, GetModuleHandle_Name);
      @iExitThread          := iGetProcAddress(Kernel32, ExitThread_Name);
      if iGetModuleHandle(InjLibraryPath) = 0 then
        iLoadLibrary(InjLibraryPath);
    end;
  Result := 0;
  iExitThread(0);
end;



function TRemoteInterface.DoInject(InjectProc: Pointer; InjectSize: Cardinal): Boolean;
var
  EQProc: THandle;
  InjBlock: Pointer;
  Written: Cardinal;
  InjThread: THandle;
  InjThreadID: Cardinal;
  InjInfo: TInjectStruct;
  Kernel32: HMODULE;
  Res: Boolean;
begin
  Result := false;
  if IsActive then
    Exit;

{  EQWnd := FindWindow('EQ2ApplicationClass', nil);
  if EQWnd = 0 then
    Exit;
  GetWindowThreadProcessID(EQWnd, EQProcID);}


  EQProc := OpenProcess(PROCESS_ALL_ACCESS, false, FGameData.EQProcID);
  if EQProc = INVALID_HANDLE_VALUE then
    Exit;
  InjBlock := VirtualAllocEx(EQProc, nil, 4096, MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  if InjBlock = nil then
    Exit;
  Kernel32 := GetModuleHandle('kernel32.dll');
  with InjInfo do
    begin
      iLoadLibrary         := GetProcAddress(Kernel32, 'LoadLibraryW');
      iGetProcAddress      := GetProcAddress(Kernel32, 'GetProcAddress');

      lstrcpyW(kernel32name,    'kernel32.dll');
      lstrcpyA(ExitThread_Name, 'ExitThread');
      lstrcpyA(GetModuleHandle_Name, 'GetModuleHandleW');
      lstrcpyW(InjLibraryPath, PWideChar(ExtractFilePath(Application.ExeName)+'eqhook.dll'));
    end;
  Res := WriteProcessMemory(EQProc, InjBlock, @InjInfo, sizeof(InjInfo), Written);
  Res := Res and (Written = sizeof(InjInfo));

  if Res then
    begin
      Res := WriteProcessMemory(EQProc, Pointer(Cardinal(InjBlock)+2048), InjectProc, InjectSize, Written);
      Res := Res and (Written = InjectSize);
      if Res then
        begin
          InjThread := CreateRemoteThread(EQProc, nil, 0, Pointer(Cardinal(InjBlock)+2048), InjBlock, 0, InjThreadID);
          if InjThread <> 0 then
            begin
              Result := true;
              WaitForSingleObject(InjThread, INFINITE);
              CloseHandle(InjThread);
            end;
        end;
    end;
  VirtualFreeEx(EQProc, InjBlock, 0, MEM_RELEASE);
end;
