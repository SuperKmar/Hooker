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
    Label1: TLabel;
    ListBox1: TListBox;
    ListBox2: TListBox;
    ListBox3: TListBox;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
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
type
  LLF = function(Name: PWideChar): HMODULE; stdcall;
var
  i:integer;

  Pipe: THandle;
  Security: Security_Attributes;
  WriteMemRes:boolean;
  ModuleHandle:THandle;
  TempOffset: dword;
  InjInfo: TInjectStruct;
  Kernel32: HMODULE;

  inputBuffer: array [0..1024] of Char;
  buffsize: integer;
  tempstring:string;
  BytesRead: longword;
  res:boolean;
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

//    LLF(pfnThreadRTN)('IHook.dll');

    //the string must be a var, sent thriugh virtual memory  //this fails
    VMemAddr:=VirtualAllocEx( ProcessHandle,   //no way this is wrong
                              nil,   //don't think this is wrong
                              4096, //might be off by 1 or 2, but should still show something at this point
                              MEM_COMMIT or MEM_RESERVE, //no way this is wrong
                              PAGE_EXECUTE_READWRITE); //_EXCECUTE_READWRITE //_READWRITE  //no way this is wrong
   {
    with InjInfo do
      begin
        Pointer(iLoadLibrary)         := GetProcAddress(Kernel32, 'LoadLibraryW');
        Pointer(iGetProcAddress)      := GetProcAddress(Kernel32, 'GetProcAddress');

        lstrcpyW(kernel32name,    'kernel32.dll');
        lstrcpyA(ExitThread_Name, 'ExitThread');
        lstrcpyA(GetModuleHandle_Name, 'GetModuleHandleW');
        lstrcpyW(InjLibraryPath, PWideChar(ExtractFilePath(Application.ExeName)+'ihook.dll'));
      end;    }

    output.Items.add('virtual memory allocated at:'+ inttostr(integer(VMemAddr)));


    WriteMemRes := WriteProcessMemory( ProcessHandle,
                        VMemAddr,
                        PWideChar(WideString(InjectLib)) ,
                        TempSize,
                        BytesWritten ); //nil needs to become a longword   //this fails
//    WriteProcessMemory(EQProc, InjBlock, @InjInfo, sizeof(InjInfo), Written);


    output.Items.add('Written into virtual memory:'+ booltostr(WriteMemRes)+' - ' + inttostr(BytesWritten) +' bytes');


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


  Pipe := CreateNamedPipe('\\.\PIPE\spypipe',
                         PIPE_ACCESS_INBOUND,
                         PIPE_TYPE_BYTE or      //PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or
                         PIPE_NOWAIT,
                         1,
                         1024,
                         1024,
                         0,
                         nil); //bullshit - recheck the paramaters... maybe we'll do filemapping instead of this crap

  output.Items.add('got Pipe:'+ inttostr(Pipe));

  //pipe created


  while (not terminated) {and ConnectNamedPipe(Pipe, nil)} do
  begin

    //output.Items.add('thread is working');

    //if ConnectNamedPipe(Pipe, nil) then
    //begin //we have connected to a pipe
    //  //do something here
    //
    //  for i:= 0 to 512 do
    //    inputBuffer[i] := #0;
    //
    //  res:= ReadFile( Pipe,
    //                  inputBuffer,
    //                  512,
    //                  BytesRead,
    //                  nil);
    //
    //
    //  //If res then
    //  //begin
    //  //  tempstring:=string(inputBuffer);
    //  //  output.Items.add('incoming: '+tempstring);
    //  //  tempstring:='';
    //  //end else
    //  //begin
    //  //  output.Items.add('not incoming: ');
    //  //end;
    //
    //
    //end else
    //begin
    //  //output.Items.add('Can"t conect');
    //end;
    //the things we do without the pipe... is there anything here?
    ConnectNamedPipe(Pipe, nil);
    If GetLastError = ERROR_PIPE_CONNECTED then
    begin
        res:= ReadFile( Pipe,
                        buffsize,
                        SizeOf(integer),
                        BytesRead,
                        nil);

        output.Items.Add('incoming '+inttostr(buffsize) + ' Bytes');

      res := ReadFile( Pipe,
                       inputbuffer,
                       buffsize,
                       BytesRead,
                       nil);

      output.Items.Add('got msg: ' + string(inputbuffer));
    end;


  end; // end of while not traminated and connected

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

    listbox2.Clear;
    Listbox2.Items.Add('Name: '+ProcArray[i].szExeFile);
    Listbox2.Items.Add('ProcessID:' +inttostr(ProcArray[i].th32ProcessID));
    ListBox3.Clear;

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

procedure TForm1.FormCreate(Sender: TObject);
begin
  //init the form, like creating the pipe and such
  //SetWindowsHookEx(
  //MyPipe := TMyPipeThread.Create(false);
  //MyPipe.FreeOnTerminate:= true;
end;

end.

