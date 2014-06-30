library InjectMeBaby;

{$mode objfpc}{$H+}

uses
  windows, sysutils, IATHOOK
  //classes are big... copy  parts that you need later
  //one word to rule them all... just figure out what the hell i did with this thing and you'll get the idea
  { you can add units after this };


function ThreadProc(lParam: Integer): Integer; stdcall;
var
  MutexHandle: THandle;

 function MsgSize(Message:String):integer;
 begin
     Result := Length(Message)*SizeOf(Char) + 1;
 end;

begin
  // here we... what do we even do here?
  //procaddress:= GetProcessID;
  InitializeCriticalSection(DangerAllAroundUs);
  pipename:= '\\.\PIPE\spypipe';
  PipeHandle := CreateFile( '\\.\PIPE\spypipe',
                            GENERIC_WRITE, //GENERIC_READ or
                            FILE_SHARE_WRITE, //FILE_SHARE_READ or
                            nil,
                            OPEN_EXISTING,
                            0,
                            0); //}
  try
    placeholder;
  except
    on E: Exception do
      MessageBox(0, PAnsiChar(AnsiString(E.Message)), 'error', 0);
  end; //}

  setmsg('Hooking complete');

  MutexHandle:=CreateMutex(nil,true,'Kmar');

  while WaitForSingleObject(MutexHandle, 25) > 0 do //(WAIT_TIMEOUT or WAIT_FAILED)
  begin //non 0 seems to work well enough
    sleep(25);
  end;

  RestoreHooks();
  ReleaseMutex(MutexHandle);
  closehandle(PipeHandle);
  DeleteCriticalSection(DangerAllAroundUs);
  freelibraryandexitthread(hinstance, 0);
end;

var
  Th: THandle;
  ThID: DWORD;
begin
  Th := CreateThread(nil, 0, @ThreadProc, nil, 0, THID);
  CloseHandle(Th);
end.




