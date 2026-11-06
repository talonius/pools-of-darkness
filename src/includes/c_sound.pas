{ Sound values: the sound commands the game plays by name, and the sound device (GDVars.soundDevice). }
unit C_Sound;

interface

const
  { The soundIds entries the game plays by name. }
  OFF = 0;
  STEP = 10;
  { GDVars.soundDevice values: the Tandy voices, the PC speaker, and no sound (none chosen, or Ctrl-S) }
  TANDY_VOICES = 3;
  PC_SPEAKER = 4;
  MUTED = 5;

implementation

end.
