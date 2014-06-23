library InjectMeBaby;

{$mode objfpc}{$H+}

uses
  windows, sysutils, IATHOOK
  //classes are big... copy  parts that you need later
  //one word to rule them all... just figure out what the hell i did with this thing and you'll get the idea
  { you can add units after this };




function CallPipe(name: string; msg: string; ntimeout: DWORD): string;
const
  BUFSIZE = 1024;
var
  pipeHandle: THandle;
  ntowrite, nwritten: DWORD;
  ntoread, nread: DWORD;
  rc: boolean;
  buffer: PChar;
begin
  if not WaitNamedPipe(PChar(name), ntimeout) then
  begin
    Result := '*No pipe';
    Exit;
  end;
  pipeHandle := CreateFile( PChar(name),
                            GENERIC_READ or GENERIC_WRITE,
                            FILE_SHARE_READ,
                            nil,
                            OPEN_EXISTING,
                            FILE_ATTRIBUTE_NORMAL,
                            0);

  if pipeHandle = INVALID_HANDLE_VALUE then
    Result := '*Open error'
  else
  begin
    GetMem(buffer, BUFSIZE);
    try
      ntowrite := length(msg);
      Move(msg[1], buffer^, ntowrite);
      rc := WriteFile(pipeHandle, buffer^, ntowrite, nwritten, nil);
      if (not rc) or (ntowrite <> nwritten) then
        Result := '*Write error'
      else
      begin
        ntoread := BUFSIZE;
        ReadFile(pipeHandle, buffer^, ntoread, nread, nil);
        SetLength(Result, nread);
        Move(buffer^, Result[1], nread);
      end;
    finally
      FreeMem(buffer);
    end;
    CloseHandle(pipeHandle);
  end;
end;



function ThreadProc(lParam: Integer): Integer; stdcall;
const
  buffsize = 1024;
var
  pipename:string;
  pipehandle:THandle;
  message:string;
  Len :integer;
  BytesWritten: longword;
  res:boolean;
  readbuffer: PAnsiChar;
  bytesread:longword;
begin
  // here we... what do we even do here?

  try
  placeholder;

  except
    on E: Exception do
      MessageBox(0, PAnsiChar(AnsiString(E.Message)), 'error', 0);
  end; //}

  pipename:= '\\.\PIPE\spypipe';
  //MessageBox(0, 'Starting another thread on this bad boy', 'lalalala', 0);

  PipeHandle := CreateFile( '\\.\PIPE\spypipe',
                            GENERIC_WRITE, //GENERIC_READ or
                            FILE_SHARE_WRITE, //FILE_SHARE_READ or
                            nil,
                            OPEN_EXISTING,
                            0,
                            0); //}



  //MessageBox(0, PAnsiChar('Got the pipe handle on this side: ' + inttostr(integer(PipeHandle))), 'Pipe', 0);
  //CallPipe(Pipename, message, 1000);
  Message := ( 'Hello boss! I am in the enemy program. They suspect nothing' );
  Len := Length(Message)*SizeOf(Char) + 1;

  res := WriteFile( PipeHandle,
                    Len,
                    SizeOf(len),
                    BytesWritten,
                    nil); //}

  if res then
    messageBox(0, PAnsiChar('Writing length succesful: ' + inttostr(BytesWritten)) , 'writing', 0)
  else
    messageBox(0, 'Writing length failed', 'writing', 0);

  res := WriteFile( PipeHandle,
                    PChar(Message)^,
                    Len,
                    BytesWritten,
                    nil); //}
 // res:= true;

//  while res do
//  begin
{    res:=CallNamedPipe( '\\.\PIPE\spypipe', //not sure how many "\" there are in the front
                        PChar(Message),
                        (Length(Message)+1)*sizeof(char),
                        readbuffer,
                        Buffsize*sizeof(char),
                        &bytesread,
                        20000
                        ); //}



  //if res then message:= 'write succesful' else message:= 'write failed';
  messagebox(0, PAnsiChar('Bytes written: ' + inttostr(BytesWritten)), PAnsiChar(message) , 0); //}
//  end;


  closehandle(PipeHandle);
  //while not terminated do
  //begin
  //  //listen for stuff?
  //  //set up the pipeline for a termination command;
  //end;
  freelibraryandexitthread(hinstance, 0); // this cleans up after it self
end;





var
  Th: THandle;
  ThID: DWORD;
begin
  //main proc code goes here


  //placeholder; //this stops, injects and resumes

  //create a new thread for keeping the injected stuff on a roll
  //new threads are harder then this... goto wasm :(
  //messagebox(0, 'Beggining the inside thread', 'Thread making', 0);
//  MyInjThread := InjThread.Create(true);
//  MyInjThread.FreeOnTerminate:=true;
//  MyInjThread.Resume;
  //messagebox(0, 'thread weaving done... now things die', 'Thread making', 0);

  Th := CreateThread(nil, 0, @ThreadProc, nil, 0, THID);
  CloseHandle(Th);
end.




