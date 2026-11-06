{ Movement input and movement commit.

  MapMainMenu drives either the first-person dungeon controls (interface state 4) or the overland map's compass controls
  (state 3). ResolveMovement applies the chosen dungeon step or scrolls the overland map window, then releases the
  portrait animation. The Area action toggles the automap only where the area is not restricted, or when command-line
  parameter 3 matches the debug word ModeInit sets up. Toggling the automap marks the palette dirty before the redraw. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Explore;

interface

uses Crt, Music, Mouse, Border, TextRend, Camp, ViewChar, GameTime, CharHlp, MapWin, MenuCore, Portrait, View3D,
  Types, GDConsts, GDVars, C_Status, C_Ifc, C_Sound, C_Dir, C_Keys;

{ Applies the pending move: in the dungeon, marks the map for redraw and steps forward when the way ahead is open; on
  the overland map, takes a MovePartyWilderness step; either way the position and time are redrawn. A suppressed
  movement state (255) is cleared instead in the dungeon and in any other interface state, but kept on the overland map.
  Finally frees the portrait animation. }
procedure ResolveMovement;

{ Reads one movement command. In the dungeon the menu offers Move, Area, Cast, View, Encamp, Search and Look, and other
  extended keys change the selected character; after Move, the up arrow steps, down turns around and left and right
  turn, until Exit or Escape returns to the menu. On the overland map only Move and Encamp are offered, and after Move
  an arrow key sets the facing for the next scroll. The bottom window is cleared once afterwards.
  @returns(The last input code, $FF after a step or turn. Note: it is undefined when the overland map's pane is disabled
    or the interface state is neither of these.) }
function MapMainMenu: Byte;

implementation

const
  { GDVars.vmBand.zone0^.movementState while a move is held back }
  MOVE_STATE_SUPPRESSED = $FF;
  { GDVars.vmBand.zone0^.travelFlags bits }
  SEARCH_FLAG = 1;
  LOOK_FLAG = 2;

{ Clears the zone's leave-map flag, then, when the barrier ahead lets the party through and the step would leave the
  16x16 map, clamps the position to the edge and sets the flag. }
procedure MoveForward;
var
  candidateX: Integer;
  candidateY: Integer;
  candidateFacing: Word;
begin
  candidateX := GDVars.mapState.x;
  candidateY := GDVars.mapState.y;
  candidateFacing := GDVars.mapState.facing;
  GDVars.vmBand.zone0^.edgeClamp := 0;
  if View3D.GetBarrierType(candidateX, candidateY, candidateFacing) <> 0 then begin
    Inc(candidateX, GDConsts.dirDeltaX[candidateFacing]);
    Inc(candidateY, GDConsts.dirDeltaY[candidateFacing]);
    if candidateX > 15 then begin
      GDVars.mapState.x := 15;
      GDVars.vmBand.zone0^.edgeClamp := 1
    end;
    if candidateX < 0 then begin
      GDVars.mapState.x := 0;
      GDVars.vmBand.zone0^.edgeClamp := 1
    end;
    if candidateY > 15 then begin
      GDVars.mapState.y := 15;
      GDVars.vmBand.zone0^.edgeClamp := 1
    end;
    if candidateY < 0 then begin
      GDVars.mapState.y := 0;
      GDVars.vmBand.zone0^.edgeClamp := 1
    end;
  end;
end;

{ Takes one step forward with the step sound and a short pause, wrapping around the map edge, looks up the wall ahead
  and the new cell's event, and advances the clock: one minute, or ten while searching. }
procedure MovePartyForward3D;
begin
  Music.SendSoundCommand(GDConsts.soundIds[C_Sound.STEP]);
  Delay(50);
  Inc(GDVars.mapState.x, GDConsts.dirDeltaX[GDVars.mapState.facing]);
  Inc(GDVars.mapState.y, GDConsts.dirDeltaY[GDVars.mapState.facing]);
  if GDVars.mapState.x < 0 then GDVars.mapState.x := 15;
  if GDVars.mapState.x > 15 then GDVars.mapState.x := 0;
  if GDVars.mapState.y < 0 then GDVars.mapState.y := 15;
  if GDVars.mapState.y > 15 then GDVars.mapState.y := 0;
  GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
  GDVars.mapState.event := View3D.GetMapEvent(GDVars.mapState.x, GDVars.mapState.y);
  if GDVars.vmBand.zone0^.travelFlags and Explore.SEARCH_FLAG > 0 then
    GameTime.AdvanceTime(1, 2)
  else
    GameTime.AdvanceTime(1, 1);
end;

{ Scroll the overland map window one cell toward the party's facing, kept within its 38-by-15 grid, and charge
  wilderness travel time. }
procedure MovePartyWilderness;
var
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  newCol: ShortInt;
  newRow: ShortInt;
begin
  Mouse.HideMouse;
  MapWin.CloseWindow;
  GDVars.vmBand.zone0^.prevX := GDVars.vmBand.zone0^.windowCol;
  GDVars.vmBand.zone0^.prevY := GDVars.vmBand.zone0^.windowRow;
  newCol := GDVars.vmBand.zone0^.windowCol + GDConsts.dirDeltaX[GDVars.mapState.facing];
  newRow := GDVars.vmBand.zone0^.windowRow + GDConsts.dirDeltaY[GDVars.mapState.facing];
  if newCol < 0 then newCol := 0;
  if newCol > 37 then newCol := 37;
  if newRow < 0 then newRow := 0;
  if newRow > 14 then newRow := 14;
  GDVars.vmBand.zone0^.windowCol := newCol;
  GDVars.vmBand.zone0^.windowRow := newRow;
  MapWin.OpenWindow;
  Mouse.ShowMouse;
  GameTime.AdvanceTime(12, 3);
end;

function MapMainMenu: Byte;
var
  loopDone: Boolean;
  slotCount: Byte;
  inputCode: Byte;
  actionDone: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  savedMenu: array[0..11] of Byte;
  savedSel: Byte;
begin
  GDVars.vmBand.zone0^.movementState := 0;
  savedSel := GDVars.horizMenuChoice;
  case GDVars.interfaceState of
  C_Ifc.DUNGEON: begin
    loopDone := False;
    inputCode := $FF;
    repeat
      if GDVars.clickInputMode = 0 then begin
        MenuCore.ResetMenuSlots(6);
        GDVars.horizMenuChoice := savedSel;
        inputCode := Ord(MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.moveMenuItems, True, False));
        savedSel := GDVars.horizMenuChoice;
        if GDVars.extendedKeyFlag = False then begin
          case inputCode of
            0: begin
                 MenuCore.ClearBottomLine;
                 GDVars.clickInputMode := 1;
               end;
            1: begin
                 if (GDVars.vmBand.zone0^.areaRestricted = 0) or
                     (ParamStr(3) = GDVars.debugPassword) then begin
                   GDVars.automapShown := Byte(GDVars.automapShown = 0);
                   GDVars.viewPaletteDirty := True;
                   View3D.Display3DMapView(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
                 end else
                   TextRend.PrintAndPause(GDConsts.notHereMsg, 14, 0);
               end;
            2: if GDVars.currentChar^.status = C_Status.OKAY then
                 Camp.NoncombatCastMenu;
            3: ViewChar.ViewCharMenu(actionDone);
            4: loopDone := True;
            5: begin
                 GDVars.vmBand.zone0^.travelFlags := GDVars.vmBand.zone0^.travelFlags xor Explore.SEARCH_FLAG;
                 CharHlp.PrintMiscInfo;
               end;
            6: begin
                 GDVars.vmBand.zone0^.travelFlags := GDVars.vmBand.zone0^.travelFlags or Explore.LOOK_FLAG;
                 CharHlp.PrintMiscInfo;
                 GameTime.AdvanceTime(1, 2);
                 GDVars.vmBand.eclIp := GDVars.vmBand.vmRun[2];
                 loopDone := True;
               end;
          end;
        end else begin
          CharHlp.DisplayRoster(GDVars.currentChar, False);
          ViewChar.SelectPrevNextChar(Chr(inputCode));
          CharHlp.DisplayRoster(GDVars.currentChar, True);
          CharHlp.PrintMiscInfo;
        end;
      end else begin
        FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
        MenuCore.ResetMenuSlots(0);
        inputCode := Ord(MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.exitMenu, True, False));
        if GDVars.extendedKeyFlag = False then begin
          if inputCode = 0 then GDVars.clickInputMode := 0;
        end else begin
          case inputCode of
            Ord(C_Keys.UP): begin
                   Explore.MoveForward;
                   loopDone := True;
                   CharHlp.PrintMiscInfo;
                   inputCode := $FF;
                 end;
            Ord(C_Keys.DOWN): begin
                   GDVars.mapState.facing := (GDVars.mapState.facing + 4) mod 8;
                   GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y,
                                                                   GDVars.mapState.facing);
                   View3D.Display3DMapView(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
                   CharHlp.PrintMiscInfo;
                   inputCode := $FF;
                 end;
            Ord(C_Keys.LEFT): begin
                   GDVars.mapState.facing := (GDVars.mapState.facing + 6) mod 8;
                   GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y,
                                                                   GDVars.mapState.facing);
                   View3D.Display3DMapView(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
                   CharHlp.PrintMiscInfo;
                   inputCode := $FF;
                 end;
            Ord(C_Keys.RIGHT): begin
                   GDVars.mapState.facing := (GDVars.mapState.facing + 2) mod 8;
                   GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y,
                                                                   GDVars.mapState.facing);
                   View3D.Display3DMapView(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
                   CharHlp.PrintMiscInfo;
                   inputCode := $FF;
                 end;
            Ord(C_Keys.ESCAPE): GDVars.clickInputMode := 0;
          end;
        end;
      end;
    until loopDone;
  end;
  C_Ifc.AREA_MAP: begin
    if GDVars.vmBand.zone0^.mapPaneEnabled <> 0 then begin
      loopDone := False;
      repeat
        FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
        if GDVars.clickInputMode = 0 then begin
          slotCount := 0;
          MenuCore.AppendSlot(0, slotCount);
          MenuCore.AppendSlot(4, slotCount);
          GDVars.horizMenuChoice := savedSel;
          inputCode := Ord(MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.moveMenuItems, True, False));
          savedSel := GDVars.horizMenuChoice;
          if not GDVars.extendedKeyFlag then begin
            case inputCode of
              0: begin
                   MenuCore.ClearBottomLine;
                   GDVars.clickInputMode := 1;
                 end;
              4: loopDone := True;
            end;
          end;
        end else begin
          FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
          GDVars.menuSlotTable[0].choiceIndex := 0;
          inputCode := Ord(MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.exitMenu, True, False));
          if GDVars.extendedKeyFlag = False then begin
            if inputCode = 0 then GDVars.clickInputMode := 0;
          end else begin
            loopDone := True;
            case inputCode of
              Ord(C_Keys.UP): GDVars.mapState.facing := C_Dir.NORTH;
              Ord(C_Keys.PAGE_UP): GDVars.mapState.facing := C_Dir.NORTHEAST;
              Ord(C_Keys.RIGHT): GDVars.mapState.facing := C_Dir.EAST;
              Ord(C_Keys.PAGE_DOWN): GDVars.mapState.facing := C_Dir.SOUTHEAST;
              Ord(C_Keys.DOWN): GDVars.mapState.facing := C_Dir.SOUTH;
              Ord(C_Keys.END_KEY): GDVars.mapState.facing := C_Dir.SOUTHWEST;
              Ord(C_Keys.LEFT): GDVars.mapState.facing := C_Dir.WEST;
              Ord(C_Keys.HOME): GDVars.mapState.facing := C_Dir.NORTHWEST;
              Ord(C_Keys.ESCAPE): GDVars.clickInputMode := 0;
            end;
            CharHlp.PrintMiscInfo;
          end;
        end;
      until loopDone;
    end;
  end;
  end;
  if GDVars.viewBoxDrawn = 0 then begin
    Border.ClearBox(1, 17, 38, 22);
    GDVars.viewBoxDrawn := 1;
  end;
  MapMainMenu := inputCode;
end;

procedure ResolveMovement;
var
  { Unused in this version; see the other implementations of this routine. }
  moved: Boolean;
begin
  moved := False;
  case GDVars.interfaceState of
  C_Ifc.DUNGEON: begin
    if GDVars.vmBand.zone0^.movementState < Explore.MOVE_STATE_SUPPRESSED then begin
      GDVars.mapRedrawPending := 1;
      if View3D.GetBarrierType(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing) = 1 then begin
        moved := True;
        Explore.MovePartyForward3D;
      end;
      CharHlp.PrintMiscInfo;
    end else
      GDVars.vmBand.zone0^.movementState := 0;
  end;
  C_Ifc.AREA_MAP: begin
    if GDVars.vmBand.zone0^.movementState < Explore.MOVE_STATE_SUPPRESSED then begin
      Explore.MovePartyWilderness;
      CharHlp.PrintMiscInfo;
    end;
  end;
  else
    GDVars.vmBand.zone0^.movementState := 0;
  end;
  Portrait.FreeAnimation;
end;

begin
end.
