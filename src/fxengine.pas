{ The spell and special-effect engine. Every creature carries a chain of effect records; this unit adds and removes
  them, fires their handlers when game events occur, and supplies the dice, attack and saving-throw rolls the effects
  are built on. It also applies non-weapon damage, kills, revives and heals creatures, recomputes stats that effects and
  magic items modify, and runs the terrain hazards (stinking cloud, cloudkill, blade barrier) and the expiry of the map
  patches that carry them. }
{$O+,F+}
unit FxEngine;

interface

uses Types, GDConsts, GDVars, Blit, TextRend, CharHlp, Pathing, CbtMap, C_Effect, C_Class, C_Race,
  C_Stat, C_Cond, C_Dir, C_Ifc, C_Item, C_Npc, C_Status, C_Terr;

{ Prints a message after a creature's name. Unless the creature is already stoned, dead or gone, it then gives it the
  status, takes it out of play at 0 hit points, removes its effects that end at 0 hit points, runs its condition-13
  (going down) effects, marks it downed on the combat map when those effects leave it out of play and it has not
  exploded, pauses, clears the message window and, outside combat, redraws the party.
  @param(cr Creature being killed.)
  @param(status Status to give it.)
  @param(msg Message printed after its name.) }
procedure KillCreature(cr: Pointer; status: Byte; msg: Types.TStr40);

{ Calls the handler for an effect. While the item-effect override flag is set, each call goes to handler 127 instead.
  Otherwise ids 127 and above are ignored.
  @param(effId The effect.)
  @param(cr The creature, passed on to the handler.)
  @param(p The effect record or item that owns the effect, passed on.)
  @param(removed True when the effect is being removed, passed on.) }
procedure CallEffectHandler(effId: Byte; var cr; p: Pointer; removed: Boolean);

{ Removes an effect from a creature. A record that asks to be told of its removal has its handler called first. Losing
  effect 14 recalculates charisma; losing effect 12 or 38 recalculates strength.
  @param(cr The creature, a Types.PCharRecord.)
  @param(id The effect.)
  @param(p The record to remove, or nil for the first record with that id.) }
procedure RemoveEffect(cr: Pointer; id: Byte; p: Pointer);

{ Fires on a creature every effect that reacts to a game event. COND_DAMAGE_TAKEN and C_Cond.EFFECT_ADDED first give
  magic resistance its chance; COND_DAMAGE_TAKEN finally drops damage the creature is immune to.
  @param(id The event.)
  @param(cr The creature.) }
procedure TriggerEffectsWithCondition(id: Byte; var cr);

{ Applies the hazard a creature in play stands in; the map scrolls to it first unless it is fully in view. Stinking
  cloud (unless `skipCloud`): undead, the helpless and creatures immune to it are spared; a save means coughing for
  1d4+1, and a creature casting a spell loses it and its turn ends; a failure means nausea (helpless) for 1d4+1.
  Cloudkill (unless immune): up to 4 hit dice dies, 5 saves at -4, 6 saves normally, more takes 1d10. Blade barrier:
  unless magic resistance clears the pending damage, knives for 8d8 (save type 4 when `allowSave`).
  @param(cr The creature.)
  @param(allowSave True grants a saving throw against the blade barrier.)
  @param(skipCloud True ignores a stinking cloud.) }
procedure ConsiderTerrainEffects(cr: Pointer; allowSave, skipCloud: Boolean);

{ Rolls to hit a creature when no creature is attacking, as with traps and hazards. A natural 1 misses; a natural 20
  counts as 100. The beheading flag is left set only for a hit on a natural 17 or better.
  @param(defender The creature attacked.)
  @param(sixtyMinusThac0 Added to the roll.)
  @returns(True when the roll plus the to-hit value exceeds the defender's armor class value.) }
function AttackRollNoAttacker(defender: Pointer; sixtyMinusThac0: Byte): Boolean;

{ Rolls to hit for an attacker against a defender. Attacking breaks invisibility; event 10 fires on the attacker and 16
  on the defender. The party's to-hit modifier is shifted by difficulty (+2 at level 1 down to -2 at level 5); monsters
  use their own fixed modifier. The beheading flag is left set only for a hit on a natural 17 or better.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @param(sixtyMinusAc The roll needed.)
  @returns(True when the roll plus the attacker's THAC0 adjustment and the modifier reaches the roll needed.) }
function AttackRoll(attacker, defender: Pointer; sixtyMinusAc: Byte): Boolean;

{ Rolls a saving throw for a creature. A natural 1 fails and a natural 20 saves; effect 118 makes each save fail.
  Otherwise the roll, plus the creature's save bonus and the modifier, must reach its save value; condition 12 lets
  effects adjust the roll first. The modified roll and the result are kept for later checks.
  @param(cr The creature.)
  @param(saveType The saving throw.)
  @param(modifier The modifier added to the roll.)
  @returns(True, or 1, when the creature saved.) }
function RollSavingThrow(cr: Pointer; saveType, modifier: ShortInt): Boolean;

{ Rolls a number of dice and adds them up.
  @param(n Number of dice; 0 rolls nothing.)
  @param(sides Faces per die.)
  @returns(The sum, kept in a Byte, so a total above 255 wraps.) }
function RollDice(n, sides: Byte): Byte;

{ Rolls damage dice, recording the number of dice for the resistances.
  @param(n Number of dice.)
  @param(sides Faces per die.)
  @returns(The sum, as RollDice returns it.) }
function RollDamageDice(n, sides: Byte): Word;

{ Adds an effect node to the end of a creature's effect list. It neither checks for a node already there nor calls the
  effect's handler.
  @param(cr The creature.)
  @param(effId The effect.)
  @param(minutes Its duration in minutes; 0 for a permanent effect.)
  @param(strength Its strength.)
  @param(onRemove True to call the effect's handler when it is removed.) }
procedure AddEffect(cr: Pointer; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);

{ Takes an enabled creature out of play: centers the map on it, prints a message after its name, disables it and sets
  its status. Its hit points drop to 0 unless it fled (running). Its icon is erased from the combat map and taken off
  the arena, and when its actions end the effects that end at 0 hit points are removed.
  @param(cr The creature.)
  @param(status Its new status.)
  @param(msg The message.) }
procedure PutOutOfPlayWithStatus(cr: Pointer; status: Byte; msg: Types.TStr40);

{ Removes each invisibility effect from a creature.
  @param(cr The creature.) }
procedure RemoveInvisibility(cr: Pointer);

{ Removes the effects a creature loses when its hit points reach zero. A creature under effect 77 whose npc value is $B3
  returns to the party's side.
  @param(cr The creature, a Types.PCharRecord.) }
procedure RemoveEffectsHp0(cr: Pointer);

{ Cures a creature of an effect: when it has the effect, prints that it is cured and removes the node.
  @param(cr The creature.)
  @param(effId The effect.)
  @returns(True when the creature had the effect.) }
function RemoveEffectWithMessage(cr: Pointer; effId: Byte): Boolean;

{ Tells whether a strength would be higher than a creature's natural strength.
  @param(cr The creature.)
  @param(baseStr The strength score.)
  @param(excStr Its exceptional strength.)
  @param(effStrength Receives the strength packed as StrengthModifier packs it, when it is higher.)
  @returns(True when it is higher.) }
function AdjustForNewStrength(cr: Pointer; baseStr, excStr: Byte; var effStrength: Byte): Boolean;

{ Deals non-weapon damage to a creature. Effects react first (event 6); a successful save then cancels or halves the
  damage, while without a save event 20 fires instead. The damage is announced with its element and applied. In combat
  it stops the creature casting, and a spell in preparation is lost. A creature that goes down is announced as dying or
  killed, and in combat it loses its zero-hit-point effects and leaves the map.
  @param(cr The creature, a Types.PCharRecord.)
  @param(damage The damage.)
  @param(saveReduction What a successful save does: 1 cancels the damage, 2 halves it.)
  @param(saved True when the creature saved.) }
procedure InflictNonWeaponDamage(cr: Pointer; damage: Integer; saveReduction: Byte; saved: Boolean);

{ Gives a creature an effect, announcing it. Effects that block it react first (condition 9) and may cancel it; the
  effect also fails when the creature saved and a save negates it. Either way the creature is reported unaffected.
  Otherwise the effect is added, replacing an instance that still has time to run, and the message, if any, is shown.
  @param(cr The creature.)
  @param(effId The effect.)
  @param(minutes Its duration.)
  @param(strength Its strength.)
  @param(onRemove Set to have its handler called when it is removed.)
  @param(saveNegates Set when a successful save stops the effect.)
  @param(saved Set when the creature saved.)
  @param(msg The announcement, or empty.) }
procedure AddEffectWithMessage(cr: Pointer; effId: Byte; minutes: Word; strength, onRemove, saveNegates, saved: Byte;
                               msg: Types.TStr40);

{ Heals a creature, up to its maximum, if its status allows healing (0, 1, 4 or 5). A dying creature becomes
  unconscious; outside combat an unconscious one gets back on its feet.
  @param(cr The creature.)
  @param(hp The hit points restored.)
  @param(flag True leaves a creature already at full hit points alone.)
  @returns(True if healing was applied.) }
function RestoreHitPoints(cr: Pointer; hp: Byte; flag: Boolean): Boolean;

{ Brings a creature back to life in its own square, announcing it, if that square can still take it. In combat the map
  is redrawn around it.
  @param(cr The creature.)
  @param(hp Its hit points.)
  @param(msg The announcement.)
  @returns(True on success.) }
function ReviveDeadCreature(cr: Pointer; hp: Byte; msg: Types.TStr40): Boolean;

{ Recomputes one ability of a creature from its base value and whatever modifies it, and stores the current value.
  Strength takes the best of magic items and strength effects; constitution also recomputes maximum hit points; charisma
  adds effect 14; feeblemind (effect 68) sets intelligence and wisdom to 3. Constitution's hit-point bonus counts only
  the levels up to each class's last hit die, gives rangers one more for their extra die, and stops at +2 a level
  outside fighters, paladins and rangers.
  @param(cr The creature, a Types.PCharRecord.)
  @param(n The ability: 0 strength, 1 intelligence, 2 wisdom, 4 constitution, 5 charisma.) }
procedure RecalcAbility(cr: Pointer; n: ShortInt);

{ Removes expired terrain patches (stinking clouds and the like) from the combat map, putting back the terrain they
  covered, or the occupied marker where a downed creature lies. Remaining patches are then repainted and the change
  announced.
  @param(expiredOnly Set to remove only patches already marked expired, as dispelling does; clear to count each patch
    down and remove it when its time runs out.) }
procedure CountDownAreaEffects(expiredOnly: Boolean);

implementation

const
  { FxEngine.TriggerEffectsWithCondition condition codes only this unit raises }
  { damage about to be taken }
  COND_DAMAGE_TAKEN = 6;
  { making an attack roll }
  COND_ATTACK_ROLL_ATT = 10;
  { rolling a saving throw }
  COND_SAVING_THROW = 12;
  { being attacked }
  COND_ATTACK_ROLL_DEF = 16;
  { damage taken without a save }
  COND_DAMAGE_NOT_SAVED = 20;

procedure KillCreature(cr: Pointer; status: Byte; msg: Types.TStr40);
begin
  CharHlp.PrintCreatureMessage(cr, msg, 10, False);
  case Types.PCharRecord(cr)^.status of
    C_Status.PETRIFIED, C_Status.DEAD_STATUS, C_Status.GONE: ;
  else begin
      Types.PCharRecord(cr)^.status := status;
      Types.PCharRecord(cr)^.inPlay := 0;
      Types.PCharRecord(cr)^.hpCur := 0;
      FxEngine.RemoveEffectsHp0(cr);
      FxEngine.TriggerEffectsWithCondition(C_Cond.ZERO_HIT_POINTS, cr);
      if (Types.PCharRecord(cr)^.inPlay = 0) and (Types.PCharRecord(cr)^.status <> 10) then
        CbtMap.CreatureDowned(cr);
      TextRend.PauseOnly;
      CharHlp.ClearMessageWindow;
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
        CharHlp.DisplayParty(GDVars.currentChar);
    end;
  end;
end;

procedure CallEffectHandler(effId: Byte; var cr; p: Pointer; removed: Boolean);
begin
  if GDVars.sharedScratch.itemEffectOverride <> 0 then
    GDVars.effectFns[C_Effect.ITEM_EFFECT](cr, p, removed)
  else if effId < 127 then
    GDVars.effectFns[effId](cr, p, removed);
end;

procedure RemoveEffect(cr: Pointer; id: Byte; p: Pointer);
var
  prev: Types.PEffectRec;
  node: Types.PEffectRec;
begin
  node := p;
  if node = nil then begin
    node := Types.PCharRecord(cr)^.effects;
    while (node <> nil) and (node^.id <> id) do
      node := node^.next;
  end;
  if node = nil then Exit;
  if node^.onRemove <> 0 then
    FxEngine.CallEffectHandler(id, cr, node, True);
  if Types.PCharRecord(cr)^.effects = node then
    Types.PCharRecord(cr)^.effects := node^.next
  else begin
    prev := Types.PCharRecord(cr)^.effects;
    while (prev <> nil) and (prev^.next <> node) do
      prev := prev^.next;
    prev^.next := node^.next;
  end;
  FreeMem(node, SizeOf(Types.TEffectRec));
  if id = C_Effect.FRIENDS then
    FxEngine.RecalcAbility(cr, C_Stat.CHARISMA);
  if (id = C_Effect.ENLARGE) or (id = C_Effect.STRENGTH) then
    FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
end;

{ Fires effect effId on cr if cr carries it. The aura effects (21, 45, 46 and 49) also fire when another creature
  carries them and cr is within reach of it: 6 squares for effect 49, otherwise 1. Outside combat any carrier in the
  roster will do. BuildTargetList overwrites list, so it is saved and restored around the search.
  @param(cr The creature.)
  @param(effId The effect.) }
procedure TriggerEffect(var cr; effId: Byte);
var
  { copy of list }
  savedList: array[1..72] of Types.TApproachResult;
  p: Types.PCharRecord;
  eff: Pointer;
  found: Boolean;
  i: Byte;
  range: Byte;
begin
  found := False;
  p := GDVars.creatureListHead;
  if CharHlp.HasEffect(Types.PCharRecord(cr), effId, eff) then
    found := True
  else if effId in [C_Effect.SILENCE, C_Effect.PROTECTION_FROM_EVIL_10_FOOT, C_Effect.PROTECTION_FROM_GOOD_10_FOOT,
                    C_Effect.PRAYER] then begin
    Move(GDVars.rankedTargets, savedList, SizeOf(savedList));
    while (p <> nil) and (not found) do begin
      if CharHlp.HasEffect(p, effId, eff) then begin
        if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
          if effId = C_Effect.PRAYER then range := 6 else range := 1;
          Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(p)), CbtMap.CombatCellY(Types.PCharRecord(p)),
                                  range, $FF,
                                  CbtMap.GetIconSize(Types.PCharRecord(p)));
          for i := 1 to GDVars.rankedTargetCount do
            if GDVars.rankedTargets[i].ent = CbtMap.CombatSlot(Types.PCharRecord(cr)) then
              found := True;
        end else
          found := True;
      end;
      p := Types.PCharRecord(p)^.next;
    end;
    Move(savedList, GDVars.rankedTargets, SizeOf(savedList));
  end;
  if found then
    FxEngine.CallEffectHandler(effId, cr, eff, False);
end;

{ Magic resistance. When an effect is pending or the attack is magical, rolls d100 against cr's resistance, raised 5
  points for each caster level below 11 and lowered 5 for each level above. A resisted spell deals no damage and its
  effect is canceled, except for effects 91 and 82.
  @param(cr The creature.) }
procedure CheckSpellResistance(cr: Types.PCharRecord);
var
  lvl: Byte;
  resist: Integer;
  chance: Integer;
begin
  resist := cr^.spellResistance;
  if resist <> 0 then
    if (GDVars.pendingEffectId <> 0) or ((GDVars.elementMask and 8) <> 0) then begin
      lvl := CharHlp.GetCasterLevel(GDVars.spellBeingCast, False);
      chance := resist + (11 - lvl) * 5;
      if FxEngine.RollDice(1, 100) <= chance then begin
        GDVars.pendingDamage := 0;
        if (GDVars.pendingEffectId <> C_Effect.BLUE_DRAGON_BREATH) and
            (GDVars.pendingEffectId <> C_Effect.BLESSED_BOLT_KILLS) then
          GDVars.pendingEffectId := 0;
      end;
    end;
end;

{ Cancels the pending damage and effect when cr is immune to the element in flight: element bit $80 against immunity bit
  $10, and $40 against $08.
  @param(cr The creature.) }
procedure CancelIfImmune(cr: Types.PCharRecord);
var
  immune: Boolean;
begin
  immune := False;
  if ((GDVars.elementMask and $80) <> 0) and ((cr^.immunities and $10) <> 0) then
    immune := True;
  if ((GDVars.elementMask and $40) <> 0) and ((cr^.immunities and $08) <> 0) then
    immune := True;
  if immune then begin
    GDVars.pendingDamage := 0;
    GDVars.pendingEffectId := 0;
  end;
end;

procedure TriggerEffectsWithCondition(id: Byte; var cr);
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
begin
  case id of
    C_Cond.ATTACKER_VETO: ;
    C_Cond.TARGET_VETO: begin
         FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE);
         FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE_TO_ANIMALS);
         FxEngine.TriggerEffect(cr, C_Effect.BLINKING);
       end;
    2: begin
         FxEngine.TriggerEffect(cr, C_Effect.DEADLY_POISON_MINUS_2);
         FxEngine.TriggerEffect(cr, C_Effect.DRAIN_ONE_LEVEL);
         FxEngine.TriggerEffect(cr, C_Effect.DRAIN_TWO_LEVELS);
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_TOUCH);
         FxEngine.TriggerEffect(cr, C_Effect.PETRIFY_TOUCH);
         FxEngine.TriggerEffect(cr, C_Effect.VORPAL);
         FxEngine.TriggerEffect(cr, C_Effect.DISPEL_EVIL_TOUCH);
         FxEngine.TriggerEffect(cr, C_Effect.PARALYZING_POISON);
       end;
    3: begin
         FxEngine.TriggerEffect(cr, C_Effect.DEADLY_POISON_ATTACK);
         FxEngine.TriggerEffect(cr, C_Effect.DRAIN_ONE_LEVEL);
         FxEngine.TriggerEffect(cr, C_Effect.DRAIN_TWO_LEVELS);
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_TOUCH);
         FxEngine.TriggerEffect(cr, C_Effect.PETRIFY_TOUCH);
         FxEngine.TriggerEffect(cr, C_Effect.DISPEL_EVIL_TOUCH);
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_DAMAGE_4D6);
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_DAMAGE_2D6);
       end;
    C_Cond.ATTACKER_WEAPON_DAMAGE: begin
         FxEngine.TriggerEffect(cr, C_Effect.ENFEEBLE);
         FxEngine.TriggerEffect(cr, C_Effect.RANGER_BONUS_DAMAGE);
         FxEngine.TriggerEffect(cr, C_Effect.DRAGON_FEARED);
         FxEngine.TriggerEffect(cr, C_Effect.GIANT_SLAYING_SWORD);
         FxEngine.TriggerEffect(cr, C_Effect.MULTI_ATTACK_NEW_WEAPONS);
       end;
    C_Cond.DEFENDER_WEAPON_DAMAGE: begin
         FxEngine.TriggerEffect(cr, C_Effect.MIRROR_IMAGE);
         FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_MISSILES);
         FxEngine.TriggerEffect(cr, C_Effect.HIT_BY_PLUS_3_ONLY);
         FxEngine.TriggerEffect(cr, C_Effect.HALF_DAMAGE_PIERCE_CUT);
         FxEngine.TriggerEffect(cr, C_Effect.HALF_DAMAGE_CRUSH);
         FxEngine.TriggerEffect(cr, C_Effect.LUCK_STONE);
         FxEngine.TriggerEffect(cr, C_Effect.HALF_DAMAGE_WEAPONS_UNDER_PLUS_3);
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD);
         FxEngine.TriggerEffect(cr, C_Effect.BLESSED_BOLT_KILLS);
         FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_NONMAGIC);
         FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_WEAPONS_UNDER_PLUS_2);
       end;
    FxEngine.COND_DAMAGE_TAKEN: begin
         FxEngine.CheckSpellResistance(Types.PCharRecord(cr));
         FxEngine.TriggerEffect(cr, C_Effect.RESIST_COLD);
         FxEngine.TriggerEffect(cr, C_Effect.SHIELD);
         FxEngine.TriggerEffect(cr, C_Effect.RESIST_FIRE);
         FxEngine.TriggerEffect(cr, C_Effect.MIRROR_IMAGE);
         FxEngine.TriggerEffect(cr, C_Effect.MINOR_GLOBE);
         FxEngine.TriggerEffect(cr, C_Effect.GLOBE_OF_INVULNERABILITY);
         FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_ELECTRICITY);
         FxEngine.TriggerEffect(cr, C_Effect.RAKSHASA_PROTECTION);
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_HOT);
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_COLD);
         FxEngine.TriggerEffect(cr, C_Effect.RESIST_FIRE_RING);
         FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_DRAGON_BREATH);
         FxEngine.TriggerEffect(cr, C_Effect.IRON_GOLEM_IMMUNITY);
         FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_FIRE);
         FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_COLD);
         FxEngine.TriggerEffect(cr, C_Effect.RESIST_FIRE_DRUID);
         FxEngine.CancelIfImmune(Types.PCharRecord(cr));
       end;
    C_Cond.TURN_START: begin
         FxEngine.TriggerEffect(cr, C_Effect.SNAKE_HARASS);
         FxEngine.TriggerEffect(cr, C_Effect.CONFUSED_LOSE_TURN);
         FxEngine.TriggerEffect(cr, C_Effect.HELPLESS);
         FxEngine.TriggerEffect(cr, C_Effect.HELD);
         FxEngine.TriggerEffect(cr, C_Effect.ASLEEP);
         FxEngine.TriggerEffect(cr, C_Effect.STUNNED);
         FxEngine.TriggerEffect(cr, C_Effect.HELPLESS_51);
       end;
    C_Cond.COMBAT_START: begin
         FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE_RING);
         FxEngine.TriggerEffect(cr, C_Effect.MAGIC_CLOAK);
         FxEngine.TriggerEffect(cr, C_Effect.DRAGON_FEAR_ATTACK);
       end;
    C_Cond.EFFECT_ADDED: begin
         FxEngine.CheckSpellResistance(Types.PCharRecord(cr));
         FxEngine.TriggerEffect(cr, C_Effect.RESIST_CHARM_30);
         FxEngine.TriggerEffect(cr, C_Effect.MIRROR_IMAGE);
         FxEngine.TriggerEffect(cr, C_Effect.RAKSHASA_PROTECTION);
         FxEngine.TriggerEffect(cr, C_Effect.GLOBE_OF_INVULNERABILITY);
         FxEngine.TriggerEffect(cr, C_Effect.MINOR_GLOBE);
         FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_DISEASE);
         FxEngine.TriggerEffect(cr, C_Effect.IRON_GOLEM_IMMUNITY);
         FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_FEAR);
         FxEngine.TriggerEffect(cr, C_Effect.RESIST_SLEEP_CHARM_90);
         FxEngine.TriggerEffect(cr, C_Effect.MIND_BLANK);
       end;
    FxEngine.COND_ATTACK_ROLL_ATT: begin
         FxEngine.TriggerEffect(cr, C_Effect.BLESS);
         FxEngine.TriggerEffect(cr, C_Effect.CURSE);
         FxEngine.TriggerEffect(cr, C_Effect.DWARF_THAC0_BONUS);
         FxEngine.TriggerEffect(cr, C_Effect.BLIND);
         FxEngine.TriggerEffect(cr, C_Effect.BESTOW_CURSE);
         FxEngine.TriggerEffect(cr, C_Effect.PRAYER);
         FxEngine.TriggerEffect(cr, C_Effect.DRAGON_FEARED);
       end;
    C_Cond.DEFENDER_ARMOR_CLASS: begin
         FxEngine.TriggerEffect(cr, C_Effect.DISPEL_EVIL);
         FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_EVIL);
         FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_GOOD);
         FxEngine.TriggerEffect(cr, C_Effect.BARKSKIN);
         FxEngine.TriggerEffect(cr, C_Effect.SHIELD);
         FxEngine.TriggerEffect(cr, C_Effect.STINKING_CLOUD_COUGH);
         FxEngine.TriggerEffect(cr, C_Effect.BLIND);
         FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_EVIL_10_FOOT);
         FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_GOOD_10_FOOT);
         FxEngine.TriggerEffect(cr, C_Effect.DANCING);
         FxEngine.TriggerEffect(cr, C_Effect.HIGHLIGHTED);
         FxEngine.TriggerEffect(cr, C_Effect.IRON_SKIN);
       end;
    FxEngine.COND_SAVING_THROW: begin
         FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_EVIL);
         FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_GOOD);
         FxEngine.TriggerEffect(cr, C_Effect.RESIST_COLD);
         FxEngine.TriggerEffect(cr, C_Effect.BARKSKIN);
         FxEngine.TriggerEffect(cr, C_Effect.SHIELD);
         FxEngine.TriggerEffect(cr, C_Effect.RESIST_FIRE);
         FxEngine.TriggerEffect(cr, C_Effect.BLIND);
         FxEngine.TriggerEffect(cr, C_Effect.BESTOW_CURSE);
         FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_EVIL_10_FOOT);
         FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_GOOD_10_FOOT);
         FxEngine.TriggerEffect(cr, C_Effect.PRAYER);
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_HOT);
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_COLD);
         FxEngine.TriggerEffect(cr, C_Effect.RESIST_FIRE_RING);
         FxEngine.TriggerEffect(cr, C_Effect.CON_POISON_SAVE_BONUS);
         FxEngine.TriggerEffect(cr, C_Effect.CON_SPELL_SAVE_BONUS);
         FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_GAZE);
       end;
    C_Cond.ZERO_HIT_POINTS: ;
    C_Cond.MONSTER_SPECIAL: begin
         FxEngine.TriggerEffect(cr, C_Effect.CONFUSION_GAZE);
         FxEngine.TriggerEffect(cr, C_Effect.BIG_RED_DRAGON_BREATH);
         FxEngine.TriggerEffect(cr, C_Effect.RED_DRAGON_BREATH);
         FxEngine.TriggerEffect(cr, C_Effect.WHITE_DRAGON_BREATH);
         FxEngine.TriggerEffect(cr, C_Effect.GREEN_DRAGON_BREATH);
         FxEngine.TriggerEffect(cr, C_Effect.BLUE_DRAGON_BREATH);
         FxEngine.TriggerEffect(cr, C_Effect.BLACK_DRAGON_BREATH);
         FxEngine.TriggerEffect(cr, C_Effect.PETRIFY_GAZE);
         FxEngine.TriggerEffect(cr, C_Effect.BEHOLDER_EYE_RAYS);
       end;
    C_Cond.ACTION_START: begin
         FxEngine.TriggerEffect(cr, C_Effect.CHARM);
         FxEngine.TriggerEffect(cr, C_Effect.SILENCE);
         FxEngine.TriggerEffect(cr, C_Effect.STINKING_CLOUD_COUGH);
         FxEngine.TriggerEffect(cr, C_Effect.FEEBLEMIND);
         FxEngine.TriggerEffect(cr, C_Effect.BLESSED_BOLT_KILLS);
       end;
    FxEngine.COND_ATTACK_ROLL_DEF: begin
         FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE);
         FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE_TO_ANIMALS);
         FxEngine.TriggerEffect(cr, C_Effect.BLINKING);
         FxEngine.TriggerEffect(cr, C_Effect.DWARF_GIANT_BONUS);
         FxEngine.TriggerEffect(cr, C_Effect.GNOME_LARGE_MONSTER_BONUS);
         FxEngine.TriggerEffect(cr, C_Effect.MAGIC_CLOAK);
       end;
    C_Cond.MORALE_CHECK: begin
         FxEngine.TriggerEffect(cr, C_Effect.BLESS);
         FxEngine.TriggerEffect(cr, C_Effect.CHARM);
       end;
    C_Cond.MOVE_ATTACK_RATE: begin
         FxEngine.TriggerEffect(cr, C_Effect.MAGIC_BOOTS);
         FxEngine.TriggerEffect(cr, C_Effect.HASTED);
         FxEngine.TriggerEffect(cr, C_Effect.SLOWED);
         FxEngine.TriggerEffect(cr, C_Effect.BULLET_RAKE);
       end;
    C_Cond.ROUND_END: begin
         FxEngine.TriggerEffect(cr, C_Effect.CHARM);
         FxEngine.TriggerEffect(cr, C_Effect.SPIRITUAL_HAMMER);
       end;
    FxEngine.COND_DAMAGE_NOT_SAVED: begin
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_HOT);
         FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_COLD);
       end;
    21: FxEngine.TriggerEffect(cr, C_Effect.CONFUSED);
    22: ;
    23: ;
    24: FxEngine.TriggerEffect(cr, C_Effect.DRAGON_FEAR_ATTACK);
  end;
end;

procedure ConsiderTerrainEffects(cr: Pointer; allowSave, skipCloud: Boolean);
var
  { set by ProbeDirection, unused }
  terrIdx: Byte;
  { set by ProbeDirection, unused }
  crIdx: Byte;
  { nausea effect }
  eff: Pointer;
  { coughing effect }
  eff2: Pointer;
  { the stinking-cloud save }
  saved: Boolean;
  { GDVars.currentChar across the effect calls }
  savedChar: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
  { hazard next to cr, 0 for none }
  adjSpecial: Byte;
begin
  if Types.PCharRecord(cr)^.inPlay <> 0 then begin
    GDVars.gMultiTarget := 1;
    CbtMap.ProbeDirection(cr, C_Dir.CENTER, crIdx, terrIdx, adjSpecial);
    if (adjSpecial <> 0) and ((adjSpecial <> C_Terr.TERRAIN_STINKING_CLOUD) or (not skipCloud)) then begin
      if (not CbtMap.CombatIconVisible(cr, 1)) or (GDVars.combatGfxOn = 0) then
        CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), $FF, C_Dir.CENTER);
      case adjSpecial of
        { Stinking cloud. Undead, creatures already nauseated and those immune to it are unaffected. A creature that
          saves only coughs, and loses the spell it was casting; one that fails is overcome by nausea. }
        C_Terr.TERRAIN_STINKING_CLOUD:
          begin
            GDVars.spellBeingCast := 34;
            if (Types.PCharRecord(cr)^.levelUndead = 0) and (not CharHlp.HasEffect(cr, C_Effect.HELPLESS, eff)) and
                ((Types.PCharRecord(cr)^.immunities and $18) = 0) then begin
              saved := FxEngine.RollSavingThrow(cr, 0, 0);
              if saved then begin
                savedChar := GDVars.currentChar;
                FxEngine.AddEffectWithMessage(cr, C_Effect.STINKING_CLOUD_COUGH, FxEngine.RollDice(1, 4) + 1, $FF, 0, 0,
                                              Ord(saved), 'starts to cough');
                eff2 := nil;
                if CharHlp.HasEffect(cr, C_Effect.STINKING_CLOUD_COUGH, eff2) then begin
                  { Note: this passes eff, left over from the failed nausea lookup above, where eff2 was meant. }
                  FxEngine.CallEffectHandler(C_Effect.STINKING_CLOUD_COUGH, cr, eff, False);
                  if Types.PCharRecord(cr)^.combatAddr^.spellCast > 0 then begin
                    CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, True);
                    CharHlp.RemoveSpell(cr, Types.PCharRecord(cr)^.combatAddr^.spellCast);
                    actionsEnded := CharHlp.EndActions(cr);
                  end;
                end;
                GDVars.currentChar := savedChar;
              end else begin
                savedChar := GDVars.currentChar;
                FxEngine.AddEffectWithMessage(cr, C_Effect.HELPLESS, FxEngine.RollDice(1, 4) + 1, $FF, 0, 0,
                                              Ord(saved), 'chokes and gags from nausea');
                if CharHlp.HasEffect(cr, C_Effect.HELPLESS, eff) then
                  FxEngine.CallEffectHandler(C_Effect.HELPLESS, cr, eff, False);
                GDVars.currentChar := savedChar;
              end;
            end;
          end;
        { Cloudkill. Up to 4 hit dice dies outright, 5 hit dice saves at -4, 6 hit dice saves normally, and anything
          larger takes 1d10 damage. }
        C_Terr.TERRAIN_CLOUDKILL:
          begin
            GDVars.spellBeingCast := 91;
            if (Types.PCharRecord(cr)^.inPlay <> 0) and ((Types.PCharRecord(cr)^.immunities and $10) = 0) then
              case Types.PCharRecord(cr)^.hitDice of
                0..4:
                  begin
                    CharHlp.PrintCreatureMessage(cr, 'is Poisoned', 10, False);
                    TextRend.PauseOnly;
                    FxEngine.AddEffect(cr, C_Effect.POISONED, 0, $FF, False);
                    FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed');
                  end;
                5:
                  if not FxEngine.RollSavingThrow(cr, 0, -4) then begin
                    CharHlp.PrintCreatureMessage(cr, 'is Poisoned', 10, False);
                    TextRend.PauseOnly;
                    FxEngine.AddEffect(cr, C_Effect.POISONED, 0, $FF, False);
                    FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed');
                  end;
                6:
                  if not FxEngine.RollSavingThrow(cr, 0, 0) then begin
                    CharHlp.PrintCreatureMessage(cr, 'is Poisoned', 10, False);
                    TextRend.PauseOnly;
                    FxEngine.AddEffect(cr, C_Effect.POISONED, 0, $FF, False);
                    FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed');
                  end;
              else begin
                  GDVars.elementMask := $88;
                  FxEngine.InflictNonWeaponDamage(cr, FxEngine.RollDamageDice(1, 10), 0, False);
                end;
              end;
          end;
        { Blade barrier: 8d8. Magic resistance, run by event 9, can turn the blades away by clearing
          GDVars.pendingDamage. }
        C_Terr.TERRAIN_BLADE_BARRIER:
          begin
            GDVars.spellBeingCast := 101;
            GDVars.elementMask := $08;
            GDVars.pendingDamage := $00FF;
            FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, cr);
            if (Types.PCharRecord(cr)^.inPlay <> 0) and (GDVars.pendingDamage <> 0) then
              if (not allowSave) or (not FxEngine.RollSavingThrow(cr, 4, 0)) then begin
                CharHlp.PrintCreatureMessage(cr, 'is cut by knives', 10, False);
                TextRend.PauseOnly;
                FxEngine.InflictNonWeaponDamage(cr, FxEngine.RollDamageDice(8, 8), 0, False);
              end;
          end;
      end;
    end;
    GDVars.gMultiTarget := 0;
  end;
end;

function AttackRollNoAttacker(defender: Pointer; sixtyMinusThac0: Byte): Boolean;
var
  hit: Boolean;
begin
  hit := False;
  GDVars.lastAttackRoll := FxEngine.RollDice(1, 20);
  if GDVars.lastAttackRoll > 1 then begin
    if GDVars.lastAttackRoll > 16 then
      GDVars.beheadEligible := True
    else
      GDVars.beheadEligible := False;
    if GDVars.lastAttackRoll = 20 then GDVars.lastAttackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_ATTACK_ROLL_DEF, defender);
    if GDVars.lastAttackRoll >= 0 then
      if GDVars.lastAttackRoll + sixtyMinusThac0 > Types.PCharRecord(defender)^.armorClass[0] then
        hit := True;
    GDVars.beheadEligible := GDVars.beheadEligible and hit;
  end;
  AttackRollNoAttacker := hit;
end;

function AttackRoll(attacker, defender: Pointer; sixtyMinusAc: Byte): Boolean;
var
  toHitAdj: ShortInt;
  hit: Boolean;
begin
  hit := False;
  AttackRoll := False;
  FxEngine.RemoveInvisibility(attacker);
  GDVars.lastAttackRoll := FxEngine.RollDice(1, 20);
  if GDVars.lastAttackRoll > 1 then begin
    if GDVars.lastAttackRoll > 16 then
      GDVars.beheadEligible := True
    else
      GDVars.beheadEligible := False;
    if GDVars.lastAttackRoll = 20 then GDVars.lastAttackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_ATTACK_ROLL_ATT, attacker);
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_ATTACK_ROLL_DEF, defender);
    if Types.PCharRecord(attacker)^.side = 0 then begin
      toHitAdj := GDVars.vmBand.zone0^.partyHitMod;
      case GDVars.vmBand.zone0^.difficulty of
        1: Inc(toHitAdj, 2);
        2: Inc(toHitAdj);
        4: Dec(toHitAdj);
        5: Dec(toHitAdj, 2);
      end;
    end else
      toHitAdj := GDVars.vmBand.zone0^.monsterHitMod;
    if GDVars.lastAttackRoll >= 0 then
      if GDVars.lastAttackRoll + Types.PCharRecord(attacker)^.thac0Adj + toHitAdj >= sixtyMinusAc then begin
        hit := True;
        AttackRoll := True;
      end;
    GDVars.beheadEligible := GDVars.beheadEligible and hit;
  end;
end;

function RollSavingThrow(cr: Pointer; saveType, modifier: ShortInt): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  tableIndex: Word;
  eff: Pointer;
begin
  GDVars.lastSaveResult := True;
  GDVars.modifiedSaveRoll := FxEngine.RollDice(1, 20);
  if CharHlp.HasEffect(cr, C_Effect.DANCING, eff) then
    GDVars.modifiedSaveRoll := 1;
  case GDVars.modifiedSaveRoll of
    1: GDVars.lastSaveResult := False;
    20: GDVars.lastSaveResult := True;
  else begin
      GDVars.modifiedSaveRoll := GDVars.modifiedSaveRoll + Types.PCharRecord(cr)^.saveBonus + modifier;
      GDVars.saveThrowType := saveType;
      FxEngine.TriggerEffectsWithCondition(FxEngine.COND_SAVING_THROW, cr);
      if Types.PCharRecord(cr)^.saves[saveType] <= GDVars.modifiedSaveRoll then
        GDVars.lastSaveResult := True
      else
        GDVars.lastSaveResult := False;
    end;
  end;
  RollSavingThrow := GDVars.lastSaveResult;
end;

function RollDice(n, sides: Byte): Byte;
var
  { die being rolled }
  i: Byte;
  { running total }
  total: Byte;
begin
  total := 0;
  if n > 0 then
    for i := 1 to n do
      Inc(total, Random(sides) + 1);
  RollDice := total;
end;

function RollDamageDice(n, sides: Byte): Word;
begin
  GDVars.gDamageDice := n;
  RollDamageDice := FxEngine.RollDice(n, sides);
end;

procedure AddEffect(cr: Pointer; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);
var
  { the new record }
  node: Types.PEffectRec;
  { walks to the end of the chain }
  p: Types.PEffectRec;
begin
  GetMem(node, SizeOf(Types.TEffectRec));
  if Types.PCharRecord(cr)^.effects = nil then
    Types.PCharRecord(cr)^.effects := node
  else begin
    p := Types.PCharRecord(cr)^.effects;
    while p^.next <> nil do
      p := p^.next;
    p^.next := node;
  end;
  node^.next := nil;
  node^.id := effId;
  node^.duration := minutes;
  node^.onRemove := Ord(onRemove);
  node^.strength := strength;
end;

procedure PutOutOfPlayWithStatus(cr: Pointer; status: Byte; msg: Types.TStr40);
var
  slot: Byte;
begin
  if Types.PCharRecord(cr)^.inPlay <> 0 then begin
    slot := CbtMap.CombatSlot(cr);
    CbtMap.DisplayMapViewCentered(cr, 3, False);
    CharHlp.PrintCreatureMessage(cr, msg, 10, True);
    Types.PCharRecord(cr)^.inPlay := 0;
    Types.PCharRecord(cr)^.status := status;
    if Types.PCharRecord(cr)^.status <> C_Status.RUNNING then
      Types.PCharRecord(cr)^.hpCur := 0;
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    Blit.FlushView;
    GDVars.arenaSlots[slot].sizeCode := 0;
    CbtMap.BuildArenaArrays;
    if CharHlp.EndActions(cr) then
      FxEngine.RemoveEffectsHp0(cr);
  end;
end;

procedure RemoveInvisibility(cr: Pointer);
var
  eff: Pointer;
begin
  while CharHlp.HasEffect(cr, C_Effect.INVISIBLE, eff) do
    FxEngine.RemoveEffect(cr, C_Effect.INVISIBLE, eff);
end;

procedure RemoveEffectsHp0(cr: Pointer);
var
  i: Byte;
  eff: Pointer;
begin
  for i := 1 to 16 do
    FxEngine.RemoveEffect(cr, GDConsts.hpZeroEffects[i], nil);
  if CharHlp.HasEffect(cr, C_Effect.CONFUSED_BERSERK, eff) and (Types.PCharRecord(cr)^.npc = C_Npc.ANIMATED_PLAYER) then
    Types.PCharRecord(cr)^.side := 0;
end;

function RemoveEffectWithMessage(cr: Pointer; effId: Byte): Boolean;
var
  eff: Pointer;
begin
  RemoveEffectWithMessage := False;
  if CharHlp.HasEffect(cr, effId, eff) then begin
    CharHlp.PrintCreatureMessage(cr, 'is Cured', 10, True);
    FxEngine.RemoveEffect(cr, effId, eff);
    RemoveEffectWithMessage := True;
  end;
end;

{ Encodes a Strength as an effect strength: 18 with exceptional Strength becomes the exceptional value + 1 (1..101), any
  other base Strength becomes the base + 100.
  @param(baseStr Base Strength.)
  @param(excStr Exceptional Strength, read when the base Strength is 18.)
  @returns(The encoded Strength.) }
function StrengthModifier(baseStr, excStr: Byte): Byte;
begin
  StrengthModifier := baseStr + 100;
  if baseStr = 18 then
    StrengthModifier := excStr + 1;
end;

{ Decodes an effect's strength byte, bit 7 aside, into Strength: up to 101 is Strength 18 with exceptional Strength of
  the value less 1, above it Strength of the value less 100 with no exceptional Strength.
  @param(eff The Strength effect.)
  @param(baseStr Receives Strength.)
  @param(excStr Receives exceptional Strength.) }
procedure StrengthEffectToStrength(eff: Pointer; var baseStr, excStr: Byte);
begin
  excStr := 0;
  baseStr := Types.PEffectRec(eff)^.strength and $7F;
  if baseStr <= 101 then begin
    excStr := baseStr - 1;
    baseStr := 18;
  end else
    baseStr := baseStr - 100;
end;

function AdjustForNewStrength(cr: Pointer; baseStr, excStr: Byte; var effStrength: Byte): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  found: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  oldExc: Byte;
  { Unused in this version; see the other implementations of this routine. }
  enc: Byte;
begin
  if (baseStr > Types.PCharRecord(cr)^.stats[C_Stat.STRENGTH].base) or
      ((baseStr = 18) and (excStr > Types.PCharRecord(cr)^.strExcBase)) then begin
    AdjustForNewStrength := True;
    effStrength := FxEngine.StrengthModifier(baseStr, excStr);
  end else
    AdjustForNewStrength := False;
end;

procedure RecalcAbility(cr: Pointer; n: ShortInt);
var
  { the value being built }
  statVal: Byte;
  { candidate strength }
  baseStr: Byte;
  { exceptional strength going with statVal }
  strExc: Byte;
  { exceptional strength going with baseStr }
  excStr: Byte;
  eff: Pointer;
  { maximum hit points before recalculation }
  hpSave: Byte;
  { constitution hit-point bonus }
  accum: Byte;
  { levels being credited }
  tmp: Byte;
  { class index }
  i: ShortInt;
  { walks the item list }
  p: Types.PItemRec;
  { strength encoding of an item }
  enc: Byte;
  { number of classes with levels }
  count: Byte;

  { Raises the strength being built to the candidate when higher, comparing exceptional strength only at 18. }
  procedure StrClamp;
  begin
    if (baseStr > statVal) or ((baseStr = 18) and (excStr > strExc)) then begin
      statVal := baseStr;
      strExc := excStr;
    end;
  end;

  { Adds the constitution hit-point bonus for b levels of class a to accum. }
  procedure StatBonus(a: ShortInt; b: Byte);
  begin
    if GDConsts.firstFixedHpLevel[a] <= b then
      b := GDConsts.firstFixedHpLevel[a] - 1;
    if a = C_Class.RANGER then Inc(b);
    if (a = C_Class.FIGHTER) or (a = C_Class.RANGER) or (a = C_Class.PALADIN) then
      case statVal of
        15..19: Inc(accum, (statVal - 14) * b);
        20: Inc(accum, b * 5);
        21..23: Inc(accum, b * 6);
        24..25: Inc(accum, b * 7);
      end else
      if statVal > 15 then Inc(accum, b * 2)
      else if statVal = 15 then Inc(accum, b);
  end;

begin
  accum := 0;
  baseStr := 0;
  excStr := 0;
  p := Types.PItemRec(Types.PCharRecord(cr)^.items);
  statVal := Types.PCharRecord(cr)^.stats[n].base;
  strExc := Types.PCharRecord(cr)^.strExcBase;
  { Equipped magic items can set strength: special 3 gives 18/00, special 5 gives 18 plus the item's effect value. }
  while p <> nil do begin
    if (p^.definition.special > C_Item.SPECIAL_POWER_BASE) and (p^.definition.equipped <> 0) then begin
      enc := p^.definition.special and C_Item.SPECIAL_POWER_MASK;
      if n = C_Stat.STRENGTH then begin
        case enc of
          3: begin
               baseStr := 18;
               excStr := 100;
             end;
          5: begin
               baseStr := p^.definition.effect + 18;
               if baseStr = 18 then excStr := 100;
             end;
        end;
        StrClamp;
      end;
    end;
    p := p^.next;
  end;

  { Write the result back, stat by stat. }
  case n of
    C_Stat.STRENGTH: begin
         { Strength effects 38, 113 and 12. 38 adds to a score of 18/99 or less; past 18, fighters, paladins and rangers
           turn the excess into exceptional strength, 10 points per point. }
         if CharHlp.HasEffect(cr, C_Effect.STRENGTH, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           if (statVal <= 18) and (strExc < 100) then begin
             baseStr := statVal + baseStr;
             if baseStr > 18 then
               if (Types.PCharRecord(cr)^.classLevels[C_Class.FIGHTER] > 0) or
                   (Types.PCharRecord(cr)^.classLevels[C_Class.PALADIN] > 0) or
                   (Types.PCharRecord(cr)^.classLevels[C_Class.RANGER] > 0) then begin
                 excStr := Types.PCharRecord(cr)^.strExcCur + (baseStr - 18) * 10;
                 if excStr > 100 then excStr := 100;
                 baseStr := 18;
               end else
                 baseStr := 18;
           end;
           StrClamp;
         end;
         if CharHlp.HasEffect(cr, C_Effect.GIANT_STRENGTH, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           StrClamp;
         end;
         if CharHlp.HasEffect(cr, C_Effect.ENLARGE, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           StrClamp;
         end;
         Types.PCharRecord(cr)^.stats[C_Stat.STRENGTH].cur := statVal;
         Types.PCharRecord(cr)^.strExcCur := strExc;
       end;
    C_Stat.CONSTITUTION: begin
         { Constitution: rebuild maximum hit points from the rolled hit points plus the constitution bonus for every
           class, averaged over the classes, and move current hit points by the same amount. }
         count := 0;
         hpSave := Types.PCharRecord(cr)^.hpMax;
         Types.PCharRecord(cr)^.hpMax := Types.PCharRecord(cr)^.hpRolled;
         for i := C_Class.CLERIC to C_Class.THIEF do begin
           tmp := Types.PCharRecord(cr)^.oldLevels[i];
           if tmp > 0 then StatBonus(i, tmp);
           tmp := Types.PCharRecord(cr)^.classLevels[i];
           if tmp > 0 then begin
             Inc(count);
             if GDConsts.firstFixedHpLevel[i] < tmp then tmp := GDConsts.firstFixedHpLevel[i];
             { A dual-classed human earns the bonus only for levels in the new class above the level of the old one. }
             if Types.PCharRecord(cr)^.race = C_Race.HUMAN then begin
               if tmp > Types.PCharRecord(cr)^.dualLevel then begin
                 Dec(tmp, Types.PCharRecord(cr)^.dualLevel);
                 StatBonus(i, tmp);
               end;
             end else
               StatBonus(i, tmp);
           end;
         end;
         { Note: a creature with no class levels makes count zero here. }
         accum := accum div count;
         Inc(Types.PCharRecord(cr)^.hpMax, accum);
         if Types.PCharRecord(cr)^.hpMax > hpSave then
           Inc(Types.PCharRecord(cr)^.hpCur, Types.PCharRecord(cr)^.hpMax - hpSave);
         if Types.PCharRecord(cr)^.hpMax < hpSave then
           if Types.PCharRecord(cr)^.hpCur > hpSave - Types.PCharRecord(cr)^.hpMax then
             Dec(Types.PCharRecord(cr)^.hpCur, hpSave - Types.PCharRecord(cr)^.hpMax)
           else
             Types.PCharRecord(cr)^.hpCur := 0;
         Types.PCharRecord(cr)^.stats[C_Stat.CONSTITUTION].cur := statVal;
         { Constitution 20 or more grants regeneration (effect 62). Note: the effect is added again on every
           recalculation. }
         if Types.PCharRecord(cr)^.stats[C_Stat.CONSTITUTION].cur >= 20 then
           FxEngine.AddEffect(cr, C_Effect.REGENERATION, 60, $FF, True)
         else
           FxEngine.RemoveEffect(cr, C_Effect.REGENERATION, nil);
       end;
    C_Stat.CHARISMA: begin
         if CharHlp.HasEffect(cr, C_Effect.FRIENDS, eff) then
           Inc(statVal, Types.PEffectRec(eff)^.strength);
         Types.PCharRecord(cr)^.stats[C_Stat.CHARISMA].cur := statVal;
       end;
    C_Stat.INTELLIGENCE, C_Stat.WISDOM: begin
         if CharHlp.HasEffect(cr, C_Effect.FEEBLEMIND, eff) then
           statVal := 3;
         Types.PCharRecord(cr)^.stats[n].cur := statVal;
       end;
  end;
end;

procedure InflictNonWeaponDamage(cr: Pointer; damage: Integer; saveReduction: Byte; saved: Boolean);
var
  { the message being built }
  s: String[80];
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
begin
  GDVars.pendingDamage := damage;
  FxEngine.TriggerEffectsWithCondition(FxEngine.COND_DAMAGE_TAKEN, cr);
  if saved then
    case saveReduction of
      1: GDVars.pendingDamage := 0;
      2: GDVars.pendingDamage := GDVars.pendingDamage div 2;
    end else
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_DAMAGE_NOT_SAVED, cr);
  if GDVars.pendingDamage > 0 then
    if Types.PCharRecord(cr)^.inPlay <> 0 then begin
      { Note: NumToStr takes a Byte, so damage above 255 is reported modulo 256. }
      if GDVars.pendingDamage <> 1 then
        s := 'takes ' + TextRend.NumToStr(GDVars.pendingDamage) + ' points of damage '
      else
        s := 'takes 1 point of damage ';
      case GDVars.elementMask and $F7 of
        1: s := s + 'from Fire';
        2: s := s + 'from Cold';
        4: s := s + 'from Electricity';
      else
        if (GDVars.elementMask and 8) = GDVars.elementMask then
          s := s + 'from Magic';
      end;
      GDVars.infoPanelDirty := 1;
      CharHlp.CombatPrintCreatureInfo(cr);
      CharHlp.PrintNameStringAnim(cr, False, s);
      CharHlp.InflictDamage(cr, GDVars.pendingDamage);
      if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
        Types.PCharRecord(cr)^.combatAddr^.castAllowed := 0;
        if Types.PCharRecord(cr)^.combatAddr^.spellCast > 0 then begin
          CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, True);
          CharHlp.RemoveSpell(cr, Types.PCharRecord(cr)^.combatAddr^.spellCast);
          actionsEnded := CharHlp.EndActions(cr);
        end;
      end;
      if Types.PCharRecord(cr)^.inPlay = 0 then begin
        s := 'Goes Down';
        { A creature with immunity bit 8 just goes down, without the dying or killed detail. }
        if (Types.PCharRecord(cr)^.immunities and 8) = 0 then begin
          if Types.PCharRecord(cr)^.status = C_Status.DYING then
            s := s + ', and is Dying';
          if Types.PCharRecord(cr)^.status in
              [C_Status.DEAD_STATUS, C_Status.PETRIFIED, C_Status.GONE] then
            s := 'is killed';
        end;
        CharHlp.PrintCreatureMessage(cr, s, GDVars.textCursorRow + 1, False);
        if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
          TextRend.PauseOnly
        else begin
          FxEngine.RemoveEffectsHp0(cr);
          FxEngine.TriggerEffectsWithCondition(C_Cond.ZERO_HIT_POINTS, cr);
          if (Types.PCharRecord(cr)^.inPlay = 0) and (Types.PCharRecord(cr)^.status <> 10) then
            CbtMap.CreatureDowned(cr)
          else
            TextRend.PauseOnly;
        end;
      end;
      CharHlp.ClearMessageWindow;
    end;
end;

procedure AddEffectWithMessage(cr: Pointer; effId: Byte; minutes: Word; strength, onRemove, saveNegates, saved: Byte;
                               msg: Types.TStr40);
var
  eff: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  oldEffect: Byte;
begin
  GDVars.pendingEffectId := effId;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, cr);
  if (GDVars.pendingEffectId = 0) or ((saved <> 0) and (saveNegates = 1)) then
    CharHlp.PrintCreatureMessage(cr, 'is Unaffected', 10, True)
  else begin
    if CharHlp.HasEffect(cr, effId, eff) then
      if Types.PEffectRec(eff)^.duration > 0 then
        FxEngine.RemoveEffect(cr, effId, eff);
    FxEngine.AddEffect(cr, effId, minutes, strength, Boolean(onRemove));
    if Length(msg) <> 0 then begin
      CharHlp.PrintNameStringAnim(cr, True, msg);
      CharHlp.ClearMessageWindow;
    end;
  end;
end;

function RestoreHitPoints(cr: Pointer; hp: Byte; flag: Boolean): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Types.PEffectRec;
begin
  RestoreHitPoints := False;
  if Types.PCharRecord(cr)^.status in [C_Status.OKAY, C_Status.ANIMATED, C_Status.UNCONSCIOUS,
      C_Status.DYING] then begin
    if ((Types.PCharRecord(cr)^.hpCur < Types.PCharRecord(cr)^.hpMax) and flag) or (not flag) then begin
      Types.PCharRecord(cr)^.hpCur := Types.PCharRecord(cr)^.hpCur + hp;
      if Types.PCharRecord(cr)^.hpCur > Types.PCharRecord(cr)^.hpMax then
        Types.PCharRecord(cr)^.hpCur := Types.PCharRecord(cr)^.hpMax;
      if Types.PCharRecord(cr)^.inPlay = 0 then begin
        if Types.PCharRecord(cr)^.status = C_Status.DYING then
          Types.PCharRecord(cr)^.status := C_Status.UNCONSCIOUS;
        if Types.PCharRecord(cr)^.status = C_Status.UNCONSCIOUS then
          if GDVars.interfaceState <> C_Ifc.IN_COMBAT then begin
            Types.PCharRecord(cr)^.status := C_Status.OKAY;
            Types.PCharRecord(cr)^.inPlay := 1;
          end;
      end;
      RestoreHitPoints := True;
    end;
  end;
end;

function ReviveDeadCreature(cr: Pointer; hp: Byte; msg: Types.TStr40): Boolean;
var
  { GDVars.combatGfxOn across the forced redraw }
  savedGfx: Byte;
begin
  if CbtMap.IsValidCreatureLoc(cr, CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), True) then begin
    Types.PCharRecord(cr)^.status := C_Status.OKAY;
    Types.PCharRecord(cr)^.inPlay := 1;
    Types.PCharRecord(cr)^.hpCur := hp;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      savedGfx := GDVars.combatGfxOn;
      GDVars.combatGfxOn := 1;
      CbtMap.DisplayMapViewCentered(cr, 3, False);
      GDVars.combatGfxOn := savedGfx;
    end;
    CharHlp.PrintNameStringAnim(cr, True, msg);
    CharHlp.CountTeams;
    ReviveDeadCreature := True;
  end else
    ReviveDeadCreature := False;
end;

{ Redraws each spell cloud's covered cells on the arena. }
procedure RefreshExplosionMap;
var
  p: Types.PCellPatch;
  i: Byte;
begin
  p := GDVars.cellPatchList;
  while p <> nil do begin
    for i := 1 to 9 do
      if p^.used[i] <> 0 then
        GDVars.arenaPtr^.cells[ShortInt(p^.y) + GDConsts.dirDeltaY[GDConsts.patchDirs[i]],
                      ShortInt(p^.x) + GDConsts.dirDeltaX[GDConsts.patchDirs[i]]] := p^.paintTerrain;
    p := p^.next;
  end;
end;

procedure CountDownAreaEffects(expiredOnly: Boolean);
var
  prev: Types.PCellPatch;
  p: Types.PCellPatch;
  nextP: Types.PCellPatch;
  { some patch was removed }
  cleared: Boolean;
  i: Byte;
  cx: ShortInt;
  cy: ShortInt;
  k: Byte;
  { cell occupied by a downed creature; patch to remove }
  found: Boolean;
  hit: Boolean;
begin
  prev := nil;
  p := GDVars.cellPatchList;
  cleared := False;
  while p <> nil do begin
    nextP := p^.next;
    if expiredOnly then
      hit := p^.ttl = -1
    else
      hit := p^.ttl <= 1;
    if hit then begin
      with p^ do
        for i := 1 to 9 do
          if used[i] <> 0 then begin
            cx := ShortInt(x) + GDConsts.dirDeltaX[GDConsts.patchDirs[i]];
            cy := ShortInt(y) + GDConsts.dirDeltaY[GDConsts.patchDirs[i]];
            found := False;
            for k := 1 to GDVars.downedListCount do
              if (GDVars.downedList[k].cr <> nil) and (ShortInt(GDVars.downedList[k].x) = cx) and
                  (ShortInt(GDVars.downedList[k].y) = cy) then
                found := True;
            if found then
              GDVars.arenaPtr^.cells[cy, cx] := C_Terr.TERRAIN_CORPSE
            else
              GDVars.arenaPtr^.cells[cy, cx] := terrainIndex[i];
          end;
      cleared := True;
      if prev = nil then
        GDVars.cellPatchList := nextP
      else
        prev^.next := nextP;
      FreeMem(p, SizeOf(Types.TCellPatch));
    end else begin
      prev := p;
      if not expiredOnly then
        Dec(p^.ttl);
    end;
    p := nextP;
  end;
  if cleared then begin
    FxEngine.RefreshExplosionMap;
    CharHlp.PrintBottomLine('The air clears a little...');
  end;
end;

begin
end.
