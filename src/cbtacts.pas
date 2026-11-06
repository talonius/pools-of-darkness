{ The combat action layer: round setup, movement and the attacks it provokes, fleeing, turn undead, attack resolution,
  spell casting and spell targeting, the aim menu and aim cursor, the AI's target and spell choices, and the Beholder's
  eye rays. }
{$O+,F+,S-,R-,V-,B-,I-}
unit CbtActs;

interface

uses Types, GDConsts, GDVars, Crt, ViewChar, Magic, FxEngine, CharHlp, ClassCal,
  MenuCore, Pathing, CbtMap, TextRend, GameIo, Music, Border, C_Effect, C_Equip, C_Keys, C_Race, C_Class, C_Status,
  C_Dir, C_Stat, C_Sound, C_Cond, C_Spell, C_Terr;

type
  { A chosen target: the creature (or nil for a ground target) and its arena cell. The aim routines pass it as an
    untyped `var` and cast it at each use. }
  TAimTarget = record
    cr: Pointer;
    x: ShortInt;
    y: ShortInt;
    { unused }
    yTail: Byte;
  end;

{ Prepares a combatant for a new round. It may cast when it has a memorized spell and may use items, but neither while
  it stands in special terrain. Its attacks for the round are set, and initiative is rolled as d6 plus its Dexterity
  missile adjustment (at least 1), less 6 when its side is surprised, and 0 when out of range 0..20 or out of play.
  Movement is recalculated last.
  @param(creature The combatant.) }
procedure BeginRound(creature: Pointer);

{ Moves a creature one cell in a direction. The step costs the terrain cost times 2 half-steps, times 3 on a diagonal;
  with too few left, movement drops to 0 but the step is still taken. The view follows the mover (faster in quick
  fight). The step plays the step sound, resets the creature's flanking counts and lets guarding enemies attack, and a
  mover left out of play or helpless loses the rest of its movement.
  @param(creature The creature moving.)
  @param(direction Direction of the step, 0..7 clockwise from north.) }
procedure CombatMoveCreature(creature: Pointer; direction: Byte);

{ Gives the attacks of opportunity a creature provokes by stepping in a direction. Every adjacent enemy that is not
  helpless, not turned and not confused out of its turn, and that would no longer be adjacent after the step, gets one
  attack: provided it may attack the creature, fights in melee or with a throwable weapon, and has initiative still to
  come, has not been flanked, or has the creature inside its facing wedge.
  @param(creature The combatant stepping.)
  @param(direction The direction of the step.) }
procedure AttacksOfOpportunity(creature: Pointer; direction: Byte);

{ Tries to flee. It succeeds automatically with no enemy in the target list, and otherwise when the creature's movement
  in whole steps beats the fastest enemy's, or on 1 in 2 when they tie. Success takes the creature out of play as
  running, with 'Got Away'; failure prints 'Escape is blocked'. The creature's actions end either way.
  @param(creature The creature fleeing.)
  @returns(The result of ending its actions.) }
function AttemptFlee(creature: Pointer): Boolean;

{ Sets a creature's current attacks for the round. It starts from the weapon's rate of fire (at least 2) when it has a
  ranged weapon with ammunition, else from its base attacks, both in half-attacks; applies its condition-18 effects and
  AttacksFromRate, and caps a ranged weapon by its ammunition. Once an attack has been made this round, the result only
  replaces the current attacks when it is lower.
  @param(creature The creature whose attacks are recalculated.) }
procedure RecalcAttacksLeft(creature: Pointer);

{ Tells whether an attacker may target a creature: itself always; otherwise the target's and the attacker's veto effects
  may refuse, and a creature of its own side needs the ally flag.
  @param(attacker Creature targeting.)
  @param(target Creature targeted; nil is refused.)
  @param(allowAlly Nonzero to allow its own side.)
  @returns(True when it may.) }
function CanTarget(attacker, target: Pointer; allowAlly: Byte): Boolean;

{ Turns undead. The turning column is the better of the cleric level and the paladin level less 2, compressed above 8
  (9..13 -> 9, 14 and up -> 10), less the area's turn-undead penalty. One d20 roll is checked against the strongest
  undead in view first. On success the creature is turned, or destroyed when its table entry is negative, and the number
  affected is d12, or d6+6 for destruction; a failure moves on to weaker undead.
  @param(creature The turner, a Types.PCharRecord.) }
procedure CombatTurnUndead(creature: Pointer);

{ Finds the highest-level unturned undead in the target list (any range) at or below a level cap; equal levels keep the
  earlier one.
  @param(creature The creature turning undead.)
  @param(target Receives the undead found, or nil.)
  @param(levelCap The highest undead level allowed; receives the level found, or 0.)
  @returns(True if a target was found.) }
function FindTurnUndeadTarget(creature: Pointer; var target: Pointer; var levelCap: ShortInt): Boolean;

{ Records an attack on a defender for flanking: the defender's count of attackers goes up, and the angle between its
  facing and the attack's direction (0..4) is added to its spread, mod 8.
  @param(attacker The attacker.)
  @param(defender The defender.) }
procedure NoteAttackDirection(attacker, defender: Pointer);

{ Carries out attacker's attack on defender. defender turns to face attacker unless it is flanked or attacked from
  behind, attacker turns to face defender, a missile weapon flies its icon across, and RollAttacks resolves the attacks.
  A missile weapon then loses the ammunition used in the first attack phase; a throwable weapon used up is moved onto
  the pile of dropped items, after GDVars.lastMissileItem, so it can be picked up after the battle. Note: the check for
  item types 28/29 reads the equipped weapon without first checking that there is one.
  @param(attacker The attacker, a Types.PCharRecord.)
  @param(defender The defender, a Types.PCharRecord.)
  @param(fromBehind True when the attack comes from behind, so the defender does not turn.)
  @param(weapon Passed on to RollAttacks.)
  @param(done Set when the attacker can act no more this turn.) }
procedure MakeAttack(attacker, defender: Pointer; fromBehind: Boolean; weapon: Pointer; var done: Boolean);

{ Builds the target list of a spell for the current caster, by the spell's area mode (the low nibble of its area byte):
  mode 0 is the caster alone; mode 5 a group picked one at a time until, from the second pick on, the creatures' weight
  exceeds a budget of 2d4, the weight counted by hit dice (for Faerie Fire by size, against a budget of the caster
  level); modes 8 to 14 everything within the radius (the area byte's low three bits) of a chosen point; mode 15 one
  creature, or everything within the radius (the area byte's high nibble) of a chosen point on the ground; any other
  mode the area byte's low two bits plus 1 separate creatures, never the same one twice, the Hold Person spells refusing
  the caster. A repeated pick is refused; for the computer it uses up a pick, or one point of the weight budget.
  @param(spellId The spell.)
  @param(ai Nonzero when the computer is choosing.)
  @param(found Receives False when nothing was targeted.) }
procedure SelectCombatTargets(spellId, ai: Byte; var found: Boolean);

{ Picks (from the spell menu, when no spell is given) and checks a spell, rejecting those not allowed in combat ('Camp
  Only Spell'). A casting delay (the casting time div 3) of 0 casts it at once and ends the caster's actions; otherwise
  the caster 'Begins Casting': the spell is recorded as being cast, initiative drops by the delay (to at least 1), and
  the caster moves back in the combat order to its new initiative, a tie going either way on a 1d2, so it resolves on a
  later action. Note: after an immediate cast, the result is that of ending the caster's actions, whatever the cast
  itself reported.
  @param(spell The spell to cast, or 0 to choose one from the menu.)
  @param(flag 0 redraws the combat screen first; passed on to the cast as its computer-controlled flag.)
  @param(outcome Set True when a spell was cast or begun, False otherwise.) }
procedure CastSpellCombat(spell, flag: Byte; var outcome: Boolean);

{ Asks before attacking an ally unless the defender is an enemy or the attacker is on quick-fight; a yes sets the
  attacked-allies flags.
  @param(attacker Creature attacking.)
  @param(defender Creature attacked.)
  @returns(True when the attack goes ahead.) }
function CheckAttackAlly(attacker, defender: Pointer): Boolean;

{ Runs the aim menu, which chooses a target for a combatant's attack or spell. Next and Prev step through the creatures
  it may attack, in rank order; Manual runs the aim cursor; Target confirms (and for an attack carries it out); Center
  recenters the view; Exit and Esc give up.
  @param(cr The combatant aiming.)
  @param(range The range, or 255 for the range of the combatant's weapon (1 without one).)
  @param(weaponMode 1 for an attack, 0 for a spell.)
  @param(groundOk Nonzero allows aiming at an empty cell.)
  @param(extra Nonzero allows aiming at a creature.)
  @param(done Receives whether a target was confirmed.)
  @param(tgt Receives the target, a TAimTarget.) }
procedure CombatAimMenu(cr: Pointer; range, weaponMode, groundOk, extra: Byte; var done: Boolean; var tgt);

{ Works out the hostile side's remaining hit points as a percentage of its maximum, in steps of 5, into
  GDVars.hostileHpPercent. Creatures with status 9 do not count, and creatures out of play count only toward the
  maximum. }
procedure UpdateHostileHpPercent;

{ Finds the fastest enabled enemy's movement in whole steps, with no range or line-of-sight check.
  @param(creature The creature whose enemies are checked.)
  @returns(The highest enemy movement, in whole steps.) }
function HighestEnemyMovement(creature: Pointer): Byte;

{ Chooses a target for a computer-controlled combatant and stores it in its combat record. The current target is kept if
  it is still an enemy in play that the combatant may attack, unless `forceNew` is set. Otherwise the creatures within
  range are tried once each, from a random starting point; when none will do, a second pass looks again with the map's
  height check off (unless `forceNew` is set), and with `relaxed` set it then accepts any candidate.
  @param(cr The combatant.)
  @param(range The range searched.)
  @param(relaxed Nonzero accepts any candidate on the second pass.)
  @param(forceNew Nonzero drops the current target.)
  @param(extra Passed on to CountTargets (to look at the combatant's own side) and to CanTarget.)
  @returns(True when the combatant has a target.) }
function AcquireTarget(cr: Pointer; range, relaxed, forceNew, extra: Byte): Boolean;

{ A testing cheat: when the program's third command-line parameter is 'Helm', every hostile creature is killed and every
  combatant's actions end. Returns True when the cheat fired.
  @returns(True when the cheat fired.) }
function VictoryCheat: Boolean;

{ Rates a spell for the computer: the caster itself for a single-target spell, otherwise the creatures within the
  spell's range, nearest first, until one rates above 0. Each is judged against the caster's own side for a
  non-offensive spell and against its enemies otherwise.
  @param(cr The caster.)
  @param(spell The spell.)
  @returns(The score, above 0 when there is a worthwhile target.) }
function RateSpell(cr: Pointer; spell: Byte): ShortInt;

{ Sets which creatures fight under computer control at the start of combat. Every hostile does, and so does every
  non-player creature in the party. Then each active paladin among the party's player characters gives each such
  creature of intelligence above 3 a chance to come under player control instead. }
procedure UseLeadership;

{ The Beholder's eye rays, an effect handler. Each round it uses up to four eyes, each at most once, on its current
  target, picking by range: disintegrate (range 2 or less), flesh to stone (3), death ray (4) and cause serious wounds
  (5), then the spells 84, 55 and 21 at any range. It picks its target again after each of the four rays. p and removed
  are not used.
  @param(cr The Beholder.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure AttackEyeRays(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

implementation

function AttacksFromRate(rate: Byte): Byte; forward;

function AimTargetMenu(cur, tgt: Pointer; range, weaponMode, flagC, flagB, flagA: Byte; outB,
                       outA: ShortInt): Char; forward;

procedure ConfirmAttackTarget(cur, tgt: Pointer; weaponMode: Byte; var done: Boolean; var sel); forward;

procedure ManualAimCursor(cur, underCursor: Pointer; range, weaponMode, ground, flagD: Byte; var valid, done: Boolean;
                          var sel; cellX, cellY: ShortInt); forward;

function IsBackstab(attacker, defender: Pointer): Boolean; forward;

procedure ApplyRangePenalty(attacker, defender: Pointer; var armorClass: Byte); forward;

procedure AnimateMissile(attacker, defender, weapon: Pointer); forward;

function RateSpellTarget(target: Pointer; spell: Byte; side: ShortInt): ShortInt; forward;

function AimAreaSpell(spell: Byte; var tgt): Boolean; forward;

procedure BeginRound(creature: Pointer);
var
  i: Byte;
  cellIndex: Byte;
  specialTerrain: Byte;
begin
  with Types.PCharRecord(creature)^.combatAddr^ do begin
    spellCast := 0;
    CbtMap.ProbeDirection(Types.PCharRecord(creature), C_Dir.CENTER, cellIndex, cellIndex, specialTerrain);
    castAllowed := 0;
    for i := 0 to 140 do
      if (Types.PCharRecord(creature)^.spells[i] > 0) and
          (Types.PCharRecord(creature)^.spells[i] < C_Spell.PENDING_FLAG) then
        castAllowed := 1;
    castAllowed := Byte((castAllowed <> 0) and Boolean(specialTerrain = 0));
    itemUseAllowed := Byte(specialTerrain = 0);
    madeAttack := 0;
    attackPhase := 2;
    CbtActs.RecalcAttacksLeft(creature);
    GDVars.attackRate := Types.PCharRecord(creature)^.attacks2;
    GDVars.attackInitByte := 0;
    FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
    Types.PCharRecord(creature)^.attacksLeft[2] := CbtActs.AttacksFromRate(GDVars.attackRate);
    if Types.PCharRecord(creature)^.inPlay <> 0 then begin
      initiative := FxEngine.RollDice(1, 6) + CharHlp.DexMissileAdjust(creature);
      if initiative < 1 then
        initiative := 1;
      if Byte(Integer(GDVars.vmBand.zone0^.surpriseMask) and (Types.PCharRecord(creature)^.side + 1)) <> 0 then
        Dec(initiative, 6);
      if (initiative < 0) or (initiative > 20) then
        initiative := 0;
    end else
      initiative := 0;
  end;
  Types.PCharRecord(creature)^.combatAddr^.movement := CharHlp.RecalcMovement(creature);
end;

{ Rolls the damage of one hit in attack phase (1 or 2): the weapon's dice plus its modifier, at least 0. The
  weapon-damage condition hooks of attacker and defender run next, and a backstab then multiplies the total by (thief
  level - 1) div 4 + 2, at most 5.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @param(phase The attack phase, 1 or 2.) }
procedure CalcWeaponDamage(attacker, defender: Pointer; phase: Byte);
var
  multiplier: Byte;
begin
  GDVars.pendingDamage := Types.PCharRecord(attacker)^.curModA[phase]
             + FxEngine.RollDamageDice(Types.PCharRecord(attacker)^.curRollsA[phase],
                                       Types.PCharRecord(attacker)^.curDiceA[phase]);
  if GDVars.pendingDamage < 0 then
    GDVars.pendingDamage := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACKER_WEAPON_DAMAGE, attacker);
  FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_WEAPON_DAMAGE, defender);
  if CbtActs.IsBackstab(attacker, defender) then begin
    multiplier := (ClassCal.EffectiveClassLevel(Types.PCharRecord(attacker), C_Class.THIEF) - 1) div 4 + 2;
    if multiplier > 5 then
      multiplier := 5;
    GDVars.pendingDamage := GDVars.pendingDamage * multiplier;
  end;
  GDVars.elementMask := 0;
end;

{ Reports one attack and applies its result. Damage interrupts a spell being cast. A creature that goes down is
  announced as dying or killed (unless bit 3 of its immunities is set), its hit-point effects run, and it is removed
  from the map. The hit or miss line is not printed for a defender that is already gone.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @param(manner How the attack was made: 0 a normal attack, 1 from behind, 2 a backstab, 3 slaying a helpless creature.)
  @param(damage The damage inflicted.)
  @param(shownDamage The damage printed.)
  @param(isHit Set for a hit.) }
procedure ProcessAttackResult(attacker, defender: Pointer; manner: Byte; damage, shownDamage: Word; isHit: Boolean);
var
  row: Byte;
  message: String[80];
  { Unused in this version; see the other implementations of this routine. }
  isDone: Boolean;
begin
  case manner of
    2: message := '-Backstabs-';
    3: message := 'slays helpless';
  else
    message := 'Attacks';
  end;
  CharHlp.PrintCreatureMessage(attacker, message, 10, False);
  row := 12;
  CharHlp.DisplayCreatureName(defender, 23, row, False);
  Inc(row);
  if manner = 1 then
    message := '(from behind) '
  else
    message := '';
  if isHit then begin
    if manner = 3 then
      message := 'with one cruel blow'
    else begin
      message := message + 'Hitting for ' + CharHlp.Uint8Str(shownDamage);
      if shownDamage = 1 then
        message := message + ' point '
      else
        message := message + ' points ';
      message := message + 'of damage';
    end;
    CharHlp.InflictDamage(defender, damage);
  end else
    message := message + 'and Misses';
  if Types.PCharRecord(defender)^.status <> C_Status.GONE then
    TextRend.DisplayMessageWindow(23, row, 38, row + 3, 10, 0, True, message);
  row := GDVars.textCursorRow + 1;
  if damage > 0 then begin
    Types.PCharRecord(defender)^.combatAddr^.castAllowed := 0;
    if Types.PCharRecord(defender)^.combatAddr^.spellCast > 0 then begin
      TextRend.PauseOnly;
      CharHlp.PrintCreatureMessage(defender, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(defender, Types.PCharRecord(defender)^.combatAddr^.spellCast);
      isDone := CharHlp.EndActions(defender);
    end else
      TextRend.PauseOnly;
  end else
    TextRend.PauseOnly;
  if Types.PCharRecord(defender)^.inPlay = 0 then begin
    CharHlp.PrintCreatureMessage(defender, 'goes down', row, False);
    if (Types.PCharRecord(defender)^.immunities and 8) = 0 then begin
      Inc(row, 2);
      if Types.PCharRecord(defender)^.status = C_Status.DYING then
        TextRend.DisplayString(23, row, 10, 0, 'and is Dying');
      if Types.PCharRecord(defender)^.status in
          [C_Status.DEAD_STATUS, C_Status.PETRIFIED, C_Status.GONE] then
        CharHlp.PrintCreatureMessage(defender, 'is killed', row, False);
      Inc(row, 2);
    end;
    FxEngine.RemoveEffectsHp0(defender);
    FxEngine.TriggerEffectsWithCondition(C_Cond.ZERO_HIT_POINTS, defender);
    if (Types.PCharRecord(defender)^.inPlay = 0) and (Types.PCharRecord(defender)^.status <> 10) then
      CbtMap.CreatureDowned(defender)
    else
      TextRend.PauseOnly;
  end;
  CharHlp.ClearMessageWindow;
end;

{ Lets guarding enemies strike a creature that moved next to them: each adjacent enemy that is guarding and not helpless
  spends its guard on one free attack, while the mover stays up.
  @param(creature The creature that moved.) }
procedure GuardersAttack(creature: Pointer);
var
  count: Byte;
  index: Byte;
  guarder: Types.PCharRecord;
  done: Boolean;
begin
  count := CharHlp.CountTargets(creature, 1, False);
  for index := 1 to count do
    if Types.PCharRecord(creature)^.inPlay <> 0 then begin
      guarder := GDVars.slotCreatures[GDVars.potentialTargets[index]];
      if (guarder^.combatAddr^.guarding <> 0) and (not CharHlp.IsHelpless(guarder)) then begin
        CbtMap.ScrollView(CbtMap.CombatCellX(Types.PCharRecord(creature)),
                          CbtMap.CombatCellY(Types.PCharRecord(creature)), 2, C_Dir.CENTER);
        guarder^.combatAddr^.guarding := 0;
        CbtActs.NoteAttackDirection(guarder, creature);
        CbtActs.MakeAttack(guarder, creature, False, nil, done);
      end;
    end;
end;

procedure CombatMoveCreature(creature: Pointer; direction: Byte);
var
  { movement-point cost, then reused as the scroll speed }
  moveCost: Byte;
  slot: Byte;
  { the destination cell }
  nx: ShortInt;
  ny: ShortInt;
  { the starting cell }
  x: ShortInt;
  y: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  destTerrain: Byte;
begin
  slot := CbtMap.CombatSlot(Types.PCharRecord(creature));
  x := GDVars.arenaSlots[slot].x;
  y := GDVars.arenaSlots[slot].y;
  nx := x + GDConsts.dirDeltaX[direction];
  ny := y + GDConsts.dirDeltaY[direction];
  if Odd(direction) then
    moveCost := GDConsts.terrainTable[Types.PCombatMap(GDVars.arenaPtr)^.cells[ny, nx]].cost * 3
  else
    moveCost := GDConsts.terrainTable[Types.PCombatMap(GDVars.arenaPtr)^.cells[ny, nx]].cost * 2;
  if moveCost > Types.PCharRecord(creature)^.combatAddr^.movement then
    Types.PCharRecord(creature)^.combatAddr^.movement := 0
  else
    Dec(Types.PCharRecord(creature)^.combatAddr^.movement, moveCost);
  moveCost := 1;
  if Types.PCharRecord(creature)^.quickfight <> 0 then begin
    moveCost := 3;
    if not CbtMap.ViewCoordsValid(nx - GDVars.arenaPtr^.ox, ny - GDVars.arenaPtr^.oy) then
      if GDVars.combatGfxOn <> 0 then
        CbtMap.ScrollView(x, y, 2, C_Dir.CENTER);
  end;
  if GDVars.combatGfxOn <> 0 then
    CbtMap.UpdateCombatMapTile(0, 0, slot);
  GDVars.arenaSlots[slot].x := nx;
  GDVars.arenaSlots[slot].y := ny;
  CbtMap.BuildArenaArrays;
  if GDVars.combatGfxOn <> 0 then
    CbtMap.ScrollView(nx, ny, moveCost, C_Dir.CENTER);
  Types.PCharRecord(creature)^.combatAddr^.flankCount := 0;
  Types.PCharRecord(creature)^.combatAddr^.flankSpread := 0;
  Music.SendSoundCommand(GDConsts.soundIds[C_Sound.STEP]);
  CbtActs.GuardersAttack(creature);
  if (Types.PCharRecord(creature)^.inPlay = 0) or CharHlp.IsHelpless(creature) then
    Types.PCharRecord(creature)^.combatAddr^.movement := 0;
end;

procedure AttacksOfOpportunity(creature: Pointer; direction: Byte);
var
  { the adjacent enemies before the step }
  candidates: array[1..12] of Byte;
  { HasEffect's out-parameter, not used }
  effect: Pointer;
  { the enemy is still adjacent after the step }
  stillAdjacent: Boolean;
  { the enemy has made its attack }
  attacked: Boolean;
  slot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
  { CountTargets' count, then the filtered count }
  candidateCount: Byte;
  { the adjacent enemies after the step }
  countAfter: Byte;
  scanPos: Byte;
  { index into candidates }
  index: Byte;
  phasePos: Byte;
  { the attack phase used }
  phase: Byte;
  { direction within the enemy's facing wedge }
  facingScan: Byte;
  { the attacking enemy }
  attacker: Pointer;
  { its target, restored after the attack }
  savedTarget: Pointer;
begin
  slot := CbtMap.CombatSlot(Types.PCharRecord(creature));
  candidateCount := CharHlp.CountTargets(creature, 1, False);
  if candidateCount = 0 then
    Exit;
  GameIo.ZeroFill(candidates, SizeOf(candidates));
  index := 1;
  for scanPos := 1 to candidateCount do
    if not CharHlp.IsHelpless(GDVars.slotCreatures[GDVars.potentialTargets[scanPos]]) then
      if Types.PCharRecord(GDVars.slotCreatures[GDVars.potentialTargets[scanPos]])^.combatAddr^.turned = 0 then
        if not CharHlp.HasEffect(GDVars.slotCreatures[GDVars.potentialTargets[scanPos]], C_Effect.CONFUSED_LOSE_TURN,
                                 effect) then begin
          candidates[index] := GDVars.potentialTargets[scanPos];
          Inc(index);
        end;
  candidateCount := index - 1;
  Inc(GDVars.arenaSlots[slot].x, GDConsts.dirDeltaX[direction]);
  Inc(GDVars.arenaSlots[slot].y, GDConsts.dirDeltaY[direction]);
  countAfter := CharHlp.CountTargets(creature, 1, False);
  Dec(GDVars.arenaSlots[slot].x, GDConsts.dirDeltaX[direction]);
  Dec(GDVars.arenaSlots[slot].y, GDConsts.dirDeltaY[direction]);
  for index := 1 to candidateCount do begin
    stillAdjacent := False;
    for scanPos := 1 to countAfter do
      if GDVars.potentialTargets[scanPos] = candidates[index] then
        stillAdjacent := True;
    if stillAdjacent then
      candidates[index] := 0;
  end;
  for index := 1 to candidateCount do
    if candidates[index] > 0 then
      if Types.PCharRecord(creature)^.inPlay <> 0 then begin
        GDVars.infoPanelDirty := 1;
        GDVars.combatGfxOn := 1;
        attacked := False;
        attacker := GDVars.slotCreatures[candidates[index]];
        if CbtActs.CanTarget(attacker, creature, 0) then
          if (not CharHlp.HasRangedWeapon(attacker)) or CharHlp.HasThrowableWeapon(attacker) then
            for facingScan := Types.PCharRecord(attacker)^.combatAddr^.direction + 6
                  to Types.PCharRecord(attacker)^.combatAddr^.direction + 10 do
              if not attacked then
                if (Types.PCharRecord(attacker)^.combatAddr^.initiative > 0) or
                    (Types.PCharRecord(attacker)^.combatAddr^.flankCount = 0) or
                    Pathing.IsDirToward(CbtMap.CombatCellX(Types.PCharRecord(attacker)),
                                        CbtMap.CombatCellY(Types.PCharRecord(attacker)),
                                        CbtMap.CombatCellX(Types.PCharRecord(creature)),
                                        CbtMap.CombatCellY(Types.PCharRecord(creature)), facingScan mod 8) then begin
                  phase := 1;
                  if Types.PCharRecord(attacker)^.attacks = 0 then
                    phase := 2;
                  for phasePos := 1 to 2 do
                    if Types.PCharRecord(attacker)^.attacksLeft[phasePos] > 0 then
                      phase := phasePos;
                  if Types.PCharRecord(attacker)^.attacksLeft[phase] = 0 then
                    Types.PCharRecord(attacker)^.attacksLeft[phase] := 1;
                  Types.PCharRecord(attacker)^.combatAddr^.attackPhase := phase;
                  savedTarget := Types.PCharRecord(attacker)^.combatAddr^.other;
                  CbtActs.MakeAttack(attacker, creature, True, nil, GDVars.roundDone);
                  attacked := True;
                  Types.PCharRecord(attacker)^.combatAddr^.other := savedTarget;
                  if Types.PCharRecord(creature)^.inPlay <> 0 then begin
                    GDVars.infoPanelDirty := 1;
                    CharHlp.CombatPrintCreatureInfo(creature);
                  end;
                end;
      end;
end;

function AttemptFlee(creature: Pointer): Boolean;
var
  hasEscaped: Boolean;
  { the fastest enemy's half movement }
  enemyMove: Byte;
  { the creature's own half movement }
  creatureMove: Byte;
begin
  hasEscaped := False;
  if CharHlp.CountTargets(creature, 255, False) = 0 then
    hasEscaped := True
  else begin
    creatureMove := CharHlp.RecalcMovement(creature) div 2;
    enemyMove := CbtActs.HighestEnemyMovement(creature);
    if enemyMove < creatureMove then
      hasEscaped := True
    else if enemyMove = creatureMove then
      if FxEngine.RollDice(1, 2) = 1 then
        hasEscaped := True;
  end;
  if hasEscaped then
    FxEngine.PutOutOfPlayWithStatus(creature, C_Status.RUNNING, 'Got Away')
  else
    CharHlp.PrintBottomLine('Escape is blocked');
  AttemptFlee := CharHlp.EndActions(creature);
end;

procedure RecalcAttacksLeft(creature: Pointer);
var
  { the new number of attacks }
  attacks: Byte;
  { the attacks left before }
  previous: Byte;
  { the ammunition available }
  ammoLimit: Byte;
  { the missile weapon's rate of fire }
  rate: Byte;
  ranged: Boolean;
  weapon: Pointer;
begin
  ranged := False;
  previous := Types.PCharRecord(creature)^.attacksLeft[1];
  Types.PCharRecord(creature)^.attacksLeft[1] := Types.PCharRecord(creature)^.attacks;
  if CharHlp.HasRangedWeapon(creature) and CharHlp.FindDamagingRangedWeapon(creature, weapon) then begin
    ranged := True;
    rate := GDVars.baseItemTable[Types.PCharRecord(creature)^.equipped[C_Equip.WEAPON]^.definition.itemType].rateOfFire;
    if rate < 2 then
      rate := 2;
    GDVars.attackRate := rate;
  end else
    GDVars.attackRate := Types.PCharRecord(creature)^.attacksLeft[1];
  GDVars.attackInitByte := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
  attacks := CbtActs.AttacksFromRate(GDVars.attackRate);
  if ranged and (weapon <> nil) then begin
    ammoLimit := 1;
    if weapon <> nil then
      if Types.PItemRec(weapon)^.definition.quantity > ammoLimit then
        ammoLimit := Types.PItemRec(weapon)^.definition.quantity;
    if (ammoLimit < attacks) and (Types.PItemRec(weapon)^.definition.quantity > 0) then
      attacks := ammoLimit;
  end;
  if (Types.PCharRecord(creature)^.combatAddr^.madeAttack = 0) or (attacks < previous) then
    Types.PCharRecord(creature)^.attacksLeft[1] := attacks
  else
    Types.PCharRecord(creature)^.attacksLeft[1] := previous;
end;

{ Converts half-attacks to attacks: adds 1 on odd rounds, then halves.
  @param(rate The rate in half-attacks.)
  @returns(The whole attacks for this round.) }
function AttacksFromRate(rate: Byte): Byte;
var
  adjusted: Byte;
begin
  adjusted := rate;
  if Odd(GDVars.combatRound) then
    Inc(adjusted);
  AttacksFromRate := adjusted div 2;
end;

function CanTarget(attacker, target: Pointer; allowAlly: Byte): Boolean;
var
  { GDVars.currentChar, restored after the target hooks }
  savedCharacter: Types.PCharRecord;
  { attacker's target, restored after the attacker hooks }
  savedTarget: Types.PCharRecord;
begin
  CanTarget := False;
  if target = nil then
    Exit;
  if attacker = target then begin
    CanTarget := True;
    Exit;
  end;
  GDVars.attackVetoed := 0;
  savedCharacter := GDVars.currentChar;
  GDVars.currentChar := Types.PCharRecord(attacker);
  FxEngine.TriggerEffectsWithCondition(C_Cond.TARGET_VETO, target);
  GDVars.currentChar := savedCharacter;
  if (GDVars.attackVetoed = 0) and ((Types.PCharRecord(target)^.side <> Types.PCharRecord(attacker)^.side) or
                                      (allowAlly <> 0)) then begin
    savedTarget := Types.PCharRecord(attacker)^.combatAddr^.other;
    Types.PCharRecord(attacker)^.combatAddr^.other := Types.PCharRecord(target);
    FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACKER_VETO, attacker);
    Types.PCharRecord(attacker)^.combatAddr^.other := savedTarget;
  end else
    GDVars.attackVetoed := 1;
  CanTarget := GDVars.attackVetoed = 0;
end;

procedure CombatTurnUndead(creature: Pointer);
var
  roll: Byte;
  { 255 until the first target sets the real count }
  affectedLeft: Byte;
  minimumLeft: Byte;
  needed: ShortInt;
  turnedAny: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  stop: Boolean;
  target: Pointer;
  tableColumn: ShortInt;
  { the highest undead level still to try }
  levelCap: ShortInt;
begin
  CharHlp.PrintCreatureMessage(creature, 'turns undead...', 10, False);
  MenuCore.ClearBottomLine;
  TextRend.PauseOnly;
  turnedAny := False;
  stop := False;
  Inc(Types.PCharRecord(creature)^.combatAddr^.turnAttempts);
  levelCap := 13;
  minimumLeft := 6;
  roll := FxEngine.RollDice(1, 20);
  tableColumn := ClassCal.EffectiveClassLevel(Types.PCharRecord(creature), C_Class.CLERIC);
  if tableColumn < ClassCal.EffectiveClassLevel(Types.PCharRecord(creature), C_Class.PALADIN) - 2 then
    tableColumn := ClassCal.EffectiveClassLevel(Types.PCharRecord(creature), C_Class.PALADIN) - 2;
  if tableColumn > 8 then
    if tableColumn < 14 then
      tableColumn := 9
    else
      tableColumn := 10;
  if GDVars.vmBand.zone0^.turnUndeadPenalty > tableColumn then
    tableColumn := 0
  else
    Dec(tableColumn, GDVars.vmBand.zone0^.turnUndeadPenalty);
  affectedLeft := 255;
  while CbtActs.FindTurnUndeadTarget(creature, target, levelCap) and (affectedLeft > 0) do begin
    needed := GDConsts.turnUndeadTable[Types.PCharRecord(target)^.levelUndead, tableColumn];
    if affectedLeft = 255 then
      if needed < 0 then
        affectedLeft := FxEngine.RollDice(1, 6) + 6
      else
        affectedLeft := FxEngine.RollDice(1, 12);
    if roll >= Abs(needed) then begin
      turnedAny := True;
      CbtMap.DisplayMapViewCentered(target, 3, False);
      GDVars.infoPanelDirty := 1;
      CharHlp.CombatPrintCreatureInfo(target);
      if needed > 0 then
        FxEngine.PutOutOfPlayWithStatus(target, C_Status.RUNNING, 'is turned')
      else begin
        CharHlp.PrintCreatureMessage(target, 'Is destroyed', 10, False);
        CbtMap.CreatureDowned(target);
        Types.PCharRecord(target)^.status := C_Status.GONE;
        Types.PCharRecord(target)^.inPlay := 0;
      end;
      if minimumLeft > 0 then
        Dec(minimumLeft);
      Dec(affectedLeft);
      if affectedLeft = 0 then
        if minimumLeft > 0 then
          if needed < 0 then
            Inc(affectedLeft);
      CharHlp.ClearMessageWindow;
    end else
      Dec(levelCap);
  end;
  if not turnedAny then
    CharHlp.PrintBottomLine('Nothing Happens...');
  CharHlp.CountTeams;
  GDVars.roundDone := CharHlp.EndActions(creature);
  CharHlp.ClearMessageWindow;
end;

function FindTurnUndeadTarget(creature: Pointer; var target: Pointer; var levelCap: ShortInt): Boolean;
var
  count: Byte;
  index: Byte;
  bestLevel: ShortInt;
  candidate: Types.PCharRecord;
begin
  bestLevel := 0;
  target := nil;
  count := CharHlp.CountTargets(creature, 255, False);
  FindTurnUndeadTarget := False;
  for index := 1 to count do begin
    candidate := GDVars.slotCreatures[GDVars.potentialTargets[index]];
    if candidate^.combatAddr^.turned = 0 then
      if candidate^.levelUndead > 0 then
        if candidate^.levelUndead > bestLevel then
          if candidate^.levelUndead <= levelCap then begin
            bestLevel := candidate^.levelUndead;
            target := candidate;
            FindTurnUndeadTarget := True;
          end;
  end;
  levelCap := bestLevel;
end;

{ Resolves an attacker's attacks on a defender. A helpless defender is slain outright. Otherwise a weapon against a
  large defender uses its large-target damage dice, and the defender's defense is its rear armor class less 4 for a
  backstab, or its rear armor class when attacked from behind (a flanked defender whose facing the attack comes along,
  with a wide enough spread of attackers), adjusted for range. The attacker then attacks with each attack phase's
  remaining attacks until the defender goes down; when it has no attacks left or is down, its actions end. Note: the
  starting phase is cleared when the attacker goes down, but it is not read again.
  @param(att The attacker.)
  @param(def The defender.)
  @param(fromBehind True when the attack comes from behind.)
  @param(done Set when the attacker has no attacks left or is down.)
  @param(weapon The weapon, or nil.) }
procedure RollAttacks(att, def: Pointer; fromBehind: Boolean; var done: Boolean; weapon: Pointer);
var
  { the weapon's base-item entry, for its large-target dice }
  base: Types.TBaseItem;
  anyHit: Boolean;
  defDowned: Boolean;
  behind: Boolean;
  defense: Byte;
  phase: Byte;
  startPhase: Byte;
  atkType: Byte;
  behindIdx: ShortInt;
begin
  behind := fromBehind;
  done := False;
  GDVars.attackHits[1] := 0;
  GDVars.attackHits[2] := 0;
  GDVars.attackCounts[1] := 0;
  GDVars.attackCounts[2] := 0;
  anyHit := False;
  defDowned := False;
  GDVars.pendingDamage := 0;
  Types.PCharRecord(att)^.combatAddr^.madeAttack := 1;
  if CharHlp.IsHelpless(def) then begin
    Music.SendSoundCommand(GDConsts.soundIds[7]);
    while Types.PCharRecord(att)^.attacksLeft[Types.PCharRecord(att)^.combatAddr^.attackPhase] = 0 do
      Dec(Types.PCharRecord(att)^.combatAddr^.attackPhase);
    Inc(GDVars.attackCounts[Types.PCharRecord(att)^.combatAddr^.attackPhase]);
    CbtActs.ProcessAttackResult(att, def, 3, Types.PCharRecord(def)^.hpCur + 5, 1, True);
    FxEngine.RemoveInvisibility(att);
    Types.PCharRecord(att)^.attacksLeft[1] := 0;
    Types.PCharRecord(att)^.attacksLeft[2] := 0;
    anyHit := True;
    done := True;
  end else begin
    if (Types.PCharRecord(att)^.equipped[C_Equip.WEAPON] <> nil) and
        ((Types.PCharRecord(def)^.iconDimensions > $80) or
         (Types.PCharRecord(def)^.iconDimensions and 7 > 1)) then begin
      base := GDVars.baseItemTable[Types.PCharRecord(att)^.equipped[C_Equip.WEAPON]^.definition.itemType];
      Types.PCharRecord(att)^.curRollsA[1] := base.dmgLgRolls;
      Types.PCharRecord(att)^.curDiceA[1] := base.dmgLgDice;
      Types.PCharRecord(att)^.curModA[1] := Types.PCharRecord(att)^.curModA[1] - base.dmgSmMod
          + base.dmgLgMod;
    end;
    CharHlp.RecalcStats(def);
    FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_ARMOR_CLASS, def);
    behindIdx := 0;
    if CbtActs.IsBackstab(att, def) then
      defense := Types.PCharRecord(def)^.armorClass[1] - 4
    else begin
      if Types.PCharRecord(def)^.combatAddr^.flankCount > 1 then
        if (CharHlp.DirTowardTarget(att, def) = Types.PCharRecord(def)^.combatAddr^.direction)
           and (Types.PCharRecord(def)^.combatAddr^.flankSpread > 4) then
          behind := True;
      if behind then
        behindIdx := 1;
      defense := Types.PCharRecord(def)^.armorClass[behindIdx];
    end;
    CbtActs.ApplyRangePenalty(att, def, defense);
    atkType := 0;
    if behind then
      atkType := 1;
    if CbtActs.IsBackstab(att, def) then
      atkType := 2;
    startPhase := Types.PCharRecord(att)^.combatAddr^.attackPhase;
    for phase := startPhase downto 1 do
      while (Types.PCharRecord(att)^.attacksLeft[phase] > 0) and (defDowned = False) do begin
        Dec(Types.PCharRecord(att)^.attacksLeft[phase]);
        Types.PCharRecord(att)^.combatAddr^.attackPhase := phase;
        Inc(GDVars.attackCounts[phase]);
        if FxEngine.AttackRoll(att, def, defense) or CharHlp.IsHelpless(def) then begin
          Inc(GDVars.attackHits[phase]);
          Music.SendSoundCommand(GDConsts.soundIds[7]);
          anyHit := True;
          CbtActs.CalcWeaponDamage(att, def, phase);
          if Types.PCharRecord(def)^.inPlay <> 0 then
            CbtActs.ProcessAttackResult(att, def, atkType, GDVars.pendingDamage, GDVars.pendingDamage, True);
          if (Types.PCharRecord(def)^.inPlay <> 0) and (GDVars.pendingDamage > 0) then
            FxEngine.TriggerEffectsWithCondition(phase + 1, att);
          if Types.PCharRecord(def)^.inPlay = 0 then
            defDowned := True;
          if Types.PCharRecord(att)^.inPlay = 0 then begin
            startPhase := 0;
            Types.PCharRecord(att)^.attacksLeft[phase] := 0;
          end;
        end;
      end;
    if not anyHit then begin
      if weapon = nil then
        Music.SendSoundCommand(GDConsts.soundIds[9]);
      CbtActs.ProcessAttackResult(att, def, atkType, 0, 0, False);
    end;
    done := True;
    for phase := 1 to 2 do
      if Types.PCharRecord(att)^.attacksLeft[phase] > 0 then
        done := False;
  end;
  if Types.PCharRecord(att)^.inPlay = 0 then
    done := True;
  if done then
    done := CharHlp.EndActions(att);
end;

procedure NoteAttackDirection(attacker, defender: Pointer);
var
  angle: Byte;
  attackDirection: Byte;
begin
  Inc(Types.PCharRecord(defender)^.combatAddr^.flankCount);
  attackDirection := CharHlp.DirTowardTarget(defender, attacker);
  angle := (attackDirection - Types.PCharRecord(defender)^.combatAddr^.direction + 8) mod 8;
  if angle > 4 then
    angle := 8 - angle;
  Types.PCharRecord(defender)^.combatAddr^.flankSpread := (Types.PCharRecord(defender)^.combatAddr^.flankSpread +
    angle) mod 8;
end;

procedure MakeAttack(attacker, defender: Pointer; fromBehind: Boolean; weapon: Pointer; var done: Boolean);
var
  { the copy of a thrown weapon }
  thrownCopy: Types.PItemRec;
  { walks the pile of dropped items }
  walker: Types.PItemRec;
  savedCharacter: Types.PCharRecord;
  direction: Byte;
begin
  GDVars.combatGfxOn := 1;
  GDVars.infoPanelDirty := 1;
  GDVars.fightEndRound := GDVars.combatRound + 15;
  if (Types.PCharRecord(defender)^.combatAddr^.flankCount < 2) and (not fromBehind) then begin
    direction := CharHlp.DirTowardTarget(defender, attacker);
    Types.PCharRecord(defender)^.combatAddr^.direction := (direction + 4) mod 8;
  end else if CbtMap.CombatIconVisible(Types.PCharRecord(defender), 0) then begin
    direction := Types.PCharRecord(defender)^.combatAddr^.direction;
    if not fromBehind then
      Types.PCharRecord(defender)^.combatAddr^.direction := (direction + 4) mod 8;
  end;
  if CbtMap.CombatIconVisible(Types.PCharRecord(defender), 0) then
    CbtMap.SetCreatureFacing(Types.PCharRecord(defender), direction, 0, 0);
  direction := CharHlp.DirTowardTarget(attacker, defender);
  CharHlp.CombatPrintCreatureInfo(attacker);
  CbtMap.SetCreatureFacing(Types.PCharRecord(attacker), direction, 1, 0);
  Types.PCharRecord(attacker)^.combatAddr^.other := Types.PCharRecord(defender);
  Delay(100);
  if weapon <> nil then
    CbtActs.AnimateMissile(attacker, defender, weapon);
  if (Types.PCharRecord(attacker)^.equipped[C_Equip.WEAPON]^.definition.itemType = 28)
     or (Types.PCharRecord(attacker)^.equipped[C_Equip.WEAPON]^.definition.itemType = 29) then
    CbtActs.AnimateMissile(attacker, defender, Types.PCharRecord(attacker)^.equipped[C_Equip.WEAPON]);
  done := True;
  if (Types.PCharRecord(attacker)^.attacksLeft[1] > 0) or (Types.PCharRecord(attacker)^.attacksLeft[2] > 0) then begin
    savedCharacter := GDVars.currentChar;
    GDVars.currentChar := Types.PCharRecord(attacker);
    CbtActs.RollAttacks(attacker, defender, fromBehind, done, weapon);
    if weapon <> nil then begin
      if Types.PItemRec(weapon)^.definition.quantity > 0 then
        Dec(Types.PItemRec(weapon)^.definition.quantity, GDVars.attackCounts[1]);
      if Types.PItemRec(weapon)^.definition.quantity = 0 then
        if CharHlp.HasThrowableWeapon(attacker) and
            (Types.PItemRec(weapon)^.definition.effect <> C_Effect.SPIRITUAL_HAMMER) then begin
          GetMem(thrownCopy, SizeOf(Types.TItemRec));
          Move(Types.PItemRec(weapon)^, thrownCopy^, SizeOf(Types.TItemRec));
          walker := GDVars.treasureList;
          if walker = nil then begin
            GDVars.treasureList := thrownCopy;
            thrownCopy^.next := nil;
          end else begin
            while (walker^.next <> nil) and (Pointer(walker) <> GDVars.lastMissileItem) do
              walker := walker^.next;
            thrownCopy^.next := walker^.next;
            walker^.next := thrownCopy;
          end;
          thrownCopy^.definition.equipped := 0;
          CharHlp.RemoveItem(attacker, weapon);
          GDVars.lastMissileItem := thrownCopy;
        end else
          CharHlp.RemoveItem(attacker, weapon);
    end;
    CharHlp.RecalcStats(attacker);
    GDVars.currentChar := savedCharacter;
  end;
  if done then
    done := CharHlp.EndActions(attacker);
  if CbtMap.CombatIconVisible(Types.PCharRecord(attacker), 0) then begin
    CbtMap.SetCreatureFacing(Types.PCharRecord(attacker), Types.PCharRecord(attacker)^.combatAddr^.direction, 1, 1);
    CbtMap.SetCreatureFacing(Types.PCharRecord(attacker), Types.PCharRecord(attacker)^.combatAddr^.direction, 0, 0);
  end;
end;

{ Raises a defense value for range. With a ranged weapon the band is (range - 1) div 3 steps; a defender more than one
  band away adds 2 and more than two bands away 3 more. A weapon of range 3 or less has a band of 0, so any distance
  adds both. Melee adds nothing.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(armorClass The defense value, raised in place.) }
procedure ApplyRangePenalty(attacker, defender: Pointer; var armorClass: Byte);
var
  band: ShortInt;
  distance: ShortInt;
begin
  distance := CharHlp.CalcDistance(attacker, defender);
  if CharHlp.HasRangedWeapon(attacker) then
    band := (GDVars.baseItemTable[Types.PCharRecord(attacker)^.equipped[C_Equip.WEAPON]^.definition.itemType].range -
             1) div 3
  else
    band := distance;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 2;
  end;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 3;
  end;
end;

{ Chooses one target for a spell and moves the cast position to it. The player aims with the aim menu. The computer
  picks a creature, or for an area spell that may be aimed at the ground the best spot. On failure the target is
  cleared.
  @param(spellId The spell.)
  @param(aiControlled Nonzero when the computer is choosing.)
  @param(groundOk Nonzero allows an area spell to be aimed at the ground.)
  @param(target Receives the target.)
  @returns(True when a target was chosen.) }
function SelectSpellTarget(spellId, aiControlled, groundOk: Byte; var target): Boolean;
var
  found: Boolean;
  acceptable: Boolean;
  candidate: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  creatureOk: Byte;
  team: ShortInt;

  { Picks the nearest suitable creature and accepts it when RateSpellTarget rates it above 0. }
  function PickSpellTarget: Boolean;
  var
    succeeded: Boolean;
    ownTeam: Boolean;
  begin
    succeeded := False;
    acceptable := True;
    ownTeam := GDConsts.spellTable[spellId].offensive = 0;
    if CbtActs.AcquireTarget(GDVars.currentChar, Magic.CalcSpellRange(spellId), 0, 1, Byte(ownTeam)) then begin
      candidate := GDVars.currentChar^.combatAddr^.other;
      if ownTeam then
        team := GDVars.currentChar^.side
      else
        team := CharHlp.EnemyTeam(GDVars.currentChar);
      acceptable := CbtActs.RateSpellTarget(candidate, spellId, team) > 0;
      if acceptable then begin
        TAimTarget(target).cr := GDVars.currentChar^.combatAddr^.other;
        TAimTarget(target).x := CbtMap.CombatCellX(Types.PCharRecord(TAimTarget(target).cr));
        TAimTarget(target).y := CbtMap.CombatCellY(Types.PCharRecord(TAimTarget(target).cr));
        succeeded := True;
      end;
    end;
    PickSpellTarget := succeeded;
  end;

begin
  found := False;
  if aiControlled = 0 then begin
    creatureOk := Byte(spellId <> 83);
    CbtActs.CombatAimMenu(GDVars.currentChar, Magic.CalcSpellRange(spellId), 0, groundOk, creatureOk, found, target);
    GDVars.currentChar^.combatAddr^.other := TAimTarget(target).cr;
  end else begin
    if groundOk = 0 then
      found := PickSpellTarget
    else if GDConsts.spellTable[spellId].area = 8 then
      found := PickSpellTarget
    else
      found := CbtActs.AimAreaSpell(spellId, target);
  end;
  if found then begin
    SelectSpellTarget := True;
    GDVars.gTargetX := TAimTarget(target).x;
    GDVars.gTargetY := TAimTarget(target).y;
  end else begin
    SelectSpellTarget := False;
    GameIo.ZeroFill(target, SizeOf(TAimTarget));
  end;
end;

procedure SelectCombatTargets(spellId, ai: Byte; var found: Boolean);
var
  n: Byte;
  cnt: Byte;
  i: Byte;
  budget: Byte;
  weight: Byte;
  tgt: TAimTarget;
  dup: Boolean;
  finished: Boolean;
begin
  GameIo.ZeroFill(GDVars.spellTargetList, SizeOf(GDVars.spellTargetList));
  found := True;
  GDVars.spellTargetTotal := 0;
  GDVars.gMultiTarget := 0;
  GDVars.gTargetX := CbtMap.CombatCellX(GDVars.currentChar);
  GDVars.gTargetY := CbtMap.CombatCellY(GDVars.currentChar);
  case GDConsts.spellTable[spellId].area and $F of
    0:
      begin
        GDVars.spellTargetList[1] := GDVars.currentChar;
        GDVars.spellTargetTotal := 1;
      end;
    5:
      begin
        weight := 0;
        cnt := 0;
        if spellId = 79 then
          budget := CharHlp.GetCasterLevel(79, False)
        else
          budget := FxEngine.RollDice(2, 4);
        finished := False;
        repeat
          if CbtActs.SelectSpellTarget(spellId, ai, 0, tgt) then begin
            dup := False;
            for i := 1 to cnt do
              if GDVars.spellTargetList[i] = tgt.cr then
                dup := True;
            if not dup then begin
              Inc(cnt);
              GDVars.spellTargetList[cnt] := tgt.cr;
              GDVars.gTargetX := CbtMap.CombatCellX(Types.PCharRecord(tgt.cr));
              GDVars.gTargetY := CbtMap.CombatCellY(Types.PCharRecord(tgt.cr));
              Inc(GDVars.spellTargetTotal);
              if spellId <> 79 then
                case GDVars.spellTargetList[cnt]^.hitDice of
                  0, 1: Inc(weight);
                  2: Inc(weight, 2);
                  3: Inc(weight, 4);
                else
                  Inc(weight, 8);
                end else
                case GDVars.spellTargetList[cnt]^.iconDimensions of
                  1: Inc(weight);
                  2, 3: Inc(weight, 2);
                  4: Inc(weight, 4);
                end;
              if (cnt > 1) and (weight > budget) then
                finished := True;
            end else begin
              if ai <> 0 then
                Dec(budget)
              else
                CharHlp.PrintBottomLine('Already been targeted');
            end;
            CbtMap.RedrawArenaCell(CbtMap.CombatCellX(Types.PCharRecord(tgt.cr)),
                                   CbtMap.CombatCellY(Types.PCharRecord(tgt.cr)));
          end else
            finished := True;
        until finished or (budget = 0);
      end;
    8..14:
      begin
        if CbtActs.SelectSpellTarget(spellId, ai, 1, tgt) then begin
          Pathing.BuildTargetList(GDVars.gTargetX, GDVars.gTargetY, GDConsts.spellTable[spellId].area and 7, $FF,
                                  1);
          for cnt := 1 to GDVars.rankedTargetCount do
            GDVars.spellTargetList[cnt] := GDVars.slotCreatures[GDVars.rankedTargets[cnt].ent];
          GDVars.spellTargetTotal := GDVars.rankedTargetCount;
          GDVars.gMultiTarget := 1;
        end else
          found := False;
      end;
    15:
      begin
        if CbtActs.SelectSpellTarget(spellId, ai, 0, tgt) then begin
          if GDVars.currentChar^.combatAddr^.other <> nil then begin
            GDVars.spellTargetList[1] := GDVars.currentChar^.combatAddr^.other;
            GDVars.spellTargetTotal := 1;
          end else begin
            Pathing.BuildTargetList(GDVars.gTargetX, GDVars.gTargetY, GDConsts.spellTable[spellId].area shr 4, $FF,
                                    1);
            for cnt := 1 to GDVars.rankedTargetCount do
              GDVars.spellTargetList[cnt] := GDVars.slotCreatures[GDVars.rankedTargets[cnt].ent];
            GDVars.spellTargetTotal := GDVars.rankedTargetCount;
            GDVars.gMultiTarget := 1;
          end;
        end else
          found := False;
      end;
  else begin
      n := (GDConsts.spellTable[spellId].area and 3) + 1;
      cnt := 0;
      while n > 0 do begin
        if CbtActs.SelectSpellTarget(spellId, ai, 0, tgt) then begin
          dup := False;
          for i := 1 to cnt do
            if GDVars.spellTargetList[i] = tgt.cr then
              dup := True;
          if ((spellId = 23) or (spellId = 49)) and (tgt.cr = GDVars.currentChar) then
            dup := True;
          if not dup then begin
            Inc(cnt);
            GDVars.spellTargetList[cnt] := tgt.cr;
            Dec(n);
            GDVars.gTargetX := CbtMap.CombatCellX(Types.PCharRecord(tgt.cr));
            GDVars.gTargetY := CbtMap.CombatCellY(Types.PCharRecord(tgt.cr));
          end else if ai = 0 then begin
            if tgt.cr = GDVars.currentChar then
              CharHlp.PrintBottomLine('Cannot target yourself')
            else
              CharHlp.PrintBottomLine('Already been targeted');
          end else
            Dec(n);
          CbtMap.RedrawArenaCell(CbtMap.CombatCellX(Types.PCharRecord(tgt.cr)),
                                 CbtMap.CombatCellY(Types.PCharRecord(tgt.cr)));
        end else
          n := 0;
      end;
      GDVars.spellTargetTotal := cnt;
      if cnt = 0 then
        found := False
      else begin
        GDVars.gTargetX := CbtMap.CombatCellX(GDVars.spellTargetList[cnt]);
        GDVars.gTargetY := CbtMap.CombatCellY(GDVars.spellTargetList[cnt]);
      end;
    end;
  end;
end;

procedure CastSpellCombat(spell, flag: Byte; var outcome: Boolean);
var
  spellId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  castTime: Byte;
  { the caster's new place in the initiative queue }
  i: Byte;
  idx: Integer;
  notEmpty: Boolean;
  caster: Types.PCharRecord;
  { walks the initiative queue }
  p: Types.PCharRecord;
begin
  caster := GDVars.currentChar;
  notEmpty := True;
  idx := -1;
  outcome := False;
  spellId := spell;
  if spellId = 0 then
    spellId := ViewChar.SpellMenu(0, 1, idx, notEmpty);
  if spellId > 0 then
    if GDConsts.spellTable[spellId].whenCast = 0 then begin
      CharHlp.PrintBottomLine('Camp Only Spell');
      spellId := 0;
    end;
  if flag = 0 then begin
    CharHlp.DisplayCombatInterface;
    GDVars.combatGfxOn := 1;
    GDVars.infoPanelDirty := 1;
    CbtMap.DisplayMapViewCentered(Types.PCharRecord(caster), 3, True);
    CharHlp.CombatPrintCreatureInfo(caster);
  end;
  if spellId > 0 then begin
    castTime := GDConsts.spellTable[spellId].castTime div 3;
    if castTime = 0 then begin
      Magic.CastSpell(spellId, flag, 1, outcome);
      outcome := CharHlp.EndActions(caster);
    end else begin
      outcome := True;
      CharHlp.PrintCreatureMessage(caster, 'Begins Casting', 10, True);
      caster^.combatAddr^.spellCast := spellId;
      if caster^.combatAddr^.initiative > castTime then
        Dec(caster^.combatAddr^.initiative, castTime)
      else
        caster^.combatAddr^.initiative := 1;
      i := GDVars.initiativeIndex;
      p := GDVars.initiativeQueue[i + 1];
      while (p <> nil) and
          ((p^.combatAddr^.initiative > caster^.combatAddr^.initiative) or
           ((p^.combatAddr^.initiative = caster^.combatAddr^.initiative) and (FxEngine.RollDice(1, 2) = 1))) do begin
        GDVars.initiativeQueue[i] := p;
        Inc(i);
        p := GDVars.initiativeQueue[i + 1];
      end;
      GDVars.initiativeQueue[i] := caster;
      Dec(GDVars.initiativeIndex);
      outcome := True;
    end;
  end;
end;

{ Tells whether an attacker can backstab a defender: the attacker is a thief, unarmed or with one of the backstab weapon
  types, and the defender is flanked, adjacent, no larger than one cell, and facing the way the attack comes from. Note:
  the attacker's armor is fetched but not checked.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @returns(True for a backstab.) }
function IsBackstab(attacker, defender: Pointer): Boolean;
var
  weapon: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  armor: Types.PItemRec;
  weaponType: Byte;
  canBackstab: Boolean;
begin
  canBackstab := False;
  weapon := Types.PCharRecord(attacker)^.equipped[C_Equip.WEAPON];
  if weapon <> nil then
    weaponType := weapon^.definition.itemType;
  armor := Types.PCharRecord(attacker)^.equipped[C_Equip.ARMOR];
  if ClassCal.EffectiveClassLevel(Types.PCharRecord(attacker), C_Class.THIEF) > 0 then
    if (weapon = nil) or (weaponType in [3, 4, 17, 18, 19, 63, 67]) then
      canBackstab := True;
  if canBackstab and (Types.PCharRecord(defender)^.combatAddr^.flankCount > 1)
           and (CharHlp.CalcDistance(attacker, defender) < 2)
           and (Types.PCharRecord(defender)^.iconDimensions and $7F <= 1)
           and (CharHlp.DirTowardTarget(attacker, defender) = Types.PCharRecord(defender)^.combatAddr^.direction) then
    IsBackstab := True
  else
    IsBackstab := False;
end;

{ Flies a weapon's missile from the attacker to the defender, with the icon, frame count, pace and sound chosen by the
  weapon's item type.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @param(weapon The weapon.) }
procedure AnimateMissile(attacker, defender, weapon: Pointer);
var
  frames: Byte;
  direction: Byte;
  pace: Byte;
begin
  direction := CharHlp.DirTowardTarget(attacker, defender);
  frames := 1;
  pace := 10;
  case Types.PItemRec(weapon)^.definition.itemType of
    5, 7, 12, 30, 66, 74, 4:
      begin
        CharHlp.BuildIconFacingsDir(direction, 13);
        Music.SendSoundCommand(GDConsts.soundIds[12]);
      end;
    2, 3, 6:
      begin
        CharHlp.BuildIconFacings(16);
        frames := 4;
        pace := 50;
        Music.SendSoundCommand(GDConsts.soundIds[9]);
      end;
    28, 29, 67:
      begin
        CharHlp.CopyIconFacing(20, 0, 0, False);
        CharHlp.CopyIconFacing(20, 1, 1, False);
        frames := 2;
        pace := 10;
        Music.SendSoundCommand(GDConsts.soundIds[9]);
      end;
  else begin
      CharHlp.CopyIconFacing(19, 0, 0, False);
      CharHlp.CopyIconFacing(19, 1, 1, False);
      frames := 2;
      pace := 20;
      Music.SendSoundCommand(GDConsts.soundIds[9]);
    end;
  end;
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(attacker)),
                                  CbtMap.CombatCellY(Types.PCharRecord(attacker)),
                                  CbtMap.CombatCellX(Types.PCharRecord(defender)),
                                  CbtMap.CombatCellY(Types.PCharRecord(defender)), frames, pace);
end;

procedure UpdateHostileHpPercent;
var
  maximumTotal: Word;
  hitPointTotal: Word;
  combatant: Types.PCharRecord;
begin
  maximumTotal := 0;
  hitPointTotal := 0;
  combatant := GDVars.creatureListHead;
  while combatant <> nil do begin
    if combatant^.side = 1 then
      if combatant^.status <> 9 then begin
        if combatant^.inPlay <> 0 then
          hitPointTotal := hitPointTotal + combatant^.hpCur;
        maximumTotal := maximumTotal + combatant^.hpMax;
      end;
    combatant := combatant^.next;
  end;
  if maximumTotal > 0 then
    GDVars.hostileHpPercent := hitPointTotal * 20 div maximumTotal * 5;
end;

function HighestEnemyMovement(creature: Pointer): Byte;
var
  { the highest so far }
  highest: Byte;
  { this enemy's half movement }
  movement: Byte;
  combatant: Types.PCharRecord;
begin
  highest := 0;
  combatant := GDVars.creatureListHead;
  while combatant <> nil do begin
    if (CharHlp.EnemyTeam(creature) = combatant^.side) and (combatant^.inPlay <> 0) then begin
      movement := CharHlp.RecalcMovement(combatant) div 2;
      if movement > highest then
        highest := movement;
    end;
    combatant := combatant^.next;
  end;
  HighestEnemyMovement := highest;
end;

function CheckAttackAlly(attacker, defender: Pointer): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  combatant: Types.PCharRecord;
begin
  if (CharHlp.EnemyTeam(defender) = Types.PCharRecord(attacker)^.side) or
      (Types.PCharRecord(attacker)^.quickfight <> 0) then
    CheckAttackAlly := True
  else if MenuCore.YesNoMenu(GDConsts.attackAllyPrompt, GDConsts.noChoice) <> GDConsts.yesChoice then
    CheckAttackAlly := False
  else begin
    CheckAttackAlly := True;
    GDVars.sharedScratch.allyAttackConfirmed := 1;
    GDVars.vmBand.zone0^.alliesAttacked := 1;
  end;
end;

{ Shows the aim menu for the creature or cell under aim and returns the player's choice. The menu text is fixed ("Next
  Prev Manual Target Center Exit"), with the words that apply enabled. Target is offered only when the point under aim
  is within range and the current aim is valid, and then: for a spell, when creatures are allowed and there is a
  creature, or empty cells are allowed and there is none; for an attack, when the attacker is not aiming at itself and
  either has no missile weapon, or has ammunition and is not engaged in melee or can throw its weapon. The distance to
  the point is shown for attacks.
  @param(cur The combatant aiming.)
  @param(tgt The creature under aim, or nil.)
  @param(range The range.)
  @param(weaponMode 1 for an attack, 0 for a spell.)
  @param(flagC Nonzero allows Target on an empty cell, for a spell.)
  @param(flagB Nonzero allows Target on a creature, for a spell.)
  @param(flagA Nonzero when the current aim is valid.)
  @param(outB The column of the point under aim.)
  @param(outA Its row.)
  @returns(The player's choice.) }
function AimTargetMenu(cur, tgt: Pointer; range, weaponMode, flagC, flagB, flagA: Byte; outB, outA: ShortInt): Char;
var
  i: Byte;
  count: Byte;
  weapon: Pointer;
  dist: Word;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
  savedNoHeight: Byte;
begin
  dist := $FF;
  savedNoHeight := GDVars.arenaPtr^.noHeight;
  GDVars.arenaPtr^.noHeight := 1;
  found := Pathing.WalkLine(CbtMap.CombatCellX(Types.PCharRecord(cur)), CbtMap.CombatCellY(Types.PCharRecord(cur)),
                            outB, outA, dist);
  GDVars.arenaPtr^.noHeight := savedNoHeight;
  dist := dist div 2;
  if weaponMode <> 0 then
    TextRend.DisplayString(0, 23, LightGreen, 0, GDConsts.rangePrompt + CharHlp.Uint16Str(dist) + '  ');
  FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
  count := 0;
  for i := 0 to 5 do
    if i = 3 then begin
      if (range >= dist) and (flagA <> 0) then
        if weaponMode = 0 then begin
          if ((flagB <> 0) and (tgt <> nil)) or ((flagC <> 0) and (tgt = nil)) then
            MenuCore.AppendSlot(3, count);
        end else if cur <> tgt then begin
          if not CharHlp.HasRangedWeapon(cur) then
            MenuCore.AppendSlot(3, count)
          else if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
            if (CharHlp.CountTargets(cur, 1, False) = 0) or CharHlp.HasThrowableWeapon(cur) then
              MenuCore.AppendSlot(3, count);
        end;
    end else
      MenuCore.AppendSlot(i, count);
  if tgt <> nil then begin
    CbtMap.DisplayMapViewCentered(Types.PCharRecord(tgt), 3, True);
    GDVars.infoPanelDirty := 1;
    CharHlp.CombatPrintCreatureInfo(tgt);
  end;
  AimTargetMenu := MenuCore.MenuHorizontal(GDConsts.aimPrompt, GDConsts.aimMenu, True, False);
end;

{ Confirms the target and records it. For an attack (weapon mode 1) an ally is only attacked after confirmation, and the
  attack is then carried out; a throwable weapon at point-blank range is used in melee rather than thrown. When the
  target is refused, the selection is cleared and the done flag is False.
  @param(cur The combatant aiming.)
  @param(tgt The target.)
  @param(weaponMode 1 for an attack, 0 for a spell.)
  @param(done Receives True when the target was accepted.)
  @param(sel Receives the target.) }
procedure ConfirmAttackTarget(cur, tgt: Pointer; weaponMode: Byte; var done: Boolean; var sel);
var
  { Unused in this version; see the other implementations of this routine. }
  targetDir: Byte;
  weapon: Pointer;
begin
  weapon := nil;
  done := True;
  if weaponMode = 1 then
    if not CbtActs.CheckAttackAlly(cur, tgt) then
      done := False;
  if done then begin
    TAimTarget(sel).cr := tgt;
    TAimTarget(sel).x := CbtMap.CombatCellX(Types.PCharRecord(tgt));
    TAimTarget(sel).y := CbtMap.CombatCellY(Types.PCharRecord(tgt));
    GDVars.arenaPtr^.cursorOn := False;
    CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 3, C_Dir.CENTER);
    if weaponMode = 1 then begin
      CbtActs.NoteAttackDirection(cur, tgt);
      if CharHlp.HasRangedWeapon(cur) then
        if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
          if CharHlp.HasThrowableWeapon(cur) then
            if CharHlp.CalcDistance(cur, tgt) = 1 then
              weapon := nil;
      CbtActs.MakeAttack(cur, tgt, False, weapon, done);
    end;
  end else
    GameIo.ZeroFill(sel, SizeOf(TAimTarget));
end;

{ Runs the manual aim cursor. Starting at the given cell, the player moves a cursor over the arena with the keypad; for
  each cell it shows the creature or corpse there and the range, and marks the cell valid when it is within range and
  line of sight, not impassable, and holds a creature the aimer may target (or is open ground, when ground is allowed).
  With the creature flag 0 a creature is an invalid target. For an attack the aimer itself, a corpse, and creatures out
  of reach of its weapon are invalid too. Target (or the confirm key) returns the cell and creature with the done flag
  set; Exit or Escape returns the starting cell with it clear. Space recenters the view.
  @param(cur The combatant aiming.)
  @param(underCursor Overwritten: holds the creature under the cursor.)
  @param(range The range.)
  @param(weaponMode 1 for an attack, 0 for a spell.)
  @param(ground Nonzero allows open ground.)
  @param(flagD 0 makes a creature an invalid target.)
  @param(valid Receives whether the cell under the cursor is a valid target.)
  @param(done Receives True when a target was chosen.)
  @param(sel Receives the target.)
  @param(cellX The starting column.)
  @param(cellY The starting row.) }
procedure ManualAimCursor(cur, underCursor: Pointer; range, weaponMode, ground, flagD: Byte; var valid, done: Boolean;
                          var sel; cellX, cellY: ShortInt);
var
  count: Byte;
  ch: Char;
  weapon: Pointer;
  dir: Byte;
  j: Byte;
  wx: ShortInt;
  wy: ShortInt;
  crIdx: Byte;
  terrIdx: Byte;
  { where the cursor started, returned on cancel }
  startX: ShortInt;
  startY: ShortInt;
  dist: Word;
begin
  GDVars.aimCursorOn := 1;
  startX := cellX;
  startY := cellY;
  GDVars.aimCursorX := cellX;
  GDVars.aimCursorY := cellY;
  GameIo.ZeroFill(sel, SizeOf(TAimTarget));
  GDVars.arenaPtr^.cursorOn := True;
  GDVars.arenaPtr^.cursorSize := 1;
  ch := #255;
  dir := C_Dir.CENTER;
  GDVars.scratchFlag := False;
  while ch > #1 do begin
    CbtMap.ScrollView(GDVars.aimCursorX, GDVars.aimCursorY, 2, dir);
    Inc(GDVars.aimCursorX, GDConsts.dirDeltaX[dir]);
    Inc(GDVars.aimCursorY, GDConsts.dirDeltaY[dir]);
    if GDVars.aimCursorX < 0 then
      GDVars.aimCursorX := 0;
    if GDVars.aimCursorY < 0 then
      GDVars.aimCursorY := 0;
    if GDVars.aimCursorX > 49 then
      GDVars.aimCursorX := 49;
    if GDVars.aimCursorY > 24 then
      GDVars.aimCursorY := 24;
    CbtMap.GetArenaContents(GDVars.aimCursorX, GDVars.aimCursorY, crIdx, terrIdx);
    GameIo.FlushKeys;
    valid := False;
    dist := 255;
    wx := GDVars.aimCursorX;
    wy := GDVars.aimCursorY;
    if Pathing.WalkLine(CbtMap.CombatCellX(Types.PCharRecord(cur)), CbtMap.CombatCellY(Types.PCharRecord(cur)), wx, wy,
                        dist) then begin
      valid := True;
      if weaponMode <> 0 then
        TextRend.DisplayString(0, 23, LightGreen, 0, GDConsts.rangePrompt + CharHlp.Uint16Str(dist div 2) + '  ');
    end else if weaponMode <> 0 then
      Border.ClearBox(0, 23, 39, 23);
    dist := dist div 2;
    underCursor := nil;
    if valid then begin
      if crIdx > 0 then
        underCursor := GDVars.slotCreatures[crIdx]
      { a corpse }
      else if terrIdx = C_Terr.TERRAIN_CORPSE then
        for j := 1 to GDVars.downedListCount do
          if GDVars.downedList[j].x = GDVars.aimCursorX then
            if GDVars.downedList[j].y = GDVars.aimCursorY then
              underCursor := GDVars.downedList[j].cr;
    end;
    if underCursor <> nil then begin
      GDVars.infoPanelDirty := 1;
      CharHlp.CombatPrintCreatureInfo(underCursor);
    end else
      Border.ClearBox(23, 1, 38, 21);
    if (range < dist) or (GDConsts.terrainTable[terrIdx].cost = C_Terr.TERRAIN_IMPASSABLE) then
      valid := False;
    if underCursor <> nil then begin
      if (not CbtActs.CanTarget(cur, underCursor, 1)) or (flagD = 0) then
        valid := False;
      if weaponMode = 1 then
        if (cur = underCursor) or ((crIdx = 0) and (terrIdx = C_Terr.TERRAIN_CORPSE)) then
          valid := False
        else if CharHlp.HasRangedWeapon(cur) then
          if (not CharHlp.FindDamagingRangedWeapon(cur, weapon)) or
              ((CharHlp.CountTargets(cur, 1, False) > 0) and (not CharHlp.HasThrowableWeapon(cur))) then
            valid := False;
    end else if ground = 0 then
      valid := False;
    FillChar(GDVars.menuSlotTable, SizeOf(GDVars.menuSlotTable), $FF);
    count := 0;
    if valid then
      MenuCore.AppendSlot(0, count)
    else
      MenuCore.AppendSlot(1, count);
    ch := MenuCore.MenuHorizontal(GDConsts.useCursorKeysPrompt, GDConsts.targetExitMenu, True, False);
    if GDVars.extendedKeyFlag then
      case ch of
        C_Keys.UP: dir := C_Dir.NORTH;
        C_Keys.PAGE_UP: dir := C_Dir.NORTHEAST;
        C_Keys.RIGHT: dir := C_Dir.EAST;
        C_Keys.PAGE_DOWN: dir := C_Dir.SOUTHEAST;
        C_Keys.DOWN: dir := C_Dir.SOUTH;
        C_Keys.END_KEY: dir := C_Dir.SOUTHWEST;
        C_Keys.LEFT: dir := C_Dir.WEST;
        C_Keys.HOME: dir := C_Dir.NORTHWEST;
        ' ':
          begin
            CbtMap.ScrollView(GDVars.aimCursorX, GDVars.aimCursorY, 0, C_Dir.CENTER);
            dir := C_Dir.CENTER;
          end;
        C_Keys.ESCAPE:
          begin
            done := False;
            CbtMap.RedrawArenaCell(GDVars.aimCursorX, GDVars.aimCursorY);
            GameIo.ZeroFill(sel, SizeOf(TAimTarget));
            TAimTarget(sel).x := startX;
            TAimTarget(sel).y := startY;
            CbtMap.ScrollView(startX, startY, 0, C_Dir.CENTER);
            GDVars.arenaPtr^.cursorOn := False;
            CbtMap.RedrawArenaCell(startX, startY);
            GDVars.scratchFlag := False;
            ch := #1;
          end;
      else
        dir := C_Dir.CENTER;
      end else
      case ch of
        #0:
          begin
            done := True;
            TAimTarget(sel).x := GDVars.aimCursorX;
            TAimTarget(sel).y := GDVars.aimCursorY;
            if underCursor <> nil then
              TAimTarget(sel).cr := underCursor
            else
              TAimTarget(sel).cr := nil;
            GDVars.arenaPtr^.cursorOn := False;
            CbtMap.RedrawArenaCell(GDVars.aimCursorX, GDVars.aimCursorY);
            GDVars.scratchFlag := False;
          end;
        #1:
          begin
            done := False;
            CbtMap.RedrawArenaCell(GDVars.aimCursorX, GDVars.aimCursorY);
            GameIo.ZeroFill(sel, SizeOf(TAimTarget));
            TAimTarget(sel).x := startX;
            TAimTarget(sel).y := startY;
            CbtMap.ScrollView(startX, startY, 0, C_Dir.CENTER);
            GDVars.arenaPtr^.cursorOn := False;
            CbtMap.RedrawArenaCell(startX, startY);
            GDVars.scratchFlag := False;
          end;
      else
        dir := C_Dir.CENTER;
      end;
  end;
  GDVars.aimCursorOn := 0;
end;

procedure CombatAimMenu(cr: Pointer; range, weaponMode, groundOk, extra: Byte; var done: Boolean; var tgt);
var
  { the creatures that may be targeted, in rank order }
  targets: array[1..72] of Types.TApproachResult;
  { the range actually used }
  effRange: Byte;
  { entries in targets }
  tgtCount: Byte;
  { the current entry of targets }
  curIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  skipStep: Byte;
  { the aim's cell before a step }
  curX: ShortInt;
  curY: ShortInt;
  { the aim's cell after a step }
  nextX: ShortInt;
  nextY: ShortInt;
  { the creature under aim }
  p: Pointer;

  { the menu choice, or the raw key }
  ch: Char;
  { the current aim is valid; kept from one pass of the loop to the next }
  valid: Boolean;
  { the aim cursor confirmed its target }
  manualDone: Boolean;
  exitLoop: Boolean;
  { the cell under aim }
  cx: ShortInt;
  cy: ShortInt;
  { cr's own cell, to return to on Esc }
  casterX: ShortInt;
  casterY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  menuResult: Word;

  { Steps the aim through the targets, wrapping, and returns the creature now under aim. }
  function AdvanceAimTarget(step: ShortInt): Pointer;
  var
    old: Pointer;
    fresh: Pointer;
  begin
    old := GDVars.slotCreatures[targets[curIdx].ent];
    if old = nil then
      old := cr;
    if tgtCount < 1 then
      GameIo.ExitGame(0);
    curX := GDVars.arenaSlots[targets[curIdx].ent].x;
    curY := GDVars.arenaSlots[targets[curIdx].ent].y;
    Inc(curIdx, step);
    if curIdx = 0 then
      curIdx := tgtCount;
    if curIdx > tgtCount then
      curIdx := 1;
    fresh := GDVars.slotCreatures[targets[curIdx].ent];
    nextX := GDVars.arenaSlots[targets[curIdx].ent].x;
    nextY := GDVars.arenaSlots[targets[curIdx].ent].y;
    if (fresh = nil) or (nextX < 0) or (nextY < 0) then begin
      AdvanceAimTarget := old;
      nextX := curX;
      nextY := curY;
    end else begin
      AdvanceAimTarget := fresh;
      CharHlp.CombatAnimateMovingIcon(curX, curY, nextX, nextY, 1, 0);
      curX := nextX;
      curY := nextY;
    end;
  end;

  { Builds the targets cr may attack, in rank order, keeping cr's current target selected. }
  procedure BuildAimTargets;
  var
    i: Byte;
    other: Pointer;
  begin
    curIdx := 1;
    Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)), 255,
                            255, CbtMap.GetIconSize(Types.PCharRecord(cr)));
    tgtCount := 0;
    for i := 1 to GDVars.rankedTargetCount do begin
      other := GDVars.slotCreatures[GDVars.rankedTargets[i].ent];
      if CbtActs.CanTarget(cr, other, 0) then begin
        Inc(tgtCount);
        targets[tgtCount] := GDVars.rankedTargets[i];
        if other = Types.PCharRecord(cr)^.combatAddr^.other then
          curIdx := tgtCount;
      end;
    end;
    p := AdvanceAimTarget(0);
    if p <> cr then begin
      GDVars.menuResetByte := $FF;
      GDVars.horizMenuChoice := 4;
    end;
  end;

begin
  GDVars.horizMenuChoice := 1;
  CharHlp.CopyIconFacing(28, 0, 0, False);
  GameIo.ZeroFill(tgt, SizeOf(TAimTarget));
  done := False;
  effRange := range;
  if effRange = 255 then
    if Types.PCharRecord(cr)^.equipped[C_Equip.WEAPON] <> nil then
      effRange := GDVars.baseItemTable[Types.PCharRecord(cr)^.equipped[C_Equip.WEAPON]^.definition.itemType].range
    else
      effRange := 1;
  if (effRange = 0) or (effRange = 255) then
    effRange := 1;
  casterX := CbtMap.CombatCellX(Types.PCharRecord(cr));
  casterY := CbtMap.CombatCellY(Types.PCharRecord(cr));
  CbtMap.RedrawArenaCell(casterX, casterY);
  BuildAimTargets;
  cx := CbtMap.CombatCellX(Types.PCharRecord(p));
  cy := CbtMap.CombatCellY(Types.PCharRecord(p));
  valid := True;
  exitLoop := False;
  while not exitLoop do begin
    ch := CbtActs.AimTargetMenu(cr, p, effRange, weaponMode, groundOk, extra, Byte(valid), cx, cy);
    if not GDVars.extendedKeyFlag then begin
      case ch of
        #0:
          begin
            valid := True;
            p := AdvanceAimTarget(1);
          end;
        #1:
          begin
            valid := True;
            p := AdvanceAimTarget(-1);
          end;
        #2:
          begin
            CbtActs.ManualAimCursor(cr, p, effRange, weaponMode, groundOk, extra, valid, manualDone, tgt, cx, cy);
            p := TAimTarget(tgt).cr;
            cx := TAimTarget(tgt).x;
            cy := TAimTarget(tgt).y;
            if valid and manualDone then begin
              ch := #3;
              exitLoop := True;
              GDVars.horizMenuChoice := 4;
              if p <> nil then
                TAimTarget(tgt).cr := p
              else
                TAimTarget(tgt).cr := nil;
              done := True;
              if weaponMode = 1 then
                CbtActs.ConfirmAttackTarget(cr, p, weaponMode, done, tgt);
              if not done then begin
                GDVars.arenaPtr^.cursorOn := False;
                CbtMap.ScrollView(cx, cy, 0, C_Dir.CENTER);
              end;
            end else begin
              if (cr <> nil) and (not manualDone) then begin
                GDVars.infoPanelDirty := 1;
                CharHlp.CombatPrintCreatureInfo(cr);
              end;
              GDVars.horizMenuChoice := 3;
            end;
          end;
        #3:
          begin
            TAimTarget(tgt).x := cx;
            TAimTarget(tgt).y := cy;
            if p <> nil then
              TAimTarget(tgt).cr := p
            else
              TAimTarget(tgt).cr := nil;
            done := True;
            if weaponMode = 1 then
              CbtActs.ConfirmAttackTarget(cr, p, weaponMode, done, tgt);
            if not done then begin
              GDVars.arenaPtr^.cursorOn := False;
              CbtMap.ScrollView(cx, cy, 0, C_Dir.CENTER);
            end;
            exitLoop := True;
          end;
        #4:
          begin
            GDVars.arenaPtr^.cursorOn := True;
            GDVars.arenaPtr^.cursorSize := 1;
            CbtMap.ScrollView(cx, cy, 0, C_Dir.CENTER);
            GDVars.arenaPtr^.cursorOn := False;
          end;
        #5:
          begin
            GDVars.arenaPtr^.cursorOn := False;
            CbtMap.ScrollView(cx, cy, 0, C_Dir.CENTER);
            exitLoop := True;
          end;
      end;
    end else begin
      if ch = C_Keys.ESCAPE then begin
        GDVars.arenaPtr^.cursorOn := False;
        CbtMap.RedrawArenaCell(cx, cy);
        CbtMap.ScrollView(casterX, casterY, 0, C_Dir.CENTER);
        ch := #5;
        exitLoop := True;
      end;
    end;
    if ch in [#0, #1, #3] then
      if p <> nil then begin
        cx := CbtMap.CombatCellX(Types.PCharRecord(p));
        cy := CbtMap.CombatCellY(Types.PCharRecord(p));
      end;
  end;
  if weaponMode <> 0 then
    Border.ClearBox(0, 23, 39, 23);
end;

function AcquireTarget(cr: Pointer; range, relaxed, forceNew, extra: Byte): Boolean;
var
  cnt: Byte;
  tries: Byte;
  pick: Byte;
  second: Boolean;
  found: Boolean;
  pass: Boolean;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  retryPass: Byte;
begin
  effect := nil;
  pass := False;
  found := False;
  second := False;
  p := Types.PCharRecord(cr)^.combatAddr^.other;
  if (forceNew <> 0) or
      ((p <> nil) and
       ((p^.side = Types.PCharRecord(cr)^.side) or (p^.inPlay = 0) or (not CbtActs.CanTarget(cr, p, extra)))) then
    Types.PCharRecord(cr)^.combatAddr^.other := nil;
  if Types.PCharRecord(cr)^.combatAddr^.other <> nil then
    found := True;
  while (not found) and (not second) do begin
    second := pass;
    if pass and (forceNew = 0) then
      GDVars.arenaPtr^.noHeight := 1;
    cnt := CharHlp.CountTargets(cr, range, Boolean(extra));
    if cnt > 0 then
      pick := FxEngine.RollDice(1, cnt);
    tries := cnt;
    while (tries > 0) and (not found) and (cnt > 0) do begin
      Dec(tries);
      if GDVars.potentialTargets[pick] > 0 then begin
        p := GDVars.slotCreatures[GDVars.potentialTargets[pick]];
        if ((relaxed <> 0) and (GDVars.arenaPtr^.noHeight <> 0)) or CbtActs.CanTarget(cr, p, extra) then begin
          found := True;
          Types.PCharRecord(cr)^.combatAddr^.other := p;
        end else begin
          GDVars.potentialTargets[pick] := 0;
          for pick := 1 to cnt do
            if GDVars.potentialTargets[pick] > 0 then
              found := True;
          if found then
            found := False
          else
            cnt := 0;
        end;
      end;
      if not found then begin
        Inc(pick);
        if pick > cnt then
          pick := 1;
      end;
    end;
    if not pass then
      pass := True;
  end;
  GDVars.arenaPtr^.noHeight := 0;
  AcquireTarget := found;
end;

function VictoryCheat: Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  p: Types.PCharRecord;
begin
  VictoryCheat := False;
  if ParamStr(3) <> 'Helm' then
    Exit;
  VictoryCheat := True;
  CharHlp.PrintBottomLine('The Gods intervene!');
  p := GDVars.creatureListHead;
  while p <> nil do begin
    if p^.side = 1 then begin
      p^.inPlay := 0;
      p^.status := C_Status.DEAD_STATUS;
      GDVars.arenaSlots[CbtMap.CombatSlot(Types.PCharRecord(p))].sizeCode := 0;
    end;
    done := CharHlp.EndActions(p);
    p := p^.next;
  end;
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 255, C_Dir.CENTER);
end;

{ Judges whether target is worth casting spell on, for the computer: -10 when target is not on `side`, otherwise 1 when
  the spell would do something useful to it and 0 when not. Most spells are judged by the effect they apply; the special
  cases are listed by spell number. A spell of level 3 or less against a minor globe of invulnerability, of level 4 or
  less against a globe of invulnerability, or any spell against a creature with more than 50% spell resistance, is never
  worth it.
  @param(target The creature.)
  @param(spell The spell.)
  @param(side The side the spell is meant for.)
  @returns(-10, 0 or 1.) }
function RateSpellTarget(target: Pointer; spell: Byte; side: ShortInt): ShortInt;
var
  eligible: Boolean;
  { HasEffect's out-parameter, not used }
  effectNode: Pointer;
  { the spell's level }
  levelVal: Byte;
  { the spell's effect }
  effectVal: Byte;
begin
  RateSpellTarget := 0;
  if Types.PCharRecord(target)^.side <> side then begin
    RateSpellTarget := -10;
    Exit;
  end;
  eligible := False;
  effectVal := GDConsts.spellTable[spell].effect;
  case spell of
    1: if (not CharHlp.HasEffect(target, C_Effect.BLESS, effectNode)) and
      (CharHlp.CountTargets(target, 1, False) = 0) then eligible := True;
    42: if not CharHlp.HasEffect(GDVars.currentChar, C_Effect.PRAYER, effectNode) then eligible := True;
    3, 58, 71, 36:
      if Byte(Types.PCharRecord(target)^.hpMax > Types.PCharRecord(target)^.hpCur) <> 0 then
        eligible := True;
    96: if Byte((Types.PCharRecord(target)^.race < C_Race.MONSTER) or
                 ((Types.PCharRecord(target)^.creatureType and 2) <> 0)) <> 0 then eligible := True;
    10: if ((Types.PCharRecord(target)^.immunities and 2) <> 0) and
      (Byte(Types.PCharRecord(target)^.iconDimensions = 1) <> 0) then eligible := True;
    65, 15: if not CharHlp.HasEffect(target, C_Effect.SHIELD, effectNode) then eligible := True;
    21: if (Byte(Types.PCharRecord(target)^.hitDice < 5) <> 0) and
      (not CharHlp.HasEffect(target, C_Effect.ASLEEP, effectNode)) then eligible := True;
    23, 49: if (Byte(Types.PCharRecord(target)^.race < C_Race.MONSTER) <> 0) and
      ((Types.PCharRecord(target)^.immunities and 2) <> 0) and
      (not CharHlp.HasEffect(target, C_Effect.HELD, effectNode)) then eligible := True;
    37: if CharHlp.HasEffect(target, C_Effect.BLIND, effectNode) then eligible := True;
    43: if CharHlp.HasEffect(target, C_Effect.BESTOW_CURSE, effectNode) then eligible := True;
    47, 64, 74, 115: if not CharHlp.HasEffect(target, C_Effect.IMMUNE_FIRE, effectNode) then eligible := True;
    51: if not CharHlp.HasEffect(target, C_Effect.IMMUNE_ELECTRICITY, effectNode) then eligible := True;
    76, 110: if (Types.PCharRecord(target)^.immunities and 8) = 0 then eligible := True;
    61: eligible := True;
    68: if (Types.PCharRecord(target)^.immunities and $10) = 0 then eligible := True;
    94, 120, 81: if (Types.PCharRecord(target)^.immunities and 2) <> 0 then eligible := True;
    82: eligible := True;
    84: if not CharHlp.HasEffect(target, C_Effect.IMMUNE_FEAR, effectNode) then eligible := True;
    91: if Types.PCharRecord(target)^.hitDice < 6 then eligible := True;
  else
    if effectVal = 0 then eligible := True
    else if Byte(not CharHlp.HasEffect(target, effectVal, effectNode)) <> 0 then
      eligible := True;
  end;
  levelVal := GDConsts.spellTable[spell].level;
  if ShortInt(eligible) > 0 then begin
    if (levelVal < 5) and
        CharHlp.HasEffect(target, C_Effect.GLOBE_OF_INVULNERABILITY, effectNode) then eligible := False;
    if (levelVal < 4) and CharHlp.HasEffect(target, C_Effect.MINOR_GLOBE, effectNode) then eligible := False;
    if Types.PCharRecord(target)^.spellResistance > 50 then eligible := False;
  end;
  RateSpellTarget := Byte(eligible);
end;

function RateSpell(cr: Pointer; spell: Byte): ShortInt;
var
  outcome: ShortInt;
  side: ShortInt;
  i: Byte;
  cnt: Byte;
  range: Byte;
  { Unused in this version; see the other implementations of this routine. }
  downIdx: Word;
begin
  RateSpell := 0;
  if GDConsts.spellTable[spell].offensive = 0 then
    side := Types.PCharRecord(cr)^.side
  else
    side := CharHlp.EnemyTeam(cr);
  if GDConsts.spellTable[spell].area = 0 then begin
    outcome := CbtActs.RateSpellTarget(cr, spell, side);
  end else begin
    range := Magic.CalcSpellRange(spell);
    Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)), range,
                            255, CbtMap.GetIconSize(Types.PCharRecord(cr)));
    cnt := GDVars.rankedTargetCount;
    i := 1;
    outcome := 0;
    if cnt > 0 then
    while (i <= cnt) and (outcome <= 0) do begin
      outcome := CbtActs.RateSpellTarget(GDVars.slotCreatures[GDVars.rankedTargets[i].ent], spell, side);
      Inc(i);
    end;
  end;
  RateSpell := outcome;
end;

{ Places the computer's area spell. Every creature near enough adds its RateSpellTarget score to each cell of a scoring
  grid, centered on the anchor (the caster, or its current target when the reach exceeds the grid), from which the
  spell's area would cover it. The best cell the caster can see is chosen, ties broken at random, and returned in tgt as
  a ground target.
  @param(spell The spell.)
  @param(tgt Receives the target, a TAimTarget.)
  @returns(True when a cell was chosen.) }
function AimAreaSpell(spell: Byte; var tgt): Boolean;
type
  { scores around the anchor cell }
  TAimGrid = array[-18..18, -18..18] of Byte;
  PAimGrid = ^TAimGrid;
var
  grid: PAimGrid;
  baseRange: Byte;
  effRange: Byte;
  extra: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedTarget: Pointer;
  cand: Types.PCharRecord;
  anchorX: ShortInt;
  anchorY: ShortInt;
  candX: ShortInt;
  candY: ShortInt;
  bestDx: ShortInt;
  bestDy: ShortInt;
  casterX: ShortInt;
  casterY: ShortInt;
  dx: ShortInt;
  dy: ShortInt;
  lowX: ShortInt;
  highX: ShortInt;
  lowY: ShortInt;
  highY: ShortInt;
  score: ShortInt;
  bestScore: ShortInt;
  maxY: ShortInt;
  maxX: ShortInt;
  minY: ShortInt;
  minX: ShortInt;
  gridMaxY: ShortInt;
  gridMaxX: ShortInt;
  gridMinY: ShortInt;
  gridMinX: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  gridLow: Byte;
  dist: Word;
  { Unused in this version; see the other implementations of this routine. }
  cellScores: array[1..8] of Byte;
  side: ShortInt;
begin
  if GDConsts.spellTable[spell].offensive = 0 then
    side := GDVars.currentChar^.side
  else
    side := CharHlp.EnemyTeam(GDVars.currentChar);
  AimAreaSpell := False;
  baseRange := GDConsts.spellTable[spell].area - 8;
  if ((spell = 47) or (spell = 115)) and (GDVars.vmBand.zone0^.inDungeon = 0) then
    Dec(baseRange);
  cand := nil;
  effRange := baseRange + Magic.CalcSpellRange(spell);
  if effRange > 18 then begin
    effRange := 18;
    cand := GDVars.currentChar^.combatAddr^.other;
  end;
  extra := effRange - baseRange;
  if cand = nil then
    cand := GDVars.currentChar;
  anchorX := CbtMap.CombatCellX(Types.PCharRecord(cand));
  anchorY := CbtMap.CombatCellY(Types.PCharRecord(cand));
  if spell in [34, 101] then begin
    minX := anchorX - extra;
    minY := anchorY - extra;
  end else begin
    minX := anchorX - effRange;
    minY := anchorY - effRange;
  end;
  gridMinX := anchorX - extra;
  gridMinY := anchorY - extra;
  maxX := anchorX + effRange;
  maxY := anchorY + effRange;
  gridMaxX := anchorX + extra;
  gridMaxY := anchorY + extra;
  GetMem(grid, SizeOf(TAimGrid));
  GameIo.ZeroFill(grid^, SizeOf(TAimGrid));
  cand := GDVars.creatureListHead;
  while cand <> nil do begin
    candX := CbtMap.CombatCellX(Types.PCharRecord(cand));
    candY := CbtMap.CombatCellY(Types.PCharRecord(cand));
    if (cand^.inPlay <> 0) and (candX >= minX) and (candX <= maxX) and (candY >= minY) and (candY <= maxY) then begin
      score := CbtActs.RateSpellTarget(cand, spell, side);
      if spell in [34, 91] then
        lowY := 0
      else
        lowY := -baseRange;
      highY := baseRange;
      if lowY + candY < gridMinY then
        lowY := gridMinY - candY;
      if highY + candY > gridMaxY then
        highY := gridMaxY - candY;
      for dy := lowY to highY do begin
        if spell in [34, 91] then
          lowX := candX
        else
          lowX := candX - GDConsts.areaHalfWidth[dy, baseRange];
        highX := candX + GDConsts.areaHalfWidth[dy, baseRange];
        if lowX < gridMinX then lowX := gridMinX;
        if highX > gridMaxX then highX := gridMaxX;
        for dx := lowX to highX do
          Inc(grid^[dx - anchorX, dy + candY - anchorY], score);
      end;
    end;
    cand := cand^.next;
  end;
  casterX := CbtMap.CombatCellX(GDVars.currentChar);
  casterY := CbtMap.CombatCellY(GDVars.currentChar);
  bestScore := 0;
  for dx := -extra to extra do
    for dy := -extra to extra do begin
      score := grid^[dx, dy];
      if (score > bestScore) or ((score = bestScore) and (score > 0) and CharHlp.PercentileRoll(25)) then begin
        candX := casterX;
        candY := casterY;
        dist := Magic.CalcSpellRange(spell);
        if (anchorX + dx >= 0) and (anchorX + dx <= 49) and (anchorY + dy >= 0) and (anchorY + dy < 24) and
            Pathing.WalkLine(anchorX + dx, anchorY + dy, candX, candY, dist) then begin
          bestDx := dx;
          bestDy := dy;
          bestScore := score;
        end;
      end;
    end;
  TAimTarget(tgt).cr := nil;
  if bestScore > 0 then begin
    AimAreaSpell := True;
    TAimTarget(tgt).x := bestDx + anchorX;
    TAimTarget(tgt).y := bestDy + anchorY;
  end else begin
    AimAreaSpell := False;
    TAimTarget(tgt).cr := nil;
  end;
  FreeMem(grid, SizeOf(TAimGrid));
end;

procedure UseLeadership;
var
  { the paladin }
  att: Types.PCharRecord;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  shown: array[1..4] of Byte;

  { The paladin's chance roll, by paladin level and charisma, against d100. }
  function LeadershipRoll(cr: Types.PCharRecord): Boolean;
  var
    { the charisma bonus }
    charismaTerm: Byte;
    { the paladin-level chance }
    tier: Byte;
  begin
    case ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.PALADIN) of
      0: tier := 0;
      1: tier := 20;
      2: tier := 40;
    else
      tier := 80;
    end;
    if cr^.stats[C_Stat.CHARISMA].cur > 13 then
      charismaTerm := (cr^.stats[C_Stat.CHARISMA].cur - 13) * 5
    else
      charismaTerm := 0;
    if (tier + charismaTerm) > FxEngine.RollDice(1, 100) then
      LeadershipRoll := True
    else
      LeadershipRoll := False;
  end;

begin
  p := GDVars.creatureListHead;
  while p <> nil do begin
    if p^.side = 0 then
      p^.quickfight := Byte(p^.npc > $7F)
    else
      p^.quickfight := 1;
    p := p^.next;
  end;
  att := GDVars.creatureListHead;
  while att <> nil do begin
    if (att^.side = 0) and (att^.npc <= $7F) and
        (ClassCal.EffectiveClassLevel(Types.PCharRecord(att), C_Class.PALADIN) > 0) and
        (att^.status = C_Status.OKAY) then begin
      p := GDVars.creatureListHead;
      while p <> nil do begin
        if (p^.side = 0) and (p^.npc > $7F) and (p^.quickfight <> 0) and (p^.status = C_Status.OKAY) and
            (p^.stats[C_Stat.INTELLIGENCE].cur > 3) then
          if LeadershipRoll(att) then
            p^.quickfight := 0;
        p := p^.next;
      end;
    end;
    att := att^.next;
  end;
end;

procedure AttackEyeRays(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { eyes left this round }
  eyeBudget: Byte;
  { the distance to the target }
  rollResult: Word;
  { one bit per eye already used }
  flags: Byte;
  { cleared when the line of sight to the target is blocked }
  losOk: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  saved: Byte;
  { the current target }
  target: Pointer;

  { Animates a ray icon from the Beholder to its target. }
  procedure RayBeam(cell: Byte);
  begin
    CharHlp.BuildIconFacings(cell);
    CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(cr)),
                                    CbtMap.CombatCellY(Types.PCharRecord(cr)),
                                    CbtMap.CombatCellX(Types.PCharRecord(target)),
                                    CbtMap.CombatCellY(Types.PCharRecord(target)), 1, 30);
  end;

  { Picks the Beholder's target (a new one with forceNew set) and checks the line of sight to it. }
  procedure LosTrace(forceNew: Byte);
  var
    tx: ShortInt;
    ty: ShortInt;
  begin
    losOk := True;
    if CbtActs.AcquireTarget(cr, $FF, 0, forceNew, 0) then begin
      tx := CbtMap.CombatCellX(Types.PCharRecord(cr^.combatAddr^.other));
      ty := CbtMap.CombatCellY(Types.PCharRecord(cr^.combatAddr^.other));
      if Pathing.WalkLine(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)), tx, ty,
                          rollResult) then
        losOk := False;
    end;
  end;

begin
  flags := 0;
  eyeBudget := 4;
  losOk := False;
  cr^.combatAddr^.other := nil;
  LosTrace(1);
  repeat
    { the rays are magical }
    GDVars.elementMask := 8;
    target := cr^.combatAddr^.other;
    rollResult := CharHlp.CalcDistance(cr, target);
    Dec(eyeBudget);
    if target <> nil then begin
      if (rollResult <= 2) and ((flags and 1) = 0) then begin
        flags := flags or 1;
        CharHlp.PrintCreatureMessage(cr, 'fires a disintegrate ray', 10, True);
        RayBeam(17);
        if not FxEngine.RollSavingThrow(target, 3, 0) then
          FxEngine.KillCreature(target, C_Status.GONE, 'is disintegrated');
        LosTrace(0);
      end else if (rollResult <= 3) and ((flags and 2) = 0) then begin
        flags := flags or 2;
        CharHlp.PrintCreatureMessage(cr, 'fires a flesh to stone ray', 10, True);
        RayBeam(17);
        if not FxEngine.RollSavingThrow(target, 1, 0) then
          FxEngine.KillCreature(target, C_Status.PETRIFIED, 'is Stoned');
        LosTrace(0);
      end else if (rollResult <= 4) and ((flags and 4) = 0) then begin
        GDVars.elementMask := $48;
        flags := flags or 4;
        CharHlp.PrintCreatureMessage(cr, 'fires a death ray', 10, True);
        RayBeam(17);
        if not FxEngine.RollSavingThrow(target, 0, 0) then
          FxEngine.KillCreature(target, C_Status.DEAD_STATUS, 'is killed');
        LosTrace(0);
      end else if (rollResult <= 5) and ((flags and 8) = 0) then begin
        flags := flags or 8;
        CharHlp.PrintCreatureMessage(cr, 'Causes Serious Wounds', 10, True);
        RayBeam(17);
        GDVars.spellBeingCast := 66;
        FxEngine.InflictNonWeaponDamage(target, FxEngine.RollDamageDice(2, 8) + 1, 0, False);
        LosTrace(0);
      end else if (flags and $10) = 0 then begin
        GDVars.spellBeingCast := 84;
        Magic.CastSpell(84, 1, 1, losOk);
        flags := flags or $10;
      end else if (flags and $20) = 0 then begin
        GDVars.spellBeingCast := 55;
        Magic.CastSpell(55, 1, 1, losOk);
        flags := flags or $20;
      end else if (flags and $40) = 0 then begin
        GDVars.spellBeingCast := 21;
        Magic.CastSpell(21, 1, 1, losOk);
        flags := flags or $40;
      end;
    end;
  until (eyeBudget <= 0) or (cr^.combatAddr^.other = nil);
end;

begin
end.
