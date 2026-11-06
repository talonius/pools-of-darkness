{ The camp: its menus and the noncombat spell work, covering casting, memorizing, scribing, the party's effects and
  order, game settings, resting, and Fix, which heals the party over two rests. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Camp;

interface

{ The camp menu: Save, View, Magic, Rest, Alter, Fix and Exit; Rest and Fix are left out where every rest is
  interrupted. Pending scribing is canceled on entry and on exit, and the previous interface state is restored.
  @param(interrupted Receives True when a rest was broken off by a wandering encounter, which also ends the menu.) }
procedure CampMainMenu(var interrupted: Boolean);

{ Casts spells from GDVars.currentChar's memory outside combat, one after another until the player picks none. }
procedure NoncombatCastMenu;

implementation
uses GameIo, Border, TextRend, SaveLoad, CharGen, ViewChar, GameTime, Magic, FxEngine, CharHlp, MenuCore, Types,
  GDConsts, GDVars, C_Class, C_Effect, C_Keys, C_Race, C_Status, C_Spell, C_Stat, C_Ifc, Crt;

const
  { the spells Fix counts by the spell slots of the members who know them, and the one it casts to restore drained
    levels }
  SPELL_CURE_LIGHT_WOUNDS = 3;
  SPELL_HEAL = 36;
  SPELL_CURE_BLINDNESS = 37;
  SPELL_REMOVE_CURSE_CLERIC = 43;
  SPELL_CURE_SERIOUS_WOUNDS = 58;
  SPELL_NEUTRALIZE_POISON = 67;
  SPELL_CURE_CRITICAL_WOUNDS = 71;
  SPELL_RAISE_DEAD = 75;
  SPELL_REMOVE_CURSE_MAGIC_USER = 89;
  SPELL_RESTORATION = 102;
  SPELL_RESURRECTION = 105;
  SPELL_STONE_TO_FLESH = 113;

  { CanDoSpellActivity's activities }
  ACTIVITY_CAST = 1;
  ACTIVITY_MEMORIZE = 2;
  ACTIVITY_SCRIBE = 3;

  MAX_GAME_DELAY = 9;

  { the effects CampDisplayMenu lists }
  VISIBLE_EFFECT_IDS = [1, 2, 4..6, 8..10, 12..17, 19..21, 23..25, 28, 29, 32..39,
                        41, 42, 45, 46, 49, 50, 54..57, 61..63, 68, 69, 71, 74, 75, 78,
                        89, 92, 93, 98, 115, 119, 121..123, 126];

{ Finds the rest time a character needs to finish memorizing and scribing: 15 minutes per level of each pending spell,
  plus 4 hours when any spell is pending, or 6 when any is above level 2. Spells being memorized count only while the
  character is in play; scribing counts readable items only. The base hours (0, 4 or 6) are kept in the character's
  record.
  @param(cr The character.)
  @returns(The rest time in minutes.) }
function CampSpellPrepTime(cr: Types.PCharRecord): Word;
var
  maxMem: Byte;
  maxScr: Byte;
  cntMem: Byte;
  cntScr: Byte;
    p: Types.PItemRec;
    i: Byte;
    lvl: Byte;
    base: Byte;
begin
  maxMem := 0; maxScr := 0; cntMem := 0; cntScr := 0;
  for i := 0 to SizeOf(cr^.spells) - 1 do
    if (cr^.spells[i] > C_Spell.ID_MASK) and (cr^.inPlay <> 0) then begin
      lvl := GDConsts.spellTable[cr^.spells[i] and C_Spell.ID_MASK].level;
      if lvl > maxMem then maxMem := lvl;
      Inc(cntMem, lvl);
    end;
  p := cr^.items;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to SizeOf(p^.definition.scrollSpells) do
        if p^.definition.scrollSpells[i] > C_Spell.ID_MASK then begin
          lvl := GDConsts.spellTable[p^.definition.scrollSpells[i] and C_Spell.ID_MASK].level;
          if lvl > maxScr then maxScr := lvl;
          Inc(cntScr, lvl);
        end;
    p := p^.next;
  end;
  base := 0;
  if (cntMem > 0) or (cntScr > 0) then base := 4;
  if (maxMem > 2) or (maxScr > 2) then base := 6;
  cr^.spellPrepTime := base;
  CampSpellPrepTime := base * 60 + cntMem * 15 + cntScr * 15;
end;

{ Removes every pending memorize request of a character, zeroing the slot, and clears its preparation hours.
  @param(cr The character.) }
procedure ResetMemorize(cr: Types.PCharRecord);
var i: Byte;
begin
  for i := 0 to SizeOf(cr^.spells) - 1 do
    if cr^.spells[i] > C_Spell.ID_MASK then cr^.spells[i] := 0;
  cr^.spellPrepTime := 0;
end;

{ Clears the pending flag of every scroll spell on a character's readable items.
  @param(cr The character.) }
procedure ResetScribe(cr: Types.PCharRecord);
var i: Byte; p: Types.PItemRec;
begin
  p := cr^.items;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to SizeOf(p^.definition.scrollSpells) do
        p^.definition.scrollSpells[i] := p^.definition.scrollSpells[i] and C_Spell.ID_MASK;
    p := p^.next;
  end;
end;

{ Clears every member's scribing marks. }
procedure ResetPartySpellActivities;
var character: Types.PCharRecord;
begin
  character := GDVars.creatureListHead;
  while character <> nil do begin
    Camp.ResetScribe(character);
    character := character^.next;
  end;
end;

{ Finds the current character's free slots for spells of one class and level: its allowance less the spells of that
  class and level memorized or pending, never below 0.
  @param(spellLevel The spell level.)
  @param(spellClass The spell list: cleric, druid or magic-user.)
  @param(usedSlots Receives how many spells of that class and level are memorized or pending.)
  @returns(The free slots.) }
function SpellSlotsRemaining(spellLevel: Byte; spellClass: ShortInt; var usedSlots: Byte): Byte;
var
  n: Byte;
  i: Byte;
begin
  with GDVars.currentChar^ do begin
    n := 0;
    for i := 0 to SizeOf(spells) - 1 do
      if spells[i] > 0 then
        if (GDConsts.spellTable[spells[i] and C_Spell.ID_MASK].level = Byte(spellLevel)) and
            (GDConsts.spellTable[spells[i] and C_Spell.ID_MASK].castClass = Byte(spellClass)) then Inc(n);
    usedSlots := n;
    if spellSlots[spellClass, spellLevel] < n then n := spellSlots[spellClass, spellLevel];
    SpellSlotsRemaining := spellSlots[spellClass, spellLevel] - n;
  end;
end;

{ Checks whether the current character can cast, memorize or scribe. The area's anti-magic flag blocks casting; animated
  or disabled characters can do none of them. On failure, prints the character's name and the reason.
  @param(activity The activity: cast, memorize or scribe.)
  @returns(True when the character can do it.) }
function CanDoSpellActivity(activity: Byte): Boolean;
var message: String[40];
begin
  message := '';
  if (activity = Camp.ACTIVITY_CAST) and (GDVars.vmBand.zone0^.antiMagic > 0) then
    message := 'cannot cast spells in this area'
  else if (GDVars.currentChar^.status = C_Status.ANIMATED) or (GDVars.currentChar^.inPlay = 0) then begin
    message := 'is in no condition to ';
    case activity of
      Camp.ACTIVITY_CAST: message := message + 'cast any spells';
      Camp.ACTIVITY_MEMORIZE: message := message + 'memorize spells';
      Camp.ACTIVITY_SCRIBE: message := message + 'scribe any scrolls';
    end;
  end;
  if message = '' then CanDoSpellActivity := True
  else begin
    CanDoSpellActivity := False;
    CharHlp.PrintCreatureMessage(GDVars.currentChar, message, 10, True);
  end;
end;

procedure NoncombatCastMenu;
var menuIndex: Integer; notEmpty: Boolean; needsRedraw: Boolean; castSelected: Boolean; spellId: Byte;
begin
  needsRedraw := False;
  menuIndex := -1;
  GDVars.horizMenuChoice := 1;
  if Camp.CanDoSpellActivity(Camp.ACTIVITY_CAST) then begin
    repeat
      spellId := ViewChar.SpellMenu(0, 1, menuIndex, notEmpty);
      if spellId <> 0 then begin
        needsRedraw := True;
        Border.ClearBox(1, 17, 38, 22);
        Magic.CastSpell(spellId, 0, 1, castSelected);
      end else begin
        if notEmpty then needsRedraw := True
        else CharHlp.PrintCreatureMessage(GDVars.currentChar, 'has no spells memorized', 10, True);
      end;
    until spellId = 0;
  end;
  if needsRedraw then CharHlp.DisplayNoncombatInterface;
end;

{ Shows the current character's free spell slots in the lower window, after clearing it: a line for each of the cleric,
  druid and magic-user lists with any allowance, a column for each level 1..9. A level with no allowance is blank; a
  full level shows zero. Also resets the magic-user bonus slot count to 0.
  @returns(True when the character has any spell allowance, even if every slot is taken.) }
function DisplaySpellSlots: Boolean;
var s: String[40];
    slotStr: array[1..9, 0..2] of String[2];
    canDo: array[0..2] of Byte;
    typ: ShortInt;
    lvl: Byte;
    col: Byte;
    row: Byte;
    any: Boolean;
    { Unused in this version; see the other implementations of this routine. }
    column: Word;
    usedSlots: Byte;
begin
  GDVars.sharedScratch.magicBonusSlots := 0;
  any := False;
  for typ := C_Spell.CLERIC_LIST to C_Spell.MAGIC_USER_LIST do begin
    canDo[typ] := 0;
    for lvl := 1 to 9 do begin
      slotStr[lvl, typ] := TextRend.NumToStr(Camp.SpellSlotsRemaining(lvl, typ, usedSlots));
      if GDVars.currentChar^.spellSlots[typ, lvl] = 0 then slotStr[lvl, typ] := ' '
      else begin canDo[typ] := 1; any := True end;
    end;
  end;
  if any then begin
    Border.ClearBox(1, 17, 38, 22);
    row := 1;
    for typ := C_Spell.CLERIC_LIST to C_Spell.MAGIC_USER_LIST do
      if canDo[typ] <> 0 then begin
        case typ of
          C_Spell.CLERIC_LIST: s := '    Cleric :';
          C_Spell.DRUID_LIST: s := '     Druid :';
          C_Spell.MAGIC_USER_LIST: s := 'Magic-User :';
        end;
        TextRend.DisplayString(1, row + 17, LightGreen, Black, s);
        col := 13;
        for lvl := 1 to 9 do begin
          TextRend.DisplayString(col + 1, row + 17, LightGreen, Black, slotStr[lvl, typ]);
          Inc(col, 3);
        end;
        Inc(row);
      end;
  end;
  DisplaySpellSlots := any;
end;

{ Rests the party for the longest spell preparation time among its members, then clears the rest clock.
  @param(interrupted Set when the rest is interrupted.) }
procedure RestForSpellPrep(var interrupted: Boolean);
var
  character: Types.PCharRecord;
  maxPrepMinutes: Word;
  prepMinutes: Word;
  { Unused in this version; see the other implementations of this routine. }
  hours: Word;
begin
  maxPrepMinutes := 0;
  character := GDVars.creatureListHead;
  while character <> nil do begin
    prepMinutes := Camp.CampSpellPrepTime(character);
    if maxPrepMinutes < prepMinutes then maxPrepMinutes := prepMinutes;
    character := character^.next;
  end;
  GDVars.restState.restTime[3] := maxPrepMinutes div 60;
  GDVars.restState.restTime[2] := (maxPrepMinutes - 60 * GDVars.restState.restTime[3]) div 10;
  GDVars.restState.restTime[1] := maxPrepMinutes mod 10;
  interrupted := GameTime.CampRest(True);
  GameIo.ZeroFill(GDVars.restState.restTime, SizeOf(GDVars.restState.restTime));
  CharHlp.PrintMiscInfo;
end;

{ Sorts the current character's memorized-spell slots by spell ID, keeping each pending flag with its spell. Empty slots
  sort to the front. }
procedure SortMemorizedSpells;
var
  i: Byte;
  j: Byte;
  swappedSpell: Byte;
begin
  for i := 0 to SizeOf(GDVars.currentChar^.spells) - 2 do
    for j := i to SizeOf(GDVars.currentChar^.spells) - 1 do
      if (GDVars.currentChar^.spells[i] and C_Spell.ID_MASK) >
          (GDVars.currentChar^.spells[j] and C_Spell.ID_MASK) then begin
        swappedSpell := GDVars.currentChar^.spells[i];
        GDVars.currentChar^.spells[i] := GDVars.currentChar^.spells[j];
        GDVars.currentChar^.spells[j] := swappedSpell;
      end;
end;

{ Runs the Memorize menu. When spells are pending they are shown first; picking one keeps them and ends the menu, while
  leaving the list discards them. Then each spell picked from the spellbook is marked pending while a slot of its level
  and class is free (or, for a magic-user spell, a bonus slot), and the pending list is shown again if the spellbook was
  shown. When the character may not memorize but is in play, 'cannot memorize any spells' is printed as well. }
procedure CampMemorizeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
    spellId: Byte;
    i: Byte;
    idx: Integer;
    used: Byte;
begin
  if Camp.CanDoSpellActivity(Camp.ACTIVITY_MEMORIZE) then begin
    done := False;
    idx := -1;
    GDVars.horizMenuChoice := 1;
    spellId := ViewChar.SpellMenu(5, 5, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if spellId = 0 then Camp.ResetMemorize(GDVars.currentChar)
      else done := True;
    end else redraw := False;
    idx := -1;
    while done = False do begin
      done := Camp.DisplaySpellSlots = False;
      if done then CharHlp.PrintCreatureMessage(GDVars.currentChar, 'cannot memorize any spells', 10, True)
      else begin
        spellId := ViewChar.SpellMenu(1, 2, idx, notEmpty);
        redraw := True;
        if spellId = 0 then done := True
        else if (Camp.SpellSlotsRemaining(GDConsts.spellTable[spellId].level,
                                          ShortInt(GDConsts.spellTable[spellId].castClass), used) > 0) or
          ((GDConsts.spellTable[spellId].castClass = C_Spell.MAGIC_USER_LIST) and
           (GDVars.sharedScratch.magicBonusSlots > 0)) then begin
          GDVars.sharedScratch.memorizeRedraw := 0;
          i := 0;
          while GDVars.currentChar^.spells[i] <> 0 do Inc(i);
          GDVars.currentChar^.spells[i] := spellId + C_Spell.PENDING_FLAG;
          Camp.SortMemorizedSpells;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(5, 5, idx, notEmpty);
      if notEmpty then
        if spellId = 0 then Camp.ResetMemorize(GDVars.currentChar);
    end;
    if redraw then CharHlp.DisplayNoncombatInterface;
  end else if GDVars.currentChar^.inPlay <> 0 then
    CharHlp.PrintCreatureMessage(GDVars.currentChar, 'cannot memorize any spells', 10, True);
end;

{ Runs the Scribe menu. The spells already pending are shown first: Yes keeps them and skips the choosing, No clears
  them. Then scroll spells are chosen and marked pending, refusing a spell already known or pending or beyond the
  character's slots, and when the scrolls were shown the pending spells are confirmed again. Note: the marking does not
  check that the item is readable; it marks the first unmarked spell byte equal to the spell on any item. Note: the
  spell's class and level index the slot table unchecked, so a spell an item alone provides can read past it. }
procedure CampScribeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
    spellId: Byte;
    { Unused in this version; see the other implementations of this routine. }
    spellClass: Byte;
    i: Byte;
    idx: Integer;
    p: Types.PItemRec;
    found: Boolean;
begin
  if Camp.CanDoSpellActivity(Camp.ACTIVITY_SCRIBE) then begin
    done := False;
    idx := -1;
    spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu(GDConsts.scribeSpellsPrompt, GDConsts.yesChoice) = GDConsts.noChoice then
        Camp.ResetScribe(GDVars.currentChar)
      else done := True;
    end else redraw := False;
    idx := -1;
    while done = False do begin
      spellId := ViewChar.SpellMenu(3, 3, idx, notEmpty);
      if spellId = 0 then begin
        done := True;
        if notEmpty = False then
          CharHlp.PrintCreatureMessage(GDVars.currentChar, 'has no copyable scrolls', 10, True)
        else redraw := True;
      end else begin
        redraw := True;
        if GDVars.currentChar^.knownSpells[spellId] <> 0 then
          CharHlp.PrintBottomLine('You already know that spell')
        else begin
          p := GDVars.currentChar^.items;
          found := False;
          while (p <> nil) and (found = False) do begin
            if Magic.ItemReadable(p) then
              for i := 1 to SizeOf(p^.definition.scrollSpells) do
                if (p^.definition.scrollSpells[i] > C_Spell.ID_MASK) and
                    (p^.definition.scrollSpells[i] and C_Spell.ID_MASK = spellId) then begin
                  CharHlp.PrintBottomLine('You are already scribing that spell');
                  found := True;
                end;
            p := p^.next;
          end;
          if found = False then begin
            if GDVars.currentChar^.spellSlots[ShortInt(GDConsts.spellTable[spellId].castClass),
                                              GDConsts.spellTable[spellId].level] > 0 then begin
              p := GDVars.currentChar^.items;
              while (p <> nil) and (found = False) do begin
                i := 1;
                repeat
                  if p^.definition.scrollSpells[i] = spellId then begin
                    p^.definition.scrollSpells[i] := p^.definition.scrollSpells[i] or C_Spell.PENDING_FLAG;
                    found := True;
                  end;
                  Inc(i);
                until (i > SizeOf(p^.definition.scrollSpells)) or found;
                p := p^.next;
              end;
            end else CharHlp.PrintBottomLine('You can not scribe that spell.');
          end;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu(GDConsts.scribeSpellsPrompt, GDConsts.yesChoice) = GDConsts.noChoice then
          Camp.ResetScribe(GDVars.currentChar);
    end;
    if redraw then CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Lists each party member's visible spell effects by name, or ' <No Spell Effects>', in a vertical menu. }
procedure CampDisplayMenu;
var effect: Types.PEffectRec;
    listHead: Types.PMenuLine;
    listTail: Types.PMenuLine;
    character: Types.PCharRecord;
    effectId: Byte;
    { Unused in this version; see the other implementations of this routine. }
    spellIndex: Byte;
    effectCount: Byte;
    { Unused in this version; see the other implementations of this routine. }
    isHeading: Byte;
    { Unused in this version; see the other implementations of this routine. }
    effectNameFound: Boolean;
    displayEffect: Boolean;
    viewNeedsRedraw: Boolean;
    effectName: String[40];
    menuIndex: Integer;
    { Unused in this version; see the other implementations of this routine. }
    choice: Char;

  { Appends a line to the list, as a title or an entry. }
  procedure AddToList(isTitle: Boolean; displayText: Types.TStr40);
  begin
    GetMem(listTail^.next, SizeOf(Types.TMenuLine));
    listTail := listTail^.next;
    listTail^.next := nil;
    listTail^.name := displayText;
    listTail^.inUse := Ord(isTitle);
  end;
begin
  GetMem(listHead, SizeOf(Types.TMenuLine));
  listTail := listHead;
  listTail^.inUse := Ord(True);
  listTail^.name := ' ';
  listTail^.next := nil;
  character := GDVars.creatureListHead;
  while character <> nil do begin
    effectCount := 0;
    AddToList(True, character^.name);
    effect := character^.effects;
    while effect <> nil do begin
      displayEffect := True;
      effectId := effect^.id;
      if effectId in Camp.VISIBLE_EFFECT_IDS then
        effectName := GDConsts.effectNames[effectId]
      else displayEffect := False;
      if displayEffect then begin
        Inc(effectCount);
        AddToList(False, ' ' + effectName);
      end;
      effect := effect^.next;
    end;
    if effectCount = 0 then AddToList(False, ' <No Spell Effects>');
    AddToList(True, ' ');
    character := character^.next;
  end;
  viewNeedsRedraw := True;
  menuIndex := 0;
  Border.DrawWindowFrame(0);
  MenuCore.ResetMenuSlots(0);
  choice := MenuCore.MenuVertical(GDConsts.emptyQuery, GDConsts.blankPrompt, 1, 4,
                                  38, 22, listHead, True,
                                  $FF, viewNeedsRedraw, menuIndex, listTail);
  MenuCore.FreeStringList(listHead);
  CharHlp.DisplayNoncombatInterface;
end;

{ The camp's magic menu: Cast, Memorize, Scribe, Display, Rest and Exit. Rest is left out where every rest is
  interrupted (a 100% interruption chance with a rest period of 1).
  @param(interrupted True ends the menu; set when a rest is broken off by a wandering encounter.) }
procedure CampMagicMenu(var interrupted: Boolean);
var
  i: Byte;
  active: Byte;
    c: Char;
    savedChoice: Byte;
begin
  c := #255;
  savedChoice := 1;
  while (interrupted = False) and (c <> #5) and
      (not GDVars.extendedKeyFlag or (c <> C_Keys.ESCAPE)) do begin
    FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
    active := 0;
    for i := 0 to 5 do
      if (i <> 4) or (GDVars.vmBand.zone0^.interruptPct < 100) or
          (GDVars.vmBand.zone0^.restPeriod <> 1) then
        MenuCore.AppendSlot(i, active);
    GDVars.horizMenuChoice := savedChoice;
    c := MenuCore.MenuHorizontal('', GDConsts.campMagicMenuItems, True, True);
    savedChoice := GDVars.horizMenuChoice;
    if GDVars.extendedKeyFlag then begin
      CharHlp.DisplayRoster(GDVars.currentChar, False);
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayRoster(GDVars.currentChar, True);
    end else
      case Ord(c) of
        0: Camp.NoncombatCastMenu;
        1: Camp.CampMemorizeMenu;
        2: Camp.CampScribeMenu;
        3: Camp.CampDisplayMenu;
        4: Camp.RestForSpellPrep(interrupted);
      end;
  end;
end;

{ Moves the current character one place earlier in the party; the first character moves to the end. }
procedure OrderMoveUp;
var
  prev: Types.PCharRecord;
  p: Types.PCharRecord;
  savedNext: Types.PCharRecord;
begin
  p := GDVars.creatureListHead;
  prev := nil;
  if p = GDVars.currentChar then begin
    while p^.next <> nil do p := p^.next;
  end else
    while p^.next <> GDVars.currentChar do begin
      prev := p;
      p := p^.next;
    end;
  savedNext := GDVars.currentChar^.next;
  if GDVars.creatureListHead = GDVars.currentChar then begin
    if savedNext <> nil then GDVars.creatureListHead := savedNext;
    p^.next := GDVars.currentChar;
    GDVars.currentChar^.next := nil;
  end else begin
    p^.next := savedNext;
    GDVars.currentChar^.next := p;
    if (p = GDVars.creatureListHead) or (prev = nil) then
      GDVars.creatureListHead := GDVars.currentChar
    else
      prev^.next := GDVars.currentChar;
  end;
end;

{ Moves the current character one place later in the party; the last character moves to the front. }
procedure OrderMoveDown;
var
  predecessor: Types.PCharRecord;
  successor: Types.PCharRecord;
begin
  predecessor := GDVars.creatureListHead;
  if predecessor <> GDVars.currentChar then
    while predecessor^.next <> GDVars.currentChar do predecessor := predecessor^.next;
  successor := GDVars.currentChar^.next;
  if successor = nil then begin
    GDVars.currentChar^.next := GDVars.creatureListHead;
    GDVars.creatureListHead := GDVars.currentChar;
    predecessor^.next := successor;
  end else begin
    GDVars.currentChar^.next := successor^.next;
    if GDVars.creatureListHead = GDVars.currentChar then GDVars.creatureListHead := successor;
    if predecessor <> GDVars.currentChar then predecessor^.next := successor;
    successor^.next := GDVars.currentChar;
  end;
end;

{ Runs the party-order menu: in Select mode extended keys change the current character; choosing Select picks it
  (announcing it) and switches to Place mode, where the up and down arrows move it up or down the order, and choosing
  Place switches back. Ends on Exit or Escape. }
procedure PartyOrderMenu;
var
  selected: Byte;
  key: Byte;
    choice: Char;
    savedChoice: Byte;
begin
  selected := 0;
  choice := #255;
  savedChoice := 1;
  while (choice <> #2) and (not GDVars.extendedKeyFlag or (choice <> C_Keys.ESCAPE)) do begin
    FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
    if selected <> 0 then
      GDVars.menuSlotTable[0].choiceIndex := 1
    else
      GDVars.menuSlotTable[0].choiceIndex := 0;
    GDVars.menuSlotTable[1].choiceIndex := 2;
    GDVars.horizMenuChoice := savedChoice;
    choice := MenuCore.MenuHorizontal(GDConsts.partyOrderPrompt, GDConsts.selectPlaceMenu, True, True);
    savedChoice := GDVars.horizMenuChoice;
    if GDVars.extendedKeyFlag then begin
      if selected = 0 then begin
        CharHlp.DisplayRoster(GDVars.currentChar, False);
        ViewChar.SelectPrevNextChar(choice);
        CharHlp.DisplayRoster(GDVars.currentChar, True);
      end else begin
        key := Ord(choice);
        case key of
          Ord(C_Keys.UP): Camp.OrderMoveUp;
          Ord(C_Keys.DOWN): Camp.OrderMoveDown;
        end;
        CharHlp.DisplayParty(GDVars.currentChar);
      end;
    end else if (Ord(choice) < 2) or (GDVars.extendedKeyFlag and (choice = C_Keys.ESCAPE)) then begin
      selected := Ord(selected = 0);
      if selected <> 0 then
        CharHlp.PrintCreatureMessage(GDVars.currentChar, GDConsts.hasBeenSelectedMsg, 10, False)
      else CharHlp.ClearMessageWindow;
    end;
  end;
  GDVars.charSelectMode := 0;
end;

{ Shows the level menu with the current difficulty preselected and stores the level picked as 1..5; extended keys change
  the current character instead. }
procedure CampDifficultyMenu;
var choice: Char;
    difficulty: Byte;
begin
  difficulty := GDVars.vmBand.zone0^.difficulty;
  GDVars.menuResetByte := $FF;
  GDVars.horizMenuChoice := difficulty;
  MenuCore.ResetMenuSlots(4);
  choice := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.levelMenu, False, True);
  if GDVars.extendedKeyFlag then begin
    CharHlp.DisplayRoster(GDVars.currentChar, False);
    ViewChar.SelectPrevNextChar(choice);
    CharHlp.DisplayRoster(GDVars.currentChar, True);
  end else if Ord(choice) < 5 then
    difficulty := Ord(choice) + 1;
  GDVars.vmBand.zone0^.difficulty := difficulty;
end;

{ Runs the speed menu: shows the game delay, 0 fastest to 9 slowest, and steps it with Faster, Slower or the arrow keys;
  Escape or Exit ends it. }
procedure CampSpeedMenu;
var slotCount: Byte;
    choice: Char;
    savedChoice: Byte;
begin
  savedChoice := 1;
  repeat
  TextRend.DisplayString(1, 18, LightGreen, Black,
                         GDConsts.gameSpeedPrompt + TextRend.NumToStr(GDVars.vmBand.zone0^.gameDelay));
    FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
    slotCount := 0;
    if GDVars.vmBand.zone0^.gameDelay > 0 then MenuCore.AppendSlot(0, slotCount);
    if GDVars.vmBand.zone0^.gameDelay < Camp.MAX_GAME_DELAY then MenuCore.AppendSlot(1, slotCount);
    MenuCore.AppendSlot(2, slotCount);
    GDVars.horizMenuChoice := savedChoice;
    choice := MenuCore.MenuHorizontal(GDConsts.gameSpeedPrefix, GDConsts.speedMenuItems, True, True);
    savedChoice := GDVars.horizMenuChoice;
    if GDVars.extendedKeyFlag then
      case Ord(choice) of
        Ord(C_Keys.DOWN): if GDVars.vmBand.zone0^.gameDelay > 0 then Dec(GDVars.vmBand.zone0^.gameDelay);
        Ord(C_Keys.UP): if GDVars.vmBand.zone0^.gameDelay <
          Camp.MAX_GAME_DELAY then Inc(GDVars.vmBand.zone0^.gameDelay);
        Ord(C_Keys.ESCAPE): choice := #2;
      end else
      case Ord(choice) of
        0: Dec(GDVars.vmBand.zone0^.gameDelay);
        1: Inc(GDVars.vmBand.zone0^.gameDelay);
      end;
  until choice = #2;
  CharHlp.ClearMessageWindow;
end;

{ The Alter menu: Order, Drop a character, Speed, Icon and Level. }
procedure CampAlterMenu;
var
  choice: Char;
  { Unused in this version; see the other implementations of this routine. }
  toggleChoice: Char;
    savedChoice: Byte;
begin
  choice := #255;
  savedChoice := 1;
  GDVars.horizMenuChoice := 1;
  while choice <> #5 do begin
    MenuCore.ResetMenuSlots(5);
    choice := MenuCore.MenuHorizontal('', GDConsts.campAlterMenuItems, True, True);
    savedChoice := GDVars.horizMenuChoice;
    if GDVars.extendedKeyFlag then begin
      if choice = C_Keys.ESCAPE then choice := #5
      else begin
        CharHlp.DisplayRoster(GDVars.currentChar, False);
        ViewChar.SelectPrevNextChar(choice);
        CharHlp.DisplayRoster(GDVars.currentChar, True);
      end;
    end else begin
      case Ord(choice) of
        0: Camp.PartyOrderMenu;
        1: if GDVars.vmBand.zone0^.partySize > 1 then CharGen.DropCharacterMenu;
        2: Camp.CampSpeedMenu;
        3: begin CharGen.CustomizeIcon; CharHlp.DisplayNoncombatInterface end;
        4: Camp.CampDifficultyMenu;
      end;
      GDVars.horizMenuChoice := savedChoice;
    end;
  end;
end;

{ Counts the levels a character has lost to drain, summed over the classes.
  @param(character The character.)
  @returns(The levels lost.) }
function LevelsDrained(character: Pointer): Byte;
var total: Byte;
    i: ShortInt;
begin
  total := 0;
  with Types.PCharRecord(character)^ do
    for i := 0 to 6 do
      if classLevels[i] < peakClassLevels[i] then
        Inc(total, peakClassLevels[i] - classLevels[i]);
  LevelsDrained := total;
end;

{ Runs the Fix menu: the party rests while its clerics and magic-users heal everyone. The first rest casts every
  cure-wounds spell the party can memorize, shortened when that is more healing than is needed, then cures conditions
  and hands out the healing. A second rest, timed for the spells the remaining conditions need, cures them as well.
  Either rest can be interrupted. Nothing happens in an anti-magic area or when nobody is hurt. Note: when the first
  rest's time is worked out, a member who cannot cast keeps the previous member's time terms, which are cleared only
  before the loop; and blindness is detected on each member but removed and reported on the current character, without
  using up a cure blindness spell.
  @param(interrupted Receives True when a rest was interrupted.) }
procedure CampFixMenu(var interrupted: Boolean);
var
  healPool: Word;
  cureLightSlots: Word;
  cureSeriousSlots: Word;
  cureCriticalSlots: Word;
  healSlots: Word;
    { Unused in this version; see the other implementations of this routine. }
    menuChoice: Byte;
    resurrectionCount: Word;
    raiseDeadCount: Word;
    deadCount: Word;
    removeCurseCount: Word;
    cursedCount: Word;
    cureBlindnessCount: Word;
    blindCount: Word;
    healCount: Word;
    feeblemindedCount: Word;
    neutralizePoisonCount: Word;
    poisonedCount: Word;
    stoneToFleshCount: Word;
    petrifiedCount: Word;
    restorationCount: Word;
    drainedLevelCount: Word;
    savedRestTime: Types.TClock;

  { True when character is in okay condition. }
  function CanCast(character: Types.PCharRecord): Boolean;
  begin
    CanCast := character^.status = C_Status.OKAY;
  end;

  { Adds up the healing the conscious members can prepare into healPool, and counts their curing spells by slots. }
  procedure AccumResources;
  var total: Word;
      { Unused in this version; see the other implementations of this routine. }
      spellIndex: Byte;
      ch: Types.PCharRecord;
  begin
    total := 0;
    ch := GDVars.creatureListHead;
    while ch <> nil do begin
      if CanCast(ch) then
        with ch^ do begin
          if knownSpells[Camp.SPELL_CURE_LIGHT_WOUNDS] <> 0 then
            Inc(total, spellSlots[C_Spell.CLERIC_LIST, 1] * 9);
          if knownSpells[Camp.SPELL_CURE_SERIOUS_WOUNDS] <> 0 then
            Inc(total, spellSlots[C_Spell.CLERIC_LIST, 4] * 17);
          if knownSpells[Camp.SPELL_CURE_CRITICAL_WOUNDS] <> 0 then
            Inc(total, spellSlots[C_Spell.CLERIC_LIST, 5] * 27);
          if knownSpells[Camp.SPELL_HEAL] <> 0 then begin
            Inc(total, spellSlots[C_Spell.CLERIC_LIST, 6] * 50);
            Inc(healCount, spellSlots[C_Spell.CLERIC_LIST, 6])
          end;
          if knownSpells[Camp.SPELL_NEUTRALIZE_POISON] <> 0 then
            Inc(neutralizePoisonCount, spellSlots[C_Spell.CLERIC_LIST, 4]);
          if knownSpells[Camp.SPELL_RAISE_DEAD] <> 0 then Inc(raiseDeadCount, spellSlots[C_Spell.CLERIC_LIST, 5]);
          if knownSpells[Camp.SPELL_REMOVE_CURSE_CLERIC] <> 0 then
            Inc(removeCurseCount, spellSlots[C_Spell.CLERIC_LIST, 3]);
          if knownSpells[Camp.SPELL_REMOVE_CURSE_MAGIC_USER] <> 0 then
            Inc(removeCurseCount, spellSlots[C_Spell.MAGIC_USER_LIST, 3]);
          if knownSpells[Camp.SPELL_STONE_TO_FLESH] <> 0 then
            Inc(stoneToFleshCount, spellSlots[C_Spell.MAGIC_USER_LIST, 6]);
          if knownSpells[Camp.SPELL_CURE_BLINDNESS] <> 0 then
            Inc(cureBlindnessCount, spellSlots[C_Spell.CLERIC_LIST, 3]);
          if knownSpells[Camp.SPELL_RESURRECTION] <> 0 then
            Inc(resurrectionCount, spellSlots[C_Spell.CLERIC_LIST, 6]);
        end;
      ch := ch^.next;
    end;
    Inc(healPool, total);
  end;

  { Adds a cure roll for each counted cure slot to the healing pool. }
  procedure RollCureSlots;
  var rolledHealing: Word;
      rollIndex: Byte;
  begin
    rolledHealing := 0;
    for rollIndex := 1 to cureLightSlots do
      Inc(rolledHealing, FxEngine.RollDice(1, 8));
    for rollIndex := 1 to cureSeriousSlots do
      Inc(rolledHealing, FxEngine.RollDice(2, 8) + 1);
    for rollIndex := 1 to cureCriticalSlots do
      Inc(rolledHealing, FxEngine.RollDice(3, 8) + 3);
    for rollIndex := 1 to healSlots do
      Inc(rolledHealing, FxEngine.RollDice(4, 8) + 3);
    Inc(healPool, rolledHealing);
  end;

  { Returns the party's total missing hit points. }
  function PartyHitPointsMissing: Word;
  var totalDamage: Word;
      character: Types.PCharRecord;
  begin
    totalDamage := 0;
    character := GDVars.creatureListHead;
    while character <> nil do begin
      Inc(totalDamage, character^.hpMax - character^.hpCur);
      character := character^.next;
    end;
    PartyHitPointsMissing := totalDamage;
  end;

  { Sets the first rest's duration and the cure dice of each kind, scaled down to the party's total wounds. }
  procedure ComputeFixTime;
  var ch: Types.PCharRecord;
      maxTime: Word;
      cureLightTime: Word;
      druidCureLightTime: Word;
      cureSeriousTime: Word;
      cureCriticalTime: Word;
      healTime: Word;
      charTime: Word;
      resourceCount: Word;
      ratio: Word;
  begin
    ch := GDVars.creatureListHead;
    cureLightTime := 0;
    druidCureLightTime := 0;
    cureSeriousTime := 0;
    cureCriticalTime := 0;
    healTime := 0;
    cureLightSlots := 0;
    cureSeriousSlots := 0;
    cureCriticalSlots := 0;
    healSlots := 0;
    maxTime := 0;
    while ch <> nil do begin
      charTime := 0;
      if CanCast(ch) and (ch^.stats[C_Stat.WISDOM].cur > 3) then begin
        resourceCount := ch^.spellSlots[C_Spell.CLERIC_LIST, 1];
        Inc(cureLightSlots, resourceCount);
        cureLightTime := resourceCount * 15;
        resourceCount := ch^.spellSlots[C_Spell.DRUID_LIST, 2];
        Inc(cureLightSlots, resourceCount);
        druidCureLightTime := resourceCount * 30;
        Inc(cureSeriousSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 4]);
        cureSeriousTime := ch^.spellSlots[C_Spell.CLERIC_LIST, 4] * 60;
        Inc(cureCriticalSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 5]);
        cureCriticalTime := ch^.spellSlots[C_Spell.CLERIC_LIST, 5] * 75;
        Inc(healSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 6]);
        healTime := ch^.spellSlots[C_Spell.CLERIC_LIST, 6] * 90;
      end;
      Inc(charTime, cureLightTime + druidCureLightTime + cureSeriousTime + cureCriticalTime + healTime);
      if maxTime < charTime then maxTime := charTime;
      ch := ch^.next;
    end;
    if PartyHitPointsMissing < healPool then begin
      ratio := healPool div PartyHitPointsMissing;
      maxTime := maxTime div ratio;
    end;
    GDVars.restState.restTime[3] := maxTime div 60;
    GDVars.restState.restTime[2] :=
      (maxTime - 60 * GDVars.restState.restTime[3]) div 10;
    GDVars.restState.restTime[1] := maxTime mod 10;
  end;

  { Count the curing spells by slot and set the second rest's duration for as many of each as there are targets. }
  procedure ComputeCureTime;
  var character: Types.PCharRecord;
      cureMinutes: Word;
      { Unused in this version; see the other implementations of this routine. }
      hours: Byte;
  begin
    character := GDVars.creatureListHead;
    while character <> nil do begin
      if CanCast(character) then begin
        Inc(restorationCount, character^.spellSlots[C_Spell.CLERIC_LIST, 7]);
        Inc(resurrectionCount, character^.spellSlots[C_Spell.CLERIC_LIST, 7]);
        Inc(healCount, character^.spellSlots[C_Spell.CLERIC_LIST, 6]);
        Inc(stoneToFleshCount, character^.spellSlots[C_Spell.MAGIC_USER_LIST, 6]);
        Inc(raiseDeadCount, character^.spellSlots[C_Spell.CLERIC_LIST, 5]);
        Inc(neutralizePoisonCount, character^.spellSlots[C_Spell.CLERIC_LIST, 4]);
        Inc(removeCurseCount, character^.spellSlots[C_Spell.MAGIC_USER_LIST, 4]);
        Inc(removeCurseCount, character^.spellSlots[C_Spell.CLERIC_LIST, 3]);
        Inc(cureBlindnessCount, character^.spellSlots[C_Spell.CLERIC_LIST, 3]);
      end;
      character := character^.next;
    end;
    cureMinutes := 0;
    cureMinutes := cureMinutes + ViewChar.MinWord(restorationCount, drainedLevelCount) * 105;
    cureMinutes := cureMinutes + ViewChar.MinWord(resurrectionCount, deadCount) * 105;
    cureMinutes := cureMinutes + ViewChar.MinWord(healCount, feeblemindedCount) * 90;
    cureMinutes := cureMinutes + ViewChar.MinWord(stoneToFleshCount, petrifiedCount) * 90;
    if resurrectionCount = 0 then begin
      cureMinutes := cureMinutes + ViewChar.MinWord(raiseDeadCount, deadCount) * 75;
      raiseDeadCount := 0;
    end;
    cureMinutes := cureMinutes + ViewChar.MinWord(neutralizePoisonCount, poisonedCount) * 60;
    cureMinutes := cureMinutes + ViewChar.MinWord(cureBlindnessCount, blindCount) * 45;
    cureMinutes := cureMinutes + ViewChar.MinWord(removeCurseCount, cursedCount) * 45;
    GDVars.restState.restTime[3] := cureMinutes div 60;
    GDVars.restState.restTime[2] := (cureMinutes - 60 * GDVars.restState.restTime[3]) div 10;
    GDVars.restState.restTime[1] := cureMinutes mod 10;
  end;

  { Spends the healing pool on each member in party order, up to that member's missing hit points. }
  procedure HealParty;
  var character: Types.PCharRecord;
      healingNeeded: Word;
  begin
    character := GDVars.creatureListHead;
    while character <> nil do begin
      if character^.hpMax > character^.hpCur then begin
        healingNeeded := character^.hpMax - character^.hpCur;
        if healingNeeded > healPool then healingNeeded := healPool;
        if healingNeeded < 1 then healingNeeded := 0;
        if healingNeeded > 0 then
          if FxEngine.RestoreHitPoints(character, Byte(healingNeeded), False) then
            if healingNeeded <= healPool then Dec(healPool, healingNeeded);
      end;
      character := character^.next;
    end;
  end;

  { Spends the counted condition-curing spells on each party member in turn. }
  procedure CureStatusEffects;
  var character: Types.PCharRecord;
      effect: array[0..3] of Byte;
      { Unused in this version; see the other implementations of this routine. }
      diseaseIndex: Byte;
      wasHealed: Boolean;
      bonusHitPoints: Byte;
      bonusDivisor: Byte;
      classIndex: ShortInt;
  begin
    character := GDVars.creatureListHead;
    while character <> nil do begin
      wasHealed := False;
      while (Camp.LevelsDrained(character) > 0) and (restorationCount > 0) do begin
        GDVars.spellTargetList[1] := character; GDVars.spellBeingCast :=
          Camp.SPELL_RESTORATION; GDVars.spellFps.spells[Camp.SPELL_RESTORATION];
        Dec(restorationCount);
      end;
      if healCount > 0 then
        if CharHlp.HasEffect(character, C_Effect.FEEBLEMIND, Pointer(effect)) then begin
          FxEngine.RemoveEffect(character, C_Effect.FEEBLEMIND, nil);
          if CharHlp.HasEffect(character, C_Effect.BLIND, Pointer(effect)) then
            FxEngine.RemoveEffect(character, C_Effect.BLIND, nil);
          wasHealed := True;
          CharHlp.PrintCreatureMessage(character, 'is healed', 10, True);
          Dec(healCount);
          FxEngine.RecalcAbility(character, C_Stat.INTELLIGENCE);
          FxEngine.RecalcAbility(character, C_Stat.WISDOM);
        end;
      if (stoneToFleshCount > 0) and (character^.status = C_Status.PETRIFIED) then begin
        character^.status := C_Status.OKAY;
        character^.inPlay := 1;
        character^.hpCur := 1;
        CharHlp.PrintCreatureMessage(character, 'is changed back to flesh', 10, True);
        Dec(stoneToFleshCount);
      end;
      if neutralizePoisonCount > 0 then
        if CharHlp.HasEffect(character, C_Effect.POISONED, Pointer(effect)) then begin
          if character^.hpCur = 0 then character^.hpCur := 1;
          GDVars.effectLock := 1;
          FxEngine.RemoveEffect(character, C_Effect.POISONED, nil);
          FxEngine.RemoveEffect(character, C_Effect.SLOW_POISON_END, nil);
          FxEngine.RemoveEffect(character, C_Effect.SLOW_POISON_HIT, nil);
          GDVars.effectLock := 0;
          character^.inPlay := 1;
          character^.status := C_Status.OKAY;
          CharHlp.PrintCreatureMessage(character, 'is detoxified', 10, True);
          Dec(neutralizePoisonCount);
        end;
      if (resurrectionCount > 0) or (raiseDeadCount > 0) then
        if character^.status = C_Status.DEAD_STATUS then
          if character^.race <> C_Race.ELF then begin
            GDVars.effectLock := 1;
            FxEngine.RemoveEffect(character, C_Effect.POISONED, nil);
            GDVars.effectLock := 0;
            character^.hpCur := 1;
            character^.status := C_Status.OKAY;
            character^.inPlay := 1;
            if resurrectionCount > 0 then begin
              raiseDeadCount := 0;
              CharHlp.PrintCreatureMessage(character, 'has been ressurected', 10, True);
              Dec(resurrectionCount);
            end else begin
              if (character^.stats[C_Stat.CONSTITUTION].cur > 0) and
                  (raiseDeadCount > 0) then Dec(character^.stats[C_Stat.CONSTITUTION].cur);
              if character^.hpMax > character^.hpRolled then bonusHitPoints := character^.hpMax - character^.hpRolled
              else bonusHitPoints := 0;
              bonusDivisor := 0;
              if character^.stats[C_Stat.CONSTITUTION].cur >= 14 then begin
                for classIndex := 0 to 6 do
                  if character^.classLevels[classIndex] > 0 then
                    if (classIndex = C_Class.FIGHTER) or (classIndex = C_Class.PALADIN) or
                        (classIndex = C_Class.RANGER) then
                      Inc(bonusDivisor,
                          (character^.stats[C_Stat.CONSTITUTION].cur - 14) * character^.classLevels[classIndex])
                    else if character^.stats[C_Stat.CONSTITUTION].cur > 15 then
                      Inc(bonusDivisor, character^.classLevels[classIndex] shl 1)
                    else
                      Inc(bonusDivisor, character^.classLevels[classIndex]);
                if bonusDivisor > 0 then bonusHitPoints := bonusHitPoints div bonusDivisor;
                if (character^.stats[C_Stat.CONSTITUTION].cur < 17) or (character^.classLevels[C_Class.FIGHTER] > 0) or
                    (character^.classLevels[C_Class.RANGER] > 0) or
                    (character^.classLevels[C_Class.PALADIN] > 0) then
                  Dec(character^.hpMax, bonusHitPoints);
              end;
              CharHlp.PrintCreatureMessage(character, 'has been raised from the dead', 10, True);
              Dec(raiseDeadCount);
            end;
          end;
      if removeCurseCount > 0 then
        if CharHlp.HasEffect(character, C_Effect.BESTOW_CURSE, Pointer(effect)) then begin
          GDVars.spellTargetList[1] := character; Magic.SpellRemoveCurse;
          CharHlp.PrintCreatureMessage(character, 'is relieved of a curse', 10, True);
          Dec(removeCurseCount);
        end;
      if (not wasHealed) and (cureBlindnessCount > 0) then
        if CharHlp.HasEffect(character, C_Effect.BLIND, Pointer(effect)) then begin
          FxEngine.RemoveEffect(GDVars.currentChar, C_Effect.BLIND, nil);
          CharHlp.PrintCreatureMessage(GDVars.currentChar, 'regains sight', 10, True);
        end;
      character := character^.next;
    end;
  end;

  { Count the party members each curing spell has to treat. }
  procedure CountCureNeeds;
  var character: Types.PCharRecord;
      effect: array[0..3] of Byte;
  begin
    drainedLevelCount := 0; deadCount := 0; cursedCount := 0;
    blindCount := 0; feeblemindedCount := 0; poisonedCount := 0;
    petrifiedCount := 0;
    character := GDVars.creatureListHead;
    while character <> nil do begin
      Inc(drainedLevelCount, Camp.LevelsDrained(character));
      if (character^.status = C_Status.DEAD_STATUS) and (character^.race > C_Race.ELF) then Inc(deadCount);
      if character^.status = C_Status.PETRIFIED then Inc(petrifiedCount);
      if CharHlp.HasEffect(character, C_Effect.BESTOW_CURSE, Pointer(effect)) then Inc(cursedCount);
      if CharHlp.HasEffect(character, C_Effect.POISONED, Pointer(effect)) then Inc(poisonedCount);
      if CharHlp.HasEffect(character, C_Effect.FEEBLEMIND, Pointer(effect)) then Inc(feeblemindedCount)
      else if CharHlp.HasEffect(character, C_Effect.BLIND, Pointer(effect)) then Inc(blindCount);
      character := character^.next;
    end;
  end;

begin
  if GDVars.vmBand.zone0^.antiMagic <> 0 then Exit;
  raiseDeadCount := 0;
  removeCurseCount := 0;
  cureBlindnessCount := 0;
  healCount := 0;
  neutralizePoisonCount := 0;
  stoneToFleshCount := 0;
  resurrectionCount := 0;
  restorationCount := 0;
  interrupted := False;
  healPool := 0;
  if PartyHitPointsMissing = 0 then Exit;
  AccumResources;
  savedRestTime := GDVars.restState.restTime;
  ComputeFixTime;
  GDVars.restState.fixBusy := 1;
  interrupted := GameTime.CampRest(False);
  GDVars.restState.fixBusy := 0;
  if interrupted then Exit;
  RollCureSlots;
  CureStatusEffects;
  HealParty;
  CharHlp.DisplayParty(GDVars.currentChar);
  CharHlp.PrintMiscInfo;
  GDVars.restState.restTime := savedRestTime;
  savedRestTime := GDVars.restState.restTime;
  CountCureNeeds;
  ComputeCureTime;
  GDVars.restState.fixBusy := 1;
  interrupted := GameTime.CampRest(False);
  GDVars.restState.fixBusy := 0;
  if not interrupted then begin
    CureStatusEffects;
    CharHlp.DisplayParty(GDVars.currentChar);
    CharHlp.PrintMiscInfo;
    GDVars.restState.restTime := savedRestTime;
  end;
end;

procedure CampMainMenu(var interrupted: Boolean);
var savedMode: Byte;
    choice: ShortInt;
    viewRedraw: Byte;
    activeSlotCount: Byte;
    savedChoice: Byte;
begin
  savedMode := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.CAMPING;
  GDVars.restHealTicks := 0;
  GameIo.ZeroFill(GDVars.restState.restTime, SizeOf(GDVars.restState.restTime));
  GDVars.savedResourceName := GDVars.picArcName;
  GDVars.savedResourceId := GDVars.picArcId;
  CharHlp.DisplayNoncombatInterface;
  Border.ClearBox(1, 17, 38, 22);
  TextRend.DisplayString(1, 18, LightGreen, Black, GDConsts.makesCampMsg);
  Camp.ResetPartySpellActivities;
  interrupted := False;
  choice := -1;
  savedChoice := 1;
  while (interrupted = False) and (choice <> 6) do begin
    FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
    activeSlotCount := 0;
    for GDVars.scratchIndex := 0 to 6 do begin
      if ((GDVars.scratchIndex <> 3) and (GDVars.scratchIndex <> 5)) or
          (GDVars.vmBand.zone0^.interruptPct < 100) or
          (GDVars.vmBand.zone0^.restPeriod <> 1) then
        MenuCore.AppendSlot(GDVars.scratchIndex, activeSlotCount);
    end;
    GDVars.horizMenuChoice := savedChoice;
    choice := Ord(MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.campMenu, True, True));
    savedChoice := GDVars.horizMenuChoice;
    if GDVars.extendedKeyFlag then begin
      if choice = Ord(C_Keys.ESCAPE) then
        choice := 6
      else begin
        CharHlp.DisplayRoster(GDVars.currentChar, False);
        ViewChar.SelectPrevNextChar(Char(choice));
        CharHlp.DisplayRoster(GDVars.currentChar, True);
      end;
    end else begin
      case choice of
        0: begin
             SaveLoad.SaveGame(False, False);
             if MenuCore.YesNoMenu(GDConsts.quitToDosPrompt, GDConsts.noChoice) = GDConsts.yesChoice then
               GameIo.ExitGame(0);
           end;
        1: ViewChar.ViewCharMenu(Boolean(viewRedraw));
        2: Camp.CampMagicMenu(interrupted);
        3: Camp.RestForSpellPrep(interrupted);
        4: Camp.CampAlterMenu;
        5: Camp.CampFixMenu(interrupted);
      end;
    end;
  end;
  Camp.ResetPartySpellActivities;
  GDVars.interfaceState := savedMode;
  CharHlp.PrintMiscInfo;
  CharHlp.ClearMessageWindow;
  MenuCore.ClearBottomLine;
end;
begin end.
