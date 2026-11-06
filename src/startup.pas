{ STARTUP.EXE, the configuration program START.BAT runs before CONTROL.EXE.

  It asks for the sound card, graphics adapter, alternate input and the two save paths, writes the answers to pool4.cfg,
  calibrates the joystick, and copies the chosen DIGPAK driver over snd.exe. The second save path is the save directory
  of the earlier game whose characters can be imported.

  When pool4.cfg already exists the questions are skipped; the driver is then copied only if snd.exe is missing. }

{$I-,O+,V-}
{$M 16384,0,0}
program Startup;

uses Dos, Crt;

{$L JOYSTICK.OBJ}

const
  { the calibration points: upper left corner, center, lower right corner }
  CAL_UPPER_LEFT = 0;
  CAL_CENTER = 3;
  CAL_LOWER_RIGHT = 6;
  { readings taken for a calibration point }
  SAMPLE_COUNT = 20;
  JOY1_BUTTON1_MASK = 1;
  JOY1_BUTTON2_MASK = 2;
  JOY2_BUTTON1_MASK = 4;
  JOY2_BUTTON2_MASK = 8;

type
  TJoyAxis = array[CAL_UPPER_LEFT..CAL_LOWER_RIGHT] of Word;

var
  index: Byte;
  cfg: Text;
  { pool4.cfg was written this run }
  wroteCfg: Boolean;
  useJoystick: Boolean;
  isTandy: Boolean;
  ioError: Byte;
  choice: Byte;
  pathBuf: string;
  { the default offered for a save path }
  savePath: string;
  { the directory this program runs from }
  exeDir: string;
  dirPart: string;
  namePart: string;
  extPart: string;
  { joystick 1 X calibration points, written to the cfg }
  joyX: TJoyAxis;
  { joystick 1 Y calibration points, written to the cfg }
  joyY: TJoyAxis;
  { joystick 2: cleared, never written out }
  secondJoyX: TJoyAxis;
  secondJoyY: TJoyAxis;
  { unused }
  rawLow: Word;
  { unused }
  rawHigh: Word;
  soundKind: Char;
  { holds the driver file while it is copied }
  copyBuffer: array[1..6001] of Byte;
  driver: file;

{ Reads a joystick from the game port, timing each axis's capacitor discharge.
  @param(joy Joystick 1 or 2; any other number fails.)
  @param(xRaw Receives the X axis count.)
  @param(yRaw Receives the Y axis count.)
  @param(buttons Receives the button bits, inverted so a set bit is a pressed button.)
  @returns(True when the read succeeded; False for a bad joystick number or when an axis times out.) }
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean; external;

{ Tells whether a normal file exists.
  @param(fileName The file name or pattern; an empty name never exists.)
  @returns(True when one exists.) }
function FileExists(fileName: string): Boolean;
var
  entry: SearchRec;
begin
  FindFirst(fileName, 0, entry);
  FileExists := (DosError = 0) and (Length(fileName) <> 0);
end;

{ Copies a driver file over snd.exe, if it exists.
  @param(srcName The driver file.) }
procedure InstallDriver(srcName: string);
var
  count: Word;
  driverFile: file;
begin
  if FileExists(srcName) then begin
    Assign(driverFile, srcName);
    Reset(driverFile, 1);
    count := FileSize(driverFile);
    BlockRead(driverFile, copyBuffer, count);
    Close(driverFile);
    Assign(driverFile, 'snd.Exe');
    if FileExists('snd.exe') then
      Erase(driverFile);
    Rewrite(driverFile, 1);
    BlockWrite(driverFile, copyBuffer, count);
    Close(driverFile);
  end;
end;

{ Waits for a digit key in a range and echoes it.
  @param(lowest The lowest digit accepted.)
  @param(highest The highest digit accepted.)
  @returns(The digit's value.) }
function GetChoice(lowest, highest: Byte): Byte;
var
  key: Char;
begin
  repeat
    key := ReadKey;
  until (key in ['0'..'9']) and ((Ord(key) - Ord('0')) in [lowest..highest]);
  Write(key);
  GetChoice := Ord(key) - Ord('0');
end;

{ Clear all calibration tables and turn joystick use off if joystick 1 does not answer. }
procedure ResetJoystick;
var
  xRaw: Word;
  yRaw: Word;
  buttons: Byte;
begin
  { joyX, joyY, secondJoyX and secondJoyY }
  FillChar(joyX, 4 * SizeOf(TJoyAxis), 0);
  if useJoystick then
    useJoystick := ReadJoystick(1, xRaw, yRaw, buttons);
end;

{ Tests one button.
  @param(joy The stick, 1 or 2.)
  @param(button The button, 1 or 2.)
  @returns(True while the button is down; False while the joystick is off or the stick cannot be read.) }
function ButtonDown(joy, button: Byte): Boolean;
var
  mask: Byte;
  xRaw: Word;
  yRaw: Word;
  buttons: Byte;
begin
  ButtonDown := False;
  if not useJoystick then Exit;
  mask := 0;
  buttons := 0;
  if ReadJoystick(joy, xRaw, yRaw, buttons) then
    case joy of
      1: case button of
           1: mask := JOY1_BUTTON1_MASK;
           2: mask := JOY1_BUTTON2_MASK;
         end;
      2: case button of
           1: mask := JOY2_BUTTON1_MASK;
           2: mask := JOY2_BUTTON2_MASK;
         end;
    end;
  ButtonDown := (buttons and mask) > 0;
end;

{ Calibrate joystick 1. The resting position is sampled as the center (point 3); the player then holds the stick in the
  upper left and lower right corners with button 1 pressed to set points 0 and 6, and points 1-2 and 4-5 are spaced
  evenly between them. If the stick cannot be read, calibration is abandoned. }
procedure Calibrate;
var
  accumX: Word;
  accumY: Word;
  answered: Boolean;
  xRaw: Word;
  yRaw: Word;
  { Unused in this version; see the other implementations of this routine. }
  pressed: Byte;
  waited: Word;
  sample: Byte;
  buttons: Byte;
begin
  ResetJoystick;
  if not useJoystick then Exit;
  accumX := 0;
  accumY := 0;
  for waited := 1 to SAMPLE_COUNT do begin
    answered := ReadJoystick(1, xRaw, yRaw, buttons);
    Inc(accumX, xRaw);
    Inc(accumY, yRaw);
  end;
  joyX[CAL_CENTER] := accumX div SAMPLE_COUNT;
  joyY[CAL_CENTER] := accumY div SAMPLE_COUNT;
  repeat
    ClrScr;
    Writeln('Push JOYSTICK #1 to the extreme upper left position and press BUTTON #1.');
    waited := 0;
    repeat
      answered := ReadJoystick(1, xRaw, yRaw, buttons);
      Inc(waited);
    until (waited > 20000) or (answered and ((buttons and JOY1_BUTTON1_MASK) <> 0));
    if waited > 20000 then begin
      ClrScr;
      Writeln('Couldn''t read the joystick.  Aborting calibration.');
      Delay(2000);
      Exit;
    end;
    accumX := $FFFF;
    accumY := $FFFF;
    for sample := 1 to SAMPLE_COUNT do
      if ReadJoystick(1, xRaw, yRaw, buttons) then begin
        if (buttons and JOY1_BUTTON1_MASK) <> 0 then begin
          if xRaw < accumX then accumX := xRaw;
          if yRaw < accumY then accumY := yRaw;
        end;
      end else begin
        ClrScr;
        Writeln('Couldn''t read the joystick.  Aborting calibration.');
        Delay(2000);
        Exit;
      end;
  until answered;
  joyX[CAL_UPPER_LEFT] := accumX;
  joyX[1] := (joyX[CAL_CENTER] - joyX[CAL_UPPER_LEFT]) div 3 + joyX[CAL_UPPER_LEFT];
  joyX[2] := (joyX[CAL_CENTER] - joyX[CAL_UPPER_LEFT]) * 2 div 3 + joyX[CAL_UPPER_LEFT];
  joyY[CAL_UPPER_LEFT] := accumY;
  joyY[1] := (joyY[CAL_CENTER] - joyY[CAL_UPPER_LEFT]) div 3 + joyY[CAL_UPPER_LEFT];
  joyY[2] := (joyY[CAL_CENTER] - joyY[CAL_UPPER_LEFT]) * 2 div 3 + joyY[CAL_UPPER_LEFT];
  repeat until not ButtonDown(1, 1);
  repeat
    ClrScr;
    Writeln('Push JOYSTICK #1 to the extreme lower right position and press BUTTON #1.');
    waited := 0;
    repeat
      answered := ReadJoystick(1, xRaw, yRaw, buttons);
      Inc(waited);
    until (waited > 20000) or (answered and ((buttons and JOY1_BUTTON1_MASK) <> 0));
    if waited > 20000 then begin
      ClrScr;
      Writeln('Couldn''t read the joystick.  Aborting calibration.');
      Delay(2000);
      Exit;
    end;
    accumX := 0;
    accumY := 0;
    for sample := 1 to SAMPLE_COUNT do
      if ReadJoystick(1, xRaw, yRaw, buttons) then begin
        if (buttons and JOY1_BUTTON1_MASK) <> 0 then begin
          if xRaw > accumX then accumX := xRaw;
          if yRaw > accumY then accumY := yRaw;
        end;
      end else begin
        ClrScr;
        Writeln('Couldn''t read the joystick.  Aborting calibration.');
        Delay(2000);
        Exit;
      end;
  until answered;
  joyX[CAL_LOWER_RIGHT] := accumX;
  joyX[4] := (joyX[CAL_LOWER_RIGHT] - joyX[CAL_CENTER]) div 3 + joyX[CAL_CENTER];
  joyX[5] := (joyX[CAL_LOWER_RIGHT] - joyX[CAL_CENTER]) * 2 div 3 + joyX[CAL_CENTER];
  joyY[CAL_LOWER_RIGHT] := accumY;
  joyY[4] := (joyY[CAL_LOWER_RIGHT] - joyY[CAL_CENTER]) div 3 + joyY[CAL_CENTER];
  joyY[5] := (joyY[CAL_LOWER_RIGHT] - joyY[CAL_CENTER]) * 2 div 3 + joyY[CAL_CENTER];
  useJoystick := True;
end;

begin
  ClrScr;
  Writeln('TANDY 1000 USERS: make sure NUMLOCK is on.');
  Delay(2000);
  FSplit(FExpand('*.exe'), dirPart, namePart, extPart);
  exeDir := dirPart;
  wroteCfg := False;
  if not FileExists('pool4.cfg') then
  begin
    wroteCfg := True;
    Assign(cfg, 'pool4.cfg');
    Rewrite(cfg);
    ioError := IOResult;
    if ioError <> 0 then begin
      ClrScr;
      Writeln('Error Writing to disk ', ioError);
      Writeln;
      Halt(1);
    end;
    ClrScr;
    Writeln('Sound Type:  [1] Sound Blaster');
    Writeln('             [2] Adlib');
    Writeln('             [3] Tandy 1000 EX/TX/SX/HX');
    Writeln('             [4] Tandy 1000 SL/TL');
    Writeln('             [5] PC');
    Writeln('             [6] Silent');
    choice := GetChoice(1, 6);
    Writeln(cfg, choice);
    ClrScr;
    Write('GRAPHICS ADAPTER TYPE:  [1] EGA  [2] Tandy [3] VGA ');
    { Note: accepts 4, which writes no adapter line }
    choice := GetChoice(1, 4);
    isTandy := False;
    case choice of
      1: Writeln(cfg, 'E');
      2: begin
           Writeln(cfg, 'T');
           isTandy := True;
         end;
      3: Writeln(cfg, 'V');
    end;
    ClrScr;
    useJoystick := False;
    ClrScr;
    Write('ALTERNATE INPUT TYPE:  [1] JOYSTICK  [2] MOUSE  [3] NEITHER  ');
    choice := GetChoice(1, 3);
    case choice of
      1: begin
           Writeln(cfg, 'J');
           useJoystick := True;
         end;
      2: if isTandy then
           Writeln(cfg, 'N')
         else
           Writeln(cfg, 'M');
      3: Writeln(cfg, 'N');
    end;
    ClrScr;
    savePath := exeDir + 'SAVE';
    Write('PATH TO SAVE DATA (DEFAULT - ' + savePath + '):  ');
    Readln(pathBuf);
    pathBuf[1] := UpCase(pathBuf[1]);
    if not ((Length(pathBuf) >= 4) and (pathBuf[2] = ':') and
            not ((pathBuf[1] in ['A'..'B']) and (pathBuf[1] = dirPart[1])) and (pathBuf[1] in ['A'..'P'])) then
    begin
      pathBuf := savePath;
      Writeln('USING DEFAULT PATH: ' + pathBuf);
      Delay(2000);
    end;
    for index := 1 to Length(pathBuf) do
      pathBuf[index] := UpCase(pathBuf[index]);
    if pathBuf[Length(pathBuf)] <> '\' then
      pathBuf := pathBuf + '\';
    Writeln(cfg, pathBuf);
    ClrScr;
    pathBuf := '';
    if exeDir[1] < 'C' then
      savePath := exeDir[1] + ':\SAVE'
    else
      savePath := exeDir[1] + ':\SECRET\SAVE';
    Writeln('PATH TO SAVE DATA FOR SECRET OF THE SILVER BLADES');
    Write('(DEFAULT - ' + savePath + '):  ');
    Readln(pathBuf);
    pathBuf[1] := UpCase(pathBuf[1]);
    if not ((Length(pathBuf) >= 4) and (pathBuf[2] = ':') and
            not ((pathBuf[1] in ['A'..'B']) and (pathBuf[1] = dirPart[1])) and (pathBuf[1] in ['A'..'P'])) then
    begin
      pathBuf := savePath;
      Writeln('USING DEFAULT PATH: ' + pathBuf);
      Delay(2000);
    end;
    for index := 1 to Length(pathBuf) do
      pathBuf[index] := UpCase(pathBuf[index]);
    if pathBuf[Length(pathBuf)] <> '\' then
      pathBuf := pathBuf + '\';
    Writeln(cfg, pathBuf);
    Writeln(cfg, 'F');
    Calibrate;
    for index := CAL_UPPER_LEFT to CAL_LOWER_RIGHT do begin
      Writeln(cfg, joyX[index]);
      Writeln(cfg, joyY[index]);
    end;
    Close(cfg);
  end;
  if FileExists('pool4.cfg') then
  begin
    if not (FileExists('snd.exe') and not wroteCfg) then
    begin
      Assign(cfg, 'pool4.cfg');
      Reset(cfg);
      Readln(cfg, soundKind);
      Close(cfg);
      case soundKind of
        '1': pathBuf := 'sblaster.exe';
        '2': pathBuf := 'adlib.exe';
        '3': pathBuf := 'tanextx.exe';
        '4': pathBuf := 'tansltl.exe';
        '5': pathBuf := 'ibmsnd.exe';
      end;
      if soundKind <> '6' then
        InstallDriver(pathBuf)
      else if FileExists('snd.exe') then
      begin
        Assign(driver, 'snd.exe');
        Close(driver);
        Erase(driver);
      end;
    end;
  end;
end.
