{ Portrait, animation-frame, large-picture, and palette-range display services. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Portrait;

interface

uses Blit, Types, GDConsts, GDVars, ZeroFree, GameIo, Mouse, Border, TextRend, DaxIo, VgaFrame, C_Video;

{ Shows a frame of the loaded animation at a character cell with the mouse cursor hidden, doing nothing when that frame
  is not loaded. A VGA frame other than a sprite is first decoded into the display image.
  @param(col Character column.)
  @param(row Character row.)
  @param(ignoredAnimate Overwritten with False, so the frame always goes straight to the screen rather than through the
    view buffer.)
  @param(frameIndex The frame; not range-checked.) }
procedure DisplayImageBuf(col, row: Integer; ignoredAnimate: Boolean; frameIndex: Byte);

{ Loads an animation from archive <archiveName>1.dax, unless it is already loaded, in which case only its palette is
  restored; nothing happens for resourceId 255. A PIC archive also selects the picture's palette-cycling preset, and an
  archive whose name starts with S holds sprites. After the header, palette and frame table, VGA frames other than
  sprites are kept encoded for DisplayImageBuf to decode, with the key frame expanded in full; otherwise every frame
  becomes a Blit image, each non-key frame expanded and XORed against the key frame. 'PIC not found' shows when the
  resource is missing. Note: once the resource is found its contents are trusted -- header fields, palette ranges and
  frame sizes are not checked -- and archiveName must not be empty.
  @param(archiveName Base name of the DAX file, without the disk digit.)
  @param(resourceId Picture number within the file; 255 loads nothing.)
  @param(transparentColor Passed to AllocPic as its flag (bit 0 asks for a mask) and to ExpandPicFrames.) }
procedure LoadAnimation(archiveName: Types.TResourceName; resourceId, transparentColor: Byte);

{ Frees the loaded animation's frames (on VGA, a PIC's encoded frames and the display image), clears the frame table,
  and forgets which animation is loaded, so the next LoadAnimation reloads. Note: the VGA path clears 66 bytes from
  GDVars.vgaFrameBufs, which holds 36, so it also clears GDVars.vgaFrameImage and most of GDVars.animFrames. }
procedure FreeAnimation;

{ Draws the sprite frame for a distance clipped into the view buffer, at the frame's own origin, and flushes the view to
  the screen; a missing frame draws nothing. A distance outside 1..3 is a fatal error, reported in text mode.
  @param(distance 1 near, 2 middle, 3 far.) }
procedure Show3DSprite(distance: Byte);

{ Frees any animation, then loads a big picture from BIGPIC1.DAX with its palette-cycling preset, unless it is already
  loaded, in which case only its palette is restored.
  @param(pictureId Picture number.) }
procedure LoadBigPic(pictureId: Byte);

{ Draws the base frame (Border.ScreenText) and shows the big picture at cell (1, 1), with the mouse cursor hidden. }
procedure DisplayBigPic;

{ Rotates a color range of the current preset by one entry. The rotated colors go into GDVars.imagePal, which is Blit's
  working palette, so ShadowPaletteEntries copies them back into GDVars.picPal and SetDacPalette shows them. MenuCore's
  input loop calls this on each range's delay. Note: a range with a zero color count underflows the palette indices and
  the Move extent.
  @param(rangeIndex The range within GDVars.palettePreset.) }
procedure CyclePaletteRange(rangeIndex: Byte);

implementation

const
  { the key color of a decoded frame }
  DEFAULT_TRANSPARENT_COLOR = 13;
  { GDVars.picArcId when no picture is loaded }
  NO_RESOURCE_ID = 255;

{ Copies the palette-cycling preset for a picture into GDVars.palettePreset and marks it available; a picture without a
  preset marks it unavailable.
  @param(pictureId The picture.) }
procedure SelectPicturePalettePreset(pictureId: Byte);
var
  presetIndex: Byte;
begin
  GDVars.palettePresetOn := 1;
  case pictureId of
    7: presetIndex := 0;
    128: presetIndex := 1;
    133: presetIndex := 2;
    136: presetIndex := 3;
    137: presetIndex := 4;
    139: presetIndex := 5;
    142: presetIndex := 6;
    149: presetIndex := 7;
    240..246:
      presetIndex := pictureId - 240 + 8;
  else
    GDVars.palettePresetOn := 0;
  end;
  if GDVars.palettePresetOn = 1 then
    GDVars.palettePreset := GDConsts.palettePresets[presetIndex];
end;

procedure DisplayImageBuf(col, row: Integer; ignoredAnimate: Boolean; frameIndex: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  frameName: array[1..14] of Byte;
begin
  if ((GDVars.videoMode = C_Video.DISPLAY_MCGA) and (GDVars.vgaFrameBufs[frameIndex] = nil)) or
      (((GDVars.videoMode <> C_Video.DISPLAY_MCGA) or GDVars.animFromSprite) and
       (GDVars.animFrames[frameIndex] = nil)) then Exit;
  if (GDVars.videoMode = C_Video.DISPLAY_MCGA) and not GDVars.animFromSprite then
    VgaFrame.PrepareVgaFrame(frameIndex);
  ignoredAnimate := False;
  if ignoredAnimate then begin
    if (GDVars.videoMode = C_Video.DISPLAY_MCGA) and not GDVars.animFromSprite then
      Blit.BlitTileClipped(col - 1, row - 1, 0, 0, GDVars.vgaFrameImage,
                  GDVars.viewImageBuf)
    else
      Blit.BlitTileClipped(col - 1, row - 1, 0, 0,
                       GDVars.animFrames[frameIndex], GDVars.viewImageBuf);
    Mouse.HideMouse;
    Blit.FlushView;
    Mouse.ShowMouse;
  end else begin
    Mouse.HideMouse;
    if (GDVars.videoMode = C_Video.DISPLAY_MCGA) and not GDVars.animFromSprite then
      Blit.ShowPic(col, row, GDVars.vgaFrameImage)
    else
      Blit.ShowPic(col, row, GDVars.animFrames[frameIndex]);
    Mouse.ShowMouse;
  end;
end;

procedure LoadAnimation(archiveName: Types.TResourceName; resourceId, transparentColor: Byte);
var
  imageX: Word;
  imageY: Word;
  frameNumber: Integer;
  pixelOffset: Word;
  lastLoadedFrame: Byte;
  paletteFirst: Byte;
  paletteCount: Byte;
  xorFrame: Types.PBytes;
  workBuffer: Types.PBytes;
  resourceData: Types.PBytes;
  decodedBytes: Word;
  imageHeight: Word;
  imageWidth: Word;
  { Unused in this version; see the other implementations of this routine. }
  frameSize: Word;
  resourceSize: Word;
  frameDataOffset: Word;
  dataOffset: Word;
  archiveSuffix: String[1];
  workBufferSize: Word;
begin
  if resourceId = Portrait.NO_RESOURCE_ID then Exit;
  if archiveName = 'PIC' then
    Portrait.SelectPicturePalettePreset(resourceId)
  else
    GDVars.palettePresetOn := 0;
  if (archiveName = GDVars.picArcName) and (resourceId = GDVars.picArcId) then begin
    if GDVars.animFromSprite then
      Blit.SetDacPalette(176, 80, GDVars.picPal)
    else
      Blit.SetDacPalette(32, 224, GDVars.picPal);
    Exit;
  end;
  if GDVars.bigPicImage <> nil then Blit.FreePic(GDVars.bigPicImage);
  TextRend.DisplayLoading;
  Portrait.FreeAnimation;
  GameIo.ZeroFill(GDVars.animFrameDelays,
                  SizeOf(GDVars.animFrameDelays) + SizeOf(GDVars.animFrameSizes) + SizeOf(GDVars.animKeyFrame) +
                  SizeOf(GDVars.animFirstFrame) + SizeOf(GDVars.animLastFrame) + SizeOf(GDVars.animCurFrame));
  GDVars.picArcName := archiveName;
  GDVars.animFromSprite := UpCase(archiveName[1]) = 'S';
  GDVars.picArcId := resourceId;
  archiveSuffix := '1';
  DaxIo.LoadDax(archiveName + archiveSuffix, '.dax', resourceId, resourceSize, resourceData);
  if resourceSize = 0 then begin
    TextRend.DisplayAndPause(14, 0, 'PIC not found');
    Exit;
  end;
  dataOffset := 0;
  Move(resourceData^[dataOffset], imageHeight, SizeOf(imageHeight)); Inc(dataOffset, SizeOf(imageHeight));
  Move(resourceData^[dataOffset], imageWidth, SizeOf(imageWidth)); Inc(dataOffset, SizeOf(imageWidth));
  Move(resourceData^[dataOffset], imageX, SizeOf(imageX)); Inc(dataOffset, SizeOf(imageX));
  Move(resourceData^[dataOffset], imageY, SizeOf(imageY)); Inc(dataOffset, SizeOf(imageY));
  Move(resourceData^[dataOffset], lastLoadedFrame, SizeOf(lastLoadedFrame)); Inc(dataOffset);
  if lastLoadedFrame > 8 then lastLoadedFrame := 8;
  GDVars.animLastFrame := lastLoadedFrame;
  Move(resourceData^[dataOffset], paletteFirst, SizeOf(paletteFirst)); Inc(dataOffset);
  Move(resourceData^[dataOffset], paletteCount, SizeOf(paletteCount)); Inc(dataOffset);
  Move(resourceData^[dataOffset], GDVars.imagePal[paletteFirst], paletteCount * SizeOf(Types.TRgb));
  Inc(dataOffset, paletteCount * SizeOf(Types.TRgb));
  for frameNumber := 0 to (paletteCount shr 1) - 1 do begin
    GDVars.palIndexMap[paletteFirst + frameNumber * 2] :=
      resourceData^[dataOffset] shr 4;
    GDVars.palIndexMap[paletteFirst + frameNumber * 2 + 1] := resourceData^[dataOffset] and
      $F;
    Inc(dataOffset);
  end;
  Inc(dataOffset, 4);
  Move(resourceData^[dataOffset], GDVars.animKeyFrame, SizeOf(GDVars.animKeyFrame)); Inc(dataOffset);
  Move(resourceData^[dataOffset], GDVars.animFirstFrame, SizeOf(GDVars.animFirstFrame)); Inc(dataOffset);
  for frameNumber := 0 to lastLoadedFrame do begin
    Move(resourceData^[dataOffset], GDVars.animFrameSizes[frameNumber], SizeOf(Word));
    Move(resourceData^[dataOffset + SizeOf(Word)], GDVars.animFrameDelays[frameNumber], SizeOf(Byte));
    Inc(dataOffset, SizeOf(Word) + SizeOf(Byte));
  end;
  if (GDVars.videoMode = C_Video.DISPLAY_MCGA) and not GDVars.animFromSprite then begin
    Blit.AllocPic(imageHeight, imageWidth, 1, transparentColor, GDVars.vgaFrameImage);
    GDVars.vgaFrameImage^.keyColor := Portrait.DEFAULT_TRANSPARENT_COLOR;
    GDVars.vgaFrameImage^.imgOriginX := imageX;
    GDVars.vgaFrameImage^.imgOriginY := imageY;
  end;
  workBufferSize := 7744;
  for frameNumber := 0 to lastLoadedFrame do
    if GDVars.animFrameSizes[frameNumber] > workBufferSize then workBufferSize := GDVars.animFrameSizes[frameNumber];
  GetMem(workBuffer, workBufferSize);
  if (GDVars.videoMode = C_Video.DISPLAY_MCGA) and not GDVars.animFromSprite then begin
    for frameNumber := 0 to lastLoadedFrame do begin
      if frameNumber = GDVars.animKeyFrame then begin
        GetMem(GDVars.vgaFrameBufs[frameNumber], 7744);
        Move(resourceData^[dataOffset], workBuffer^, GDVars.animFrameSizes[frameNumber]);
        VgaFrame.ExpandRleFrame(workBuffer, GDVars.vgaFrameBufs[frameNumber], GDVars.animFrameSizes[frameNumber]);
      end else begin
        GetMem(GDVars.vgaFrameBufs[frameNumber], GDVars.animFrameSizes[frameNumber]);
        Move(resourceData^[dataOffset], GDVars.vgaFrameBufs[frameNumber]^, GDVars.animFrameSizes[frameNumber]);
      end;
      Inc(dataOffset, GDVars.animFrameSizes[frameNumber]);
    end;
  end else begin
    GetMem(xorFrame, 7744);
    frameDataOffset := dataOffset;
    frameNumber := 0;
    while frameNumber < GDVars.animKeyFrame do begin Inc(dataOffset,
                                                           GDVars.animFrameSizes[frameNumber]); Inc(frameNumber) end;
    VgaFrame.ExpandRleFrame(@resourceData^[dataOffset], xorFrame, GDVars.animFrameSizes[GDVars.animKeyFrame]);
    dataOffset := frameDataOffset;
    for frameNumber := 0 to lastLoadedFrame do begin
      Blit.AllocPic(imageHeight, imageWidth, 1, transparentColor, GDVars.animFrames[frameNumber]);
      GDVars.animFrames[frameNumber]^.imgOriginX := imageX;
      GDVars.animFrames[frameNumber]^.imgOriginY := imageY;
      GDVars.animFrames[frameNumber]^.keyColor := Portrait.DEFAULT_TRANSPARENT_COLOR;
      if frameNumber <> GDVars.animKeyFrame then begin
        VgaFrame.ExpandRleFrame(@resourceData^[dataOffset], workBuffer, GDVars.animFrameSizes[frameNumber]);
        VgaFrame.XorFrame(workBuffer, workBuffer, xorFrame, 7744);
        if GDVars.animFromSprite then
          for pixelOffset := 0 to 7743 do
            case workBuffer^[pixelOffset] of
              0: workBuffer^[pixelOffset] := Portrait.DEFAULT_TRANSPARENT_COLOR;
              Portrait.DEFAULT_TRANSPARENT_COLOR: workBuffer^[pixelOffset] := 0;
            end;
        decodedBytes := 0;
        Blit.ExpandPicFrames(workBuffer, decodedBytes, transparentColor,
                             Portrait.DEFAULT_TRANSPARENT_COLOR, GDVars.animFrames[frameNumber]);
      end;
      Inc(dataOffset, GDVars.animFrameSizes[frameNumber]);
    end;
    if GDVars.animFromSprite then
      for pixelOffset := 0 to 7743 do
        case xorFrame^[pixelOffset] of
          0: xorFrame^[pixelOffset] := Portrait.DEFAULT_TRANSPARENT_COLOR;
          Portrait.DEFAULT_TRANSPARENT_COLOR: xorFrame^[pixelOffset] := 0;
        end;
    decodedBytes := 0;
    Blit.ExpandPicFrames(xorFrame, decodedBytes, transparentColor, Portrait.DEFAULT_TRANSPARENT_COLOR,
                 GDVars.animFrames[GDVars.animKeyFrame]);
    ZeroFree.PrefixFree(xorFrame, 7744);
  end;
  ZeroFree.PrefixFree(resourceData, resourceSize);
  ZeroFree.PrefixFree(workBuffer, workBufferSize);
  if GDVars.animFromSprite then begin
    Blit.ShadowPaletteEntries(176, 80, GDVars.picPal);
    Blit.SetDacPalette(176, 80, GDVars.picPal);
  end else begin
    Blit.ShadowPaletteEntries(32, 224, GDVars.picPal);
    Blit.SetDacPalette(32, 224, GDVars.picPal);
  end;
end;

procedure FreeAnimation;
begin
  if (GDVars.videoMode = C_Video.DISPLAY_MCGA) and not GDVars.animFromSprite then begin
    for GDVars.scratchIndex := 0 to GDVars.animLastFrame do
      if GDVars.vgaFrameBufs[GDVars.scratchIndex] <> nil then
        if GDVars.scratchIndex = GDVars.animKeyFrame then
          ZeroFree.PrefixFree(GDVars.vgaFrameBufs[GDVars.scratchIndex], 7744)
        else
          ZeroFree.PrefixFree(GDVars.vgaFrameBufs[GDVars.scratchIndex],
                              GDVars.animFrameSizes[GDVars.scratchIndex]);
    Blit.FreePic(GDVars.vgaFrameImage);
    GameIo.ZeroFill(GDVars.vgaFrameBufs, 66);
  end else begin
    for GDVars.scratchIndex := 0 to GDVars.animLastFrame do
      Blit.FreePic(GDVars.animFrames[GDVars.scratchIndex]);
    GameIo.ZeroFill(GDVars.animFrames, SizeOf(GDVars.animFrames));
  end;
  GDVars.picArcName := '';
  GDVars.picArcId := Portrait.NO_RESOURCE_ID;
end;

procedure Show3DSprite(distance: Byte);
begin
  if (distance < 1) or (distance > 3) then begin
    Blit.RestoreVideoMode;
    WriteLn('Illegal range in Show3DSprite.');
    GameIo.ExitGame(0);
  end;
  if GDVars.animFrames[distance - 1] = nil then Exit;
  Blit.BlitTileClipped(2, 2, 0, 1,
              GDVars.animFrames[distance - 1], GDVars.viewImageBuf);
  Blit.FlushView;
end;

procedure LoadBigPic(pictureId: Byte);
begin
  Portrait.FreeAnimation;
  if (GDVars.bigPicId = pictureId) and (GDVars.bigPicImage <> nil) then
    Blit.SetDacPalette(32, 224, GDVars.picPal)
  else begin
    TextRend.DisplayLoading;
    Blit.LoadPic('bigpic1', pictureId, 0, 0, GDVars.bigPicImage);
    Portrait.SelectPicturePalettePreset(pictureId);
    GDVars.bigPicId := pictureId;
    Blit.ShadowPaletteEntries(32, 224, GDVars.picPal);
    Blit.SetDacPalette(32, 224, GDVars.imagePal);
    TextRend.ClearStatusLine;
  end;
end;

procedure DisplayBigPic;
begin
  Mouse.HideMouse;
  Border.ScreenText;
  Blit.ShowPic(1, 1, GDVars.bigPicImage);
  Mouse.ShowMouse;
end;

procedure CyclePaletteRange(rangeIndex: Byte);
var
  firstColor: Byte;
  colorCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  colorIndex: Word;
begin
  firstColor := GDVars.palettePreset[rangeIndex].firstColor;
  colorCount := GDVars.palettePreset[rangeIndex].colorCount;
  Move(GDVars.picPal[firstColor], GDVars.imagePal[firstColor + 1], (colorCount - 1) * SizeOf(Types.TRgb));
  Move(GDVars.picPal[firstColor + colorCount - 1], GDVars.imagePal[firstColor], SizeOf(Types.TRgb));
  Blit.ShadowPaletteEntries(firstColor, colorCount, GDVars.picPal);
  Blit.SetDacPalette(firstColor, colorCount, GDVars.picPal);
end;

begin
end.
