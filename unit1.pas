unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls, JwaTlHelp32,windows;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Label1: TLabel;
    ListBox1: TListBox;
    ListBox2: TListBox;
    ListBox3: TListBox;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
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


procedure TMyPipeThread.execute;
var
  Pipe: THandle;
  Security: Security_Attributes;
  WriteMemRes:boolean;
  ModuleHandle:THandle;
begin
  //here, we take a look at pipe handeling - we are the pipe server i think.

  //inject the lib



    ProcessHandle:= OpenProcess(PROCESS_VM_READ or PROCESS_VM_WRITE, true, RemoteProcID); //this works?
    output.Items.add('Proc Handle:'+ inttostr(ProcessHandle));
    //do something with the handle... find dll place and go on from there
    // полагаю, что ковырять будем kernel32.dll

    TempSize := Length(InjectLib);
    TempSize:= TempSize*SizeOf(WChar);


    ModuleHandle := GetModuleHandle('Kernel32'); //this works
    output.Items.add('kernel32 handle:'+ inttostr(ModuleHandle));

    pfnThreadRTN := GetProcAddress(ModuleHandle, 'LoadLibraryW'); //can't get proc addr   //this must be sent via allocated memory? //Fixed - it works now
    output.Items.add('got Proc address:'+ inttostr(integer(pfnThreadRTN)));


    //the string must be a var, sent thriugh virtual memory
    VMemAddr:=VirtualAllocEx( ProcessHandle,
                              nil,
                              TempSize,
                              MEM_COMMIT,  //or MEM_RESERVE
                              PAGE_READWRITE); //_EXCECUTE_READWRITE      //this fails

    output.Items.add('virtual memory allocated at:'+ inttostr(integer(VMemAddr)));
    //MessageBox(handle, 'got mem', 'yo', 0);


//    BytesWritten:= NULL;

    WriteMemRes := WriteProcessMemory( ProcessHandle,
                        VMemAddr,
                        @InjectLib ,
                        TempSize,
                        BytesWritten ); //nil needs to become a longword   //this fails


    output.Items.add('Written into virtual memory:'+ booltostr(WriteMemRes)+' - ' + inttostr(BytesWritten) +' bytes');



    RemoteThreadHandle := CreateRemoteThread( ProcessHandle,
                                              nil,
                                              0,
                                              pfnThreadRTN,
                                              @ProcessHandle,
                                              0,
                                              BytesWritten); //nil needs to become a longword

    output.Items.add('got remote thread handle:'+ inttostr(RemoteThreadHandle));


    WaitForSingleObject(RemoteThreadHandle, 9001*100500); //2 mins is almost forever - wonder if this is needed
    //
    //reciving period? something should happen now, right?
    //


    VirtualFreeEx(ProcessHandle, VMemAddr, 0, MEM_RELEASE);

    CloseHandle(RemoteThreadHandle);

    CloseHandle(ProcessHandle); //move this to a more appropriate spot - no way we are done in one go... all of this should be in the pipe thread -_-



   //
   // NOW PIPE TIME
   //


  Pipe := CreateNamedPipe('\\.\pipe\spypipe',
                         PIPE_ACCESS_INBOUND,
                         PIPE_TYPE_MESSAGE or
                         PIPE_READMODE_MESSAGE or
                         PIPE_NOWAIT,
                         10,
                         9001,
                         9001,
                         0,
                         nil);

    output.Items.add('got Pipe:'+ inttostr(Pipe));

  //pipe created


  while (not terminated) do
  begin
    if ConnectNamedPipe(Pipe, nil) then
    begin //we have connected to a pipe
      //do something here

    end;

    //the things we do without the pipe... is there anything here?

  end;

  //pipe destroyed
  CloseHandle(Pipe);

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
  i:integer;

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
  pfnThreadRtn: PTHREAD_START_ROUTINE;
  RemoteThreadID: longword; //was longword
  VMemAddr: pointer;
  InjectLib:String;
  TempSize:dword;
  SomeNullString:PAnsiString;
  BytesWritten: dword;
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

    InjectLib:=GetCurrentDir+'\Inject.dll';

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

procedure TForm1.FormCreate(Sender: TObject);
begin
  //init the form, like creating the pipe and such

  //MyPipe := TMyPipeThread.Create(false);
  //MyPipe.FreeOnTerminate:= true;
end;

end.

