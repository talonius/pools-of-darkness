{ Keyboard, mouse and joystick input. Every key the game reads passes through ReadGameKey, which also handles the Ctrl-S
  sound toggle, the Ctrl-U debug toggle and the Ctrl-C abort. The unit also hands out a fixed pool of 63-byte work
  records. }
{$F+,O-,S-,R-,V-,B-,I-}
unit GameIo;

interface

uses Mouse, Joystick, Crt, MusDrv, SoundDrv, Types, GDConsts, GDVars, C_Keys, C_Sound, C_Dir, C_Driver;

{ Ends the program: hides and resets the mouse, shuts the music driver down, sends the reset request if the sound driver
  is in use, and halts. Note: the reset id is outside SoundDrv.SoundCommand's 2..12 range, so nothing is sent.
  @param(code The exit status.) }
procedure ExitGame(code: Byte);

{ Returns the next key. A waiting key is read at once. Otherwise the mouse, or the joystick when there is no mouse, is
  polled until it gives input or a key is pressed: mouse button 1 or 2 gives Enter or Escape (and sets
  GDVars.keyFromMouse), a joystick direction gives its key from GDConsts.joystickKeys, and joystick buttons 1 and 2 give
  Enter and Escape; a key pressed meanwhile wins. With neither device it waits for a key, or returns #0 while the demo
  runs. Then Ctrl-S mutes the sound or restores the saved mode (Tandy voices or the PC speaker only), Ctrl-U toggles the
  debug flag (shutting the music driver down when it clears), and Ctrl-C aborts the game.
  @returns(The key, control keys included, or #0 in the demo when none was waiting.) }
function ReadGameKey: Char;

{ Tells whether input is waiting.
  @returns(True when a key is waiting, a mouse button is down, or -- without a mouse -- a joystick button is down or the
    stick is out of the center.) }
function InputPending: Boolean;

{ Reads and discards every key waiting in the keyboard buffer. }
procedure FlushKeys;

{ Reads and discards one waiting input through ReadGameKey, so its control-key commands still work. }
procedure DiscardPendingKeys;

{ Reads an overlay for the overlay manager, as installed by GameBoot: calls the saved reader until that succeeds,
  beeping (4000 Hz, 20 ms) after each failure.
  @param(readParam The overlay to read, passed to the saved reader.)
  @returns(0, success.) }
function OverlayReadWithBeep(readParam: Word): Integer;

{ Finds the first free record in the item pool (item type 0). It is not marked taken here: the caller's record fills it.
  @returns(The record, or nil when none is free.) }
function AllocSlot: Types.PItemRec;

{ Frees p: a pool record is zeroed in place and p set to nil; anything else is a heap block, freed at a record's size.
  Note: after FreeMem, p is left unchanged, pointing at the freed block.
  @param(p Record to free.) }
procedure FreeSlot(var p: Types.PItemRec);

{ Fills a block with zero bytes.
  @param(s The block.)
  @param(n Its size in bytes.) }
procedure ZeroFill(var s; n: Word);

implementation

const
  { the control keys ReadGameKey acts on }
  KEY_CTRL_C = #3;
  KEY_CTRL_S = #19;
  KEY_CTRL_U = #21;
  { soundIds entry }
  SOUND_ON = 1;

{$L KEYBOARD.OBJ}
procedure ZeroFill(var s; n: Word); external;

procedure ExitGame(code: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  Mouse.HideMouse;
  Mouse.ResetMouse;
  MusDrv.StopHook;
  if GDVars.driverState = C_Driver.SOUND_EFFECTS then
    SoundDrv.SoundCommand(GDConsts.soundReset);
  Halt(code);
end;

function ReadGameKey: Char;
var
  key: Char;
  { Unused in this version; see the other implementations of this routine. }
  cur: Pointer;
  inputState: record
    ready: Byte;
    scanCode: Byte;
    action: Integer;
  end;
  { Unused in this version; see the other implementations of this routine. }
  mouseButtons: Word;

  { Waits for a key or for joystick input, turning a button into Enter or Escape and a stick zone into its keypad key. }
  procedure TranslateJoystick;
  begin
    inputState.action := 0;
    inputState.ready := 0;
    while not (KeyPressed or (inputState.ready <> 0)) do begin
      Joystick.GetJoystick(inputState.action, inputState.scanCode);
      if (inputState.scanCode < C_Dir.CENTER) or Boolean(inputState.action <> 0) then begin
        if inputState.scanCode < C_Dir.CENTER then
          key := GDConsts.joystickKeys[inputState.scanCode]
        else
          case inputState.action of
            1: key := C_Keys.ENTER;
            2: key := C_Keys.ESCAPE;
          end;
        inputState.ready := 1;
      end;
    end;
  end;

  { Waits for a key or a mouse button, turning the button into Enter or Escape and noting the mouse click. }
  procedure TranslateMouse;
  begin
    inputState.action := 0;
    inputState.ready := 0;
    while not (KeyPressed or (inputState.ready <> 0)) do begin
      Mouse.GetMouse(inputState.action, GDVars.mousePosX, GDVars.mousePosY);
      if inputState.action <> 0 then begin
        case inputState.action of
          1: key := C_Keys.ENTER;
          2: key := C_Keys.ESCAPE;
        end;
        GDVars.keyFromMouse := 1;
        inputState.ready := 1;
      end;
    end;
  end;

begin
  GDVars.keyFromMouse := 0;
  if KeyPressed then
    key := ReadKey
  else if GDVars.joystickInstalled or GDVars.mouseInstalled then begin
    if GDVars.mouseInstalled then
      TranslateMouse
    else
      TranslateJoystick;
    if KeyPressed then
      key := ReadKey;
  end else begin
    if GDVars.demoMode then
      key := #0
    else
      key := ReadKey;
  end;

  if key = GameIo.KEY_CTRL_S then
    if GDVars.soundDevice <> C_Sound.MUTED then begin
      GDVars.savedSoundMode := GDVars.soundDevice;
      if GDVars.driverState = C_Driver.SOUND_EFFECTS then
        SoundDrv.SoundCommand(GDConsts.soundIds[C_Sound.OFF]);
      GDVars.soundDevice := C_Sound.MUTED;
    end else if GDVars.savedSoundMode in [C_Sound.TANDY_VOICES, C_Sound.PC_SPEAKER] then begin
      GDVars.soundDevice := GDVars.savedSoundMode;
      if GDVars.driverState = C_Driver.SOUND_EFFECTS then
        SoundDrv.SoundCommand(GDConsts.soundIds[GameIo.SOUND_ON]);
    end;

  if key = GameIo.KEY_CTRL_U then begin
    GDVars.debugEnabled := Ord(GDVars.debugEnabled = 0);
    if GDVars.debugEnabled = 0 then
      MusDrv.StopHook;
  end;

  if key = GameIo.KEY_CTRL_C then
    GameIo.ExitGame(0);

  ReadGameKey := key;
end;

function InputPending: Boolean;
var action: Integer; scanCode: Byte;
begin
  InputPending := KeyPressed;
  if GDVars.joystickInstalled or GDVars.mouseInstalled then
    if GDVars.mouseInstalled then begin
      Mouse.GetMouse(action, GDVars.mousePosX, GDVars.mousePosY);
      InputPending := KeyPressed or Boolean(action <> 0);
    end else begin
      Joystick.GetJoystick(action, scanCode);
      InputPending := KeyPressed or Boolean(action > 0) or Boolean(scanCode < C_Dir.CENTER);
    end;
end;

procedure FlushKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  discardedKey: Char;
begin
  while KeyPressed do
    discardedKey := ReadKey;
end;

procedure DiscardPendingKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  discardedKey: Char;
begin
  if GameIo.InputPending then
    discardedKey := GameIo.ReadGameKey;
end;

function OverlayReadWithBeep(readParam: Word): Integer;
begin
  while GDVars.savedOvrReadFunc(readParam) <> 0 do begin
    Sound(4000);
    Delay(20);
    NoSound;
  end;
  OverlayReadWithBeep := 0;
end;

function AllocSlot: Types.PItemRec;
var i: Byte; found: Boolean; r: Types.PItemRec;
begin
  found := False;
  i := 1;
  r := nil;
  while (i <= SizeOf(GDVars.workSlots) div SizeOf(Types.TItemRec)) and not found do
    if GDVars.workSlots[i].definition.itemType = 0 then begin
      r := @GDVars.workSlots[i];
      found := True;
    end else
      Inc(i);
  AllocSlot := r;
end;

procedure FreeSlot(var p: Types.PItemRec);
var i: Byte;
begin
  i := 1;
  while (i <= SizeOf(GDVars.workSlots) div SizeOf(Types.TItemRec)) and (p <> @GDVars.workSlots[i]) do
    Inc(i);
  if i <= SizeOf(GDVars.workSlots) div SizeOf(Types.TItemRec) then begin
    GameIo.ZeroFill(GDVars.workSlots[i], SizeOf(Types.TItemRec));
    p := nil;
  end else
    FreeMem(p, SizeOf(Types.TItemRec));
end;

begin
end.
