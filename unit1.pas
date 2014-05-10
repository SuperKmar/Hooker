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
    ListBox1: TListBox;
    ListBox2: TListBox;
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
begin
  //here, we take a look at pipe handeling - we are the pipe server i think.

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

  //pipe created


  while (not terminated) do
  begin
    if ConnectNamedPipe(Pipe, nil) then
    begin //we have connected to a pipe
      //do something here
    end;


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
  ThreadID:longword;
begin
  // if something is selected, splice the .dll file
  if listbox1.ItemIndex >=0 then
  begin
    i:= listbox1.ItemIndex; //index of the proc

    //do something here

    listbox2.Clear;
    Listbox2.Items.Add('Name: '+ProcArray[i].szExeFile);
    Listbox2.Items.Add('ProcessID:' +inttostr(ProcArray[i].th32ProcessID));


    ProcessHandle:= OpenProcess(PROCESS_VM_READ or PROCESS_VM_WRITE, true, ProcArray[i].th32ProcessID);
    //do something with the handle... find dll place and go on from there
    // полагаю, что ковырять будем kernel32.dll

    pfnThreadRTN := GetProcAddress(GetModuleHandle('Kernel32'), 'loadLibraryW');

    RemoteThreadHandle := CreateRemoteThread( ProcessHandle, nil, 0, pfnThreadRTN, 'C \\MyLib.dll', 0, ThreadID);


    CloseHandle(ProcessHandle); //move this to a more appropriate spot
  end;

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  //init the form, like creating the pipe and such

  MyPipe := TMyPipeThread.Create(false);
  MyPipe.FreeOnTerminate:= true;
end;

end.

