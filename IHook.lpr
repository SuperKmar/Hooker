library IHook;

{$mode objfpc}{$H+}

uses
  SysUtils, windows
  { you can add units after this };

begin

  messagebox(0, 'foobar', 'hi', 0);
  freelibraryandexitthread(hinstance, 0);

end.

