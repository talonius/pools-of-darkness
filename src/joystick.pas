{ PC game-port joystick input, read against the calibration points STARTUP.EXE stored in pool4.cfg. The stick position
  maps to one of eight compass directions or the center, and the two buttons to confirm and cancel. }
{$F+,O-,S-,R-,V-,B-,I-}
unit Joystick;

interface

{ Clears both calibration records; when the joystick is enabled, keeps it enabled only if joystick 1 can be read. }
procedure ProbeJoystick;

{ Reads a joystick and places each axis among its calibrated boundaries 1..5, then looks the column and row up in the
  zone map.
  @param(joy Joystick 1 or 2.)
  @returns(The zone from the zone map, or the no-zone value when the joystick is off or cannot be read.) }
function JoyZone(joy: Byte): Byte;

{ Tells whether a joystick button is pressed. Joystick 1's buttons are bits 0 and 1 of the button byte, joystick 2's
  bits 2 and 3; another joystick or button number reads as not pressed.
  @param(joy Joystick 1 or 2.)
  @param(button Button 1 or 2.)
  @returns(True when the button is down; False when the joystick is off or cannot be read.) }
function JoyButton(joy, button: Byte): Boolean;

{ Reads joystick 1 as input: a pressed button and the stick's zone.
  @param(action Receives 2 when button 2 is down, else 1 when button 1 is down, else 0.)
  @param(zone Receives the stick's zone, from JoyZone.) }
procedure GetJoystick(var action: Integer; var zone: Byte);

{ Reads a joystick from the game port, timing each axis's capacitor discharge.
  @param(joy Joystick 1 or 2; any other number fails.)
  @param(xRaw Receives the X axis count.)
  @param(yRaw Receives the Y axis count.)
  @param(buttons Receives all four button bits of both joysticks, inverted so a set bit is a pressed button and shifted
    to the low nibble.)
  @returns(True when the read succeeded; False for a bad joystick number or when an axis times out.) }
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;

implementation

uses GDConsts, GDVars, C_Dir;

const
  { the game-port button bits }
  JOY1_BUTTON1_MASK = 1;
  JOY1_BUTTON2_MASK = 2;
  JOY2_BUTTON1_MASK = 4;
  JOY2_BUTTON2_MASK = 8;

{$L JOYSTICK.OBJ}
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean; external;

procedure ProbeJoystick;
var
  x: Word;
  y: Word;
  buttons: Byte;
begin
  FillChar(GDVars.joyCalibrations, SizeOf(GDVars.joyCalibrations), 0);
  if GDVars.joystickInstalled then
    GDVars.joystickInstalled := Joystick.ReadJoystick(1, x, y, buttons);
end;

function JoyZone(joy: Byte): Byte;
var
  x: Word;
  y: Word;
  col: Integer;
  row: Integer;
  buttons: Byte;
  { Unused in this version; see the other implementations of this routine. }
  threshold: array[0..1] of Byte;
begin
  JoyZone := C_Dir.CENTER;
  if not GDVars.joystickInstalled then
    Exit;
  if not Joystick.ReadJoystick(joy, x, y, buttons) then
    Exit;
  col := 0;
  for GDVars.scratchIndex := 1 to 5 do
    if GDVars.joyCalibrations[joy].x.threshold[GDVars.scratchIndex] < x then
      col := GDVars.scratchIndex;
  row := 0;
  for GDVars.scratchIndex := 1 to 5 do
    if GDVars.joyCalibrations[joy].y.threshold[GDVars.scratchIndex] < y then
      row := GDVars.scratchIndex;
  JoyZone := GDConsts.joystickZones[row, col];
end;

function JoyButton(joy, button: Byte): Boolean;
var
  mask: Byte;
  x: Word;
  y: Word;
  buttons: Byte;
begin
  JoyButton := False;
  if not GDVars.joystickInstalled then
    Exit;
  mask := 0;
  buttons := 0;
  if Joystick.ReadJoystick(joy, x, y, buttons) then
    case joy of
      1: case button of
                   1: mask := Joystick.JOY1_BUTTON1_MASK;
                   2: mask := Joystick.JOY1_BUTTON2_MASK;
                 end;
      2: case button of
                  1: mask := Joystick.JOY2_BUTTON1_MASK;
                  2: mask := Joystick.JOY2_BUTTON2_MASK;
                end;
    end;
  JoyButton := (buttons and mask) > 0;
end;

procedure GetJoystick(var action: Integer; var zone: Byte);
begin
  action := 0;
  if Joystick.JoyButton(1, 2) then
    action := 2
  else if Joystick.JoyButton(1, 1) then
    action := 1;
  zone := Joystick.JoyZone(1);
end;

begin
end.
