{ Refreshes the view pane while exploring: the area's big picture when a map redraw is pending, otherwise the 3D view
  from the party's position. }
{$O+,F+,S-,R-,V-,B-,I-}
unit MapView;

interface

{ Refreshes the view pane, unless the party is defeated. With a redraw pending, shows the big picture of the area's tile
  set, except in a 3D area whose map pane is turned off. Otherwise, in the exploration interface only, draws the 3D view
  and loads the map palette if it changed. Clears the pending redraw. }
procedure DisplayMapView;

implementation

uses Blit, Portrait, View3D, Types, GDConsts, GDVars, C_Ifc;

procedure DisplayMapView;
var
  pictureId: Byte;
begin
  if GDVars.partyDefeatedFlag then Exit;

  if (not ((GDVars.vmBand.zone0^.inDungeon = 1) and
           (GDVars.vmBand.zone0^.mapPaneEnabled = 0))) and
             (GDVars.mapRedrawPending <> 0) then begin
    { Note: the tile set is not checked against the six-entry picture table. }
    pictureId := GDConsts.areaPictureIds[GDVars.vmBand.zone0^.tileSet];
    Portrait.LoadBigPic(pictureId);
    Portrait.DisplayBigPic;
  end else begin
    if GDVars.interfaceState <> C_Ifc.DUNGEON then Exit;
    View3D.Display3DMapView(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
    if GDVars.mainPalReload then begin
      Blit.SetDacPalette(32, 148, GDVars.mainPal);
      GDVars.mainPalReload := False;
    end;
  end;

  GDVars.mapRedrawPending := 0;
end;

begin
end.
