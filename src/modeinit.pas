{ Builds the debug password ('Gem') at startup from the item-name word table. Explore compares the third command-line
  parameter against it and, on a match, allows the area map even in restricted zones. }
{$F+,O-,S-,R-,V-,B-,I-}
unit ModeInit;

interface

implementation

uses GDConsts, GDVars;

begin
  GDVars.debugPassword := GDConsts.itemNameParts[122];
end.
