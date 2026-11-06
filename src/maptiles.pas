{ Map tiles and combat icons: loads sets of 24x24 map tiles into the shared tile image, loads and frees the two-frame
  icon animations, and draws an icon frame, mirrored when it faces west. }
{$O+,F+,S-,R-,V-,B-,I-}
unit MapTiles;

interface

uses Blit, GameIo, GDConsts, GDVars, C_Dir, Types;

{ Loads a picture of 24x24 map tiles and copies the given number of its tiles into the map tile sheet from the given
  slot on, then shadows the tile palette entries and flushes pending keystrokes. A slot past 39 is a fatal error.
  @param(tileSetName Base name of the DAX file.)
  @param(assetId Picture number within the file.)
  @param(startTile First tile slot written, 0..39.)
  @param(tileCount Number of tiles copied.) }
procedure Load24x24Set(tileSetName: String; assetId, startTile, tileCount: Byte);

{ Frees both frames of an icon animation slot.
  @param(animationIndex The slot.) }
procedure FreeIconAnim(animationIndex: Byte);

{ Loads the two frames of an icon animation, picture assetId and assetId + 128, then flushes pending keystrokes. For
  CHEAD and CBODY files the last letter of the name is a size letter: it is dropped, and T adds 64 to assetId; a head
  uses one picture for both frames. COMSPR, ICON and CPIC (read from CPIC1.DAX) keep their own colors, and CPIC also
  shadows its palette entries; any other name loads from file assetName + '1' and has its colors remapped through
  GDConsts.pink8ColorMap.
  @param(assetName Base name of the DAX file.)
  @param(assetId Picture number of the first frame.)
  @param(animationIndex Slot receiving the frames.) }
procedure LoadIconAnim(assetName: String; assetId, animationIndex: Byte);

{ Draws one frame of an icon animation into the view buffer, clipped, at three character cells per map cell, mirrored
  for facings past southeast. Nothing is drawn if the frame is not loaded.
  @param(col Map column.)
  @param(row Map row.)
  @param(facing Direction the icon faces.)
  @param(frame Frame to draw, 0 or 1.)
  @param(animationIndex Animation slot.) }
procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animationIndex: Byte);

implementation

procedure Load24x24Set(tileSetName: String; assetId, startTile, tileCount: Byte);
var
  loadedTileImage: Types.PImage;
  copyByteCount: Word;
  destinationOffset: Word;
begin
  if startTile > 39 then begin
    Blit.RestoreVideoMode;
    WriteLn('Start range error in Load24x24Set');
    GameIo.ExitGame(0);
  end;
  loadedTileImage := nil;
  Blit.LoadPic(tileSetName, assetId, 0, 0, loadedTileImage);
  { Note: the load is assumed to succeed, and the copy is not checked against either image's size. }
  copyByteCount := tileCount * loadedTileImage^.total;
  destinationOffset := startTile * loadedTileImage^.total;
  if GDVars.mapTileSheet <> nil then
    Move(loadedTileImage^.data, GDVars.mapTileSheet^.data[destinationOffset], copyByteCount);
  Blit.ShadowPaletteEntries(32, 32, GDVars.backupPal);
  Blit.FreePic(loadedTileImage);
  GameIo.FlushKeys;
end;

procedure FreeIconAnim(animationIndex: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  frameIndex: Integer;
begin
  if GDVars.iconAnimTable[animationIndex, 0] <> nil then
    Blit.FreePic(GDVars.iconAnimTable[animationIndex, 0]);
  if GDVars.iconAnimTable[animationIndex, 1] <> nil then
    Blit.FreePic(GDVars.iconAnimTable[animationIndex, 1]);
end;

procedure LoadIconAnim(assetName: String; assetId, animationIndex: Byte);
var
  assetSuffix: String[1];
  { Unused in this version; see the other implementations of this routine. }
  letter: Char;
begin
  if (Copy(assetName, 1, 5) = 'CHEAD') or (Copy(assetName, 1, 5) = 'CBODY') then
  begin
    if UpCase(assetName[Length(assetName)]) = 'T' then
      Inc(assetId, $40);
    assetName := Copy(assetName, 1, Length(assetName) - 1);
    Blit.LoadPic(assetName, assetId, 1, 8,
                   GDVars.iconAnimTable[animationIndex, 0]);
    if assetName = 'CHEAD' then
      Blit.LoadPic(assetName, assetId, 1, 8,
                     GDVars.iconAnimTable[animationIndex, 1])
    else
      Blit.LoadPic(assetName, assetId + $80, 1, 8,
                     GDVars.iconAnimTable[animationIndex, 1]);
  end else if (assetName = 'COMSPR') or (assetName = 'ICON') or (assetName = 'CPIC') then
  begin
    if assetName = 'CPIC' then
      assetSuffix := '1'
    else
      assetSuffix := '';
    Blit.LoadPic(assetName + assetSuffix, assetId, 1, 8,
                   GDVars.iconAnimTable[animationIndex, 0]);
    Blit.LoadPic(assetName + assetSuffix, assetId + $80, 1, 8,
                   GDVars.iconAnimTable[animationIndex, 1]);
    if assetName = 'CPIC' then
      Blit.ShadowPaletteEntries(144, 112, GDVars.backupPal);
  end else begin
    assetSuffix := '1';
    Blit.LoadPic(assetName + assetSuffix, assetId, 1, 0,
                   GDVars.iconAnimTable[animationIndex, 0]);
    Blit.RemapPic(GDConsts.identityColorMap, GDConsts.pink8ColorMap, 0, False, GDVars.iconAnimTable[animationIndex, 0]);
    Blit.LoadPic(assetName + assetSuffix, assetId + $80, 1, 0,
                   GDVars.iconAnimTable[animationIndex, 1]);
    Blit.RemapPic(GDConsts.identityColorMap, GDConsts.pink8ColorMap, 0, False, GDVars.iconAnimTable[animationIndex, 1]);
  end;
  GameIo.FlushKeys;
end;

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animationIndex: Byte);
var
  mirrorBuffer: Types.PImage;
begin
  if GDVars.iconAnimTable[animationIndex, frame] = nil then
    Exit;
  with GDVars.iconAnimTable[animationIndex, frame]^ do begin
    if facing > C_Dir.SOUTHEAST then begin
      Blit.AllocPic(rows, cells, 1, 1, mirrorBuffer);
      mirrorBuffer^.keyColor := GDVars.iconAnimTable[animationIndex, frame]^.keyColor;
      Blit.MirrorPic(GDVars.iconAnimTable[animationIndex, frame], mirrorBuffer);
      Blit.BlitTileClipped(col * 3, row * 3, 0, 1, mirrorBuffer,
                       GDVars.viewImageBuf);
      Blit.FreePic(mirrorBuffer);
    end else
      Blit.BlitTileClipped(col * 3, row * 3, 0, 1,
                       GDVars.iconAnimTable[animationIndex, frame], GDVars.viewImageBuf);
  end;
end;

begin
end.
