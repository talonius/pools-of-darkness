{ The INT 33h mouse driver calls the game uses, and a classifier that turns a mouse movement into the scan code of the
  matching arrow key. Every call does nothing when no mouse driver was found. }
{$F+,O-,S-,R-,V-,B-,I-}
unit Mouse;

interface

uses Dos, GDConsts, GDVars, C_Dir, C_Keys;

{ Resets the mouse driver through INT 33h; when a driver answers, marks the mouse present and records the button count,
  otherwise marks it absent. }
procedure InitMouse;

{ Shows the mouse cursor. Does nothing without a mouse. }
procedure ShowMouse;

{ Hides the mouse cursor. Does nothing without a mouse. }
procedure HideMouse;

{ Reads the mouse buttons and position, halving the column unless the mouse's scale flag is set. Does nothing without a
  mouse.
  @param(buttons Receives the button state.)
  @param(x Receives the column.)
  @param(y Receives the row.) }
procedure GetMouse(var buttons, x, y: Integer);

{ Moves the mouse cursor, doubling the column unless the mouse's scale flag is set. Does nothing without a mouse.
  @param(x Column.)
  @param(y Row.) }
procedure SetMouse(x, y: Integer);

{ Sets the graphics cursor shape and hot spot. Does nothing without a mouse.
  @param(hotX Hot spot column within the cursor.)
  @param(hotY Hot spot row within the cursor.)
  @param(mask Screen and cursor masks of the shape.) }
procedure SetMouseCursor(hotX, hotY: Integer; mask: Pointer);

{ Resets the mouse driver's software state. Does nothing without a mouse. }
procedure ResetMouse;

{ Classifies a mouse move into one of eight 45-degree sectors and returns the matching keypad key. The slopes 618/256
  and 106/256 stand for tan 67.5 and tan 22.5 degrees; the sectors are tried clockwise from up, so a move with no motion
  counts as up. Note: the horizontal change times 618 overflows an Integer for moves wider than 53 units, which can give
  the wrong direction.
  @param(oldX Starting column.)
  @param(oldY Starting row.)
  @param(newX Ending column.)
  @param(newY Ending row.)
  @returns(The scan code of the arrow, Home, End, Page Up or Page Down key for that direction.) }
function MouseDirection(oldX, oldY, newX, newY: Integer): Byte;

implementation

const
  RESET_DRIVER = 0;
  SHOW_CURSOR = 1;
  HIDE_CURSOR = 2;
  GET_STATE = 3;
  SET_POSITION = 4;
  SET_CURSOR = 9;
  SOFT_RESET = 33;
  DRIVER_PRESENT = 65535;

procedure InitMouse;
begin
  GDVars.interruptRegs.ax := Mouse.RESET_DRIVER;
  Intr($33, Registers(GDVars.interruptRegs));
  if GDVars.interruptRegs.ax = Mouse.DRIVER_PRESENT then begin
    GDVars.mouseButtonCount := GDVars.interruptRegs.bx;
    GDVars.mouseInstalled := True;
  end else
    GDVars.mouseInstalled := False;
end;

procedure ShowMouse;
begin
  if not GDVars.mouseInstalled then
    Exit;
  GDVars.interruptRegs.ax := Mouse.SHOW_CURSOR;
  Intr($33, Registers(GDVars.interruptRegs));
end;

procedure HideMouse;
begin
  if not GDVars.mouseInstalled then
    Exit;
  GDVars.interruptRegs.ax := Mouse.HIDE_CURSOR;
  Intr($33, Registers(GDVars.interruptRegs));
end;

procedure GetMouse(var buttons, x, y: Integer);
begin
  if not GDVars.mouseInstalled then
    Exit;
  GDVars.interruptRegs.ax := Mouse.GET_STATE;
  Intr($33, Registers(GDVars.interruptRegs));
  buttons := GDVars.interruptRegs.bx;
  x := GDVars.interruptRegs.cx;
  if not GDVars.mouseRawX then
    x := x div 2;
  y := GDVars.interruptRegs.dx;
end;

procedure SetMouse(x, y: Integer);
begin
  if not GDVars.mouseInstalled then
    Exit;
  GDVars.interruptRegs.ax := Mouse.SET_POSITION;
  if not GDVars.mouseRawX then
    x := x shl 1;
  GDVars.interruptRegs.cx := x;
  GDVars.interruptRegs.dx := y;
  Intr($33, Registers(GDVars.interruptRegs));
end;

procedure SetMouseCursor(hotX, hotY: Integer; mask: Pointer);
begin
  if not GDVars.mouseInstalled then
    Exit;
  GDVars.interruptRegs.ax := Mouse.SET_CURSOR;
  GDVars.interruptRegs.bx := hotX;
  GDVars.interruptRegs.cx := hotY;
  GDVars.interruptRegs.es := Seg(mask^);
  GDVars.interruptRegs.dx := Ofs(mask^);
  Intr($33, Registers(GDVars.interruptRegs));
end;

procedure ResetMouse;
begin
  if not GDVars.mouseInstalled then
    Exit;
  GDVars.interruptRegs.ax := Mouse.SOFT_RESET;
  Intr($33, Registers(GDVars.interruptRegs));
end;

function MouseDirection(oldX, oldY, newX, newY: Integer): Byte;
var
  direction: Byte;
  found: Boolean;
  scanCode: Byte;
  deltaX: Integer;
  deltaY: Integer;
begin
  deltaX := Abs(newX - oldX);
  deltaY := Abs(newY - oldY);
  direction := C_Dir.NORTH;
  found := False;
  while not found do begin
    case direction of
      C_Dir.NORTH: begin
           found := (newY <= oldY) and (deltaX * 618 div 256 <= deltaY);
           scanCode := Ord(C_Keys.UP);
         end;
      C_Dir.EAST: begin
           found := (newX >= oldX) and (deltaX * 106 div 256 >= deltaY);
           scanCode := Ord(C_Keys.RIGHT);
         end;
      C_Dir.SOUTH: begin
           found := (newY >= oldY) and (deltaX * 618 div 256 <= deltaY);
           scanCode := Ord(C_Keys.DOWN);
         end;
      C_Dir.WEST: begin
           found := (newX <= oldX) and (deltaX * 106 div 256 >= deltaY);
           scanCode := Ord(C_Keys.LEFT);
         end;
      C_Dir.NORTHEAST: begin
           found := (newY < oldY) and (newX > oldX) and
             (deltaX * 618 div 256 >= deltaY) and
             (deltaX * 106 div 256 <= deltaY);
           scanCode := Ord(C_Keys.PAGE_UP);
         end;
      C_Dir.SOUTHEAST: begin
           found := (newY > oldY) and (newX > oldX) and
             (deltaX * 618 div 256 >= deltaY) and
             (deltaX * 106 div 256 <= deltaY);
           scanCode := Ord(C_Keys.PAGE_DOWN);
         end;
      C_Dir.SOUTHWEST: begin
           found := (newY > oldY) and (newX < oldX) and
             (deltaX * 618 div 256 >= deltaY) and
             (deltaX * 106 div 256 <= deltaY);
           scanCode := Ord(C_Keys.END_KEY);
         end;
      C_Dir.NORTHWEST: begin
           found := (newY < oldY) and (newX < oldX) and
             (deltaX * 618 div 256 >= deltaY) and
             (deltaX * 106 div 256 <= deltaY);
           scanCode := Ord(C_Keys.HOME);
         end;
    end;
    if not found then
      Inc(direction);
  end;
  MouseDirection := scanCode;
end;

begin
end.
