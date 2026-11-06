{ The display: the display classes GDVars.videoMode selects, and VGA display memory. }
unit C_Video;

interface

const
  { GDVars.videoMode values }
  DISPLAY_EGA = 0;
  DISPLAY_TANDY = 1;
  DISPLAY_MCGA = 2;
  { VGA display memory as a 32-bit value: a Word offset is added to it and the sum cast to a pointer }
  VGA_BASE = $A0000000;

implementation

end.
