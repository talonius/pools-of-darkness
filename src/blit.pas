{ Image loading, conversion and screen composition for the three display classes the game drives: mode 0 is EGA planar
  (4 plane bytes per 8-pixel cell), mode 1 is Tandy packed 4bpp (4 bytes per cell) and mode 2 is MCGA 8bpp (8 bytes per
  cell). GDVars.videoMode selects the class everywhere in this unit.

  Images come off disk as DAX payloads with one byte per pixel; PreparePic and ExpandPicFrames convert them into the
  in-memory layout of the active class, plus a transparency mask for the planar and packed classes (MCGA uses a color
  key instead). The blitters themselves are hand-coded in BLIT.OBJ; this unit dispatches to them by class.

  Screen updates go through a two-phase deferred-span compositor: drawing into the offscreen view surface records, per
  scanline, the dirty byte range (FillPicRect and the blitters), and FlushView later copies just those ranges to video
  memory and resets the span tables for the next frame. }
{$F+,O+,S-,R-,V-,B-,I-}
unit Blit;

interface

uses Dos, GameIo, ZeroFree, DaxIo, Mouse, GDConsts, GDVars, C_Video, Types;

type
  { An 8-pixel chunk as stored in a picture: one byte per pixel. }
  TChunk = array[0..7] of Byte;

{ Waits for the start of vertical retrace (bit 3 of the input status register). }
procedure WaitRetraceStart;

{ Waits for the end of vertical retrace. }
procedure WaitRetraceEnd;

{ Returns the transparency mask of an 8-pixel chunk.
  @param(transpColor The color that is transparent.)
  @param(chunk The chunk's eight pixels, one byte each.)
  @returns(A bit set for each pixel equal to transpColor, bit 7 for chunk[0] down to bit 0 for chunk[7].) }
function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;

{ Switches the display to a BIOS video mode, remembering the mode it replaces so RestoreVideoMode can go back. The BIOS
  result is not checked, so an unsupported mode fails silently while the current-mode bookkeeping still records it.
  @param(mode BIOS INT 10h mode number to select.) }
procedure SetVideoMode(mode: Byte);

{ Returns to the mode that was current before the last SetVideoMode call. That call saves the mode it replaces, so two
  calls in a row toggle between two modes. }
procedure RestoreVideoMode;

{ Decodes a DAX image payload into an image record; LoadPic calls it. The header gives the size in rows and cells, two
  further words, the frame count and the palette range; the palette goes into GDVars.imagePal and GDVars.palIndexMap.
  The pixels are then expanded by ExpandPicFrames. Note: colorMapScratch is never written, so pic^.colorMap receives
  whatever the stack held.
  @param(data The loaded payload.)
  @param(hasMask Bit 0 asks for a mask, as AllocPic's flag.)
  @param(transpColor The transparent color key.)
  @param(needsAlloc True allocates a fresh image (the planar and packed classes need a different layout from the
    payload's); False makes the payload block itself the image record, with loadedSize as its size.)
  @param(loadedSize The payload block's size.)
  @param(pic Receives the image.) }
procedure PreparePic(var data: Types.PBytes; hasMask, transpColor: Byte; needsAlloc: Boolean; loadedSize: Word;
                     var pic: Types.PImage);

{ Frees any picture already held, loads a record of a .dax archive and builds the picture from it; outside the 256-color
  mode the loaded buffer is then freed. The keyboard is flushed after a successful load only.
  @param(name The archive's name.)
  @param(fileId The record.)
  @param(hasMask Asks for a transparency mask, outside the 256-color mode.)
  @param(transpColor The transparent color.)
  @param(pic Receives the picture.) }
procedure LoadPic(name: String; fileId, hasMask, transpColor: Byte; var pic: Types.PImage);

{ Draws a frame of gfx at a cell position of dest with no clipping. Bit 0 of flag asks for a transparent draw, which
  uses the image's mask, or in MCGA its key color; an image without a mask draws plain in the other classes.
  @param(screenX The cell column.)
  @param(screenY The scanline row.)
  @param(tileIdx The frame.)
  @param(flag Bit 0 draws transparently.)
  @param(gfx The image drawn.)
  @param(dest The image drawn into.) }
procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx: Types.PImage; dest: Types.PImage);

{ Draws a frame of gfx at a cell position of dest, clipped to dest. The clipped blitters interpret flag themselves and
  save what they cover into GDVars.iconSaveBuf.
  @param(screenX The cell column.)
  @param(screenY The scanline row.)
  @param(tileIdx The frame.)
  @param(flag Bit 0 draws through the mask or key color; bit 2 first saves the covered pixels.)
  @param(gfx The image drawn.)
  @param(dest The image drawn into.) }
procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx: Types.PImage; dest: Types.PImage);

{ Copies the first frame of an image into another with every row reversed left to right, with its color map. In EGA a
  byte holds 8 one-bit pixels, so each plane byte's bits are reversed as well; in Tandy a byte holds two pixels, so its
  nibbles swap; in the 256-color mode a byte is one pixel. The mask is mirrored the same way; the 256-color mode has
  none.
  @param(src The image mirrored; nothing happens if nil.)
  @param(dst Receives the mirror image, already allocated at the source's size; nothing happens if nil.) }
procedure MirrorPic(src, dst: Types.PImage);

{ Copies a cell-aligned rectangle of the screen, pic^.rows scanlines by pic^.cells cells, into pic's pixel data in the
  active class's layout. EGA reads each plane in turn through the Graphics Controller's read-map select and restores
  read map 0 and mode 0 afterwards.
  @param(col The rectangle's left cell column.)
  @param(row Its top cell row.)
  @param(pic Receives the pixels; its size gives the rectangle's.) }
procedure GrabPic(col, row: Integer; pic: Types.PImage);

{ Puts an image's pixel data back onto the screen; the inverse of GrabPic. EGA writes each plane in turn through the
  Sequencer's map mask and re-enables all four planes afterwards.
  @param(screenX The left cell column.)
  @param(screenY The top cell row.)
  @param(pic The image.) }
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImage);

{ Copies every dirty scanline run of the view surface to the screen, with the mouse cursor hidden, and resets the span
  tables. The view surface's slot 0 is screen scanline 8. EGA stages each plane of each run in a hidden page and then
  latch-copies the staged runs to the displayed page; Tandy and the 256-color mode copy each run straight to video
  memory. }
procedure FlushView;

{ Recolors an image. For each of the 16 color-map entries whose source and destination colors differ, every pixel of the
  source color becomes the destination color. EGA builds an 8-pixel match mask per cell by XOR-folding the four planes,
  Tandy tests the high and low nibble of each byte separately, and the 256-color mode is a plain compare and store. The
  work is done in a scratch copy which is copied back and freed at the end. Note: the 256-color mode's key test reads
  the scratch image's key color, which allocation leaves 0, rather than the picture's, so it is color 0 that is never
  recolored.
  @param(fromColors The colors to replace.)
  @param(toColors Their replacements.)
  @param(frame The frame to recolor. Note: a negative frame selects every frame for the first pass only; every later
    pass finds it zeroed, so only the first frame is recolored and copied back.)
  @param(isDithered Set to change only a random subset of the matching pixels, in EGA and Tandy; the 256-color mode has
    no dither.)
  @param(pic The image.) }
procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImage);

{ Frees an image's mask, if it has one (one frame's bytes times the frame count), then the record block, and sets the
  pointer to nil; a nil pointer is left alone.
  @param(p The image.) }
procedure FreePic(var p: Types.PImage);

{ Allocates a zero-filled image in the active display class's layout: the record and all frames as one block of
  totalSize + 27 bytes, 8 bytes per cell in MCGA and 4 otherwise, with the size fields filled in.
  @param(height The rows.)
  @param(width The width in cells.)
  @param(count The frames.)
  @param(flag Bit 0 asks for a separate zero-filled mask of totalSize bytes as well, never allocated for MCGA.)
  @param(pic Receives the image.) }
procedure AllocPic(height, width, count: Word; flag: Byte; var pic: Types.PImage);

{ Converts a one-byte-per-pixel payload into an image's pixel data in the active class's layout, frame by frame,
  building the transparency mask from the key color when the image has one. Note: mode 1's mask pass runs over
  everything converted so far rather than just the current frame, which repeats work but gives the same result.
  @param(imgData The payload.)
  @param(srcOff The offset of the first pixel in imgData; left just past the data consumed.)
  @param(hasMask Unused.)
  @param(transpColor The key color the mask covers.)
  @param(pic The image, already allocated at its size.) }
procedure ExpandPicFrames(imgData: Types.PBytes; var srcOff: Word; hasMask, transpColor: Byte; pic: Types.PImage);

{ Fills a rectangle of an image with a solid color, clipping it to the picture, and raises each touched row's span so
  FlushView copies it to the screen. Note: with a negative top edge the fill starts at the top and covers one row more
  than is visible, and is not clipped against the surface height.
  @param(x The rectangle's left cell column; may be negative.)
  @param(y Its top scanline; may be negative.)
  @param(width Its width in cells.)
  @param(height Its height in scanlines.)
  @param(color The fill color.)
  @param(colorMap Unused.)
  @param(pic The image filled; nothing happens if nil.) }
procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap; pic: Types.PImage);

{ In the 256-color mode, copies entries of the picture palette into the same entries of another palette.
  @param(startIdx The first entry.)
  @param(count The number of entries.)
  @param(dest The palette copied into.) }
procedure ShadowPaletteEntries(startIdx: Byte; count: Word; var dest: Types.TPalette);

{ Copies palette entries into the same entries of another palette; it acts only in MCGA.
  @param(first The first entry.)
  @param(count The number of entries.)
  @param(src The palette copied from.)
  @param(dst The palette copied into.) }
procedure CopyPaletteEntries(first: Byte; count: Word; var src, dst: Types.TPalette);

{ In MCGA mode, loads DAC entries from a palette on the next vertical retrace.
  @param(startIdx The first entry.)
  @param(count The number of entries.)
  @param(src The palette.) }
procedure SetDacPalette(startIdx, count: Word; src: Types.TPalette);

{ Builds the moving combat icon's four frames from an icon's tiles 0 and 1: tile 0, tile 0 mirrored, tile 1 mirrored and
  tile 1, so the second half of the cycle walks the other way.
  @param(kind The icon animation row.) }
procedure BuildIconFrames(kind: Byte);

implementation

procedure WaitRetraceStart;
begin
  repeat until (Port[$3DA] and 8) > 0;
end;

procedure WaitRetraceEnd;
begin
  repeat until (Port[$3DA] and 8) = 0;
end;

function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;
var
  mask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  transpHigh: Byte;
  bit: Byte;
  i: Byte;
begin
  mask := 0;
  bit := $80;
  for i := 0 to 7 do begin
    if chunk[i] = transpColor then Inc(mask, bit);
    bit := bit shr 1;
  end;
  ComputeMask := mask;
end;

procedure SetVideoMode(mode: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  oldMode: Byte;
begin
  GDVars.savedVideoMode := GDVars.curVideoMode;
  GDVars.interruptRegs.ah := 0;
  GDVars.interruptRegs.al := mode;
  Intr($10, Registers(GDVars.interruptRegs));
  GDVars.curVideoMode := mode;
end;

procedure RestoreVideoMode;
begin
  Blit.SetVideoMode(GDVars.savedVideoMode);
end;

procedure PreparePic(var data: Types.PBytes; hasMask, transpColor: Byte; needsAlloc: Boolean; loadedSize: Word;
                     var pic: Types.PImage);
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  j: Byte;
  { header[0] -- row count }
  picHeight: Byte;
  { header[1] -- width in cells }
  picWidth: Byte;
  { header[2] }
  picOriginX: Word;
  { header[4] }
  picOriginY: Word;
  { header[9] + 1 -- number of palette entries }
  paletteCount: Word;
  { header[8] -- first palette entry }
  firstPaletteSlot: Byte;
  { header[6] -- frame count }
  picCount: Word;
  { copied to pic^.colorMap }
  colorMapScratch: Types.TColorMap;
  { read cursor into data^ }
  readOfs: Word;
  { Unused in this version; see the other implementations of this routine. }
  colorTables: array[1..513] of Byte;
  frameSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  chunk: array[1..8] of Byte;
begin
  Move(data^[0], picHeight, SizeOf(picHeight));
  Move(data^[1], picWidth, SizeOf(picWidth));
  Move(data^[2], picOriginX, SizeOf(picOriginX));
  Move(data^[4], picOriginY, SizeOf(picOriginY));
  Move(data^[6], picCount, SizeOf(picCount));
  Move(data^[8], firstPaletteSlot, SizeOf(firstPaletteSlot));
  paletteCount := data^[9] + 1;
  Move(data^[10], GDVars.imagePal[firstPaletteSlot], paletteCount * SizeOf(Types.TRgb));
  readOfs := paletteCount * SizeOf(Types.TRgb) + 10;
  for i := 0 to (paletteCount div 2) - 1 do begin
    GDVars.palIndexMap[firstPaletteSlot + i * 2] := data^[readOfs] shr 4;
    GDVars.palIndexMap[firstPaletteSlot + i * 2 + 1] := data^[readOfs] and $0F;
    Inc(readOfs);
  end;
  if (firstPaletteSlot = 32) and (paletteCount = 112) then
    Inc(readOfs, 32)
  else
    Inc(readOfs, 4);
  if needsAlloc then
    Blit.AllocPic(picHeight, picWidth, picCount, hasMask, pic)
  else begin
    frameSize := picHeight * picWidth * 8;
    pic := Types.PImage(data);
    pic^.rows := picHeight;
    pic^.cells := picWidth;
    pic^.total := frameSize;
    pic^.frameCount := picCount;
    pic^.mask := nil;
    pic^.allocSize := loadedSize;
  end;
  with pic^ do begin
    imgOriginX := picOriginX;
    imgOriginY := picOriginY;
    keyColor := transpColor;
    colorMap := colorMapScratch;
  end;
  Blit.ExpandPicFrames(data, readOfs, hasMask, transpColor, pic);
end;

procedure LoadPic(name: String; fileId, hasMask, transpColor: Byte; var pic: Types.PImage);
var
  dataSize: Word;
  data: Types.PBytes;
begin
  if pic <> nil then Blit.FreePic(pic);
  DaxIo.LoadDax(name, '.dax', fileId, dataSize, data);
  if dataSize = 0 then Exit;
  Blit.PreparePic(data, hasMask, transpColor, GDVars.videoMode <> C_Video.DISPLAY_MCGA, dataSize, pic);
  if GDVars.videoMode <> C_Video.DISPLAY_MCGA then ZeroFree.PrefixFree(data, dataSize);
  GameIo.FlushKeys;
end;

procedure ExpandPicFrames(imgData: Types.PBytes; var srcOff: Word; hasMask, transpColor: Byte; pic: Types.PImage);
var
  { one 8-pixel source cell }
  chunk: TChunk;
  { frame being converted }
  frame: Word;
  { cell or byte within the row or frame }
  col: Word;
  { mode 0 only }
  row: Word;
  { running destination byte offset }
  dstOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  mask: Byte;
  { pixel within a cell }
  k: Byte;
  { Unused in this version; see the other implementations of this routine. }
  chunkIndex: Byte;
  { bit of the current pixel in a plane byte }
  bit: Byte;
  plane: Byte;
  { the 4-bit color of the current pixel }
  color: Byte;
  { Unused in this version; see the other implementations of this routine. }
  vgaPalette: array[1..769] of Byte;
begin
  if pic = nil then Exit;
  with pic^ do begin
    dstOff := 0;
    maskOff := 0;
    case GDVars.videoMode of
      C_Video.DISPLAY_EGA:
        { EGA planar: 8 source bytes -> 4 destination bytes, one per bit plane. The cell's mask byte is stored into all
          four plane positions, and every plane is cleared under it. }
        for frame := 1 to frameCount do
          for row := 0 to rows - 1 do
            for col := 0 to cells - 1 do begin
              Move(imgData^[srcOff], chunk, SizeOf(chunk));
              if mask <> nil then
                FillChar(mask^[dstOff], 4, Blit.ComputeMask(transpColor, chunk));
              bit := $80;
              for k := 0 to 7 do begin
                color := GDVars.palIndexMap[chunk[k]];
                for plane := 0 to 3 do
                  if (GDConsts.planeBit[plane] and color) > 0 then
                    data[plane + dstOff] := data[plane + dstOff] or bit;
                bit := bit shr 1;
              end;
              if mask <> nil then
                for plane := 0 to 3 do
                  data[plane + dstOff] := data[plane + dstOff] and not mask^[dstOff];
              Inc(dstOff, 4);
              Inc(srcOff, SizeOf(chunk));
            end;
      C_Video.DISPLAY_TANDY:
        { Tandy packed nibbles: 2 source bytes -> 1 destination byte. }
        for frame := 1 to frameCount do begin
          for col := 0 to total - 1 do begin
            data[dstOff] := (GDVars.palIndexMap[imgData^[srcOff]] shl 4) + GDVars.palIndexMap[imgData^[srcOff + 1]];
            Inc(dstOff);
            Inc(srcOff, 2);
          end;
          if mask <> nil then
            for col := 0 to dstOff - 1 do begin
              if (data[col] shr 4) = transpColor then mask^[col] := $F0;
              if (data[col] and $0F) = transpColor then Inc(mask^[col], $0F);
              data[col] := data[col] and not mask^[col];
            end;
        end;
      C_Video.DISPLAY_MCGA:
        { MCGA linear: 1 byte per pixel, a straight copy. There is no mask; MCGA draws with the record's own key color
          for transparency instead. }
        for frame := 1 to frameCount do begin
          Move(imgData^[srcOff], data[dstOff], total);
          Inc(dstOff, total);
          Inc(srcOff, total);
        end;
    end;
  end;
end;

{ The hand-coded blitters in BLIT.OBJ, all near routines.
  BlitTileCell's six draw one frame without clipping, one plain and one transparent per class:
    BlitCellEga/BlitCellEgaMasked  EGA, plain / masked
    BlitCellTandy/BlitCellTandyMasked  Tandy, plain / masked
    BlitCellVga/BlitCellVgaKeyed  MCGA, plain / color-keyed
  BlitCellVgaKeyed takes the key color before the frame number. Note: the blitters take dest's cells, its row stride,
  as a width and its rows as a height, the opposite of how PreparePic fills rows and cells. }
{$F-}
{$L BLIT.OBJ}
{ Draws a frame of a graphic opaque into an EGA buffer (four plane bytes per cell) at a character-cell position,
  unclipped, and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellEga(screenX, screenY: Integer; tileIdx: Byte; gfx: Types.PImage; dest: Types.PImage); external;

{ Draws a frame of a graphic through its transparency mask, keeping the background where the mask is set, into an EGA
  buffer (four plane bytes per cell) at a character-cell position, unclipped, and marks the touched scanlines dirty for
  FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellEgaMasked(screenX, screenY: Integer; tileIdx: Byte; gfx: Types.PImage; dest: Types.PImage); external;

{ Draws a frame of a graphic opaque into a Tandy buffer (four bytes per cell) at a character-cell position, unclipped,
  and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellTandy(screenX, screenY: Integer; tileIdx: Byte; gfx: Types.PImage; dest: Types.PImage); external;

{ Draws a frame of a graphic through its transparency mask, keeping the background where the mask is set, into a Tandy
  buffer (four bytes per cell) at a character-cell position, unclipped, and marks the touched scanlines dirty for
  FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellTandyMasked(screenX, screenY: Integer; tileIdx: Byte; gfx: Types.PImage;
                              dest: Types.PImage); external;

{ Draws a frame of a graphic opaque into a 256-color buffer (eight bytes per cell) at a character-cell position,
  unclipped, and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellVga(screenX, screenY: Integer; tileIdx: Byte; gfx: Types.PImage; dest: Types.PImage); external;

{ Draws a frame of a graphic into a 256-color buffer (eight bytes per cell) at a character-cell position, unclipped,
  keeping the background where a pixel has the transparent color, and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(transpColor The color left out.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellVgaKeyed(screenX, screenY: Integer; transpColor, tileIdx: Byte; gfx: Types.PImage;
                           dest: Types.PImage); external;

{ Draws a frame of a graphic into an EGA buffer (four plane bytes per cell) at a character-cell position, clipped
  against the buffer's edges, opaque or masked as the flags ask, and marks the touched scanlines dirty for FlushView. A
  frame lying entirely off the buffer is skipped. Note: an opaque frame cut at the left or right edge is drawn with its
  rows out of step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of the flags set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedEga(under: Types.PImage; screenX, screenY: Integer; tileIdx, flag: Byte;
                         gfx: Types.PImage; dest: Types.PImage); external;

{ Draws a frame of a graphic into a Tandy buffer (four bytes per cell) at a character-cell position, clipped against the
  buffer's edges, opaque or masked as the flags ask, and marks the touched scanlines dirty for FlushView. A frame lying
  entirely off the buffer is skipped. Note: an opaque frame cut at the left or right edge is drawn with its rows out of
  step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of the flags set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedTandy(under: Types.PImage; screenX, screenY: Integer; tileIdx, flag: Byte;
                           gfx: Types.PImage; dest: Types.PImage); external;

{ Draws a frame of a graphic into a 256-color buffer (eight bytes per cell) at a character-cell position, clipped
  against the buffer's edges, opaque or keyed on the transparent color as the flags ask, and marks the touched scanlines
  dirty for FlushView. A frame lying entirely off the buffer is skipped. Note: an opaque frame cut at the left or right
  edge is drawn with its rows out of step.
  @param(under Save-under buffer, which receives the covered bytes when drawing keyed with bit 2 of the flags set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(transpColor The color left out when drawing keyed.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(flag Bit 0 selects keyed drawing; bit 2 saves the covered bytes when drawing keyed.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedVga(under: Types.PImage; screenX, screenY: Integer; transpColor, tileIdx, flag: Byte;
                         gfx: Types.PImage; dest: Types.PImage); external;

{ Waits for vertical retrace and then loads DAC entries.
  @param(dac The first entry's color.)
  @param(first The first DAC entry.)
  @param(count The number of entries.) }
procedure ProgramPaletteOnRetrace(var dac: Types.TRgb; first, count: Word); external;
{$F+}

procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx: Types.PImage; dest: Types.PImage);
var
  { Unused in this version; see the other implementations of this routine. }
  leftSkip: Integer;
  { Unused in this version; see the other implementations of this routine. }
  rightSkip: Integer;
  { Unused in this version; see the other implementations of this routine. }
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  srcOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  destOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  lastRow: Word;
  { Unused in this version; see the other implementations of this routine. }
  y: Byte;
  useMask: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  maskOff: Word;
begin
  useMask := ((flag and 1) <> 0)
             and ((gfx^.mask <> nil) or (GDVars.videoMode = C_Video.DISPLAY_MCGA));
  case GDVars.videoMode of
    C_Video.DISPLAY_EGA: if useMask then Blit.BlitCellEgaMasked(screenX, screenY, tileIdx, gfx, dest)
                              else Blit.BlitCellEga(screenX, screenY, tileIdx, gfx, dest);
    C_Video.DISPLAY_TANDY: if useMask then Blit.BlitCellTandyMasked(screenX, screenY, tileIdx, gfx, dest)
                              else Blit.BlitCellTandy(screenX, screenY, tileIdx, gfx, dest);
    C_Video.DISPLAY_MCGA: if useMask then Blit.BlitCellVgaKeyed(screenX, screenY, gfx^.keyColor, tileIdx, gfx, dest)
                              else Blit.BlitCellVga(screenX, screenY, tileIdx, gfx, dest);
  end;
end;

procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx: Types.PImage; dest: Types.PImage);
var
  { Unused in this version; see the other implementations of this routine. }
  clipLeft: Word;
  { Unused in this version; see the other implementations of this routine. }
  clipRight: Word;
  { Unused in this version; see the other implementations of this routine. }
  leftSkip: Word;
  { Unused in this version; see the other implementations of this routine. }
  rightSkip: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskClipLeft: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskClipRight: Word;
  { Unused in this version; see the other implementations of this routine. }
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  srcOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  destOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  saveOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  lastRow: Word;
  { Unused in this version; see the other implementations of this routine. }
  y: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskOff: Word;
begin
  case GDVars.videoMode of
    C_Video.DISPLAY_EGA: Blit.BlitClippedEga(GDVars.iconSaveBuf, screenX, screenY, tileIdx, flag, gfx, dest);
    C_Video.DISPLAY_TANDY: Blit.BlitClippedTandy(GDVars.iconSaveBuf, screenX, screenY, tileIdx, flag, gfx, dest);
    C_Video.DISPLAY_MCGA: Blit.BlitClippedVga(GDVars.iconSaveBuf, screenX, screenY, gfx^.keyColor, tileIdx, flag, gfx,
                                              dest);
  end;
end;

{ Reverses the bit order of a byte, reflecting eight EGA pixels (one plane byte or mask byte) left to right.
  @param(value Byte to reflect.)
  @returns(The byte with bits 0..7 swapped with bits 7..0.) }
function MirrorBits(value: Byte): Byte;
var
  mirrored: Byte;
begin
  mirrored := value shl 7;
  Inc(mirrored, (value and 2) shl 5);
  Inc(mirrored, (value and 4) shl 3);
  Inc(mirrored, (value and 8) shl 1);
  Inc(mirrored, (value and $10) shr 1);
  Inc(mirrored, (value and $20) shr 3);
  Inc(mirrored, (value and $40) shr 5);
  Inc(mirrored, (value and $80) shr 7);
  MirrorBits := mirrored;
end;

{ Swaps the two 4-bit Tandy pixels of a byte, reflecting them left to right.
  @param(value Byte holding two pixels.)
  @returns(The byte with its nibbles exchanged.) }
function MirrorNibbles(value: Byte): Byte;
var
  mirrored: Byte;
begin
  mirrored := value shl 4;
  Inc(mirrored, (value and $F0) shr 4);
  MirrorNibbles := mirrored;
end;

procedure MirrorPic(src, dst: Types.PImage);
var
  { running destination byte offset }
  dstOff: Word;
  { source index of the current row's last atom }
  srcOff: Word;
  { dstOff at the start of this row }
  rowStart: Word;
  { bytes per row }
  rowBytes: Word;
  { atom within the row }
  col: Word;
  { row being mirrored }
  row: Word;
  { mode 0 only }
  plane: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cell: Word;
begin
  { srcOff is the source index of the row's last atom; each row is read backward from it by however much of the row has
    been written so far. }
  if (src = nil) or (dst = nil) then Exit;
  with src^ do begin
    Move(colorMap, dst^.colorMap, SizeOf(colorMap));
    case GDVars.videoMode of
      C_Video.DISPLAY_EGA:
        { EGA planar: 4 bytes per cell, 8 one-bit pixels per byte -- the row reverses and every byte's bits reverse with
          it. }
        begin
          rowBytes := cells * 4;
          srcOff := rowBytes - 4;
          dstOff := 0;
          for row := 1 to rows do begin
            rowStart := dstOff;
            for col := 1 to cells do begin
              for plane := 0 to 3 do begin
                dst^.data[plane + dstOff] := Blit.MirrorBits(data[srcOff - dstOff + rowStart + plane]);
                if mask <> nil then
                  dst^.mask^[plane + dstOff] := Blit.MirrorBits(mask^[srcOff - dstOff + rowStart + plane]);
              end;
              Inc(dstOff, 4);
            end;
            Inc(srcOff, rowBytes);
          end;
        end;
      C_Video.DISPLAY_TANDY:
        { Tandy packed nibbles: 2 four-bit pixels per byte, so the byte's nibbles swap as the row reverses. }
        begin
          rowBytes := cells * 4;
          srcOff := rowBytes - 1;
          dstOff := 0;
          for row := 1 to rows do begin
            rowStart := dstOff;
            for col := 1 to rowBytes do begin
              dst^.data[dstOff] := Blit.MirrorNibbles(data[srcOff - dstOff + rowStart]);
              if mask <> nil then
                dst^.mask^[dstOff] := Blit.MirrorNibbles(mask^[srcOff - dstOff + rowStart]);
              Inc(dstOff);
            end;
            Inc(srcOff, rowBytes);
          end;
        end;
      C_Video.DISPLAY_MCGA:
        { MCGA linear: 1 byte per pixel, so reversing the row is the whole operation. }
        begin
          rowBytes := cells * 8;
          srcOff := rowBytes - 1;
          dstOff := 0;
          for row := 1 to rows do begin
            rowStart := dstOff;
            for col := 1 to rowBytes do begin
              dst^.data[dstOff] := data[srcOff - dstOff + rowStart];
              Inc(dstOff);
            end;
            Inc(srcOff, rowBytes);
          end;
        end;
    end;
  end;
end;

procedure GrabPic(col, row: Integer; pic: Types.PImage);
var
  { mode 0 only: EGA byte column, colOff .. colEnd }
  c: Integer;
  { scanline }
  r: Integer;
  { mode 0: col; mode 1: col*4; unused in mode 2 }
  colOff: Integer;
  { row*8, the first scanline }
  firstRow: Integer;
  { mode 0 only: colOff + cells - 1 }
  colEnd: Integer;
  { firstRow + rows - 1, the last scanline }
  lastRow: Integer;
  { mode 2 only: the MCGA linear offset, advanced 320 a row }
  screenOff: Word;
  { modes 1/2: bytes copied per scanline }
  rowBytes: Word;
  { running write offset into pic^.data }
  dataOffset: Word;
  { mode 0 only: 0..3, the EGA read map }
  plane: Byte;
begin
  if pic = nil then Exit;
  with pic^ do begin
    case GDVars.videoMode of
      C_Video.DISPLAY_EGA:
        begin
          dataOffset := 0;
          firstRow := row * 8;
          lastRow := firstRow + Integer(rows) - 1;
          colOff := col;
          colEnd := colOff + Integer(cells) - 1;
          Port[$3CE] := 5;
          Port[$3CF] := 0;
          Port[$3CE] := 4;
          for r := firstRow to lastRow do
            for c := colOff to colEnd do
              for plane := 0 to 3 do begin
                Port[$3CF] := plane;
                pic^.data[dataOffset] := Mem[$A000 : GDVars.fbRowOfs[r] + c];
                Inc(dataOffset);
              end;
          Port[$3CF] := 0;
          Port[$3CE] := 5;
          Port[$3CF] := 0;
        end;
      C_Video.DISPLAY_MCGA:
        begin
          screenOff := row * 8 * 320 + col * 8;
          dataOffset := 0;
          rowBytes := cells * 8;
          firstRow := row * 8;
          lastRow := firstRow + Integer(rows) - 1;
          for r := firstRow to lastRow do begin
            Move(Types.PBytes(C_Video.VGA_BASE + LongInt(screenOff))^, pic^.data[dataOffset], rowBytes);
            Inc(dataOffset, rowBytes);
            Inc(screenOff, 320);
          end;
        end;
      C_Video.DISPLAY_TANDY:
        begin
          rowBytes := cells * 4;
          dataOffset := 0;
          firstRow := row * 8;
          lastRow := firstRow + Integer(rows) - 1;
          colOff := col * 4;
          for r := firstRow to lastRow do begin
            Move(Mem[GDVars.tandyRowSeg[r] : colOff], pic^.data[dataOffset], rowBytes);
            Inc(dataOffset, rowBytes);
          end;
        end;
    end;
  end;
end;

procedure ShowPic(screenX, screenY: Integer; pic: Types.PImage);
var
  { mode 0 only: EGA byte column, colOff .. colEnd }
  col: Integer;
  { scanline }
  row: Integer;
  { mode 0: screenX; mode 1: screenX*4; mode 2: screenX*8 }
  colOff: Word;
  { screenY*8, the first scanline }
  firstRow: Word;
  { mode 0 only: colOff + cells - 1 }
  colEnd: Word;
  { firstRow + rows - 1, the last scanline }
  lastRow: Word;
  { modes 1/2: bytes copied per scanline }
  rowBytes: Word;
  { running read offset into pic^.data }
  srcOff: Word;
  { mode 0 only: 0..3, the EGA write plane }
  plane: Byte;
begin
  if pic = nil then Exit;
  with pic^ do begin
    case GDVars.videoMode of
      C_Video.DISPLAY_EGA:
        begin
          srcOff := 0;
          firstRow := screenY * 8;
          lastRow := firstRow + rows - 1;
          colOff := screenX;
          colEnd := colOff + cells - 1;
          Port[$3C4] := 2;
          for row := firstRow to lastRow do
            for col := colOff to colEnd do
              for plane := 0 to 3 do begin
                Port[$3C5] := GDConsts.planeBit[plane];
                Mem[$A000 : GDVars.fbRowOfs[row] + col] := pic^.data[srcOff];
                Inc(srcOff);
              end;
          Port[$3C5] := $0F;
        end;
      C_Video.DISPLAY_TANDY:
        begin
          rowBytes := cells * 4;
          srcOff := 0;
          firstRow := screenY * 8;
          lastRow := firstRow + rows - 1;
          colOff := screenX * 4;
          for row := firstRow to lastRow do begin
            Move(pic^.data[srcOff], Mem[GDVars.tandyRowSeg[row] : colOff], rowBytes);
            Inc(srcOff, rowBytes);
          end;
        end;
      C_Video.DISPLAY_MCGA:
        begin
          rowBytes := cells * 8;
          srcOff := 0;
          firstRow := screenY * 8;
          lastRow := firstRow + rows - 1;
          colOff := screenX * 8;
          for row := firstRow to lastRow do begin
            Move(pic^.data[srcOff], Mem[$A000 : colOff + 320 * row], rowBytes);
            Inc(srcOff, rowBytes);
          end;
        end;
    end;
  end;
end;

procedure FlushView;
var
  { span slot = view surface row }
  row: Word;
  { byte cursor into the surface data }
  srcOff: Word;
  { byte cursor / row base in video memory }
  dstOff: Word;
  { mode 0: the row's base in the staging page }
  dstBase: Word;
  { Unused in this version; see the other implementations of this routine. }
  plane: Word;
  { Unused in this version; see the other implementations of this routine. }
  spanBuf: array[1..256] of Byte;
begin
  { An EGA cell is four interleaved plane bytes, so an EGA run covers (hi - lo) div 4 + 1 screen bytes; Tandy and MCGA
    copy hi - lo + 1 bytes. }
  Mouse.HideMouse;
  case GDVars.videoMode of
    C_Video.DISPLAY_EGA:
      begin
        Port[$3C4] := 2;
        for row := 0 to 167 do
          if GDVars.spanRowActive[row] <> 0 then begin
            dstBase := GDVars.fbRowOfs[row + 8] + GDVars.spanScreenOfs[row] + 1;
            Port[$3C5] := GDConsts.planeBit[0];
            srcOff := GDVars.spanFirstOfs[row];
            dstOff := dstBase;
            repeat
              Mem[$A200 : dstOff] := GDVars.viewImageBuf^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff);
            until srcOff > GDVars.spanLastOfs[row];
            Port[$3C5] := GDConsts.planeBit[1];
            srcOff := GDVars.spanFirstOfs[row] + 1;
            dstOff := dstBase;
            repeat
              Mem[$A200 : dstOff] := GDVars.viewImageBuf^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff);
            until srcOff > GDVars.spanLastOfs[row];
            Port[$3C5] := GDConsts.planeBit[2];
            srcOff := GDVars.spanFirstOfs[row] + 2;
            dstOff := dstBase;
            repeat
              Mem[$A200 : dstOff] := GDVars.viewImageBuf^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff);
            until srcOff > GDVars.spanLastOfs[row];
            Port[$3C5] := GDConsts.planeBit[3];
            srcOff := GDVars.spanFirstOfs[row] + 3;
            dstOff := dstBase;
            repeat
              Mem[$A200 : dstOff] := GDVars.viewImageBuf^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff);
            until srcOff > GDVars.spanLastOfs[row];
          end;
        Port[$3C5] := $0F;
        dstOff := GDVars.fbRowOfs[8] + 1;
        Port[$3CE] := 5;
        Port[$3CF] := 1;
        for row := 0 to 167 do begin
          if GDVars.spanRowActive[row] <> 0 then
            Move(Mem[$A200 : dstOff + GDVars.spanScreenOfs[row]], Mem[$A000 : dstOff + GDVars.spanScreenOfs[row]],
                 (GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row]) div 4 + 1);
          Inc(dstOff, 40);
        end;
        Port[$3CF] := 0;
      end;
    C_Video.DISPLAY_TANDY:
      for row := 0 to 167 do
        if GDVars.spanRowActive[row] <> 0 then
          Move(GDVars.viewImageBuf^.data[GDVars.spanFirstOfs[row]],
               Mem[GDVars.tandyRowSeg[row + 8] : GDVars.spanScreenOfs[row] + 4],
               GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row] + 1);
    C_Video.DISPLAY_MCGA:
      for row := 0 to 167 do
        if GDVars.spanRowActive[row] <> 0 then
          Move(GDVars.viewImageBuf^.data[GDVars.spanFirstOfs[row]],
               Types.PBytes(C_Video.VGA_BASE + (row + 8) * 320 + GDVars.spanScreenOfs[row] + 8)^,
               GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row] + 1);
  end;
  GameIo.ZeroFill(GDVars.spanRowActive, SizeOf(GDVars.spanRowActive));
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  GameIo.ZeroFill(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs));
  Mouse.ShowMouse;
end;

procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImage);
var
  { byte cursor into pic^.data }
  srcOff: Word;
  { byte cursor into scratchPic^.data }
  dstOff: Word;
  { 1, or pic^.frameCount when frame < 0 }
  nFrames: Byte;
  { 1..cells, or 1..rowBytes }
  col: Word;
  { 1..rows }
  row: Word;
  { mode 0: the cell's match mask }
  match: Byte;
  { 0 where fromColors[pairIdx] has the plane bit, $FF where it does not }
  planeMask: array[0..3] of Byte;
  plane: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cellByte: Byte;
  { Unused in this version; see the other implementations of this routine. }
  pixPos: Byte;
  { mode 1: cells*4; mode 2: cells*8 }
  rowBytes: Word;
  { mode 1 only: fromColors[pairIdx] shl 4 }
  fromHigh: Byte;
  { mode 1 only: toColors[pairIdx] shl 4 }
  toHigh: Byte;
  { the color-map entry, 0..15 }
  pairIdx: Byte;
  { the scratch image }
  scratchPic: Types.PImage;
begin
  { Inside the case, the bare field names are the scratch image's; the source pixels are always read as pic^.data. }
  if pic = nil then Exit;
  with pic^ do begin
    if frame < 0 then begin
      frame := 0;
      nFrames := frameCount;
    end else
      nFrames := 1;
    srcOff := frame * total;
    dstOff := 0;
  end;
  Blit.AllocPic(pic^.rows, pic^.cells, nFrames, 0, scratchPic);
  scratchPic^.colorMap := pic^.colorMap;
  Move(pic^.data[srcOff], scratchPic^.data[dstOff], scratchPic^.total * scratchPic^.frameCount);
  for pairIdx := 0 to 15 do begin
    with pic^ do begin
      if frame < 0 then begin
        frame := 0;
        nFrames := frameCount;
      end else
        nFrames := 1;
      srcOff := frame * total;
      dstOff := 0;
    end;
    if fromColors[pairIdx] <> toColors[pairIdx] then
    with scratchPic^ do
      case GDVars.videoMode of
        C_Video.DISPLAY_EGA:
          begin
            for plane := 0 to 3 do
              if (fromColors[pairIdx] and GDConsts.planeBit[plane]) > 0 then
                planeMask[plane] := 0
              else
                planeMask[plane] := $FF;
            for GDVars.scratchIndex := frame to nFrames + frame - 1 do
              for row := 1 to rows do
                for col := 1 to cells do begin
                  if isDithered then
                    match := Random(256) and Random(256)
                  else
                    match := $FF;
                  for plane := 0 to 3 do
                    match := (pic^.data[plane + srcOff] xor planeMask[plane]) and match;
                  for plane := 0 to 3 do
                    if (toColors[pairIdx] and GDConsts.planeBit[plane]) > 0 then
                      data[plane + dstOff] := data[plane + dstOff] or match
                    else
                      data[plane + dstOff] := data[plane + dstOff] and not match;
                  Inc(srcOff, 4);
                  Inc(dstOff, 4);
                end;
          end;
        C_Video.DISPLAY_TANDY:
          begin
            rowBytes := cells * 4;
            fromHigh := fromColors[pairIdx] shl 4;
            toHigh := toColors[pairIdx] shl 4;
            for GDVars.scratchIndex := frame to nFrames + frame - 1 do
              for row := 1 to rows do
                for col := 1 to rowBytes do begin
                  if (pic^.data[srcOff] and $F0) = fromHigh then
                    if (not isDithered) or (isDithered and (Random(4) = 0)) then
                      data[dstOff] := (data[dstOff] and $0F) or toHigh;
                  if (pic^.data[srcOff] and $0F) = fromColors[pairIdx] then
                    if (not isDithered) or (isDithered and (Random(4) = 0)) then
                      data[dstOff] := (data[dstOff] and $F0) or toColors[pairIdx];
                  Inc(srcOff);
                  Inc(dstOff);
                end;
          end;
        C_Video.DISPLAY_MCGA:
          begin
            rowBytes := cells * 8;
            for GDVars.scratchIndex := frame to nFrames + frame - 1 do
              for row := 1 to rows do
                for col := 1 to rowBytes do begin
                  if (pic^.data[srcOff] = fromColors[pairIdx]) and (fromColors[pairIdx] <> keyColor) then
                    data[dstOff] := toColors[pairIdx];
                  Inc(srcOff);
                  Inc(dstOff);
                end;
          end;
      end;
  end;
  with pic^ do
    Move(scratchPic^.data[0], data[frame * total], nFrames * total);
  Blit.FreePic(scratchPic);
end;

procedure AllocPic(height, width, count: Word; flag: Byte; var pic: Types.PImage);
var
  { one frame's bytes, height*width*cellSize }
  frameSize: Word;
  { every frame, frameSize*count }
  totalSize: Word;
  { 8 for MCGA, 4 otherwise }
  cellSize: Byte;
begin
  case GDVars.videoMode of
    C_Video.DISPLAY_MCGA: cellSize := 8;
  else
    cellSize := 4;
  end;
  frameSize := height * width * cellSize;
  totalSize := frameSize * count;
  GetMem(pic, totalSize + (SizeOf(Types.TImage) - SizeOf(pic^.data)));
  GameIo.ZeroFill(pic^, totalSize + (SizeOf(Types.TImage) - SizeOf(pic^.data)));
  pic^.rows := height;
  pic^.cells := width;
  pic^.total := frameSize;
  pic^.frameCount := count;
  pic^.allocSize := totalSize + (SizeOf(Types.TImage) - SizeOf(pic^.data));
  if ((flag and 1) > 0) and (GDVars.videoMode <> C_Video.DISPLAY_MCGA) then begin
    GetMem(pic^.mask, totalSize);
    GameIo.ZeroFill(pic^.mask^, totalSize);
  end;
end;

procedure FreePic(var p: Types.PImage);
begin
  if p = nil then Exit;
  with p^ do begin
    if mask <> nil then
      ZeroFree.PrefixFree(mask, total * frameCount);
    ZeroFree.PrefixFree(p, allocSize);
  end;
  p := nil;
end;

procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap; pic: Types.PImage);
var
  { 4 (Tandy) or 8 (MCGA) bytes per cell }
  cellSize: Word;
  { cells clipped off the left edge }
  clipLeft: Word;
  { cells clipped off the right edge }
  clipRight: Word;
  { first visible column, later scaled }
  clampedX: Word;
  { per-row tail advance, later scaled }
  rightMargin: Word;
  { the run: cells in mode 0, bytes in 1/2 }
  runLen: Word;
  { the row loop's upper bound }
  lastRow: Word;
  { running byte offset into pic^.data }
  dstOff: Word;
  row: Word;
  { $FF where color lights that EGA plane }
  planeMask: array[0..3] of Byte;
  { the span slot = the surface row }
  absRow: Word;
  { the value written into GDVars.spanScreenOfs[] }
  screenOfs: Word;
  plane: Byte;
begin
  { Per surviving row: mark the row active, advance to the run, lower GDVars.spanFirstOfs (and set GDVars.spanScreenOfs)
    if the run starts earlier, fill the run in the class's own pixel format, raise GDVars.spanLastOfs to the run's last
    byte, then advance over the rest of the surface row. In Tandy and MCGA the column values are scaled to bytes before
    screenOfs is taken; in EGA screenOfs stays in cells. }
  if pic = nil then Exit;

  if x < 0 then begin clipLeft := Abs(x); clampedX := 0 end
           else begin clipLeft := 0; clampedX := x end;

  if pic^.cells < x + width then
    begin clipRight := (x + width) - pic^.cells; rightMargin := 0 end
  else
    begin clipRight := 0; rightMargin := pic^.cells - (x + width) end;

  if y < 0 then begin
    dstOff := 0;
    absRow := 0;
    lastRow := height - Abs(y);
  end else begin
    absRow := y;
    dstOff := absRow * pic^.cells;
    lastRow := height - 1;
    if pic^.rows < y + height then lastRow := pic^.rows - 1 - y
                              else lastRow := height - 1;
  end;

  case GDVars.videoMode of
    C_Video.DISPLAY_TANDY, C_Video.DISPLAY_MCGA:
      begin
        case GDVars.videoMode of
          { Tandy packed 4bpp: 4 bytes per 8-px cell }
          C_Video.DISPLAY_TANDY: cellSize := 4;
          { MCGA chunky 8bpp: 8 bytes per 8-px cell }
          C_Video.DISPLAY_MCGA: cellSize := 8;
        end;
        runLen := (width - clipLeft - clipRight) * cellSize;
        clampedX := clampedX * cellSize;
        rightMargin := rightMargin * cellSize;
        dstOff := dstOff * cellSize;
        screenOfs := clampedX;
        for row := 0 to lastRow do begin
          GDVars.spanRowActive[absRow] := 1;
          Inc(dstOff, clampedX);
          if GDVars.spanFirstOfs[absRow] > dstOff then begin
            GDVars.spanScreenOfs[absRow] := screenOfs;
            GDVars.spanFirstOfs[absRow] := dstOff;
          end;
          case GDVars.videoMode of
            C_Video.DISPLAY_TANDY: FillChar(pic^.data[dstOff], runLen, GDConsts.tandyDup[color]);
            C_Video.DISPLAY_MCGA: FillChar(pic^.data[dstOff], runLen, color);
          end;
          Inc(dstOff, runLen);
          if dstOff - 1 > GDVars.spanLastOfs[absRow] then GDVars.spanLastOfs[absRow] := dstOff - 1;
          Inc(dstOff, rightMargin);
          Inc(absRow);
        end;
      end;
    C_Video.DISPLAY_EGA:
      begin
        { unscaled -- EGA is one byte per plane }
        screenOfs := clampedX;
        { in cells }
        runLen := width - clipLeft - clipRight;
        clampedX := clampedX * 4;
        rightMargin := rightMargin * 4;
        dstOff := dstOff * 4;
        GameIo.ZeroFill(planeMask, SizeOf(planeMask));
        for plane := 0 to 3 do
          if (GDConsts.planeBit[plane] and color) > 0 then planeMask[plane] := $FF;
        for row := 0 to lastRow do begin
          GDVars.spanRowActive[absRow] := 1;
          Inc(dstOff, clampedX);
          if GDVars.spanFirstOfs[absRow] > dstOff then begin
            GDVars.spanScreenOfs[absRow] := screenOfs;
            GDVars.spanFirstOfs[absRow] := dstOff;
          end;
          for GDVars.scratchIndex := 1 to runLen do begin
            Move(planeMask, pic^.data[dstOff], SizeOf(planeMask));
            Inc(dstOff, SizeOf(planeMask));
          end;
          if dstOff - 1 > GDVars.spanLastOfs[absRow] then GDVars.spanLastOfs[absRow] := dstOff - 1;
          Inc(dstOff, rightMargin);
          Inc(absRow);
        end;
      end;
  end;
end;

procedure ShadowPaletteEntries(startIdx: Byte; count: Word; var dest: Types.TPalette);
begin
  if GDVars.videoMode <> C_Video.DISPLAY_MCGA then Exit;
  Move(GDVars.imagePal[startIdx], dest[startIdx], count * 3);
end;

procedure CopyPaletteEntries(first: Byte; count: Word; var src, dst: Types.TPalette);
begin
  if GDVars.videoMode <> C_Video.DISPLAY_MCGA then Exit;
  Move(src[first], dst[first], count * 3);
end;

procedure SetDacPalette(startIdx, count: Word; src: Types.TPalette);
var
  { Unused in this version; see the other implementations of this routine. }
  runLength: Word;
  { Unused in this version; see the other implementations of this routine. }
  videoRegs: Registers;
  { Unused in this version; see the other implementations of this routine. }
  scratchSeg: Word;
  { Unused in this version; see the other implementations of this routine. }
  scratchOfs: Word;
begin
  if GDVars.videoMode = C_Video.DISPLAY_MCGA then Blit.ProgramPaletteOnRetrace(src[startIdx], startIdx, count);
  scratchSeg := Seg(src);
  scratchOfs := Ofs(src);
end;

{ Copies a tile of an icon into a frame of the moving combat icon, mirrored when asked, together with its mask, when it
  has one, and its key color. Mirroring goes through a scratch image of 24 rows by 3 cells, the combat icon size, which
  has a mask outside the 256-color mode. Note: the key color always comes from the icon's own image, even in the
  mirrored case.
  @param(kind The icon animation row.)
  @param(tileIdx The icon's tile.)
  @param(frame The frame of the moving icon filled.)
  @param(isMirrored Set to mirror the tile.) }
procedure CopyIconTile(kind, tileIdx, frame, isMirrored: Byte);
var
  { the scratch image, mirror case only }
  tmp: Types.PImage;
  { GDVars.moveIconSheet^.total, one frame's bytes }
  frameSize: Word;
  { frame * frameSize }
  frameOfs: Word;
begin
  frameSize := GDVars.moveIconSheet^.total;
  frameOfs := frame * frameSize;
  if isMirrored <> 0 then begin
    Blit.AllocPic(24, 3, 1, 1, tmp);
    Blit.MirrorPic(GDVars.iconAnimTable[kind, tileIdx], tmp);
    Move(tmp^.data, GDVars.moveIconSheet^.data[frameOfs], frameSize);
    GDVars.moveIconSheet^.keyColor := GDVars.iconAnimTable[kind, tileIdx]^.keyColor;
    if tmp^.mask <> nil then
      Move(tmp^.mask^, GDVars.moveIconSheet^.mask^[frameOfs], frameSize);
    Blit.FreePic(tmp);
  end else begin
    Move(GDVars.iconAnimTable[kind, tileIdx]^.data, GDVars.moveIconSheet^.data[frameOfs], frameSize);
    GDVars.moveIconSheet^.keyColor := GDVars.iconAnimTable[kind, tileIdx]^.keyColor;
    if GDVars.iconAnimTable[kind, tileIdx]^.mask <> nil then
      Move(GDVars.iconAnimTable[kind, tileIdx]^.mask^, GDVars.moveIconSheet^.mask^[frameOfs], frameSize);
  end;
end;

procedure BuildIconFrames(kind: Byte);
begin
  Blit.CopyIconTile(kind, 0, 0, 0);
  Blit.CopyIconTile(kind, 0, 1, 1);
  Blit.CopyIconTile(kind, 1, 2, 1);
  Blit.CopyIconTile(kind, 1, 3, 0);
end;

begin
end.
