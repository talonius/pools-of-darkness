{ The handlers FxEngine calls for each effect id. A handler receives the affected creature, the effect's data, and
  whether the effect is being removed; most of them adjust the attack, save, or damage being resolved.
  InitEffectHandlers installs them into GDVars.effectFns. }
{$O+,F+}
unit EffHndlr;

interface

uses Types, GDConsts, GDVars, GameIo, TextRend, CbtActs, ViewChar, FxEngine, CharHlp,
  ClassCal, Pathing, CbtMap, C_Effect, C_Race, C_Class, C_Ifc, C_Npc, C_Spell, C_Status, C_Stat, C_Equip;

type
  TNN16 = 0..32767;

{ Installs the effect handlers into GDVars.effectFns by effect id; effect 117 is handled by CbtActs.AttackEyeRays. }
procedure InitEffectHandlers;

{ Effects 27, 31, 51, 52, 53 (lose turn, helpless, held, asleep): ends the creature's actions.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffClearGuard(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the bless effect: adds 5 to morale and 1 to the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBless(var cr; p: Pointer; removed: Boolean);

{ Applies the curse effect: takes 5 from morale (not below 0) and 1 from the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffCurse(var cr; p: Pointer; removed: Boolean);

{ Applies sticks to snakes: the snakes use up the creature's attacks this round, taking them off the effect's strength
  (the effect ends when it runs out); the creature is shown fighting with snakes and its actions end.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffSticksToSnakes(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Applies Dispel Evil: takes 7 from the attack roll when the current creature has creature-type flag bit 0, except on
  removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDispelEvil(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 6, Immune to Electricity: cancels electrical damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneElectricity(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 7: unless the effect is being removed, +1 attack against a target with immunities bit 2.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffGnomeHitBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies protection from evil: against an evil attacker (the current character) adds 2 to the saving throw and takes 2
  from the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffProtEvil(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies protection from good: against a good attacker (the current character) adds 2 to the saving throw and takes 2
  from the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffProtGood(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies resist cold: halves cold damage and adds 3 to the saving throw against it, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffResistCold(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies charm: the first time (strength bit 5 marks it), saves the creature's side in strength bit 6, moves it to the
  side in bit 7, makes it a quick fighter (NPC value $B3 unless the value is above $7F), drops its target and recounts
  the sides; each call except a removal sets morale to 100. On removal the saved side returns and the NPC value $B3 is
  cleared.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffCharm(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Effects 12 and 38, Enlarged and Strengthened: does nothing when called.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffExtraStr(var cr; p: Pointer; removed: Boolean);

{ Applies Barkskin: adds 1 to the saving throw unless the attack carries element bit 3, and takes 1 from the attack
  roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBarkskin(var cr; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFriends(var cr; p: Pointer; removed: Boolean);

{ Applies the poison that slow poison holds back: except on removal, every ten minutes, unless the effect lock is set,
  renews itself and costs the creature 1 hit point while it has more than 1, redrawing its roster line outside combat.
  Note: the effect it renews is the dwarf's attack bonus, not itself.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffSlowPoisonHit(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Does nothing for the read magic effect.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffReadMagic(var cr; p: Pointer; removed: Boolean);

{ Applies shield: raises the creature's armor class value to at least 57 (armor class 3), adds 1 to the saving throw,
  and stops Magic Missile, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffShield(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 18, 30% resistant to charm: a 30% chance to shrug off charm and sleep.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffHalfElfResistance(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies resist fire: halves fire damage and adds 3 to the saving throw against it, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffResistFire(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 21, Silenced: a creature in the middle of casting is announced as silenced and loses the spell.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSilence(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Ends slow poison: except on removal, a creature still poisoned collapses from the poison (falls unconscious), and the
  held-back poison is removed under the effect lock.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSlowPoisonEnd(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Spiritual Hammer effect: adding it gives the creature a +1 spiritual hammer, readied if it has no weapon ready, unless
  it already has one or its pack is full; removing it takes the hammer away. The creature's statistics are then
  recalculated. Note: the search after adding the hammer stops one item past it, so a different item can be readied.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSpiritualHammer(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 25, Invisible (spell): attackers that cannot see invisible suffer -4 to hit.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffInvisible(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the dwarf's attack bonus: adds 1 to the attack roll against a combat target with creature-type flag bit 7,
  except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDwarfHitBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 28, Duplicated: in combat, a single-target attack may strike one of the mirror images instead, the chance
  growing with the number of images. The image is lost and the effect ends with the last one.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed.) }
procedure EffMirrorImage(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Applies ray of enfeeblement: takes a quarter off the pending damage, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffEnfeeble(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Nauseated effect: in combat the creature's pending action is cleared, with a coughing message if it had one, and it
  suffers -2 on both defense values.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffCoughing(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 32: unless the effect is being removed, the creature's target, if it has creatureType bit 0 and fails its save
  (type 4), 'is dispelled' and this creature loses effects 4 and $20; otherwise it 'resists dispel evil'.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffDispelEvilTouch(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies blindness: takes 4 from the attack roll, the saving throw and both armor classes, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBlind(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies disease: runs the strength-loss and hit-point-loss disease handlers, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffDiseased(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies confusion: rolls d100: on 1..10 the creature runs away (forced to flee under AI control with the fear effect,
  the confusion ending), on 11..60 it is confused and its actions end, on 61..80 it goes berserk, and on 81..100 it is
  enraged. A spell save at -2 then ends the confusion. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffConfusion(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies bestow curse: takes 4 from the attack roll and the saving throw, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBestowCurse(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Blink effect: when the creature has no initiative left, it cannot be targeted and the attack misses, except on
  removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBlinking(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Haste effect: ages the creature a year the first time (strength bit 5 marks it, and the aging flag is set) and doubles
  its movement and attacks, except on removal.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed.) }
procedure EffHasted(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Effect 40, Rakshasa Protection: spells below level 8 do no damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRakshasaProt(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Protection from Normal Missiles effect: except on removal, ranged attacks with a nonmagical weapon always miss.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffProtNormalMissiles(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies Slow: halves the movement and attacks, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSlowed(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Strength disease: except on removal, and unless the effect lock is on, re-arms itself for another 60 and costs a point
  of current Strength ('weakened') while it is above 3; at 3 or less the creature becomes helpless.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed; nothing is done then.) }
procedure EffDiseaseStrength(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Hit-point disease: except on removal, and unless the effect lock is on, re-arms itself for another 10 and costs 1 hit
  point while the creature has more than 1, redrawing its party-panel row outside combat; at 1 or less the creature
  becomes helpless.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed; nothing is done then.) }
procedure EffDiseaseHitPoints(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Dwarf's defense against giants: takes 4 from the attack roll of an attacker (the current character) with creature-type
  flag bit 2, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDwarfGiantDefense(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the gnome's defensive bonus: takes 4 from the attack roll of an attacker (the current character) with
  creature-type flag bit 5, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGnomeBugDefense(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies prayer: except on removal, a creature on the side named by the top bit (bit 7) of the effect's strength gains
  1 on its attack and save rolls, and a creature on the other side loses 1 on both.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed.) }
procedure EffPrayer(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Effect 50, Fire Shield with hot flames: +2 on saves against cold, and fire damage is doubled when the save fails.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFireShieldHot(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 54, Fire Shield with cold flames: +2 on saves against fire, and cold damage is doubled while the game-saved
  flag is clear. Note: that flag records whether the game was just saved, not whether the target made its saving throw,
  which is what the hot flames handler tests: an SSI bug.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFireShieldCold(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Does nothing for the poisoned effect.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffPoisoned(var cr; p: Pointer; removed: Boolean);

{ Ring of Invisibility effect: adding it makes the wearer invisible as the spell does; removing it in combat ends that
  invisibility.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRenewInvisibility(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 57, Enveloped in Globe of Invulnerability: spells of level 4 and below have no effect.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGlobeInvuln(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Petrifying gaze effect: except on removal, the creature picks an enemy and gazes at it. A gazer whose gaze can be
  reflected has it turned back by a target with a mirror ready. The victim is turned to stone unless it saves (saving
  throw 1) or is immune to gaze attacks.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffPetrifyingGaze(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 59: nothing to do when called.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGazeReflectable(var cr; p: Pointer; removed: Boolean);

{ Effect 60, +3 weapons or better to hit: only +3 or better weapons do damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNeedPlus3(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the ring of fire resistance: against fire takes 2 off the damage per die (to no less than one per die) and
  adds 4 to the saving throw, canceling the attack unless it carries element bit 3, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRingFireRes(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 62, Regeneration: re-arms itself for another 60 and restores 1 hit point.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed.) }
procedure EffRegeneration(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Effect 63: unless the effect is being removed, cancels an incoming spell of level 3 or lower.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffMinorGlobe(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Poisons the creature's combat target on a hit, with no save modifier; nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffPoisonAttack(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 65, Petrification Touch Attack: unless the effect is being removed, the creature's target saves (saving throw
  1) or is turned to stone.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffPetrifyTouch(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Halves the damage of weapons of class 0 and 1.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfDamageFromWeaponClass(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 67: halves damage from a weapon whose weapon class is above $7F.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfDmgCrush(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 68, Mentally Enfeebled: intelligence and wisdom drop to 3, a spell being cast in combat is lost, and the spell
  entries marked with the high bit are cleared.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFeeblemind(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies Invisible to Animals: takes 4 from the attack roll when the creature has creature-type bits $45 and lacks See
  Invisible. Note: the animal test reads the protected creature's flags, not the attacker's.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffInvisibleToAnimals(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 70, confusion gaze: unless the effect is being removed, the creature picks a target (as spell 68) and, when one
  is picked and adjacent (CalcDistance below 2), gazes at it ('gazes...'); unless the target saves (saving throw 4) or
  is immune to gaze attacks, it 'stares blankly', confused for 1d10+2.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffConfusionGaze(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 71, Magically Highlighted: unless the effect is being removed, -2 on both armor class values.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffHighlighted(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 72, mirror ready: nothing to do when called; the gaze handlers test for it.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMirrorReady(var cr; p: Pointer; removed: Boolean);

{ Applies breath immunity: cancels attacks carrying element bit 5 (breath), except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneBreath(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 74, Wearing Magical Boots: no effect. Note: it doubles a local that is never used.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffMagicBoots(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 75, giant slaying sword: unless the effect is being removed, against a target with immunities bit 0 the damage
  becomes 6d6 plus CharHlp.StrDamageAdjust and the attack roll gains 1.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffGiantSlayingSword(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 76, Immune to Disease: cancels disease.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneDisease(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 77, Confused (berserk): the creature fights under computer control; in combat it turns on the nearest creature
  and takes the opposing side. Removal restores its morale and puts it on side 0.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffConfusedBerserk(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 78, Carrying Magical Stone: +1 on saving throws.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffMagicStone(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the iron golem's immunity: a fire attack with element bit 3 heals the creature by the damage (to its maximum),
  an electrical attack slows it, and each attack is canceled, on removal too.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffIronGolem(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 80: halves damage from weapons below +3.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffLuckStone(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 81: halves damage from weapons below +4.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfDmgWeaponLt3(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 82, killed by blessed crossbow bolts: a hit from item type 74 slays the creature.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBlessedBoltKills(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Poisons the creature's combat target on a hit, with a save modifier of -2; nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffStrongPoisonAttack(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 88, paralyzing poison: unless the effect is being removed, paralyzes the creature's target through
  ParalyzeTarget when it is close (CalcDistance below 2).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffParalyzingPoison(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies displacement: except on removal, the first attack on the creature misses (the attack roll becomes -1) and
  strength bit 4 marks it used; the mark is cleared only in round 0 on a zero attack roll.
  @param(cr Unused.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffDisplaced(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Applies fear immunity: cancels fear, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 93, immune to fire: cancels fire damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneFire(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the Constitution saving-throw bonus: adds 1 to 5 to a spell, paralyzation or type-2 saving throw, rising with
  Constitution from 4 to 20, except on removal. Note: other Constitution values add whatever the local held.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffConPsnSave(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Elven resistance: except on removal, a 90 percent chance to shrug off charm and sleep.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffElfResistance(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Constitution save bonus: adds 1 to 5, rising with Constitution from 4 to 20, to a saving throw against spells or
  wands, except on removal. Note: other Constitution values add an unset value.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffConSpellSave(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 98, immune to cold: unless the effect is being removed, cancels cold attacks (damage-type bit 2).
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffNoCold(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 99, bullet rake attack: sets the second phase's attacks left to 8 one time in four, otherwise to 4.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBulletRake(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the dragon fear attack: every conscious enemy that fails saving throw 1 at -4 is terrified, unless already
  affected.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDragonFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 101, drain 1 level: in combat the creature's hit drains one level from its target.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDrainOne(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 102, drain 2 levels: in combat the creature's hit drains two levels from its target.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDrainTwo(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 103, immune to nonmagical weapons: only magical weapons do damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNeedMagic(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 104: in combat, deals 4d6 magical fire damage to the creature's target, which saves (type 4).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireDmg4d6(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 105, bonus damage from rangers: in melee against a target with creatureType bit 8, the ranger adds its ranger
  level to the damage.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRangerDamageBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies Stunned: the creature's actions end.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffStunned(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 107, Berserk: the creature fights under computer control, turns on the nearest creature, and takes the opposing
  side. Removal restores its morale and the side kept in the effect data.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed.) }
procedure EffBerserk(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Effect 108: in combat, deals 2d6 magical fire damage to the creature's target, which saves (type 4).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireDmg2d6(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 110, paladin can't remove curse: on removal, poisonCount is recomputed as one per five paladin levels, plus
  one.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRecentCure(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies fear: on removal a $B3 creature leaves AI control and the creature is no longer forced to flee.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Zaps an adjacent attacker (the current character), except on removal: it 'gets zapped' for twice the pending damage,
  when that is above 0, as magic damage (element bit 3).
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffZapAttacker(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies giant strength: announces that the creature gains it, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGiantStrength(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 114, paralyze gaze attack: the creature picks an enemy and gazes at it, with the same reflection rule as the
  petrification gaze. The victim is held for 10 unless it saves (saving throw 1 at +3) or is immune to gaze attacks.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffParalyzeGaze(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 115, vorpal weapon: in combat, unless the effect is being removed, a beheading hit kills a target without
  immunities bit 5 ('is beheaded').
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffVorpal(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 116, multiple attacks by new weapons: sets the damage for the weapon kind in the first attack count (its dice +
  4 + the strength bonus) and prints the weapon's message.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMultiAttackNewWeapons(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Forced to dance: the armor class and rear armor class 4 lower.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDancing(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 119, Resist Fire (Druid): absorbs 12 points of fire damage per point of strength in the effect data, ending
  when the strength is used up.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed Unused.) }
procedure EffResistFireDruid(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);

{ Effect 120, affected by dragon fear: -2 damage (never below 0) and -2 to hit.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDragonFeared(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 121, Fire Touch: in combat, deals 2d6 magical fire damage to the creature's target, which saves (type 4).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireTouch(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Iron Skin: the armor class and rear armor class 4 higher.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffIronSkin(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Mind Blank: cancels a charm, confusion, hold, feeblemind or fear.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMindBlank(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 125, immune to weapons < +2: only +2 or better weapons do damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNeedPlus2(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 126, immune to gaze attacks: a gaze attack's saving throw always succeeds.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneGaze(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNone(var cr; p: Pointer; removed: Boolean);

{ The override handler for an item's special effect: adds the item's effect to the creature (removed through its
  handler) or, on removal, takes it away, and clears the override flag.
  @param(cr The creature readying or unreadying the item.)
  @param(p The item whose effect is granted.)
  @param(removed True when the item is unreadied.) }
procedure EffGrantItemEffect(var cr: Types.PCharRecord; p: Types.PItemRec; removed: Boolean);

implementation

const
  { TCharRecord.npc for a creature outside the party fighting under computer control while berserk }
  ANIMATED_NON_PLAYER = $B2;
  { effect ids }
  GAZE_REFLECTABLE = 59;
  MIRROR_READY = 72;
  { carrying the magical stone }
  MAGIC_STONE = 78;
  EFFECT_87 = 87;
  { paralyze gaze attack }
  PARALYZE_GAZE = 114;

{ Holds a creature's target, which may save against saving throw 0. Note: minutes is not used; the hold always lasts 10.
  @param(cr The attacking creature.)
  @param(minutes Unused.)
  @param(saveMod The modifier to the target's save.) }
procedure ParalyzeTarget(var cr: Types.PCharRecord; minutes: Word; saveMod: ShortInt);
var saved: Boolean;
begin
  GDVars.effectTarget := cr^.combatAddr^.other;
  saved := FxEngine.RollSavingThrow(GDVars.effectTarget, 0, saveMod);
  FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.HELD, 10, 12, 0, 1, Byte(saved),
                                'paralyzed by poison');
end;

{ Cancels the pending effect and the damage when the given effect is 0 or is the effect being applied.
  @param(effectId The effect to cancel, or 0 for whichever effect is pending.) }
procedure NullifyAttack(effectId: Byte);
begin
  if (effectId = 0) or (GDVars.pendingEffectId = effectId) then begin
    GDVars.pendingDamage := 0;
    GDVars.pendingEffectId := 0;
  end;
end;

procedure PoisonTarget(var cr: Types.PCharRecord; saveMod: ShortInt); forward;

procedure ImproveRolls(var cr; p: Pointer; removed: Boolean); forward;

{ Adds an effect, removed through its handler, unless the effect lock is set.
  @param(cr The creature given the effect.)
  @param(effectId The effect.)
  @param(strength Its strength.)
  @param(minutes Its duration.)
  @returns(True when the effect was added.) }
function AddEffectIfNoLock(var cr; effectId, strength: Byte; minutes: Word): Boolean;
begin
  if GDVars.effectLock <> 0 then
    AddEffectIfNoLock := False
  else begin
    AddEffectIfNoLock := True;
    FxEngine.AddEffect(Pointer(cr), effectId, minutes, strength, True);
  end;
end;

{ Cancels the pending damage when the attack's element mask includes the given bits.
  @param(mask The element bits.) }
procedure ClearDamageForElement(mask: Byte);
begin
  if (GDVars.elementMask and mask) <> 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffClearGuard(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
begin
  actionsEnded := CharHlp.EndActions(Pointer(cr));
end;

{ Gives +1 to the attack roll and the saving throw.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure ImproveRolls(var cr; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Inc(GDVars.modifiedSaveRoll);
    Inc(GDVars.lastAttackRoll);
  end;
end;

procedure EffBless(var cr; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Inc(GDVars.moraleCheck, 5);
    Inc(GDVars.lastAttackRoll);
  end;
end;

procedure EffCurse(var cr; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if GDVars.moraleCheck < 5 then GDVars.moraleCheck := 0 else Dec(GDVars.moraleCheck, 5);
    Dec(GDVars.lastAttackRoll);
  end;
end;

procedure EffSticksToSnakes(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
var
  total: Byte;
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
begin
  total := cr^.attacksLeft[1] + cr^.attacksLeft[2];
  if p^.strength > total then Dec(p^.strength, total)
  else FxEngine.RemoveEffect(Pointer(cr), C_Effect.SNAKE_HARASS, nil);
  CharHlp.PrintNameStringAnim(Pointer(cr), True, 'is fighting with snakes');
  CharHlp.ClearMessageWindow;
  actionsEnded := CharHlp.EndActions(Pointer(cr));
end;

procedure EffDispelEvil(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.currentChar^.creatureType and 1) <> 0 then Dec(GDVars.lastAttackRoll, 7);
end;

procedure EffImmuneElectricity(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then EffHndlr.ClearDamageForElement(4);
end;

procedure EffGnomeHitBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    GDVars.effectTarget := cr^.combatAddr^.other;
    if (GDVars.effectTarget^.immunities and 4) <> 0 then Inc(GDVars.lastAttackRoll);
  end;
end;

procedure EffProtEvil(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.currentChar^.alignment = 2) or (GDVars.currentChar^.alignment = 5) or
        (GDVars.currentChar^.alignment = 8) then begin
      Inc(GDVars.modifiedSaveRoll, 2); Dec(GDVars.lastAttackRoll, 2);
    end;
end;

procedure EffProtGood(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.currentChar^.alignment = 0) or (GDVars.currentChar^.alignment = 3) or
        (GDVars.currentChar^.alignment = 6) then begin
      Inc(GDVars.modifiedSaveRoll, 2); Dec(GDVars.lastAttackRoll, 2);
    end;
end;

procedure EffResistCold(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.elementMask and 2) <> 0 then begin
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
      Inc(GDVars.modifiedSaveRoll, 3);
    end;
end;

procedure EffCharm(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
begin
  if removed then begin
    cr^.side := (p^.strength and $40) div 64;
    if cr^.npc = C_Npc.ANIMATED_PLAYER then begin
      cr^.npc := 0;
      cr^.quickfight := 0;
    end;
  end else begin
    if (p^.strength and $20) = 0 then begin
      p^.strength := p^.strength + $20 + (cr^.side * 64);
      cr^.side := p^.strength div 128;
      cr^.quickfight := 1;
      if cr^.npc <= $7F then cr^.npc := C_Npc.ANIMATED_PLAYER;
      cr^.combatAddr^.other := nil;
      CharHlp.CountTeams;
    end;
    GDVars.moraleCheck := 100;
  end;
end;

procedure EffExtraStr(var cr; p: Pointer; removed: Boolean); begin end;

procedure EffBarkskin(var cr; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if (GDVars.elementMask and 8) = 0 then Inc(GDVars.modifiedSaveRoll);
    Dec(GDVars.lastAttackRoll);
  end;
end;

procedure EffFriends(var cr; p: Pointer; removed: Boolean); begin end;

procedure EffSlowPoisonHit(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
begin
  if not removed then
    if EffHndlr.AddEffectIfNoLock(cr, C_Effect.DWARF_THAC0_BONUS, p^.strength, 10) then
      if cr^.hpCur > 1 then begin
        GDVars.elementMask := 0;
        FxEngine.InflictNonWeaponDamage(Pointer(cr), 1, 0, False);
        if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
          CharHlp.DisplayRoster(Pointer(cr), cr = GDVars.currentChar);
      end;
end;

procedure EffReadMagic(var cr; p: Pointer; removed: Boolean); begin end;

procedure EffShield(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if cr^.armorClass[0] < 57 then cr^.armorClass[0] := 57;
    Inc(GDVars.modifiedSaveRoll);
    if GDVars.spellBeingCast = 15 then GDVars.pendingDamage := 0;
  end;
end;

procedure EffHalfElfResistance(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if FxEngine.RollDice(1, 100) <= 30 then begin
      EffHndlr.NullifyAttack(C_Effect.CHARM);
      EffHndlr.NullifyAttack(C_Effect.ASLEEP);
    end;
end;

procedure EffResistFire(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.elementMask and 1) <> 0 then begin
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
      Inc(GDVars.modifiedSaveRoll, 3);
    end;
end;

procedure EffSilence(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if cr^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintCreatureMessage(Pointer(cr), GDConsts.isWord + GDConsts.effectNames[C_Effect.SILENCE], 10, True);
  if cr^.combatAddr^.spellCast > 0 then
    CharHlp.RemoveSpell(Pointer(cr), cr^.combatAddr^.spellCast);
  cr^.combatAddr^.spellCast := 0;
  cr^.combatAddr^.itemUseAllowed := 0;
  cr^.combatAddr^.castAllowed := 0;
end;

procedure EffSlowPoisonEnd(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  eff: Pointer;
begin
  if not removed then begin
    if CharHlp.HasEffect(Pointer(cr), C_Effect.POISONED, eff) then
      FxEngine.KillCreature(Pointer(cr), C_Status.UNCONSCIOUS, 'collapses from poison');
    GDVars.effectLock := 1;
    FxEngine.RemoveEffect(Pointer(cr), C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectLock := 0;
  end;
end;

procedure EffSpiritualHammer(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  found: Boolean;
  savedCurChar: Types.PCharRecord;
begin
  item := cr^.items;
  found := False;
  while (item <> nil) and not found do
    if (item^.definition.itemType = 6) and (item^.definition.nameIds[3] = 121) then
      found := True
    else
      item := item^.next;

  if removed and (item <> nil) then CharHlp.RemoveItem(Pointer(cr), item);

  if (not removed) and (not found) and (cr^.numberOfItems < 16) then begin
    GetMem(item, SizeOf(Types.TItemRec));
    GameIo.ZeroFill(item^, SizeOf(Types.TItemRec));
    item^.definition.itemType := 6;
    item^.definition.nameIds[2] := 6;
    item^.definition.nameIds[3] := 121;
    item^.definition.plus := 1;
    item^.definition.effect := C_Effect.SPIRITUAL_HAMMER;
    item^.definition.special := $80;
    CharHlp.AddItemCopy(Pointer(cr), item);
    FreeMem(item, SizeOf(Types.TItemRec));

    item := cr^.items;
    found := False;
    while (item <> nil) and not found do begin
      found := (item^.definition.nameIds[3] = 121) and (item^.definition.itemType = 6);
      item := item^.next;
    end;

    savedCurChar := GDVars.currentChar;
    GDVars.currentChar := cr;
    if (item <> nil) and (cr^.equipped[C_Equip.WEAPON] = nil) then begin
      ViewChar.ToggleReadyItem(item);
      item^.definition.equipped := 1;
    end;
    GDVars.currentChar := savedCurChar;
    CharHlp.PrintCreatureMessage(Pointer(cr), 'Gains an item', 10, True);
  end;
  CharHlp.RecalcStats(Pointer(cr));
end;

procedure EffInvisible(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  eff: Pointer;
begin
  if not removed then
    if not CharHlp.HasEffect(GDVars.currentChar, C_Effect.SEE_INVISIBLE, eff) then Dec(GDVars.lastAttackRoll, 4);
end;

procedure EffDwarfHitBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Integer;
begin
  if not removed then begin
    GDVars.effectTarget := cr^.combatAddr^.other;
    if (GDVars.effectTarget^.creatureType and $80) <> 0 then Inc(GDVars.lastAttackRoll);
  end;
end;

procedure EffMirrorImage(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
var images: Byte;
begin
  if removed then Exit;
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then Exit;
  if (FxEngine.RollDice(1, (p^.strength div 32) + 1) > 1) and
      ((GDVars.gMultiTarget = 0) or
       ((GDVars.spellBeingCast > 0) and (GDConsts.spellTable[GDVars.spellBeingCast].offensive = 0))) then begin
    EffHndlr.NullifyAttack(0);
    CharHlp.PrintCreatureMessage(Pointer(cr), 'lost an image', 10, True);
    images := p^.strength shr 5;
    Dec(images);
    if images = 0 then FxEngine.RemoveEffect(Pointer(cr), C_Effect.MIRROR_IMAGE, nil)
    else begin
      images := images shl 5;
      p^.strength := (p^.strength and $1F) or images;
    end;
  end;
end;

procedure EffEnfeeble(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then GDVars.pendingDamage := GDVars.pendingDamage - GDVars.pendingDamage div 4;
end;

procedure EffCoughing(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then Exit;
  if cr^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintCreatureMessage(Pointer(cr), 'is coughing', 10, True);
  cr^.combatAddr^.itemUseAllowed := 0;
  cr^.combatAddr^.castAllowed := 0;
  CharHlp.RecalcStats(Pointer(cr));
  Dec(cr^.armorClass[0], 2);
  Dec(cr^.armorClass[1], 2);
  if cr = GDVars.currentChar then CharHlp.CombatPrintCreatureInfo(Pointer(cr));
end;

procedure EffDispelEvilTouch(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  GDVars.effectTarget := cr^.combatAddr^.other;
  if ((GDVars.effectTarget^.creatureType and 1) <> 0) and
      (not FxEngine.RollSavingThrow(GDVars.effectTarget, 4, 0)) then begin
    FxEngine.KillCreature(GDVars.effectTarget, C_Status.GONE, 'is dispelled');
    FxEngine.RemoveEffect(Pointer(cr), C_Effect.DISPEL_EVIL, nil);
    FxEngine.RemoveEffect(Pointer(cr), C_Effect.DISPEL_EVIL_TOUCH, nil);
  end else CharHlp.PrintCreatureMessage(GDVars.effectTarget, 'resists dispel evil', 10, True);
end;

procedure EffBlind(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Dec(GDVars.lastAttackRoll, 4);
    Dec(cr^.armorClass[0], 4);
    Dec(cr^.armorClass[1], 4);
    Dec(GDVars.modifiedSaveRoll, 4);
  end;
end;

procedure EffDiseased(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    FxEngine.CallEffectHandler(C_Effect.DISEASE_STRENGTH, cr, p, removed);
    FxEngine.CallEffectHandler(C_Effect.DISEASE_HIT_POINTS, cr, p, removed);
  end;
end;

procedure EffConfusion(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  roll: Byte;
  saved: Boolean;
begin
  if removed then Exit;
  roll := FxEngine.RollDice(1, 100);
  case roll of
    1..10:
      begin
        FxEngine.RemoveEffect(Pointer(cr), C_Effect.CONFUSED, nil);
        cr^.combatAddr^.turned := 1;
        cr^.quickfight := 1;
        if cr^.npc <= $7F then cr^.npc := C_Npc.ANIMATED_PLAYER;
        cr^.combatAddr^.other := nil;
        FxEngine.AddEffectWithMessage(Pointer(cr), C_Effect.FRIGHTENED, 10, 0, 1, 1, 0, 'runs away');
      end;
    11..60:
      begin
        CharHlp.PrintNameStringAnim(Pointer(cr), True, 'is confused');
        CharHlp.ClearMessageWindow;
        EffHndlr.EffClearGuard(cr, p, False);
      end;
    61..80:
      begin
        FxEngine.AddEffectWithMessage(Pointer(cr), C_Effect.CONFUSED_BERSERK, 1, cr^.side, 1, 1, 0, 'goes berserk');
        FxEngine.CallEffectHandler(C_Effect.CONFUSED_BERSERK, cr, nil, False);
      end;
    81..100:
      begin
        CharHlp.PrintNameStringAnim(Pointer(cr), True, 'is enraged');
        CharHlp.ClearMessageWindow;
      end;
  end;
  saved := FxEngine.RollSavingThrow(Pointer(cr), 4, -2);
  if saved then FxEngine.RemoveEffect(Pointer(cr), C_Effect.CONFUSED, nil);
end;

procedure EffBestowCurse(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin Dec(GDVars.lastAttackRoll, 4); Dec(GDVars.modifiedSaveRoll, 4) end;
end;

procedure EffBlinking(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if cr^.combatAddr^.initiative = 0 then begin GDVars.attackVetoed := 1; GDVars.lastAttackRoll := -1 end;
end;

procedure EffHasted(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
begin
  if not removed then begin
    if (p^.strength and $20) = 0 then begin
      p^.strength := p^.strength + $20;
      CharHlp.PrintCreatureMessage(Pointer(cr), 'ages', 10, True);
      Inc(cr^.age);
      GDVars.agingPending := 1;
    end;
    GDVars.movementRate := GDVars.movementRate * 2;
    GDVars.attackRate := GDVars.attackRate * 2;
  end;
end;

procedure EffRakshasaProt(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if GDVars.spellBeingCast <> 0 then
      if GDConsts.spellTable[GDVars.spellBeingCast].level < 8 then EffHndlr.NullifyAttack(0);
end;

{ Lets a creature avoid a missile: when the current character has a readied weapon and stands more than one cell away, a
  d100 roll within the chance cancels the damage, makes the attack miss and takes the hit back, with 'Avoids it'.
  @param(cr The creature attacked.)
  @param(chance The chance in percent.) }
procedure AvoidMissile(var cr; chance: Byte);
begin
  if (GDVars.currentChar^.equipped[C_Equip.WEAPON] <> nil) and
      (CharHlp.CalcDistance(Pointer(GDVars.currentChar), Pointer(cr)) > 1) and
      (FxEngine.RollDice(1, 100) <= chance) then begin
    CharHlp.PrintCreatureMessage(Pointer(cr), 'Avoids it', 10, True);
    GDVars.pendingDamage := 0;
    GDVars.lastAttackRoll := -1;
    Dec(GDVars.attackHits[1]);
  end;
end;

{ Finds the item a creature attacks with: the missile its readied weapon fires or throws, else the readied weapon.
  @param(cr The creature.)
  @returns(The item, or nil with no weapon readied.) }
function FindDamagingWeapon(cr: Types.PCharRecord): Types.PItemRec;
var
  item: Pointer;
  found: Boolean;
begin
  item := nil;
  if cr^.equipped[C_Equip.WEAPON] <> nil then begin
    found := CharHlp.FindDamagingRangedWeapon(Pointer(cr), item);
    if (not found) or (item = nil) then item := cr^.equipped[C_Equip.WEAPON];
  end;
  FindDamagingWeapon := Types.PItemRec(item);
end;

procedure EffProtNormalMissiles(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (EffHndlr.FindDamagingWeapon(GDVars.currentChar) <> nil) and
      (EffHndlr.FindDamagingWeapon(GDVars.currentChar)^.definition.plus = 0) then EffHndlr.AvoidMissile(cr, 100);
end;

procedure EffSlowed(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  GDVars.movementRate := GDVars.movementRate div 2;
  GDVars.attackRate := GDVars.attackRate div 2;
end;

procedure EffDiseaseStrength(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
begin
  if removed then Exit;
  if EffHndlr.AddEffectIfNoLock(cr, C_Effect.DISEASE_STRENGTH, p^.strength, 60) then
    if cr^.stats[C_Stat.STRENGTH].cur > 3 then begin
      CharHlp.PrintCreatureMessage(Pointer(cr), GDConsts.isWord + 'weakened', 10, True);
      Dec(cr^.stats[C_Stat.STRENGTH].cur);
    end else FxEngine.AddEffect(Pointer(cr), C_Effect.HELPLESS, 0, $FF, False);
end;

procedure EffDiseaseHitPoints(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
begin
  if removed then Exit;
  if EffHndlr.AddEffectIfNoLock(cr, C_Effect.DISEASE_HIT_POINTS, p^.strength, 10) then
    if cr^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(Pointer(cr), 1, 0, False);
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
        CharHlp.DisplayRoster(Pointer(cr), cr = GDVars.currentChar);
    end else FxEngine.AddEffect(Pointer(cr), C_Effect.HELPLESS, 0, $FF, False);
end;

procedure EffDwarfGiantDefense(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.currentChar^.creatureType and 4) <> 0 then Dec(GDVars.lastAttackRoll, 4);
end;

procedure EffGnomeBugDefense(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.currentChar^.creatureType and $20) <> 0 then Dec(GDVars.lastAttackRoll, 4);
end;

procedure EffPrayer(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
var side: Byte;
begin
  if removed then Exit;
  side := (p^.strength and $80) div 128;
  if Byte(cr^.side) = side then EffHndlr.ImproveRolls(cr, p, removed)
  else begin
    Dec(GDVars.lastAttackRoll);
    Dec(GDVars.modifiedSaveRoll);
  end;
end;

procedure EffFireShieldHot(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.elementMask and 2) <> 0 then Inc(GDVars.modifiedSaveRoll, 2)
  else if (GDVars.elementMask and 1) <> 0 then
    if not GDVars.lastSaveResult then GDVars.pendingDamage := GDVars.pendingDamage * 2;
end;

procedure EffFireShieldCold(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.elementMask and 1) <> 0 then Inc(GDVars.modifiedSaveRoll, 2)
  else if (GDVars.elementMask and 2) <> 0 then
    if GDVars.justSaved = 0 then GDVars.pendingDamage := GDVars.pendingDamage * 2;
end;

procedure EffPoisoned(var cr; p: Pointer; removed: Boolean); begin end;

procedure EffRenewInvisibility(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then begin
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then FxEngine.RemoveEffect(Pointer(cr), C_Effect.INVISIBLE, nil)
  end else
    FxEngine.AddEffect(Pointer(cr), C_Effect.INVISIBLE, 1, 12, False);
end;

procedure EffGlobeInvuln(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if GDVars.spellBeingCast > 0 then
    if GDConsts.spellTable[GDVars.spellBeingCast].level <= 4 then EffHndlr.NullifyAttack(0);
end;

procedure EffPetrifyingGaze(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  reflected: Boolean;
  eff: Pointer;
begin
  if removed then Exit;
  GDVars.spellFps.castMenu(61, 1, GDVars.scratchFlag);
  if Byte(CharHlp.EnemyTeam(Pointer(cr))) <> Byte(GDVars.spellTargetList[1]^.side) then
    GDVars.scratchFlag := False;
  if not GDVars.scratchFlag then Exit;
  GDVars.effectTarget := GDVars.spellTargetList[1];
  CharHlp.PrintCreatureMessage(Pointer(cr), 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(Pointer(cr))),
                                  CbtMap.CombatCellY(Types.PCharRecord(Pointer(cr))),
                                  CbtMap.CombatCellX(Types.PCharRecord(GDVars.effectTarget)),
                                  CbtMap.CombatCellY(Types.PCharRecord(GDVars.effectTarget)), 4, 45);
  if CharHlp.HasEffect(Pointer(cr), EffHndlr.GAZE_REFLECTABLE, eff) then begin
    reflected := False;
    if CharHlp.HasEffect(GDVars.effectTarget, EffHndlr.MIRROR_READY, eff) then begin
      CharHlp.PrintCreatureMessage(GDVars.effectTarget, 'reflects it!', 12, False);
      CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(GDVars.effectTarget)),
                                      CbtMap.CombatCellY(Types.PCharRecord(GDVars.effectTarget)),
                                      CbtMap.CombatCellX(Types.PCharRecord(Pointer(cr))),
                                      CbtMap.CombatCellY(Types.PCharRecord(Pointer(cr))), 4, 45);
      reflected := True;
      GDVars.effectTarget := cr;
    end;
  end;
  if not FxEngine.RollSavingThrow(GDVars.effectTarget, 1, 0) then
    if not CharHlp.HasEffect(GDVars.effectTarget, C_Effect.IMMUNE_GAZE, eff) then
      FxEngine.KillCreature(GDVars.effectTarget, C_Status.PETRIFIED, 'is turned to stone');
end;

procedure EffGazeReflectable(var cr; p: Pointer; removed: Boolean); begin end;

{ Lets only a weapon of at least plus limit hurt the defender. An unarmed monster (race 6) gets through only when its
  hitDice is at least (limit - 1) * 2 + 5; anyone else unarmed does no damage.
  @param(limit The weapon bonus needed.) }
procedure LimitDamageByResistance(limit: Byte);
var
  threshold: Byte;
  item: Types.PItemRec;
begin
  item := EffHndlr.FindDamagingWeapon(GDVars.currentChar);
  if item <> nil then begin
    if item^.definition.plus < limit then GDVars.pendingDamage := 0;
  end else if GDVars.currentChar^.race = C_Race.MONSTER then begin
    threshold := (limit - 1) * 2 + 5;
    if threshold > GDVars.currentChar^.hitDice then GDVars.pendingDamage := 0;
  end else GDVars.pendingDamage := 0;
end;

procedure EffNeedPlus3(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.LimitDamageByResistance(3);
end;

procedure EffRingFireRes(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var i: Byte;
begin
  if removed then Exit;
  if (GDVars.elementMask and 1) <> 0 then begin
    for i := 1 to GDVars.gDamageDice do begin
      Dec(GDVars.pendingDamage, 2);
      if GDVars.pendingDamage < GDVars.gDamageDice then GDVars.pendingDamage := GDVars.gDamageDice;
    end;
    Inc(GDVars.modifiedSaveRoll, 4);
    if (GDVars.elementMask and 8) = 0 then EffHndlr.NullifyAttack(0);
  end;
end;

procedure EffRegeneration(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
begin
  if removed then Exit;
  if EffHndlr.AddEffectIfNoLock(cr, C_Effect.REGENERATION, p^.strength, 60) then
    if FxEngine.RestoreHitPoints(Pointer(cr), 1, True) then
      CharHlp.AnnounceHealStatus(Pointer(cr));
end;

procedure EffMinorGlobe(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if GDVars.spellBeingCast > 0 then
    if GDConsts.spellTable[GDVars.spellBeingCast].level <= 3 then EffHndlr.NullifyAttack(0);
end;

{ Poisons a creature's target, which may save against saving throw 0; poison that takes hold kills.
  @param(cr The attacking creature.)
  @param(saveMod The modifier to the target's save.) }
procedure PoisonTarget(var cr: Types.PCharRecord; saveMod: ShortInt);
var
  eff: Pointer;
  saved: Boolean;
begin
  GDVars.effectTarget := cr^.combatAddr^.other;
  saved := FxEngine.RollSavingThrow(GDVars.effectTarget, 0, saveMod);
  FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.POISONED, 0, $FF, 0, 1, Byte(saved),
                                GDConsts.isWord + GDConsts.effectNames[C_Effect.POISONED]);
  TextRend.PauseOnly;
  if CharHlp.HasEffect(GDVars.effectTarget, C_Effect.POISONED, eff) then
    FxEngine.KillCreature(GDVars.effectTarget, C_Status.DEAD_STATUS, 'is killed');
end;

procedure EffPoisonAttack(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  EffHndlr.PoisonTarget(cr, 0);
end;

procedure EffPetrifyTouch(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  hasSaved: Byte;
begin
  if removed then Exit;
  GDVars.effectTarget := cr^.combatAddr^.other;
  if not FxEngine.RollSavingThrow(GDVars.effectTarget, 1, 0) then
    FxEngine.KillCreature(GDVars.effectTarget, C_Status.PETRIFIED, 'is turned to stone');
end;

procedure EffHalfDamageFromWeaponClass(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var item: Types.PItemRec;
begin
  item := EffHndlr.FindDamagingWeapon(GDVars.currentChar);
  if (item <> nil) and Boolean(GDVars.baseItemTable[item^.definition.itemType].wpnClass <= 1) then
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

procedure EffHalfDmgCrush(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var item: Types.PItemRec;
begin
  item := EffHndlr.FindDamagingWeapon(GDVars.currentChar);
  if (item <> nil) and Boolean(GDVars.baseItemTable[item^.definition.itemType].wpnClass > $7F) then
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

procedure EffFeeblemind(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var i: Byte;
begin
  if removed then Exit;
  cr^.stats[C_Stat.INTELLIGENCE].cur := 3;
  cr^.stats[C_Stat.WISDOM].cur := 3;
  CharHlp.PrintCreatureMessage(Pointer(cr), 'loses intellect', 10, True);
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    cr^.combatAddr^.castAllowed := 0;
    if cr^.combatAddr^.spellCast > 0 then begin
      CharHlp.PrintCreatureMessage(Pointer(cr), 'lost a spell', 12, True);
      CharHlp.RemoveSpell(Pointer(cr), cr^.combatAddr^.spellCast);
      cr^.combatAddr^.spellCast := 0;
    end;
  end;
  for i := 1 to 140 do
    if Types.PCharRecord(cr)^.spells[i] > C_Spell.ID_MASK then
      Types.PCharRecord(cr)^.spells[i] := 0;
end;

procedure EffInvisibleToAnimals(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  eff: Pointer;
begin
  if not removed then
    if (cr^.creatureType and $45) <> 0 then
      if not CharHlp.HasEffect(Pointer(cr), C_Effect.SEE_INVISIBLE, eff) then Dec(GDVars.lastAttackRoll, 4);
end;

procedure EffConfusionGaze(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  selected: Boolean;
  eff: Pointer;
begin
  if removed then Exit;
  GDVars.spellFps.castMenu(68, 1, selected);
  GDVars.effectTarget := GDVars.spellTargetList[1];
  if not selected then Exit;
  if CharHlp.CalcDistance(Pointer(cr), GDVars.effectTarget) >= 2 then Exit;
  GDVars.elementMask := $10;
  CharHlp.PrintCreatureMessage(Pointer(cr), 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(Pointer(cr))),
                                  CbtMap.CombatCellY(Types.PCharRecord(Pointer(cr))),
                                  CbtMap.CombatCellX(Types.PCharRecord(GDVars.effectTarget)),
                                  CbtMap.CombatCellY(Types.PCharRecord(GDVars.effectTarget)), 4, 45);
  if not FxEngine.RollSavingThrow(GDVars.effectTarget, 4, 0) then
    if not CharHlp.HasEffect(GDVars.effectTarget, C_Effect.IMMUNE_GAZE, eff) then
      FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.CONFUSED, FxEngine.RollDice(1, 10) + 2,
                                    cr^.side, 1, 1,
                                    0, 'stares blankly');
end;

procedure EffHighlighted(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  oldArmorClass: Integer;
begin
  if removed then Exit;
  Dec(cr^.armorClass[0], 2); Dec(cr^.armorClass[1], 2);
end;

procedure EffMirrorReady(var cr; p: Pointer; removed: Boolean); begin end;

procedure EffImmuneBreath(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.elementMask and $20) > 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffMagicBoots(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  n: Integer;
  { Unused in this version; see the other implementations of this routine. }
  oldMovement: Integer;
  { Unused in this version; see the other implementations of this routine. }
  newMovement: Integer;
begin
  if not removed then n := n * 2;
end;

procedure EffGiantSlayingSword(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  GDVars.effectTarget := cr^.combatAddr^.other;
  if (GDVars.effectTarget^.immunities and 1) <> 0 then begin
    GDVars.pendingDamage := FxEngine.RollDamageDice(6, 6) + CharHlp.StrDamageAdjust(Pointer(cr));
    Inc(GDVars.lastAttackRoll);
  end;
end;

procedure EffImmuneDisease(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  EffHndlr.NullifyAttack(C_Effect.DISEASED);
end;

procedure EffConfusedBerserk(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    cr^.quickfight := 1;
    if (cr^.npc <= $7F) or (cr^.npc = C_Npc.ANIMATED_PLAYER) then
      cr^.npc := C_Npc.ANIMATED_PLAYER
    else
      cr^.npc := EffHndlr.ANIMATED_NON_PLAYER;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      cr^.combatAddr^.other := nil;
      Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(Pointer(cr))),
                              CbtMap.CombatCellY(Types.PCharRecord(Pointer(cr))),
                              $FF, $FF, CbtMap.GetIconSize(Types.PCharRecord(Pointer(cr))));
      cr^.combatAddr^.other := GDVars.slotCreatures[GDVars.rankedTargets[2].ent];
      cr^.combatAddr^.castAllowed := 0;
      cr^.side := cr^.combatAddr^.other^.side xor 1;
      CharHlp.PrintCreatureMessage(Pointer(cr), 'goes berserk', 10, True);
    end;
  end else begin
    if cr^.npc = C_Npc.ANIMATED_PLAYER then begin
      cr^.npc := 0;
      cr^.quickfight := 0;
    end;
    cr^.side := 0;
  end;
end;

procedure EffMagicStone(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  Inc(GDVars.modifiedSaveRoll);
end;

procedure EffIronGolem(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  hpTotal: LongInt;
  newHp: Word;
begin
  if ((GDVars.elementMask and 1) <> 0) and ((GDVars.elementMask and 8) <> 0) then begin
    CharHlp.PrintCreatureMessage(Pointer(cr), GDConsts.isWord + GDConsts.healedMsg, 10, True);
    newHp := cr^.hpCur + GDVars.pendingDamage;
    if cr^.hpMax < newHp then cr^.hpCur := cr^.hpMax
    else cr^.hpCur := newHp;
    EffHndlr.NullifyAttack(0);
  end else if (GDVars.elementMask and 4) <> 0 then begin
    FxEngine.AddEffect(Pointer(cr), C_Effect.SLOWED, 3, $FF, False);
    CharHlp.PrintCreatureMessage(Pointer(cr), GDConsts.isWord + GDConsts.effectNames[C_Effect.SLOWED], 10, True);
    EffHndlr.NullifyAttack(0);
  end else EffHndlr.NullifyAttack(0);
end;

procedure EffLuckStone(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var item: Types.PItemRec;
begin
  item := EffHndlr.FindDamagingWeapon(GDVars.currentChar);
  if (item <> nil) and Boolean(item^.definition.plus < 3) then GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

procedure EffHalfDmgWeaponLt3(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var item: Types.PItemRec;
begin
  item := EffHndlr.FindDamagingWeapon(GDVars.currentChar);
  if (item <> nil) and Boolean(item^.definition.plus < 4) then GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

procedure EffBlessedBoltKills(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var item: Types.PItemRec;
begin
  item := EffHndlr.FindDamagingWeapon(GDVars.currentChar);
  if (item <> nil) and (item^.definition.itemType = 74) then
    FxEngine.KillCreature(Pointer(cr), C_Status.DEAD_STATUS, 'is slain');
end;

procedure EffStrongPoisonAttack(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  EffHndlr.PoisonTarget(cr, -2);
end;

procedure EffParalyzingPoison(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if CharHlp.CalcDistance(Pointer(cr), cr^.combatAddr^.other) < 2 then
    EffHndlr.ParalyzeTarget(cr, 100, 0);
end;

procedure EffDisplaced(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.combatRound = 0) and (GDVars.lastAttackRoll = 0) then
    p^.strength := p^.strength and $F
  else if (p^.strength and $10) = 0 then begin
    GDVars.lastAttackRoll := -1;
    p^.strength := p^.strength or $10;
  end;
end;

procedure EffImmuneFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  EffHndlr.NullifyAttack(C_Effect.FRIGHTENED);
end;

procedure EffImmuneFire(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.ClearDamageForElement(1);
end;

procedure EffConPsnSave(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  n: Byte;
begin
  if removed then Exit;
  if (GDVars.saveThrowType = 4) or (GDVars.saveThrowType = 2) or (GDVars.saveThrowType = 0) then begin
    case cr^.stats[C_Stat.CONSTITUTION].cur of
      4..6: n := 1;
      7..10: n := 2;
      11..13: n := 3;
      14..17: n := 4;
      18..20: n := 5;
    end;
    GDVars.modifiedSaveRoll := GDVars.modifiedSaveRoll + n;
  end;
end;

procedure EffElfResistance(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if FxEngine.RollDice(1, 100) <= 90 then begin
    EffHndlr.NullifyAttack(C_Effect.CHARM);
    EffHndlr.NullifyAttack(C_Effect.ASLEEP);
  end;
end;

procedure EffConSpellSave(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  n: Byte;
begin
  if removed then Exit;
  if (GDVars.saveThrowType = 4) or (GDVars.saveThrowType = 2) then begin
    case cr^.stats[C_Stat.CONSTITUTION].cur of
      4..6: n := 1;
      7..10: n := 2;
      11..13: n := 3;
      14..17: n := 4;
      18..20: n := 5;
    end;
    GDVars.modifiedSaveRoll := GDVars.modifiedSaveRoll + n;
  end;
end;

procedure EffNoCold(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.elementMask and 2) <> 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffBulletRake(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 4) = 1 then cr^.attacksLeft[2] := 8
  else cr^.attacksLeft[2] := 4;
end;

procedure EffDragonFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  eff: Pointer;
  walk: Types.PCharRecord;
begin
  GDVars.gMultiTarget := 1;
  eff := nil;
  walk := GDVars.creatureListHead;
  while walk <> nil do begin
    if (walk^.side <> cr^.side) and (walk^.status = C_Status.OKAY) and
        (not FxEngine.RollSavingThrow(walk, 1, -4)) and
        (not CharHlp.HasEffect(walk, C_Effect.DRAGON_FEARED, eff)) then
      FxEngine.AddEffectWithMessage(walk, C_Effect.DRAGON_FEARED, 0, 0, 1, 1, 0, 'is terrified');
    walk := walk^.next;
  end;
  GDVars.gMultiTarget := 0;
end;

{ Drains levels from a creature, which 'gets drained': each pass lowers its highest class level by one, setting
  experience halfway into the new level and recalculating, after keeping the old peaks for later restoration. With no
  levels or maximum hit points left it dies; at 0 hit points it collapses. Memorized spells beyond the new spell slots
  are dropped, uncast ones first; a row-2 spell over the limit may use up a bonus-slot allowance instead.
  @param(cr The creature.)
  @param(levels The levels drained.) }
procedure DrainLevels(cr: Types.PCharRecord; levels: Byte);
var
  level: Byte;
  maxLevel: Byte;
  i: ShortInt;
  selectedClass: ShortInt;
  xpUpper: LongInt;
  xpLower: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  classIndex: Byte;
  drainNo: Byte;
  activeClasses: Byte;
  anyClass: Boolean;

  { Forgets the spells cr no longer has slots for, class by class and level by level. }
  procedure PruneSpells;
  var
    counts: array[0..2, 1..9] of Byte;
    spellId: Byte;
    idx: Byte;
    cls: ShortInt;
    spellLevel: Byte;
  begin
    GameIo.ZeroFill(counts, SizeOf(counts));
    for idx := 0 to 140 do
      with cr^ do
      if (spells[idx] > 0) and (spells[idx] < C_Spell.PENDING_FLAG) then begin
        spellId := spells[idx] and C_Spell.ID_MASK;
        cls := GDConsts.spellTable[spellId].castClass;
        spellLevel := GDConsts.spellTable[spellId].level;
        if counts[cls, spellLevel] >= spellSlots[cls, spellLevel] then begin
          if not ((spellSlots[cls, spellLevel] <> 0) and (GDVars.sharedScratch.magicBonusSlots <> 0) and
                  (cls = C_Spell.MAGIC_USER_LIST)) then
            spells[idx] := 0
          else
            Dec(GDVars.sharedScratch.magicBonusSlots);
        end else
          Inc(counts[cls, spellLevel]);
      end;
    for idx := 0 to 140 do
      with cr^ do
      if spells[idx] > C_Spell.ID_MASK then begin
        spellId := spells[idx] and C_Spell.ID_MASK;
        cls := GDConsts.spellTable[spellId].castClass;
        spellLevel := GDConsts.spellTable[spellId].level;
        if counts[cls, spellLevel] >= spellSlots[cls, spellLevel] then
          spells[idx] := 0
        else
          Inc(counts[cls, spellLevel]);
      end;
  end;

begin
  if cr = nil then Exit;
  CharHlp.PrintCreatureMessage(cr, 'gets drained', 10, False);
  TextRend.PauseOnly;
  for drainNo := 1 to levels do begin
    activeClasses := 0;
    maxLevel := 0;
    for i := 0 to 6 do begin
      level := cr^.classLevels[i];
      if (level > 0) or (cr^.peakClassLevels[i] > 0) then Inc(activeClasses);
      if level > maxLevel then begin
        maxLevel := level;
        selectedClass := i;
      end else if (level = maxLevel) and (maxLevel <> 0) then
        if ClassCal.XpForLevel(Types.PCharRecord(cr), level,
                               selectedClass) > ClassCal.XpForLevel(Types.PCharRecord(cr), maxLevel, i) then begin
          maxLevel := level;
          selectedClass := i;
        end;
    end;
    if cr^.peakClassLevels[selectedClass] <= cr^.classLevels[selectedClass] then
      cr^.peakClassLevels[selectedClass] := cr^.classLevels[selectedClass];
    if cr^.oldExperience <= cr^.experience then
      cr^.oldExperience := cr^.experience;
    if cr^.oldHpMax <= cr^.hpMax then cr^.oldHpMax := cr^.hpMax;
    case maxLevel of
      1: begin xpLower := 0; xpUpper := 0 end;
      2: begin
        xpLower := 0;
        xpUpper := GDConsts.classLevelTable[selectedClass].xp[maxLevel];
      end;
    else
      xpLower := ClassCal.XpForLevel(Types.PCharRecord(cr), Pred(maxLevel), selectedClass);
      xpUpper := ClassCal.XpForLevel(Types.PCharRecord(cr), maxLevel, selectedClass);
    end;
    cr^.experience := xpLower + (xpUpper - xpLower) div 2;
    if cr^.classLevels[selectedClass] > 0 then
      Dec(cr^.classLevels[selectedClass]);
    if cr^.classLevels[selectedClass] >= cr^.dualLevel then
      ViewChar.AdjustLevelHitPoints(cr, GDConsts.levelUpClassBit[selectedClass], activeClasses, 0);
    ClassCal.RecalcClassStats(Types.PCharRecord(cr));
    PruneSpells;
  end;
  anyClass := False;
  for i := 0 to 6 do
    if cr^.classLevels[i] > 0 then anyClass := True;
  if (not anyClass) or (cr^.hpMax <= 0) then
    FxEngine.KillCreature(cr, C_Status.GONE, 'dies from drainning')
  else if cr^.hpCur <= 0 then
    FxEngine.KillCreature(cr, C_Status.UNCONSCIOUS, 'collapses from drainning');
end;

procedure EffDrainOne(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then EffHndlr.DrainLevels(cr^.combatAddr^.other, 1);
end;

procedure EffDrainTwo(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then EffHndlr.DrainLevels(cr^.combatAddr^.other, 2);
end;

procedure EffNeedMagic(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.LimitDamageByResistance(1);
end;

procedure EffFireDmg4d6(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  target: Types.PCharRecord;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    target := cr^.combatAddr^.other;
    if target <> nil then begin
      GDVars.elementMask := 9;
      FxEngine.InflictNonWeaponDamage(target, FxEngine.RollDamageDice(4, 6), 2, FxEngine.RollSavingThrow(target, 4, 0));
    end;
  end;
end;

procedure EffRangerDamageBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foe: Pointer;
begin
  if removed then Exit;
  GDVars.effectTarget := cr^.combatAddr^.other;
  if CharHlp.CalcDistance(Pointer(cr), GDVars.effectTarget) > 1 then Exit;
  if (GDVars.effectTarget^.creatureType and 8) <> 0 then
    Inc(GDVars.pendingDamage, ClassCal.EffectiveClassLevel(Types.PCharRecord(Pointer(cr)), C_Class.RANGER));
end;

procedure EffStunned(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
begin
  actionsEnded := CharHlp.EndActions(Pointer(cr));
end;

procedure EffBerserk(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
begin
  if not removed then begin
    cr^.quickfight := 1;
    if (cr^.npc <= $7F) or (cr^.npc = C_Npc.ANIMATED_PLAYER) then
      cr^.npc := C_Npc.ANIMATED_PLAYER
    else
      cr^.npc := EffHndlr.ANIMATED_NON_PLAYER;
    cr^.combatAddr^.other := nil;
    Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(Pointer(cr))),
                            CbtMap.CombatCellY(Types.PCharRecord(Pointer(cr))),
                            $FF, $FF, CbtMap.GetIconSize(Types.PCharRecord(Pointer(cr))));
    cr^.combatAddr^.other := GDVars.slotCreatures[GDVars.rankedTargets[2].ent];
    cr^.side := cr^.combatAddr^.other^.side xor 1;
  end else begin
    if cr^.npc = C_Npc.ANIMATED_PLAYER then cr^.npc := 0;
    cr^.side := p^.strength;
  end;
end;

procedure EffFireDmg2d6(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  target: Types.PCharRecord;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    target := cr^.combatAddr^.other;
    if target <> nil then begin
      GDVars.elementMask := 9;
      FxEngine.InflictNonWeaponDamage(target, FxEngine.RollDamageDice(2, 6), 2, FxEngine.RollSavingThrow(target, 4, 0));
    end;
  end;
end;

procedure EffRecentCure(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then
    cr^.poisonCount := TNN16(ClassCal.EffectiveClassLevel(Types.PCharRecord(Pointer(cr)), C_Class.PALADIN)) div
      5 + 1;
end;

procedure EffFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then begin
    if cr^.npc = C_Npc.ANIMATED_PLAYER then begin
      cr^.npc := 0;
      cr^.quickfight := 0;
    end;
    cr^.combatAddr^.turned := 0;
  end;
end;

procedure EffZapAttacker(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  savedDamage: Integer;
  savedMask: Word;
begin
  if removed then Exit;
  if CharHlp.CalcDistance(GDVars.currentChar, Pointer(cr)) < 2 then begin
    savedDamage := GDVars.pendingDamage;
    GDVars.pendingDamage := GDVars.pendingDamage * 2;
    if GDVars.pendingDamage > 0 then begin
      savedMask := GDVars.elementMask;
      GDVars.elementMask := 8;
      CharHlp.PrintCreatureMessage(GDVars.currentChar, 'gets zapped', 10, True);
      FxEngine.InflictNonWeaponDamage(GDVars.currentChar, GDVars.pendingDamage, 0, False);
      GDVars.pendingDamage := savedDamage;
      GDVars.elementMask := savedMask;
    end;
  end;
end;

procedure EffGiantStrength(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    CharHlp.PrintCreatureMessage(Pointer(cr), GDConsts.gainsWord + GDConsts.effectNames[C_Effect.GIANT_STRENGTH], 10,
                                 True);
end;

procedure EffParalyzeGaze(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
  saved: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  reflected: Boolean;
  eff: Pointer;
begin
  if removed then Exit;
  GDVars.spellFps.castMenu(10, 1, GDVars.scratchFlag);
  if Byte(CharHlp.EnemyTeam(Pointer(cr))) <> Byte(GDVars.spellTargetList[1]^.side) then
    GDVars.scratchFlag := False;
  if not GDVars.scratchFlag then Exit;
  GDVars.elementMask := $10;
  GDVars.effectTarget := GDVars.spellTargetList[1];
  CharHlp.PrintCreatureMessage(Pointer(cr), 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(Pointer(cr))),
                                  CbtMap.CombatCellY(Types.PCharRecord(Pointer(cr))),
                                  CbtMap.CombatCellX(Types.PCharRecord(GDVars.effectTarget)),
                                  CbtMap.CombatCellY(Types.PCharRecord(GDVars.effectTarget)), 4, 45);
  if CharHlp.HasEffect(Pointer(cr), EffHndlr.GAZE_REFLECTABLE, eff) then begin
    reflected := False;
    if CharHlp.HasEffect(GDVars.effectTarget, EffHndlr.MIRROR_READY, eff) then begin
      CharHlp.PrintCreatureMessage(GDVars.effectTarget, 'reflects it!', 12, False);
      CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(GDVars.effectTarget)),
                                      CbtMap.CombatCellY(Types.PCharRecord(GDVars.effectTarget)),
                                      CbtMap.CombatCellX(Types.PCharRecord(Pointer(cr))),
                                      CbtMap.CombatCellY(Types.PCharRecord(Pointer(cr))), 4, 45);
      reflected := True;
      GDVars.effectTarget := cr;
    end;
  end;
  saved := FxEngine.RollSavingThrow(GDVars.effectTarget, 1, 3) or
    CharHlp.HasEffect(GDVars.effectTarget, C_Effect.IMMUNE_GAZE, eff);
  FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.HELD, 10, 12, 0, 1, Byte(saved),
                                'paralyzed');
end;

procedure EffVorpal(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  target: Types.PCharRecord;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    if not removed then
      if GDVars.beheadEligible then begin
        target := cr^.combatAddr^.other;
        if (target^.immunities and $20) = 0 then
          FxEngine.KillCreature(target, C_Status.DEAD_STATUS, 'is beheaded');
      end;
end;

procedure EffMultiAttackNewWeapons(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  msg: String[40];
  bonus: ShortInt;
begin
  msg := '';
  bonus := CharHlp.StrDamageAdjust(Pointer(cr));
  case GDVars.attackCounts[1] of
    1: begin
      GDVars.pendingDamage := bonus + (FxEngine.RollDice(1, 10) + 4);
      msg := GDConsts.itemNameParts[20] + GDConsts.itemNameParts[114];
    end;
    2: begin
      GDVars.pendingDamage := bonus + (FxEngine.RollDice(2, 4) + 4);
      msg := GDConsts.itemNameParts[16] + GDConsts.itemNameParts[114];
    end;
    3: begin
      GDVars.pendingDamage := bonus + (FxEngine.RollDice(1, 8) + 4);
      msg := GDConsts.itemNameParts[18] + GDConsts.itemNameParts[114];
    end;
    4: begin
      GDVars.pendingDamage := bonus + (FxEngine.RollDice(1, 8) + 4);
      msg := GDConsts.itemNameParts[13] + GDConsts.itemNameParts[114];
    end;
    5: begin
      GDVars.pendingDamage := bonus + (FxEngine.RollDice(1, 4) + 4);
      msg := GDConsts.itemNameParts[4] + GDConsts.itemNameParts[114];
    end;
    6: begin
      GDVars.pendingDamage := bonus + (FxEngine.RollDice(1, 6) + 4);
      msg := GDConsts.itemNameParts[14] + GDConsts.itemNameParts[114];
    end;
  end;
  TextRend.DisplayMessageWindow(23, 7, 38, 9, 10, 0, True, msg);
end;

procedure EffDancing(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Dec(cr^.armorClass[0], 4); Dec(cr^.armorClass[1], 4);
end;

procedure EffResistFireDruid(var cr: Types.PCharRecord; p: Types.PEffectRec; removed: Boolean);
var
  cost: Word;
begin
  if (GDVars.elementMask and 1) <> 0 then begin
    cost := p^.strength * 12;
    if LongInt(cost) > GDVars.pendingDamage then begin
      Dec(cost, Word(GDVars.pendingDamage));
      GDVars.pendingDamage := 0;
      p^.strength := cost div 12;
      if p^.strength = 0 then
        FxEngine.RemoveEffect(Pointer(cr), C_Effect.RESIST_FIRE_DRUID, nil);
    end else begin
      Dec(GDVars.pendingDamage, Integer(cost));
      FxEngine.RemoveEffect(Pointer(cr), C_Effect.RESIST_FIRE_DRUID, nil);
    end;
  end;
end;

procedure EffDragonFeared(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.pendingDamage > 2 then Dec(GDVars.pendingDamage, 2) else GDVars.pendingDamage := 0;
  Dec(GDVars.lastAttackRoll, 2);
end;

procedure EffFireTouch(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  target: Types.PCharRecord;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    target := cr^.combatAddr^.other;
    if target <> nil then begin
      GDVars.elementMask := 9;
      FxEngine.InflictNonWeaponDamage(target, FxEngine.RollDamageDice(2, 6), 2, FxEngine.RollSavingThrow(target, 4, 0));
    end;
  end;
end;

procedure EffIronSkin(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Inc(cr^.armorClass[0], 4); Inc(cr^.armorClass[1], 4);
end;

procedure EffMindBlank(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.CHARM);
  EffHndlr.NullifyAttack(C_Effect.CONFUSED);
  EffHndlr.NullifyAttack(C_Effect.HELD);
  EffHndlr.NullifyAttack(C_Effect.FEEBLEMIND);
  EffHndlr.NullifyAttack(C_Effect.FRIGHTENED);
end;

procedure EffNeedPlus2(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.LimitDamageByResistance(2);
end;

procedure EffImmuneGaze(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and $10) <> 0 then GDVars.modifiedSaveRoll := 20;
end;

procedure EffNone(var cr; p: Pointer; removed: Boolean); begin end;

procedure EffGrantItemEffect(var cr: Types.PCharRecord; p: Types.PItemRec; removed: Boolean);
var
  info: Types.PItemRec;
begin
  GDVars.sharedScratch.itemEffectOverride := 0;
  info := p;
  if removed then
    FxEngine.RemoveEffect(Pointer(cr), info^.definition.effect, nil)
  else
    FxEngine.AddEffect(Pointer(cr), info^.definition.effect, 0, $FF, True);
end;

procedure InitEffectHandlers;
begin
  @GDVars.effectFns[C_Effect.BLESS] := @EffHndlr.EffBless;
  @GDVars.effectFns[C_Effect.CURSE] := @EffHndlr.EffCurse;
  @GDVars.effectFns[C_Effect.SNAKE_HARASS] := @EffHndlr.EffSticksToSnakes;
  @GDVars.effectFns[C_Effect.DISPEL_EVIL] := @EffHndlr.EffDispelEvil;
  @GDVars.effectFns[C_Effect.DETECT_MAGIC] := @EffHndlr.EffNone;
  @GDVars.effectFns[C_Effect.IMMUNE_ELECTRICITY] := @EffHndlr.EffImmuneElectricity;
  @GDVars.effectFns[C_Effect.GNOME_THAC0_BONUS] := @EffHndlr.EffGnomeHitBonus;
  @GDVars.effectFns[C_Effect.PROTECTION_FROM_EVIL] := @EffHndlr.EffProtEvil;
  @GDVars.effectFns[C_Effect.PROTECTION_FROM_GOOD] := @EffHndlr.EffProtGood;
  @GDVars.effectFns[C_Effect.RESIST_COLD] := @EffHndlr.EffResistCold;
  @GDVars.effectFns[C_Effect.CHARM] := @EffHndlr.EffCharm;
  @GDVars.effectFns[C_Effect.ENLARGE] := @EffHndlr.EffExtraStr;
  @GDVars.effectFns[C_Effect.BARKSKIN] := @EffHndlr.EffBarkskin;
  @GDVars.effectFns[C_Effect.FRIENDS] := @EffHndlr.EffFriends;
  @GDVars.effectFns[C_Effect.SLOW_POISON_HIT] := @EffHndlr.EffSlowPoisonHit;
  @GDVars.effectFns[C_Effect.READ_MAGIC] := @EffHndlr.EffReadMagic;
  @GDVars.effectFns[C_Effect.SHIELD] := @EffHndlr.EffShield;
  @GDVars.effectFns[C_Effect.RESIST_CHARM_30] := @EffHndlr.EffHalfElfResistance;
  @GDVars.effectFns[C_Effect.FIND_TRAPS] := @EffHndlr.EffNone;
  @GDVars.effectFns[C_Effect.RESIST_FIRE] := @EffHndlr.EffResistFire;
  @GDVars.effectFns[C_Effect.SILENCE] := @EffHndlr.EffSilence;
  @GDVars.effectFns[C_Effect.SLOW_POISON_END] := @EffHndlr.EffSlowPoisonEnd;
  @GDVars.effectFns[C_Effect.SPIRITUAL_HAMMER] := @EffHndlr.EffSpiritualHammer;
  @GDVars.effectFns[C_Effect.SEE_INVISIBLE] := @EffHndlr.EffNone;
  @GDVars.effectFns[C_Effect.INVISIBLE] := @EffHndlr.EffInvisible;
  @GDVars.effectFns[C_Effect.DWARF_THAC0_BONUS] := @EffHndlr.EffDwarfHitBonus;
  @GDVars.effectFns[C_Effect.CONFUSED_LOSE_TURN] := @EffHndlr.EffClearGuard;
  @GDVars.effectFns[C_Effect.MIRROR_IMAGE] := @EffHndlr.EffMirrorImage;
  @GDVars.effectFns[C_Effect.ENFEEBLE] := @EffHndlr.EffEnfeeble;
  @GDVars.effectFns[C_Effect.STINKING_CLOUD_COUGH] := @EffHndlr.EffCoughing;
  @GDVars.effectFns[C_Effect.HELPLESS] := @EffHndlr.EffClearGuard;
  @GDVars.effectFns[C_Effect.DISPEL_EVIL_TOUCH] := @EffHndlr.EffDispelEvilTouch;
  @GDVars.effectFns[C_Effect.BLIND] := @EffHndlr.EffBlind;
  @GDVars.effectFns[C_Effect.DISEASED] := @EffHndlr.EffDiseased;
  @GDVars.effectFns[C_Effect.CONFUSED] := @EffHndlr.EffConfusion;
  @GDVars.effectFns[C_Effect.BESTOW_CURSE] := @EffHndlr.EffBestowCurse;
  @GDVars.effectFns[C_Effect.BLINKING] := @EffHndlr.EffBlinking;
  @GDVars.effectFns[C_Effect.STRENGTH] := @EffHndlr.EffExtraStr;
  @GDVars.effectFns[C_Effect.HASTED] := @EffHndlr.EffHasted;
  @GDVars.effectFns[C_Effect.RAKSHASA_PROTECTION] := @EffHndlr.EffRakshasaProt;
  @GDVars.effectFns[C_Effect.PROTECTION_FROM_MISSILES] := @EffHndlr.EffProtNormalMissiles;
  @GDVars.effectFns[C_Effect.SLOWED] := @EffHndlr.EffSlowed;
  @GDVars.effectFns[C_Effect.DISEASE_STRENGTH] := @EffHndlr.EffDiseaseStrength;
  @GDVars.effectFns[C_Effect.DISEASE_HIT_POINTS] := @EffHndlr.EffDiseaseHitPoints;
  @GDVars.effectFns[C_Effect.PROTECTION_FROM_EVIL_10_FOOT] := @EffHndlr.EffProtEvil;
  @GDVars.effectFns[C_Effect.PROTECTION_FROM_GOOD_10_FOOT] := @EffHndlr.EffProtGood;
  @GDVars.effectFns[C_Effect.DWARF_GIANT_BONUS] := @EffHndlr.EffDwarfGiantDefense;
  @GDVars.effectFns[C_Effect.GNOME_LARGE_MONSTER_BONUS] := @EffHndlr.EffGnomeBugDefense;
  @GDVars.effectFns[C_Effect.PRAYER] := @EffHndlr.EffPrayer;
  @GDVars.effectFns[C_Effect.FIRE_SHIELD_HOT] := @EffHndlr.EffFireShieldHot;
  @GDVars.effectFns[C_Effect.HELPLESS_51] := @EffHndlr.EffClearGuard;
  @GDVars.effectFns[C_Effect.HELD] := @EffHndlr.EffClearGuard;
  @GDVars.effectFns[C_Effect.ASLEEP] := @EffHndlr.EffClearGuard;
  @GDVars.effectFns[C_Effect.FIRE_SHIELD_COLD] := @EffHndlr.EffFireShieldCold;
  @GDVars.effectFns[C_Effect.POISONED] := @EffHndlr.EffPoisoned;
  @GDVars.effectFns[C_Effect.INVISIBLE_RING] := @EffHndlr.EffRenewInvisibility;
  @GDVars.effectFns[C_Effect.GLOBE_OF_INVULNERABILITY] := @EffHndlr.EffGlobeInvuln;
  @GDVars.effectFns[C_Effect.PETRIFY_GAZE] := @EffHndlr.EffPetrifyingGaze;
  @GDVars.effectFns[EffHndlr.GAZE_REFLECTABLE] := @EffHndlr.EffGazeReflectable;
  @GDVars.effectFns[C_Effect.HIT_BY_PLUS_3_ONLY] := @EffHndlr.EffNeedPlus3;
  @GDVars.effectFns[C_Effect.RESIST_FIRE_RING] := @EffHndlr.EffRingFireRes;
  @GDVars.effectFns[C_Effect.REGENERATION] := @EffHndlr.EffRegeneration;
  @GDVars.effectFns[C_Effect.MINOR_GLOBE] := @EffHndlr.EffMinorGlobe;
  @GDVars.effectFns[C_Effect.DEADLY_POISON_ATTACK] := @EffHndlr.EffPoisonAttack;
  @GDVars.effectFns[C_Effect.PETRIFY_TOUCH] := @EffHndlr.EffPetrifyTouch;
  @GDVars.effectFns[C_Effect.HALF_DAMAGE_PIERCE_CUT] := @EffHndlr.EffHalfDamageFromWeaponClass;
  @GDVars.effectFns[C_Effect.HALF_DAMAGE_CRUSH] := @EffHndlr.EffHalfDmgCrush;
  @GDVars.effectFns[C_Effect.FEEBLEMIND] := @EffHndlr.EffFeeblemind;
  @GDVars.effectFns[C_Effect.INVISIBLE_TO_ANIMALS] := @EffHndlr.EffInvisibleToAnimals;
  @GDVars.effectFns[C_Effect.CONFUSION_GAZE] := @EffHndlr.EffConfusionGaze;
  @GDVars.effectFns[C_Effect.HIGHLIGHTED] := @EffHndlr.EffHighlighted;
  @GDVars.effectFns[EffHndlr.MIRROR_READY] := @EffHndlr.EffMirrorReady;
  @GDVars.effectFns[C_Effect.IMMUNE_DRAGON_BREATH] := @EffHndlr.EffImmuneBreath;
  @GDVars.effectFns[C_Effect.MAGIC_BOOTS] := @EffHndlr.EffMagicBoots;
  @GDVars.effectFns[C_Effect.GIANT_SLAYING_SWORD] := @EffHndlr.EffGiantSlayingSword;
  @GDVars.effectFns[C_Effect.IMMUNE_DISEASE] := @EffHndlr.EffImmuneDisease;
  @GDVars.effectFns[C_Effect.CONFUSED_BERSERK] := @EffHndlr.EffConfusedBerserk;
  @GDVars.effectFns[EffHndlr.MAGIC_STONE] := @EffHndlr.EffMagicStone;
  @GDVars.effectFns[C_Effect.IRON_GOLEM_IMMUNITY] := @EffHndlr.EffIronGolem;
  @GDVars.effectFns[C_Effect.LUCK_STONE] := @EffHndlr.EffLuckStone;
  @GDVars.effectFns[C_Effect.HALF_DAMAGE_WEAPONS_UNDER_PLUS_3] := @EffHndlr.EffHalfDmgWeaponLt3;
  @GDVars.effectFns[C_Effect.BLESSED_BOLT_KILLS] := @EffHndlr.EffBlessedBoltKills;
  @GDVars.effectFns[C_Effect.DEADLY_POISON_MINUS_2] := @EffHndlr.EffStrongPoisonAttack;
  @GDVars.effectFns[EffHndlr.EFFECT_87] := @EffHndlr.EffNone;
  @GDVars.effectFns[C_Effect.PARALYZING_POISON] := @EffHndlr.EffParalyzingPoison;
  @GDVars.effectFns[C_Effect.MAGIC_CLOAK] := @EffHndlr.EffDisplaced;
  @GDVars.effectFns[C_Effect.IMMUNE_FEAR] := @EffHndlr.EffImmuneFear;
  @GDVars.effectFns[C_Effect.IMMUNE_FIRE] := @EffHndlr.EffImmuneFire;
  @GDVars.effectFns[C_Effect.CON_POISON_SAVE_BONUS] := @EffHndlr.EffConPsnSave;
  @GDVars.effectFns[C_Effect.RESIST_SLEEP_CHARM_90] := @EffHndlr.EffElfResistance;
  @GDVars.effectFns[C_Effect.CON_SPELL_SAVE_BONUS] := @EffHndlr.EffConSpellSave;
  @GDVars.effectFns[C_Effect.IMMUNE_COLD] := @EffHndlr.EffNoCold;
  @GDVars.effectFns[C_Effect.BULLET_RAKE] := @EffHndlr.EffBulletRake;
  @GDVars.effectFns[C_Effect.DRAGON_FEAR_ATTACK] := @EffHndlr.EffDragonFear;
  @GDVars.effectFns[C_Effect.DRAIN_ONE_LEVEL] := @EffHndlr.EffDrainOne;
  @GDVars.effectFns[C_Effect.DRAIN_TWO_LEVELS] := @EffHndlr.EffDrainTwo;
  @GDVars.effectFns[C_Effect.IMMUNE_NONMAGIC] := @EffHndlr.EffNeedMagic;
  @GDVars.effectFns[C_Effect.FIRE_DAMAGE_4D6] := @EffHndlr.EffFireDmg4d6;
  @GDVars.effectFns[C_Effect.RANGER_BONUS_DAMAGE] := @EffHndlr.EffRangerDamageBonus;
  @GDVars.effectFns[C_Effect.STUNNED] := @EffHndlr.EffStunned;
  @GDVars.effectFns[C_Effect.BERSERK] := @EffHndlr.EffBerserk;
  @GDVars.effectFns[C_Effect.FIRE_DAMAGE_2D6] := @EffHndlr.EffFireDmg2d6;
  @GDVars.effectFns[C_Effect.RECENT_HEAL] := @EffHndlr.EffNone;
  @GDVars.effectFns[C_Effect.RECENT_CURE] := @EffHndlr.EffRecentCure;
  @GDVars.effectFns[C_Effect.FRIGHTENED] := @EffHndlr.EffFear;
  @GDVars.effectFns[C_Effect.FIRE_SHIELD] := @EffHndlr.EffZapAttacker;
  @GDVars.effectFns[C_Effect.GIANT_STRENGTH] := @EffHndlr.EffGiantStrength;
  @GDVars.effectFns[EffHndlr.PARALYZE_GAZE] := @EffHndlr.EffParalyzeGaze;
  @GDVars.effectFns[C_Effect.VORPAL] := @EffHndlr.EffVorpal;
  @GDVars.effectFns[C_Effect.MULTI_ATTACK_NEW_WEAPONS] := @EffHndlr.EffMultiAttackNewWeapons;
  @GDVars.effectFns[C_Effect.BEHOLDER_EYE_RAYS] := @CbtActs.AttackEyeRays;
  @GDVars.effectFns[C_Effect.DANCING] := @EffHndlr.EffDancing;
  @GDVars.effectFns[C_Effect.RESIST_FIRE_DRUID] := @EffHndlr.EffResistFireDruid;
  @GDVars.effectFns[C_Effect.DRAGON_FEARED] := @EffHndlr.EffDragonFeared;
  @GDVars.effectFns[C_Effect.FIRE_TOUCH] := @EffHndlr.EffFireTouch;
  @GDVars.effectFns[C_Effect.IRON_SKIN] := @EffHndlr.EffIronSkin;
  @GDVars.effectFns[C_Effect.MIND_BLANK] := @EffHndlr.EffMindBlank;
  @GDVars.effectFns[C_Effect.IMMUNE_WEAPONS_UNDER_PLUS_2] := @EffHndlr.EffNeedPlus2;
  @GDVars.effectFns[C_Effect.IMMUNE_GAZE] := @EffHndlr.EffImmuneGaze;
  @GDVars.effectFns[C_Effect.ITEM_EFFECT] := @EffHndlr.EffGrantItemEffect;
end;

begin
end.
