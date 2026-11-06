{ The 8x8 symbol sets: the two dungeon sets and the border set. Loads a set, draws one symbol by its global number, and
  draws the straight frame segments the Border unit lays out. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Sym8x8;

interface

{ Loads a symbol set from a picture of its file (8X8D0 and 8X8D1 for the dungeon sets, BORDERS for the border set),
  transparent in light magenta, then flushes pending keystrokes. A setId above 2 does nothing. A failed load shows the
  error in text mode and quits the game after a key. Note: RestoreVideoMode runs twice on that path.
  @param(fileId Picture number within the file.)
  @param(setId Symbol set: 0 and 1 the dungeon sets, 2 the borders.) }
procedure Load8x8Set(fileId, setId: Byte);

{ Draws a symbol at a character cell, finding the set whose range holds it. Symbol 0, a symbol past the last set and a
  symbol in an unloaded set draw nothing.
  @param(col Column, in character cells.)
  @param(row Row, in character cells.)
  @param(symbol Global symbol number, which picks its set.)
  @param(directBlit True to blit the symbol into the view buffer; False to copy it through GDVars.current8x8Symbol
    straight to the screen.)
  @param(useMask With directBlit, True draws through the symbol's mask.) }
procedure Put8x8Sym(col, row: ShortInt; symbol: Word; directBlit, useMask: Boolean);

{ Draws a horizontal (y1 = y2) or vertical frame segment out of border symbols on the screen: capStart at the first
  cell, the straight piece along the middle and capEnd at the last. Note: a segment shorter than three cells gets no end
  cap, and a one-cell segment also draws a straight piece past its end.
  @param(x1 The column of one end.)
  @param(y1 The row of one end.)
  @param(x2 The column of the other end.)
  @param(y2 The row of the other end.)
  @param(capStart The first cell's symbol, counted from the border set's first.)
  @param(capEnd The last cell's symbol, likewise.) }
procedure DrawBorderRun(x1, y1, x2, y2: ShortInt; capStart, capEnd: Byte);

implementation

uses Blit, GameIo, GDConsts, GDVars, Types;

const
  { symbol sets }
  DUNGEON_SET_0 = 1;
  BORDER_SET = 2;
  { DrawBorderRun's cell kinds }
  CELL_SKIP = 0;
  CELL_MIDDLE = 1;
  CELL_START = 2;
  CELL_END = 3;
  { DrawBorderRun's orientations, added to the first straight border symbol }
  ORIENTATION_HORIZONTAL = 0;
  ORIENTATION_VERTICAL = 1;

procedure Load8x8Set(fileId, setId: Byte);
var
  fileName: String[8];
  { Unused in this version; see the other implementations of this routine. }
  result: Word;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if setId in [0..2] then begin
    if setId = Sym8x8.BORDER_SET then
      fileName := 'borders'
    else if setId = Sym8x8.DUNGEON_SET_0 then
      fileName := '8x8d0'
    else
      { DUNGEON_SET_1 }
      fileName := '8x8d1';
    Blit.LoadPic(fileName, fileId, 1, 13, GDVars.symbolSets[setId]);
    if GDVars.symbolSets[setId] = nil then begin
      Blit.RestoreVideoMode;
      WriteLn('Unable to load ', fileId, ' from ' + fileName);
      ch := GameIo.ReadGameKey;
      Blit.RestoreVideoMode;
      GameIo.ExitGame(0);
    end;
    GameIo.FlushKeys;
  end;
end;

procedure Put8x8Sym(col, row: ShortInt; symbol: Word; directBlit, useMask: Boolean);
var
  setIdx: Byte;
begin
  setIdx := 0;
  { Note: a symbol past the last set reads the ceilings beyond the table before the bound check rejects it. }
  while GDConsts.symbolSetCeiling[setIdx] < symbol do
    Inc(setIdx);
  if (symbol = 0) or (setIdx > 2) then
    Exit;
  if GDVars.symbolSets[setIdx] <> nil then begin
      Dec(symbol, GDConsts.symbolSetBase[setIdx]);
      if directBlit then
        Blit.BlitTileCell(col, row, symbol, Ord(useMask), GDVars.symbolSets[setIdx], GDVars.viewImageBuf)
      else begin
        with GDVars.symbolSets[setIdx]^ do
          Move(data[symbol * total], GDVars.current8x8Symbol^.data, total);
        Blit.ShowPic(col, row, GDVars.current8x8Symbol);
      end;
  end;
end;

procedure DrawBorderRun(x1, y1, x2, y2: ShortInt; capStart, capEnd: Byte);
var
  orientation: Byte;
  remaining: ShortInt;

  { Draw one cell of the segment and step to the next. }
  procedure EmitBorderCell(kind: Byte);
  var glyph: ShortInt;
  begin
    case kind of
      Sym8x8.CELL_SKIP: glyph := -1;
      Sym8x8.CELL_MIDDLE: glyph := orientation + 4;
      Sym8x8.CELL_START: glyph := capStart;
      Sym8x8.CELL_END: glyph := capEnd;
    end;
    if glyph >= 0 then
      Sym8x8.Put8x8Sym(x1, y1, glyph + GDConsts.symbolSetBase[Sym8x8.BORDER_SET], False, False);
    if orientation <> Sym8x8.ORIENTATION_HORIZONTAL then
      Inc(y1)
    else
      Inc(x1);
    Dec(remaining);
  end;

begin
  if y1 = y2 then begin
    orientation := Sym8x8.ORIENTATION_HORIZONTAL;
    if x1 > x2 then begin
      remaining := x1; x1 := x2; x2 := remaining;
    end;
    remaining := x2 - x1 + 1;
  end else begin
    orientation := Sym8x8.ORIENTATION_VERTICAL;
    if y1 > y2 then begin
      remaining := y1; y1 := y2; y2 := remaining;
    end;
    remaining := y2 - y1 + 1;
  end;
  EmitBorderCell(Sym8x8.CELL_START);
  EmitBorderCell(Sym8x8.CELL_MIDDLE);
  while remaining > 2 do
    EmitBorderCell(Sym8x8.CELL_MIDDLE);
  if remaining = 2 then
    EmitBorderCell(Sym8x8.CELL_MIDDLE);
  if remaining = 1 then
    EmitBorderCell(Sym8x8.CELL_END);
end;

begin
end.
