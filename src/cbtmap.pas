{ The combat arena map: the 50x25 grid of terrain and combatants, and the 7x7-cell viewport that shows part of it.
  Tracks where each combatant stands and the cells its icon covers, scrolls and redraws the view, draws facing, the
  cursor and the death animation, records corpses, and answers what lies in a direction. }
{$O+,F+,S-,R-,V-,B-,I-}
unit CbtMap;

interface

uses Blit, Types, GDConsts, GDVars, TextRend, Music, GameIo, Crt, MapTiles, C_Ifc, C_Dir,
  C_Status, C_Terr;

{ Gives the direction from one combatant's arena cell to another's.
  @param(src The combatant looked from.)
  @param(dst The combatant looked at.)
  @returns(The direction 0..7.) }
function DirectionToward(src, dst: Types.PCharRecord): Byte;

{ Gives the direction, clockwise from north, from one point to another: the first of the eight whose sector holds the
  second. The tests multiply by 106 or 618 and divide by 256: 106/256 and 618/256 approximate tan 22.5 and tan 67.5
  degrees.
  @param(x1 The column looked from.)
  @param(y1 The row looked from.)
  @param(x2 The column looked at.)
  @param(y2 The row looked at.)
  @returns(The direction 0..7.) }
function DirectionBetween(x1, y1, x2, y2: Integer): Byte;

{ Finds the terrain beneath an arena cell: under a cloud or barrier, what the covering patch recorded; under a corpse,
  what the corpse lies on. Note: the coordinates are not checked, and a cyclic patch list would never end.
  @param(x The arena column.)
  @param(y The arena row.)
  @returns(The terrain.) }
function ResolveTerrain(x, y: ShortInt): Byte;

{ Finds the offset of one cell of an icon from its anchor cell. Neither sizeCode nor idx is range-checked.
  @param(sizeCode The icon's size code.)
  @param(idx The cell, 0..5.)
  @param(dx Receives the column offset.)
  @param(dy Receives the row offset.)
  @returns(False when the icon has no such cell or the size is 0.) }
function FootprintCell(sizeCode, idx: Byte; var dx, dy: ShortInt): Boolean;

{ Empty: the palette is left as it is after combat. }
procedure SetNoncombatPalette;

{ Redraws one arena cell: repaints its terrain (the whole icon footprint when a creature stands there, through
  UpdateCombatMapTile), then the creature's sprite if it is visible.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.) }
procedure RedrawArenaCell(x, y: ShortInt);

{ Rebuilds the arena's creature-index grid: clears it, then for each creature with a nonzero icon size marks every cell
  its icon covers with the creature's combat slot and recomputes the creature's view coordinates. }
procedure BuildArenaArrays;

{ Looks up what lies on an arena cell.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(combatantIndex Receives the combat slot of the creature standing there; 0 for none or outside the arena.)
  @param(terrainIndex Receives the cell's terrain; 0 outside the arena.) }
procedure GetArenaContents(x, y: ShortInt; var combatantIndex, terrainIndex: Byte);

{ Repaints the terrain under each visible tile of a creature's icon, erasing its sprite, or under the single view cell
  when no creature is there.
  @param(x View column of the cell; the creature's own view column replaces it.)
  @param(y View row of the cell; the creature's own view row replaces it.)
  @param(combatantIndex The creature's combat slot, or 0 to look up the creature standing on the cell.) }
procedure UpdateCombatMapTile(x, y: ShortInt; combatantIndex: Byte);

{ Tells whether a view cell lies inside the 7x7 view.
  @param(x View column.)
  @param(y View row.)
  @returns(True when both coordinates lie inside the view.) }
function ViewCoordsValid(x, y: ShortInt): Boolean;

{ Tests whether a creature's icon is visible in the view.
  @param(character The creature.)
  @param(requireWhole Nonzero to require each tile of the icon in view, 0 to require one.)
  @returns(True when the icon is visible; False when the creature has no icon.) }
function CombatIconVisible(character: Types.PCharRecord; requireWhole: Byte): Boolean;

{ Targets the arena cell one step in the given direction from a cell and redraws the whole view if needed
  (BuildViewBuffer), redrawing each visible icon of a creature in play after a full redraw. Then redraws the cell, draws
  the cursor at the target (kept inside the arena) and flushes the view.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(recenterThreshold How far the target may lie from the view center before the view moves; 255 forces a full
    redraw.)
  @param(direction Direction of the target, 0 to 7; 8 for the cell itself.) }
procedure ScrollView(x, y: ShortInt; recenterThreshold, direction: Byte);

{ Turns a creature. While the combat map shows, it scrolls the creature into view unless it is wholly visible, and
  repaints its terrain when the facing crosses between 0 to 3 and 4 to 7 (the mirrored sprites) or `frame` or
  `eraseOnly` is nonzero. It stores the new facing and, unless `eraseOnly` is set, draws its sprite and flushes when it
  is visible and the map shows.
  @param(character The creature.)
  @param(direction The new facing, 0 to 7.)
  @param(frame The animation frame to draw.)
  @param(eraseOnly Nonzero to erase the sprite without drawing it again.) }
procedure SetCreatureFacing(character: Types.PCharRecord; direction, frame, eraseOnly: Byte);

{ Finds a creature's arena column.
  @param(character The creature.)
  @returns(The column of its icon's upper-left cell.) }
function CombatCellX(character: Types.PCharRecord): ShortInt;

{ Finds a creature's arena row.
  @param(character The creature.)
  @returns(The row of its icon's upper-left cell.) }
function CombatCellY(character: Types.PCharRecord): ShortInt;

{ Finds a creature's icon size in the arena.
  @param(character The creature.)
  @returns(The icon size; 0 when it has no icon.) }
function GetIconSize(character: Types.PCharRecord): Byte;

{ Finds a combatant's combat slot. Note: with no combatants, or more than 72, the search runs past the end of the table.
  @param(character The combatant.)
  @returns(The slot, or 0 if it is not in the fight.) }
function CombatSlot(character: Types.PCharRecord): Byte;

{ Looks one step in a direction from every cell of a combatant's icon.
  @param(character The combatant.)
  @param(direction The direction, 8 for where it stands.)
  @param(combatantIndex Receives another combatant in the way, or 0.)
  @param(terrainIndex Receives the costliest terrain there, or 0 if any cell is off the map.)
  @param(adjacentSpecialTerrain Receives any cloud or barrier terrain met, or 0.) }
procedure ProbeDirection(character: Types.PCharRecord; direction: Byte; var combatantIndex, terrainIndex,
                         adjacentSpecialTerrain: Byte);

{ Shows a combatant falling. Outside combat this is just a sound and a pause. In combat it plays the death animation
  over the icon, once per fall, then, for a regular combatant (notPcNpc clear) that is not gone entirely, leaves a
  corpse, or a petrified one, on its cell unless a cloud covers it, remembering the terrain beneath. Finally it takes
  the creature off the map with no turn left. Note: nothing checks that the corpse table has room.
  @param(character The combatant.) }
procedure CreatureDowned(character: Types.PCharRecord);

{ Places a creature on an arena cell if it fits. Outside combat it does nothing. In combat it places the creature at the
  cell, probes its own cells and rejects the place, zeroing the icon size, on any creature, terrain 0 or impassable
  terrain. On success with `updateMap` set, for a party member it clears the creature's body entries and, unless another
  body lies on the cell, writes into it the terrain its last body covered, or the probed terrain when it has no body
  entry or the body covered a corpse cell. The creature grid is then refilled.
  @param(character The creature.)
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(updateMap True when the creature moves there, so its bodies are cleared.)
  @returns(True outside combat or when the creature fits.) }
function IsValidCreatureLoc(character: Types.PCharRecord; x, y: Byte; updateMap: Boolean): Boolean;

{ Scrolls the view to the creature (ScrollView toward its own cell) when the combat map shows, drawing the cursor over
  its icon footprint when `showCursor` is set; afterwards the cursor is off with size 1.
  @param(character The creature.)
  @param(recenterThreshold How far it may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(showCursor True to draw the cursor.) }
procedure DisplayMapViewCentered(character: Types.PCharRecord; recenterThreshold: Byte; showCursor: Boolean);

implementation

const
  { the terrain drawn for an out-of-range terrain value }
  DEFAULT_TERRAIN_INDEX = 21;
  { cloud and barrier patches (27..29) and the corpses (30 and 31) }
  SPECIAL_TERRAIN_FIRST = 27;
  SPECIAL_TERRAIN_LAST = 31;
  PATCH_TERRAIN_LAST = 29;
  PETRIFIED_CORPSE_TERRAIN = 30;
  { soundIds entry }
  SOUND_MAP_VIEW = 5;
  FOOTPRINT_SIZE_MASK = $7F;
  DEFAULT_PROBE_TERRAIN = 23;
  { GDVars.iconAnimTable entries }
  CURSOR_ANIMATION_INDEX = 28;
  CORPSE_ANIMATION_INDEX = 22;

function FootprintCell(sizeCode, idx: Byte; var dx, dy: ShortInt): Boolean;
begin
  FootprintCell := False;
  if sizeCode = 0 then Exit;
  dx := GDConsts.footprintOffsets[sizeCode, idx].dx;
  dy := GDConsts.footprintOffsets[sizeCode, idx].dy;
  if dx >= 0 then
    FootprintCell := True;
end;

{ Recomputes each arena creature's view coordinates from its arena cell and the view's upper-left cell. }
procedure CalcGridDeltas;
var
  i: Byte;
begin
  for i := 1 to GDVars.arenaCount do begin
    GDVars.arenaGridX[i] := GDVars.arenaSlots[i].x - GDVars.arenaPtr^.ox;
    GDVars.arenaGridY[i] := GDVars.arenaSlots[i].y - GDVars.arenaPtr^.oy;
  end;
end;

procedure SetNoncombatPalette;
begin
end;

{ Draws an arena cell at a view cell. A cloud, barrier or corpse cell shows the terrain beneath it with its own icon
  drawn on top.
  @param(viewColumn The view column.)
  @param(viewRow The view row.)
  @param(arenaColumn The arena column.)
  @param(arenaRow The arena row.) }
procedure DrawTerrainCell(viewColumn, viewRow, arenaColumn, arenaRow: ShortInt);
var
  t: Byte;
  baseTileId: Byte;
  tileIdToDraw: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cellPointer: array[1..4] of Byte;
begin
  viewColumn := viewColumn * 3;
  viewRow := viewRow * 3;
  t := GDVars.arenaPtr^.cells[arenaRow, arenaColumn];
  if (t > SizeOf(GDConsts.terrainTable) div SizeOf(Types.TTerrain)) or (t = 0) then
    t := CbtMap.DEFAULT_TERRAIN_INDEX;
  baseTileId := GDConsts.terrainTable[t].tileId;
  if t in [CbtMap.SPECIAL_TERRAIN_FIRST..CbtMap.SPECIAL_TERRAIN_LAST] then begin
    t := CbtMap.ResolveTerrain(arenaColumn, arenaRow);
    { overwritten below }
    tileIdToDraw := GDConsts.terrainTable[t].tileId;

    case t of
      C_Terr.TERRAIN_CORPSE, CbtMap.PETRIFIED_CORPSE_TERRAIN:
        for i := 1 to GDVars.downedListCount do
          if (GDVars.downedList[i].x = arenaColumn) and (GDVars.downedList[i].y = arenaRow) then
            t := GDVars.downedList[i].terrain;
    end;
    if (t > SizeOf(GDConsts.terrainTable) div SizeOf(Types.TTerrain)) or (t = 0) then
      t := CbtMap.DEFAULT_TERRAIN_INDEX;
    tileIdToDraw := GDConsts.terrainTable[t].tileId;
    Blit.BlitTileCell(viewColumn, viewRow, tileIdToDraw, 0, GDVars.mapTileSheet, GDVars.viewImageBuf);
    Blit.BlitTileCell(viewColumn, viewRow, 0, 1, GDVars.iconAnimTable[baseTileId + 13, 0], GDVars.viewImageBuf);
  end else
    Blit.BlitTileCell(viewColumn, viewRow, baseTileId, 0, GDVars.mapTileSheet, GDVars.viewImageBuf);
end;

{ Repaints the terrain under the cursor's footprint at an arena cell, draws the cursor there when it is on, then redraws
  the creature standing on the cell if it is visible.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.) }
procedure DrawCursorCell(x, y: ShortInt);
var
  relativeX: ShortInt;
  relativeY: ShortInt;
  footprintX: ShortInt;
  footprintY: ShortInt;
  i: Byte;
  c: Byte;
  t: Byte;
begin
  relativeX := x - GDVars.arenaPtr^.ox;
  relativeY := y - GDVars.arenaPtr^.oy;
  for i := 0 to 5 do
    if CbtMap.FootprintCell(GDVars.arenaPtr^.cursorSize, i, footprintX, footprintY) then
      if CbtMap.ViewCoordsValid(relativeX + footprintX, relativeY + footprintY) then begin
        CbtMap.DrawTerrainCell(relativeX + footprintX, relativeY + footprintY, x + footprintX, y + footprintY);
        if GDVars.arenaPtr^.cursorOn then
          MapTiles.DrawIconAnimSprite(relativeX + footprintX, relativeY + footprintY, 0, 0,
                                      CbtMap.CURSOR_ANIMATION_INDEX);
      end;
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GDVars.slotCreatures[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.arenaGridX[c], GDVars.arenaGridY[c],
                                  GDVars.slotCreatures[c]^.combatAddr^.direction, 0,
                                  GDVars.slotCreatures[c]^.orderNumber);
end;

procedure RedrawArenaCell(x, y: ShortInt);
var
  relativeX: ShortInt;
  relativeY: ShortInt;
  c: Byte;
  t: Byte;
begin
  relativeX := x - GDVars.arenaPtr^.ox;
  relativeY := y - GDVars.arenaPtr^.oy;
  CbtMap.UpdateCombatMapTile(relativeX, relativeY, 0);
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GDVars.slotCreatures[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.arenaGridX[c], GDVars.arenaGridY[c],
                                  GDVars.slotCreatures[c]^.combatAddr^.direction, 0,
                                  GDVars.slotCreatures[c]^.orderNumber);
end;

procedure BuildArenaArrays;
var
  i: Byte;
  j: Byte;
  footprintX: ShortInt;
  footprintY: ShortInt;
begin
  GameIo.ZeroFill(GDVars.arenaCellSlot, SizeOf(GDVars.arenaCellSlot));
  for i := 1 to GDVars.arenaCount do begin
    if GDVars.arenaSlots[i].sizeCode > 0 then begin
      for j := 0 to 5 do
        if CbtMap.FootprintCell(GDVars.arenaSlots[i].sizeCode, j, footprintX, footprintY) then
          GDVars.arenaCellSlot[GDVars.arenaSlots[i].y + footprintY, GDVars.arenaSlots[i].x + footprintX] := i;
      GDVars.arenaGridX[i] := GDVars.arenaSlots[i].x - GDVars.arenaPtr^.ox;
      GDVars.arenaGridY[i] := GDVars.arenaSlots[i].y - GDVars.arenaPtr^.oy;
    end;
  end;
end;

procedure GetArenaContents(x, y: ShortInt; var combatantIndex, terrainIndex: Byte);
begin
  if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then begin
    terrainIndex := GDVars.arenaPtr^.cells[y, x];
    combatantIndex := GDVars.arenaCellSlot[y, x];
  end else begin
    combatantIndex := 0;
    terrainIndex := 0;
  end;
end;

procedure UpdateCombatMapTile(x, y: ShortInt; combatantIndex: Byte);
var
  arenaX: ShortInt;
  arenaY: ShortInt;
  footprintX: ShortInt;
  footprintY: ShortInt;
  i: Byte;
  t: Byte;
  footprintSize: Byte;
begin
  if combatantIndex = 0 then begin
    arenaX := x + GDVars.arenaPtr^.ox;
    arenaY := y + GDVars.arenaPtr^.oy;
    CbtMap.GetArenaContents(arenaX, arenaY, combatantIndex, t);
  end;
  if combatantIndex > 0 then begin
    x := GDVars.arenaGridX[combatantIndex];
    y := GDVars.arenaGridY[combatantIndex];
    arenaX := x + GDVars.arenaPtr^.ox;
    arenaY := y + GDVars.arenaPtr^.oy;
    footprintSize := GDVars.arenaSlots[combatantIndex].sizeCode;
    for i := 0 to 5 do
      if CbtMap.FootprintCell(footprintSize, i, footprintX, footprintY) then
        if CbtMap.ViewCoordsValid(x + footprintX, y + footprintY) then
          CbtMap.DrawTerrainCell(x + footprintX, y + footprintY, arenaX + footprintX, arenaY + footprintY);
  end else if CbtMap.ViewCoordsValid(x, y) then
    CbtMap.DrawTerrainCell(x, y, arenaX, arenaY);
end;

function ViewCoordsValid(x, y: ShortInt): Boolean;
begin
  if (x < 0) or (x > 6) or (y < 0) or (y > 6) then
    ViewCoordsValid := False
  else
    ViewCoordsValid := True;
end;

function CombatIconVisible(character: Types.PCharRecord; requireWhole: Byte): Boolean;
var
  i: Byte;
  combatSlotIndex: Byte;
  footprintX: ShortInt;
  footprintY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  visibleTiles: Integer;
begin
  CombatIconVisible := True;
  combatSlotIndex := CbtMap.CombatSlot(character);
  if GDVars.arenaSlots[combatSlotIndex].sizeCode = 0 then
    CombatIconVisible := False
  else
    for i := 0 to 5 do begin
      if CbtMap.FootprintCell(GDVars.arenaSlots[combatSlotIndex].sizeCode, i, footprintX, footprintY) then
        if not CbtMap.ViewCoordsValid(GDVars.arenaGridX[combatSlotIndex] + footprintX,
                               GDVars.arenaGridY[combatSlotIndex] + footprintY) then begin
          CombatIconVisible := False;
          if requireWhole <> 0 then Exit;
        end else begin
          CombatIconVisible := True;
          if requireWhole = 0 then Exit;
        end;
    end;
end;

{ Recenters the 7x7 view on a target cell when it lies farther from the view center than allowed, keeping the view
  inside the arena, then draws the view's terrain and recomputes the creatures' view coordinates.
  @param(x Arena column of the target.)
  @param(y Arena row of the target.)
  @param(recenterThreshold How far the target may lie from the view center; 255 forces a redraw.)
  @returns(True when the view was redrawn.) }
function BuildViewBuffer(x, y: ShortInt; recenterThreshold: Byte): Boolean;
var
  d: Byte;
  { Unused in this version; see the other implementations of this routine. }
  pixX: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  pixY: ShortInt;
  i: Byte;
  j: Byte;
  cX: ShortInt;
  cY: ShortInt;
  minX: ShortInt;
  maxX: ShortInt;
  minY: ShortInt;
  maxY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bufferIndex: Integer;
begin
  BuildViewBuffer := False;
  cX := GDVars.arenaPtr^.ox + 3;
  cY := GDVars.arenaPtr^.oy + 3;
  d := recenterThreshold;
  if recenterThreshold = 255 then
    d := 0;
  minX := cX - d;
  maxX := cX + d;
  minY := cY - d;
  maxY := cY + d;
  if (recenterThreshold <> 255) and (x >= minX) and (x <= maxX)
     and (y >= minY) and (y <= maxY) then Exit;
  if x < minX then
    while (x < cX) and (cX > 3) do Dec(cX)
  else if x > maxX then
    while (x > cX) and (cX < 46) do Inc(cX);
  if y < minY then
    while (y < cY) and (cY > 3) do Dec(cY)
  else if y > maxY then
    while (y > cY) and (cY < 21) do Inc(cY);
  GDVars.arenaPtr^.ox := cX - 3;
  GDVars.arenaPtr^.oy := cY - 3;
  cY := GDVars.arenaPtr^.oy;
  for j := 0 to 6 do begin
    cX := GDVars.arenaPtr^.ox;
    for i := 0 to 6 do begin
      CbtMap.DrawTerrainCell(i, j, cX, cY);
      Inc(cX);
    end;
    Inc(cY);
  end;
  CbtMap.CalcGridDeltas;
  BuildViewBuffer := True;
end;

procedure ScrollView(x, y: ShortInt; recenterThreshold, direction: Byte);
var
  p: Types.PCharRecord;
  i: Byte;
  tx: ShortInt;
  ty: ShortInt;
begin
  tx := x + GDConsts.dirDeltaX[direction];
  ty := y + GDConsts.dirDeltaY[direction];
  if CbtMap.BuildViewBuffer(tx, ty, recenterThreshold) then begin
    for i := 1 to GDVars.arenaCount do begin
      p := GDVars.slotCreatures[i];

      if (p^.inPlay <> 0) and (GDVars.arenaSlots[i].sizeCode > 0) then
        if CbtMap.CombatIconVisible(p, 0) then
          MapTiles.DrawIconAnimSprite(GDVars.arenaGridX[i], GDVars.arenaGridY[i], p^.combatAddr^.direction, 0,
                                      p^.orderNumber);
    end;
  end;
  CbtMap.RedrawArenaCell(x, y);
  if not CbtMap.ViewCoordsValid(tx - GDVars.arenaPtr^.ox, ty - GDVars.arenaPtr^.oy) then begin
    if tx > 49 then tx := 49;
    if tx < 0 then tx := 0;
    if ty > 24 then ty := 24;
    if ty < 0 then ty := 0;
  end;
  CbtMap.DrawCursorCell(tx, ty);
  Blit.FlushView;
end;

procedure SetCreatureFacing(character: Types.PCharRecord; direction, frame, eraseOnly: Byte);
var
  combatSlotIndex: Byte;
begin
  combatSlotIndex := CbtMap.CombatSlot(character);
  if not CbtMap.CombatIconVisible(character, 1) then
    if GDVars.combatGfxOn <> 0 then
      CbtMap.ScrollView(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), 3, C_Dir.CENTER);
  if (character^.combatAddr^.direction div 4 <> direction div 4)
     or (frame <> 0) or (eraseOnly <> 0) then
    if GDVars.combatGfxOn <> 0 then
      CbtMap.UpdateCombatMapTile(0, 0, combatSlotIndex);
  character^.combatAddr^.direction := direction;
  if eraseOnly = 0 then
    if CbtMap.CombatIconVisible(character, 0) then
      if GDVars.combatGfxOn <> 0 then begin
        MapTiles.DrawIconAnimSprite(GDVars.arenaGridX[combatSlotIndex], GDVars.arenaGridY[combatSlotIndex],
                                    direction, frame, character^.orderNumber);
        Blit.FlushView;
      end;
end;

function CombatCellX(character: Types.PCharRecord): ShortInt;
begin
  CombatCellX := GDVars.arenaSlots[CbtMap.CombatSlot(character)].x;
end;

function CombatCellY(character: Types.PCharRecord): ShortInt;
begin
  CombatCellY := GDVars.arenaSlots[CbtMap.CombatSlot(character)].y;
end;

function GetIconSize(character: Types.PCharRecord): Byte;
begin
  GetIconSize := GDVars.arenaSlots[CbtMap.CombatSlot(character)].sizeCode;
end;

function CombatSlot(character: Types.PCharRecord): Byte;
var
  wasFound: Boolean;
  i: Byte;
begin
  wasFound := False;
  CombatSlot := 0;
  i := 0;
  repeat
    Inc(i);
    if GDVars.slotCreatures[i] = character then
      wasFound := True;
  until wasFound or (i = GDVars.arenaCount);
  if wasFound then
    CombatSlot := i;
end;

procedure ProbeDirection(character: Types.PCharRecord; direction: Byte; var combatantIndex, terrainIndex,
                         adjacentSpecialTerrain: Byte);
var
  i: Byte;
  combatSlotIndex: Byte;
  c: Byte;
  t: Byte;
  best: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
  footprintX: ShortInt;
  footprintY: ShortInt;
begin
  combatantIndex := 0;
  terrainIndex := CbtMap.DEFAULT_PROBE_TERRAIN;
  best := 1;
  adjacentSpecialTerrain := 0;
  combatSlotIndex := CbtMap.CombatSlot(character);
  x := GDVars.arenaSlots[combatSlotIndex].x;
  y := GDVars.arenaSlots[combatSlotIndex].y;
  for i := 0 to 5 do begin
    if CbtMap.FootprintCell(GDVars.arenaSlots[combatSlotIndex].sizeCode, i, footprintX, footprintY) then begin
      nx := x + footprintX + GDConsts.dirDeltaX[direction];
      ny := y + footprintY + GDConsts.dirDeltaY[direction];
      CbtMap.GetArenaContents(nx, ny, c, t);
      if c = combatSlotIndex then
        c := 0;
      if c > 0 then
        combatantIndex := c;

      if t in [CbtMap.SPECIAL_TERRAIN_FIRST..CbtMap.PATCH_TERRAIN_LAST] then
        adjacentSpecialTerrain := t;
      if (t = 0) or (terrainIndex = 0) then
        terrainIndex := 0
      else
        if GDConsts.terrainTable[t].cost >= best then begin
          best := GDConsts.terrainTable[t].cost;
          terrainIndex := t;
        end;
    end;
  end;
end;

procedure CreatureDowned(character: Types.PCharRecord);
var
  combatSlotIndex: Byte;
  k: Byte;
  { the animation frame, then the terrain under the corpse }
  frame: Byte;
  footprintX: ShortInt;
  footprintY: ShortInt;
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bodyCell: array[0..2] of Byte;
begin
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then begin
    Music.SendSoundCommand(GDConsts.soundIds[CbtMap.SOUND_MAP_VIEW]);
    TextRend.PauseOnly;
  end else begin
    k := 1;
    while (k < 9) and (GDVars.downedList[k].cr <> character) do
      Inc(k);
    if k < 9 then Exit;
    combatSlotIndex := CbtMap.CombatSlot(character);
    cellX := CbtMap.CombatCellX(character);
    cellY := CbtMap.CombatCellY(character);
    if not CbtMap.CombatIconVisible(character, 1) then
      CbtMap.ScrollView(cellX, cellY, 3, C_Dir.CENTER);
    CbtMap.UpdateCombatMapTile(0, 0, combatSlotIndex);
    Music.SendSoundCommand(GDConsts.soundIds[CbtMap.SOUND_MAP_VIEW]);
    for frame := 0 to 8 do begin
      for k := 0 to 5 do
        if CbtMap.FootprintCell(GDVars.arenaSlots[combatSlotIndex].sizeCode, k, footprintX, footprintY) then
          if CbtMap.ViewCoordsValid(GDVars.arenaGridX[combatSlotIndex] + footprintX,
                             GDVars.arenaGridY[combatSlotIndex] + footprintY) then
            Blit.BlitTileClipped((GDVars.arenaGridX[combatSlotIndex] + footprintX) * 3,
                        (GDVars.arenaGridY[combatSlotIndex] + footprintY) * 3, 0,
                        5, GDVars.iconAnimTable[CbtMap.CORPSE_ANIMATION_INDEX, frame mod 2], GDVars.viewImageBuf);
      Blit.FlushView;
      Delay(10);
    end;

    if character^.combatAddr^.notPcNpc = 0 then
    if character^.status <> C_Status.GONE then begin

      frame := CbtMap.ResolveTerrain(cellX, cellY);
      Inc(GDVars.downedListCount);
      GDVars.downedList[GDVars.downedListCount].terrain := frame;

      if not (GDVars.arenaPtr^.cells[cellY, cellX] in [C_Terr.TERRAIN_CLOUDKILL, C_Terr.TERRAIN_STINKING_CLOUD]) then
        if character^.status = C_Status.PETRIFIED then
          GDVars.arenaPtr^.cells[cellY, cellX] := CbtMap.PETRIFIED_CORPSE_TERRAIN
        else
          GDVars.arenaPtr^.cells[cellY, cellX] := C_Terr.TERRAIN_CORPSE;
      GDVars.downedList[GDVars.downedListCount].cr := character;
      GDVars.downedList[GDVars.downedListCount].x := cellX;
      GDVars.downedList[GDVars.downedListCount].y := cellY;
    end;
    TextRend.PauseOnly;
    CbtMap.UpdateCombatMapTile(0, 0, combatSlotIndex);
    GDVars.arenaSlots[CbtMap.CombatSlot(character)].sizeCode := 0;
    CbtMap.BuildArenaArrays;
    CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 3, C_Dir.CENTER);

    character^.combatAddr^.initiative := 0;
    character^.combatAddr^.movement := 0;
    character^.combatAddr^.guarding := 0;
  end;
end;

function IsValidCreatureLoc(character: Types.PCharRecord; x, y: Byte; updateMap: Boolean): Boolean;
var
  combatSlotIndex: Byte;
  i: Byte;
  c: Byte;
  t: Byte;
  wasFound: Boolean;
  adjacentSpecialTerrain: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    IsValidCreatureLoc := False;
    combatSlotIndex := CbtMap.CombatSlot(character);
    GDVars.arenaSlots[combatSlotIndex].sizeCode := character^.iconDimensions and CbtMap.FOOTPRINT_SIZE_MASK;
    GDVars.arenaSlots[combatSlotIndex].x := x;
    GDVars.arenaSlots[combatSlotIndex].y := y;
    CbtMap.ProbeDirection(character, C_Dir.CENTER, c, t, adjacentSpecialTerrain);
    if (c <> 0) or (t = 0) or (GDConsts.terrainTable[t].cost = C_Terr.TERRAIN_IMPASSABLE) then
      GDVars.arenaSlots[combatSlotIndex].sizeCode := 0
    else begin
      IsValidCreatureLoc := True;
      if updateMap then
        if character^.combatAddr^.notPcNpc = 0 then begin
          for i := 1 to GDVars.downedListCount do
            if GDVars.downedList[i].cr = character then begin
              if GDVars.downedList[i].terrain <> C_Terr.TERRAIN_CORPSE then
                t := GDVars.downedList[i].terrain;
              GameIo.ZeroFill(GDVars.downedList[i], SizeOf(GDVars.downedList[i]));
            end;
          wasFound := False;
          for i := 1 to GDVars.downedListCount do
            if (GDVars.downedList[i].cr <> nil) and (GDVars.downedList[i].x = x)
               and (GDVars.downedList[i].y = y) then
              wasFound := True;
          if not wasFound then
            GDVars.arenaPtr^.cells[y, x] := t;
        end;
      CbtMap.BuildArenaArrays;
    end;
  end else
    IsValidCreatureLoc := True;
end;

procedure DisplayMapViewCentered(character: Types.PCharRecord; recenterThreshold: Byte; showCursor: Boolean);
begin
  GDVars.arenaPtr^.cursorOn := showCursor;
  GDVars.arenaPtr^.cursorSize := GDVars.arenaSlots[CbtMap.CombatSlot(character)].sizeCode;
  if GDVars.combatGfxOn <> 0 then
    CbtMap.ScrollView(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), recenterThreshold,
                      C_Dir.CENTER);
  GDVars.arenaPtr^.cursorOn := False;
  GDVars.arenaPtr^.cursorSize := 1;
end;

function ResolveTerrain(x, y: ShortInt): Byte;
var
  t: Byte;
  i: Byte;
  p: Types.PCellPatch;
begin
  t := GDVars.arenaPtr^.cells[y, x];
  if t in [CbtMap.SPECIAL_TERRAIN_FIRST..CbtMap.PATCH_TERRAIN_LAST] then begin
    p := GDVars.cellPatchList;
    while p <> nil do begin
      for i := 1 to 9 do
        if (p^.used[i] <> 0) and (p^.x + GDConsts.dirDeltaX[GDConsts.patchDirs[i]] = x)
           and (p^.y + GDConsts.dirDeltaY[GDConsts.patchDirs[i]] = y) then
          t := p^.terrainIndex[i];
      p := p^.next;
    end;
  end else if t = C_Terr.TERRAIN_CORPSE then begin
    for i := 1 to GDVars.downedListCount do
      if (GDVars.downedList[i].x = x) and (GDVars.downedList[i].y = y) then
        t := GDVars.downedList[i].terrain;
  end;
  ResolveTerrain := t;
end;

function DirectionBetween(x1, y1, x2, y2: Integer): Byte;
var
  d: Byte;
  wasFound: Boolean;
  absoluteDeltaX: Integer;
  absoluteDeltaY: Integer;
begin
  absoluteDeltaX := Abs(x2 - x1);
  absoluteDeltaY := Abs(y2 - y1);
  d := 0;
  wasFound := False;
  while not wasFound do begin
    case d of
      1: wasFound := (y2 < y1) and (x2 > x1) and
        ((618 * absoluteDeltaX) div 256 >= absoluteDeltaY)
           and ((106 * absoluteDeltaX) div 256 <= absoluteDeltaY);
      3: wasFound := (y2 > y1) and (x2 > x1) and
        ((618 * absoluteDeltaX) div 256 >= absoluteDeltaY)
           and ((106 * absoluteDeltaX) div 256 <= absoluteDeltaY);
      5: wasFound := (y2 > y1) and (x2 < x1) and
        ((618 * absoluteDeltaX) div 256 >= absoluteDeltaY)
           and ((106 * absoluteDeltaX) div 256 <= absoluteDeltaY);
      7: wasFound := (y2 < y1) and (x2 < x1) and
        ((618 * absoluteDeltaX) div 256 >= absoluteDeltaY)
           and ((106 * absoluteDeltaX) div 256 <= absoluteDeltaY);
      0: wasFound := (y2 <= y1) and ((618 * absoluteDeltaX) div 256 <= absoluteDeltaY);
      2: wasFound := (x2 >= x1) and ((106 * absoluteDeltaX) div 256 >= absoluteDeltaY);
      4: wasFound := (y2 >= y1) and ((618 * absoluteDeltaX) div 256 <= absoluteDeltaY);
      6: wasFound := (x2 <= x1) and ((106 * absoluteDeltaX) div 256 >= absoluteDeltaY);
    end;
    if not wasFound then
      Inc(d);
  end;
  DirectionBetween := d;
end;

function DirectionToward(src, dst: Types.PCharRecord): Byte;
begin
  DirectionToward := CbtMap.DirectionBetween(CbtMap.CombatCellX(src), CbtMap.CombatCellY(src), CbtMap.CombatCellX(dst),
                                             CbtMap.CombatCellY(dst));
end;

begin
end.
