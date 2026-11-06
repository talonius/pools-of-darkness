{ Character class progression: derived combat values, spell slots, saving throws, thief skills, dual-class state, level
  experience thresholds, and class changes. }
{$O+,F+}
unit ClassCal;

interface

uses Types, GDConsts, GDVars, TextRend, MenuCore, GameIo, C_Class, C_Race, C_Stat, C_Spell,
  C_Status, C_Item;

{ Recomputes everything that follows from the class levels: THAC0 base, highest level, attacks per round, spell slots,
  saving throws, thief skills and the class mask, then unreadies any uncursed item the class mask no longer allows. Once
  a dual-classed human's new class passes the old one, the old class's attack rate and thief skills return. The hit dice
  and the attack rate are not reset here; callers supply their starting values. Note: class bits are added, not ORed,
  and paladin and ranger share a bit, so a character holding both gets a wrong mask.
  @param(cr The character.) }
procedure RecalcClassStats(cr: Types.PCharRecord);

{ Sets the cleric spell slots from the cleric level: Wisdom above 12 adds slots at levels 1 to 4, and Wisdom below 17 or
  18 removes the level 6 or 7 slots.
  @param(cr The character.) }
procedure RecalcClericSlots(cr: Types.PCharRecord);

{ Each saving throw starts at 20 and takes the lowest table value over the character's classes. The first saving throw
  also gains a high-Constitution amount, plus a further Constitution amount while an item with special code
  SAVING_THROW_BONUS_ITEM_CODE is readied. Note: both Constitution amounts are added once per class the character has
  levels in.
  @param(cr The character.) }
procedure RecalcSaves(cr: Types.PCharRecord);

{ Sets the eight thief skills from the thief level (capped at 18) and race, adding the Dexterity adjustment to the first
  five; a race penalty larger than the base value gives 0. zeroBonus is always 0. Note: signed table sums are stored
  into Bytes without saturation.
  @param(cr The character.) }
procedure RecalcThiefSkills(cr: Types.PCharRecord);

{ Lets a conscious human pick a new class: one other than the current class, allowed for the race and alignment, with
  the current class's prime requisites at 15 or more and the new class's at 17 or more. The character restarts at level
  1 with no experience, the old class's levels are kept for later, and a new cleric or magic-user gets a first spell
  slot (a magic-user also four starting spells). Note: the conscious and human checks read the current character, not
  the one passed, so callers must pass the current character; canceling the menu exits without freeing the menu list.
  @param(cr The character.)
  @returns(The new class, or the no-class value when nothing changed.) }
function ChangeClass(cr: Types.PCharRecord): Byte;

{ Finds a human's level in the first class they currently have levels in.
  @param(cr The character.)
  @returns(The level; 0 for any other race.) }
function CurrentDualClassLevel(cr: Types.PCharRecord): Byte;

{ Tells whether a human's current class level exceeds the level it had when it changed class, which lets its earlier
  class's abilities count again.
  @param(cr The character to check.)
  @returns(True when the earlier class counts again.) }
function EarlierClassActive(cr: Types.PCharRecord): Boolean;

{ Finds the level that counts for a class: the current level, or the old class level when that is higher and the old
  class's abilities have been restored.
  @param(cr The character.)
  @param(cls The class.)
  @returns(The level.) }
function EffectiveClassLevel(cr: Types.PCharRecord; cls: ShortInt): Byte;

{ Finds the experience needed to reach a level in a class: the table value through level 11, a fixed increment per level
  beyond it up to level 40, and $7FFFFFFF above that.
  @param(cr Unused.)
  @param(level The level.)
  @param(cls The class.)
  @returns(The experience.) }
function XpForLevel(cr: Types.PCharRecord; level: Byte; cls: ShortInt): LongInt;

{ Rebuilds the spell slots from each class's effective level. Clerics, paladins and rangers know every spell of their
  lists at a level they have slots for; magic-user slots are trimmed by Intelligence. An equipped item with special code
  DOUBLE_LEVEL_FIVE_SLOTS_ITEM doubles the level-5 magic-user slots. Note: slot sums use Byte arithmetic and may wrap.
  @param(cr The character.) }
procedure RecalcSpellSlots(cr: Types.PCharRecord);

implementation

const
  { TItemDef.special codes }
  DOUBLE_LEVEL_FIVE_SLOTS_ITEM = $81;
  SAVING_THROW_BONUS_ITEM_CODE = 6;

function IsHuman(cr: Types.PCharRecord): Boolean; forward;

function FirstEarlierClass(cr: Types.PCharRecord): Byte; forward;

function FirstCurrentClass(cr: Types.PCharRecord): Byte; forward;

procedure TrimHighSpellSlots(cr: Types.PCharRecord); forward;

procedure RecalcSpellSlots(cr: Types.PCharRecord);
var
  cls: Byte;
  level: Byte;
  spellLevel: Byte;
  j: Byte;
  ruleIdx: Byte;
  item: Types.PItemRec;
begin
  with cr^ do begin
    GameIo.ZeroFill(spellSlots, SizeOf(spellSlots));
    for cls := 0 to 6 do begin
      level := ClassCal.EffectiveClassLevel(cr, cls);
      if level > 29 then level := 29;
      if level > 0 then case cls of
        C_Class.CLERIC: begin
          ClassCal.RecalcClericSlots(cr);
          for ruleIdx := 1 to 126 do begin
            with GDConsts.spellTable[ruleIdx] do
              if (castClass = C_Spell.CLERIC_LIST) and (spellSlots[C_Spell.CLERIC_LIST, level] > 0) then
                knownSpells[ruleIdx] := 1;
          end;
        end;
        C_Class.PALADIN: if level > 8 then begin
          for j := 1 to 4 do
            Inc(spellSlots[C_Spell.CLERIC_LIST, j], GDConsts.classLevelTable[C_Class.PALADIN].spellSlots[level, j]);
          for ruleIdx := 1 to 126 do begin
            with GDConsts.spellTable[ruleIdx] do
              if (castClass = C_Spell.CLERIC_LIST) and (spellSlots[C_Spell.CLERIC_LIST, level] > 0) then
                knownSpells[ruleIdx] := 1;
          end;
        end;
        C_Class.RANGER: if level > 7 then begin
          for j := 1 to 3 do
            Inc(spellSlots[C_Spell.DRUID_LIST, j], GDConsts.classLevelTable[C_Class.RANGER].spellSlots[level, j]);
          for j := 5 to 6 do begin
            spellLevel := j - 4;
            Inc(spellSlots[C_Spell.MAGIC_USER_LIST, spellLevel],
                GDConsts.classLevelTable[C_Class.RANGER].spellSlots[level, j]);
          end;
          for ruleIdx := 1 to 126 do begin
            with GDConsts.spellTable[ruleIdx] do
              if (((castClass = C_Spell.DRUID_LIST) and (spellSlots[C_Spell.DRUID_LIST, level] > 0)) or
                  ((castClass = C_Spell.MAGIC_USER_LIST) and (spellSlots[C_Spell.MAGIC_USER_LIST, level] > 0))) then
                knownSpells[ruleIdx] := 1;
          end;
        end;
        C_Class.MAGE: begin
          for j := 1 to 9 do
            Inc(spellSlots[C_Spell.MAGIC_USER_LIST, j], GDConsts.classLevelTable[C_Class.MAGE].spellSlots[level, j]);
          ClassCal.TrimHighSpellSlots(cr);
        end;
      end;
    end;
    item := items;
  end;
  while item <> nil do begin
    if (item^.definition.special = ClassCal.DOUBLE_LEVEL_FIVE_SLOTS_ITEM) and (item^.definition.equipped <> 0) then
      Inc(cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5], cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5]);
    item := item^.next;
  end;
end;

procedure RecalcClassStats(cr: Types.PCharRecord);
var
  cls: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  levelIndex: Byte;
  cappedLevel: Byte;
  level: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellIndex: Byte;
  slot: ShortInt;
begin
  cr^.thac0Base := 0;
  for cls := 0 to 6 do begin
    level := ClassCal.EffectiveClassLevel(cr, cls);
    if level > 21 then
      cappedLevel := 21
    else
      cappedLevel := level;
    if GDConsts.thac0ByLevel[cls, cappedLevel] > cr^.thac0Base then
      cr^.thac0Base := GDConsts.thac0ByLevel[cls, cappedLevel];
    if cr^.hitDice < level then cr^.hitDice := level;
    case cls of
      C_Class.PALADIN, C_Class.FIGHTER: begin
        if level > 6 then cr^.attacks := 3;
        if level > 12 then cr^.attacks := 4;
      end;
      C_Class.RANGER: begin
        if level > 7 then cr^.attacks := 3;
        if level > 14 then cr^.attacks := 4;
      end;
    end;
  end;
  ClassCal.RecalcSpellSlots(cr);
  ClassCal.RecalcSaves(cr);
  if cr^.classLevels[C_Class.THIEF] > 0 then ClassCal.RecalcThiefSkills(cr);
  cr^.classMask := 0;
  for cls := 0 to 6 do
    if (cr^.classLevels[cls] > 0) or ((cr^.oldLevels[cls] > 0) and (cr^.oldLevels[cls] < cr^.hitDice)) then
      Inc(cr^.classMask, GDConsts.classMaskBit[cls]);
  for slot := 0 to 12 do
    if cr^.equipped[slot] <> nil then
      if (GDVars.baseItemTable[cr^.equipped[slot]^.definition.itemType].classMask and cr^.classMask = 0) and
          (cr^.equipped[slot]^.definition.cursed = 0) then
        cr^.equipped[slot]^.definition.equipped := 0;
  if ClassCal.EarlierClassActive(cr) then
    for cls := 0 to 6 do begin
      level := cr^.oldLevels[cls];
      case cls of
        C_Class.FIGHTER, C_Class.PALADIN: if level >=
          13 then cr^.attacks := 4
             else if level >= 7 then cr^.attacks := 3;
        C_Class.RANGER: if level >= 15 then cr^.attacks := 4
           else if level >= 8 then cr^.attacks := 3;
        C_Class.THIEF: if level > 0 then ClassCal.RecalcThiefSkills(cr);
      end;
    end;
end;

procedure RecalcClericSlots(cr: Types.PCharRecord);
var
  i: Byte;
  level: Byte;
begin
  level := ClassCal.EffectiveClassLevel(cr, C_Class.CLERIC);
  if level > 0 then begin
    with cr^ do begin
      if level > 29 then level := 29;
      for i := 1 to 7 do
        spellSlots[C_Spell.CLERIC_LIST, i] := GDConsts.classLevelTable[C_Class.CLERIC].spellSlots[level, i];
      if (stats[C_Stat.WISDOM].cur > 12) and (spellSlots[C_Spell.CLERIC_LIST, 1] > 0) then
        Inc(spellSlots[C_Spell.CLERIC_LIST, 1]);
      if (stats[C_Stat.WISDOM].cur > 13) and (spellSlots[C_Spell.CLERIC_LIST, 1] > 0) then
        Inc(spellSlots[C_Spell.CLERIC_LIST, 1]);
      if (stats[C_Stat.WISDOM].cur > 14) and (spellSlots[C_Spell.CLERIC_LIST, 2] > 0) then
        Inc(spellSlots[C_Spell.CLERIC_LIST, 2]);
      if (stats[C_Stat.WISDOM].cur > 15) and (spellSlots[C_Spell.CLERIC_LIST, 2] > 0) then
        Inc(spellSlots[C_Spell.CLERIC_LIST, 2]);
      if (stats[C_Stat.WISDOM].cur > 16) and (spellSlots[C_Spell.CLERIC_LIST, 3] > 0) then
        Inc(spellSlots[C_Spell.CLERIC_LIST, 3]);
      if (stats[C_Stat.WISDOM].cur > 17) and (spellSlots[C_Spell.CLERIC_LIST, 4] > 0) then
        Inc(spellSlots[C_Spell.CLERIC_LIST, 4]);
      if stats[C_Stat.WISDOM].cur < 17 then spellSlots[C_Spell.CLERIC_LIST, 6] := 0;
      if stats[C_Stat.WISDOM].cur < 18 then spellSlots[C_Spell.CLERIC_LIST, 7] := 0;
    end;
  end;
end;

{ Removes the magic-user slots at levels 6 to 9 that the character's Intelligence does not allow.
  @param(cr The character.) }
procedure TrimHighSpellSlots(cr: Types.PCharRecord);
begin
  with cr^ do begin
    if stats[C_Stat.INTELLIGENCE].cur < 12 then spellSlots[C_Spell.MAGIC_USER_LIST, 6] := 0;
    if stats[C_Stat.INTELLIGENCE].cur < 14 then spellSlots[C_Spell.MAGIC_USER_LIST, 7] := 0;
    if stats[C_Stat.INTELLIGENCE].cur < 16 then spellSlots[C_Spell.MAGIC_USER_LIST, 8] := 0;
    if stats[C_Stat.INTELLIGENCE].cur < 18 then spellSlots[C_Spell.MAGIC_USER_LIST, 9] := 0;
  end;
end;

procedure RecalcSaves(cr: Types.PCharRecord);
var
  saveIdx: ShortInt;
  cls: ShortInt;
  level: Byte;
  { Unused in this version; see the other implementations of this routine. }
  specialBonus: Byte;
  specialCode: Byte;
  item: Types.PItemRec;
  hasSpecial: Boolean;
  cappedLevel: Byte;
begin
  hasSpecial := False;
  item := cr^.items;
  while (item <> nil) and not hasSpecial do begin
    if (item^.definition.special > C_Item.SPECIAL_POWER_BASE) and (item^.definition.equipped <> 0) then begin
      specialCode := item^.definition.special and C_Item.SPECIAL_POWER_MASK;
      hasSpecial := specialCode = ClassCal.SAVING_THROW_BONUS_ITEM_CODE;
    end;
    item := item^.next;
  end;
  for saveIdx := 0 to 4 do begin
    cr^.saves[saveIdx] := 20;
    for cls := 0 to 6 do begin
      level := ClassCal.EffectiveClassLevel(cr, cls);
      if level > 0 then begin
        if level > 21 then
          cappedLevel := 21
        else
          cappedLevel := level;
        if cr^.saves[saveIdx] > GDConsts.savingThrowTable[cls, cappedLevel, saveIdx] then
          cr^.saves[saveIdx] := GDConsts.savingThrowTable[cls, cappedLevel, saveIdx];
        if (saveIdx = 0) and hasSpecial then
          case cr^.stats[C_Stat.CONSTITUTION].cur of
            4..6: Inc(cr^.saves[saveIdx]);
            7..10: Inc(cr^.saves[saveIdx], 2);
            11..13: Inc(cr^.saves[saveIdx], 3);
            14..17: Inc(cr^.saves[saveIdx], 4);
            18: Inc(cr^.saves[saveIdx], 5)
          end;
        if saveIdx = 0 then
          case cr^.stats[C_Stat.CONSTITUTION].cur of
            19, 20: Inc(cr^.saves[saveIdx]);
            21, 22: Inc(cr^.saves[saveIdx], 2);
            23, 24: Inc(cr^.saves[saveIdx], 3);
            25: Inc(cr^.saves[saveIdx], 4)
          end;
      end;
    end;
  end;
end;

procedure RecalcThiefSkills(cr: Types.PCharRecord);
var
  i: Byte;
  zeroBonus: Byte;
  { Unused in this version; see the other implementations of this routine. }
  specialCode: Byte;
  level: Byte;
  cappedLevel: Byte;
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  skillBonusItem: Word;
begin
  with cr^ do begin
    zeroBonus := 0;
    item := items;
    level := ClassCal.EffectiveClassLevel(cr, C_Class.THIEF);
    if level > 18 then level := 18;
    cappedLevel := level;
    for i := 1 to 8 do begin
      if (GDConsts.thiefRaceAdjustments[race, i] < 0) and
          (GDConsts.thiefSkillsByLevel[level, i] < Abs(GDConsts.thiefRaceAdjustments[race, i]) + zeroBonus) then
        thiefSkills[i] := 0
      else begin
        thiefSkills[i] := zeroBonus + (GDConsts.thiefSkillsByLevel[level, i] + GDConsts.thiefRaceAdjustments[race, i]);
        if i < 6 then
          thiefSkills[i] := thiefSkills[i] + GDConsts.thiefDexterityAdjustments[stats[C_Stat.DEXTERITY].cur, i];
      end;
      level := cappedLevel;
    end;
  end;
end;

{ Finds the lowest class a human held before changing class.
  @param(cr The character.)
  @returns(The class, or C_Class.NO_CLASS for none or for another race.) }
function FirstEarlierClass(cr: Types.PCharRecord): Byte;
var i: ShortInt;
begin
  FirstEarlierClass := C_Class.NO_CLASS;
  if cr^.race <> C_Race.HUMAN then Exit;
  i := 0;
  while (i < C_Class.THIEF) and (cr^.oldLevels[i] = 0) do Inc(i);
  if cr^.oldLevels[i] > 0 then FirstEarlierClass := i;
end;

{ Finds the lowest class a human currently has levels in.
  @param(cr The character.)
  @returns(The class, or C_Class.NO_CLASS for none or for another race.) }
function FirstCurrentClass(cr: Types.PCharRecord): Byte;
var i: ShortInt;
begin
  FirstCurrentClass := C_Class.NO_CLASS;
  if cr^.race <> C_Race.HUMAN then Exit;
  i := 0;
  while (i < C_Class.THIEF) and (cr^.classLevels[i] = 0) do Inc(i);
  if cr^.classLevels[i] > 0 then FirstCurrentClass := i;
end;

function CurrentDualClassLevel(cr: Types.PCharRecord): Byte;
var cls: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then CurrentDualClassLevel := 0
  else begin
    cls := 0;
    while (cls < C_Class.THIEF) and (cr^.classLevels[cls] = 0) do Inc(cls);
    CurrentDualClassLevel := cr^.classLevels[cls];
  end;
end;

{ Tells whether a character is human, the one race that may change class.
  @param(cr The character to check.)
  @returns(True for a human.) }
function IsHuman(cr: Types.PCharRecord): Boolean;
begin
  IsHuman := cr^.race = C_Race.HUMAN;
end;

function EarlierClassActive(cr: Types.PCharRecord): Boolean;
begin
  EarlierClassActive := ClassCal.CurrentDualClassLevel(cr) > cr^.dualLevel;
end;

function ChangeClass(cr: Types.PCharRecord): Byte;
var
  choice: Char;
  newClass: ShortInt;
  candidateCount: ShortInt;
  listHead: Types.PMenuLine;
  selectionNode: Types.PMenuLine;
  selectionIndex: Integer;
  addExit: Boolean;
  redraw: Boolean;
  item: Types.PItemRec;

  { True when the character may change to class `cls`. }
  function QualifiesForClass(cls: ShortInt): Boolean;
  var ok: Boolean; i: ShortInt; alignIdx: Byte;
  begin
    ok := ClassCal.FirstCurrentClass(cr) <> Byte(GDConsts.raceClasses[cr^.race, GDVars.scratchIndex]);
    i := 0;
    while (i <= 5) and
        not ((GDConsts.classMinStats[ShortInt(ClassCal.FirstCurrentClass(cr)), i] >= 9) and
             (cr^.stats[i].base <= 14)) do Inc(i);
    ok := ok and (i > 5);
    i := 0;
    while (i <= 5) and
        not ((GDConsts.classMinStats[cls, i] >= 9) and
             (cr^.stats[i].base <= 16)) do Inc(i);
    ok := ok and (i > 5);
    alignIdx := 1;
    while (alignIdx <= GDConsts.classAlignments[cls].count) and
        (GDConsts.classAlignments[cls].allowed[alignIdx] <> Byte(cr^.alignment)) do
      Inc(alignIdx);
    ok := ok and (alignIdx <= GDConsts.classAlignments[cls].count);
    QualifiesForClass := ok;
  end;
begin
  ChangeClass := C_Class.NO_CLASS;
  if GDVars.currentChar^.status <> C_Status.OKAY then
    TextRend.PrintAndPause('only conscious humans may change', 14, 0)
  else if not (ClassCal.IsHuman(GDVars.currentChar) and
               (ClassCal.FirstEarlierClass(GDVars.currentChar) = C_Class.NO_CLASS)) then
    TextRend.PrintAndPause(cr^.name + ' doesn''t qualify.', 4, 15)
  else begin
  candidateCount := GDConsts.raceClasses[cr^.race, 0];
  GetMem(listHead, SizeOf(Types.TMenuLine));
  selectionNode := listHead;
  selectionNode^.next := nil;
  selectionNode^.inUse := 1;
  selectionNode^.name := 'Pick New Class';
  selectionIndex := 1;
  for GDVars.scratchIndex := 1 to candidateCount do begin
    newClass := GDConsts.raceClasses[cr^.race, GDVars.scratchIndex];
    if QualifiesForClass(newClass) then begin
      GetMem(selectionNode^.next, SizeOf(Types.TMenuLine));
      selectionNode := selectionNode^.next;
      selectionNode^.next := nil;
      selectionNode^.inUse := 0;
      selectionNode^.name := GDConsts.classNameTable[newClass];
      Inc(selectionIndex);
    end;
  end;
  if selectionIndex = 1 then begin
    TextRend.PrintAndPause(cr^.name + ' doesn''t qualify.', 4, 15);
    MenuCore.FreeStringList(listHead);
  end else begin
  selectionNode := listHead;
  selectionIndex := 1;
  addExit := True;
  redraw := True;
  repeat
    choice := MenuCore.MenuVertical('', 'Select', 1, 2, 38,
                                    22, listHead, addExit, 0, redraw,
                                    selectionIndex, selectionNode);
    if (GDVars.extendedKeyFlag and (Ord(choice) = 0)) or (Ord(choice) = 1) then begin
      Exit;
    end;
  until Ord(choice) = 0;
  cr^.experience := 0;
  cr^.attacks := 2;
  newClass := 0;
  while (newClass <= 6) and (GDConsts.classNameTable[newClass] <> selectionNode^.name) do Inc(newClass);
  MenuCore.FreeStringList(listHead);
  cr^.oldLevels[ShortInt(ClassCal.FirstCurrentClass(cr))] := ClassCal.CurrentDualClassLevel(cr);
  cr^.dualLevel := cr^.hitDice;
  cr^.hitDice := 1;
  cr^.classLevels[ShortInt(ClassCal.FirstCurrentClass(cr))] := 0;
  cr^.classLevels[newClass] := 1;
  GameIo.ZeroFill(cr^.peakClassLevels, SizeOf(cr^.peakClassLevels));
  GameIo.ZeroFill(cr^.spellSlots, SizeOf(cr^.spellSlots));
  GameIo.ZeroFill(cr^.spells, SizeOf(cr^.spells));
  case newClass of
    C_Class.CLERIC: cr^.spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
    C_Class.MAGE: begin
      cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 1] := 1;
      cr^.knownSpells[11] := 1;
      cr^.knownSpells[18] := 1;
      cr^.knownSpells[12] := 1;
      cr^.knownSpells[21] := 1;
    end;
  end;
  cr^.charClass := newClass;
  ChangeClass := newClass;
  TextRend.PrintAndPause(cr^.name + ' is now a 1st level ' + GDConsts.classNameTable[newClass] + '.', 10,
                         0);
  GameIo.ZeroFill(cr^.spells, SizeOf(cr^.spells));
  ClassCal.RecalcClassStats(cr); ClassCal.RecalcClericSlots(cr);
  ClassCal.TrimHighSpellSlots(cr); ClassCal.RecalcSaves(cr); ClassCal.RecalcThiefSkills(cr);
  item := cr^.items;
  while item <> nil do begin
    if (GDVars.baseItemTable[item^.definition.itemType].classMask and cr^.classMask = 0) and
        (item^.definition.cursed = 0) then item^.definition.equipped := 0;
    item := item^.next;
  end;
  end;
  end;
end;

function EffectiveClassLevel(cr: Types.PCharRecord; cls: ShortInt): Byte;
var
  currentLevel: Byte;
  previousLevel: Byte;
begin
  currentLevel := cr^.classLevels[cls];
  if ClassCal.EarlierClassActive(cr) then
    previousLevel := cr^.oldLevels[cls]
  else
    previousLevel := 0;
  if currentLevel > previousLevel then
    EffectiveClassLevel := currentLevel
  else
    EffectiveClassLevel := previousLevel;
end;

function XpForLevel(cr: Types.PCharRecord; level: Byte; cls: ShortInt): LongInt;
begin
  XpForLevel := $7FFFFFFF;
  if level < 41 then begin
    if level < 12 then
      XpForLevel := GDConsts.classLevelTable[cls].xp[level]
    else
      XpForLevel :=
        GDConsts.classLevelTable[cls].xp[11] +
        (level - 11) * GDConsts.xpIncrement[cls];
  end;
end;

begin
end.
