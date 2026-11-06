{ Sound effects through the INT 66h sound driver: SoundCommand copies a loaded sound into the staging buffer and asks
  the driver to play it. The driver calls themselves are in assembler. }
{$F+,O-,S-,R-,V-,B-,I-}
unit SoundDrv;

interface

{ Plays a sound effect, after the driver finishes the one before: copies the loaded sound into the staging buffer and
  sends the driver the play command. Nothing happens without a driver.
  @param(soundId The effect, 2..12; other ids play nothing.) }
procedure SoundCommand(soundId: Word);

{ Does nothing. DaxIo calls it at the end of disk access when the sound driver is in use, and Music after shutting down
  the music driver. }
procedure StartSound;

implementation

uses Types, GDConsts, GDVars;

{$L SOUNDDRV.OBJ}
{ Hand the driver a command block.
  @param(commandOffset The block's offset in the data segment.) }
procedure DriverDispatch(commandOffset: Word); external;

{ Return whether the driver is still playing.
  @returns(True while it plays.) }
function DriverBusy: Boolean; external;

{ Return whether the sound driver is installed, by its "KERN" signature.
  @returns(True when it is.) }
function DriverPresent: Boolean; external;

procedure SoundCommand(soundId: Word);
var
  bufferPtrCopy: Pointer;
begin
  if (soundId > 1) and (soundId < 13) then
    if SoundDrv.DriverPresent then begin
      while SoundDrv.DriverBusy do ;
      FillChar(GDVars.soundDriverCmd, SizeOf(GDVars.soundDriverCmd), 0);
      FillChar(GDVars.soundStagingBuf^, 9000, 0);
      GDVars.soundDriverCmd.bufferSize := 9000;
      GDVars.soundDriverCmd.length := LongInt(GDVars.loadedSounds[soundId - 1].size);
      Move(GDVars.loadedSounds[soundId - 1].data^, GDVars.soundStagingBuf^,
           GDVars.loadedSounds[soundId - 1].size);
      bufferPtrCopy := GDVars.soundStagingBuf;
      Move(bufferPtrCopy, GDVars.soundDriverCmd.buffer, SizeOf(GDVars.soundDriverCmd.buffer));
      SoundDrv.DriverDispatch(Ofs(GDVars.soundDriverCmd));
    end;
end;

procedure StartSound;
begin
end;

begin
end.
