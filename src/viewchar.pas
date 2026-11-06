{ Character-sheet display, the inventory and money menus, item ready/trade/sell/identify handling, the hit-point rolls
  for a level gained or drained, and the paladin's lay-on-hands and cure-disease services. }
{$O+,F+,A-,I-,V-}
unit ViewChar;

interface

{ Draws the current character's sheet: name, status, gender and age, alignment, race, class (a human's earlier class
  after a slash while its level is below the current class's), levels (for a human with any earlier-class level, the
  first current class level, then a slash and the earlier class's level while it is below the current class's; otherwise
  each class's level joined by slashes), experience, the six abilities, the money, the combat values, and the readied
  weapon and armor. The character becomes the one the sheet shows. }
procedure DisplayChar;

{ Recalculates the current character's stats and shows its hit points, armor class, encumbrance, THAC0, movement and
  damage dice on the character sheet. }
procedure PrintCombatStats;

{ Draws one of the current character's abilities on its row of the character sheet, in light magenta while modifying and
  light green otherwise. Strength 18 with exceptional strength adds '(NN)', with 100 shown as '(00)'; a '*' marks a
  current value (or exceptional strength) that differs from its base.
  @param(statIdx The ability, 0 to 5.)
  @param(modifying True draws it in the modify color.) }
procedure PrintStat(statIdx: ShortInt; modifying: Boolean);

{ Redraws the money panel of the character sheet, one line per coin type the character holds. }
procedure PrintMoney;

{ The view-character menu: Items, Spells, Trade and Drop (or Deposit at a vault) coins, the paladin's Heal and Cure, and
  Exit. Runs until Exit, or until an item use reports done.
  @param(done Receives True when an item used in combat ended the turn.) }
procedure ViewCharMenu(var done: Boolean);

{ The items menu for GDVars.currentChar: Ready, Use, Trade, Deposit (at a vault) or Drop, Halve, Join, and, in a shop,
  Sell and Id. Runs until Exit, until the pack is empty, or until an item used in combat ends the turn.
  @param(done Receives True when an item used in combat ended the turn; always False outside combat.) }
procedure UseItemMenu(var done: Boolean);

{ Readies or unreadies an item for GDVars.currentChar. Cursed items cannot be unreadied; readying fails on wrong class,
  an occupied slot, or full hands, each with its own message.
  @param(it The item, a Types.PItemRec.) }
procedure ToggleReadyItem(it: Pointer);

{ Tells whether a character cannot take an item: the pack already holds 16 items and the item does not join an existing
  stack, or its weight would exceed the carrying allowance by more than 1500.
  @param(cr The character.)
  @param(quantity Nonzero enables the stack check.)
  @param(it The item.)
  @returns(True when the character cannot take it.) }
function CannotCarryItem(cr: Pointer; quantity: Byte; it: Pointer): Boolean;

{ Changes the current character: with a mouse and a character picked by it, to that one; otherwise up moves to the
  previous roster member, wrapping from the first to the last, and down to the next, wrapping from the last to the
  first.
  @param(c The key: up selects the previous member, down the next.) }
procedure SelectPrevNextChar(c: Char);

{ Shows GDVars.currentChar's spell list of the given kind and lets the player pick one.
  @param(menuType The list: 0 in memory, 1 grimoire, 2 on scroll, 3 on scrolls, 4 to choose, 5 to memorize, 6 to
    scribe.)
  @param(selType Passed to Magic.SpellSelection; 1 also redraws the frame.)
  @param(idx The highlighted entry, kept between calls; below 0 redraws the frame.)
  @param(notEmpty Receives whether the list had any entries.)
  @returns(The spell id, or 0 when nothing is picked.) }
function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;

{ Finds the smaller of two numbers.
  @param(a One number.)
  @param(b The other.)
  @returns(The smaller.) }
function MinWord(a, b: Word): Word;

{ Rolls or removes the hit points for a level in each class whose bit is set in a mask, divided among the classes. Each
  die is rolled twice and the better kept; above the fixed-gain level a class adds a flat amount. Removal never leaves
  maximum hit points above what HitPointCap allows.
  @param(cr The character.)
  @param(a The mask of classes that gained or lost a level.)
  @param(b The number of classes the hit points are divided among.)
  @param(c Nonzero rolls the hit points; 0 removes them.) }
procedure AdjustLevelHitPoints(cr: Pointer; a, b, c: Byte);

{ Finds the highest maximum hit points the character's levels allow, with each die at its top value plus the
  constitution bonus, averaged over the active classes.
  @param(cr The character.)
  @returns(The cap.) }
function HitPointCap(cr: Pointer): Byte;

{ Joins each matching stack in the current character's pack into an item, up to 255 per stack; the overflow stays in the
  last stack touched. Note: the charges, effect and special tests compare a stack with itself, so they always pass.
  @param(it The item.) }
procedure JoinItem(it: Pointer);

{ Lets the player move the highlight through the party list and choose a character.
  @returns(True when one is chosen, False on exit.) }
function PickCharacter: Boolean;

{ Drops money: lists the current character's coin types, asks how much of the chosen one to drop (at a vault, to
  deposit) and drops that many, until Exit or no coins are left. On the character sheet the coin panel is redrawn and
  the menu sits in it; otherwise the menu is in the lower window.
  @param(mode Nonzero on the character sheet, where the coin panel is redrawn; 0 for the menu in the lower window.) }
procedure DropMoneyMenu(mode: Byte);

implementation

uses Crt, Border, TextRend, Money, Magic, FxEngine, CharHlp, ClassCal, MenuCore, CbtMap, Types, GDConsts, GDVars,
  C_Class, C_Effect, C_Equip, C_Keys, C_Race, C_Stat, C_Ifc, C_Status, C_Npc, C_Spell;

procedure ToggleItemEffect(it: Types.PItemRec; readying: Boolean); forward;

procedure TradeTreasureMenu; forward;

function CanHeal(cr: Types.PCharRecord): Boolean; forward;

function CanCure(cr: Types.PCharRecord): Boolean; forward;

procedure PaladinLayOnHands(cr: Types.PCharRecord); forward;

procedure PaladinCureDisease(cr: Types.PCharRecord); forward;

function ClassConHpBonus(cr: Pointer; extra: Byte): ShortInt; forward;

function CheckItemAvail(it: Types.PItemRec): Boolean; forward;

procedure UseItem(it: Types.PItemRec; var done: Boolean); forward;

procedure ItemTradeMenu(it: Types.PItemRec); forward;

procedure HalveItem(it: Types.PItemRec); forward;

procedure SellItem(it: Types.PItemRec); forward;

procedure IdentifyItem(it: Types.PItemRec; var redraw: Boolean); forward;

procedure DisplayChar;
var
  { Unused in this version; see the other implementations of this routine. }
  statRow: Byte;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  statCol: Byte;
  i: ShortInt;
  j: ShortInt;
  s: String;
  multi: Boolean;
  dual: Boolean;
begin
  GDVars.globals.sheetChar := GDVars.currentChar;
  Border.DrawCharViewFrame;
  CharHlp.DisplayCreatureName(GDVars.globals.sheetChar, 1, 1, False);
  TextRend.DisplayString(20, 1, White, Black, 'Status:');
  TextRend.DisplayString(27, 1, LightGreen, Black, GDConsts.statusNameTable[GDVars.globals.sheetChar^.status]);
  s := GDConsts.genderNameTable[GDVars.globals.sheetChar^.gender];
  TextRend.DisplayString(1, 3, White, Black, s);
  TextRend.DisplayString(8, 3, White, Black, CharHlp.Uint16Str(GDVars.globals.sheetChar^.age) + ' years');
  s := GDConsts.alignmentNameTable[GDVars.globals.sheetChar^.alignment];
  TextRend.DisplayString(1, 4, White, Black, s);
  s := GDConsts.raceNameTable[GDVars.globals.sheetChar^.race];
  TextRend.DisplayString(20, 4, White, Black, s);

  dual := False;
  s := GDConsts.classNameTable[GDVars.globals.sheetChar^.charClass];
  if GDVars.globals.sheetChar^.race = C_Race.HUMAN then begin
    for j := 0 to 6 do
      if GDVars.globals.sheetChar^.oldLevels[j] > 0 then begin
        dual := True;
        if GDVars.globals.sheetChar^.oldLevels[j] <
           ClassCal.CurrentDualClassLevel(Types.PCharRecord(GDVars.globals.sheetChar)) then begin
          s := s + '/' + GDConsts.classNameTable[j];
          j := 6
        end
      end
  end;
  TextRend.DisplayString(1, 5, White, Black, s);
  TextRend.DisplayString(1, 7, White, Black, 'Level');

  s := '';
  if dual then begin
    for j := 0 to 6 do
      if GDVars.globals.sheetChar^.classLevels[j] > 0 then begin
        s := s + CharHlp.Uint8Str(GDVars.globals.sheetChar^.classLevels[j]);
        j := 6
      end;
    for j := 0 to 6 do
      if (GDVars.globals.sheetChar^.oldLevels[j] <
          ClassCal.CurrentDualClassLevel(Types.PCharRecord(GDVars.globals.sheetChar))) and
          (GDVars.globals.sheetChar^.oldLevels[j] > 0) then begin
        s := s + '/' + CharHlp.Uint8Str(GDVars.globals.sheetChar^.oldLevels[j]);
        j := 6
      end
  end else begin
    multi := False;
    for j := 0 to 6 do
      if GDVars.globals.sheetChar^.classLevels[j] > 0 then begin
        if multi then s := s + '/';
        s := s + CharHlp.Uint8Str(GDVars.globals.sheetChar^.classLevels[j] + GDVars.globals.sheetChar^.oldLevels[j]);
        multi := True
      end
  end;
  TextRend.DisplayString(7, 7, White, Black, s);
  TextRend.DisplayString(24, 6, White, Black, 'Experience:');
  s := CharHlp.Int32Str(GDVars.globals.sheetChar^.experience);
  TextRend.DisplayString(20 + ((20 - Length(s)) div 2), 7, LightGreen, Black, s);
  for i := C_Stat.STRENGTH to C_Stat.CHARISMA do begin
    case i of
      C_Stat.STRENGTH: s := 'STR ';
      C_Stat.INTELLIGENCE: s := 'INT ';
      C_Stat.WISDOM: s := 'WIS ';
      C_Stat.DEXTERITY: s := 'DEX ';
      C_Stat.CONSTITUTION: s := 'CON ';
      C_Stat.CHARISMA: s := 'CHA '
    end;
    TextRend.DisplayString(1, i + 9, LightGreen, Black, s);
    ViewChar.PrintStat(i, False)
  end;
  ViewChar.PrintMoney;
  ViewChar.PrintCombatStats;
  if GDVars.globals.sheetChar^.equipped[C_Equip.WEAPON] <> nil then
    CharHlp.PrintItemString(GDVars.globals.sheetChar, GDVars.globals.sheetChar^.equipped[C_Equip.WEAPON], 1, 21, False,
                            True);
  if GDVars.globals.sheetChar^.equipped[C_Equip.ARMOR] <> nil then
    CharHlp.PrintItemString(GDVars.globals.sheetChar, GDVars.globals.sheetChar^.equipped[C_Equip.ARMOR], 1, 22, False,
                            True)
end;

procedure PrintMoney;
var
  row: Byte;
  m: ShortInt;
  s: Types.TStr40;
begin
  Border.ClearBox(20, 9, 38, 15);
  row := 9;
  for m := 0 to 2 do
    if GDVars.currentChar^.coins[m] > 0 then begin
      s := GDConsts.moneyNameTable[m];
      TextRend.DisplayString(20, row, LightGreen, Black, s);
      s := CharHlp.Uint16Str(GDVars.currentChar^.coins[m]);
      TextRend.DisplayString(38 - Length(s), row, LightGreen, Black, s);
      Inc(row)
    end
end;

procedure PrintCombatStats;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mv: Byte;
  s: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;

  { Right-aligns a sheet field to its width. }
  procedure RightAlignField(var t: Types.TStr40; width: Byte);
  begin
    while Length(t) < width do
      t := ' ' + t
  end;

begin
  p := GDVars.currentChar;
  CharHlp.RecalcStats(p);
  TextRend.DisplayString(20, 3, White, Black, 'Hit Points ');
  Border.ClearBox(31, 3, 37, 3);
  CharHlp.PrintHitPoints(p, 31, 3, False, True);
  TextRend.DisplayString(1, 17, White, Black, 'Armor Class');
  case p^.armorClass[0] of
    1..50: col := 16;
    51..60: col := 17;
    61..69: col := 16
  else
    col := 15
  end;
  Border.ClearBox(15, 17, 17, 17);
  CharHlp.PrintArmorClass(p, col, 17);
  TextRend.DisplayString(20, 17, White, Black, 'Encumbrance');
  s := CharHlp.Uint16Str(p^.encumbrance);
  RightAlignField(s, 5);
  TextRend.DisplayString(33, 17, LightGreen, Black, s);

  TextRend.DisplayString(1, 18, White, Black, 'THAC0   ');
  Str(60 - p^.thac0Adj:0, s);
  RightAlignField(s, 2);
  TextRend.DisplayString(16, 18, LightGreen, Black, s);

  TextRend.DisplayString(20, 18, White, Black, 'Movement');
  mv := CharHlp.RecalcMovement(p);
  s := CharHlp.Uint8Str(p^.movementCur);
  RightAlignField(s, 3);
  TextRend.DisplayString(35, 18, LightGreen, Black, s);

  s := CharHlp.Uint8Str(p^.curRollsA[1]) + 'd' + CharHlp.Uint8Str(p^.curDiceA[1]);
  if p^.curModA[1] > 0 then
    s := s + '+' + CharHlp.Uint8Str(p^.curModA[1]);
  if p^.curModA[1] < 0 then
    s := s + '-' + CharHlp.Uint8Str(Abs(p^.curModA[1]));
  TextRend.DisplayString(1, 19, White, Black, 'Damage');
  RightAlignField(s, 7);
  TextRend.DisplayString(11, 19, LightGreen, Black, s)
end;

procedure PrintStat(statIdx: ShortInt; modifying: Boolean);
var
  s: Types.TStr40;
  col: Byte;
  hlCol: Byte;
begin
  if modifying then
    hlCol := LightMagenta
  else
    hlCol := LightGreen;
  col := 5;
  Border.ClearBox(col, statIdx + 9, 11, statIdx + 9);
  if GDVars.currentChar^.stats[statIdx].cur < 10 then
    Inc(col);
  TextRend.DisplayString(col, statIdx + 9, hlCol, Black, CharHlp.Uint8Str(GDVars.currentChar^.stats[statIdx].cur));
  if (statIdx = C_Stat.STRENGTH) and (GDVars.currentChar^.stats[C_Stat.STRENGTH].cur = 18) and
      (GDVars.currentChar^.strExcCur > 0) then begin
    s := CharHlp.Uint8Str(GDVars.currentChar^.strExcCur);
    if GDVars.currentChar^.strExcCur < 10 then
      s := '0' + s;
    if GDVars.currentChar^.strExcCur = 100 then
      s := '00';
    TextRend.DisplayString(7, 9, hlCol, Black, '(' + s + ')')
  end;
  if (GDVars.currentChar^.stats[statIdx].cur <> GDVars.currentChar^.stats[statIdx].base) or
      ((statIdx = C_Stat.STRENGTH) and (GDVars.currentChar^.strExcBase <> GDVars.currentChar^.strExcCur)) then
    TextRend.DisplayString(12, statIdx + 9, hlCol, Black, '*')
end;

procedure ViewCharMenu(var done: Boolean);
var
  ch: Byte;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  hasMoney: Boolean;
  hasSpells: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  ext: Boolean;
  spellResult: Byte;
  j: ShortInt;
  idx: Integer;
  optionCount: Byte;
  selection: Byte;
begin
  done := False;
  ch := $FF;
  GDVars.globals.tradeTarget := GDVars.currentChar;
  ViewChar.DisplayChar;
  FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
  selection := 1;
  while (ch <> 7) and not done do begin
    optionCount := 0;
    hasSpells := False;
    hasMoney := False;
    for spellResult := 0 to 140 do
      if (GDVars.globals.sheetChar^.spells[spellResult] and $7F) > 0 then
        hasSpells := True;
    for j := 0 to 2 do
      if GDVars.globals.sheetChar^.coins[j] > 0 then
        hasMoney := True;
    if GDVars.globals.sheetChar^.items <> nil then
      MenuCore.AppendSlot(0, optionCount);
    if hasSpells then
      MenuCore.AppendSlot(1, optionCount);
    if (((GDVars.globals.sheetChar^.npc < C_Npc.NON_PLAYER) or (GDVars.globals.sheetChar^.inPlay = 0) or
         (GDVars.globals.sheetChar^.status = C_Status.ANIMATED)) and hasMoney and
        (GDVars.interfaceState <> C_Ifc.IN_COMBAT)) then
      MenuCore.AppendSlot(2, optionCount);
    if hasMoney then
      if GDVars.interfaceState = C_Ifc.IN_VAULT then
        MenuCore.AppendSlot(3, optionCount)
      else
        MenuCore.AppendSlot(4, optionCount);
    if ViewChar.CanHeal(GDVars.currentChar) then
      MenuCore.AppendSlot(5, optionCount);
    if ViewChar.CanCure(GDVars.currentChar) then
      MenuCore.AppendSlot(6, optionCount);
    MenuCore.AppendSlot(7, optionCount);
    GDVars.horizMenuChoice := selection;
    ch := Byte(MenuCore.MenuHorizontal('', GDConsts.encampCharMenu, False, False));
    if GDVars.extendedKeyFlag and (ch = Ord(C_Keys.ESCAPE)) then
      ch := 7;
    selection := GDVars.horizMenuChoice;
    idx := -1;
    case ch of
      0: ViewChar.UseItemMenu(done);
      1: spellResult := ViewChar.SpellMenu(0, 0, idx, hasSpells);
      2: ViewChar.TradeTreasureMenu;
      3, 4: begin
              ViewChar.DropMoneyMenu(1);
              ViewChar.PrintMoney
            end;
      5: ViewChar.PaladinLayOnHands(GDVars.currentChar);
      6: ViewChar.PaladinCureDisease(GDVars.currentChar)
    end;
    if not done and (ch < 3) then
      ViewChar.DisplayChar
  end;
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    CbtMap.SetNoncombatPalette;
  CharHlp.DisplayNoncombatInterface
end;

{ Tells whether an item may leave the current character's inventory: a readied item must be unreadied first, and a
  scroll with scribing pending (charges, effect or special above $7F) asks before that work is lost.
  @param(it The item.)
  @returns(True when the item may go.) }
function CheckItemAvail(it: Types.PItemRec): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  p: Pointer;
begin
  CheckItemAvail := False;
  if it^.definition.equipped <> 0 then
    CharHlp.PrintBottomLine('Must be unreadied')
  else if not Magic.ItemReadable(it) then
    CheckItemAvail := True
  else if (it^.definition.charges > $7F) or (it^.definition.effect > $7F) or (it^.definition.special > $7F) then begin
    CharHlp.DisplayCreatureName(GDVars.currentChar, 1, 21, False);
    GDVars.textCursorCol := Length(GDVars.currentChar^.name) + 2;
    GDVars.textCursorRow := 21;
    TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, False, ' was going to scribe from that scroll');
    if MenuCore.YesNoMenu('is it Okay to lose it? ', GDConsts.noChoice) = GDConsts.yesChoice then
      CheckItemAvail := True
  end else
    CheckItemAvail := True;
  Border.ClearBox(1, 21, 38, 22)
end;

procedure UseItemMenu(var done: Boolean);
var
  optionCount: Byte;
  ch: Byte;
  { Unused in this version; see the other implementations of this routine. }
  menuState: Byte;
  needRedraw: Boolean;
  vmRedraw: Boolean;
  p: Types.PItemRec;
  sel: Types.PMenuLine;
  idx: Integer;
  { Unused in this version; see the other implementations of this routine. }
  previousItem: Types.PItemRec;
  cr: Types.PCharRecord;
  itemCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemTotal: Byte;
  selection: Byte;
begin
  cr := GDVars.currentChar;
  sel := Types.PMenuLine(cr^.items);
  idx := 0;
  vmRedraw := True;
  needRedraw := True;
  ch := $FF;
  selection := 1;
  while (ch <> 9) and not done and (cr^.numberOfItems > 0) do begin
    itemCount := cr^.numberOfItems;
    if cr^.items <> nil then begin
      FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
      optionCount := 0;
      MenuCore.AppendSlot(0, optionCount);
      if (cr^.inPlay <> 0) and (GDVars.vmBand.zone0^.antiMagic = 0) and
          ((GDVars.interfaceState = C_Ifc.CAMPING) or (GDVars.interfaceState = C_Ifc.AREA_MAP) or
           (GDVars.interfaceState = C_Ifc.DUNGEON) or
           ((GDVars.interfaceState = C_Ifc.IN_COMBAT) and
            (Types.PCombatRec(cr^.combatAddr)^.itemUseAllowed <> 0))) then
        MenuCore.AppendSlot(1, optionCount);
      if ((cr^.npc < C_Npc.NON_PLAYER) or (cr^.inPlay = 0) or (cr^.status = C_Status.ANIMATED)) and
          (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then
        MenuCore.AppendSlot(2, optionCount);
      if GDVars.interfaceState = C_Ifc.IN_VAULT then MenuCore.AppendSlot(3, optionCount)
      else MenuCore.AppendSlot(4, optionCount);
      if cr^.numberOfItems < 16 then MenuCore.AppendSlot(5, optionCount);
      MenuCore.AppendSlot(6, optionCount);
      if ((cr^.npc < C_Npc.NON_PLAYER) or (cr^.inPlay = 0) or (cr^.status = C_Status.ANIMATED)) and
          (GDVars.interfaceState = C_Ifc.IN_SHOP) and (GDVars.vmBand.zone0^.healerRequest <> 1) then
        MenuCore.AppendSlot(7, optionCount);
      if (GDVars.interfaceState = C_Ifc.IN_SHOP) and (GDVars.vmBand.zone0^.healerRequest <> 1) then
        MenuCore.AppendSlot(8, optionCount)
      ;
      p := cr^.items;
      while p <> nil do begin
        CharHlp.PrintItemString(cr, p, 0, 0, True, False);
        p := p^.next
      end;
      if needRedraw or (GDVars.itemsMenuRedraw <> 0) then begin
        Border.DrawListFrame;
        CharHlp.DisplayCreatureName(cr, 1, 1, True);
        TextRend.DisplayString(Length(cr^.name) + 4, 1, LightGreen, Black, GDConsts.itemsHeading);
        TextRend.DisplayString(1, 3, White, Black, GDConsts.readyItemHeading);
        vmRedraw := True;
        needRedraw := False;
        GDVars.itemsMenuRedraw := 0
      end;
      GDVars.horizMenuChoice := selection;
      ch := Byte(MenuCore.MenuVertical(GDConsts.emptyQuery, GDConsts.itemActionMenu, 1, 5, 38, 22,
                                       Types.PMenuLine(cr^.items), True, 8, vmRedraw, idx, sel));
      selection := GDVars.horizMenuChoice;
      if GDVars.extendedKeyFlag then
        if ch = Ord(C_Keys.ESCAPE) then ch := 9
      ;
      if sel <> nil then
        case ch of
          0: ViewChar.ToggleReadyItem(sel);
          1: if Types.PItemRec(sel)^.definition.equipped = 0 then begin
               CharHlp.PrintBottomLine(GDConsts.mustBeReadiedMsg);
               ch := $FF
             end else if Magic.ItemReadable(sel) or
               ((Types.PItemRec(sel)^.definition.effect > 0) and
                (Types.PItemRec(sel)^.definition.special < $80)) then begin
               ViewChar.UseItem(Types.PItemRec(sel), done);
               if GDVars.interfaceState <> C_Ifc.IN_COMBAT then done := False;
               if not done then needRedraw := True
             end;
          2: begin
               if ViewChar.CheckItemAvail(Types.PItemRec(sel)) then ViewChar.ItemTradeMenu(Types.PItemRec(sel))
               else ch := $FF;
               needRedraw := True
             end;
          3: if ViewChar.CheckItemAvail(Types.PItemRec(sel)) then begin
               GDVars.vaultTail := GDVars.treasureList;
               while (GDVars.vaultTail <> nil) and (GDVars.vaultTail^.next <> nil) do
                 GDVars.vaultTail := GDVars.vaultTail^.next;
               CharHlp.PrintItemString(cr, sel, 0, 0, False, False);
               if GDVars.interfaceState = C_Ifc.IN_VAULT then begin
                 TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                               'Your ' + Types.PItemRec(sel)^.name + 'will be left in the vault');
                 TextRend.PauseOnly;
                 if GDVars.treasureList = nil then begin
                   New(GDVars.treasureList);
                   GDVars.vaultTail := GDVars.treasureList
                 end else begin
                   New(GDVars.vaultTail^.next);
                   GDVars.vaultTail := GDVars.vaultTail^.next
                 end;
                 GDVars.vaultTail^ := Types.PItemRec(sel)^;
                 GDVars.vaultTail^.next := nil;
                 CharHlp.RemoveItem(cr, sel);
                 vmRedraw := True
               end
             end else ch := $FF;
          4: if ViewChar.CheckItemAvail(Types.PItemRec(sel)) then begin
               CharHlp.PrintItemString(cr, sel, 0, 0, False, False);
               TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                             GDConsts.yourPrefix + Types.PItemRec(sel)^.name +
                                             GDConsts.goneForeverMsg);
               if MenuCore.YesNoMenu(GDConsts.loseItemPrompt, GDConsts.noChoice) = GDConsts.yesChoice then begin
                 CharHlp.RemoveItem(GDVars.currentChar, sel);
                 vmRedraw := True
               end;
               Border.ClearBox(1, 21, 38, 22)
             end else ch := $FF;
          5: ViewChar.HalveItem(Types.PItemRec(sel));
          6: ViewChar.JoinItem(sel);
          7: if ViewChar.CheckItemAvail(Types.PItemRec(sel)) then ViewChar.SellItem(Types.PItemRec(sel))
             else ch := $FF;
          8: ViewChar.IdentifyItem(Types.PItemRec(sel), vmRedraw)
        end;
      CharHlp.RecalcStats(cr)
    end;
    if cr^.numberOfItems <> itemCount then vmRedraw := True
  end;
end;

{ Apply or remove the special power of an item as it is readied or unreadied. Special type 0 runs the item's effect
  handler; type 1 doubles the magic-user's level-5 spell slots, and on removal resets them from the level table and
  forgets any level-5 magic-user spells memorized beyond the restored count.
  @param(it The item.)
  @param(readying True as it is readied, False as it is unreadied.) }
procedure ToggleItemEffect(it: Types.PItemRec; readying: Boolean);
var
  specialType: Byte;
  rawSlots: Byte;
  { Unused in this version; see the other implementations of this routine. }
  damage: Byte;
  cr: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  classIndex: Byte;
  clampSlots: Byte;
  { Unused in this version; see the other implementations of this routine. }
  levelIndex: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lvl: Byte;
  forgottenCount: Byte;
begin
  cr := GDVars.currentChar;
  specialType := it^.definition.special and $7F;
  case specialType of
    0: begin
         GDVars.sharedScratch.itemEffectOverride := 1;
         FxEngine.CallEffectHandler(it^.definition.effect, cr, it, not readying)
       end;
    1: if readying then begin
         i := cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5] shl 1;
         cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5] := i
       end else begin
         rawSlots := ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.MAGE);
         clampSlots := rawSlots;
         cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5] := 0;
         if clampSlots > 29 then clampSlots := 29
         else if clampSlots < 2 then clampSlots := 2;
         Inc(cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5],
             GDConsts.classLevelTable[C_Class.MAGE].spellSlots[clampSlots, 5]);
         forgottenCount := 0;
         for i := 0 to 140 do
           if cr^.spells[i] <> 0 then
             if GDConsts.spellTable[cr^.spells[i]].castClass = 2 then
               if GDConsts.spellTable[cr^.spells[i]].level = 5 then begin
                 Inc(forgottenCount);
                 if forgottenCount > cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5] then
                   cr^.spells[i] := 0
               end
       end;
    3: FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
    5: FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
    9: if not readying then FxEngine.RemoveEffect(cr, C_Effect.SPIRITUAL_HAMMER, nil)
  end
end;

procedure ToggleReadyItem(it: Pointer);
var
  specialFlag: Boolean;
  refusal: Byte;
  slot: Byte;
  cr: Types.PCharRecord;
begin
  specialFlag := Types.PItemRec(it)^.definition.special > $7F;
  cr := GDVars.currentChar;
  if Types.PItemRec(it)^.definition.equipped <> 0 then begin
    if Types.PItemRec(it)^.definition.cursed <> 0 then
      CharHlp.PrintBottomLine('It''s Cursed!')
    else begin
      Types.PItemRec(it)^.definition.equipped := 0;
      if specialFlag then
        ViewChar.ToggleItemEffect(Types.PItemRec(it), False)
    end
  end else begin
    refusal := 0;
    if cr^.handsEquipped + GDVars.baseItemTable[Types.PItemRec(it)^.definition.itemType].hands > 2 then
      refusal := 3;
    slot := GDVars.baseItemTable[Types.PItemRec(it)^.definition.itemType].slot;
    case slot of
      C_Equip.WEAPON..C_Equip.BOOTS: if cr^.equipped[ShortInt(slot)] <> nil then refusal := 2;
      C_Equip.FIRST_RING: if cr^.equipped[C_Equip.SECOND_RING] <> nil then refusal := 2
    end;
    if Types.PItemRec(it)^.definition.itemType = 30 then
      if cr^.equipped[C_Equip.ARROW] <> nil then begin
        refusal := 2;
        slot := C_Equip.ARROW
      end;
    if (Types.PItemRec(it)^.definition.itemType = 12) or (Types.PItemRec(it)^.definition.itemType = 74) then
      if cr^.equipped[C_Equip.BOLT] <> nil then begin
        refusal := 2;
        slot := C_Equip.BOLT
      end;
    if (GDVars.baseItemTable[Types.PItemRec(it)^.definition.itemType].classMask and cr^.classMask) = 0 then
      refusal := 1;
    case refusal of
      0: begin
           Types.PItemRec(it)^.definition.equipped := 1;
           if specialFlag then
             ViewChar.ToggleItemEffect(Types.PItemRec(it), True)
         end;
      1: CharHlp.PrintBottomLine('Wrong Class');
      2: begin
           CharHlp.PrintItemString(cr, cr^.equipped[ShortInt(slot)], 0, 0, False, False);
           CharHlp.PrintBottomLine('already using ' + cr^.equipped[ShortInt(slot)]^.name)
         end;
      3: if not ((GDVars.interfaceState = C_Ifc.IN_COMBAT) and (cr^.quickfight <> 0)) then
           CharHlp.PrintBottomLine('Your hands are full!')
    end
  end
end;

{ Gives an item to another party member chosen by the player, unless that member cannot carry it.
  @param(it The item.) }
procedure ItemTradeMenu(it: Types.PItemRec);
var
  target: Pointer;
begin
  target := GDVars.globals.tradeTarget;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.SelectChar('Trade with Whom?', True, 1, target);
  if target <> nil then begin
    GDVars.globals.tradeTarget := target;
    if ViewChar.CannotCarryItem(target, 0, it) then
      CharHlp.PrintBottomLine('Overloaded')
    else begin
      CharHlp.AddItemCopy(target, it);
      CharHlp.RemoveItem(GDVars.currentChar, it);
      CharHlp.RecalcStats(target)
    end
  end
end;

{ Splits an item stack: a copy holding half the quantity, rounded down, and unreadied, follows the original, which keeps
  the rest. A quantity below 2 cannot be halved ("Can't halve that").
  @param(it The item.) }
procedure HalveItem(it: Types.PItemRec);
var
  newItem: Types.PItemRec;
  half: Byte;
  remainder: Byte;
begin
  half := it^.definition.quantity shr 1;
  if half > 0 then begin
    remainder := it^.definition.quantity - half;
    GetMem(newItem, SizeOf(Types.TItemRec));
    Move(it^, newItem^, SizeOf(Types.TItemRec));
    newItem^.definition.quantity := half;
    newItem^.definition.equipped := 0;
    newItem^.next := it^.next;
    it^.definition.quantity := remainder;
    it^.next := newItem
  end else
    CharHlp.PrintBottomLine('Can''t halve that')
end;

procedure JoinItem(it: Pointer);
var
  candidate: Types.PItemRec;
  nextItem: Types.PItemRec;
  itLocal: Types.PItemRec;
  remainingQty: Byte;
begin
  itLocal := Types.PItemRec(it);
  remainingQty := itLocal^.definition.quantity;
  candidate := GDVars.currentChar^.items;
  while candidate <> nil do begin
    nextItem := candidate^.next;
    if candidate <> itLocal then
      if candidate^.definition.quantity > 0 then
        if candidate^.definition.nameIds[1] = itLocal^.definition.nameIds[1] then
          if candidate^.definition.nameIds[2] = itLocal^.definition.nameIds[2] then
            if candidate^.definition.nameIds[3] = itLocal^.definition.nameIds[3] then
              if candidate^.definition.unidMask = itLocal^.definition.unidMask then
                if candidate^.definition.itemType = itLocal^.definition.itemType then
                  if candidate^.definition.plus = itLocal^.definition.plus then
                    if candidate^.definition.saveBonus = itLocal^.definition.saveBonus then
                      if candidate^.definition.cursed = itLocal^.definition.cursed then
                        if candidate^.definition.weight = itLocal^.definition.weight then
                          if candidate^.definition.charges = candidate^.definition.charges then
                            if candidate^.definition.charges < 2 then
                            if candidate^.definition.effect = candidate^.definition.effect then
                              if candidate^.definition.special = candidate^.definition.special then begin
                                if remainingQty + candidate^.definition.quantity <= 255 then begin
                                  Inc(remainingQty, candidate^.definition.quantity);
                                  CharHlp.RemoveItem(GDVars.currentChar, candidate)
                                end else begin
                                  itLocal^.definition.quantity := 255;
                                  candidate^.definition.quantity := candidate^.definition.quantity -
                                    (255 - remainingQty);
                                  remainingQty := candidate^.definition.quantity;
                                  itLocal := candidate
                                end
                              end;
    candidate := nextItem
  end;
  itLocal^.definition.quantity := remainingQty
end;

{ Use a readied item. A scroll lets the user pick one of its spells; magic-users and clerics always read it, a thief
  above level 9 succeeds three times in four. Any other item casts its effect spell. A successful use spends the scroll
  spell or one charge, and in combat may end the user's turn.
  @param(it The item.)
  @param(done Receives True when the use ended the user's turn.) }
procedure UseItem(it: Types.PItemRec; var done: Boolean);
var
  effectId: Byte;
  idx: Integer;
  notEmpty: Boolean;
begin
  idx := -1;
  GDVars.castFromItem := 0;
  effectId := 0;
  if Magic.ItemReadable(it) then begin
    GDVars.castingItem := it;
    effectId := ViewChar.SpellMenu(2, 1, idx, notEmpty)
  end else if (it^.definition.effect > 0) and (it^.definition.special < $80) then begin
    GDVars.castFromItem := 1;
    effectId := it^.definition.effect and $7F
  end;
  if effectId = 0 then
    done := False
  else begin
    if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (GDVars.currentChar^.quickfight = 0) then
      CharHlp.DisplayCombatInterface;
    if GDVars.castFromItem <> 0 then begin
      CharHlp.PrintCreatureMessage(GDVars.currentChar, 'uses an item', 10, False);
      if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
        TextRend.DisplayString(0, 23, LightGreen, Black, 'Item:');
        CharHlp.PrintItemString(GDVars.currentChar, it, 5, 23, False, True)
      end else
        CharHlp.PrintItemString(GDVars.currentChar, it, 1, 22, False, True);
      TextRend.PauseOnly;
      CharHlp.ClearMessageWindow
    end;
    GDVars.castFromItem := 1;
    if Magic.ItemReadable(it) then begin
      if (ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.MAGE) > 0) or
          (ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.CLERIC) > 0) then
        Magic.CastSpell(effectId, GDVars.currentChar^.quickfight, 0, done)
      else if (ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.THIEF) > 9) and
        (FxEngine.RollDice(1, 100) <= 75) then
        Magic.CastSpell(effectId, GDVars.currentChar^.quickfight, 0, done)
      else
        CharHlp.PrintCreatureMessage(GDVars.currentChar, 'oops!', GDVars.textCursorRow + 1, True)
    end else
      Magic.CastSpell(effectId, GDVars.currentChar^.quickfight, 0, done);
    GDVars.castFromItem := 0;
    if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (GDConsts.spellTable[effectId].whenCast <> 0) then
      done := CharHlp.EndActions(GDVars.currentChar)
  end;
  if done then
    if Magic.ItemReadable(it) then
      Magic.RemoveSpellFromScroll(GDVars.currentChar, it, effectId)
    else if it^.definition.charges > 0 then
      if it^.definition.quantity > 1 then
        Dec(it^.definition.quantity)
      else begin
        Dec(it^.definition.charges);
        if it^.definition.charges = 0 then
          CharHlp.RemoveItem(GDVars.currentChar, it)
      end
end;

{ Makes the shop's offer for an item: half its value times the quantity, divided by 20 for ammunition bundles. With a
  price, it names the platinum it will pay and asks whether the player will sell; without one, the item is worthless and
  the shop offers to dispose of it. On Yes the item goes, and the price is paid in platinum to the current character,
  any part that would overload the character going to the party pool.
  @param(it The item offered.) }
procedure SellItem(it: Types.PItemRec);
var
  priceWord: Word;
  sellPrice: Word;
  takable: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  t: LongInt;
  promptStr: String[40];
begin
  sellPrice := 0;
  if it^.definition.value > 0 then
    sellPrice := it^.definition.value shr 1;
  if it^.definition.quantity > 1 then
    if (it^.definition.itemType = 30) or (it^.definition.itemType = 12) then
      sellPrice := (it^.definition.quantity * sellPrice) div 20
    else
      sellPrice := it^.definition.quantity * sellPrice;
  CharHlp.PrintItemString(GDVars.globals.sheetChar, it, 0, 0, False, False);
  if sellPrice > 0 then begin
    TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                  'I''ll give you ' + CharHlp.Uint16Str(sellPrice) + ' platinum pieces for your ' +
                                  it^.name);
    promptStr := 'Will you sell ';
    if it^.definition.quantity < 2 then
      promptStr := promptStr + 'it? '
    else
      promptStr := promptStr + 'them? '
  end else begin
    if it^.definition.quantity < 2 then begin
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True, 'Your ' + it^.name + ' is worthless to me.');
      promptStr := 'Shall I dispose of it for you? '
    end else begin
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True, 'Your ' + it^.name + ' are worthless.');
      promptStr := 'Would you like to discard them? '
    end
  end;
  if MenuCore.YesNoMenu(promptStr, GDConsts.yesChoice) = GDConsts.yesChoice then begin
    if sellPrice > 0 then
      CharHlp.PrintBottomLine('Sold!')
    else if it^.definition.quantity < 2 then
      CharHlp.PrintBottomLine('I will give it to one of my sons.')
    else
      CharHlp.PrintBottomLine('Very well.  I''ll take them.');
    CharHlp.RemoveItem(GDVars.currentChar, it);
    priceWord := sellPrice;
    if Money.CheckOverload(GDVars.currentChar, priceWord, takable) then begin
      CharHlp.PrintBottomLine('Overloaded.  Money will be put in pool.');
      Inc(GDVars.currentChar^.coins[0], takable);
      Dec(sellPrice, takable);
      Inc(GDVars.moneyPool[0], sellPrice)
    end else
      Inc(GDVars.currentChar^.coins[0], sellPrice)
  end;
  Border.ClearBox(1, 21, 38, 22)
end;

{ Makes the shop's identify offer: 20 platinum pieces, asking whether it is a deal. On Yes the price comes from the
  current character's platinum and then the party pool, or the offer fails for lack of money. Once paid, it clears the
  item's three identify bits and shows what the item looks like, or says nothing new can be told when none was set.
  @param(it The item.)
  @param(redraw Set when the item's name changes, so the item list must be redrawn.) }
procedure IdentifyItem(it: Types.PItemRec; var redraw: Boolean);
var
  moneyOnHand: LongInt;
  poolCopy: LongInt;
  canIdentify: Boolean;
begin
  canIdentify := False;
  CharHlp.PrintItemString(GDVars.globals.sheetChar, it, 0, 0, False, False);
  TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                'For 20 platinum pieces I''ll identify your ' + it^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', GDConsts.yesChoice) = GDConsts.yesChoice then
  begin
    poolCopy := GDVars.moneyPool[0];
    moneyOnHand := GDVars.currentChar^.coins[0];
    if moneyOnHand >= 20 then begin
      canIdentify := True;
      Dec(GDVars.currentChar^.coins[0], 20)
    end else if poolCopy + moneyOnHand >= 20 then begin
      canIdentify := True;
      GDVars.currentChar^.coins[0] := 0;
      Dec(GDVars.moneyPool[0], 20 - moneyOnHand)
    end else begin
      CharHlp.PrintBottomLine('Not Enough Money');
      TextRend.PauseOnly
    end
  end;
  if canIdentify then begin
    if (it^.definition.unidMask and 7) = 0 then
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                    'I can''t tell anything new about your ' + it^.name)
    else begin
      it^.definition.unidMask := it^.definition.unidMask and $F8;
      CharHlp.PrintItemString(GDVars.globals.sheetChar, it, 0, 0, False, False);
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True, 'It looks like some sort of ' + it^.name);
      redraw := True
    end
  end;
  if canIdentify then
    TextRend.PauseOnly;
  Border.ClearBox(1, 21, 38, 22)
end;

{ Trades money: the player picks a party member to trade to (Exit leaves), then repeatedly picks one of the current
  character's coin types and an amount to give. It leaves once the character has no coins left. Note: leaving the coin
  menu does not set the outer loop's exit flag, so whether it goes back to picking a recipient depends, on the first
  pass, on an uninitialized local. }
procedure TradeTreasureMenu;
var
  selectedChar: Types.PCharRecord;
  i: ShortInt;
  moneyTypeIdx: ShortInt;
  j: Byte;
  spaceCount: Byte;
  listHead: Types.PMenuLine;
  sel: Types.PMenuLine;
  savedListHead: Types.PMenuLine;
  entryCount: Integer;
  idx: Integer;
  numText: String[15];
  spaces: String[15];
  workStr: String;
  selChar: Char;
  qty: Word;
  keepGoing: Boolean;
  tradedOk: Boolean;
  redraw: Boolean;
begin
  repeat
    selectedChar := GDVars.globals.tradeTarget;
    CharHlp.DisplayNoncombatInterface;
    CharHlp.SelectChar(GDConsts.tradeToPrompt, True, 1, Pointer(selectedChar));
    if selectedChar = nil then
      keepGoing := True
    else begin
      ViewChar.DisplayChar;
      repeat
        ViewChar.PrintMoney;
        GDVars.globals.tradeTarget := selectedChar;
        listHead := nil;
        sel := nil;
        savedListHead := nil;
        entryCount := 0;
        for i := 2 downto 0 do
          if GDVars.currentChar^.coins[i] <> 0 then begin
            Inc(entryCount);
            if listHead = nil then begin
              GetMem(Pointer(listHead), SizeOf(Types.TMenuLine));
              listHead^.next := nil
            end else begin
              sel := listHead;
              GetMem(Pointer(listHead), SizeOf(Types.TMenuLine));
              listHead^.next := sel
            end;
            numText := CharHlp.Uint16Str(GDVars.currentChar^.coins[i]);
            spaceCount := 14 - Length(GDConsts.moneyNameTable[i]);
            spaces := '';
            for j := 1 to spaceCount do
              spaces := spaces + ' ';
            listHead^.name := GDConsts.moneyNameTable[i] + spaces + numText;
            listHead^.inUse := 0
          end;
        savedListHead := listHead;
        idx := 0;
        redraw := True;
        MenuCore.ResetMenuSlots(0);
        selChar := MenuCore.MenuVertical(GDConsts.selectCoinTypePrompt, GDConsts.selectMenu, 20, 9, 38, 15, listHead,
                                         True, 1, redraw, idx, sel);
        if (selChar = #1) or (GDVars.extendedKeyFlag and (selChar = C_Keys.ESCAPE)) then
          sel := nil;
        if sel = nil then
          tradedOk := True
        else begin
          workStr := '';
          moneyTypeIdx := Money.ParseMoneyType(sel^.name, workStr);
          workStr := GDConsts.howMuchPrompt + workStr + GDConsts.willYouTradePrompt;
          qty := Money.InputNumberMax(GDVars.currentChar^.coins[moneyTypeIdx], workStr, LightGreen);
          Money.TradeMoney(GDVars.currentChar, Types.PCharRecord(selectedChar), qty, moneyTypeIdx);
          tradedOk := True;
          keepGoing := True;
          for i := 0 to 2 do
            if GDVars.currentChar^.coins[i] > 0 then begin
              keepGoing := False;
              tradedOk := False
            end
        end;
        if savedListHead <> nil then
          MenuCore.FreeStringList(savedListHead)
      until tradedOk
    end
  until keepGoing
end;

procedure DropMoneyMenu(mode: Byte);
var
  i: ShortInt;
  moneyTypeIdx: ShortInt;
  spaceCount: Byte;
  j: Byte;
  entryCount: Integer;
  idx: Integer;
  listHead: Types.PMenuLine;
  sel: Types.PMenuLine;
  savedListHead: Types.PMenuLine;
  keepGoing: Boolean;
  redraw: Boolean;
  numText: String[15];
  spaces: String[15];
  workStr: String;
  selChar: Char;
  qty: Word;
  ulCol: ShortInt;
  lrCol: ShortInt;
  ulRow: ShortInt;
  lrRow: ShortInt;
begin
  repeat
    if mode <> 0 then
      ViewChar.PrintMoney;
    listHead := nil;
    sel := nil;
    savedListHead := nil;
    entryCount := 0;
    for i := 2 downto 0 do
      if GDVars.currentChar^.coins[i] <> 0 then begin
        Inc(entryCount);
        if listHead = nil then begin
          GetMem(Pointer(listHead), SizeOf(Types.TMenuLine));
          listHead^.next := nil
        end else begin
          sel := listHead;
          GetMem(Pointer(listHead), SizeOf(Types.TMenuLine));
          listHead^.next := sel
        end;
        numText := CharHlp.Uint16Str(GDVars.currentChar^.coins[i]);
        spaceCount := 18 - Length(GDConsts.moneyNameTable[i]) - Length(numText);
        spaces := '';
        for j := 1 to spaceCount do
          spaces := spaces + ' ';
        listHead^.name := GDConsts.moneyNameTable[i] + spaces + numText;
        listHead^.inUse := 0
      end;
    savedListHead := listHead;
    idx := 0;
    redraw := True;
    MenuCore.ResetMenuSlots(1);
    if mode <> 0 then begin
      ulCol := 20;
      lrCol := 38;
      ulRow := 9;
      lrRow := 15
    end else begin
      ulCol := 1;
      lrCol := 38;
      ulRow := 17;
      lrRow := 22
    end;
    selChar := MenuCore.MenuVertical(GDConsts.selectCoinTypePrompt, GDConsts.selectMenu, ulCol, ulRow, lrCol, lrRow,
                                     listHead, True, 1, redraw, idx, sel);
    if (sel = nil) or (selChar = #1) then
      keepGoing := True
    else begin
      workStr := '';
      moneyTypeIdx := Money.ParseMoneyType(sel^.name, workStr);
      if GDVars.interfaceState = C_Ifc.IN_VAULT then
        workStr := GDConsts.howMuchPrompt + workStr + GDConsts.willYouDepositPrompt
      else
        workStr := GDConsts.howMuchPrompt + workStr + GDConsts.willYouDropPrompt;
      qty := Money.InputNumberMax(GDVars.currentChar^.coins[moneyTypeIdx], workStr, LightGreen);
      Money.DropMoney(GDVars.currentChar, qty, moneyTypeIdx);
      keepGoing := True;
      for i := 0 to 2 do
        if GDVars.currentChar^.coins[i] > 0 then
          keepGoing := False
    end;
    if savedListHead <> nil then
      MenuCore.FreeStringList(savedListHead)
  until keepGoing
end;

function CannotCarryItem(cr: Pointer; quantity: Byte; it: Pointer): Boolean;
var
  full: Boolean;
  itemWeight: Word;
  walkPtr: Types.PItemRec;
  merged: Boolean;
begin
  CharHlp.RecalcStats(cr);
  full := False;
  merged := False;
  walkPtr := Types.PCharRecord(cr)^.items;
  if Types.PItemRec(it)^.definition.quantity > 0 then
    if quantity <> 0 then
      while (not merged) and (walkPtr <> nil) do begin
        merged := (walkPtr^.definition.nameIds[1] = Types.PItemRec(it)^.definition.nameIds[1]) and
          (walkPtr^.definition.nameIds[2] = Types.PItemRec(it)^.definition.nameIds[2]) and
          (walkPtr^.definition.nameIds[3] = Types.PItemRec(it)^.definition.nameIds[3]) and
          (walkPtr^.definition.itemType = Types.PItemRec(it)^.definition.itemType) and
          (walkPtr^.definition.plus = Types.PItemRec(it)^.definition.plus) and
          (walkPtr^.definition.saveBonus = Types.PItemRec(it)^.definition.saveBonus) and
          (walkPtr^.definition.cursed = Types.PItemRec(it)^.definition.cursed) and
          (walkPtr^.definition.weight = Types.PItemRec(it)^.definition.weight) and
          (walkPtr^.definition.charges = Types.PItemRec(it)^.definition.charges) and
          (walkPtr^.definition.charges < 2) and (walkPtr^.definition.effect = Types.PItemRec(it)^.definition.effect) and
          (walkPtr^.definition.special = Types.PItemRec(it)^.definition.special);
        walkPtr := walkPtr^.next
      end;
  if (Types.PCharRecord(cr)^.numberOfItems > 15) and (not merged) then
    full := True;
  itemWeight := Types.PItemRec(it)^.definition.weight;
  if Types.PItemRec(it)^.definition.quantity > 0 then
    itemWeight := Types.PItemRec(it)^.definition.quantity * itemWeight;
  if LongInt(Types.PCharRecord(cr)^.encumbrance + itemWeight) > LongInt(CharHlp.WeightAllowance(cr) + 1500) then
    full := True;
  CannotCarryItem := full
end;

procedure SelectPrevNextChar(c: Char);
var
  walkPtr: Types.PCharRecord;
  localC: Char;
begin
  if GDVars.mouseInstalled and (GDVars.keyFromMouse <> 0) and (GDVars.clickedChar <> nil) then begin
    GDVars.currentChar := GDVars.clickedChar;
    GDVars.clickedChar := nil
  end else begin
    localC := c;
    walkPtr := GDVars.creatureListHead;
    if walkPtr <> nil then
      case localC of
      C_Keys.UP:
      begin
        if walkPtr = GDVars.currentChar then
          while walkPtr^.next <> nil do
            walkPtr := walkPtr^.next
        else
          while (walkPtr <> nil) and (walkPtr^.next <> GDVars.currentChar) do
            walkPtr := walkPtr^.next;
        GDVars.currentChar := walkPtr
      end;
      C_Keys.DOWN:
      begin
        if GDVars.currentChar^.next <> nil then
          walkPtr := GDVars.currentChar^.next
        else
          walkPtr := GDVars.creatureListHead;
        GDVars.currentChar := walkPtr
      end
      end
  end
end;

function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;
var
  queryStr: String[40];
begin
  case menuType of
    0: queryStr := 'in Memory';
    1: queryStr := 'in Grimoire';
    2: queryStr := 'on Scroll';
    3: queryStr := 'on Scrolls';
    4: queryStr := 'to Choose';
    5: queryStr := 'to Memorize';
    6: queryStr := 'to Scribe'
  else
    queryStr := ''
  end;
  notEmpty := Magic.GenerateSpellList(menuType);
  if notEmpty then begin
    if (idx < 0) or (selType = 1) then
      Border.DrawListFrame;
    CharHlp.DisplayCreatureName(GDVars.currentChar, 1, 1, True);
    TextRend.DisplayString(Length(GDVars.currentChar^.name) + 4, 1, LightGreen, Black, 'Spells ' + queryStr);
    SpellMenu := Magic.SpellSelection(selType, idx)
  end else
    SpellMenu := 0
end;

{ Tells whether a character can lay on hands: a paladin, or a former paladin with its earlier class active, okay,
  outside combat, and not within a day of its last healing.
  @param(cr The character.)
  @returns(True when it can heal.) }
function CanHeal(cr: Types.PCharRecord): Boolean;
var
  eff: Pointer;
begin
  CanHeal := ((cr^.charClass = C_Class.PALADIN) or
              ((cr^.oldLevels[C_Class.PALADIN] > 0) and
               ClassCal.EarlierClassActive(Types.PCharRecord(cr)))) and
    (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (cr^.status = C_Status.OKAY) and
    (not CharHlp.HasEffect(cr, C_Effect.RECENT_HEAL, eff))
end;

{ Tells whether a character can cure disease: a paladin, or a former paladin with its earlier class active, okay,
  outside combat, with a cure left.
  @param(cr The character.)
  @returns(True when it can cure.) }
function CanCure(cr: Types.PCharRecord): Boolean;
begin
  CanCure := ((cr^.charClass = C_Class.PALADIN) or
              ((cr^.oldLevels[C_Class.PALADIN] > 0) and
               ClassCal.EarlierClassActive(Types.PCharRecord(cr)))) and
    (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (cr^.status = C_Status.OKAY) and (cr^.poisonCount > 0)
end;

{ Lays on hands: asks whom to heal, restores 2 hit points per paladin level to the chosen character (who feels better,
  or is unaffected), and gives the paladin the recent-healing effect for 1440 minutes, so it heals once a day. Returns
  to the character sheet, also when nobody is chosen.
  @param(cr The paladin.) }
procedure PaladinLayOnHands(cr: Types.PCharRecord);
var
  selectedChar: Types.PCharRecord;
begin
  CharHlp.DisplayNoncombatInterface;
  selectedChar := GDVars.creatureListHead;
  CharHlp.SelectChar('Heal whom? ', True, 0, Pointer(selectedChar));
  if selectedChar = nil then
    ViewChar.DisplayChar
  else begin
    if FxEngine.RestoreHitPoints(selectedChar,
                                 ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.PALADIN) * 2,
                                 False) then begin
      CharHlp.DisplayRoster(selectedChar, True);
      CharHlp.PrintBottomLine(selectedChar^.name + ' feels better')
    end else
      CharHlp.PrintBottomLine(selectedChar^.name + ' is unaffected');
    FxEngine.AddEffect(cr, C_Effect.RECENT_HEAL, 1440, 0, False);
    ViewChar.DisplayChar
  end
end;

{ Cures disease: asks whom to cure, then says the target is not diseased and asks whether to cure anyway. On Yes, it
  uses one of the paladin's cures, gives the paladin the recent-cure effect for 10080 minutes (a week) unless it has it,
  and says the paladin cures the healthy. Nothing is cured. Returns to the character sheet. Note: the flag that marks a
  diseased target is never set, so each target is reported as not diseased.
  @param(cr The paladin.) }
procedure PaladinCureDisease(cr: Types.PCharRecord);
var
  selectedChar: Types.PCharRecord;
  confirmFlag: Boolean;
  answer: Byte;
  eff: Pointer;
begin
  CharHlp.DisplayNoncombatInterface;
  selectedChar := GDVars.creatureListHead;
  CharHlp.SelectChar('Cure whom? ', True, 0, Pointer(selectedChar));
  if selectedChar = nil then
    ViewChar.DisplayChar
  else begin
    confirmFlag := False;
    answer := GDConsts.yesChoice;
    if not confirmFlag then begin
      CharHlp.PrintCreatureMessage(selectedChar, 'is not diseased', 0, False);
      answer := MenuCore.YesNoMenu('cure anyway: ', GDConsts.noChoice);
      CharHlp.ClearMessageWindow
    end;
    if answer = GDConsts.yesChoice then begin
      GDVars.effectLock := 1;
      GDVars.effectLock := 0;
      if cr^.poisonCount > 0 then
        Dec(cr^.poisonCount);
      if not CharHlp.HasEffect(cr, C_Effect.RECENT_CURE, eff) then
        FxEngine.AddEffect(cr, C_Effect.RECENT_CURE, 10080, 0, True);
      if confirmFlag then
        CharHlp.PrintBottomLine(selectedChar^.name + ' is cured')
      else
        CharHlp.PrintBottomLine(cr^.name + ' cures the healthy')
    end;
    ViewChar.DisplayChar
  end
end;

function PickCharacter: Boolean;
var
  selChar: Char;
  savedMouseMode: Byte;
begin
  savedMouseMode := GDVars.mouseMenuMode;
  GDVars.mouseMenuMode := 1;
  repeat
    MenuCore.ResetMenuSlots(1);
    selChar := MenuCore.MenuHorizontal(GDConsts.pickCharacterPrompt, GDConsts.selectMenu, True, False);
    if GDVars.extendedKeyFlag then
      if selChar = C_Keys.ESCAPE then begin
        selChar := #1;
        GDVars.extendedKeyFlag := False
      end else begin
        CharHlp.DisplayRoster(GDVars.currentChar, False);
        ViewChar.SelectPrevNextChar(selChar);
        CharHlp.DisplayRoster(GDVars.currentChar, True)
      end
  until not GDVars.extendedKeyFlag and (selChar <= #1);
  CharHlp.DisplayRoster(GDVars.currentChar, True);
  PickCharacter := (selChar = #0);
  GDVars.mouseMenuMode := savedMouseMode
end;

{ Finds the constitution bonus to hit points per hit die for a class. Fighters, paladins and rangers get the extra bonus
  for constitution above 16.
  @param(cr The character.)
  @param(extra The class.)
  @returns(The bonus.) }
function ClassConHpBonus(cr: Pointer; extra: Byte): ShortInt;
var
  total: Byte;
  { Unused in this version; see the other implementations of this routine. }
  conScore: Integer;
begin
  total := 0;
  Inc(total, GDConsts.conBonusTable[Types.PCharRecord(cr)^.stats[C_Stat.CONSTITUTION].cur]);
  if (extra = C_Class.FIGHTER) or (extra = C_Class.PALADIN) or (extra = C_Class.RANGER) then
    case Types.PCharRecord(cr)^.stats[C_Stat.CONSTITUTION].cur of
      17: Inc(total);
      18: Inc(total, 2);
      19, 20: Inc(total, 3);
      21..23: Inc(total, 4);
      24, 25: Inc(total, 5)
    end;
  ClassConHpBonus := total
end;

procedure AdjustLevelHitPoints(cr: Pointer; a, b, c: Byte);
var
  spent: Byte;
  roll2: Byte;
  slotTotal: Byte;
  diceCount: Byte;
  weightedTotal: Byte;
  lvl: ShortInt;
  pointsCost: Byte;
  reserve: Byte;
begin
  slotTotal := 0;
  weightedTotal := 0;
  for lvl := 0 to 6 do
    if Types.PCharRecord(cr)^.classLevels[lvl] > 0 then
      if (GDConsts.levelUpClassBit[lvl] and a) > 0 then
        if Types.PCharRecord(cr)^.classLevels[lvl] < GDConsts.firstFixedHpLevel[lvl] then begin
          if Types.PCharRecord(cr)^.classLevels[lvl] > 1 then
            diceCount := 1
          else
            diceCount := GDConsts.firstLevelHitDice[lvl];
          spent := FxEngine.RollDice(diceCount, GDConsts.hitDieSides[lvl]);
          roll2 := FxEngine.RollDice(diceCount, GDConsts.hitDieSides[lvl]);
          if roll2 > spent then
            spent := roll2;
          Inc(slotTotal, spent);
          Inc(weightedTotal, ViewChar.ClassConHpBonus(cr, lvl) * diceCount)
        end else
          case lvl of
            C_Class.FIGHTER, C_Class.PALADIN: slotTotal := 3;
            C_Class.RANGER, C_Class.CLERIC, C_Class.THIEF: slotTotal := 2;
            C_Class.MAGE: slotTotal := 1
          end;
  with Types.PCharRecord(cr)^ do begin
    if b > 0 then begin
      slotTotal := slotTotal div b;
      if slotTotal < 1 then
        slotTotal := 1;
      weightedTotal := weightedTotal div b;
      spent := hpMax - hpCur;
      if c <> 0 then begin
        Inc(hpRolled, slotTotal);
        Inc(hpMax, slotTotal + weightedTotal);
        if spent > hpMax then
          hpCur := 0
        else
          hpCur := hpMax - spent
      end else begin
        if hpRolled > slotTotal then
          Dec(hpRolled, slotTotal)
        else
          hpRolled := 0;
        pointsCost := slotTotal + weightedTotal;
        reserve := ViewChar.HitPointCap(cr);
        if (hpMax - pointsCost) > reserve then
          pointsCost := hpMax - reserve;
        if pointsCost > hpMax then
          hpMax := 0
        else
          Dec(hpMax, pointsCost);
        if spent > hpMax then
          hpCur := 0
        else
          hpCur := hpMax - spent
      end
    end else begin
      hpCur := 0;
      hpRolled := 0;
      hpMax := 0
    end
  end
end;

function HitPointCap(cr: Pointer): Byte;
var
  levelCount: Byte;
  total: Word;
  levelValue: ShortInt;
  lvl: ShortInt;
  adjLevel: Byte;
  termB: Byte;
  termA: Byte;
  flag: Boolean;
begin
  with Types.PCharRecord(cr)^ do begin
    levelCount := 0;
    total := 0;
    for lvl := 0 to 6 do
      if ((classLevels[lvl] > 0) and (classLevels[lvl] > dualLevel))
         or (oldLevels[lvl] > 0) then begin
        levelValue := CharHlp.ClassConAdj(cr, lvl);
        if oldLevels[lvl] > 0 then begin
          adjLevel := oldLevels[lvl];
          flag := True
        end else begin
          Inc(levelCount);
          adjLevel := classLevels[lvl];
          flag := (dualLevel = 0)
        end;
        if GDConsts.firstFixedHpLevel[lvl] > adjLevel then begin
          if (not flag) and (adjLevel > dualLevel) then begin
            adjLevel := adjLevel - dualLevel;
            flag := True
          end else
            if lvl = C_Class.RANGER then Inc(adjLevel);
          if flag then
            Inc(total, (GDConsts.hitDieSides[lvl] + levelValue) * adjLevel)
        end else begin
          if (not flag) and (adjLevel > dualLevel) then begin
            flag := True;
            if dualLevel >= GDConsts.firstFixedHpLevel[lvl] - 1 then begin
              termA := adjLevel - dualLevel;
              termB := 0
            end else begin
              termB := (GDConsts.firstFixedHpLevel[lvl] - dualLevel - 1) * (GDConsts.hitDieSides[lvl] + levelValue);
              termA := adjLevel - GDConsts.firstFixedHpLevel[lvl] + 1
            end
          end else begin
            termA := adjLevel - GDConsts.firstFixedHpLevel[lvl] + 1;
            termB := (GDConsts.firstFixedHpLevel[lvl] - 1) * (GDConsts.hitDieSides[lvl] + levelValue)
          end;
          if lvl = C_Class.RANGER then
            Inc(termB, GDConsts.hitDieSides[lvl] + levelValue);
          if flag then
            case lvl of
              C_Class.CLERIC, C_Class.RANGER, C_Class.THIEF: Inc(total, termB + termA * 2);
              C_Class.FIGHTER, C_Class.PALADIN: Inc(total, termB + termA * 3);
              C_Class.MAGE: Inc(total, termB + termA)
            end
        end
      end;
    if levelCount > 0 then
      total := total div levelCount
    else if dualLevel = 0 then
      total := 0;
    HitPointCap := Byte(total)
  end
end;

function MinWord(a, b: Word): Word;
begin
  MinWord := a;
  if b < a then
    MinWord := b
end;

begin
end.
