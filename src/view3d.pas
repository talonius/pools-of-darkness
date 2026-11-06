{ 3D dungeon-view renderer and GEO/WALLDEF resource loader. }
{$O+,F+,S-,R-,V-,B-,I-}
unit View3D;

interface

uses Blit, DaxIo, ZeroFree, GameIo, Sym8x8, Types, GDConsts, GDVars, C_Dir;

{ Stores the four 3D view band colors: sky, the two horizon bands and floor.
  @param(newSkyColor The sky color.)
  @param(newHorizonColor1 The first horizon band's color.)
  @param(newHorizonColor2 The second horizon band's color.)
  @param(newFloorColor The floor color.) }
procedure SetView3DColors(newSkyColor, newHorizonColor1, newHorizonColor2, newFloorColor: Byte);

{ Reads the wall type on one side of a cell: north and east share one map plane and south and west another, one nibble
  each. Off-map coordinates wrap around the 16x16 map, except in scripts 0 and 80, where they give 0.
  @param(x The map column.)
  @param(y The map row.)
  @param(facing The side, one of the four compass points.)
  @returns(The wall type, 0 for none. Note: a facing other than the four compass points leaves it undefined.) }
function GetWallType(x, y: ShortInt; facing: Byte): Byte;

{ Reads the barrier on one side of a cell. Off the 16x16 map it returns 0 while script 0 or 80 is loaded, and otherwise
  wraps around the edges.
  @param(x The map column.)
  @param(y The map row.)
  @param(facing The side, one of the four compass points.)
  @returns(The two-bit barrier type of the wall there, or 1 when there is no wall.) }
function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;

{ Reads a cell's event from the 3D map. Off the 16x16 map it returns 0 while script 0 or 80 is loaded, and otherwise
  wraps around the edges.
  @param(x The map column.)
  @param(y The map row.)
  @returns(The cell event.) }
function GetMapEvent(x, y: ShortInt): Byte;

{ Draws the party's view: the automap when it is on, otherwise the backdrop and then the front and side walls from two
  cells ahead back to the party's own cell, finishing with any pending sky or backdrop palette.
  @param(x The party's map column.)
  @param(y The party's map row.)
  @param(facing The direction the party faces; not range-checked.) }
procedure Display3DMapView(x, y: ShortInt; facing: Byte);

{ Loads the wall definitions of a WALLDEF1.DAX resource into the wall-set slots after wallSetSlot, along with the
  matching 8x8 symbol set and backdrop image, and remembers which set is loaded. A wallSetSlot above 3 does nothing. A
  missing resource, or one too large for the remaining slots, is a fatal error reported in text mode. Note: a resource
  whose size is not a multiple of a wall definition's size passes the size check; the final Move then reads past the
  data and can write past GDVars.wallGfx.
  @param(resourceId The resource, also the symbol set's and backdrop's picture number.)
  @param(wallSetSlot The slot the definitions follow, 0..3; also the symbol set loaded.) }
procedure LoadWallSet(resourceId, wallSetSlot: Byte);

{ Loads a GEO1.DAX map -- the two wall planes, the event plane and the barrier plane after a two-byte header -- and
  records it as the loaded map. A missing or wrongly sized resource is a fatal error reported in text mode.
  @param(mapId The map's resource number.) }
procedure Load3DMap(mapId: Byte);

implementation

const
  { GDVars.mapState.event's flag: the cell shows the backdrop picture instead of the sky }
  BACKDROP_EVENT_MASK = $80;

procedure LoadBackdrop(imageId: Byte); forward;

{ Draws the overhead automap: an 11 x 11 window of wall symbols around the party, kept on the map, with the party's
  facing arrow on top.
  @param(x The party's map column.)
  @param(y The party's map row.)
  @param(facing The party's facing.) }
procedure DrawAutoMap(x, y: ShortInt; facing: Byte);
var
  partyMapX: ShortInt;
  partyMapY: ShortInt;
  worldX: ShortInt;
  worldY: ShortInt;
  mapOriginX: ShortInt;
  mapOriginY: ShortInt;
  mapX: ShortInt;
  mapY: ShortInt;
  mapSymbol: Word;
  { Unused in this version; see the other implementations of this routine. }
  symbolText: String;
begin
  mapOriginX := x - 5;
  if mapOriginX < 0 then mapOriginX := 0;
  if mapOriginX > 5 then mapOriginX := 5;
  partyMapX := x - mapOriginX;
  mapOriginY := y - 5;
  if mapOriginY < 0 then mapOriginY := 0;
  if mapOriginY > 5 then mapOriginY := 5;
  partyMapY := y - mapOriginY;
  for worldY := 0 to 10 do begin
    mapY := worldY + mapOriginY;
    for worldX := 0 to 10 do begin
      mapX := worldX + mapOriginX;
      mapSymbol := 256;
      if View3D.GetWallType(mapX, mapY, C_Dir.NORTH) > 0 then Inc(mapSymbol, 1);
      if View3D.GetWallType(mapX, mapY, C_Dir.EAST) > 0 then Inc(mapSymbol, 2);
      if View3D.GetWallType(mapX, mapY, C_Dir.SOUTH) > 0 then Inc(mapSymbol, 4);
      if View3D.GetWallType(mapX, mapY, C_Dir.WEST) > 0 then Inc(mapSymbol, 8);
      Sym8x8.Put8x8Sym(worldX + 3 - 1,
                       worldY + 3 - 1, mapSymbol, True, False);
    end;
  end;
  Sym8x8.Put8x8Sym(partyMapX + 3 - 1,
                   partyMapY + 3 - 1, facing div 2 + 272,
                   True, False);
  Blit.FlushView;
end;

procedure SetView3DColors(newSkyColor, newHorizonColor1, newHorizonColor2, newFloorColor: Byte);
begin
  GDVars.viewSkyColor := newSkyColor;
  GDVars.viewHorizonColor1 := newHorizonColor1;
  GDVars.viewHorizonColor2 := newHorizonColor2;
  GDVars.viewFloorColor := newFloorColor;
end;

{ Fill the sky, horizon and floor, then draw over them either the wall set's backdrop image, when the current map event
  has BACKDROP_EVENT_MASK set, or the sky picture chosen by tile set, hour of day and sky variant. Switching between the
  two marks the palette dirty, so Display3DMapView loads the matching one. }
procedure DrawBackdrop;
var
  { Unused in this version; see the other implementations of this routine. }
  hourOfDay: Word;
  imageX: Byte;
  imageY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  columnWidth: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rowHeight: Byte;
begin
  Blit.FillPicRect(2, 16, 11, 44, GDVars.viewSkyColor, GDConsts.standardColorMap, GDVars.viewImageBuf);
  Blit.FillPicRect(2, 60, 11, 2, GDVars.viewHorizonColor2, GDConsts.standardColorMap,
                   GDVars.viewImageBuf);
  Blit.FillPicRect(2, 62, 11, 42, GDVars.viewFloorColor, GDConsts.standardColorMap,
                   GDVars.viewImageBuf);
  imageX := 2;
  imageY := 2;
  columnWidth := 12;
  rowHeight := 12;
  if (GDVars.mapState.event and View3D.BACKDROP_EVENT_MASK) <> 0 then begin
    if GDVars.backdropPicture = nil then
      View3D.LoadBackdrop(Lo(GDVars.loadedWallSet.id));
    Blit.BlitTileClipped(imageX, imageY, 0, 0, GDVars.backdropPicture, GDVars.viewImageBuf);
    if not GDVars.backdropPalActive then begin
      GDVars.viewPaletteDirty := True;
      GDVars.backdropPalActive := True;
    end;
  end else begin
    GDVars.prevSkyId := GDVars.curSkyId;
    GDVars.curSkyId := 1;
    if GDVars.vmBand.zone0^.tileSet in [0, 4] then begin
      if GDVars.vmBand.zone0^.clock[3] >= 14 then
        GDVars.curSkyId := 2
      else if GDVars.vmBand.zone0^.skyVariant <> 0 then
        GDVars.curSkyId := 3;
    end else
      GDVars.curSkyId := 4;
    if GDVars.prevSkyId <> GDVars.curSkyId then begin
      Blit.FreePic(GDVars.skyPicture);
      Blit.LoadPic('skygrnd', GDVars.curSkyId, 0, 13, GDVars.skyPicture);
      Blit.ShadowPaletteEntries(144, 32, GDVars.skyPal);
      GDVars.backdropPalActive := True;
    end;
    if GDVars.backdropPalActive then begin
      GDVars.viewPaletteDirty := True;
      GDVars.backdropPalActive := False;
    end;
    Blit.BlitTileClipped(imageX, imageY, 0, 0, GDVars.skyPicture, GDVars.viewImageBuf);
  end;
end;

{ Draws a wall in one perspective form, its width by its height in symbols, clipped to the 11x11 view; symbol 0 is left
  transparent.
  @param(x The view column of its top left symbol.)
  @param(y The view row of its top left symbol.)
  @param(wallType The wall type, an index into the loaded wall graphics.)
  @param(slot The perspective form.) }
procedure DrawWallSlice(x, y: ShortInt; wallType, slot: Byte);
var
  lastColumn: Integer;
  lastRow: Integer;
  col: Integer;
  row: Integer;
  sliceIndex: Byte;
begin
  sliceIndex := GDConsts.viewSlices.startSymbol[slot];
  lastColumn := GDConsts.viewSlices.columns[slot] + x - 1;
  lastRow := GDConsts.viewSlices.rows[slot] + y - 1;
  for row := y to lastRow do
    for col := x to lastColumn do begin
      if (row >= 0) and (row <= 10) and (col >= 0) and (col <= 10) and
          (GDVars.wallGfx^.slices[wallType][sliceIndex] > 0) then
        Sym8x8.Put8x8Sym(col + 3 - 1,
                         row + 3 - 1, GDVars.wallGfx^.slices[wallType][sliceIndex], True,
                         True);
      Inc(sliceIndex);
    end;
end;

{ Tells whether a cell is on the 16x16 map.
  @param(x The map column.)
  @param(y The map row.)
  @returns(True when the cell is on the map.) }
function Valid3DCoords(x, y: ShortInt): Boolean;
begin
  if (x > 15) or (x < 0) or (y > 15) or (y < 0) then
    Valid3DCoords := False
  else
    Valid3DCoords := True;
end;

function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;
var
  barrierType: Byte;
begin
  if not View3D.Valid3DCoords(x, y) and
      ((GDVars.eclScriptId = 0) or (GDVars.eclScriptId = 80)) then
    GetBarrierType := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0 else if y < 0 then y := 15;
    barrierType := 1;
    if View3D.GetWallType(x, y, facing) > 0 then
      case facing of
        C_Dir.WEST: barrierType := (GDVars.map3d^.barriers[y][x] and $C0) shr 6;
        C_Dir.SOUTH: barrierType := (GDVars.map3d^.barriers[y][x] and $30) shr 4;
        C_Dir.EAST: barrierType := (GDVars.map3d^.barriers[y][x] and $C) shr 2;
        C_Dir.NORTH: barrierType := GDVars.map3d^.barriers[y][x] and 3;
      end;
    GetBarrierType := barrierType;
  end;
end;

function GetWallType(x, y: ShortInt; facing: Byte): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and
      ((GDVars.eclScriptId = 0) or (GDVars.eclScriptId = 80)) then
    GetWallType := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0 else if y < 0 then y := 15;
    case facing of
      C_Dir.NORTH: GetWallType := (GDVars.map3d^.wallsNE[y][x] and $F0) shr 4;
      C_Dir.EAST: GetWallType := GDVars.map3d^.wallsNE[y][x] and $F;
      C_Dir.SOUTH: GetWallType := (GDVars.map3d^.wallsSW[y][x] and $F0) shr 4;
      C_Dir.WEST: GetWallType := GDVars.map3d^.wallsSW[y][x] and $F;
    end;
  end;
end;

function GetMapEvent(x, y: ShortInt): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and
      ((GDVars.eclScriptId = 0) or (GDVars.eclScriptId = 80)) then
    GetMapEvent := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0;
    if y < 0 then y := 15;
    GetMapEvent := GDVars.map3d^.events[y][x];
  end;
end;

procedure Display3DMapView(x, y: ShortInt; facing: Byte);
var
  leftFacing: Byte;
  rightFacing: Byte;
  backFacing: Byte;
  centerX: Integer;
  centerY: Integer;
  { holds a signed delta; the wrapping arithmetic still sums correctly }
  forwardDeltaX: Word;
  forwardDeltaY: Word;
  worldX: Integer;
  worldY: Integer;
  sideIndex: Byte;
  horizontalOffset: Integer;
  distance: Byte;
  frontWallType: Byte;
  sideWallType: Byte;
  { Unused in this version; see the other implementations of this routine. }
  wallBack: Byte;
  previousWall: Byte;
begin
  if GDVars.automapShown <> 0 then
    View3D.DrawAutoMap(x, y, facing)
  else begin
    GDVars.palettePresetOn := 0;
    View3D.DrawBackdrop;
    leftFacing := (facing + C_Dir.WEST) mod 8;
    backFacing := (facing + C_Dir.SOUTH) mod 8;
    rightFacing := (facing + C_Dir.EAST) mod 8;
    centerX := x;
    centerY := y;
    forwardDeltaX := GDConsts.dirDeltaX[facing];
    forwardDeltaY := GDConsts.dirDeltaY[facing];
    distance := 2;
    Inc(centerX, distance * forwardDeltaX);
    Inc(centerY, distance * forwardDeltaY);
    repeat
      case distance of
        2: begin
          worldX := centerX; worldY := centerY; sideIndex := 0; horizontalOffset := 0; previousWall := 0;
          while sideIndex < 4 do begin
            frontWallType := View3D.GetWallType(worldX, worldY, facing);
            if not View3D.Valid3DCoords(worldX, worldY) and (View3D.GetWallType(worldX, worldY, rightFacing) = 0) then
              previousWall := 0;
            if frontWallType <> 0 then begin
              if previousWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[9] + horizontalOffset + 1, GDConsts.viewSlices.yRow[9],
                                     previousWall, 9);
              previousWall := frontWallType;
              View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[0] + horizontalOffset, GDConsts.viewSlices.yRow[0],
                                   frontWallType, 0);
            end else begin
              if (previousWall > 0) and
                  (View3D.GetWallType(worldX - GDConsts.dirDeltaX[leftFacing], worldY - GDConsts.dirDeltaY[leftFacing],
                               leftFacing) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[9] + horizontalOffset + 1, GDConsts.viewSlices.yRow[9],
                                     previousWall, 9);
              previousWall := 0;
            end;
            Inc(sideIndex); Dec(horizontalOffset, 2);
            worldX := worldX + GDConsts.dirDeltaX[leftFacing]; worldY := worldY + GDConsts.dirDeltaY[leftFacing];
          end;
          worldX := centerX; worldY := centerY; sideIndex := 0; horizontalOffset := 0; previousWall := 0;
          while sideIndex < 4 do begin
            frontWallType := View3D.GetWallType(worldX, worldY, facing);
            if not View3D.Valid3DCoords(worldX, worldY) and (View3D.GetWallType(worldX, worldY, leftFacing) = 0) then
              previousWall := 0;
            if frontWallType <> 0 then begin
              if previousWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[9] + horizontalOffset - 1, GDConsts.viewSlices.yRow[9],
                                     previousWall, 9);
              previousWall := frontWallType;
              View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[0] + horizontalOffset, GDConsts.viewSlices.yRow[0],
                                   frontWallType, 0);
            end else begin
              if (previousWall > 0) and
                  (View3D.GetWallType(worldX - GDConsts.dirDeltaX[rightFacing],
                                      worldY - GDConsts.dirDeltaY[rightFacing], rightFacing) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[9] + horizontalOffset - 1, GDConsts.viewSlices.yRow[9],
                                     previousWall, 9);
              previousWall := 0;
            end;
            Inc(sideIndex); Inc(horizontalOffset, 2);
            worldX := worldX + GDConsts.dirDeltaX[rightFacing]; worldY := worldY + GDConsts.dirDeltaY[rightFacing];
          end;
          worldX := centerX; worldY := centerY; sideIndex := 0; horizontalOffset := 0;
          while sideIndex < 3 do begin
            sideWallType := View3D.GetWallType(worldX, worldY, leftFacing);
            if sideWallType <> 0 then
              if sideIndex = 0 then
                View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[1] + horizontalOffset, GDConsts.viewSlices.yRow[1],
                                     sideWallType, 1)
              else
                View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[1] + horizontalOffset - 1, GDConsts.viewSlices.yRow[1],
                                     sideWallType, 1);
            Inc(sideIndex); Dec(horizontalOffset, 2);
            worldX := worldX + GDConsts.dirDeltaX[leftFacing]; worldY := worldY + GDConsts.dirDeltaY[leftFacing];
          end;
          worldX := centerX; worldY := centerY; sideIndex := 0; horizontalOffset := 0;
          while sideIndex < 3 do begin
            sideWallType := View3D.GetWallType(worldX, worldY, rightFacing);
            if sideWallType <> 0 then
              if sideIndex = 0 then
                View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[2] + horizontalOffset, GDConsts.viewSlices.yRow[2],
                                     sideWallType, 2)
              else
                View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[2] + horizontalOffset + 1, GDConsts.viewSlices.yRow[2],
                                     sideWallType, 2);
            Inc(sideIndex); Inc(horizontalOffset, 2);
            worldX := worldX + GDConsts.dirDeltaX[rightFacing]; worldY := worldY + GDConsts.dirDeltaY[rightFacing];
          end;
        end;
        1: begin
          worldX := centerX + GDConsts.dirDeltaX[leftFacing]; worldX := worldX + GDConsts.dirDeltaX[leftFacing];
          worldY := centerY + GDConsts.dirDeltaY[leftFacing]; worldY := worldY + GDConsts.dirDeltaY[leftFacing];
          sideIndex := 0; horizontalOffset := -6;
          while sideIndex < 3 do begin
            frontWallType := View3D.GetWallType(worldX, worldY, facing);
            if frontWallType <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[3] + horizontalOffset, GDConsts.viewSlices.yRow[3],
                                   frontWallType, 3);
            sideWallType := View3D.GetWallType(worldX, worldY, leftFacing);
            if sideWallType <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[4] + horizontalOffset, GDConsts.viewSlices.yRow[4],
                                   sideWallType, 4);
            Inc(sideIndex); Inc(horizontalOffset, 3);
            worldX := worldX + GDConsts.dirDeltaX[rightFacing]; worldY := worldY + GDConsts.dirDeltaY[rightFacing];
          end;
          worldX := centerX + GDConsts.dirDeltaX[rightFacing]; worldX := worldX + GDConsts.dirDeltaX[rightFacing];
          worldY := centerY + GDConsts.dirDeltaY[rightFacing]; worldY := worldY + GDConsts.dirDeltaY[rightFacing];
          sideIndex := 0; horizontalOffset := 6;
          while sideIndex < 3 do begin
            frontWallType := View3D.GetWallType(worldX, worldY, facing);
            if frontWallType <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[3] + horizontalOffset, GDConsts.viewSlices.yRow[3],
                                   frontWallType, 3);
            sideWallType := View3D.GetWallType(worldX, worldY, rightFacing);
            if sideWallType <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[5] + horizontalOffset, GDConsts.viewSlices.yRow[5],
                                   sideWallType, 5);
            Inc(sideIndex); Dec(horizontalOffset, 3);
            worldX := worldX + GDConsts.dirDeltaX[leftFacing]; worldY := worldY + GDConsts.dirDeltaY[leftFacing];
          end;
        end;
        0: begin
          worldX := centerX + GDConsts.dirDeltaX[leftFacing];
          worldY := centerY + GDConsts.dirDeltaY[leftFacing];
          sideIndex := 0; horizontalOffset := -7;
          while sideIndex < 2 do begin
            frontWallType := View3D.GetWallType(worldX, worldY, facing);
            if frontWallType <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[6] + horizontalOffset, GDConsts.viewSlices.yRow[6],
                                   frontWallType, 6);
            sideWallType := View3D.GetWallType(worldX, worldY, leftFacing);
            if sideWallType <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[7] + horizontalOffset, GDConsts.viewSlices.yRow[7],
                                   sideWallType, 7);
            Inc(sideIndex); Inc(horizontalOffset, 7);
            worldX := worldX + GDConsts.dirDeltaX[rightFacing]; worldY := worldY + GDConsts.dirDeltaY[rightFacing];
          end;
          worldX := centerX + GDConsts.dirDeltaX[rightFacing];
          worldY := centerY + GDConsts.dirDeltaY[rightFacing];
          sideIndex := 0; horizontalOffset := 7;
          while sideIndex < 2 do begin
            frontWallType := View3D.GetWallType(worldX, worldY, facing);
            if frontWallType <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[6] + horizontalOffset, GDConsts.viewSlices.yRow[6],
                                   frontWallType, 6);
            sideWallType := View3D.GetWallType(worldX, worldY, rightFacing);
            if sideWallType <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlices.xColumn[8] + horizontalOffset, GDConsts.viewSlices.yRow[8],
                                   sideWallType, 8);
            Inc(sideIndex); Dec(horizontalOffset, 7);
            worldX := worldX + GDConsts.dirDeltaX[leftFacing]; worldY := worldY + GDConsts.dirDeltaY[leftFacing];
          end;
        end;
      end;
      centerX := centerX + GDConsts.dirDeltaX[backFacing];
      centerY := centerY + GDConsts.dirDeltaY[backFacing];
      Dec(distance);
    until distance = 255;
    Blit.FlushView;

    if GDVars.viewPaletteDirty then begin
      if GDVars.backdropPalActive then begin
        Blit.SetDacPalette(144, 32, GDVars.backdropPal);
        Blit.CopyPaletteEntries(144, 32, GDVars.backdropPal, GDVars.mainPal);
      end else begin
        Blit.SetDacPalette(144, 32, GDVars.skyPal);
        Blit.CopyPaletteEntries(144, 32, GDVars.skyPal, GDVars.mainPal);
      end;
      GDVars.viewPaletteDirty := False;
    end;
  end;
end;

{ Loads a backdrop picture of BACK1.DAX and keeps its palette for the next redraw.
  @param(imageId The picture number.) }
procedure LoadBackdrop(imageId: Byte);
var
  resourceName: String[5];
begin
  resourceName := 'back1';
  Blit.LoadPic(resourceName, imageId, 0, GDVars.viewSkyColor, GDVars.backdropPicture);
  Blit.ShadowPaletteEntries(144, 32, GDVars.backdropPal);
  GDVars.viewPaletteDirty := True;
end;

procedure LoadWallSet(resourceId, wallSetSlot: Byte);
var
  resourceSize: Word;
  resourceData: Types.PBytes;
  dataOffset: Word;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  wallDefinitionIndex: Word;
  { Unused in this version; see the other implementations of this routine. }
  entryIdx: Integer;
  { Unused in this version; see the other implementations of this routine. }
  definitionCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  keyPressed: Char;
begin
  if wallSetSlot > 3 then Exit;
  DaxIo.LoadDax('WALLDEF1', '.dax', resourceId, resourceSize, resourceData);
  if (resourceSize = 0) or (resourceSize div SizeOf(Types.TWallDefinition) + wallSetSlot > 4) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load ', resourceId, ' from WALLDEF1.');
    keyPressed := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame(0);
  end;
  dataOffset := 0;
  wallDefinitionIndex := 1;
  repeat
    Move(resourceData^[dataOffset], GDVars.wallGfx^.definitions[wallSetSlot + wallDefinitionIndex],
         SizeOf(Types.TWallDefinition));
    Inc(dataOffset, SizeOf(Types.TWallDefinition));
    Inc(wallDefinitionIndex);
  until dataOffset >= resourceSize;
  ZeroFree.PrefixFree(resourceData, resourceSize);
  definitionCount := wallDefinitionIndex - 1;
  Sym8x8.Load8x8Set(resourceId, wallSetSlot);
  GDVars.mainPalReload := True;
  View3D.LoadBackdrop(resourceId);
  Blit.ShadowPaletteEntries(32, 115, GDVars.mainPal);
  GDVars.loadedWallSet.id := resourceId;
  GDVars.loadedWallSet.slot := wallSetSlot;
end;

procedure Load3DMap(mapId: Byte);
var
  resourceSize: Word;
  resourceData: Types.PBytes;
  dataOffset: Word;
  { Unused in this version; see the other implementations of this routine. }
  keyPressed: Char;
begin
  DaxIo.LoadDax('GEO1', '.dax', mapId, resourceSize, resourceData);
  if (resourceSize = 0) or (resourceSize <> 2 + SizeOf(Types.TMapGeometry)) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load geo in Load3DMap.');
    keyPressed := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame(0);
  end;
  dataOffset := 2;
  Move(resourceData^[dataOffset], GDVars.map3d^.wallsNE, SizeOf(Types.TMapPlane)); Inc(dataOffset,
                                                                                       SizeOf(Types.TMapPlane));
  Move(resourceData^[dataOffset], GDVars.map3d^.wallsSW, SizeOf(Types.TMapPlane)); Inc(dataOffset,
                                                                                       SizeOf(Types.TMapPlane));
  Move(resourceData^[dataOffset], GDVars.map3d^.events, SizeOf(Types.TMapPlane)); Inc(dataOffset,
                                                                                      SizeOf(Types.TMapPlane));
  Move(resourceData^[dataOffset], GDVars.map3d^.barriers, SizeOf(Types.TMapPlane));
  ZeroFree.PrefixFree(resourceData, resourceSize);
  GDVars.vmBand.zone0^.areaState.loadedMapId := mapId;
end;

begin
end.
