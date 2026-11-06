{ Battle setup: builds the combat arena, from the surrounding map squares and their walls in a dungeon or from river,
  trees and scattered terrain in the wilderness, gives every creature a fresh combat record, and places the party and
  its enemies on the arena by spiraling outward from each side's base square. CombatStart is the entry point. }
{$O+,F+,S-,R-,V-,B-,I-}
unit CombatSt;

interface

{ Starts a battle: frees the pictures the exploration screens held, loads the combat sprites, resets the combat state,
  builds the arena, prepares and places every creature, centers the view on the party leader, shows the combat screen,
  and triggers each creature's start-of-combat effects. Note: the palette saved covers entries 64..95, but the restore
  writes 32..255 from the same buffer. }
procedure CombatStart;

implementation

uses CharGen, CbtActs, MenuCore, Portrait, View3D, FxEngine, CharHlp, CbtMap, MapTiles, GameIo, Blit, TextRend, Types,
  GDConsts, GDVars, C_Dir, C_Ifc, C_Npc, C_Status, C_Terr, C_Cond;

{ Sets one arena cell in the current dungeon cell's skewed six-by-five block, ignoring cells off the 50x25 arena.
  @param(i Column within the block.)
  @param(j Row within the block.)
  @param(t The terrain, stored plus 1.) }
procedure PlotCell(i, j, t: Byte);
var
  x: ShortInt;
  y: ShortInt;
begin
  x := GDVars.dx * 6 + GDVars.dy * 5 + 21 + i;
  y := GDVars.dy * 5 + 10 + j;
  if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then
    GDVars.arenaPtr^.cells[y, x] := t + 1;
end;

{ Classifies the edge between a map cell and its neighbor in a direction, from both sides. Off the map it is open on the
  party's row going east or west, otherwise blocked.
  @param(x Map column.)
  @param(y Map row.)
  @param(dir Direction of the neighbor.)
  @returns(0 open, 1 blocked, 3 a wall that can be passed; the two sides' bits combined.) }
function WallBetween(x, y: ShortInt; dir: Byte): Byte;
var
  nearKind: Byte;
  farKind: Byte;
  opp: Byte;

  { The wall kind on one side of a square; off the map, east and west on the party's row read open, else solid. }
  function GetWallKind(px, py: ShortInt; pdir: Byte): Byte;
  begin
    if (px >= 0) and (px <= 15) and (py >= 0) and (py <= 15) then begin
      if View3D.GetBarrierType(px, py, pdir) = 0 then
        GetWallKind := 1
      else if View3D.GetWallType(px, py, pdir) = 0 then
        GetWallKind := 0
      else
        GetWallKind := 3;
    end else begin
      if (py = GDVars.mapState.y) and ((pdir = C_Dir.EAST) or (pdir = C_Dir.WEST)) then
        GetWallKind := 0
      else
        GetWallKind := 1;
    end;
  end;

begin
  opp := (dir + 4) mod 8;
  nearKind := GetWallKind(x, y, dir);
  farKind := GetWallKind(x + GDConsts.dirDeltaX[dir], y + GDConsts.dirDeltaY[dir], opp);
  WallBetween := nearKind or farKind;
end;

{ Draw the dungeon arena: for each square in the 13 by 5 window around the party, find its walls and draw its floor,
  west and north walls, and both northern corners. }
procedure BuildDungeonArena;
var
  { the square being drawn, on the area map }
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  cellColumn: Byte;

  { Draws the cell's three floor rows and its west wall or door. }
  procedure DrawFloorWestWall;
  var
    c: Byte;
    r: Byte;
  begin
    for r := 2 to 4 do
      for c := 0 to 5 do
        CombatSt.PlotCell(c, r, 22);
    if GDVars.wallW = 1 then begin
      for r := 2 to 4 do begin
        CombatSt.PlotCell(r - 1, r, 4);
        CombatSt.PlotCell(r, r, 3);
        CombatSt.PlotCell(r + 1, r, 13);
      end;
    end else if GDVars.wallW = 3 then begin
      CombatSt.PlotCell(1, 2, 8);
      CombatSt.PlotCell(5, 4, 0);
    end;
  end;

  { Draws the current cell's north wall band (spots 3..4 on rows 0..1): wall terrain when solid, floor otherwise. }
  procedure DrawNorthWall;
  var
    { Unused in this version; see the other implementations of this routine. }
    column: Integer;
  begin
    if GDVars.wallN = 1 then begin
      CombatSt.PlotCell(3, 0, 5);
      CombatSt.PlotCell(4, 0, 5);
      CombatSt.PlotCell(3, 1, 10);
      CombatSt.PlotCell(4, 1, 10);
    end else begin
      CombatSt.PlotCell(3, 0, 22);
      CombatSt.PlotCell(4, 0, 22);
      CombatSt.PlotCell(3, 1, 22);
      CombatSt.PlotCell(4, 1, 22);
    end;
  end;

  { Fills the cell's northwest corner from its north and west walls and whether the edges beyond the corner are open. }
  procedure FillCornerNorthWest;
  var
    k: Byte;
    topLeftTile: Byte;
    bottomLeftTile: Byte;
    topRightTile: Byte;
    bottomRightTile: Byte;
    open: Byte;
  begin
    if (CombatSt.WallBetween(cellX, cellY - 1, C_Dir.WEST) = 0) and
        (CombatSt.WallBetween(cellX - 1, cellY, C_Dir.NORTH) = 0) then
      open := 1
    else
      open := 0;
    topLeftTile := 0;
    for k := 1 to 4 do
      case k of
        1: case GDVars.wallN of
             0: case GDVars.wallW of
                  0: topLeftTile := 22;
                  3, 1: if open <> 0 then topLeftTile := 0 else topLeftTile := 13;
                end;
             3, 1: if GDVars.wallW = 0 then begin
                     if open <> 0 then topLeftTile := 15 else topLeftTile := 5;
                   end else begin
                     if open <> 0 then topLeftTile := 18 else topLeftTile := 2;
                   end;
           end;
        2: case GDVars.wallN of
             0: topRightTile := 22;
             3: topRightTile := 17;
             1: topRightTile := 5;
           end;
        3: case GDVars.wallW of
             0: if GDVars.wallN = 0 then
                  bottomLeftTile := 22
                else if open <> 0 then
                  bottomLeftTile := 16
                else
                  bottomLeftTile := 10;
             3: if open <> 0 then bottomLeftTile := 20 else bottomLeftTile := 7;
             1: if open <> 0 then bottomLeftTile := 1 else bottomLeftTile := 3;
           end;
        4: case GDVars.wallW of
             0, 3: case GDVars.wallN of
                     0: bottomRightTile := 22;
                     3: bottomRightTile := 23;
                     1: bottomRightTile := 10;
                   end;
             1: case GDVars.wallN of
                  0: bottomRightTile := 13;
                  3: bottomRightTile := 21;
                  1: bottomRightTile := 6;
                end;
           end;
      end;
    CombatSt.PlotCell(1, 0, topLeftTile);
    CombatSt.PlotCell(2, 0, topRightTile);
    CombatSt.PlotCell(1, 1, bottomLeftTile);
    CombatSt.PlotCell(2, 1, bottomRightTile);
  end;

  { Fills the cell's northeast corner, which spills one spot into the next cell's block. }
  procedure FillCornerNorthEast;
  var
    k: Byte;
    topLeftTile: Byte;
    bottomLeftTile: Byte;
    topRightTile: Byte;
    bottomRightTile: Byte;
    open: Byte;
    kN: Byte;
    kE: Byte;
    { Unused in this version; see the other implementations of this routine. }
    cornerTile: array[0..1] of Byte;
  begin
    kN := CombatSt.WallBetween(cellX, cellY - 1, C_Dir.EAST);
    kE := CombatSt.WallBetween(cellX + 1, cellY, C_Dir.NORTH);
    if (kN = 0) and (kE = 0) then
      open := 1
    else
      open := 0;
    for k := 1 to 4 do
      case k of
        1: case GDVars.wallN of
             0: if kN = 1 then topLeftTile := 4 else topLeftTile := 22;
             3: topLeftTile := 15;
             1: topLeftTile := 5;
           end;
        2: if GDVars.wallN = 0 then begin
             case kN of
               0: topRightTile := 22;
               3: if (GDVars.wallE = 0) and (kE <> 0) then
                    topRightTile := 24
                  else if GDVars.wallE = 0 then
                    topRightTile := 7
                  else
                    topRightTile := 1;
               1: if GDVars.wallE = 0 then begin
                    if kE <> 0 then topRightTile := 11 else topRightTile := 7;
                  end else
                    topRightTile := 3;
             end;
           end else begin
             if GDVars.wallE <> 0 then
               topRightTile := 9
             else if kE <> 0 then
               topRightTile := 5
             else if open <> 0 then
               topRightTile := 17
             else
               topRightTile := 19;
           end;
        3: case GDVars.wallN of
             0: bottomLeftTile := 22;
             3: bottomLeftTile := 16;
             1: bottomLeftTile := 10;
           end;
        4: if GDVars.wallN = 0 then begin
             if kN = 0 then
               bottomRightTile := 22
             else if GDVars.wallE <> 0 then
               bottomRightTile := 4
             else if kE = 0 then
               bottomRightTile := 8
             else
               bottomRightTile := 12;
           end else begin
             if GDVars.wallE <> 0 then
               bottomRightTile := 14
             else if kE = 0 then
               bottomRightTile := 23
             else
               bottomRightTile := 10;
           end;
      end;
    CombatSt.PlotCell(5, 0, topLeftTile);
    CombatSt.PlotCell(6, 0, topRightTile);
    CombatSt.PlotCell(5, 1, bottomLeftTile);
    CombatSt.PlotCell(6, 1, bottomRightTile);
  end;

begin
  { 22 is the dungeon floor }
  FillChar(GDVars.arenaPtr^.cells, SizeOf(GDVars.arenaPtr^.cells), 22);
  for GDVars.dy := -2 to 2 do
    for GDVars.dx := -6 to 6 do begin
      cellX := GDVars.mapState.x + GDVars.dx;
      cellY := GDVars.mapState.y + GDVars.dy;
      GDVars.wallW := CombatSt.WallBetween(cellX, cellY, C_Dir.WEST);
      GDVars.wallN := CombatSt.WallBetween(cellX, cellY, C_Dir.NORTH);
      GDVars.wallE := CombatSt.WallBetween(cellX, cellY, C_Dir.EAST);
      GDVars.wallS := CombatSt.WallBetween(cellX, cellY, C_Dir.SOUTH);
      DrawFloorWestWall;
      DrawNorthWall;
      FillCornerNorthWest;
      FillCornerNorthEast;
    end;
end;

{ Looks up the class bits of the current terrain type, which steer the wilderness arena generators.
  @returns(The class bits.) }
function TerrainClassOf: Byte;
begin
  TerrainClassOf := GDConsts.terrainClassByChar[GDVars.terrainChar];
end;

{ Lays a diagonal band of river tiles down the arena when the area calls for a river, crossed by fords at random rows;
  the chance of a ford grows with each row that has none. }
procedure PlaceRiver;
var
  { the chance of a ford, out of 20 }
  fordVal: Byte;
  { Unused in this version; see the other implementations of this routine. }
  startCol: ShortInt;
  { the river's first column on this row }
  col: ShortInt;
  { the row being drawn }
  row: ShortInt;

  { Draw a ford across the river at (col, row) and reset the ford chance. }
  procedure PlotFord(col, row: ShortInt);
  begin
    GDVars.arenaPtr^.cells[row, col] := 58;
    if col < 49 then begin
      GDVars.arenaPtr^.cells[row, col + 1] := FxEngine.RollDice(1, 2) + 58;
      if col + 1 < 49 then
        GDVars.arenaPtr^.cells[row, col + 2] := FxEngine.RollDice(1, 2) + 58;
      if col + 2 < 49 then
        GDVars.arenaPtr^.cells[row, col + 3] := 61;
    end;
    fordVal := 1;
  end;

begin
  if GDVars.vmBand.zone0^.placeRiver <> 0 then begin
    col := 34 - FxEngine.RollDice(5, 4);
    while (col + 2) mod 7 > 0 do
      Dec(col);
    startCol := col;
    fordVal := 1;
    for row := 0 to 24 do begin
      if col <= 49 then begin
        GDVars.arenaPtr^.cells[row, col] := 52;
        if col < 49 then begin
          if FxEngine.RollDice(1, 20) <= fordVal then
            PlotFord(col + 1, row)
          else begin
            Inc(fordVal);
            GDVars.arenaPtr^.cells[row, col + 1] := FxEngine.RollDice(1, 2) + 52;
            if col + 1 < 49 then
              GDVars.arenaPtr^.cells[row, col + 2] := 55;
            if col + 2 < 49 then
              GDVars.arenaPtr^.cells[row, col + 3] := 55;
            if col + 3 < 49 then
              GDVars.arenaPtr^.cells[row, col + 4] := FxEngine.RollDice(1, 2) + 55;
          end;
        end;
        if col + 4 < 49 then
          GDVars.arenaPtr^.cells[row, col + 5] := 52;
        Inc(col);
      end;
    end;
  end;
end;

{ Unless the terrain class has bit 7 set, replaces some vertical pairs of open-ground cells (tile 37) with features, at
  a chance the class raises or lowers. }
procedure PlaceTrees;
var
  { Unused in this version; see the other implementations of this routine. }
  roll: Byte;
  { the arena column }
  col: ShortInt;
  { the arena row }
  row: ShortInt;
  { the tree chance, in percent; signed, since the class bits can take it below zero }
  dens: ShortInt;
begin
  if CombatSt.TerrainClassOf and $80 <> 0 then Exit;
  dens := 5;
  if CombatSt.TerrainClassOf and 2 <> 0 then Dec(dens, 3);
  if CombatSt.TerrainClassOf and 4 <> 0 then Dec(dens, 3);
  if CombatSt.TerrainClassOf and $40 <> 0 then Inc(dens, 2);
  if CombatSt.TerrainClassOf and 8 <> 0 then Inc(dens, 5);
  if dens < 0 then dens := 1;
  for col := 0 to 49 do
    for row := 1 to 24 do
      if GDConsts.terrainTable[GDVars.arenaPtr^.cells[row, col]].tileId = 37 then
        if GDConsts.terrainTable[GDVars.arenaPtr^.cells[row - 1, col]].tileId = 37 then
          if FxEngine.RollDice(1, 100) <= dens then begin
            if FxEngine.RollDice(1, 100) <= dens then
              GDVars.arenaPtr^.cells[row, col] := FxEngine.RollDice(1, 2) + 41
            else begin
              GDVars.arenaPtr^.cells[row - 1, col] := FxEngine.RollDice(1, 5) + 31;
              GDVars.arenaPtr^.cells[row, col] := FxEngine.RollDice(1, 5) + 36;
            end;
          end;
end;

{ Scatters decorative terrain over open ground, the mix chosen by terrain class: five feature kinds by percentage
  chances. Note: the third kind's band is always 1 percent wide, and its chance widens the fourth kind's band instead. }
procedure ScatterFeatures;
var
  { the arena column }
  col: ShortInt;
  { the arena row }
  row: ShortInt;
  { the terrain score, 50 adjusted by the class bits; picks the feature mix }
  accum: Integer;

  { Places one of five feature kinds at a cell, or none, by percentage chances; the third band is always 1% wide. }
  procedure ScatterOneCell(col, row: ShortInt; firstChance, secondChance, thirdChance, fourthChance, fifthChance: Byte);
  var
    { the percentage roll }
    r: Byte;
  begin
    r := FxEngine.RollDice(1, 100);
    if r <= firstChance then
      GDVars.arenaPtr^.cells[row, col] := FxEngine.RollDice(1, 2) + 49
    else if r <= firstChance + secondChance then
      GDVars.arenaPtr^.cells[row, col] := 44
    else if r <= firstChance + secondChance + 1 then
      GDVars.arenaPtr^.cells[row, col] := FxEngine.RollDice(1, 5) + 44
    else if r <= firstChance + secondChance + thirdChance + fourthChance then
      GDVars.arenaPtr^.cells[row, col] := 68
    else if r <= firstChance + secondChance + thirdChance + fourthChance + fifthChance then
      GDVars.arenaPtr^.cells[row, col] := FxEngine.RollDice(1, 6) + 61;
  end;

begin
  accum := 50;
  if CombatSt.TerrainClassOf and $10 <> 0 then Inc(accum, 10);
  if CombatSt.TerrainClassOf and $20 <> 0 then Inc(accum, 30);
  if CombatSt.TerrainClassOf and $40 <> 0 then Inc(accum, 20);
  if CombatSt.TerrainClassOf and 4 <> 0 then Dec(accum, 10);
  if CombatSt.TerrainClassOf and 2 <> 0 then Dec(accum, 20);
  if CombatSt.TerrainClassOf and $80 <> 0 then Dec(accum, 50);
  for col := 0 to 49 do
    for row := 0 to 24 do
      if GDConsts.terrainTable[GDVars.arenaPtr^.cells[row, col]].tileId = 37 then
        case accum of
          -30..9: ScatterOneCell(col, row, 0, 0, 0, 30, 15);
          10..29: ScatterOneCell(col, row, 0, 1, 5, 20, 10);
          30..69: ScatterOneCell(col, row, 0, 2, 5, 10, 5);
          70..89: ScatterOneCell(col, row, 10, 2, 10, 10, 1);
          90..110: ScatterOneCell(col, row, 15, 5, 15, 10, 1);
        end;
end;

{ Fills the arena with wilderness ground, then adds the river, the trees and the scattered features. The terrain under
  the party is always taken as terrain 15. }
procedure BuildWildernessArena;
var
  { Unused in this version; see the other implementations of this routine. }
  mapX: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mapY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mapIndex: array[0..1] of Byte;
begin
  FillChar(GDVars.arenaPtr^.cells, SizeOf(GDVars.arenaPtr^.cells), 69);
  mapX := GDVars.vmBand.zone0^.raw[$C3];
  mapY := GDVars.vmBand.zone0^.raw[$C4];
  GDVars.terrainChar := 15;
  CombatSt.PlaceRiver;
  CombatSt.PlaceTrees;
  CombatSt.ScatterFeatures;
end;

{ Load the combat tile set, the dungeon's chosen by the current wall set and the wilderness's by the area's tile set;
  then allocate the arena and build it. }
procedure LoadCombatTileSet;
var
  { the wilderness tile set, 0 unless the area's is 1 or 2 }
  slot: Byte;
begin
  if GDVars.vmBand.zone0^.inDungeon <> 0 then
    MapTiles.Load24x24Set('DungCom', Lo(GDVars.loadedWallSet.id), 0, 25)
  else begin
    if GDVars.vmBand.zone0^.tileSet in [1, 2] then
      slot := GDVars.vmBand.zone0^.tileSet
    else
      slot := 0;
    MapTiles.Load24x24Set('WildCom', slot, 0, 39);
  end;
  GetMem(GDVars.arenaPtr, SizeOf(Types.TCombatMap));
  GDVars.arenaPtr^.cursorOn := False;
  GDVars.arenaPtr^.cursorSize := 1;
  GDVars.arenaPtr^.noHeight := 0;
  if GDVars.vmBand.zone0^.inDungeon <> 0 then
    CombatSt.BuildDungeonArena
  else
    CombatSt.BuildWildernessArena;
end;

{ Give every creature on the roster a fresh combat record, facing the party's way (the other side facing back).
  Creatures past the party count are marked as not party members; such a creature on the party's side without a valid
  morale takes the party size as its morale. }
procedure InitCreatureCombatData;
var
  p: Types.PCharRecord;
  { roster position, from 1 }
  count: Byte;
  { the creature's morale }
  m: Byte;
begin
  p := GDVars.creatureListHead;
  count := 0;
  while p <> nil do begin
    CharHlp.RecalcStats(p);
    Inc(count);
    GetMem(p^.combatAddr, SizeOf(Types.TCombatRec));
    GameIo.ZeroFill(p^.combatAddr^, SizeOf(Types.TCombatRec));
    if count > GDVars.vmBand.zone0^.partySize then
      p^.combatAddr^.notPcNpc := 1;
    p^.combatAddr^.direction := GDConsts.quadDir[GDVars.mapState.facing div 2];
    if p^.side = 1 then
      p^.combatAddr^.direction := (p^.combatAddr^.direction + 4) mod 8;
    m := p^.npc and C_Npc.MORALE_MASK;
    if (p^.side = 0) and (p^.combatAddr^.notPcNpc = 1) and ((m = 0) or (m > 102)) then
      p^.npc := GDVars.vmBand.zone0^.partySize + C_Npc.NON_PLAYER;
    p^.combatAddr^.initialized := 1;
    p := p^.next;
  end;
end;

{ Tells whether a placement square lies off the 11x6 grid on both axes.
  @param(qx The square's column.)
  @param(qy The square's row.)
  @returns(True when both coordinates are off the grid.) }
function QuadFullyOff(qx, qy: ShortInt): Boolean;
begin
  if ((qx >= 0) and (qx < 11)) or ((qy >= 0) and (qy < 6)) then
    QuadFullyOff := False
  else
    QuadFullyOff := True;
end;

{ Tries to put a creature on a placement square of its team's grid for one ring. The square must be on the grid and
  free; its arena cell, from the same skewed mapping as the dungeon builder, is stored before the probe, and the cell
  must hold no creature and passable terrain.
  @param(slot The creature's combat slot.)
  @param(qx The square's column.)
  @param(qy The square's row.)
  @param(bqx The grid's base column.)
  @param(bqy The grid's base row.)
  @param(ring The placement ring, 0 to 3.)
  @returns(1 when the creature was placed, which takes the square; 0 otherwise.) }
function TryPlaceAt(slot: Byte; qx, qy, bqx, bqy: ShortInt; ring: Byte): Byte;
var
  { ProbeDirection's cloud or barrier terrain, not needed here }
  adjSpecial: Byte;
  { the combatant already on the spot, 0 for none }
  crIdx: Byte;
  { the terrain on the spot }
  terrIdx: Byte;
begin
  if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) or (GDVars.quadFree[GDVars.team, ring, qy, qx] = 0) then
    TryPlaceAt := 0
  else begin
    GDVars.arenaSlots[slot].x := qx + bqx * 6 + bqy * 5 + 22;
    GDVars.arenaSlots[slot].y := qy + bqy * 5 + 10;
    CbtMap.ProbeDirection(GDVars.slotCreatures[slot], C_Dir.CENTER, crIdx, terrIdx, adjSpecial);
    if (crIdx = 0) and (terrIdx > 0) and (GDConsts.terrainTable[terrIdx].cost < C_Terr.TERRAIN_IMPASSABLE) then begin
      TryPlaceAt := 1;
      GDVars.quadFree[GDVars.team, ring, qy, qx] := 0;
    end else
      TryPlaceAt := 0;
  end;
end;

{ Searches the team's placement grid for a square for a creature, in zigzag legs from the ring's start square. A leg
  ends at a square partly off the grid or after a set number of tries, and the next leg starts a step further back; for
  team 0 facing diagonally, ring 0's first step back is doubled when any of the ring's three directions is not walled
  off (always outdoors). A square fully off the grid moves on to the next ring whose direction is not walled off (always
  outdoors), up to ring 3.
  @param(slot The creature's combat slot.)
  @returns(True when the creature was placed; False when no ring is left.) }
function FindPlacement(slot: Byte): Boolean;
var
  { 1 once the creature is placed }
  placed: Byte;
  { 1 until the first leg sequence is used up }
  firstPass: Byte;
  { 1 when every ring is used up }
  giveUp: Byte;
  { 1 when the cell being tried is off the grid }
  offGrid: Byte;
  { 1 when a way out of the base square is open }
  open: Byte;
  { 1 start a leg; 2 and 3 step along it }
  state: Byte;
  { the direction from the base toward the next ring }
  dir: Byte;
  { the quarter the spiral starts in }
  quad: Byte;
  { loop counter }
  k: Byte;
  { the step along the current leg, x }
  stepX: ShortInt;
  { the step along the current leg, y }
  stepY: ShortInt;
  { the team base on the area map, x }
  wallX: ShortInt;
  { the team base on the area map, y }
  wallY: ShortInt;
  { how far the leg start has moved out }
  legShift: Byte;
  { the current leg length }
  legLen: Byte;
  { the ring's base square, x }
  baseQuadX: ShortInt;
  { the ring's base square, y }
  baseQuadY: ShortInt;
  { cells tried in this leg sequence }
  tries: Byte;
  { 0 the team base; 1..3 the neighboring squares }
  ring: Byte;
  { the leg's starting cell, x }
  legX: ShortInt;
  { the leg's starting cell, y }
  legY: ShortInt;
  { the cell being tried, x }
  qx: ShortInt;
  { the cell being tried, y }
  qy: ShortInt;
begin
  firstPass := 1;
  giveUp := 0;
  state := 1;
  legShift := 0;
  ring := 0;
  baseQuadX := GDVars.placeX[GDVars.team];
  baseQuadY := GDVars.placeY[GDVars.team];
  repeat
    quad := GDConsts.ringStart[GDVars.teamDir[GDVars.team], ring] div 2;
    case state of
      1: begin
           stepX := GDConsts.dirDeltaX[GDConsts.quadDir[(quad + 2) mod 4]];
           stepY := GDConsts.dirDeltaY[GDConsts.quadDir[(quad + 2) mod 4]];
           legX := GDConsts.startQuadX[ring > 0, quad] + stepX * legShift;
           legY := GDConsts.startQuadY[ring > 0, quad] + stepY * legShift;
           qx := legX;
           qy := legY;
           legLen := 1;
           state := 2;
           tries := 1;
         end;
      2: begin
           stepX := GDConsts.dirDeltaX[GDConsts.quadDir[(quad + 1) mod 4]];
           stepY := GDConsts.dirDeltaY[GDConsts.quadDir[(quad + 1) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 3;
           Inc(tries);
         end;
      3: begin
           stepX := GDConsts.dirDeltaX[GDConsts.quadDir[(quad + 3) mod 4]];
           stepY := GDConsts.dirDeltaY[GDConsts.quadDir[(quad + 3) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 2;
           Inc(legLen);
           Inc(tries);
         end;
    end;
    if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) then
      offGrid := 1
    else
      offGrid := 0;
    if state > 1 then begin
      if ((offGrid <> 0) and (not CombatSt.QuadFullyOff(qx,
                                                        qy))) or ((firstPass <> 0) and
                                                                  (tries >= GDVars.teamRows[GDVars.team])) or
          ((firstPass = 0) and (tries > 11)) then begin
        Inc(legShift);
        if (GDVars.team = 0) and Odd(GDVars.teamDir[0]) and (ring = 0) and (legShift = 1) then begin
          wallX := GDVars.placeX[GDVars.team] + GDVars.mapState.x;
          wallY := GDVars.placeY[GDVars.team] + GDVars.mapState.y;
          open := 0;
          for k := 1 to 3 do begin
            dir := GDConsts.ringDirTbl[GDVars.teamDir[GDVars.team], k];
            if (GDVars.interfaceState = C_Ifc.AREA_MAP) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then
              open := 1;
          end;
          if open <> 0 then
            Inc(legShift);
        end;
        state := 1;
        firstPass := 0;
      end;
    end;
    if (offGrid <> 0) and CombatSt.QuadFullyOff(qx, qy) then begin
      placed := 0;
      state := 0;
      while (ring < 3) and (state <> 1) do begin
        Inc(ring);
        wallX := GDVars.placeX[GDVars.team] + GDVars.mapState.x;
        wallY := GDVars.placeY[GDVars.team] + GDVars.mapState.y;
        dir := GDConsts.ringDirTbl[GDVars.teamDir[GDVars.team], ring];
        if (GDVars.interfaceState = C_Ifc.AREA_MAP) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then begin
          baseQuadX := GDVars.placeX[GDVars.team] + GDConsts.dirDeltaX[dir];
          baseQuadY := GDVars.placeY[GDVars.team] + GDConsts.dirDeltaY[dir];
          legShift := 0;
          state := 1;
        end;
      end;
      if state <> 1 then
        giveUp := 1;
    end;
    if offGrid = 0 then
      placed := CombatSt.TryPlaceAt(slot, qx, qy, baseQuadX, baseQuadY, ring);
  until (placed <> 0) or (giveUp <> 0);
  if giveUp <> 0 then
    FindPlacement := False
  else
    FindPlacement := True;
end;

{ Place every creature on the arena. Each roster member gets a combat slot and a spot found by FindPlacement; enemies
  are spread over the directions in GDVars.hostileDirections, encounterDist squares away (or 1 when that is 0 and the
  facing has been turned). A creature outside the party that cannot be placed is removed from the battle, and a downed
  party member leaves a body on the arena. The party's facing is restored at the end. }
procedure PlaceAllCreatures;
var
  prev: Types.PCharRecord;
  p: Types.PCharRecord;
  slot: Byte;
  d: Byte;
  placedCnt: Byte;
  removedCnt: Byte;
  savedFacing: Byte;
  lastFacingCache: Byte;
  rotIdx: Byte;
  x: ShortInt;
  y: ShortInt;
  dirTmp: Byte;
  rotCount: Byte;
  placedResult: Boolean;

  { Sets both teams' bases, facings and free placement cells for the current facing, unless already set for it. }
  procedure PrepareCombatOccupancy;
  var
    g: Byte;
    x: ShortInt;
    y: ShortInt;
    dist: Byte;
    { Unused in this version; see the other implementations of this routine. }
    plane: array[0..1] of Byte;
  begin
    if (GDVars.vmBand.zone0^.encounterDist = 0) and (GDVars.mapState.facing <> savedFacing) then
      dist := 1
    else
      dist := GDVars.vmBand.zone0^.encounterDist;
    if GDVars.mapState.facing = lastFacingCache then Exit;
    lastFacingCache := GDVars.mapState.facing;
    GDVars.teamDir[0] := GDVars.mapState.facing div 2;
    GDVars.placeX[1] := GDConsts.dirDeltaX[GDVars.mapState.facing] * dist + GDVars.placeX[0];
    GDVars.placeY[1] := GDConsts.dirDeltaY[GDVars.mapState.facing] * dist + GDVars.placeY[0];
    GDVars.teamDir[1] := (GDVars.mapState.facing + 4) mod 8 div 2;
    for GDVars.team := 0 to 1 do
      for g := 0 to 3 do begin
        if g = 1 then d := 4 else d := GDVars.teamDir[GDVars.team];
        for y := 0 to 5 do
          for x := 0 to 10 do
            if (GDConsts.rowBand[d, y].lo > x) or (GDConsts.rowBand[d, y].hi < x) then
              GDVars.quadFree[GDVars.team, g, y, x] := 0
            else
              GDVars.quadFree[GDVars.team, g, y, x] := 1;
      end;
  end;

begin
  savedFacing := GDVars.mapState.facing;
  lastFacingCache := $FF;
  rotIdx := 0;
  CharHlp.CountTeams;
  removedCnt := 0;
  placedCnt := 0;
  for slot := 1 to 72 do
    GDVars.arenaSlots[slot].sizeCode := 0;
  FillChar(GDVars.arenaCellSlot, SizeOf(GDVars.arenaCellSlot), 0);
  GDVars.placeX[0] := 0;
  GDVars.placeY[0] := 0;
  GDVars.teamRows[0] := (GDVars.teamCount[0] + 1) div 2;
  rotCount := 0;
  if GDVars.hostileDirections and $F = 0 then
    Inc(rotCount)
  else begin
    if GDVars.hostileDirections and 1 <> 0 then Inc(rotCount);
    if GDVars.hostileDirections and 2 <> 0 then Inc(rotCount);
    if GDVars.hostileDirections and 4 <> 0 then Inc(rotCount);
    if GDVars.hostileDirections and 8 <> 0 then Inc(rotCount);
  end;
  rotCount := rotCount * 2;
  GDVars.teamRows[1] := (GDVars.teamCount[1] + rotCount - 1) div rotCount;
  PrepareCombatOccupancy;
  slot := 1;
  GDVars.arenaCount := 1;
  prev := GDVars.creatureListHead;
  p := GDVars.creatureListHead;
  while p <> nil do begin
    GameIo.DiscardPendingKeys;
    GDVars.slotCreatures[slot] := p;
    GDVars.team := p^.side;
    GDVars.arenaSlots[slot].aux := slot;
    GDVars.arenaSlots[slot].sizeCode := p^.iconDimensions and 7;
    if GDVars.hostileDirections <> 0 then begin
      if p^.side = 0 then
        GDVars.mapState.facing := savedFacing
      else begin
        repeat
          rotIdx := (rotIdx + 1) and 3;
        until Byte((1 shl rotIdx) and GDVars.hostileDirections) <> 0;
        GDVars.mapState.facing := rotIdx * 2;
      end;
      PrepareCombatOccupancy;
    end;
    dirTmp := GDVars.mapState.facing;
    if p^.side = 1 then
      dirTmp := (dirTmp + 4) mod 8;
    p^.combatAddr^.direction := GDConsts.quadDir[dirTmp div 2];
    placedResult := CombatSt.FindPlacement(slot);
    if placedResult then begin
      prev := p;
      if p^.inPlay = 0 then begin
        GDVars.arenaSlots[slot].sizeCode := 0;
        if (p^.combatAddr^.notPcNpc = 0) and (p^.status <> C_Status.GONE) then begin
          x := GDVars.arenaSlots[slot].x;
          y := GDVars.arenaSlots[slot].y;
          Inc(GDVars.downedListCount);
          GDVars.downedList[GDVars.downedListCount].terrain := CbtMap.ResolveTerrain(x, y);
          GDVars.arenaPtr^.cells[y, x] := C_Terr.TERRAIN_CORPSE;
          GDVars.downedList[GDVars.downedListCount].cr := p;
          GDVars.downedList[GDVars.downedListCount].x := x;
          GDVars.downedList[GDVars.downedListCount].y := y;
        end;
      end;
      if p^.status = 9 then begin
        p^.inPlay := 0;
        GDVars.arenaSlots[slot].sizeCode := 0;
      end;
      CbtMap.BuildArenaArrays;
      Inc(slot);
      Inc(GDVars.arenaCount);
      Inc(placedCnt);
    end else begin
      GDVars.arenaSlots[slot].sizeCode := 0;
      if p^.combatAddr^.notPcNpc = 1 then begin
        Inc(removedCnt);
        GDVars.slotCreatures[slot] := nil;
        GDVars.currentChar := p;
        CharGen.RemoveCreature(True, False);
        p := prev;
      end else begin
        prev := p;
        Inc(slot);
        Inc(GDVars.arenaCount);
      end;
    end;
    p := p^.next;
  end;
  prev^.next := nil;
  GDVars.mapState.facing := savedFacing;
end;

procedure CombatStart;
var
  { Counts the sprite frames loaded. }
  spriteFrame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedFlags: array[1..9] of Byte;
  p: Types.PCharRecord;
begin
  GDVars.msgDelayFlag := False;
  Portrait.FreeAnimation;
  GDVars.palettePresetOn := 0;
  Blit.FreePic(GDVars.bigPicImage);
  Blit.FreePic(GDVars.backdropPicture);
  Blit.FreePic(GDVars.skyPicture);
  GDVars.curSkyId := 0;
  GameIo.ZeroFill(GDVars.backdropPicture, SizeOf(GDVars.backdropPicture) + SizeOf(GDVars.skyPicture));
  for spriteFrame := 0 to 21 do
    MapTiles.LoadIconAnim('COMSPR', spriteFrame, spriteFrame + 13);
  Blit.ShadowPaletteEntries(64, 32, GDVars.backupPal);
  Blit.AllocPic(24, 3, 39, 0, GDVars.mapTileSheet);
  GDVars.bigPicId := $FF;
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, 10, 0, 'A battle begins...');
  GDVars.quickMagic := 0;
  GDVars.combatRound := 0;
  GDVars.fightEndRound := 15;
  GDVars.lastAttackRoll := 0;
  GDVars.downedListCount := 0;
  GDVars.cellPatchList := nil;
  GDVars.lastMissileItem := nil;
  GameIo.ZeroFill(GDVars.downedList, SizeOf(GDVars.downedList));
  GDVars.vmBand.zone0^.alliesAttacked := 0;
  CombatSt.LoadCombatTileSet;
  GameIo.DiscardPendingKeys;
  CombatSt.InitCreatureCombatData;
  GameIo.DiscardPendingKeys;
  CombatSt.PlaceAllCreatures;
  GameIo.DiscardPendingKeys;
  Blit.AllocPic(24, 3, 4, 1, GDVars.moveIconSheet);
  GDVars.arenaPtr^.ox := CbtMap.CombatCellX(GDVars.creatureListHead) - 3;
  GDVars.arenaPtr^.oy := CbtMap.CombatCellY(GDVars.creatureListHead) - 3;
  CharHlp.DisplayCombatInterface;
  p := GDVars.creatureListHead;
  Blit.SetDacPalette(32, 224, GDVars.backupPal);
  while p <> nil do begin
    p^.combatAddr^.turnAttempts := 0;
    FxEngine.TriggerEffectsWithCondition(C_Cond.COMBAT_START, p);
    p := p^.next;
  end;
  CbtActs.UpdateHostileHpPercent;
  GDVars.manualMoveActive := 0;
  GDVars.aimCursorOn := 0;
  GDVars.interfaceState := C_Ifc.IN_COMBAT;
  GDVars.clickInputMode := 0;
  p := GDVars.creatureListHead;
  GDVars.spellBeingCast := 0;
end;

begin
end.
