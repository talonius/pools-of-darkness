{ Game startup, run as this unit's initialization: start the overlay manager, choose the data paths, then read pool4.cfg
  (written by STARTUP.EXE) to set the sound device, video mode, input device, save paths and joystick calibration. }
{$O+,F+}
{$I-}
unit GameBoot;

interface

implementation

uses Crt, Dos, Overlay, DaxIo, GameIo, Joystick, Blit, TextRend, GDConsts, GDVars, C_Sound, C_Video, Types;

const
  { soundDevice values only this unit sets }
  SOUND_MODE_SOUND_BLASTER = 0;
  SOUND_MODE_ADLIB = 2;
  { the video BIOS function that returns the current mode in AL }
  BIOS_GET_VIDEO_MODE = $0F;
  { BIOS video modes }
  VIDEO_MODE_EGA_320X200 = $0D;
  VIDEO_MODE_TANDY_320X200 = $09;
  VIDEO_MODE_VGA_320X200 = $13;
  { the paragraphs HeapEnd is lowered by to make room for the Tandy screen }
  TANDY_HEAP_RESERVE_PARAGRAPHS = 1024;
  OVERLAY_BUFFER_BYTES = 143360;

{ Most of what this unit sets up lives in other units and is read by them. }
var
  { the program's own directory, searched first }
  executableDirectory: DirStr absolute GDVars.currentDataPath;

begin
  CheckBreak := False;
  DaxIo.OverlayPrompt;
  OvrInit('GAME.OVR');
  { Hook the overlay reader so a failed read beeps and retries until the right disk is in. This must follow OvrInit,
    which installs the reader being wrapped. }
  @GDVars.savedOvrReadFunc := @OvrReadBuf;
  OvrReadBuf := GameIo.OverlayReadWithBeep;

  FSplit(FExpand('*.exe'), executableDirectory, NameStr(GDVars.executableName), ExtStr(GDVars.executableExtension));
  { The alternate data path: on a hard disk it is the program's own directory; run from a floppy it is the other floppy
    drive. }
  if GDVars.currentDataPath[1] < 'C' then begin
    if GDVars.currentDataPath[1] = 'A' then GDVars.alternateDataPath := 'B:\'
    else GDVars.alternateDataPath := 'A:\';
  end else GDVars.alternateDataPath := GDVars.currentDataPath;
  GDVars.promptDrive := GDVars.alternateDataPath[1];

  { The cfg lines in order: sound card, video adapter, input device, the two save paths, one unused line, then the
    joystick calibration points. }
  if not DaxIo.FileExists('pool4.cfg') then Halt(1);
  Assign(GDVars.configFile, 'pool4.cfg');
  Reset(GDVars.configFile);

  ReadLn(GDVars.configFile, GDVars.configCode);
  case GDVars.configCode of
    '1': GDVars.soundDevice := GameBoot.SOUND_MODE_SOUND_BLASTER;
    '2': GDVars.soundDevice := GameBoot.SOUND_MODE_ADLIB;
    '3',
    '4': GDVars.soundDevice := C_Sound.TANDY_VOICES;
    '5': GDVars.soundDevice := C_Sound.PC_SPEAKER;
  else
    GDVars.soundDevice := C_Sound.MUTED;
  end;

  ReadLn(GDVars.configFile, GDVars.configCode);
  GDVars.interruptRegs.ah := GameBoot.BIOS_GET_VIDEO_MODE;
  Intr($10, Registers(GDVars.interruptRegs));
  GDVars.savedVideoMode := GDVars.interruptRegs.al;
  GDVars.curVideoMode := GDVars.savedVideoMode;
  case GDVars.configCode of
    'E': begin
           GDVars.videoMode := C_Video.DISPLAY_EGA;
           Blit.SetVideoMode(GameBoot.VIDEO_MODE_EGA_320X200);
           GDVars.shownPageNum := 0;
           GDVars.drawPageNum := 0;
           TextRend.SetupEgaCurrentPage(GDVars.shownPageNum);
           TextRend.SetupEgaOtherPage(GDVars.drawPageNum);
         end;
    'T': begin
           GDVars.videoMode := C_Video.DISPLAY_TANDY;
           GDVars.tandyHeapEnd := Ptr(Types.TPtrRec(HeapEnd).seg - GameBoot.TANDY_HEAP_RESERVE_PARAGRAPHS,
                                      Types.TPtrRec(HeapEnd).ofs);
           HeapEnd := GDVars.tandyHeapEnd;
           Blit.SetVideoMode(GameBoot.VIDEO_MODE_TANDY_320X200);
         end;
    'V': begin
           GDVars.videoMode := C_Video.DISPLAY_MCGA;
           Blit.SetVideoMode(GameBoot.VIDEO_MODE_VGA_320X200);
         end;
  end;

  if GameBoot.OVERLAY_BUFFER_BYTES - OvrGetBuf <= MemAvail then
    OvrSetBuf(GameBoot.OVERLAY_BUFFER_BYTES)
  else begin
    Blit.RestoreVideoMode;
    WriteLn('Not enough memory to run game.  You need ', GameBoot.OVERLAY_BUFFER_BYTES - OvrGetBuf - MemAvail,
            ' more bytes.');
    Halt(0);
  end;
  if OvrResult <> ovrOk then begin
    Blit.RestoreVideoMode;
    WriteLn('Overlay error, program abort!');
    Halt(0);
  end;

  ReadLn(GDVars.configFile, GDVars.configCode);
  case GDVars.configCode of
    'J': begin
      GDVars.joystickInstalled := True; GDVars.mouseInstalled := False;
    end;
    'M': begin
      GDVars.mouseInstalled := True; GDVars.joystickInstalled := False;
    end;
    'N': begin
      GDVars.mouseInstalled := False; GDVars.joystickInstalled := False;
    end;
  end;

  ReadLn(GDVars.configFile, GDVars.saveDir);
  ReadLn(GDVars.configFile, GDVars.importDir);
  ReadLn(GDVars.configFile, GDVars.configCode);
  Joystick.ProbeJoystick;

  if GDVars.joystickInstalled then
    for GDVars.calibrationIndex := 0 to 6 do begin
      ReadLn(GDVars.configFile, GDVars.joyCalibrations[1].x.points[GDVars.calibrationIndex]);
      ReadLn(GDVars.configFile, GDVars.joyCalibrations[1].y.points[GDVars.calibrationIndex]);
    end;
  Close(GDVars.configFile);
end.
