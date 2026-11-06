{ Horizontal and scrolling menu services, mouse click handling for the menus and the game screens, timed palette cycling
  while a menu waits, and allocation of the string lists the scrolling menu shows. }
{$O+,F+,S-,R-,V-,B-,I-}
unit MenuCore;

interface

uses Types, GDConsts, GDVars, TextRend, Mouse, Border, GameIo, Joystick, Portrait,
  CbtMap, C_Keys, C_Ifc, C_Driver;

{ Finds a member of a string list by position.
  @param(targetIndex The member's position, counting from 0.)
  @param(list The list's first member.)
  @returns(The member, or nil when the list is shorter.) }
function FindListMember(targetIndex: Integer; list: Types.PMenuLine): Types.PMenuLine;

{ Registers an option as the next choice of the coming menu. Note: slotCount is not checked; 20 or more writes past the
  menu slot table.
  @param(optionId The option's index in the menu string.)
  @param(slotCount The slot to fill; advanced past it.) }
procedure AppendSlot(optionId: Byte; var slotCount: Byte);

{ Clears the menu slots and registers choices 0..lastIdx. Note: lastIdx is not checked; 20 or more writes past the menu
  slot table.
  @param(lastIdx The last choice registered.) }
procedure ResetMenuSlots(lastIdx: Byte);

{ Shows a query and a menu on the bottom line (two lines when the menu holds '@') and waits for a choice. Each option is
  a word starting with a capital letter or digit, its hotkey; only the options registered in GDVars.menuSlotTable are
  shown. The cursor keys move the highlight, a hotkey or Enter chooses, and mouse clicks are handled for the menu, the
  party list and the game screen behind it. While waiting it cycles palette ranges and can time out to a preset key.
  @param(query The text before the options.)
  @param(menu The options.)
  @param(reinterpret True turns keypad digits into the cursor keys they sit on.)
  @param(animate True also animates the portrait while waiting.)
  @returns(The chosen option's registered choice, or the key code of a special key with GDVars.extendedKeyFlag set.) }
function MenuHorizontal(query: Types.TStr40; menu: Types.TStr255; reinterpret, animate: Boolean): Char;

{ Blanks the bottom text row. }
procedure ClearBottomLine;

{ Shows a string list in a window and lets the player highlight a line, with the menu below it extended by Next, Prev
  and (when addExit is set) Exit. Heading lines cannot be highlighted.
  @param(query The text before the menu.)
  @param(menu The menu's own options.)
  @param(ulCol The window's left column.)
  @param(ulRow Its top row.)
  @param(lrCol Its right column.)
  @param(lrRow Its bottom row.)
  @param(list The lines to show.)
  @param(addExit True adds Exit to the menu.)
  @param(initial The last registered choice, or $FF when menu has no registered options of its own.)
  @param(redraw True asks for a full repaint; cleared once done.)
  @param(selectionIndex The highlighted position, kept between calls.)
  @param(selection Receives the chosen line, or nil on Escape.)
  @returns(The key that ended the menu, or Escape.) }
function MenuVertical(query: Types.TStr40; menu: Types.TStr255; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PMenuLine; addExit: Boolean; initial: Byte; var redraw: Boolean;
                      var selectionIndex: Integer; var selection: Types.PMenuLine): Char;

{ Asks a question with Yes and No.
  @param(query The question.)
  @param(defaultChoice 0 to highlight Yes first, 1 for No.)
  @returns(0 for Yes, 1 for No.) }
function YesNoMenu(query: Types.TStr40; defaultChoice: Byte): Byte;

{ Allocates a list of empty members, as many as asked; the first is allocated before the count is read, so a count below
  1 gives one member.
  @param(nodeCount Members wanted.)
  @param(list Receives the first member.) }
procedure AllocStringList(nodeCount: Integer; var list: Types.PMenuLine);

{ Frees each member of a string list; the caller's pointer is not set to nil.
  @param(list The list's first member, or nil.) }
procedure FreeStringList(var list: Types.PMenuLine);

implementation

const
  { Menu result meaning no selection: MenuVertical returns it for an empty list (Escape and Exit come back as an
    extended C_Keys.ESCAPE). }
  KEY_NONE = #0;

type
  TMenuSpan = record
    first: Byte;
    last: Byte;
  end;

function FindListMember(targetIndex: Integer; list: Types.PMenuLine): Types.PMenuLine;
var
  p: Types.PMenuLine;
  i: Integer;
begin
  i := 0;
  p := list;
  while (p <> nil) and (i <> targetIndex) do begin
    p := p^.next;
    Inc(i);
  end;
  if i = targetIndex then
    FindListMember := p
  else
    FindListMember := nil;
end;

{ Counts the members of a string list.
  @param(list The list's first member, or nil.)
  @returns(The number of members.) }
function ListCount(list: Types.PMenuLine): Integer;
var
  p: Types.PMenuLine;
  n: Integer;
begin
  n := 0;
  p := list;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ListCount := n;
end;

procedure AppendSlot(optionId: Byte; var slotCount: Byte);
begin
  GDVars.menuSlotTable[slotCount].choiceIndex := optionId;
  Inc(slotCount);
end;

procedure ResetMenuSlots(lastIdx: Byte);
var
  i: Byte;
begin
  FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
  for i := 0 to lastIdx do
    GDVars.menuSlotTable[i].choiceIndex := i;
end;

function MenuHorizontal(query: Types.TStr40; menu: Types.TStr255; reinterpret, animate: Boolean): Char;
var
  tick: LongInt;
  animTicks: array[1..4] of LongInt;
  { read only to set longDeadline }
  shortDeadline: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  longDeadline: LongInt;
  paletteDue: Boolean;
  ch: Char;
  mouseCellColumn: Integer;
  mouseCellRow: Integer;
  scan: Byte;
  { Unused in this version; see the other implementations of this routine. }
  secondIndex: Byte;
  done: Boolean;
  menuLen: Byte;
  queryLen: Byte;
  spans: array[0..20] of TMenuSpan;
  clickedCharacter: Pointer;
  buttons: Integer;
  releaseX: Integer;
  releaseY: Integer;
  hasAt: Boolean;
  { screen row of the menu's first line }
  displayRow: Byte;
  { options on the first line of a two-line menu }
  spanCount: Byte;
  workMenu: Types.TStr255;
  mappedKey: Char;
  mappedReady: Boolean;

  { Finds the first and last character of each option in workMenu, the option count and the first line's count. }
  procedure ParseMenu;
  var
    wordIdx: Byte;
    i: Byte;
    len: Byte;
  begin
    GameIo.ZeroFill(spans[1], SizeOf(spans) - SizeOf(spans[0]));
    wordIdx := 1;
    len := Length(workMenu);
    { Note: more than 20 options overrun spans. }
    for i := 1 to len do
      if workMenu[i] in ['0'..'9', 'A'..'Z'] then
        if spans[wordIdx].first = 0 then
          spans[wordIdx].first := i
        else begin
          spans[wordIdx].last := i - 2;
          Inc(wordIdx);
          spans[wordIdx].first := i;
        end else if workMenu[i] = '@' then
        spanCount := wordIdx;
    spans[wordIdx].last := len;
    spans[0].last := wordIdx;
  end;

  { Draw the menu after the query with option cur highlighted and every hotkey in the highlight color. }
  procedure DisplayOption(cur: Byte);
  var
    col: Byte;
    row: Byte;
    i: Byte;
  begin
    Mouse.HideMouse;
    col := 1;
    row := displayRow;
    if menuLen > 0 then
      for i := 1 to menuLen do begin
        if workMenu[i] = '@' then
        begin
          Border.ClearBox(queryLen + col - 1, row, 39, row);
          Inc(row);
          col := 1;
        end else begin
          if (spans[cur].first <= i) and (spans[cur].last >= i)
             and (GDVars.menuHighlightColor <> 0) then
            TextRend.RenderChar(queryLen + col - 1, row, 0, GDVars.menuHighlightColor, 1, workMenu[i], True)
          else if workMenu[i] in ['0'..'9', 'A'..'Z'] then
            TextRend.RenderChar(queryLen + col - 1, row, GDVars.menuHighlightColor, 0, 1, workMenu[i], True)
          else
            TextRend.RenderChar(queryLen + col - 1, row, GDVars.menuTextColor, 0, 1, workMenu[i], True);
          Inc(col);
        end;
      end;
    if queryLen + col - 1 <= 39 then
      Border.ClearBox(queryLen + col - 1, row, 39, row);
    Mouse.ShowMouse;
  end;

  { Answers with the current option's key (Enter for an empty one) and finishes. }
  procedure AcceptCurrent;
  begin
    GDVars.extendedKeyFlag := False;
    ch := workMenu[spans[GDVars.horizMenuChoice].first];
    if ch = #0 then
      ch := C_Keys.ENTER;
    done := True;
  end;

  { Tells whether the click falls on the party list and party clicks are allowed on this screen. }
  function PartyClick: Boolean;
  begin
    PartyClick := (GDVars.mouseMenuMode <> 0)
      and not ((GDVars.interfaceState = C_Ifc.AREA_MAP) and (GDVars.vmBand.zone0^.mapPaneEnabled = 1))
      and ((GDVars.clickInputMode = 0) or (GDVars.interfaceState <> C_Ifc.DUNGEON))
      and (GDVars.interfaceState <> C_Ifc.IN_COMBAT)
      and (GDVars.partyAreaLeft <= mouseCellColumn) and (GDVars.partyAreaRight >= mouseCellColumn)
      and (GDVars.partyAreaTop <= mouseCellRow) and (GDVars.partyAreaBottom >= mouseCellRow);
  end;

  { A party click picks another member (as a cursor-up key) or chooses the highlighted option on the current one. }
  procedure HandlePartyClick;
  var
    i: Byte;
  begin
    scan := mouseCellRow - GDVars.partyAreaTop;
    clickedCharacter := GDVars.creatureListHead;
    { A click below the last party member walks off the roster; the nil check stops the walk there. }
    for i := 1 to scan do
      if clickedCharacter <> nil then
        clickedCharacter := Types.PCharRecord(clickedCharacter)^.next;
    if clickedCharacter <> nil then
      if ((clickedCharacter <> GDVars.currentChar) and (GDVars.charSelectMode = 0))
         or ((clickedCharacter <> GDVars.selectStartChar) and (GDVars.charSelectMode <> 0)) then begin
        if GDVars.charSelectMode <> 0 then
          GDVars.selectStartChar := clickedCharacter
        else
          GDVars.clickedChar := clickedCharacter;
        ch := C_Keys.UP;
        GDVars.extendedKeyFlag := True;
        done := True;
        Exit;
      end;
    if (clickedCharacter <> nil) and
        ((clickedCharacter = GDVars.currentChar) or (clickedCharacter = GDVars.selectStartChar)) then
      AcceptCurrent;
  end;

  { Tells whether, in combat, the click falls inside the arena while the player is moving a combatant or aiming. }
  function ArenaClick: Boolean;
  begin
    ArenaClick := ((GDVars.manualMoveActive <> 0) or (GDVars.aimCursorOn <> 0))
      and (GDVars.interfaceState = C_Ifc.IN_COMBAT)
      and (mouseCellColumn >= 1) and (mouseCellColumn <= 21)
      and (mouseCellRow >= 1) and (mouseCellRow <= 21);
  end;

  { Turns an arena click into the movement key toward the clicked cell, from the aim cursor or the combatant. }
  procedure HandleArenaClick;
  begin
    GDVars.extendedKeyFlag := True;
    if GDVars.aimCursorOn <> 0 then begin
      releaseX := GDVars.aimCursorX - GDVars.arenaPtr^.ox + 1;
      releaseY := GDVars.aimCursorY - GDVars.arenaPtr^.oy + 1;
    end else begin
      { Note: CombatSlot's result is used as a GDVars.arenaSlots index unchecked. }
      scan := CbtMap.CombatSlot(GDVars.currentChar);
      releaseX := GDVars.arenaSlots[scan].x - GDVars.arenaPtr^.ox + 1;
      releaseY := GDVars.arenaSlots[scan].y - GDVars.arenaPtr^.oy + 1;
    end;
    ch := Char(Mouse.MouseDirection(releaseX, releaseY, mouseCellColumn div 3 + 1, mouseCellRow div 3 + 1));
    done := True;
  end;

  { Tells whether the click falls inside the 3-D view and view clicks are enabled. }
  function ViewAreaClick: Boolean;
  begin
    ViewAreaClick := (GDVars.clickInputMode <> 0)
      and (mouseCellColumn >= 3) and (mouseCellColumn <= 13)
      and (mouseCellRow >= 3) and (mouseCellRow <= 13)
      and (GDVars.interfaceState = C_Ifc.DUNGEON);
  end;

  { Turns a 3D-view or automap click into a movement key. }
  procedure HandleViewClick;
  var
    x: ShortInt;
    y: ShortInt;
    dir: Byte;
    face: Byte;
  begin
    GDVars.extendedKeyFlag := True;
    if GDVars.automapShown <> 0 then begin
      x := GDVars.mapState.x - 5;
      y := GDVars.mapState.y - 5;
      if x < 0 then x := 0;
      if x > 5 then x := 5;
      if y < 0 then y := 0;
      if y > 5 then y := 5;
      x := GDVars.mapState.x - x + 3;
      y := GDVars.mapState.y - y + 3;
      { Note: the facing and direction are used as indices into GDConsts.arrowKeyByFacing unchecked. }
      dir := CbtMap.DirectionBetween(x, y, mouseCellColumn, mouseCellRow) shr 1;
      face := GDVars.mapState.facing shr 1;
      if (x = mouseCellColumn) and (y = mouseCellRow) then
        ch := C_Keys.UP
      else
        ch := GDConsts.arrowKeyByFacing[face, dir];
    end else
      ch := Char(GDConsts.combatClickKeys[mouseCellRow, mouseCellColumn]);
    done := True;
  end;

  { True when the click falls on the outdoor area map and map clicks are enabled. }
  function WildernessClick: Boolean;
  begin
    WildernessClick := (GDVars.clickInputMode <> 0)
      and (GDVars.vmBand.zone0^.mapPaneEnabled = 1) and (GDVars.vmBand.zone0^.inDungeon = 0)
      and (GDVars.interfaceState = C_Ifc.AREA_MAP)
      and (mouseCellColumn >= 1) and (mouseCellColumn <= 38)
      and (mouseCellRow >= 1) and (mouseCellRow <= 15);
  end;

  { Turn an area-map click into the movement key that steps the party toward the clicked cell. }
  procedure HandleAreaMapClick;
  begin
    GDVars.extendedKeyFlag := True;
    ch := Char(Mouse.MouseDirection(GDVars.vmBand.zone0^.windowCol + 1, GDVars.vmBand.zone0^.windowRow + 1,
                                     mouseCellColumn, mouseCellRow));
    done := True;
  end;

  { True when the click falls on the menu line or below it. }
  function MenuRowClick: Boolean;
  begin
    MenuRowClick := (displayRow <= mouseCellRow) and not done;
  end;

  { Chooses the option under the clicked column, recording whether it was not already highlighted. }
  procedure HandleMenuRowClick;
  var i: Byte;
  begin
    Inc(mouseCellColumn);
    if queryLen < mouseCellColumn then begin
      mouseCellColumn := mouseCellColumn - queryLen;
      if hasAt then
        if displayRow < mouseCellRow then
          Inc(mouseCellColumn, Pos('@', workMenu))
        else if Pos('@', workMenu) <= mouseCellColumn then
          Exit;
      for i := 1 to spans[0].last do
        if (spans[i].first <= mouseCellColumn)
           and (spans[i].last >= mouseCellColumn) then begin
          ch := workMenu[spans[i].first];
          if i = GDVars.horizMenuChoice then
            GDVars.menuClickChanged := False
          else
            GDVars.menuClickChanged := True;
          GDVars.horizMenuChoice := i;
          DisplayOption(GDVars.horizMenuChoice);
          done := True;
        end;
    end;
  end;

  { True while the modify-character screen is up and no choice has been made. }
  function ModifyScreenClick: Boolean;
  begin
    ModifyScreenClick := (GDVars.sharedScratch.modifyActive <> 0) and not done;
  end;

  { On the modify-character screen, reports the field clicked and returns the Home key. }
  procedure HandleModifyClick;
  begin
    done := True;
    case mouseCellRow of
      1:
        if (mouseCellColumn >= 1) and (mouseCellColumn <= 16) then
          GDVars.modifyMouseRow := 6;
      3:
        if (mouseCellColumn >= 31) and (mouseCellColumn <= 33) then
          GDVars.modifyMouseRow := 7;
      9..14:
        if (mouseCellColumn >= 5) and (mouseCellColumn <= 9) then
          GDVars.modifyMouseRow := mouseCellRow - 9;
    else
      done := False;
    end;
    GDVars.extendedKeyFlag := True;
    ch := C_Keys.HOME;
  end;

  { True when the click falls within the columns of the scrolling list MenuVertical shows. }
  function HotspotClick: Boolean;
  begin
    HotspotClick := not done and (GDVars.listColLeft <= mouseCellColumn)
      and (GDVars.listColRight >= mouseCellColumn);
  end;

  { Chooses the highlighted option on a click on a list row, and flags the click for the vertical menu. }
  procedure HandleHotspotClick;
  begin
    scan := 1;
    GDVars.menuClickChanged := True;
    while (scan <= 25) and (GDVars.menuHotRows[scan] <> $FF) and not done do begin
      if GDVars.menuHotRows[scan] <= mouseCellRow then
        done := True;
      Inc(scan);
    end;
    if done then
      AcceptCurrent;
  end;

  { Highlights the previous option, wrapping to the last. }
  procedure MoveLeft;
  begin
    if GDVars.horizMenuChoice = 1 then
      GDVars.horizMenuChoice := spans[0].last
    else
      Dec(GDVars.horizMenuChoice);
    DisplayOption(GDVars.horizMenuChoice);
    done := False;
  end;

  { Highlights the next option, wrapping to the first. }
  procedure MoveRight;
  begin
    if GDVars.horizMenuChoice = spans[0].last then
      GDVars.horizMenuChoice := 1
    else
      Inc(GDVars.horizMenuChoice);
    DisplayOption(GDVars.horizMenuChoice);
    done := False;
  end;

  { Moves to the other line of a two-line menu, clamped to its options. }
  procedure MoveVertical;
  begin
    if GDVars.horizMenuChoice <= spanCount then begin
      Inc(GDVars.horizMenuChoice, spanCount);
      if GDVars.horizMenuChoice > spans[0].last then
        GDVars.horizMenuChoice := spans[0].last;
    end else begin
      Dec(GDVars.horizMenuChoice, spanCount);
      if GDVars.horizMenuChoice > spanCount then
        GDVars.horizMenuChoice := spanCount;
    end;
    DisplayOption(GDVars.horizMenuChoice);
    done := False;
  end;

  { Builds workMenu from a menu, keeping the registered options and recording each one's hotkey in the slot table. }
  procedure NormalizeMenu;
  var
    { Unused in this version; see the other implementations of this routine. }
    firstChar: Byte;
    ordinal: Byte;
    startAt: Byte;
    { Unused in this version; see the other implementations of this routine. }
    lastChar: Byte;
    i: Byte;
    slot: Byte;
    len: Byte;
  begin
    len := Length(menu);
    workMenu := '';
    slot := 0;
    ordinal := 0;
    i := 1;
    { Note: the menu text and the registered slots are not checked. A 21st selected option overruns
      GDVars.menuSlotTable, and because the character test precedes i <= len below, an option ending the string also
      reads menu[len + 1]. }
    while i <= len do begin
      if menu[i] in ['0'..'9', 'A'..'Z'] then
      begin
        if GDVars.menuSlotTable[slot].choiceIndex = ordinal then begin
          GDVars.menuSlotTable[slot].keyCode := Ord(menu[i]);
          startAt := i;
          Inc(i);
          while not (menu[i] in ['0'..'9', 'A'..'Z']) and (i <= len) do
            Inc(i);
          workMenu := workMenu + Copy(menu, startAt, i - startAt);
          Inc(slot);
        end else
          Inc(i);
        Inc(ordinal);
      end else
        Inc(i);
    end;
    len := Length(workMenu);
    { An empty result reads workMenu[0], its length byte. }
    if workMenu[len] = ' ' then
      Delete(workMenu, len, 1);
  end;

  { Returns the registered choice for the key pressed, a special key's own code, or $FF when no hotkey matches. }
  function MapMenuKey: Byte;
  var i: Byte;
  begin
    if GDVars.extendedKeyFlag then
      MapMenuKey := Ord(ch)
    else begin
      i := 0;
      while (i < 20) and (GDVars.menuSlotTable[i].keyCode <> Ord(ch)) do
        Inc(i);
      if i < 20 then
        MapMenuKey := GDVars.menuSlotTable[i].choiceIndex
      else
        MapMenuKey := $FF;
    end;
  end;

begin
  mappedReady := False;
  NormalizeMenu;
  if Pos('@', workMenu) > 0 then
  begin
    hasAt := True;
    displayRow := 23;
  end else begin
    hasAt := False;
    displayRow := 24;
  end;
  GDVars.extendedKeyFlag := False;
  spans[0].first := Ord((GDVars.menuTextColor <> 0) or (GDVars.menuHighlightColor <> 0));
  queryLen := Length(query) + 0;
  ParseMenu;
  if (GDVars.horizMenuChoice > spans[0].last) or (GDVars.horizMenuChoice = 0) then
    GDVars.horizMenuChoice := 1;
  menuLen := Length(workMenu);
  ch := #0;
  done := False;
  for scan := 1 to 4 do
    animTicks[scan] := TextRend.GetTicks;
  tick := TextRend.GetTicks;
  shortDeadline := TextRend.GetTicks + 30;
  longDeadline := shortDeadline + 50;
  if query <> '' then
    TextRend.DisplayString(0, 24, GDVars.menuQueryColor, 0, query);
  DisplayOption(GDVars.horizMenuChoice);
  if GDVars.animFromSprite then
    animate := False;
  if animate and (GDVars.animCurFrame > 0) then begin
    Portrait.DisplayImageBuf(3, 3, animate, GDVars.animCurFrame);
    if GDVars.animLastFrame < 2 then
      animate := False;
  end;
  repeat
    if animate and (GDVars.animLastFrame > 0) then
      { Note: the current frame number is used as an index into GDVars.animFrameDelays unchecked. }
      if GDVars.animFrameDelays[GDVars.animCurFrame] * 10
         <= TextRend.GetTicks - tick then begin
        Inc(GDVars.animCurFrame);
        if GDVars.animCurFrame > GDVars.animLastFrame then
          GDVars.animCurFrame := GDVars.animFirstFrame;
        Portrait.DisplayImageBuf(3, 3, animate, GDVars.animCurFrame);
        tick := TextRend.GetTicks;
        animate := (GDVars.animFrameDelays[GDVars.animCurFrame] = 99) = False;
      end;
    if GDVars.palettePresetOn <> 0 then
      for scan := 1 to 4 do begin
        if GDVars.driverState = C_Driver.MUSIC_INSTALLED then
          paletteDue :=
            (GDVars.palettePreset[scan].delay * 5 < (TextRend.GetTicks - animTicks[scan]))
                      and (GDVars.palettePreset[scan].delay <> 0)
        else
          paletteDue := (GDVars.palettePreset[scan].delay < (TextRend.GetTicks - animTicks[scan]))
                      and (GDVars.palettePreset[scan].delay <> 0);
        if paletteDue then begin
          Portrait.CyclePaletteRange(scan);
          animTicks[scan] := TextRend.GetTicks;
        end;
      end;
    if (GDVars.menuAutoDelay > 0)
       and (TextRend.GetTicks - tick >= GDVars.menuAutoDelay) then begin
      mappedKey := Char(GDVars.menuAutoKey);
      mappedReady := True;
      done := True;
    end;
    if GameIo.InputPending then begin
      ch := GameIo.ReadGameKey;
      if ch = #0 then begin
        ch := GameIo.ReadGameKey;
        GDVars.extendedKeyFlag := True;
        done := True;
        if spans[0].last > 1 then
          case ch of
            C_Keys.LEFT: MoveLeft;
            C_Keys.RIGHT: MoveRight;
            C_Keys.UP, C_Keys.DOWN: if hasAt then MoveVertical;
          end;
      end else begin
        GDVars.extendedKeyFlag := False;
        case ch of
          C_Keys.ESCAPE:
          begin
            GDVars.extendedKeyFlag := True;
            done := True;
          end;
          C_Keys.ENTER:
            if GDVars.keyFromMouse <> 0 then begin
              mouseCellRow := GDVars.mousePosY div 8;
              mouseCellColumn := GDVars.mousePosX div 8;
              if PartyClick then HandlePartyClick
              else if ArenaClick then HandleArenaClick
              else if ViewAreaClick then HandleViewClick
              else if WildernessClick then HandleAreaMapClick
              else if MenuRowClick then HandleMenuRowClick
              else if ModifyScreenClick then HandleModifyClick
              else if HotspotClick then HandleHotspotClick
              else if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (mouseCellRow <= 22) then begin
                if hasAt then begin
                  ch := 'T';
                  done := True;
                end else if query = 'Aim:' then
                begin
                  ch := 'M';
                  done := True;
                end;
              end else if spans[0].last > 1 then begin
                GDVars.extendedKeyFlag := True;
                ch := C_Keys.ESCAPE;
              end else
                done := True;
            end else
              AcceptCurrent;
        else
          ch := UpCase(ch);
          mappedKey := Char(MapMenuKey);
          if Byte(mappedKey) <> $FF then
            for scan := 1 to menuLen do
              if workMenu[scan] = ch then begin
                done := True;
                mouseCellColumn := 1;
                while scan <> spans[mouseCellColumn].first do
                  Inc(mouseCellColumn);
                GDVars.horizMenuChoice := mouseCellColumn;
                DisplayOption(GDVars.horizMenuChoice);
              end;
          if not done and (spans[0].last > 1) then
            if ch = '4' then
              MoveLeft
            else if ch = '6' then
              MoveRight
            else if (ch in ['2', '8', 'H', 'P']) and hasAt then
              MoveVertical;
          if reinterpret and (ch in ['1'..'9', '\']) then
          begin
            if ch = '\' then ch := '7'
            else ch := Char(GDConsts.keypadArrowKeys[Ord(ch) - Ord('1')]);
            mappedKey := ch;
            GDVars.extendedKeyFlag := True;
            done := True;
          end;
        end;
      end;
    end;
  until done;
  if mappedReady then
    MenuHorizontal := mappedKey
  else
    MenuHorizontal := Char(MapMenuKey);
  GameIo.FlushKeys;
  if GDVars.keyFromMouse <> 0 then
    repeat Mouse.GetMouse(buttons, releaseX, releaseY) until buttons = 0
  else if GDVars.joystickInstalled then
    repeat Joystick.GetJoystick(buttons, scan) until buttons = 0;
end;

procedure ClearBottomLine;
begin
  TextRend.PrintSpaces(0, 24, 0, 40);
end;

function MenuVertical(query: Types.TStr40; menu: Types.TStr255; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PMenuLine; addExit: Boolean; initial: Byte; var redraw: Boolean;
                      var selectionIndex: Integer; var selection: Types.PMenuLine): Char;
var
  width: Byte;
  { hotspot-row counter }
  line: Byte;
  { lines in the list }
  count: Integer;
  { lines the window holds }
  rows: Integer;
  { the key the menu returned }
  ch: Char;
  { that key, with Next, Prev and Exit turned into Page Down, Page Up and Esc }
  prevCh: Char;
  hMenu: Types.TStr255;
  { Next is offered }
  hasNext: Boolean;
  { Prev is offered }
  hasPrev: Boolean;
  p: Types.PMenuLine;
  { heading lines at the top of the list }
  headerCnt: Integer;
  { lines in the list, counted again }
  total: Integer;
  mouseCellCol: Byte;
  mouseCellRow: Byte;
  registeredCount: Byte;
  optionCount: Byte;
  slotCursor: Byte;
  prevSlot: Byte;
  nextSlot: Byte;
  exitSlot: Byte;
  clickedIdx: Byte;

  { The last heading line before position n. DrawPage keeps the result but does not use it. }
  function LastLabelBefore(n: Integer; l: Types.PMenuLine): Types.PMenuLine;
  var
    pp: Types.PMenuLine;
    found: Types.PMenuLine;
    i: Integer;
  begin
    i := 0;
    pp := l;
    found := nil;
    while (pp <> nil) and (i < n) do begin
      if pp^.inUse <> 0 then
        found := pp;
      pp := pp^.next;
      Inc(i);
    end;
    if (found = nil) and (l^.inUse <> 0) then
      LastLabelBefore := l
    else
      LastLabelBefore := found;
  end;

  { Draw one window of lines starting at list position top, recording each line's screen row in GDVars.menuHotRows. }
  procedure DrawPage(top: Integer);
  var
    pp: Types.PMenuLine;
    { Unused in this version; see the other implementations of this routine. }
    q: Types.PMenuLine;
    row: ShortInt;
  begin
    FillChar(GDVars.menuHotRows[1], SizeOf(GDVars.menuHotRows), $FF);
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
    Mouse.HideMouse;
    pp := MenuCore.FindListMember(top, list);
    q := LastLabelBefore(top, list);
    row := ulRow;
    line := 1;
    while (pp <> nil) and (row <= lrRow) do begin
      GDVars.menuHotRows[line] := row;
      if pp^.inUse <> 0 then
        TextRend.DisplayString(ulCol, row, GDVars.menuQueryColor, 0, pp^.name)
      else
        TextRend.DisplayString(ulCol, row, GDVars.menuTextColor, 0, pp^.name);
      if Length(pp^.name) < width then
        TextRend.RenderChar(ulCol + Length(pp^.name), row, 0, 0, width - Length(pp^.name), ' ', True);
      pp := pp^.next;
      Inc(row);
      Inc(line);
    end;
    Mouse.ShowMouse;
  end;

  { The position of the first non-blank character of s. }
  function FirstNonBlank(s: Types.TStr40): Byte;
  var
    i: Byte;
    len: Byte;
  begin
    i := 1;
    len := Length(s);
    while (i < len) and (s[i] = ' ') do
      Inc(i);
    FirstNonBlank := i;
  end;

  { The position of the last non-blank character of s. }
  function LastNonBlank(s: Types.TStr40): Byte;
  var
    n: Byte;
  begin
    n := Length(s);
    while (n > 1) and (s[n] = ' ') do
      Dec(n);
    LastNonBlank := n;
  end;

  { Draw line n in the highlight color. }
  procedure HighlightLine(n: Integer);
  var
    pp: Types.PMenuLine;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertMenuTop), 0, GDVars.menuHighlightColor,
                           Copy(pp^.name, a, b));
  end;

  { Draw line n in the normal menu color; heading and plain lines are drawn alike. }
  procedure UnhighlightLine(n: Integer);
  var
    pp: Types.PMenuLine;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    if pp^.inUse <> 0 then
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertMenuTop), GDVars.menuTextColor, 0,
                             Copy(pp^.name, a, b))
    else
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertMenuTop), GDVars.menuTextColor, 0,
                             Copy(pp^.name, a, b));
  end;

  { Move the selection off heading lines, in the given direction, wrapping within the page. }
  procedure SkipLabels(down: Boolean);
  var
    k: Integer;
  begin
    k := 0;
    if down then begin
      while (k < rows) and
          ((MenuCore.FindListMember(selectionIndex, list) = nil) or (MenuCore.FindListMember(selectionIndex,
              list)^.inUse <> 0)) do begin
        Inc(k);
        Inc(selectionIndex);
        if GDVars.vertMenuTop + rows - 1 < selectionIndex then
          selectionIndex := GDVars.vertMenuTop;
      end;
    end else
      while (k < rows) and
          ((MenuCore.FindListMember(selectionIndex, list) = nil) or (MenuCore.FindListMember(selectionIndex,
              list)^.inUse <> 0)) do begin
        Inc(k);
        Dec(selectionIndex);
        if selectionIndex < GDVars.vertMenuTop then
          selectionIndex := GDVars.vertMenuTop + rows - 1;
      end;
  end;

  { Scroll one page down or up, keeping the selection at the same place on the page. }
  procedure MovePage(down: Boolean);
  var
    rel: Integer;
  begin
    rel := selectionIndex - GDVars.vertMenuTop;
    if down then begin
      Inc(GDVars.vertMenuTop, rows);
      if count - rows < GDVars.vertMenuTop then
        GDVars.vertMenuTop := count - rows;
    end else begin
      Dec(GDVars.vertMenuTop, rows);
      if GDVars.vertMenuTop < 0 then
        GDVars.vertMenuTop := 0;
    end;
    selectionIndex := GDVars.vertMenuTop + rel;
    SkipLabels(down);
    DrawPage(GDVars.vertMenuTop);
  end;

  { Moves the selection one line down or up within the page, wrapping at its ends and skipping headings. }
  procedure MoveLine(down: Boolean);
  var
    { Unused in this version; see the other implementations of this routine. }
    pp: Types.PMenuLine;
    { Unused in this version; see the other implementations of this routine. }
    k: Integer;
    { Unused in this version; see the other implementations of this routine. }
    n: Integer;
  begin
    if down then begin
      Inc(selectionIndex);
      if GDVars.vertMenuTop + rows - 1 < selectionIndex then
        selectionIndex := GDVars.vertMenuTop;
    end else begin
      Dec(selectionIndex);
      if selectionIndex < GDVars.vertMenuTop then
        selectionIndex := GDVars.vertMenuTop + rows - 1;
    end;
    SkipLabels(down);
  end;

  { Returns the highlighted line as the selection, with the key that chose it. }
  procedure SelectLine;
  begin
    selection := MenuCore.FindListMember(selectionIndex, list);
    MenuVertical := ch;
    GDVars.listColLeft := 127;
    GDVars.listColRight := -128;
  end;

begin
  if list = nil then begin
    selectionIndex := 0;
    selection := nil;
    GDVars.listColLeft := 127;
    GDVars.listColRight := -128;
    MenuVertical := MenuCore.KEY_NONE;
  end else begin
    GDVars.listColLeft := ulCol;
    GDVars.listColRight := lrCol;
    width := lrCol - ulCol + 1;
    count := MenuCore.ListCount(list);
    rows := lrRow - ulRow + 1;
    { Note: the geometry and selectionIndex are not checked. Reversed bounds give meaningless width and rows, more than
      25 rows overrun GDVars.menuHotRows, and a selectionIndex past the list makes HighlightLine dereference nil. }
    p := list;
    headerCnt := 0;
    while (p <> nil) and (p^.inUse <> 0) do begin
      p := p^.next;
      Inc(headerCnt);
    end;
    p := list;
    total := 0;
    while p <> nil do begin
      p := p^.next;
      Inc(total);
    end;
    if total <= rows then
      GDVars.vertMenuTop := 0;
    if GDVars.vertMenuTop > selectionIndex then begin
      GDVars.vertMenuTop := selectionIndex;
      redraw := True;
    end;
    if GDVars.vertMenuTop > total then begin
      GDVars.vertMenuTop := 0;
      redraw := True;
    end;
    Inc(selectionIndex);
    MoveLine(False);
    if redraw then
      DrawPage(GDVars.vertMenuTop);
    redraw := False;
    registeredCount := 0;
    if initial <> $FF then
      for line := 0 to 19 do
        if GDVars.menuSlotTable[line].choiceIndex <> $FF then
          Inc(registeredCount);
    repeat
      GDVars.menuClickChanged := False;
      HighlightLine(selectionIndex);
      hMenu := menu;
      hasNext := False;
      hasPrev := False;
      optionCount := registeredCount;
      slotCursor := ShortInt(initial) + 1;
      if (not hasNext) and hasPrev and (GDVars.horizMenuChoice > 1) then
        Inc(GDVars.horizMenuChoice);
      if count - rows > GDVars.vertMenuTop then begin
        hMenu := hMenu + GDConsts.nextLabel;
        nextSlot := slotCursor;
        MenuCore.AppendSlot(slotCursor, optionCount);
        Inc(slotCursor);
        hasNext := True;
      end;
      if GDVars.vertMenuTop > headerCnt then begin
        hMenu := hMenu + GDConsts.prevLabel;
        prevSlot := slotCursor;
        MenuCore.AppendSlot(slotCursor, optionCount);
        Inc(slotCursor);
        hasPrev := True;
      end;
      if addExit then begin
        hMenu := hMenu + GDConsts.exitLabel;
        exitSlot := slotCursor;
        MenuCore.AppendSlot(slotCursor, optionCount);
        Inc(slotCursor);
      end;
      ch := MenuCore.MenuHorizontal(query, hMenu, True, False);
      prevCh := ch;
      if not GDVars.extendedKeyFlag then
        if Ord(ch) > registeredCount - 1 then begin
          GDVars.extendedKeyFlag := True;
          if (ch = Char(nextSlot)) and hasNext then
            prevCh := C_Keys.PAGE_DOWN
          else if (ch = Char(prevSlot)) and hasPrev then
            prevCh := C_Keys.PAGE_UP
          else if ch = Char(exitSlot) then
            prevCh := C_Keys.ESCAPE
          else
            GDVars.extendedKeyFlag := False;
      end;
      UnhighlightLine(selectionIndex);
      if GDVars.extendedKeyFlag then begin
        case prevCh of
          C_Keys.UP: MoveLine(False);
          C_Keys.DOWN: MoveLine(True);
          C_Keys.PAGE_UP: if hasPrev then MovePage(False);
          C_Keys.PAGE_DOWN: if hasNext then MovePage(True);
          'P': MovePage(False);
          'N': MovePage(True);
          C_Keys.ESCAPE, 'E', #0:
            begin
              selection := nil;
              MenuVertical := C_Keys.ESCAPE;
              GDVars.listColLeft := 127;
              GDVars.listColRight := -128;
              Exit
            end;
        end;
      end else begin
            if (GDVars.keyFromMouse <> 0) and GDVars.menuClickChanged then begin
              mouseCellRow := GDVars.mousePosY div 8;
              mouseCellCol := GDVars.mousePosX div 8;
              if mouseCellCol >= GDVars.listColLeft then
                if mouseCellCol <= GDVars.listColRight then begin
                line := 1;
                while (line <= 25) and (GDVars.menuHotRows[line] <> $FF) do begin
                  if GDVars.menuHotRows[line] = mouseCellRow then begin
                    clickedIdx := line - 1 + GDVars.vertMenuTop;
                    if clickedIdx = selectionIndex then begin
                      SelectLine;
                      Exit;
                    end else begin
                      UnhighlightLine(selectionIndex);
                      selectionIndex := line - 1 + GDVars.vertMenuTop;
                      HighlightLine(selectionIndex);
                    end;
                  end;
                  Inc(line);
                end;
              end;
            end else begin
              SelectLine;
              Exit;
            end;
      end;
    until False;
  end;
end;

function YesNoMenu(query: Types.TStr40; defaultChoice: Byte): Byte;
var
  choice: Byte;
begin
  GDVars.horizMenuChoice := defaultChoice + 1;
  MenuCore.ResetMenuSlots(1);
  repeat
    choice := Ord(MenuCore.MenuHorizontal(query, GDConsts.yesNoChoices, False, GDVars.eclPicShown));
  until (choice >= 0) and (choice < 2);
  YesNoMenu := choice;
end;

procedure AllocStringList(nodeCount: Integer; var list: Types.PMenuLine);
var
  p: Types.PMenuLine;
  i: Integer;
begin
  GetMem(list, SizeOf(Types.TMenuLine));
  list^.next := nil;
  list^.inUse := 0;
  list^.name := '';
  p := list;
  for i := 2 to nodeCount do begin
    GetMem(p^.next, SizeOf(Types.TMenuLine));
    p := p^.next;
    p^.next := nil;
    p^.inUse := 0;
    p^.name := '';
  end;
end;

procedure FreeStringList(var list: Types.PMenuLine);
var
  p: Types.PMenuLine;
  q: Types.PMenuLine;
begin
  p := list;
  while p <> nil do begin
    q := p;
    p := p^.next;
    FreeMem(q, SizeOf(Types.TMenuLine));
  end;
end;

begin
end.
