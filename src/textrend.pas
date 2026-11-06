{ Character renderer and page control. Draws 8x8 font glyphs in each of the three display modes -- 0 = EGA planar, 1 =
  Tandy 4-bank, 2 = MCGA linear -- through a hand-written assembler blitter per mode, and builds the text services on
  top of them: strings, word-wrapped paragraphs, the status-line prompts and messages, line and number input, and screen
  and rectangle clears.

  The routines that bracket their work with HideMouse/ShowMouse test their bounds after hiding the cursor. Note: an
  out-of-range call returns with the mouse cursor still hidden. }
{$O+,F+,S-,R-,V-,B-,I-}
unit TextRend;

interface

uses Dos, Crt, DaxIo, ZeroFree, GameIo, Mouse, Types, GDConsts, GDVars, C_Keys, C_Video;

{ The Tandy/PCjr frame buffer: four interleaved banks, each 50 rows of 160 bytes. }
type
  TTandyBank = array[0..49, 0..159] of Byte;
var
  tandyBank0: TTandyBank absolute $B800:0000;
  tandyBank1: TTandyBank absolute $BA00:0000;
  tandyBank2: TTandyBank absolute $BC00:0000;
  tandyBank3: TTandyBank absolute $BE00:0000;

{ Shows an EGA page (video BIOS function 5) and records its segment as the current page.
  @param(page The page to show.) }
procedure SetupEgaCurrentPage(page: Byte);

{ Records an EGA page's segment as the other page.
  @param(page The page.) }
procedure SetupEgaOtherPage(page: Byte);

{ Fills a character-cell rectangle of an EGA page with one color in write mode 2, then restores write mode 0 and points
  the other page back at the page number saved for it.
  @param(x1 Left column.)
  @param(y1 Top row.)
  @param(x2 Right column.)
  @param(y2 Bottom row.)
  @param(page The EGA page to fill.)
  @param(value The fill color.) }
procedure FillRectEga(x1, y1, x2, y2: ShortInt; page, value: Byte);

{ Loads the 64-glyph 8x8 font (8X8D0.DAX, block 201) into the buffer GDVars.gameFont already points at, then frees the
  loader's temporary block. Does nothing if the block cannot be read. }
procedure LoadGameFont;

{ Draws a character several times, advancing one column each time. Off-screen cells and a missing font are ignored.
  @param(col The first column.)
  @param(row The row.)
  @param(fg The foreground color.)
  @param(bg The background color.)
  @param(count The number of copies.)
  @param(ch The character.)
  @param(xlat True upper-cases the character and folds it into the 64-glyph font; False uses it as the glyph index.) }
procedure RenderChar(col, row, fg, bg, count: Byte; ch: Char; xlat: Boolean);

{ Blanks a run of cells with the mouse cursor hidden. Note: a first cell off the screen exits early and leaves the mouse
  hidden.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(color The color to blank to.)
  @param(count The number of cells.) }
procedure PrintSpaces(col, row, color, count: Byte);

{ Writes a string from a cell, one character per cell, with the mouse cursor hidden; characters off the screen are not
  drawn. Note: a column above 39 or a row above 39 exits early and leaves the mouse hidden.
  @param(col The first character's column.)
  @param(row The row.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(s The text.) }
procedure DisplayString(col, row, fg, bg: Byte; s: String);

{ Writes a string word-wrapped into a window, from the text cursor when it is inside the window, else, or after clearing
  when asked, from the top left. Punctuation stays with the word next to it. Characters appear one by one with a delay
  while slow text is on. When the window fills with text left over, it waits for a key and goes on in the cleared
  window. The text cursor is left after the text. Note: the check meant to keep a word whose trailing space alone
  overruns the right edge can never hold, so such a word wraps as well; and a window edge off the screen exits early
  with the mouse left hidden.
  @param(x1 Left column of the window.)
  @param(y1 Top row of the window.)
  @param(x2 Right column of the window.)
  @param(y2 Bottom row of the window.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(clearFirst True to clear the window and start at its top left.)
  @param(s The text.) }
procedure DisplayMessageWindow(x1, y1, x2, y2, fg, bg: Byte; clearFirst: Boolean; s: String);

{ Reads a line on the status row under a prompt, echoing as it goes. Backspace deletes, the numeric keypad types digits,
  a leading space is refused, and Enter or Esc ends the line, as does the input-abort flag. Note: the keypad-5 arm tests
  scancode $20 (Alt-D) instead of $4C, so keypad 5 does not type '5' and Alt-D does.
  @param(prompt The prompt.)
  @param(fg The prompt's foreground color.)
  @param(bg The prompt's background color.)
  @param(maxLen The most characters accepted.)
  @returns(The line, trailing spaces trimmed and upper-cased.) }
function ReadString(prompt: Types.TStr40; fg, bg, maxLen: Byte): Types.TStr40;

{ Reads a non-negative number through ReadString, prompting again until the entry is all digits and converts cleanly.
  Note: the upper-bound test can never be true; the sign test does the work.
  @param(prompt The prompt.)
  @param(fg The prompt's foreground color.)
  @param(bg The prompt's background color.)
  @param(maxLen The most digits accepted.)
  @returns(The number; 0 for an empty entry.) }
function ReadNumber(prompt: Types.TStr40; fg, bg, maxLen: Byte): LongInt;

{ Shows a message on the status row and waits for Enter or Esc, then, with a mouse present, for all buttons to be
  released.
  @param(fg The foreground color.)
  @param(bg The background color.)
  @param(msg The message.) }
procedure DisplayAndPause(fg, bg: Byte; msg: Types.TStr40);

{ Reads the time of day.
  @returns(The time since midnight in hundredths of a second.) }
function GetTicks: LongInt;

{ Clears the whole screen in the current display mode: both EGA pages, the MCGA frame, or all four Tandy banks. }
procedure ClearScreen;

{ Shows a message on the bottom row for the game-speed pause (PauseOnly), then clears the row.
  @param(msg The message.)
  @param(fg The text color.)
  @param(bg The background color.) }
procedure PrintAndPause(msg: Types.TStr40; fg, bg: Byte);

{ Waits for the game-speed setting times 100 milliseconds. }
procedure PauseOnly;

{ Clears a rectangle of character cells to color 0.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearRect(ulCol, ulRow, lrCol, lrRow: Byte);

{ Shows the loading banner on the status row, clearing columns 21..39 first. }
procedure DisplayLoading;

{ Clears the whole status row. }
procedure ClearStatusLine;

{ Formats a Byte as decimal.
  @param(n The number.)
  @returns(Its decimal string.) }
function NumToStr(n: Byte): String;

{ Right-aligns a string in a field by adding spaces on the left.
  @param(s The string, padded in place.)
  @param(n The field width.) }
procedure RightAlignString(var s: Types.TStr40; n: Byte);

implementation

const
  { the Ins key's extended scan code }
  KEY_INS = #82;

{ The three glyph blitters, in textrend.asm. Each draws one glyph at a character cell in foreground and background
  colors. The EGA and Tandy blitters are near procedures and the MCGA one is far. The EGA and Tandy blitters read the
  staged rows from GDVars.glyphRowBuf; the MCGA blitter reads the font through GDVars.gameFont. textrend.asm refers to
  GDVars.gameFont and GDVars.glyphRowBuf by name. }
{$F-}
{$L TEXTREND.OBJ}

{ Draws one character cell on EGA from the glyph rows that RenderChar staged.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(glyph Unused.) }
procedure EgaGlyph(col, row: Word; fg, bg, glyph: Byte); external;

{ Draws one character cell on Tandy from the glyph rows that RenderChar staged.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(glyph Unused.) }
procedure TandyGlyph(col, row: Word; fg, bg, glyph: Byte); external;

{$F+}
{ Draws one 8x8 glyph in VGA mode 13h, reading it from the font.
  @param(col The text cell's column.)
  @param(row The text cell's row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(glyph The glyph number.) }
procedure VgaGlyph(col, row: Word; fg, bg, glyph: Byte); external;

{ Resets the EGA Graphics Controller and Sequencer to their defaults: no set/reset, no rotate, write mode 0, all bits
  and all planes enabled. }
procedure ResetEgaGc;
begin
  { GC index 0 -- Set/Reset }
  Port[$3CE] := 0;
  Port[$3CF] := 0;
  { GC index 1 -- Enable Set/Reset }
  Port[$3CE] := 1;
  Port[$3CF] := 0;
  { GC index 2 -- Color Compare }
  Port[$3CE] := 2;
  Port[$3CF] := 0;
  { GC index 3 -- Data Rotate }
  Port[$3CE] := 3;
  Port[$3CF] := 0;
  { GC index 4 -- Read Map Select }
  Port[$3CE] := 4;
  Port[$3CF] := 0;
  { GC index 5 -- Mode }
  Port[$3CE] := 5;
  Port[$3CF] := 0;
  { GC index 7 -- Color Don't Care }
  Port[$3CE] := 7;
  Port[$3CF] := $0F;
  { GC index 8 -- Bit Mask }
  Port[$3CE] := 8;
  Port[$3CF] := $FF;
  { SEQ index 2 -- Map Mask }
  Port[$3C4] := 2;
  Port[$3C5] := $0F;
end;

procedure SetupEgaCurrentPage(page: Byte);
begin
  { INT 10h AH=5 -- select active display page }
  GDVars.interruptRegs.ah := 5;
  GDVars.interruptRegs.al := page;
  Intr($10, Registers(GDVars.interruptRegs));
  GDVars.egaCurPage := $A000 + (page shl 9);
end;

procedure SetupEgaOtherPage(page: Byte);
begin
  GDVars.egaOtherPage := $A000 + (page shl 9);
end;

procedure FillRectEga(x1, y1, x2, y2: ShortInt; page, value: Byte);
var
  { draw page on entry }
  saved: Byte;
  { byte offset of the current scanline's first cell }
  rowOfs: Word;
  { last scanline index, counting from 0 }
  rows: Word;
  i: Word;
begin
  saved := GDVars.drawPageNum;
  rowOfs := Word(y1 * 40) * 8 + x1;
  rows := (y2 - y1 + 1) * 8 - 1;
  TextRend.SetupEgaOtherPage(page);
  TextRend.ResetEgaGc;
  { GC index 5 -- Mode }
  Port[$3CE] := 5;
  { write mode 2: the latches supply the plane data }
  Port[$3CF] := 2;
  for i := 0 to rows do begin
    FillChar(Mem[GDVars.egaOtherPage : rowOfs], x2 - x1 + 1, value);
    Inc(rowOfs, 40);
  end;
  Port[$3CE] := 5;
  { back to write mode 0 }
  Port[$3CF] := 0;
  GDVars.drawPageNum := saved;
  TextRend.SetupEgaOtherPage(GDVars.drawPageNum);
end;

procedure LoadGameFont;
var
  size: Word;
  data: Types.PBytes;
begin
  DaxIo.LoadDax('8X8d0', '.dax', 201, size, data);
  if size = 0 then Exit;
  Move(data^, GDVars.gameFont^, size);
  ZeroFree.PrefixFree(data, size);
end;

procedure RenderChar(col, row, fg, bg, count: Byte; ch: Char; xlat: Boolean);
var
  i: Byte;
  { font index 0..63 }
  glyph: Byte;
  { Unused in this version; see the other implementations of this routine. }
  glyphBuffer: array[1..14] of Byte;
begin
  if (col > 39) or (row > 24) or (GDVars.gameFont = nil) then Exit;
  if xlat then
    glyph := Ord(UpCase(ch)) mod 64
  else
    glyph := Ord(ch);
  Move(GDVars.gameFont^[glyph * 8], GDVars.glyphRowBuf, SizeOf(GDVars.glyphRowBuf));
  case GDVars.videoMode of
    C_Video.DISPLAY_EGA:
      for i := 1 to count do begin
        TextRend.EgaGlyph(col, row, fg, bg, glyph);
        Inc(col);
      end;
    C_Video.DISPLAY_TANDY:
      for i := 1 to count do begin
        TextRend.TandyGlyph(col, row, fg, bg, glyph);
        Inc(col);
      end;
    C_Video.DISPLAY_MCGA:
      for i := 1 to count do begin
        TextRend.VgaGlyph(col, row, fg, bg, glyph);
        Inc(col);
      end;
  end;
end;

procedure PrintSpaces(col, row, color, count: Byte);
begin
  Mouse.HideMouse;
  if (col < 0) or (col > 39) or (row < 0) or (row > 24) then Exit;
  TextRend.RenderChar(col, row, color, color, count, ' ', True);
  Mouse.ShowMouse;
end;

procedure DisplayString(col, row, fg, bg: Byte; s: String);
var
  { characters to draw }
  len: Byte;
  { the character being drawn }
  i: Byte;
begin
  Mouse.HideMouse;
  if (col > 39) or (row > 39) then Exit;
  len := Length(s);
  for i := 1 to len do begin
    TextRend.RenderChar(col, row, fg, bg, 1, s[i], True);
    Inc(col);
  end;
  Mouse.ShowMouse;
end;

{ Waits for the player at a full page of wrapped text; defined below. }
procedure PauseContinue; forward;

procedure DisplayMessageWindow(x1, y1, x2, y2, fg, bg: Byte; clearFirst: Boolean; s: String);
var
  len: Byte;
  { Unused in this version; see the other implementations of this routine. }
  width: Byte;
  { start of the word being emitted }
  i: Byte;
  { scan cursor / end of that word }
  j: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lineStart: Byte;

  { Prints the current word at the text cursor, advancing it, with a delay after each character while slow text is on. }
  procedure PrintCharInWindow;
  begin
    while i <= j do begin
      TextRend.RenderChar(GDVars.textCursorCol, GDVars.textCursorRow, fg, bg, 1, s[i], True);
      if GDVars.msgDelayFlag then Delay(GDVars.vmBand.zone0^.gameDelay * 3);
      Inc(i);
      Inc(GDVars.textCursorCol);
    end;
  end;

  { Advances i over a run of spaces. Note: a space in the last position of the string is never skipped. }
  procedure SkipSpaces;
  begin
    while (i < len) and (s[i] = ' ') do Inc(i);
  end;

begin
  Mouse.HideMouse;
  if (x1 > 39) or (y1 > 24) or (x2 > 39) or (y2 > 39) then Exit;
  if (GDVars.textCursorCol < x1) or (GDVars.textCursorCol > x2) or (GDVars.textCursorRow < y1) or
      (GDVars.textCursorRow > y2) then begin
    GDVars.textCursorCol := x1;
    GDVars.textCursorRow := y1;
  end;
  if clearFirst then begin
    TextRend.ClearRect(x1, y1, x2, y2);
    GDVars.textCursorCol := x1;
    GDVars.textCursorRow := y1;
  end;
  i := 1;
  len := Length(s);
  if len = 0 then begin
    Mouse.ShowMouse;
    Exit;
  end;
  width := x2 - x1 + 1;
  repeat
    j := i;
    while (j < len) and (s[j] in GDConsts.punct) do Inc(j);
    while (j < len) and not (s[j] in GDConsts.punct) and (s[j] <> ' ') do Inc(j);
    if s[j] <> ' ' then
      while (j + 1 < len) and (s[j + 1] in GDConsts.punct) do Inc(j);
    if (j - i) + GDVars.textCursorCol > x2 then begin
      if ((j - i) + GDVars.textCursorCol = x2) and (s[j] = ' ') then
      begin
        Dec(j);
        PrintCharInWindow;
      end;
      GDVars.textCursorCol := x1;
      Inc(GDVars.textCursorRow);
      SkipSpaces;
      if (GDVars.textCursorRow > y2) and (i < len) then begin
        GDVars.textCursorCol := x1;
        GDVars.textCursorRow := y1;
        TextRend.PauseContinue;
        GameIo.FlushKeys;
        TextRend.ClearRect(x1, y1, x2, y2);
        PrintCharInWindow;
      end;
    end else
      PrintCharInWindow;
  until i > len;
  if GDVars.textCursorCol > x2 then begin
    GDVars.textCursorCol := x1;
    Inc(GDVars.textCursorRow);
  end;
  Mouse.ShowMouse;
end;

function ReadString(prompt: Types.TStr40; fg, bg, maxLen: Byte): Types.TStr40;
var
  { echo column, then the upper-casing counter }
  col: Byte;
  len: Byte;
  buf: String;
  key: Char;
begin
  TextRend.PrintSpaces(0, 24, 0, 40);
  TextRend.DisplayString(0, 24, fg, bg, prompt);
  col := Length(prompt);
  buf := '';
  repeat
    { the cursor block, one cell past the text }
    TextRend.PrintSpaces(col + 1, 24, 15, 1);
    key := ReadKey;
    if key = #0 then begin
      { the extended scancode }
      key := ReadKey;
      case key of
        C_Keys.HOME: key := '7';
        C_Keys.UP: key := '8';
        C_Keys.PAGE_UP: key := '9';
        C_Keys.LEFT: key := '4';
        { Note: should be #76; see above }
        #32: key := '5';
        C_Keys.RIGHT: key := '6';
        C_Keys.END_KEY: key := '1';
        C_Keys.DOWN: key := '2';
        C_Keys.PAGE_DOWN: key := '3';
        TextRend.KEY_INS: key := '0';
      else
        key := #0;
      end;
    end;
    len := Length(buf);
    case key of
      ' ':
        if (len <> 0) and (len < maxLen) then begin
          buf := buf + ' ';
          Inc(col);
          TextRend.DisplayString(col, 24, 15, 0, ' ');
        end;
      '!'..'z':
        if len < maxLen then begin
          buf := buf + key;
          Inc(col);
          TextRend.DisplayString(col, 24, 15, 0, key);
        end;
      C_Keys.BACKSPACE:
        if len > 0 then begin
          buf := Copy(buf, 1, len - 1);
          TextRend.PrintSpaces(col, 24, 0, 2);
          Dec(col);
        end;
    end;
  until (key = C_Keys.ENTER) or (key = C_Keys.ESCAPE) or GDVars.demoMode;
  TextRend.PrintSpaces(0, 24, 0, 40);
  len := Length(buf);
  while buf[len] = ' ' do Dec(len);
  buf := Copy(buf, 1, len);
  for col := 1 to len do
    buf[col] := UpCase(buf[col]);
  ReadString := buf;
end;

function ReadNumber(prompt: Types.TStr40; fg, bg, maxLen: Byte): LongInt;
var
  ok: Boolean;
  value: LongInt;
  numStr: string[10];
  { Val's error position }
  err: Integer;
begin
  repeat
    numStr := TextRend.ReadString(prompt, fg, bg, maxLen);
    value := 0;
    err := 0;
    ok := True;
    if Length(numStr) > 0 then begin
      GDVars.scratchIndex := 1;
      while (GDVars.scratchIndex <= Length(numStr)) and ok do begin
        ok := numStr[GDVars.scratchIndex] in ['0'..'9'];
        Inc(GDVars.scratchIndex);
      end;
      if ok then begin
        Val(numStr, value, err);
        if err = 0 then
          if (value > $7FFFFFFF) or (value < 0) then err := 1;
      end else
        err := 1;
    end;
  until err = 0;
  ReadNumber := value;
end;

procedure DisplayAndPause(fg, bg: Byte; msg: Types.TStr40);
var
  k: Char;
  { mouse buttons held }
  buttons: Integer;
  { mouse position, not needed here }
  mx: Integer;
  { likewise }
  my: Integer;
begin
  TextRend.PrintSpaces(0, 24, 0, 40);
  TextRend.DisplayString(0, 24, fg, bg, msg);
  repeat
    k := GameIo.ReadGameKey;
  until k in [C_Keys.ENTER, C_Keys.ESCAPE];
  if GDVars.keyFromMouse <> 0 then
    repeat
      Mouse.GetMouse(buttons, mx, my);
    until buttons = 0;
end;

function GetTicks: LongInt;
var
  { hours }
  h: Word;
  { minutes }
  m: Word;
  { seconds }
  s: Word;
  { hundredths }
  hundredths: Word;
begin
  GetTime(h, m, s, hundredths);
  GetTicks := LongInt(h) * 360000 + LongInt(m) * 6000
                     + LongInt(s) * 100 + hundredths;
end;

procedure ClearScreen;
begin
  case GDVars.videoMode of
    C_Video.DISPLAY_EGA: begin
         TextRend.FillRectEga(0, 0, 39, 24, 0, 0);
         TextRend.FillRectEga(0, 0, 39, 24, 1, 0);
       end;
    C_Video.DISPLAY_MCGA: GameIo.ZeroFill(Types.PBytes(Ptr($A000, 0))^, 64000);
    C_Video.DISPLAY_TANDY: begin
         GameIo.ZeroFill(Types.PBytes(Ptr($B800, 0))^, 8000);
         GameIo.ZeroFill(Types.PBytes(Ptr($BA00, 0))^, 8000);
         GameIo.ZeroFill(Types.PBytes(Ptr($BC00, 0))^, 8000);
         GameIo.ZeroFill(Types.PBytes(Ptr($BE00, 0))^, 8000);
       end;
  end;
end;

procedure PrintAndPause(msg: Types.TStr40; fg, bg: Byte);
begin
  TextRend.PrintSpaces(0, 24, 0, 40);
  TextRend.DisplayString(0, 24, fg, bg, msg);
  TextRend.PauseOnly;
  TextRend.PrintSpaces(0, 24, 0, 40);
end;

procedure PauseOnly;
begin
  Delay(GDVars.vmBand.zone0^.gameDelay * 100);
end;

{ Fills a rectangle of character cells with a solid color in the current display mode. EGA goes through FillRectEga on
  both pages; MCGA writes one byte per pixel, 320 bytes a scanline; Tandy writes two pixels per byte, so the color is
  packed into both nibbles, and a cell row spans two scanlines in each of the four banks.
  @param(x1 Left column.)
  @param(y1 Top row.)
  @param(x2 Right column.)
  @param(y2 Bottom row.)
  @param(color The fill color.) }
procedure FillRect(x1, y1, x2, y2, color: Byte);
var
  { Tandy: first scanline, y1*2 }
  ty1: Word;
  { Tandy: last scanline, y2*2+1 }
  ty2: Word;
  { Tandy: byte column, x1*4 }
  tx: Word;
  { Tandy: bytes per bank per row }
  tw: Word;
  { the scanline counter, modes 1 and 2 }
  row: Word;
  { MCGA: running linear offset, += 320 }
  rowOfs: Word;
  { MCGA: bytes per scanline }
  wid: Word;
  { Tandy: color packed into both nibbles }
  cc: Byte;
begin
  Mouse.HideMouse;
  case GDVars.videoMode of
    C_Video.DISPLAY_EGA: begin
         TextRend.FillRectEga(x1, y1, x2, y2, 0, color);
         TextRend.FillRectEga(x1, y1, x2, y2, 1, color);
       end;
    C_Video.DISPLAY_MCGA: begin
         rowOfs := y1 * 8 * 320 + x1 * 8;
         wid := (x2 - x1 + 1) * 8;
         for row := y1 * 8 to (y2 + 1) * 8 - 1 do begin
           FillChar(Types.PBytes(C_Video.VGA_BASE + LongInt(rowOfs))^, wid, color);
           Inc(rowOfs, 320);
         end;
       end;
    C_Video.DISPLAY_TANDY: begin
         ty1 := y1 * 2;
         ty2 := y2 * 2 + 1;
         tx := x1 * 4;
         tw := (x2 - x1 + 1) * 4;
         cc := color + (color shl 4);
         for row := ty1 to ty2 do begin
           FillChar(tandyBank0[row, tx], tw, cc);
           FillChar(tandyBank1[row, tx], tw, cc);
           FillChar(tandyBank2[row, tx], tw, cc);
           FillChar(tandyBank3[row, tx], tw, cc);
         end;
       end;
  end;
  Mouse.ShowMouse;
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: Byte);
begin
  TextRend.FillRect(ulCol, ulRow, lrCol, lrRow, 0);
end;

{ Drains any keys already pressed, waits for the player with the continue prompt on the status line, then clears the
  line. }
procedure PauseContinue;
begin
  GameIo.FlushKeys;
  TextRend.DisplayAndPause(0, 15, GDConsts.pressButtonPrompt);
  TextRend.ClearRect(0, 24, 39, 24);
end;

procedure DisplayLoading;
begin
  TextRend.ClearRect(21, 24, 39, 24);
  TextRend.DisplayString(0, 24, 10, 0, 'Loading...Please Wait');
end;

procedure ClearStatusLine;
begin
  TextRend.ClearRect(0, 24, 39, 24);
end;

function NumToStr(n: Byte): String;
var
  buf: String;
begin
  Str(n, buf);
  NumToStr := buf;
end;

procedure RightAlignString(var s: Types.TStr40; n: Byte);
begin
  while Length(s) < n do
    s := ' ' + s;
end;

begin
end.
