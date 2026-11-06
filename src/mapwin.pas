{ The party marker on the area map: draws the cursor picture over the party's map cell, keeping the screen beneath it so
  the marker can be lifted again when the party moves. }
{$O+,F+,S-,R-,V-,B-,I-}
unit MapWin;

interface

{ Saves the screen under the party's map cell into GDVars.mapWinBackdrop, draws the cursor over a copy of it and puts
  that on the screen, then empties the span tables. }
procedure OpenWindow;

{ Lifts the marker: puts back the screen OpenWindow saved. }
procedure CloseWindow;

implementation

uses Blit, GameIo, Types, GDConsts, GDVars;

procedure OpenWindow;
begin
  Blit.GrabPic(GDVars.vmBand.zone0^.windowCol + 1,
               GDVars.vmBand.zone0^.windowRow + 1, GDVars.mapWinBackdrop);
  Blit.BlitTileCell(0, 0, 0, 0, GDVars.mapWinBackdrop, GDVars.mapWinImage);
  Blit.BlitTileCell(0, 0, 0, 1, GDVars.mapWinOverlay, GDVars.mapWinImage);
  Blit.ShowPic(GDVars.vmBand.zone0^.windowCol + 1,
               GDVars.vmBand.zone0^.windowRow + 1, GDVars.mapWinImage);

  GameIo.ZeroFill(GDVars.spanRowActive, SizeOf(GDVars.spanRowActive));
  GameIo.ZeroFill(GDVars.spanScreenOfs, SizeOf(GDVars.spanScreenOfs));
  { $FF in every byte makes each running minimum $FFFF, the empty value. }
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  GameIo.ZeroFill(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs));
end;

procedure CloseWindow;
begin
  Blit.ShowPic(GDVars.vmBand.zone0^.windowCol + 1,
               GDVars.vmBand.zone0^.windowRow + 1, GDVars.mapWinBackdrop);
end;

begin
end.
