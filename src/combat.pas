{ The combat round driver and the player's combat menus. CombatMain sets up the fight, then runs rounds until one side
  is gone or the round limit is reached: each round orders the combatants by initiative and gives each its turn, under
  the AI or under the player's command menu, then advances the clock. Afterwards it ages the survivors and tears the
  fight down. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Combat;

interface

uses Types, GDConsts, GDVars, Blit, TextRend, Border, GameIo, Crt, CombatAi, CombatSt, CbtActs,
  ViewChar, GameTime, FxEngine, CharHlp, ClassCal, MenuCore, CbtMap, MapTiles, Magic, C_Class, C_Effect, C_Keys, C_Dir,
  C_Ifc, C_Spell, C_Status, C_Terr, C_Npc, C_Cond;

{ Runs a fight. Switches to the combat interface state and the combat cast-target menu, applies leadership, sets up the
  fight and fires each creature's condition-24 effects, then, unless a side starts empty, plays rounds: each round
  counts the sides, runs each creature's round-start setup, clears the surprise mask, sorts the creatures by initiative
  and lets them act in that order, recounting the sides after each turn and ending the fight once a side is empty or the
  round limit is reached, then ends the round. Afterwards it runs the aging deaths when aging is pending, cleans up and
  turns slow text (the message-delay flag) back on. }
procedure CombatMain;

implementation

const
  { extended scan codes }
  KEY_ALT_Q = #16;
  KEY_ALT_R = #19;
  KEY_ALT_A = #30;

procedure AgingDeaths; forward;

procedure OrderCreatures; forward;

procedure CreatureAction(cr: Types.PCharRecord); forward;

procedure ManualControl(cr: Types.PCharRecord); forward;

procedure CombatMenu(cr: Types.PCharRecord; var ch: Char); forward;

procedure EndOfRound(var done: Boolean); forward;

procedure MoveMenu(cr: Types.PCharRecord; var done: Boolean); forward;

procedure MeleeAttack(att, def: Types.PCharRecord; var done: Boolean); forward;

procedure SpeedMenu; forward;

procedure TurnOnAuto(cr: Types.PCharRecord); forward;

{ Tears down the fight: frees the arena's cell patches, settles the status of creatures still charmed, strips every
  creature of the effects lost at zero hit points, frees the arena and its images and icons, and restores the normal
  spell dispatcher. }
procedure CombatDoneCleanup;
var
  nx: Types.PCellPatch;
  p: Types.PCharRecord;
  { HasEffect's out-parameter, not needed here }
  eff: Pointer;
  i: Byte;
begin
  while GDVars.cellPatchList <> nil do begin
    nx := GDVars.cellPatchList^.next;
    FreeMem(GDVars.cellPatchList, SizeOf(Types.TCellPatch));
    GDVars.cellPatchList := nx;
  end;
  p := GDVars.creatureListHead;
  while p <> nil do begin
    if CharHlp.HasEffect(p, C_Effect.CHARM, eff) then
      if p^.status = C_Status.OKAY then
        if GDVars.teamCount[1] > 1 then
          p^.status := C_Status.RUNNING
        else
          p^.status := C_Status.OKAY;
    FxEngine.RemoveEffectsHp0(p);
    p := p^.next;
  end;
  FreeMem(GDVars.arenaPtr, SizeOf(Types.TCombatMap));
  GDVars.arenaPtr := nil;
  Blit.FreePic(GDVars.moveIconSheet);
  Blit.FreePic(GDVars.mapTileSheet);
  for i := 0 to 21 do
    MapTiles.FreeIconAnim(i + 13);
  @GDVars.spellFps.castMenu := @Magic.NoncombatCastTargetMenu;
end;

procedure CombatMain;
var
  { flagA: the end has been noticed mid-round; flagB: the fight is over }
  flagA: Boolean;
  flagB: Boolean;
  cr: Types.PCharRecord;
begin
  flagA := False;
  GDVars.interfaceState := C_Ifc.IN_COMBAT;
  @GDVars.spellFps.castMenu := @CbtActs.SelectCombatTargets;
  CbtActs.UseLeadership;
  CombatSt.CombatStart;
  flagB := False;
  if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0) then
    flagB := True;
  cr := GDVars.creatureListHead;
  while cr <> nil do begin
    FxEngine.TriggerEffectsWithCondition(24, cr);
    cr := cr^.next;
  end;
  while not flagB do begin
    CharHlp.CountTeams;
    cr := GDVars.creatureListHead;
    while cr <> nil do begin
      CbtActs.BeginRound(cr);
      cr := cr^.next;
    end;
    GDVars.vmBand.zone0^.surpriseMask := 0;
    Combat.OrderCreatures;
    cr := GDVars.initiativeQueue[1];
    GDVars.initiativeIndex := 1;
    while (cr <> nil) and not flagB do begin
      Combat.CreatureAction(cr);
      Inc(GDVars.initiativeIndex);
      if GDVars.initiativeIndex > 72 then
        cr := nil
      else
        cr := GDVars.initiativeQueue[GDVars.initiativeIndex];
      CharHlp.CountTeams;
      if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0) or (GDVars.combatRound >= GDVars.fightEndRound) then
        if not flagA then begin
          flagB := True;
          flagA := True;
        end;
    end;
    Combat.EndOfRound(flagB);
  end;
  if GDVars.agingPending <> 0 then
    Combat.AgingDeaths;
  Combat.CombatDoneCleanup;
  GDVars.msgDelayFlag := True;
end;

{ After a fight that aged its combatants: anyone within ten years of their race's age limit is warned that they look
  very old, and anyone past it dies of old age, mourned according to how many able party members witness it. Note: warn
  keeps its previous value for a creature that dies, and count is never cleared, so the warning and the choice of grief
  message can come from stale values. }
procedure AgingDeaths;
var
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  witness: Types.PCharRecord;
  diesOfAge: Boolean;
  warn: Boolean;
  row: Byte;
  { the able party members watching }
  count: Byte;
  he: String[4];
  msg: Types.TStr255;
begin
  p := GDVars.creatureListHead;
  while p <> nil do begin
    if (p^.status < C_Status.DEAD_STATUS) and (p^.combatAddr^.notPcNpc <> 1) then
      with p^ do begin
        diesOfAge := age > GDConsts.ageThreshold[race];
        if not diesOfAge then
          warn := age > GDConsts.ageThreshold[race] - 10;
        if warn then
          CharHlp.PrintCreatureMessage(p, 'is looking very old', 10, True);
        if diesOfAge then begin
          row := 14;
          Border.ClearBox(23, row, 38, 21);
          TextRend.DisplayMessageWindow(23, row, 38, 21, 15, 0, True,
                                        'The strain of this last battle has worn heavily on ' + name + '.  ');
          TextRend.DisplayAndPause(13, 0, GDConsts.pressButtonPrompt);
          Border.ClearBox(23, row, 38, 21);
          if gender = 0 then
            he := 'He'
          else
            he := 'She';
          TextRend.DisplayMessageWindow(23, row, 38, 21, 15, 0, True,
                                        he + ' breathes deeply one last time and crumples to the ground.');
          TextRend.DisplayAndPause(13, 0, GDConsts.pressButtonPrompt);
          Border.ClearBox(23, row, 38, 21);
          FxEngine.KillCreature(p, C_Status.GONE, 'dies from age');
          q := GDVars.creatureListHead;
          while q <> nil do begin
            if (q^.inPlay = 1) and (q^.status = C_Status.OKAY) and (q^.side <> 1) then begin
              Inc(count);
              witness := q;
            end;
            q := q^.next;
          end;
          case count of
            0: msg := 'Sadly, no party member witnesses the passing of the champion.';
            1: msg := witness^.name + ' weeps at the loss of such a venerable companion.';
          else
            msg := ' The remaining party members are overcome with grief as they search '
                 + name + '''s body for valuables.';
          end;
          Border.ClearBox(23, row, 38, 21);
          TextRend.DisplayMessageWindow(23, row, 38, 21, 14, 0, True, msg);
          TextRend.DisplayAndPause(13, 0, GDConsts.pressButtonPrompt);
        end;
      end;
    p := p^.next;
  end;
  GDVars.agingPending := 0;
end;

{ Insertion-sorts the combatants into the initiative queue by initiative, highest first; a tie goes either way on a coin
  flip, and an empty slot counts as initiative -1. Note: the insertion scan looks at the first 64 slots, while the shift
  that makes room runs to the end of the queue. }
procedure OrderCreatures;
var
  ok: Boolean;
  { the combatant being placed }
  p: Types.PCharRecord;
  { entries being shifted down the queue }
  cur: Types.PCharRecord;
  nxt: Types.PCharRecord;
  ins: ShortInt;
  other: ShortInt;
  slot: Byte;
  j: Byte;
begin
  p := GDVars.creatureListHead;
  GameIo.ZeroFill(GDVars.initiativeQueue, SizeOf(GDVars.initiativeQueue));
  while p <> nil do begin
    slot := 1;
    ok := True;
    ins := p^.combatAddr^.initiative;
    while (slot < 65) and ok do begin
      if GDVars.initiativeQueue[slot] <> nil then
        other := GDVars.initiativeQueue[slot]^.combatAddr^.initiative
      else
        other := -1;
      if (ins > other) or ((ins = other) and (FxEngine.RollDice(1, 2) = 1)) then
        ok := False
      else
        Inc(slot);
    end;
    cur := GDVars.initiativeQueue[slot];
    GDVars.initiativeQueue[slot] := p;
    if cur <> nil then begin
      j := slot;
      ok := True;
      while (j < 72) and ok do begin
        Inc(j);
        nxt := GDVars.initiativeQueue[j];
        GDVars.initiativeQueue[j] := cur;
        cur := nxt;
        if nxt = nil then
          ok := False;
      end;
    end;
    p := p^.next;
  end;
end;

{ Runs one creature's turn: resets its flanking counts and guard and fires its condition-7 effects. If it still has
  initiative (a finished turn's marker becomes 19), it becomes the current character, the map shows when it is friendly
  or a visible hostile, the view centers on it, its statistics are recalculated and shown, and its condition-15 effects
  fire (and its condition-21 effects when it is not casting). If initiative is still left, the AI (quick fight) or the
  player acts. Last, its cell is redrawn to erase the cursor.
  @param(cr The creature whose turn it is.) }
procedure CreatureAction(cr: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  initiative: Integer;
begin
  cr^.combatAddr^.flankCount := 0;
  cr^.combatAddr^.flankSpread := 0;
  cr^.combatAddr^.guarding := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.TURN_START, cr);
  if cr^.combatAddr^.initiative > 0 then begin
    if cr^.combatAddr^.initiative = 20 then
      cr^.combatAddr^.initiative := 19;
    GDVars.currentChar := cr;
    GDVars.combatGfxOn := Byte((cr^.side = 0) or CbtMap.CombatIconVisible(Types.PCharRecord(cr), 0));
    CbtMap.DisplayMapViewCentered(Types.PCharRecord(cr), 2, True);
    CharHlp.RecalcStats(cr);
    GDVars.infoPanelDirty := 1;
    CharHlp.CombatPrintCreatureInfo(cr);
    FxEngine.TriggerEffectsWithCondition(C_Cond.ACTION_START, cr);
    if cr^.combatAddr^.spellCast = 0 then
      FxEngine.TriggerEffectsWithCondition(21, cr);
    if cr^.combatAddr^.initiative > 0 then
      if cr^.quickfight <> 0 then
        CombatAi.CombatAiControl(Types.PCharRecord(cr))
      else
        Combat.ManualControl(cr);
    CbtMap.RedrawArenaCell(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)));
  end;
end;

{ The player's turn for cr. A spell begun last round is finished first. Otherwise the command menu runs until an action
  ends the turn: Move, Aim, Use, Cast, Turn, Guard, Quick, Delay, Bandage, View, Speed or End. The extended keys are
  Space (take the whole party off quick fight), Alt-M (toggle quick magic), Alt-Q and Alt-A (put everyone on quick
  fight) and Alt-X (the debug win, if enabled).
  @param(cr The creature whose turn it is.) }
procedure ManualControl(cr: Types.PCharRecord);
var
  ch: Char;
  done: Boolean;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  aimInfo: array[1..3] of Byte;
  { CombatAimMenu's target out-parameter }
  aimTgt: Pointer;
  spell: Byte;
begin
  if cr^.inPlay <> 0 then begin
    if cr^.combatAddr^.spellCast > 0 then begin
      spell := cr^.combatAddr^.spellCast;
      cr^.combatAddr^.spellCast := 0;
      Magic.CastSpell(spell, 0, 1, done);
      done := CharHlp.EndActions(cr);
    end else begin
      done := False;
      while not done do begin
        GDVars.horizMenuChoice := 1;
        Combat.CombatMenu(cr, ch);
        if not GDVars.extendedKeyFlag then
          case ch of
            #0: Combat.MoveMenu(cr, done);
            #1: CbtActs.CombatAimMenu(cr, $FF, 1, 0, 1, done, aimTgt);
            #2: begin
                  GDVars.horizMenuChoice := 2;
                  ViewChar.UseItemMenu(done);
                  CbtActs.RecalcAttacksLeft(cr);
                  if not done then
                    CharHlp.DisplayCombatInterface;
                end;
            #3: CbtActs.CastSpellCombat(0, 0, done);
            #4: begin
                  if (ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.CLERIC) > 0)
                     or (ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.PALADIN) > 2) then
                    if cr^.combatAddr^.turnAttempts < GDVars.turnUndeadLimit then begin
                      CbtActs.CombatTurnUndead(cr);
                      done := CharHlp.EndActions(cr);
                    end;
                end;
            #5: done := CharHlp.Guard(cr);
            #6: begin
                  Combat.TurnOnAuto(cr);
                  MenuCore.ClearBottomLine;
                  GameIo.FlushKeys;
                  Delay(200);
                  done := True;
                  CombatAi.CombatAiControl(Types.PCharRecord(cr));
                end;
            #7: begin
                  { Delay: move to the end of this round's queue. }
                  cr^.combatAddr^.initiative := 1;
                  GDVars.scratchIndex := GDVars.initiativeIndex;
                  p := GDVars.initiativeQueue[GDVars.scratchIndex + 1];
                  while (p <> nil) and (GDVars.scratchIndex < 72) do begin
                    GDVars.initiativeQueue[GDVars.scratchIndex] := p;
                    Inc(GDVars.scratchIndex);
                    p := GDVars.initiativeQueue[GDVars.scratchIndex + 1];
                  end;
                  GDVars.initiativeQueue[GDVars.scratchIndex] := cr;
                  Dec(GDVars.initiativeIndex);
                  done := True;
                end;
            #8: begin
                  done := CharHlp.BandageDying(True);
                  done := CharHlp.EndActions(cr);
                end;
            #9: begin
                  ViewChar.ViewCharMenu(done);
                  CbtActs.RecalcAttacksLeft(cr);
                  if not done then
                    CharHlp.DisplayCombatInterface;
                end;
            #10: Combat.SpeedMenu;
            #11: done := CharHlp.EndActions(cr);
          end else
          case ch of
            ' ': begin
                   p := GDVars.creatureListHead;
                   while p <> nil do begin
                     if p^.npc < C_Npc.NON_PLAYER then
                       p^.quickfight := 0;
                     p := p^.next;
                   end;
                 end;
            C_Keys.ALT_M: begin
                    GDVars.quickMagic := Byte(GDVars.quickMagic = 0);
                    if GDVars.quickMagic <> 0 then
                      CharHlp.PrintBottomLine(GDConsts.magicOnMsg)
                    else
                      CharHlp.PrintBottomLine(GDConsts.magicOffMsg);
                  end;
            Combat.KEY_ALT_Q, Combat.KEY_ALT_A: begin
                    Dec(GDVars.initiativeIndex);
                    cr^.combatAddr^.initiative := 20;
                    p := GDVars.creatureListHead;
                    while p <> nil do begin
                      Combat.TurnOnAuto(p);
                      p := p^.next;
                    end;
                    MenuCore.ClearBottomLine;
                    Delay(200);
                    done := True;
                  end;
            C_Keys.ALT_X: if CbtActs.VictoryCheat then begin
                    CbtMap.DisplayMapViewCentered(Types.PCharRecord(cr), 3, False);
                    done := True;
                  end else
                    CharHlp.PrintBottomLine('That doesn''t work');
          end;
        if not done then begin
          CbtMap.DisplayMapViewCentered(Types.PCharRecord(cr), 2, True);
          GDVars.infoPanelDirty := 1;
          CharHlp.CombatPrintCreatureInfo(cr);
        end;
      end;
    end;
  end else
    done := CharHlp.EndActions(cr);
end;

{ Shows the combat command menu with only the commands cr can use enabled, and waits for one, or for one of the extended
  keys ManualControl handles.
  @param(cr The creature whose commands are offered.)
  @param(ch Receives the command's index, or the extended key.) }
procedure CombatMenu(cr: Types.PCharRecord; var ch: Char);
var
  { the number of enabled commands }
  count: Byte;
  i: Byte;
  hasSpell: Boolean;
begin
  count := 0;
  if cr^.combatAddr^.movement > 0 then
    MenuCore.AppendSlot(0, count);
  MenuCore.AppendSlot(1, count);
  if cr^.numberOfItems > 0 then
    MenuCore.AppendSlot(2, count);
  hasSpell := False;
  for i := 0 to 140 do
    if (cr^.spells[i] and C_Spell.ID_MASK) > 0 then
      hasSpell := True;
  if hasSpell then
    if cr^.combatAddr^.castAllowed <> 0 then
      if GDVars.vmBand.zone0^.antiMagic = 0 then
        MenuCore.AppendSlot(3, count);
  if (ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.CLERIC) > 0)
     or (ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.PALADIN) > 2) then
    if cr^.combatAddr^.turnAttempts < GDVars.turnUndeadLimit then
      MenuCore.AppendSlot(4, count);
  if not (CharHlp.HasRangedWeapon(cr) and not CharHlp.HasThrowableWeapon(cr)) then
    MenuCore.AppendSlot(5, count);
  MenuCore.AppendSlot(6, count);
  MenuCore.AppendSlot(7, count);
  if CharHlp.BandageDying(False) then
    MenuCore.AppendSlot(8, count);
  for i := 9 to 11 do
    MenuCore.AppendSlot(i, count);
  repeat
    ch := MenuCore.MenuHorizontal('', GDConsts.combatMenuItems, True, False);
    if GDVars.extendedKeyFlag then
      if not (ch in
              [Combat.KEY_ALT_Q, Combat.KEY_ALT_R, Combat.KEY_ALT_A, ' ', C_Keys.ALT_X, C_Keys.ALT_M]) then
        ch := #$FF;
  until (Ord(ch) < 12)
     or (GDVars.extendedKeyFlag and (ch in [Combat.KEY_ALT_Q, Combat.KEY_ALT_R, Combat.KEY_ALT_A, ' ', C_Keys.ALT_X,
                                       C_Keys.ALT_M]));
  Border.ClearBox(0, 23, 39, 24);
end;

{ Ends a round: advances the clock a minute, counts down the area effects, counts the round, refigures the hostiles'
  hit-point percentage, fires each creature's round-end (condition-19) effects and terrain effects, moves each dying
  creature a turn closer to death (dead once its count passes 9), warns when a party member is dying, counts the sides
  and rebuilds the view. The battle is done when a side is empty or the round limit is reached; when the party is left
  alone outside the demo, the player is asked whether to continue the battle.
  @param(done Set when the battle is over, and cleared when the player continues it; otherwise left as it was.) }
procedure EndOfRound(var done: Boolean);
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  status: Byte;
  { unused: counted, never read }
  cnt: Byte;
begin
  GameTime.AdvanceTime(1, 1);
  FxEngine.CountDownAreaEffects(False);
  Inc(GDVars.combatRound);
  CbtActs.UpdateHostileHpPercent;
  p := GDVars.creatureListHead;
  cnt := 1;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(C_Cond.ROUND_END, p);
    FxEngine.ConsiderTerrainEffects(p, False, True);
    if p^.status = C_Status.DYING then begin
      Inc(p^.combatAddr^.overkill);
      if p^.combatAddr^.overkill > 9 then
        p^.status := C_Status.DEAD_STATUS;
    end;
    Inc(cnt);
    p := p^.next;
  end;
  if CharHlp.BandageDying(False) then
    CharHlp.PrintBottomLine('Your Teammate is Dying');
  CharHlp.CountTeams;
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, $FF, C_Dir.CENTER);
  if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0) or (GDVars.combatRound >= GDVars.fightEndRound) then
    done := True;
  if (GDVars.teamCount[0] > 0) and (GDVars.teamCount[1] = 0) and not GDVars.demoMode then
    if MenuCore.YesNoMenu(GDConsts.continueBattlePrompt, GDConsts.noChoice) = GDConsts.yesChoice then
      done := False;
end;

{ The player's Move command: each arrow key turns cr and steps it one cell, attacking a creature in the way or offering
  to flee off the map edge. Diagonal steps cost half again as much. Esc puts cr back where it started with its movement
  restored.
  @param(cr The creature moving.)
  @param(done Set when the move ends the creature's turn.) }
procedure MoveMenu(cr: Types.PCharRecord; var done: Boolean);
var
  { movement left on entry }
  savedMove: Byte;
  { facing on entry }
  savedDir: Byte;
  { cell on entry }
  startX: Byte;
  startY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  slot: Integer;
  { the direction of the step, 8 = none }
  dir: Byte;
  { a combatant in the way }
  crIdx: Byte;
  { the terrain stepped onto, 0 = off the map }
  terrIdx: Byte;
  { the menu key, $FF to ask again }
  ch: Byte;
  { the step's movement cost }
  cost: Byte;
  { ProbeDirection's cloud or barrier terrain, not needed here }
  adjSpecial: Byte;

  { Esc: puts the creature back where it started. }
  procedure UndoMove;
  begin
    cr^.combatAddr^.movement := savedMove;
    CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(Types.PCharRecord(cr)));
    done := CbtMap.IsValidCreatureLoc(Types.PCharRecord(cr), startX, startY, False) = False;
    CbtMap.ScrollView(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)), 0,
                      C_Dir.CENTER);
    cr^.combatAddr^.direction := savedDir;
    dir := C_Dir.CENTER;
  end;

begin
  GDVars.manualMoveActive := 1;
  savedMove := cr^.combatAddr^.movement;
  savedDir := cr^.combatAddr^.direction;
  startX := CbtMap.CombatCellX(Types.PCharRecord(cr));
  startY := CbtMap.CombatCellY(Types.PCharRecord(cr));
  ch := $FF;
  done := False;
  dir := C_Dir.CENTER;
  repeat
    while (ch <> 0) and (ch <> Ord(C_Keys.ESCAPE)) and not done do begin
      MenuCore.ResetMenuSlots(0);
      Border.ClearBox(24, 24, 39, 24);
      if ch = $FF then
        ch := Ord(MenuCore.MenuHorizontal(GDConsts.moveLeftPrompt + CharHlp.Uint8Str(cr^.combatAddr^.movement div 2),
                                          GDConsts.doneMenu, True, False));
      dir := C_Dir.CENTER;
      if GDVars.extendedKeyFlag then
        case ch of
          Ord(C_Keys.ESCAPE): UndoMove;
          Ord(C_Keys.UP): dir := C_Dir.NORTH;
          Ord(C_Keys.PAGE_UP): dir := C_Dir.NORTHEAST;
          Ord(C_Keys.RIGHT): dir := C_Dir.EAST;
          Ord(C_Keys.PAGE_DOWN): dir := C_Dir.SOUTHEAST;
          Ord(C_Keys.DOWN): dir := C_Dir.SOUTH;
          Ord(C_Keys.END_KEY): dir := C_Dir.SOUTHWEST;
          Ord(C_Keys.LEFT): dir := C_Dir.WEST;
          Ord(C_Keys.HOME): dir := C_Dir.NORTHWEST;
        end;
      if dir < C_Dir.CENTER then begin
        CbtMap.SetCreatureFacing(Types.PCharRecord(cr), dir, 0, 0);
        CbtMap.ProbeDirection(Types.PCharRecord(cr), dir, crIdx, terrIdx, adjSpecial);
        if crIdx > 0 then
          Combat.MeleeAttack(cr, GDVars.slotCreatures[crIdx], done)
        else if terrIdx = 0 then begin
          case MenuCore.YesNoMenu(GDConsts.fleePrompt, GDConsts.noChoice) of
            0: done := CbtActs.AttemptFlee(cr);
            1: done := False;
          end;
        end else begin
          if Odd(dir) then
            cost := GDConsts.terrainTable[terrIdx].cost * 3
          else
            cost := GDConsts.terrainTable[terrIdx].cost * 2;
          if GDConsts.terrainTable[terrIdx].cost = C_Terr.TERRAIN_IMPASSABLE then
            cost := C_Terr.TERRAIN_IMPASSABLE;
          if cost > cr^.combatAddr^.movement then
            CharHlp.PrintBottomLine(GDConsts.cantGoThereMsg)
          else begin
            CbtActs.AttacksOfOpportunity(cr, dir);
            if cr^.inPlay = 0 then
              done := CharHlp.EndActions(cr)
            else begin
              if cr^.combatAddr^.movement > 0 then
                CbtActs.CombatMoveCreature(cr, dir);
              if cr^.inPlay = 0 then
                done := CharHlp.EndActions(cr);
              FxEngine.ConsiderTerrainEffects(cr, False, False);
              if CharHlp.IsHelpless(cr) or (cr^.inPlay = 0) then
                done := CharHlp.EndActions(cr);
            end;
          end;
        end;
      end;
      if (ch <> Ord(C_Keys.ESCAPE)) or not GDVars.extendedKeyFlag then
        if GDVars.extendedKeyFlag or (ch <> 0) then
          ch := $FF;
    end;
  until not ((ch = $FF) and not done);
  if cr^.combatAddr^.movement < 2 then
    cr^.combatAddr^.movement := 0;
  GDVars.manualMoveActive := 0;
end;

{ att attacks def in melee after stepping into it, unless att holds a missile weapon it cannot swing, or declines to
  attack an ally.
  @param(att The attacker.)
  @param(def The creature stepped into.)
  @param(done Set by the attack when it ends the attacker's turn.) }
procedure MeleeAttack(att, def: Types.PCharRecord; var done: Boolean);
begin
  if CharHlp.HasRangedWeapon(att) and not CharHlp.HasThrowableWeapon(att) then
    CharHlp.PrintBottomLine('Not with that weapon')
  else if CbtActs.CheckAttackAlly(att, def) then begin
    att^.combatAddr^.other := def;
    CbtActs.NoteAttackDirection(att, def);
    CbtActs.MakeAttack(att, def, False, nil, done);
  end;
end;

{ The Speed command: adjusts the game-speed setting, 0 to 9, until Exit. }
procedure SpeedMenu;
var
  query: Types.TStr40;
  { the number of enabled options }
  count: Byte;
  sel: Byte;
begin
  sel := $FF;
  while sel <> 2 do begin
    query := GDConsts.gameSpeedPrefix + '(' + CharHlp.Uint8Str(GDVars.vmBand.zone0^.gameDelay) + ') ';
    FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
    count := 0;
    if GDVars.vmBand.zone0^.gameDelay > 0 then
      MenuCore.AppendSlot(0, count);
    if GDVars.vmBand.zone0^.gameDelay < 9 then
      MenuCore.AppendSlot(1, count);
    MenuCore.AppendSlot(2, count);
    sel := Ord(MenuCore.MenuHorizontal(query, GDConsts.speedMenuItems, False, False));
    case sel of
      0: Dec(GDVars.vmBand.zone0^.gameDelay);
      1: Inc(GDVars.vmBand.zone0^.gameDelay);
    end;
  end;
end;

{ Puts a creature on quick fight and drops a locked target on its own side.
  @param(cr The creature to hand to the AI.) }
procedure TurnOnAuto(cr: Types.PCharRecord);
begin
  cr^.quickfight := 1;
  if (cr^.combatAddr^.other <> nil)
     and (cr^.combatAddr^.other^.side = cr^.side) then
    cr^.combatAddr^.other := nil;
end;

begin
end.
