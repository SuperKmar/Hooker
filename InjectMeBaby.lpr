library InjectMeBaby;

{$mode objfpc}{$H+}

uses
  windows, sysutils, IATHOOK
  //classes are big... copy  parts that you need later
  //one word to rule them all... just figure out what the hell i did with this thing and you'll get the idea
  { you can add units after this };

  /////////////////////////////////////////////////////////////////////////////
  //TNotifyEvent = procedure(Sender: TObject) of object;
  //THelpEvent = function (Command: Word; Data: Longint;
  //  var CallHelp: Boolean): Boolean of object;
  //TGetStrProc = procedure(const S: string) of object;
  //
  //{ TThread } ///////////////////////becasue i'm too lazy to use my brain//////
  //
  //  EThread = class(Exception);
  //  EThreadDestroyCalled = class(EThread);
  //  TSynchronizeProcVar = procedure;
  //  TThreadMethod = procedure of object;
  //
  //  TThreadPriority = (tpIdle, tpLowest, tpLower, tpNormal, tpHigher, tpHighest,
  //    tpTimeCritical);
  //
  //  TThread = class
  //  private
  //    FHandle: TThreadID;
  //    FTerminated: Boolean;
  //    FFreeOnTerminate: Boolean;
  //    FFinished: Boolean;
  //    FSuspended: LongBool;
  //    FReturnValue: Integer;
  //    FOnTerminate: TNotifyEvent;
  //    FFatalException: TObject;
  //    procedure CallOnTerminate;
  //    function GetPriority: TThreadPriority;
  //    procedure SetPriority(Value: TThreadPriority);
  //    procedure SetSuspended(Value: Boolean);
  //    function GetSuspended: Boolean;
  //  protected
  //    FThreadID: TThreadID; // someone might need it for pthread_* calls
  //    procedure DoTerminate; virtual;
  //    procedure Execute; virtual; abstract;
  //    procedure Synchronize(AMethod: TThreadMethod);
  //    property ReturnValue: Integer read FReturnValue write FReturnValue;
  //    property Terminated: Boolean read FTerminated;
  //{$ifdef windows}
  //  private
  //    FInitialSuspended: boolean;
  //{$endif}
  //{$ifdef Unix}
  //  private
  //    // see tthread.inc, ThreadFunc and TThread.Resume
  //    FSem: Pointer;
  //    FInitialSuspended: boolean;
  //    FSuspendedExternal: boolean;
  //    FSuspendedInternal: longbool;
  //    FThreadReaped: boolean;
  //{$endif}
  //{$ifdef netwlibc}
  //  private
  //    // see tthread.inc, ThreadFunc and TThread.Resume
  //    FSem: Pointer;
  //    FInitialSuspended: boolean;
  //    FSuspendedExternal: boolean;
  //    FPid: LongInt;
  //{$endif}
  //  public
  //    constructor Create(CreateSuspended: Boolean;
  //                       const StackSize: SizeUInt = DefaultStackSize);
  //    destructor Destroy; override;
  //    procedure AfterConstruction; override;
  //    procedure Start;
  //    procedure Resume; deprecated;
  //    procedure Suspend; deprecated;
  //    procedure Terminate;
  //    function WaitFor: Integer;
  //    class procedure Synchronize(AThread: TThread; AMethod: TThreadMethod);
  //    property FreeOnTerminate: Boolean read FFreeOnTerminate write FFreeOnTerminate;
  //    property Handle: TThreadID read FHandle;
  //    property Priority: TThreadPriority read GetPriority write SetPriority;
  //    property Suspended: Boolean read GetSuspended write SetSuspended;
  //    property ThreadID: TThreadID read FThreadID;
  //    property OnTerminate: TNotifyEvent read FOnTerminate write FOnTerminate;
  //    property FatalException: TObject read FFatalException;
  //  end;
  //
  //
  //
  //
  //
  //
  //
  ////////////////////////////////////////////////////////////////////////////////


function ThreadProc(lParam: Integer): Integer; stdcall;
var
//  pipename:string;
  pipehandle:THandle;
  message:PAnsiChar;
  Len :integer;
  BytesWritten: longword;
  res:boolean;
begin
  // here we... what do we even do here?
  try
  placeholder;

  except
    on E: Exception do
      MessageBox(0, PAnsiChar(AnsiString(E.Message)), 'error', 0);
  end;

  //pipename:= PAnsiChar('\\.\pipe\spypipe');
  MessageBox(0, 'Starting another thread on this bad boy', 'lalalala', 0);

  PipeHandle := CreateFile( '\\.\pipe\spypipe',
                            GENERIC_READ or GENERIC_WRITE,
                            FILE_SHARE_READ or FILE_SHARE_WRITE,
                            nil,
                            OPEN_EXISTING,
                            0,
                            0);

  MessageBox(0, 'Got the pipe handle on this side', 'Pipe', 0);

  Message := PAnsiChar( 'Hello boss! I am in the enemy program. They suspect nothing' );
  Len := Length(Message)*SizeOf(Char) + 1;

  res := WriteFile( PipeHandle,
                    Message^,
                    Len,
                    BytesWritten,
                    nil);


  if res then message:= 'write succesful' else message:= 'write failed';
  messagebox(0, 'Bytes written: ', message, 0);

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

