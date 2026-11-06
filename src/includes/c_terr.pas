{ Combat terrain values: the markers a cell takes under a spell or a corpse, and the cost no move can pay. }
unit C_Terr;

interface

const
  { a cell under a blade barrier }
  TERRAIN_BLADE_BARRIER = 27;
  { a cell under a cloudkill }
  TERRAIN_CLOUDKILL = 28;
  { a cell under a stinking cloud }
  TERRAIN_STINKING_CLOUD = 29;
  { the marker a downed creature leaves on its cell }
  TERRAIN_CORPSE = 31;
  { a terrain movement cost no move can pay }
  TERRAIN_IMPASSABLE = 255;

implementation

end.
