unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ActnList, JwaTlHelp32, windows;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    CheckBox1: TCheckBox;
    ListBox1: TListBox;
    ListBox3: TListBox;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation
type TMyPipeThread = class(TThread)
  //may add other vars for more simple data extraction
  public
    pfnThreadRtn: PTHREAD_START_ROUTINE;
    RemoteThreadID: longword; //was longword
    VMemAddr: pointer;
    InjectLib:String;
    TempSize:dword;
    SomeNullString:PAnsiString;
    BytesWritten: dword;
    RemoteProcID: integer;
    output: tlistbox;
    procedure execute; override;
end;

var
  ProcArray: array of TProcessEntry32;
  ProcessHandle: THandle;
  MyPipe: TMyPipeThread;
  RemoteThreadHandle: THandle;
  IsSimpleView: boolean = False;


{$R *.lfm}



{ TForm1 }

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
      Pointer(iGetModuleHandle)     := iGetProcAddress(Kernel32, GetModuleHandle_Name);
      Pointer(iExitThread)          := iGetProcAddress(Kernel32, ExitThread_Name);
      if iGetModuleHandle(InjLibraryPath) = 0 then
        iLoadLibrary(InjLibraryPath);
    end;
  Result := 0;
  iExitThread(0);
end;



procedure TMyPipeThread.execute;
var
  i:integer;

  Pipe: THandle;
  Security: Security_Attributes;
  WriteMemRes:boolean;
  ModuleHandle:THandle;
  TempOffset: dword;
  InjInfo: TInjectStruct;
  Kernel32: HMODULE;

  InputBuffer: array [0..1024] of Char;
  StringInputBuffer:string;
  buffsize: integer;
  tempstring:string;
  BytesRead: longword;
  res:boolean;
  BytesInStack: DWord;

  MutexHandle: THandle;

begin

  ProcessHandle:= OpenProcess(PROCESS_ALL_ACCESS, true, RemoteProcID); //this works?
  output.Items.add('Proc Handle:'+ inttostr(ProcessHandle));
  //do something with the handle... find dll place and go on from there
  // полагаю, что ковырять будем kernel32.dll
  TempSize := Length(InjectLib);
  TempSize:= TempSize*SizeOf(WChar);

  ModuleHandle := GetModuleHandle('kernel32.dll'); //this works
  output.Items.add('kernel32 handle:'+ inttostr(ModuleHandle));

  pfnThreadRTN := GetProcAddress(ModuleHandle, 'LoadLibraryW'); //this must be sent via allocated memory? //Fixed - it works now
  output.Items.add('got Proc address:'+ inttostr(integer(pfnThreadRTN)));


  //the string must be a var, sent thriugh virtual memory  //this fails
  VMemAddr:=VirtualAllocEx( ProcessHandle,   //no way this is wrong
                            nil,   //don't think this is wrong
                            4096, //might be off by 1 or 2, but should still show something at this point
                            MEM_COMMIT or MEM_RESERVE, //no way this is wrong
                            PAGE_EXECUTE_READWRITE); //_EXCECUTE_READWRITE //_READWRITE  //no way this is wrong

  output.Items.add('virtual memory allocated at:'+ inttostr(integer(VMemAddr)));


  WriteMemRes := WriteProcessMemory( ProcessHandle,
                                     VMemAddr,
                                     PWideChar(WideString(InjectLib)) ,
                                     TempSize,
                                     BytesWritten ); //nil needs to become a longword   //this fails



  output.Items.add('Written into virtual memory:'+ booltostr(WriteMemRes)+' - ' + inttostr(BytesWritten) +' bytes');

  Pipe := CreateNamedPipe('\\.\PIPE\spypipe',
                           PIPE_ACCESS_INBOUND,
                           PIPE_TYPE_BYTE or      //PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or
                           PIPE_NOWAIT,
                           1,
                           1024,
                           1024,
                           0,
                           nil); //bullshit - recheck the paramaters... maybe we'll do filemapping instead of this crap

  RemoteThreadHandle := CreateRemoteThread( ProcessHandle,
                                            nil,
                                            0,
                                            pfnThreadRTN,
                                            VMemAddr,
                                            0,
                                            TempOffset); //nil needs to become a longword

  output.Items.add('got remote thread handle:'+ inttostr(RemoteThreadHandle));

  WaitForSingleObject(RemoteThreadHandle, 9001*100500); //a year or so...
    //
    //reciving period? something should happen now, right? wrong! we let the DLL do it's magic
    //


  VirtualFreeEx(ProcessHandle, VMemAddr, 0, MEM_RELEASE);
  CloseHandle(RemoteThreadHandle);
  CloseHandle(ProcessHandle); //move this to a more appropriate spot - no way we are done in one go...

   //
   // NOW PIPE TIME
   //

  output.Items.add('got Pipe:'+ inttostr(Pipe));

  //pipe created

  MutexHandle := CreateMutex(nil, true, 'Kmar');

  while (not terminated) {and ConnectNamedPipe(Pipe, nil)} do
  begin

    ConnectNamedPipe(Pipe, nil);
    If GetLastError = ERROR_PIPE_CONNECTED then
    begin
        //peek pipe for 4 bytes, continue if found
      PeekNamedPipe(Pipe, nil, 0, nil, @bytesInStack ,nil);

        //while not terminated and not read do
      if BytesInStack >=4 then
      begin
        buffsize:=0;
        res:= ReadFile( Pipe,
                        buffsize,
                        SizeOf(integer),
                        BytesRead,
                        nil);

        if (buffsize <> 0) and (bytesRead = SizeOf(Integer) )then
        begin

          repeat
            PeekNamedPipe(Pipe, nil, 0, nil, @bytesInStack ,nil);
          until (buffsize = BytesInStack) or (terminated);

          //output.Items.Add('incoming '+inttostr(buffsize) + ' Bytes');

          res := ReadFile( Pipe,
                           inputbuffer,
                           buffsize,
                           BytesRead,
                           nil);


          StringInputBuffer:= string(InputBuffer);

          //output.Items.Add(string(InputBuffer)); //remove this later

          if IsSimpleView then
          begin
            if pos('Write', StringInputBuffer) > 0 then StringInputBuffer:='Program is writing something';
            if pos('Read' , StringInputBuffer) > 0 then StringInputBuffer:='Program is reading something';
          end;


          tempstring := output.Items.Strings[output.Count-1];

          if { ord(tempstring[2]) = ord('0') } (ord(tempstring[2]) < ord('9')) and IsSimpleView then
          begin //this string was here before - check if the next one is the same as well (we have a 100x buffer)
            if {copy(tempstring, 6, length(tempstring)) = StringInputBuffer} Pos(StringInputBuffer, tempstring )>0 then
            begin //they are the same - fix the counter
              tempstring := inttostr( strtoint(copy(tempstring, 2, 3)) +1 );
              while length(tempstring) < 3 do tempstring := '0'+ tempstring;
              tempstring:=tempstring + ' ';
              output.Items.Strings[output.Count - 1] := 'x'+ tempstring+ StringInputBuffer;
            end else
            begin //they are not identical after all... just add it
              output.Items.Add(StringInputBuffer);
            end;
          end else
          begin //simple check
            if tempstring = StringInputBuffer then
            begin //first reoccurence - add a 'x002 ' prefix to prev string
              output.Items.Strings[output.Count - 1] := 'x002 ' + StringInputBuffer;
            end //otherwise just add our new string
            else output.Items.Add(StringInputBuffer);
          end; //end of string magic //}

          //output.ScrollBy(1, 1); //
          //sleep(10);

        end; //end of buffsize <> 0
      end; //end of bytes in stack
    end; //end of get last error
  end; // end of while not traminated and connected

  ReleaseMutex(MutexHandle);
  //pipe destroyed
  CloseHandle(Pipe);
  output.Items.add('closing server pipe');

end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  //clean up
  MyPipe.Terminate;
end;

procedure TForm1.Button1Click(Sender: TObject);
  // we scan for all of the procedures
var
  pa: TProcessEntry32;
  RetVal: THandle;
  sList: TStringList;

 procedure AddProcItem(ProcItem: TProcessEntry32);
 begin
   slist.Add(pa.szExeFile + ' ------ ' + inttostr(pa.th32ProcessID));

   setlength(ProcArray, length(ProcArray)+1);
   ProcArray[length(ProcArray)-1]:= ProcItem;
 end;

begin
  RetVal := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);

  Setlength(ProcArray, 0);

  pa.dwSize := sizeof(pa);
  //Create string list
  sList := TStringList.Create;
  //Get first process
  if Process32First(RetVal, pa) then
    //Add process name to string list
    //sList.Add(pa.szExeFile);
    AddProcItem(pa);
  begin
    //While we have process handle
    while Process32Next(RetVal, pa) do
    begin
      //sList.Add(pa.szExeFile + ' ------ ' + inttostr(pa.th32ProcessID) );
      AddprocItem(pa);
    end;
  end;
  //Assign to listbox or what ever you want to do
  ListBox1.Items.Assign(sList);
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  i:integer;
  InjectLib:String;
begin
  // if something is selected, splice the .dll file
  if listbox1.ItemIndex >=0 then
  begin
    i:= listbox1.ItemIndex; //index of the proc

    //do something here

    Listbox3.Clear;
    Listbox3.Items.Add('Name: '+ProcArray[i].szExeFile);
    Listbox3.Items.Add('ProcessID:' +inttostr(ProcArray[i].th32ProcessID));
    //ListBox3.Clear;

    InjectLib:=GetCurrentDir+'\InjectMeBaby.dll'; // - let's hope that we only need the name for this to work

    MyPipe := TMyPipeThread.create(true);
    MyPipe.InjectLib:=InjectLib;
    MyPipe.RemoteProcID:= ProcArray[i].th32ProcessID;
    Listbox3.Items.Add('Our library assult team: ');
    Listbox3.Items.Add(InjectLib);

    MyPipe.output:= listbox3;
    MyPipe.Resume;

    //summon the thread!
  end;

end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  //kill active threads
  MyPipe.Terminate;
  Listbox3.Items.Add('Listener thread has been killed... murderer -_-' );
end;

procedure TForm1.CheckBox1Change(Sender: TObject);
begin
  IsSimpleView := CheckBox1.Checked;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
end;

end.

