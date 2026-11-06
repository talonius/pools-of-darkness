{ What happens after a fight: deciding who won, fled or fell, sharing out experience, gathering the monsters' coins and
  items into the treasure, the summary screen, and the treasure menu where the party views, takes, pools and shares the
  spoils. }
{$O+,F+}
unit PostCbt;

interface

uses Crt, Types, GDConsts, GDVars, TextRend, GameIo, Border, Shop, CharGen, ViewChar, Money,
  Magic, FxEngine, CharHlp, MenuCore, C_Class, C_Keys, C_Status, C_Ifc, C_Stat, C_Npc;

{ Everything after a fight: settles the results and the field, reports the outcome to the script, shows the summary and
  the treasure menu (or the party's destruction), frees what treasure is left, and resets the fight's special rules.
  During the demo it only clears the field. }
procedure PostCombat;

{ Offers Money, Items and Exit for taking from the treasure while both remain, going straight to the one that is left
  otherwise. The cursor keys change the current character.
  @param(moneyLeft Whether the treasure holds money; updated after each choice while both remain.)
  @param(itemsLeft Whether the treasure holds items; updated likewise.) }
procedure LootTakeMenu(var moneyLeft, itemsLeft: Boolean);

implementation

const
  PRIME_STAT_THRESHOLD = 15;

{ Merges the treasure item it with every identical item in the treasure list, adding up their quantities in stacks of at
  most 255. Note: charges, effect and special are each compared with themselves rather than with the item being merged,
  so items that differ only in those still merge.
  @param(it The treasure item to merge.) }
procedure CoalesceItem(it: Types.PItemRec);
var
  prev: Types.PItemRec;
  p: Types.PItemRec;
  next: Types.PItemRec;
  target: Types.PItemRec;
  quantity: Byte;
begin
  target := it;
  quantity := target^.definition.quantity;
  p := GDVars.treasureList;
  while p <> nil do begin
    next := p^.next;
    if (p <> target) and (p^.definition.quantity > 0) and (p^.definition.nameIds[1] = target^.definition.nameIds[1]) and
        (p^.definition.nameIds[2] = target^.definition.nameIds[2]) and
        (p^.definition.nameIds[3] = target^.definition.nameIds[3]) and
        (p^.definition.itemType = target^.definition.itemType) and (p^.definition.plus = target^.definition.plus) and
        (p^.definition.saveBonus = target^.definition.saveBonus) and
        (p^.definition.cursed = target^.definition.cursed) and (p^.definition.weight = target^.definition.weight) and
        (p^.definition.charges = p^.definition.charges) and (p^.definition.charges < 2) and
        (p^.definition.effect = p^.definition.effect) and (p^.definition.special = p^.definition.special) then begin
      if Integer(quantity) + p^.definition.quantity <= 255 then begin
        Inc(quantity, p^.definition.quantity);
        prev := GDVars.treasureList;
        if p = prev then
          GDVars.treasureList := p^.next
        else
          while (prev <> nil) and (prev^.next <> p) do
            prev := prev^.next;
        prev^.next := p^.next;
        GameIo.FreeSlot(Types.PItemRec(p));
      end else begin
        target^.definition.quantity := 255;
        p^.definition.quantity := p^.definition.quantity - (255 - quantity);
        quantity := p^.definition.quantity;
        target := p;
      end;
    end;
    p := next;
  end;
  target^.definition.quantity := quantity;
end;

{ Gathers the spoils of a won fight and works out each member's share of the experience. Every hostile that was put down
  (not okay, fleeing, or held in reserve) adds its experience award, and its coins if CombatSt marked it notPcNpc.
  Unless the fight forbids it, its items other than type 73 are copied into the treasure list. The coins add 2, 250 and
  2200 experience apiece by kind, and every new treasure item adds 400 per point of its magical bonus. The total is
  divided among the party members who share in it.
  @param(share Receives each sharing member's experience.) }
procedure DetermineLootExp(var share: LongInt);
var
  p: Types.PCharRecord;
  i: ShortInt;
  expTotal: LongInt;
  { the saved list head, then the experience walk }
  q: Types.PItemRec;
  it: Types.PItemRec;
  { unused: counted, never read }
  cnt: Byte;
begin
  expTotal := 0;
  p := GDVars.creatureListHead;
  cnt := 0;
  while p <> nil do begin
    it := p^.items;
    if (p^.side = 1) and (p^.status <> C_Status.OKAY) and (p^.status <> 9) and
        (p^.status <> C_Status.RUNNING) then begin
      GDVars.monstersKilled := True;
      if p^.combatAddr^.notPcNpc = 1 then
        for i := 0 to 2 do
          Inc(GDVars.moneyPool[i], p^.coins[i]);
      Inc(expTotal, p^.xpAward);
      if GDVars.vmBand.zone0^.noCombatItems <> 1 then
        while it <> nil do begin
          Inc(cnt);
          if it^.definition.itemType <> 73 then begin
            if GDVars.treasureList = nil then begin
              GetMem(GDVars.treasureList, SizeOf(Types.TItemRec));
              CharHlp.PrintItemString(p, it, 0, 0, False, False);
              GDVars.treasureList^ := it^;
              GDVars.treasureList^.definition.equipped := 0;
              GDVars.treasureList^.next := nil;
            end else begin
              q := GDVars.treasureList;
              GetMem(GDVars.treasureList, SizeOf(Types.TItemRec));
              CharHlp.PrintItemString(p, it, 0, 0, False, False);
              GDVars.treasureList^ := it^;
              GDVars.treasureList^.definition.equipped := 0;
              GDVars.treasureList^.next := q;
            end;
            if GDVars.treasureList^.definition.quantity > 0 then
              PostCbt.CoalesceItem(GDVars.treasureList);
          end;
          it := it^.next;
        end;
    end;
    p := p^.next;
  end;
  Inc(expTotal, GDVars.moneyPool[0] * 2);
  Inc(expTotal, GDVars.moneyPool[1] * 250);
  Inc(expTotal, GDVars.moneyPool[2] * 2200);
  q := GDVars.treasureList;
  while (q <> nil) and (q <> GDVars.lastMissileItem) do begin
    if q^.definition.plus > 0 then
      Inc(expTotal, q^.definition.plus * 400);
    q := q^.next;
  end;
  share := expTotal div (GDVars.vmBand.zone0^.partySize - GDVars.nonAnimCount);
end;

{ Gives experience to each party member still in play and not animated, unless the fight was a mirror duel, and then
  sets the member's level-up flag from CanLevelUp. A single-class character with a high prime requisite gets 10 percent
  more: Wisdom for a cleric, Strength for a fighter, Strength and Wisdom for a paladin, Strength, Intelligence and
  Wisdom for a ranger, Intelligence for a mage, Dexterity for a thief. A two-class character gets half, a three-class
  character a third. Note: the cleric's threshold is one lower than the others'.
  @param(xp Each member's share before the class adjustment.) }
procedure AwardExperience(xp: LongInt);
var
  p: Types.PCharRecord;
  share: LongInt;
begin
  if GDVars.vmBand.zone0^.mirrorDuel = 0 then begin
    p := GDVars.creatureListHead;
    while p <> nil do begin
      if (p^.inPlay <> 0) and (p^.status <> C_Status.ANIMATED) then begin
        share := xp;
        case p^.charClass of
          C_Class.CLERIC: if p^.stats[C_Stat.WISDOM].cur > 14 then share := xp div 10 + xp;
          C_Class.FIGHTER: if p^.stats[C_Stat.STRENGTH].cur >
            PostCbt.PRIME_STAT_THRESHOLD then share := xp div 10 + xp;
          C_Class.PALADIN:
            if (p^.stats[C_Stat.STRENGTH].cur > PostCbt.PRIME_STAT_THRESHOLD)
               and (p^.stats[C_Stat.WISDOM].cur > PostCbt.PRIME_STAT_THRESHOLD) then
              share := xp div 10 + xp;
          C_Class.RANGER:
            if (p^.stats[C_Stat.STRENGTH].cur > PostCbt.PRIME_STAT_THRESHOLD)
               and (p^.stats[C_Stat.INTELLIGENCE].cur > PostCbt.PRIME_STAT_THRESHOLD)
               and (p^.stats[C_Stat.WISDOM].cur > PostCbt.PRIME_STAT_THRESHOLD) then
              share := xp div 10 + xp;
          C_Class.MAGE: if p^.stats[C_Stat.INTELLIGENCE].cur >
            PostCbt.PRIME_STAT_THRESHOLD then share := xp div 10 + xp;
          C_Class.THIEF: if p^.stats[C_Stat.DEXTERITY].cur >
            PostCbt.PRIME_STAT_THRESHOLD then share := xp div 10 + xp;
          C_Class.CLERIC_FIGHTER, C_Class.CLERIC_RANGER..C_Class.FIGHTER_THIEF,
              C_Class.MAGE_THIEF: share := xp div 2;
          C_Class.CLERIC_FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF: share := xp div 3;
        end;
        Inc(p^.experience, share);
        p^.levelCapped := Byte(CharHlp.CanLevelUp(p));
      end;
      p := p^.next;
    end;
  end;
end;

{ Decides how the fight went and settles the party. The party sits at the head of the combatant list, ahead of the first
  combatant marked notPcNpc. Works out whether the party fled, was defeated or won, counts the members who take no
  share, strips the combat-only effects, and awards experience on a win. Then, unless the party was defeated, it
  restores statuses: a fleeing member is back to okay, a dying one falls unconscious (or revives at 1 hit point when the
  fight allows it), and an unconscious one with hit points wakes. If the party fled, everyone who did not flee with it
  is left behind. A defeated party is removed entirely. During the demo the winners share the experience and nobody is
  lost. Note: PostCombat calls this only when GDVars.demoMode is clear, so that branch never runs. }
procedure DetermineCombatResults;
var
  p: Types.PCharRecord;
  b: Boolean;
  i: Byte;
  alive: Boolean;
begin
  GDVars.nonAnimCount := 0; GDVars.partyDefeatedFlag := True; GDVars.partyFled := False;
  p := GDVars.creatureListHead;
  while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
    if p^.status = C_Status.RUNNING then GDVars.partyFled := True;
    p := p^.next
  end;
  p := GDVars.creatureListHead; alive := False;
  while (p <> nil) and not alive do begin
    if (p^.inPlay <> 0) or (p^.status = C_Status.UNCONSCIOUS) or (p^.status = C_Status.RUNNING) or
        (p^.status = C_Status.DYING) then
      alive := True;
    p := p^.next
  end;
  if (GDVars.vmBand.zone0^.reviveFlag <> 0) and alive then
    GDVars.partyDefeatedFlag := False;
  GDVars.combatWon := False; p := GDVars.creatureListHead;
  if not GDVars.demoMode then begin
    while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
      if ((p^.status = C_Status.RUNNING) or (p^.status = C_Status.ANIMATED) or
          (p^.status = C_Status.OKAY)) and (p^.side = 0)
         and (p^.npc < C_Npc.NON_PLAYER) then GDVars.partyDefeatedFlag := False;
      if (p^.status = C_Status.ANIMATED) or (p^.status = C_Status.OKAY) then begin
        GDVars.combatWon := True; GDVars.partyFled := False
      end;
      if (p^.inPlay = 0) or (p^.status = C_Status.ANIMATED) then Inc(GDVars.nonAnimCount);
      for i := 1 to 15 do FxEngine.RemoveEffect(p, GDConsts.clearEffects[i], nil);
      p := p^.next
    end;
    if GDVars.combatWon then begin
      PostCbt.DetermineLootExp(GDVars.expShare); PostCbt.AwardExperience(GDVars.expShare)
    end;
    p := GDVars.creatureListHead;
    if not GDVars.partyDefeatedFlag then begin
      while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
        if not GDVars.partyFled then begin
          case p^.status of
            C_Status.RUNNING: begin p^.status := C_Status.OKAY; p^.inPlay := 1 end;
            C_Status.DYING: if GDVars.vmBand.zone0^.reviveFlag <> 0 then begin
                p^.status := C_Status.OKAY; p^.inPlay := 1; p^.hpCur := 1
              end else p^.status := C_Status.UNCONSCIOUS;
            C_Status.UNCONSCIOUS: if p^.hpCur >
              0 then begin p^.status := C_Status.OKAY; p^.inPlay := 1 end
              else if GDVars.vmBand.zone0^.reviveFlag <> 0 then begin
                p^.status := C_Status.OKAY; p^.inPlay := 1; p^.hpCur := 1
              end
          end;
          p := p^.next
        end else begin
          if p^.status =
              C_Status.RUNNING then begin p^.status := C_Status.OKAY; p^.inPlay := 1; p := p^.next end
          else begin GDVars.currentChar := p; p := p^.next; CharGen.RemoveCreature(False, True) end
        end
      end
    end else begin
      p := GDVars.creatureListHead; b := False;
      while (p <> nil) and not b do begin
        if p^.combatAddr^.notPcNpc <> 1 then begin GDVars.currentChar := p; CharGen.RemoveCreature(False, True) end
        else b := True;
        p := p^.next
      end;
      GDVars.vmBand.zone0^.partySize := 0
    end
  end else begin
    p := GDVars.creatureListHead;
    while p <> nil do begin
      if (p^.inPlay = 1) and (p^.status = C_Status.OKAY) and (p^.side <> 1) then begin
        GDVars.combatWon := True; PostCbt.DetermineLootExp(GDVars.expShare);
        PostCbt.AwardExperience(GDVars.expShare)
      end;
      p := p^.next
    end;
    p := GDVars.creatureListHead;
    while p <> nil do begin
      if (p^.status = C_Status.OKAY) or (p^.status = C_Status.ANIMATED) then p^.inPlay := 1;
      if p^.status = C_Status.DYING then p^.status := C_Status.UNCONSCIOUS;
      p := p^.next
    end
  end
end;

{ The summary screen: how the fight ended, the experience each member receives, and whether treasure was found. A party
  that fled abandons the treasure and, like one revived after losing, earns nothing, so xp is shown as 0.
  @param(xp The experience each member receives.) }
procedure PostCombatSummary(xp: LongInt);
var
  numStr: String[10];
  msg: String;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
  query: String[1];
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  query[0] := #0;
  Border.DrawWindowFrame(0);
  if GDVars.monstersKilled then begin
    if GDVars.partyFled then begin
      TextRend.DisplayString(1, 3, LightGreen, Black, GDConsts.partyFledMsg); xp := 0;
      p := GDVars.treasureList;
      while p <> nil do begin q := p^.next; GameIo.FreeSlot(Types.PItemRec(p)); p := q end;
      GameIo.ZeroFill(GDVars.moneyPool, SizeOf(GDVars.moneyPool))
    end else if (not GDVars.combatWon) and (GDVars.vmBand.zone0^.reviveFlag <> 0) then begin
      TextRend.DisplayString(1, 3, LightGreen, Black, GDConsts.lostFightMsg); xp := 0
    end else TextRend.DisplayString(1, 3, LightGreen, Black, GDConsts.partyWonMsg)
  end else TextRend.DisplayString(1, 3, LightGreen, Black, GDConsts.foundTreasureMsg);
  Str(xp, numStr);
  msg := GDConsts.eachReceivesMsg + numStr;
  if GDVars.vmBand.zone0^.mirrorDuel = 0 then begin
    TextRend.DisplayString(1, 5, LightGreen, Black, msg);
    TextRend.DisplayString(1, 7, LightGreen, Black, GDConsts.experiencePointsMsg)
  end;
  GDVars.treasureHasMoney := False; GDVars.treasureHasItems := False;
  Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
  if GDVars.monstersKilled then begin
    if GDVars.treasureHasMoney or
        GDVars.treasureHasItems then TextRend.DisplayString(1, 10, LightGreen, Black, GDConsts.foundTreasureMsg)
    else TextRend.DisplayString(1, 10, LightGreen, Black, GDConsts.noTreasureMsg)
  end;
  c := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.pressButtonPrompt, True, False)
end;

{ Lists the treasure items in a vertical Take menu.
  @param(c Receives the key pressed.)
  @param(itemToTake Receives the chosen item.)
  @param(cursor The highlighted item, kept between calls; receives the chosen item.)
  @param(idx The highlighted item's position, kept between calls.) }
procedure LootTakeItemSelection(var c: Char; var itemToTake: Types.PItemRec; var cursor: Types.PItemRec;
                                var idx: Integer);
var
  head: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  itemText: String[16];
  { Unused in this version; see the other implementations of this routine. }
  textLength: Byte;
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
  { asks MenuVertical for a full draw; it clears the flag }
  redraw: Boolean;
  p: Types.PItemRec;
begin
  redraw := True;
  Border.DrawWindowFrame(0);
  p := GDVars.treasureList;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
  head := GDVars.treasureList;
  MenuCore.ResetMenuSlots(0);
  c := MenuCore.MenuVertical(GDConsts.itemsPrompt, GDConsts.takeMenu, 1, 1, 38, 22, Types.PMenuLine(head), True, 0,
                             redraw, idx, Types.PMenuLine(cursor));
  itemToTake := cursor;
end;

{ Gives the current character copies of the picked items, removing each taken one from the treasure, until it leaves or
  the treasure is empty. }
procedure LootTakeItemMenu;
var
  itemToTake: Types.PItemRec;
  { walks the list to unlink the item }
  p: Types.PItemRec;
  c: Char;
  done: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
  failed: Boolean;
begin
  itemToTake := nil;
  cursor := GDVars.treasureList;
  idx := 0;
  GDVars.horizMenuChoice := 1;
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    if c <> #0 then
      done := True
    else begin
      done := False;
      Shop.GiveItemCopyToCreature(itemToTake, failed);
      if not failed then begin
        p := GDVars.treasureList;
        if p = itemToTake then
          GDVars.treasureList := itemToTake^.next
        else begin
          while p^.next <> itemToTake do
            p := p^.next;
          p^.next := itemToTake^.next;
        end;
        itemToTake^.next := nil;
        if itemToTake <> nil then GameIo.FreeSlot(Types.PItemRec(itemToTake));
        if GDVars.treasureList = nil then
          done := True;
      end;
    end;
  until done;
  CharHlp.DisplayNoncombatInterface;
end;

procedure LootTakeMenu(var moneyLeft, itemsLeft: Boolean);
var
  c: Char;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  ext: Boolean;
begin
  GDVars.horizMenuChoice := 1; done := False;
  if moneyLeft then begin
    if itemsLeft then begin
      repeat
        MenuCore.ResetMenuSlots(2);
        c := MenuCore.MenuHorizontal('Take: ', 'Money Items Exit', True, True);
        if GDVars.extendedKeyFlag then begin
          case c of
            C_Keys.ESCAPE: done := True;
            C_Keys.UP: ViewChar.SelectPrevNextChar(c);
            C_Keys.DOWN: ViewChar.SelectPrevNextChar(c)
          end
        end else begin
          case c of
            #0: begin Money.TakeMoneyMenu; CharHlp.DisplayNoncombatInterface end;
            #1: PostCbt.LootTakeItemMenu;
            #2: done := True
          end
        end;
        CharHlp.DisplayParty(GDVars.currentChar);
        Money.DetermineTreasure(moneyLeft, itemsLeft);
        if not moneyLeft or not itemsLeft then
          done := True;
      until done;
    end else begin
      Money.TakeMoneyMenu;
      CharHlp.DisplayNoncombatInterface;
    end;
  end else
    PostCbt.LootTakeItemMenu;
end;

{ The treasure menu after a won fight: View, Pool and Exit always, Take while any treasure remains, Share while money
  remains, and Detect while there are items and the current character, in play, has spell 5, 11 or 77 memorized. The
  cursor keys change the current character. Leaving with treasure still on the ground asks for confirmation. }
procedure LootMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  treasure: Boolean;
  i: Byte;
  menuState: Byte;
  c: Char;
  done: Boolean;
  changed: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  itemIndex: Byte;
  detectSpell: Byte;
  hasDetect: Boolean;
  savedMenuClear: Byte;
begin
  done := False;
  CharHlp.DisplayNoncombatInterface;
  savedMenuClear := 1;
  repeat
    FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
    Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
    i := 0; hasDetect := False;
    if GDVars.treasureHasItems then
      while (i <= 140) and not hasDetect do begin
        if (GDVars.currentChar^.spells[i] = 5) or (GDVars.currentChar^.spells[i] = 11) or
            (GDVars.currentChar^.spells[i] = 77) then
          if GDVars.currentChar^.inPlay <> 0 then begin
            hasDetect := True; detectSpell := GDVars.currentChar^.spells[i]
          end;
        Inc(i)
      end;
    menuState := 0;
    for i := 0 to 5 do
      case i of
        1: if GDVars.treasureHasMoney or GDVars.treasureHasItems then MenuCore.AppendSlot(1, menuState);
        3: if GDVars.treasureHasMoney then MenuCore.AppendSlot(3, menuState);
        4: begin if hasDetect then MenuCore.AppendSlot(4, menuState) end
      else MenuCore.AppendSlot(i, menuState)
      end;
    GDVars.horizMenuChoice := savedMenuClear;
    c := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.treasureMenu, True, True);
    savedMenuClear := GDVars.horizMenuChoice;
    if GDVars.extendedKeyFlag then begin
      case c of
        C_Keys.ESCAPE: c := #5;
        C_Keys.UP, C_Keys.DOWN: begin
          CharHlp.DisplayRoster(GDVars.currentChar, False); ViewChar.SelectPrevNextChar(c);
          CharHlp.DisplayRoster(GDVars.currentChar, True); c := #$FF
        end
      end
    end;
    case c of
      #0: ViewChar.ViewCharMenu(changed);
      #1: PostCbt.LootTakeMenu(GDVars.treasureHasMoney, GDVars.treasureHasItems);
      #2: Money.PoolMoney;
      #3: Money.ShareMoney;
      #4: Magic.CastSpell(detectSpell, 0, 0, changed);
      #5: begin
        Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
        if GDVars.treasureHasMoney or GDVars.treasureHasItems then begin
          TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, GDConsts.treasureLeftMsg);
          TextRend.DisplayMessageWindow(1, 17, 38, 22, White, Black, False, GDConsts.claimTreasurePrompt);
          if MenuCore.YesNoMenu(GDConsts.emptyQuery, GDConsts.noChoice) = GDConsts.noChoice then done := True
          else TextRend.ClearRect(1, 17, 38, 22)
        end else done := True
      end
    end;
  until done;
end;

{ Clears the field: removes each combatant that is neither a player character nor an NPC, or is on the hostile side,
  recording it as a monster killed and counting those out of play for the script, and frees the combat record of each
  remaining party member. The current character is left at the head of the list. }
procedure PostCombatCreatureCleanup;
var
  p: Types.PCharRecord;
  next: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  first: Boolean;
begin
  first := True;
  GDVars.vmBand.zone0^.monstersDefeated := 0;
  p := GDVars.creatureListHead;
  while p <> nil do begin
    if (p^.combatAddr^.notPcNpc = 1) or (p^.side = 1) then begin
      GDVars.monstersKilled := True;
      if p^.inPlay <> 1 then Inc(GDVars.vmBand.zone0^.monstersDefeated);
      first := False;
      next := p^.next;
      GDVars.currentChar := p;
      CharGen.RemoveCreature(p^.combatAddr^.notPcNpc = 1, True);
      p := next;
    end else begin
      if p^.combatAddr <> nil then begin
        FreeMem(p^.combatAddr, SizeOf(Types.TCombatRec));
        p^.combatAddr := nil;
      end;
      p := p^.next;
    end;
  end;
  GDVars.currentChar := GDVars.creatureListHead;
end;

procedure PostCombat;
var
  p: Types.PItemRec;
  q: Types.PItemRec;
  cr: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Word;
begin
  GameIo.ZeroFill(GDVars.eclCmpFlags, SizeOf(GDVars.eclCmpFlags));
  GDVars.monstersKilled := False;
  if not GDVars.demoMode then PostCbt.DetermineCombatResults;
  GDVars.interfaceState := C_Ifc.LOOT;
  PostCbt.PostCombatCreatureCleanup;
  if GDVars.demoMode then Exit;
  cr := GDVars.creatureListHead;
  GDVars.eclCmpFlags[2] := 1;
  while cr <> nil do begin
    CharHlp.RecalcStats(cr); cr := cr^.next
  end;
  if not GDVars.partyDefeatedFlag then begin
    if GDVars.partyFled then begin
      p := GDVars.treasureList;
      while p <> nil do begin q := p; p := p^.next; GameIo.FreeSlot(Types.PItemRec(q)) end;
      GDVars.treasureList := nil
    end else begin
      GDVars.eclCmpFlags[1] := 1; GDVars.eclCmpFlags[2] := 0
    end;
    if not GDVars.demoMode then begin
      PostCbt.PostCombatSummary(GDVars.expShare);
      if GDVars.treasureHasMoney or GDVars.treasureHasItems then PostCbt.LootMenu
    end;
    p := GDVars.treasureList;
    while p <> nil do begin
      q := p;
      p := p^.next;
      GameIo.FreeSlot(Types.PItemRec(q));
    end;
    GDVars.treasureList := nil;
  end else begin
    Border.DrawWindowFrame(0);
    GDVars.textCursorCol := 2; GDVars.textCursorRow := 6;
    TextRend.DisplayMessageWindow(2, 5, 37, 22, LightGreen, Black, True,
                                  'The monsters rejoice for the party has been destroyed.');
    TextRend.DisplayAndPause(LightMagenta, Black, 'Press any key to continue');
  end;
  GDVars.msgDelayFlag := True;
  GDVars.vmBand.zone0^.monsterHitMod := 0;
  GDVars.vmBand.zone0^.partyHitMod := 0;
  GDVars.vmBand.zone0^.partyMoveMod := 0;
  GDVars.vmBand.zone0^.noCombatItems := 0;
  GDVars.vmBand.zone0^.reviveFlag := 0;
  GDVars.vmBand.zone0^.mirrorDuel := 0;
  CharHlp.ClearEncounterState
end;

begin
end.
