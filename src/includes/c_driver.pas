{ The music and sound driver state (GDVars.driverState). }
unit C_Driver;

interface

const
  { no driver in use }
  NO_DRIVER = 0;
  { the sound-effect driver is in use, and sounds go to SoundDrv; nothing in this game sets this state }
  SOUND_EFFECTS = 1;
  { the music driver is installed (MusDrv.StartDriver) }
  MUSIC_INSTALLED = 2;

implementation

end.
