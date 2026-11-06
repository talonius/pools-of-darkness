{ The music driver: loads the driver image and its parameter blocks from MUSIC.dax, installs the driver through MusDrv,
  and shuts it down around sound commands and disk access. }
{$F+}
{$I-}
unit Music;

interface

uses DaxIo, GameIo, MusDrv, SoundDrv, ZeroFree, GDConsts, GDVars, C_Driver, C_Sound, Types;

{ Plays a sound effect: shuts down the music driver if it is installed, then passes the sound to SoundDrv.
  @param(soundId The effect for SoundDrv.SoundCommand.) }
procedure SendSoundCommand(soundId: Word);

{ Shuts down the music driver if it is installed, then calls SoundDrv.StartSound. }
procedure RestoreSoundDriver;

{ Starts the music described by a parameter block of MUSIC.dax. Nothing happens while sound is muted. SoundDrv's driver
  is reset if it is active, and a music driver installed with a different block is shut down; when no driver is
  installed the block is loaded and the driver installed with it. Then the driver is told to start (StartPlayback).
  @param(paramsDaxId The parameter block's entry in MUSIC.dax.) }
procedure StartMusic(paramsDaxId: Word);

{ Shuts down the music driver if it is installed. }
procedure StopMusic;

{ Loads the driver image, entry 0 of MUSIC.dax, into the driver buffer (cleared first) at its first paragraph boundary,
  and marks it loaded. A missing image stops the game with 'unable to load com file'. }
procedure LoadDriverCode;

{ Loads a parameter block of MUSIC.dax into the driver parameter buffer (cleared first) and points the driver's
  parameter pointer at it. Note: a missing block is not reported; the buffer is then left cleared.
  @param(paramsDaxId The block's entry in MUSIC.dax.) }
procedure LoadMusicBank(paramsDaxId: Word);

implementation

procedure SendSoundCommand(soundId: Word);
begin
  if GDVars.driverState = C_Driver.MUSIC_INSTALLED then MusDrv.StopHook;
  SoundDrv.SoundCommand(soundId);
end;

procedure RestoreSoundDriver;
begin
  if GDVars.driverState = C_Driver.MUSIC_INSTALLED then MusDrv.StopHook;
  SoundDrv.StartSound;
end;

procedure StartMusic(paramsDaxId: Word);
begin
  if GDVars.soundDevice = C_Sound.MUTED then Exit;
  if GDVars.driverState = C_Driver.SOUND_EFFECTS then SoundDrv.SoundCommand(GDConsts.soundReset);
  if GDVars.drvParamsDaxId <> paramsDaxId then
    if GDVars.driverState = C_Driver.MUSIC_INSTALLED then MusDrv.StopHook;
  if GDVars.driverState = C_Driver.NO_DRIVER then begin
    GDVars.drvParamsDaxId := paramsDaxId;
    Music.LoadMusicBank(paramsDaxId);
    MusDrv.StartDriver(GDVars.drvLoadAddress, GDVars.drvParams);
  end;
  MusDrv.StartPlayback(0);
end;

procedure StopMusic;
begin
  if GDVars.driverState = C_Driver.MUSIC_INSTALLED then MusDrv.StopHook;
end;

procedure LoadDriverCode;
var
  data: Types.PBytes;
  { Unused in this version; see the other implementations of this routine. }
  driverFile: file;
begin
  data := nil;
  DaxIo.LoadDax('MUSIC', '.dax', 0, GDVars.drvImageSize, data);
  if GDVars.drvImageSize = 0 then begin
    WriteLn('unable to load com file');
    GameIo.ExitGame(0);
  end;
  GameIo.ZeroFill(GDVars.drvImageBuffer^, 13000);
  GDVars.drvLoadAddress := LongInt(GDVars.drvImageBuffer);
  while Lo(GDVars.drvLoadAddress and $F) <> 0 do
    Inc(GDVars.drvLoadAddress);
  Move(data^, Types.PBytes(GDVars.drvLoadAddress)^, GDVars.drvImageSize);
  ZeroFree.PrefixFree(data, GDVars.drvImageSize);
  GDVars.drvImageLoaded := 1;
end;

procedure LoadMusicBank(paramsDaxId: Word);
var
  data: Types.PBytes;
  { Unused in this version; see the other implementations of this routine. }
  musicFile: file;
  { Unused in this version; see the other implementations of this routine. }
  bytesRead: Word;
begin
  DaxIo.LoadDax('MUSIC', '.dax', paramsDaxId, GDVars.drvParamsSize, data);
  GameIo.ZeroFill(GDVars.drvParamsBuffer^, 6144);
  GDVars.drvParams := GDVars.drvParamsBuffer;
  Move(data^, GDVars.drvParams^, GDVars.drvParamsSize);
  ZeroFree.PrefixFree(data, GDVars.drvParamsSize);
end;

begin
end.
