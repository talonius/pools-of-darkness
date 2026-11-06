{ Screen frames and rectangle clearing. The frame routines paint stored lists of line segments through Sym8x8 to build
  the full, split, side-pane and inset frames; ClearBox blanks a rectangle of character cells in the EGA, Tandy or MCGA
  screen layout. Note: ClearBox does not check its coordinates, and a GDVars.videoMode outside 0..2 clears nothing. }
{$F+,O-,S-,R-,V-,B-,I-}
unit Border;

interface

uses Mouse, GameIo, Sym8x8, Blit, TextRend, Types, GDConsts, GDVars, C_Video;

{ Clears the screen inside the frame area (columns 0..38, rows 0..22) and draws the outer frame.
  @param(layout Unused.) }
procedure DrawWindowFrame(layout: Byte);

{ Draws a divider across a row, with end tiles 9 and 7 as the frame scripts' dividers have.
  @param(y The row.)
  @param(x1 The first column.)
  @param(x2 The last column.) }
procedure DrawHLine(y, x1, x2: Byte);

{ Draws the text screen's frame through ScreenText, then the exploration screen's extra frame segments. }
procedure DrawExploreFrame;

{ Clears the screen inside the outer frame (columns 1..38, rows 1..22), draws the outer frame with a divider across row
  16, and records the text window below it, rows 17 to 22. }
procedure ScreenText;

{ Clears inside the frame down to row 21, draws the ground combat frame, clears row 23, and sets the text window to
  column 23, rows 1 to 21. }
procedure DrawCombatFrame;

{ Clears the screen inside the outer frame (columns 1..38, rows 1..22) and draws the outer frame. }
procedure DrawCharViewFrame;

{ Clears rows 1..16 inside the outer frame and draws the outer frame. }
procedure DrawListFrame;

{ Clears a rectangle of character cells, corners included, to color 0 directly in video memory, after waiting for the
  start of a vertical retrace and with the mouse cursor hidden. EGA clears both display pages through TextRend, Tandy
  clears two scanlines in each of its four banks and MCGA clears eight scanlines per cell row.
  @param(x1 Left column.)
  @param(y1 Top row.)
  @param(x2 Right column.)
  @param(y2 Bottom row.) }
procedure ClearBox(x1, y1, x2, y2: ShortInt);

implementation

const
  LINE_END = $FE;

type
  PLineList = ^TLineList;
  { a stored segment list, read unchecked }
  TLineList = array[0..0] of Byte;
  PVideoMemory = ^TVideoMemory;
  TVideoMemory = array[0..0] of Byte;

{ Draws each run of a frame script.
  @param(list Six-byte runs (x1, y1, x2, y2 and the two end tiles) ended by a terminator.) }
procedure DrawFrameSegments(list: PLineList);
var
  x1: Byte;
  y1: Byte;
  x2: Byte;
  y2: Byte;
  capStart: Byte;
  capEnd: Byte;
  { read position in the list }
  i: Byte;
begin
  GDVars.scratchFlag := False;
  i := 0;
  repeat
    if list^[i] = Border.LINE_END then
      GDVars.scratchFlag := True
    else begin
      x1 := list^[i]; Inc(i);
      y1 := list^[i]; Inc(i);
      x2 := list^[i]; Inc(i);
      y2 := list^[i]; Inc(i);
      capStart := list^[i]; Inc(i);
      capEnd := list^[i]; Inc(i);
      Sym8x8.DrawBorderRun(x1, y1, x2, y2, capStart, capEnd);
    end;
  until GDVars.scratchFlag;
end;

{ Draws the main frame from its frame script. }
procedure DrawOuterFrame;
begin
  Border.DrawFrameSegments(@GDConsts.fullFrameSegments);
end;

procedure DrawWindowFrame;
begin
  Mouse.HideMouse;
  Border.ClearBox(0, 0, 38, 22);
  Border.DrawOuterFrame;
  Mouse.ShowMouse;
end;

procedure DrawHLine(y, x1, x2: Byte);
begin
  Sym8x8.DrawBorderRun(x1, y, x2, y, 9, 7);
end;

procedure DrawExploreFrame;
begin
  Mouse.HideMouse;
  Border.ScreenText;
  Border.DrawFrameSegments(@GDConsts.splitFrameSegments);
  Mouse.ShowMouse;
end;

procedure ScreenText;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 22);
  Border.DrawOuterFrame;
  Border.DrawHLine(16, 0, 39);
  GDVars.activePane.left := 1;
  GDVars.activePane.top := 17;
  GDVars.activePane.right := 38;
  GDVars.activePane.bottom := 22;
  Mouse.ShowMouse;
end;

procedure DrawCombatFrame;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 21);
  Border.DrawFrameSegments(@GDConsts.sideFrameSegments);
  Border.ClearBox(0, 23, 39, 23);
  GDVars.activePane.left := 23;
  GDVars.activePane.top := 1;
  GDVars.activePane.right := 23;
  GDVars.activePane.bottom := 21;
  Mouse.ShowMouse;
end;

procedure DrawCharViewFrame;
var
  { Unused in this version; see the other implementations of this routine. }
  frameScript: LongInt;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 22);
  Border.DrawOuterFrame;
  Mouse.ShowMouse;
end;

procedure DrawListFrame;
var
  { Unused in this version; see the other implementations of this routine. }
  row: Word;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 16);
  Border.DrawOuterFrame;
  Mouse.ShowMouse;
end;

procedure ClearBox(x1, y1, x2, y2: ShortInt);
var
  firstRow: Word;
  lastRow: Word;
  firstByte: Word;
  bytesPerRow: Word;
  { Unused in this version; see the other implementations of this routine. }
  cgaColOff: Word;
  { scanline being cleared }
  row: Word;
  { MCGA: offset of the row's first byte }
  videoOffset: Word;
  { MCGA: bytes to clear per scanline }
  clearWidth: Word;
begin
  Blit.WaitRetraceEnd;
  Blit.WaitRetraceStart;
  Mouse.HideMouse;
  case GDVars.videoMode of
    C_Video.DISPLAY_EGA:
      begin
        TextRend.FillRectEga(x1, y1, x2, y2, 0, 0);
        TextRend.FillRectEga(x1, y1, x2, y2, 1, 0);
      end;
    C_Video.DISPLAY_TANDY:
      begin
        firstRow := y1 * 2;
        lastRow := y2 * 2 + 1;
        firstByte := x1 * 4;
        bytesPerRow := (x2 - x1 + 1) * 4;
        for row := firstRow to lastRow do begin
          GameIo.ZeroFill(TextRend.tandyBank0[row, firstByte], bytesPerRow);
          GameIo.ZeroFill(TextRend.tandyBank1[row, firstByte], bytesPerRow);
          GameIo.ZeroFill(TextRend.tandyBank2[row, firstByte], bytesPerRow);
          GameIo.ZeroFill(TextRend.tandyBank3[row, firstByte], bytesPerRow);
        end;
      end;
    C_Video.DISPLAY_MCGA:
      begin
        videoOffset := y1 * 8 * 320 + x1 * 8;
        clearWidth := (x2 - x1 + 1) * 8;
        for row := y1 * 8 to
                   (y2 + 1) * 8 - 1 do begin
          GameIo.ZeroFill(PVideoMemory(LongInt(videoOffset) + C_Video.VGA_BASE)^, clearWidth);
          Inc(videoOffset, 320);
        end;
      end;
  end;
  Mouse.ShowMouse;
end;

begin
end.
