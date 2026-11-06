{ CONTROL.EXE, the launcher START.BAT runs after STARTUP.EXE. It reads the sound and video choices from pool4.cfg, sets
  the video mode, plays the VACE introduction, then runs GAME. When GAME exits with code 23 the VACE finale is played
  and GAME is run again with a first argument of 1, which loads a saved game straight away. Any other exit restores the
  original video mode and ends. }

{$I-}
{$M 2048,0,0}
program Control;

uses Dos;

const
  { video BIOS functions, passed in AH }
  BIOS_GET_VIDEO_MODE = $0F;
  BIOS_SET_VIDEO_MODE = 0;
  { BIOS video modes }
  VIDEO_MODE_EGA_320X200 = $0D;
  VIDEO_MODE_TANDY_320X200 = $09;
  VIDEO_MODE_VGA_320X200 = $13;
  { VACE's video-mode argument }
  VACE_MODE_EGA = 2;
  VACE_MODE_TANDY = 3;
  VACE_MODE_VGA = 4;

var
  cfg: Text;
  { VACE's music switch: '0' for the silent sound choice, else '1' }
  musicArg: Char;
  cfgChar: Char;
  regs: Dos.Registers;
  vaceVideoMode: Integer;
  savedMode: Byte;
  cmdLine: string[40];
  isDone: Boolean;

begin
  Assign(cfg, 'pool4.cfg');
  Reset(cfg);
  Readln(cfg, cfgChar);
  if cfgChar = '6' then musicArg := '0' else musicArg := '1';
  Readln(cfg, cfgChar);
  Close(cfg);
  regs.AH := BIOS_GET_VIDEO_MODE;
  Dos.Intr($10, regs);
  savedMode := regs.AL;
  regs.AH := BIOS_SET_VIDEO_MODE;
  { Note: an unrecognized video choice has no fallback. }
  case cfgChar of
    'E': begin regs.AL := VIDEO_MODE_EGA_320X200; vaceVideoMode := VACE_MODE_EGA; end;
    'T': begin regs.AL := VIDEO_MODE_TANDY_320X200; vaceVideoMode := VACE_MODE_TANDY; end;
    'V': begin regs.AL := VIDEO_MODE_VGA_320X200; vaceVideoMode := VACE_MODE_VGA; end;
  end;
  Dos.Intr($10, regs);
  Str(vaceVideoMode, cmdLine);
  cmdLine := cmdLine + ' INTRO 1 ' + musicArg;
  Dos.SwapVectors;
  Dos.Exec('vace.exe', cmdLine);
  Dos.SwapVectors;
  cmdLine := '0 ' + ParamStr(1) + ' ' + ParamStr(2);
  repeat
    Dos.SwapVectors;
    Dos.Exec('game.exe', cmdLine);
    Dos.SwapVectors;
    if Dos.DosExitCode = 23 then begin
      Str(vaceVideoMode, cmdLine);
      cmdLine := cmdLine + ' FINAL 1 ' + musicArg;
      { The finale runs without swapping the interrupt vectors. }
      Dos.Exec('vace.exe', cmdLine);
      isDone := False;
      cmdLine := '1 ' + ParamStr(1) + ' ' + ParamStr(2);
    end else
      isDone := True;
  until isDone;
  regs.AH := BIOS_SET_VIDEO_MODE;
  regs.AL := savedMode;
  Dos.Intr($10, regs);
  Halt;
end.
