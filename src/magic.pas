{ The spell menus, spell targeting and casting, one cast handler per spell id run through the spell dispatch table, and
  the effect handlers for the dragons' breath and the charming gaze. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Magic;

interface

uses Blit, Types, GDConsts, GDVars, Music, GameIo, FxEngine, CharHlp, ClassCal,
  MenuCore, Pathing, CbtMap, TextRend, Border, C_Effect, C_Class, C_Race, C_Keys, C_Status, C_Ifc, C_Stat,
  C_Cond, C_Dir, C_Npc, C_Spell, C_Terr, C_Equip;

{ Runs the spell menu over the list GenerateSpellList built and returns the chosen spell id, or 0 when the player leaves
  it. The selection type names the menu's action: 1 Cast, 2 Memorize, 3 Scribe (which also records the scroll being
  read), 4 Learn, 5 Keep; any other shows the bare list.
  @param(selType The menu's action.)
  @param(idx The highlighted entry, kept between calls; negative asks for a full redraw.)
  @returns(The chosen spell id, or 0.) }
function SpellSelection(selType: Byte; var idx: Integer): Byte;

{ Builds GDVars.currentChar's spell selector list and returns True when it is not empty. menuType 0 lists the memorized
  spells still to be cast, 5 those already cast, 1 the known spells there are slots for, 2 the spells on
  GDVars.castingItem, 3 the spells on every scroll carried, 6 the scribable ones, and 4 the magic-user spells
  GDVars.currentChar could learn. Lists built from spell ids get a heading line per spell level.
  @param(menuType Which spells are listed.)
  @returns(True when the list is not empty.) }
function GenerateSpellList(menuType: Byte): Boolean;

{ Computes a spell's range in combat cells: its base plus its per-level range at the caster's level, or at level 6 when
  cast from an item. Power Word Kill reaches a quarter of that; an area spell reaches at least 1 cell, and a range of
  $FF means touch, 1 cell.
  @param(s The spell.)
  @returns(The range in combat cells.) }
function CalcSpellRange(s: Byte): Byte;

{ The noncombat target selector, which runs from dispatch slot 0: the spell targets the caster, a character the player
  picks, or the whole party, as its targeting says. cast is False when nothing was chosen or the spell has no noncombat
  targeting. Combat puts its own aiming routine in slot 0.
  @param(spell The spell.)
  @param(b Unused.)
  @param(cast Receives False when nothing was chosen.) }
procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);

{ Casts a spell for the current character. Outside combat a combat-only spell is refused: from memory it offers to lose
  the spell, from an item it asks whether to use the item (the selected flag reports yes). With the announce flag set
  the cast is announced. Then the target selector picks the targets. Once picked, in combat (not for spell 124) the
  caster turns and a missile flies to the target (Fireball, Necklace Of Missiles, Flame Strike and spell 115 with their
  own missile; Fireball and Lightning Bolt with their own sound), and Stinking Cloud, Cloud Kill, Ice Storm and the
  fireball kinds burst. Invisibility ends, the memorized copy is spent (not for an item), and the spell's handler runs
  from the dispatch table. With no pick, combat asks whether to abort (the abort flag aborts at once) and spends the
  spell; outside combat it just stops.
  @param(spell The spell.)
  @param(b Nonzero aborts a canceled aim without asking; passed to the target selector.)
  @param(ai Nonzero announces the cast.)
  @param(sel Receives True when the cast went ahead.) }
procedure CastSpell(spell, b, ai: Byte; var sel: Boolean);

{ Tells whether an item is readable.
  @param(it The item, or nil.)
  @returns(True for a scroll: item type 39 or 40.) }
function ItemReadable(it: Pointer): Boolean;

{ Removes a spell from a scroll: the scroll's spell-count name part drops by one, and the scroll goes when none are left
  (name id below 100).
  @param(cr The character carrying the scroll.)
  @param(it The scroll.)
  @param(sp The spell to remove; bit 7 of the scroll's entries is ignored, and the last matching entry is cleared.) }
procedure RemoveSpellFromScroll(cr, it: Pointer; sp: Byte);

{ Reports a cast: in combat "Casts a Spell" and the spell's name on row 23; outside combat the caster's name, the given
  text and the spell's name in the text window, then a pause.
  @param(cr The caster.)
  @param(s Printed after the caster's name outside combat.)
  @param(id The spell cast.) }
procedure PrintCastSpellMsg(cr: Pointer; s: Types.TStr40; id: Byte);

{ Remove Curse: cures the target's strength-draining disease or, if it has none, unequips the first cursed item it
  carries and ends that item's magic. }
procedure SpellRemoveCurse;

{ Fills the spell dispatch table (slot 0 NoncombatCastTargetMenu, then spells 1..126) and the breath and gaze effect
  handlers, clears the effect-lock and using-item flags and sets the redraw flag. }
procedure InitSpellFns;

{ Casts Bless on the caster's own side. }
procedure SpellBless;

{ Casts Curse on the caster's enemies. }
procedure SpellCurse;

{ Cure Light Wounds: restores 1d8 hit points. }
procedure SpellCureLightWounds;

{ Casts Cause Light Wounds: 1d8 magic damage. }
procedure SpellCauseLightWounds;

{ Applies a detection spell's effect to the targets. }
procedure SpellDetection;

{ Applies a protection spell's effect to the targets. }
procedure SpellProtection;

{ Applies Resist Cold's effect to the targets. }
procedure SpellResistCold;

{ Casts Burning Hands: fire damage of 1 point per caster level. }
procedure SpellBurningHands;

{ Casts Charm Person: a monster without the charmable flag, or a creature bigger than one combat cell, is unaffected.
  The charm records the caster's side. }
procedure SpellCharmPerson;

{ Casts Enlarge: a Strength by caster level (18 with exceptional 0, 1, 51, 76, 91 and 100 for levels 1..6, then 19, 20,
  21, and 22 above); if it beats the target's and the target has neither Globe of Invulnerability nor Minor Globe of
  Invulnerability, the Enlarge effect makes it 'stronger'. }
procedure SpellEnlarge;

{ Casts Reduce: removes Enlarge from the target unless it saves against spells ("has been reduced"). }
procedure SpellReduce;

{ Casts Friends: the effect with strength 2d4, then the caster's Charisma is recalculated. }
procedure SpellFriends;

{ Casts Magic Missile: (caster level + 1) div 2 missiles of 1d4 + 1 magic damage. }
procedure SpellMagicMissile;

{ Applies Shield's effect to the targets. }
procedure SpellShield;

{ Casts Shocking Grasp: 1d8 plus the caster level in electrical damage. }
procedure SpellShockingGrasp;

{ Casts Sleep with a 4d4 hit-dice pool. Each target costs by its level: 0..1 costs 1, 2 costs 2, 3 costs 4, 4 costs 6, 5
  costs 10 for a creature of the monster race and 20 otherwise, and higher levels cost 20. Animated dead, targets
  already asleep and targets the remaining pool cannot pay for are dropped; the pool is spent greedily in target
  order. }
procedure SpellSleep;

{ Hold Person and Hold Monsters: puts the hold effect on up to four targets, with a save modifier by their number: -2 or
  -3 for one, depending on the spell, -1 for two and 0 for three or four. Note: more targets leave the modifier
  undefined. }
procedure SpellHold;

{ Applies Resist Fire's effect to the targets. }
procedure SpellResistFire;

{ Applies Silence's effect to the targets. }
procedure SpellSilence;

{ Casts Slow Poison: on a poisoned target that is not animated, raises 0 hit points to 1, sets it okay and in play,
  applies the spell and re-arms the poison damage for 10. }
procedure SpellSlowPoison;

{ Casts Snake Charm: charms snakes in play and not yet charmed whose hit points, in total, fit in the caster's current
  hit points. }
procedure SpellSnakeCharm;

{ Casts Spiritual Hammer: applies the spell's effect, then runs the Spiritual Hammer effect handler for the first
  target. }
procedure SpellSpiritualHammer;

{ Applies the Invisibility spells' effect to the targets. }
procedure SpellInvisibility;

{ Applies Knock's effect to the targets. }
procedure SpellKnock;

{ Mirror Image: 1d4 images, kept in the effect's top bits above the caster's level. }
procedure SpellMirrorImage;

{ Applies Ray of Enfeeblement's effect to the targets. }
procedure SpellRayOfEnfeeblement;

{ Casts Stinking Cloud, Cloud Kill or Blade Barrier: spreads a timed patch of cloud or blades over 4 or 9 cells around
  the target point, links it into the cloud list and lets every creature inside feel it at once. }
procedure SpellStinkingCloud;

{ Strength: raises Strength by a die that goes with the target's class (d4 magic-user, d6 cleric or thief, d8 fighter,
  paladin or ranger); a fighter type goes on into exceptional strength past 18. }
procedure SpellStrength;

{ Casts Heal: removes the target's diseases, blindness and feeblemindedness (recalculating Intelligence and Wisdom),
  then heals it to 1d4 below its maximum. Note: a target already within 1d4 of its maximum heals nothing. }
procedure SpellHeal;

{ Casts Cure Blindness: ends the first target's blindness ('can see'). }
procedure SpellCureBlindness;

{ Casts Cause Blindness: blinds the targets. }
procedure SpellCauseBlindness;

{ Casts Cure Disease: cures the target's disease effects ('cured'). }
procedure SpellCureDisease;

{ Casts Cause Disease, resolving the spell (run on removal) with the Diseased effect's name. }
procedure SpellCauseDisease;

{ Dispel Magic: each spell effect on each target goes on a percentile roll of 50, plus 5 for every level the caster has
  over the effect's level or minus 2 for every level under. In combat, clouds next to the target point are dispelled the
  same way. Note: for a cloud, the levels under are measured from the last effect level rolled against (spellTemp2), not
  from the cloud's own level. }
procedure SpellDispelMagic;

{ Prayer: the effect records the caster's side. }
procedure SpellPrayer;

{ Bestow Curse. }
procedure SpellBestowCurse;

{ Applies Blink's effect to the targets. }
procedure SpellBlink;

{ Fireball, Necklace of Missiles and Delayed Blast Fireball: a d6 per caster level (the necklace rolls its own count),
  plus the caster's level for Delayed Blast Fireball. Outdoors the blast takes in every creature within 2 cells of the
  target point. }
procedure SpellFireball;

{ Casts Haste on the caster's side; it removes Slow instead where there is one. }
procedure SpellHaste;

{ Lightning Bolt: a d6 per caster level along a bolt 7 cells long. }
procedure SpellLightningBolt;

{ Casts Slow on the caster's enemies; it removes Haste instead where there is one. }
procedure SpellSlow;

{ Casts Harm: diseases the target and leaves it 1d4 hit points. }
procedure SpellHarm;

{ Removes Slow from the target, or else applies the Potion of Speed's effect. }
procedure SpellPotionOfSpeed;

{ Casts Cure Serious Wounds: heals the target 2d8 + 1. }
procedure SpellCureSeriousWounds;

{ Gives the target frost giant strength: Strength 21 for 1d4 * 10 + 40, announced when that beats the target's own; the
  effect is added either way. }
procedure SpellGiantStrength;

{ Javelin of Lightning: a 20-point bolt 3 cells long. }
procedure SpellJavelinOfLightning;

{ Applies the Wand of Paralyzation's effect to the targets ("is paralyzed"). }
procedure SpellWandOfParalyzation;

{ Heals the first target 2d4 + 2 hit points for the Potion of Healing. }
procedure SpellPotionOfHealing;

{ Makes the caster 1d4 + 1 years younger, but no younger than 18. }
procedure SpellYouth;

{ Deals the Wand of Magic Missiles' 2d4 + 2 magic damage. }
procedure SpellWandOfMagicMissiles;

{ Casts Cause Serious Wounds: deals 2d8 + 1 magic damage. }
procedure SpellCauseSeriousWounds;

{ Casts Neutralize Poison: cures the poison of a target that is not animated (Poisoned and both slow-poison effects
  removed with the effect lock), raising 0 hit points to 1 and setting it okay; an unpoisoned target "is unaffected". }
procedure SpellNeutralizePoison;

{ Casts Poison: applies the spell, then, unless the effects of the caster's target cancel the poison attack, runs the
  poison attack's handler (a poison bite) for the caster. }
procedure SpellPoison;

{ Casts Sticks to Snakes: a first target below attack level 6 takes the spell's effect at the caster's level and has the
  snakes effect's handler run if it already has it; a stronger one, unless helpless, 'smashes them flat'. }
procedure SpellSticksToSnakes;

{ Casts Cure Critical Wounds: heals the target 3d8 + 3. }
procedure SpellCureCriticalWounds;

{ Casts Cause Critical Wounds: deals 3d8 + 3 magic damage. }
procedure SpellCauseCriticalWounds;

{ Casts Dispel Evil: gives the caster the dispel evil effect for the spell's duration and applies the spell. }
procedure SpellDispelEvil;

{ Flame Strike: 6d8 damage. }
procedure SpellFlameStrike;

{ Casts Raise Dead: raises a dead or animated target that is not an elf and has Constitution left: its poison is removed
  under the effect lock, it becomes okay with 1 hit point and loses a point of base Constitution ("is raised"). }
procedure SpellRaiseDead;

{ Casts Slay Living: unless the first target's effects cancel it (then it 'is unaffected'), the target is slain ('is
  slain') when it fails a saving throw (type 4) and lacks immunity bit 8; otherwise it takes 2d8 + 1 magic damage. }
procedure SpellSlayLiving;

{ Entangle: works only outdoors. }
procedure SpellEntangle;

{ Casts Faerie Fire: ApplyEffectToTargets ("is highlighted"). }
procedure SpellFaerieFire;

{ Invisibility to Animals: makes the targets invisible, each with the message 'is invisible'. }
procedure SpellInvisibilityToAnimals;

{ Casts Charm Monsters: ApplyEffectToTargets ("is charmed"), then the charm handler for each charmed target. }
procedure SpellCharmMonsters;

{ Casts Confusion: with the multi-target flag raised throughout, at most 2d8 targets each save (type 4) or are confused
  for the spell's duration ('is confused'). }
procedure SpellConfusion;

{ Casts Dimension Door: erases the caster's icon, places it on the target cell, scrolls the view to it and reports
  "teleports". Note: the placement's result is ignored. }
procedure SpellDimensionDoor;

{ Casts Fear: with the multi-target flag raised throughout, a cone of 3 rays reaching 6 from the caster toward the
  target cell. Each target that fails a save (type 4) gets the fear effect for the spell's duration ('runs in terror')
  and, if the effect took, flees: fleeing and quick fight set, NPC value $B3 unless above $7F, combat target cleared.
  One that saves 'is unaffected'. }
procedure SpellFear;

{ Casts Fire Shield: the caster picks hot or cold flames (the computer at random), which shield it and zap its
  attackers; declining asks whether to abort the spell. }
procedure SpellFireShield;

{ Casts Fumble: a first target that fails a save (type 4) becomes clumsy ('is clumsy'), one that saves is slowed ('is
  slowed'), each effect with its handler run; then the spell's table effect is resolved on the targets as well ('is
  clumsy'). }
procedure SpellFumble;

{ Ice Storm: 3d10 damage. }
procedure SpellIceStorm;

{ Minor Globe of Invulnerability: protects the targets, each with the message 'is protected'. }
procedure SpellMinorGlobeOfInvulnerability;

{ Barkskin: gives the targets the barkskin effect. }
procedure SpellBarkskin;

{ Casts Cone of Cold: sets the multi-target flag; a cone of 2 rays toward the target cell, reaching (caster level + 1)
  div 2 cells, at least 1, deals caster level + caster-level d4 cold damage (element mask 10). }
procedure SpellConeOfCold;

{ Feeblemind: the target's save is adjusted by its class for the roll (cleric -1, magic-user +4, others +2). A
  feebleminded target also loses the spells it has already cast from memory. }
procedure SpellFeeblemind;

{ Scroll of Protection. }
procedure SpellScrollOfProtection;

{ Casts Charm Person or Mammal: charms the target when it is a person (a race below monster) or a creature of type bit
  2, then runs the charm's handler; the charm's strength holds the caster's team in bit 7 and the caster level. Any
  other target is not charmed. }
procedure SpellCharmPersonOrMammal;

{ Potion of Invisibility. }
procedure SpellPotionOfInvisibility;

{ Cure Light Wounds: restores 1d8 hit points. }
procedure SpellDruidCureLightWounds;

{ Potion of Extra Healing: restores 2d4+2 hit points. }
procedure SpellPotionOfExtraHealing;

{ Bestow Curse. }
procedure SpellMageBestowCurse;

{ Restoration: gives back one drained level, in the class whose next level costs the least experience, with a share of
  the hit points the drain took. }
procedure SpellRestoration;

{ Energy Drain: the caster drains a level from the target through the level-drain effect handler. }
procedure SpellEnergyDrain;

{ Destruction: unless magic resistance (condition 9, element $48) or immunities bit 3 stops it, the target 'is
  destroyed'; otherwise it 'is unaffected'. }
procedure SpellDestruction;

{ Resurrection: brings back a dead target that is not an elf and has constitution left, at full hit points and cured of
  poison. }
procedure SpellResurrection;

{ Hold Animal: the fewer the targets, the harder the save. }
procedure SpellHoldAnimal;

{ Protection from Fire: a ranger gets the druid's form of the protection, anyone else the spell's. }
procedure SpellProtectionFromFire;

{ Casts Death Spell: spends a budget of 2 * 4d20 on the targets in order, each costing by its hit dice (0: 1, 1: 2, 2-3:
  8, 4-5: 16, 6: 16 up to 51 maximum hit points else 20, 7-8: 20, more: 162). A target the budget covers that magic
  resistance (element $40) and immunities bit 3 do not protect drops dead; the rest leave the list. }
procedure SpellDeathSpell;

{ Casts Disintegrate: unless magic resistance (element $48) stops it, a target that fails its saving throw disintegrates
  and loses its items; otherwise it is unaffected. }
procedure SpellDisintegrate;

{ Casts Globe of Invulnerability: applies its effect, protecting the targets. }
procedure SpellGlobeOfInvulnerability;

{ Casts Stone to Flesh: restores a petrified target with 1 hit point; in combat it rises from among the downed. }
procedure SpellStoneToFlesh;

{ Casts Flesh to Stone: unless the target's effects cancel it, the target turns to stone on a failed save against
  spells. }
procedure SpellFleshToStone;

{ Casts Mass Invisibility on the caster's side, in combat passing over those with an enemy next to them. }
procedure SpellMassInvisibility;

{ Casts Power Word Stun: stuns the target for 4d4 rounds at up to 30 hit points, 2d4 up to 60, 1d4 up to 90, and not at
  all above. }
procedure SpellPowerWordStun;

{ Fire Touch: covers the targets in flame. }
procedure SpellFireTouch;

{ Iron Skin: protects the targets. }
procedure SpellIronSkin;

{ Mass Charm: charms enemies, up to twice the caster's level in total hit dice, each saving at -2. A creature without
  the charmable flag, one bigger than one combat cell, or one of the caster's side is unaffected. }
procedure SpellMassCharm;

{ Otto's Irresistible Dance: on a hit, the target dances helplessly. }
procedure SpellIrresistibleDance;

{ Power Word Blind: blinds targets until their maximum hit points pass 100 in all. }
procedure SpellPowerWordBlind;

{ Meteor Swarm: four meteors, one per aim mode, each landing on or beside the target point. A creature on a meteor's
  path takes 10d4; one caught in its blast takes 10d4, halved by a save. Note: dir is never reset before the facing
  search. }
procedure SpellMeteorSwarm;

{ Power Word Kill: slays one target of 11 to 60 hit points or, failing that, every target of 10 or less. }
procedure SpellPowerWordKill;

{ Monster Summoning: gates in up to two waiting creatures on the caster's side, each on a free cell of the area's open
  ground next to a combatant. }
procedure SpellMonsterSummoning;

{ Breathes poison, as an effect handler: three uses from round 0, with the multi-target flag raised throughout. With a
  target chosen, it breathes on the creatures within 3 cells of the end of a 3-cell line toward it, each taking the
  breather's maximum hit points, half on save 3; then a use is spent and its turn ends. Nothing happens when no target
  is caught.
  @param(cr The creature the effect is on.)
  @param(eff The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffBreathePoison(var cr: Pointer; eff: Pointer; removed: Boolean);

{ Lightning breath effect: up to three uses a battle, the count set to 3 in round 0 and kept at 3 or less. With a target
  chosen, aiming as for Lightning Bolt, it breathes lightning along a 9-cell path doing the breather's maximum hit
  points; then a use is spent and its turn ends.
  @param(cr The creature the effect is on.)
  @param(eff The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffBreatheLightning(var cr: Pointer; eff: Pointer; removed: Boolean);

{ Breathes as a red, white or black dragon, as an effect handler: three times a fight, a cone of fire or cold or a line
  of acid that does the dragon's hit points in damage, halved by a save. The biggest red dragon breathes 24d10+12. The
  dragon will not breathe while a creature of its own side is in the way. The multi-target flag is raised while it runs.
  @param(cr The creature the effect is on.)
  @param(eff The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffDragonBreath(var cr: Pointer; eff: Pointer; removed: Boolean);

{ A charming gaze: when a target is chosen, the creature gazes and casts Charm Person on it.
  @param(cr The creature the effect is on.)
  @param(eff Unused.)
  @param(removed Unused.) }
procedure EffGazeCharm(var cr: Pointer; eff: Pointer; removed: Boolean);
implementation

const
  { effect id }
  EFF_CHARM_GAZE = 124;
  { soundIds entries }
  SOUND_SPELL = 2;
  SOUND_LIGHTNING = 8;
  SOUND_FIREBALL = 11;

procedure ResolveSpell(spell, effectId: Byte; onRemove: Boolean; damage, element: Word; msg: Types.TStr40); forward;

function CalcSpellDuration(spell: Byte): Word; forward;

procedure CollectConeTargets(x, y, tx, ty: ShortInt; rays, reach: Byte); forward;

procedure HasteSlowLogic(effectId: Byte; side: ShortInt; msg: Types.TStr40); forward;

function ClassCanCastSpell(cr: Types.PCharRecord; spell: Byte; fromItem: Boolean): Boolean; forward;

procedure AddSpellToList(spell: Byte); forward;

procedure AddScrollSpellLine(spell: Byte); forward;

procedure AddScrollSpells(forScribe, oneItem: Boolean); forward;

procedure AddAllScrollSpells(forScribe, allItems: Boolean); forward;

{ Tells whether a character can cast a spell by class. A cleric spell needs Wisdom over 8 and either cleric levels or a
  paladin past level 8; a druid spell, Wisdom over 8 and a ranger past level 6; a magic-user spell, Intelligence over 8
  and either magic-user levels, a ranger past level 8 or, when read from an item, a thief past level 10. A human
  magic-user cannot cast in combat with something in equipment slot 2. Magic-item spells are never cast this way.
  @param(cr The caster.)
  @param(spell The spell.)
  @param(fromItem True when the spell is read from an item.)
  @returns(True when the character can cast it.) }
function ClassCanCastSpell(cr: Types.PCharRecord; spell: Byte; fromItem: Boolean): Boolean;
begin
  spell := spell and C_Spell.ID_MASK;
  ClassCanCastSpell := False;
  case GDConsts.spellTable[spell].castClass of
    C_Spell.CLERIC_LIST: ClassCanCastSpell := Boolean(cr^.stats[C_Stat.WISDOM].cur > 8) and
      ((ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.CLERIC) > 0) or
       (ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.PALADIN) > 8));
    C_Spell.DRUID_LIST: ClassCanCastSpell := Boolean(cr^.stats[C_Stat.WISDOM].cur > 8) and
      (ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.RANGER) > 6);
    C_Spell.MAGIC_USER_LIST: if cr^.stats[C_Stat.INTELLIGENCE].cur > 8 then begin
         if ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.MAGE) > 0 then
           if (cr^.race <> C_Race.HUMAN) or (cr^.equipped[C_Equip.ARMOR] = nil) or
               (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then
             ClassCanCastSpell := True;
         if ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.RANGER) > 8 then
           ClassCanCastSpell := True;
         if fromItem and (ClassCal.EffectiveClassLevel(Types.PCharRecord(cr), C_Class.THIEF) > 10) then
           ClassCanCastSpell := True
       end;
    C_Spell.ITEM_LIST: ClassCanCastSpell := False
  end
end;

function SpellSelection(selType: Byte; var idx: Integer): Byte;
var
  item: Types.PMenuLine;
  scan: Types.PMenuLine;
  prompt: Types.TStr40;
  title: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  count: Byte;
  bottomRow: Byte;
  ch: Char;
  addExit: Boolean;
  redraw: Boolean;
  initial: Byte;
begin
  prompt := GDConsts.chooseSpellPrompt;
  bottomRow := 22;
  initial := 0;
  MenuCore.ResetMenuSlots(0);
  redraw := False;
  GDVars.horizMenuChoice := 1;
  case selType of
    1: title := GDConsts.castMenu;
    2: begin
         title := GDConsts.memorizeMenu;
         bottomRow := 15;
         redraw := Boolean(GDVars.sharedScratch.memorizeRedraw)
       end;
    3: title := GDConsts.scribeMenu;
    4: title := GDConsts.learnMenu;
    5: begin
         prompt := GDConsts.spellsOkPrompt;
         title := GDConsts.keepMenu
       end else
    initial := $FF;
    title := GDConsts.blankPrompt;
    prompt := GDConsts.emptyQuery
  end;
  addExit := selType <> 4;
  if idx < 0 then begin
    redraw := True;
    idx := 0
  end;
  if (selType = 4) or (selType = 1) then redraw := True;
  item := nil;
  repeat
    ch := MenuCore.MenuVertical(prompt, title, 1, 5, 38, bottomRow, GDVars.selectorVars.spellList, addExit, initial,
                                redraw, idx, item)
  until (ch = #0) or (ch = C_Keys.ESCAPE);
  scan := GDVars.selectorVars.spellList;
  count := 0;
  while scan <> item do begin
    if scan^.inUse = 0 then Inc(count);
    scan := scan^.next
  end;
  if ch <> #0 then
    SpellSelection := 0
  else
    SpellSelection := GDVars.selectorVars.spellIds[count];
  if selType = 3 then GDVars.castingItem := GDVars.selectorVars.scrollPtrs[count];
  MenuCore.FreeStringList(GDVars.selectorVars.spellList)
end;

{ Appends a spell to the scroll spell list (and its id list), with a level heading when its level differs from the last
  spell's.
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddScrollSpellLine(spell: Byte);
var
  item: Types.PMenuLine;
  count: ShortInt;
  lastLevel: Byte;
begin
  item := GDVars.selectorVars.spellList;
  if GDVars.selectorVars.spellList = nil then begin
    GetMem(item, SizeOf(Types.TMenuLine));
    GDVars.selectorVars.spellList := item;
    lastLevel := 0;
    count := 0
  end else begin
    count := 1;
    while item^.next <> nil do begin
      if item^.inUse = 0 then Inc(count);
      item := item^.next
    end;
    lastLevel := GDConsts.spellTable[GDVars.selectorVars.spellIds[count - 1]].level;
    GetMem(item^.next, SizeOf(Types.TMenuLine));
    item := item^.next
  end;
  item^.next := nil;
  if GDConsts.spellTable[spell and C_Spell.ID_MASK].level <> lastLevel then begin
    item^.name := GDConsts.spellLevelNames[GDConsts.spellTable[spell and C_Spell.ID_MASK].level];
    item^.inUse := 1;
    GetMem(item^.next, SizeOf(Types.TMenuLine));
    item := item^.next;
    item^.next := nil
  end;
  if spell > C_Spell.ID_MASK then
    item^.name := ' *'
  else
    item^.name := '  ';
  item^.name := item^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  item^.inUse := 0;
  GDVars.selectorVars.spellIds[count] := spell and C_Spell.ID_MASK
end;

{ Adds a spell to the menu list (and its id list), before the first spell of a higher level; a repeat of the same spell
  is merged into a count "(n)".
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddSpellToList(spell: Byte);
var
  carry: Byte;
  tmp: Byte;
  item: Types.PMenuLine;
  scan: Types.PMenuLine;
  newNode: Types.PMenuLine;
  count: ShortInt;
  k: Byte;
  found: Boolean;
  newLevel: Byte;
begin
  item := GDVars.selectorVars.spellList;
  found := False;
  newLevel := GDConsts.spellTable[spell and C_Spell.ID_MASK].level;
  if GDVars.selectorVars.spellList = nil then begin
    GameIo.ZeroFill(GDVars.selectorVars.spellCounts, SizeOf(GDVars.selectorVars.spellCounts));
    GetMem(item, SizeOf(Types.TMenuLine));
    item^.next := nil;
    GDVars.selectorVars.spellList := item;
    count := 0;
    GDVars.selectorVars.spellCounts[count] := 1
  end else begin
    count := 0;
    while (item <> nil) and not found do begin
      if item^.inUse = 0 then begin
        if not ((GDConsts.spellTable[GDVars.selectorVars.spellIds[count]].level > newLevel) or
                (GDVars.selectorVars.spellIds[count] = (spell and C_Spell.ID_MASK))) then begin
          Inc(count);
          item := item^.next
        end else
          found := True
      end else begin
        item := item^.next;
        Inc(count)
      end
    end;
    if GDVars.selectorVars.spellIds[count] <> (spell and C_Spell.ID_MASK) then begin
      scan := GDVars.selectorVars.spellList;
      if scan <> item then begin
        while scan^.next <> item do scan := scan^.next;
        GetMem(newNode, SizeOf(Types.TMenuLine));
        newNode^.next := scan^.next;
        scan^.next := newNode;
        item := newNode
      end else begin
        GetMem(newNode, SizeOf(Types.TMenuLine));
        newNode^.next := item;
        GDVars.selectorVars.spellList := newNode;
        item := newNode
      end;
      carry := 1;
      for k := count to 140 do begin
        tmp := GDVars.selectorVars.spellCounts[k];
        GDVars.selectorVars.spellCounts[k] := carry;
        carry := tmp
      end
    end else
      Inc(GDVars.selectorVars.spellCounts[count])
  end;
  if spell > C_Spell.ID_MASK then
    item^.name := ' *'
  else
    item^.name := '  ';
  item^.name := item^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  item^.inUse := 0;
  if GDVars.selectorVars.spellCounts[count] > 1 then
    item^.name := item^.name + ' (' + CharHlp.Uint8Str(GDVars.selectorVars.spellCounts[count]) + ')';
  if GDVars.selectorVars.spellIds[count] <> (spell and C_Spell.ID_MASK) then begin
    carry := GDVars.selectorVars.spellIds[count];
    GDVars.selectorVars.spellIds[count] := spell and C_Spell.ID_MASK;
    for k := count + 1 to 140 do begin
      tmp := GDVars.selectorVars.spellIds[k];
      GDVars.selectorVars.spellIds[k] := carry;
      carry := tmp
    end
  end
end;

{ Adds GDVars.castingItem's spells to the selector list and remembers the scroll for each line. Reading Magic, or a
  cleric reading an equipment-slot-12 scroll, identifies the scroll first, and an unidentified scroll adds nothing.
  forScribe lists only the spells that can be scribed; oneItem leaves out slot-12 scrolls.
  @param(forScribe True lists only the spells that can be scribed.)
  @param(oneItem True leaves out slot-12 scrolls.) }
procedure AddScrollSpells(forScribe, oneItem: Boolean);
var
  i: Byte;
  eff: Pointer;
begin
  if oneItem and (GDVars.baseItemTable[GDVars.castingItem^.definition.itemType].slot = 12) then
    Exit;
  if CharHlp.HasEffect(GDVars.currentChar, C_Effect.READ_MAGIC, eff) or
      ((ClassCal.EffectiveClassLevel(GDVars.currentChar, C_Class.CLERIC) > 0) and
       (GDVars.baseItemTable[GDVars.castingItem^.definition.itemType].slot = 12)) then
    GDVars.castingItem^.definition.unidMask := GDVars.castingItem^.definition.unidMask and $F8;
  if (GDVars.castingItem^.definition.unidMask and 7) = 0 then
    for i := 1 to 3 do
      if (forScribe and (GDVars.castingItem^.definition.scrollSpells[i] > C_Spell.PENDING_FLAG)) or
          ((not forScribe) and (GDVars.castingItem^.definition.scrollSpells[i] > 0)) then begin
        Magic.AddScrollSpellLine(GDVars.castingItem^.definition.scrollSpells[i]);
        GDVars.selectorVars.scrollPtrs[GDVars.selectorVars.scrollCount] := GDVars.castingItem;
        Inc(GDVars.selectorVars.scrollCount)
      end
end;

{ Adds the spells of every scroll GDVars.currentChar carries to the selector list.
  @param(forScribe Passed to AddScrollSpells.)
  @param(allItems Passed to AddScrollSpells as its oneItem.) }
procedure AddAllScrollSpells(forScribe, allItems: Boolean);
var
  i: Byte;
begin
  for i := 0 to 48 do GDVars.selectorVars.scrollPtrs[i] := nil;
  GDVars.selectorVars.scrollCount := 0;
  GDVars.castingItem := GDVars.currentChar^.items;
  while GDVars.castingItem <> nil do begin
    if Magic.ItemReadable(GDVars.castingItem) then
      Magic.AddScrollSpells(forScribe, allItems);
    GDVars.castingItem := GDVars.castingItem^.next
  end
end;

function GenerateSpellList(menuType: Byte): Boolean;
var
  classIdx: Byte;
  i: Integer;
  item: Types.PMenuLine;
  newNode: Types.PMenuLine;
  prevLevel: Byte;
  level: Byte;
  doBuild: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  headingAdded: Byte;
begin
  doBuild := True;
  GenerateSpellList := False;
  GDVars.selectorVars.spellList := nil;
  GameIo.ZeroFill(GDVars.selectorVars.spellIds, SizeOf(GDVars.selectorVars.spellIds));
  with GDVars.currentChar^ do begin
  case menuType of
    0: for i := 0 to 140 do
         if (spells[i] > 0) and
             Magic.ClassCanCastSpell(GDVars.currentChar, spells[i] and C_Spell.ID_MASK, False) and
             (spells[i] < C_Spell.PENDING_FLAG) then
           Magic.AddSpellToList(spells[i]);
    5: for i := 0 to 140 do
         if (GDVars.currentChar^.spells[i] > C_Spell.ID_MASK) and
             Magic.ClassCanCastSpell(GDVars.currentChar, spells[i] and C_Spell.ID_MASK, False) then
           Magic.AddSpellToList(spells[i]);
    1: for i := 1 to 126 do
         if (knownSpells[i] <> 0) and
             (spellSlots[ShortInt(GDConsts.spellTable[i].castClass), GDConsts.spellTable[i].level] > 0) and
             Magic.ClassCanCastSpell(GDVars.currentChar, i, False) then
           Magic.AddSpellToList(i);
    2: begin
         GDVars.selectorVars.scrollCount := 0;
         Magic.AddScrollSpells(False, False);
         doBuild := False
       end;
    3: begin Magic.AddAllScrollSpells(False, True); doBuild := False end;
    6: begin Magic.AddAllScrollSpells(True, True); doBuild := False end;
    4: for classIdx := 1 to 126 do begin
         level := GDConsts.spellTable[classIdx].level;
         if (spellSlots[C_Spell.MAGIC_USER_LIST, level] > 0) and
             (GDConsts.spellTable[classIdx].castClass = C_Spell.MAGIC_USER_LIST) and (knownSpells[classIdx] = 0) then
           Magic.AddSpellToList(classIdx)
       end
  end;
  end;
  if GDVars.selectorVars.spellList <> nil then begin
    if doBuild then begin
      i := 0;
      level := GDConsts.spellTable[GDVars.selectorVars.spellIds[i]].level;
      GetMem(newNode, SizeOf(Types.TMenuLine));
      newNode^.next := GDVars.selectorVars.spellList;
      GDVars.selectorVars.spellList := newNode;
      GDVars.selectorVars.spellList^.name :=
        GDConsts.spellLevelNames[GDConsts.spellTable[GDVars.selectorVars.spellIds[i]].level];
      GDVars.selectorVars.spellList^.inUse := 1;
      item := GDVars.selectorVars.spellList;
      repeat
        prevLevel := level;
        if GDVars.selectorVars.spellIds[i] <> 0 then
          level := GDConsts.spellTable[GDVars.selectorVars.spellIds[i]].level;
        if prevLevel < level then begin
          GetMem(newNode, SizeOf(Types.TMenuLine));
          newNode^.next := item^.next;
          item^.next := newNode;
          item := item^.next;
          item^.name := GDConsts.spellLevelNames[level];
          item^.inUse := 1
        end;
        Inc(i);
        item := item^.next
      until item = nil
    end;
    GenerateSpellList := True
  end
end;

function CalcSpellRange(s: Byte): Byte;
var
  spellRange: Byte;
begin
  if GDVars.castFromItem = 0 then
    spellRange := GDConsts.spellTable[s].rangeFixed + GDConsts.spellTable[s].rangeVar * CharHlp.GetCasterLevel(s, False)
  else
    spellRange := GDConsts.spellTable[s].rangeVar * 6 + GDConsts.spellTable[s].rangeFixed;
  if s = 125 then spellRange := spellRange div 4;
  if (spellRange = 0) and (GDConsts.spellTable[s].area <> 0) then spellRange := 1;
  if spellRange = $FF then spellRange := 1;
  CalcSpellRange := spellRange
end;

{ The duration of spell's effect: its base plus its per-level duration at the caster's level, except for Slow Poison,
  Potion of Speed, Potion of Frost, Wand of Paralyzation, Otto's Irresistible Dance and Mind Blank, which have their
  own.
  @param(spell The spell.)
  @returns(The duration.) }
function CalcSpellDuration(spell: Byte): Word;
var
  d: Word;
begin
  case spell of
    26: d := 3780;
    57, 61: d := FxEngine.RollDice(5, 4);
    59: d := FxEngine.RollDice(1, 4) * 10 + 40;
    122: d := 1440;
    121: d := FxEngine.RollDice(1, 4) + 1;
  else
    d := GDConsts.spellTable[spell].durFixed + GDConsts.spellTable[spell].durVar * CharHlp.GetCasterLevel(spell, False)
  end;
  CalcSpellDuration := d
end;

{ Applies a spell to each target. The save is rolled only when the spell has a saving throw. A spell of fixed range 255
  needs an attack roll as well; a miss counts as saved and zeroes the damage for this and each later target. The damage
  is dealt with the save reducing it, and the spell's effect, if any, is added. With no targets it returns at once,
  leaving the element mask set.
  @param(spell The spell.)
  @param(effectId The effect's strength; 0 for the casting level.)
  @param(onRemove True to call the effect's handler when it is removed.)
  @param(damage The damage; 0 for none.)
  @param(element The damage's element mask.)
  @param(msg Printed after each target's name when the effect takes hold.) }
procedure ResolveSpell(spell, effectId: Byte; onRemove: Boolean; damage, element: Word; msg: Types.TStr40);
var
  effLevel: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  tgt: Types.PCharRecord;
  saved: Boolean;
begin
  if damage = 0 then GDVars.elementMask := 0 else GDVars.elementMask := element;
  if GDVars.spellTargetTotal = 0 then Exit;
  if effectId = 0 then
    effLevel := CharHlp.GetCasterLevel(spell, True)
  else
    effLevel := effectId;
  for i := 1 to GDVars.spellTargetTotal do
    if GDVars.spellTargetList[i] <> nil then begin
      if GDConsts.spellTable[spell].saveResult = 0 then
        saved := False
      else
        saved := FxEngine.RollSavingThrow(GDVars.spellTargetList[i], GDConsts.spellTable[spell].saveType, 0);
      if GDConsts.spellTable[GDVars.spellBeingCast].rangeFixed = $FF then begin
        CharHlp.RecalcStats(GDVars.spellTargetList[i]);
        FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_ARMOR_CLASS, GDVars.spellTargetList[i]);
        if not FxEngine.AttackRoll(GDVars.currentChar, GDVars.spellTargetList[i],
                                   GDVars.spellTargetList[i]^.armorClass[0]) then begin
          damage := 0;
          saved := True
        end
      end;
      if damage > 0 then
        FxEngine.InflictNonWeaponDamage(GDVars.spellTargetList[i], damage, GDConsts.spellTable[spell].saveResult,
                                        saved);
      if GDConsts.spellTable[spell].effect > 0 then
        FxEngine.AddEffectWithMessage(GDVars.spellTargetList[i], GDConsts.spellTable[spell].effect,
                                      Magic.CalcSpellDuration(spell), effLevel, Byte(onRemove),
                                      GDConsts.spellTable[spell].saveResult, Byte(saved), msg)
    end;
  GDVars.elementMask := 0
end;

procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  target: Pointer;
begin
  GDVars.spellTargetList[1] := GDVars.currentChar;
  GDVars.spellTargetTotal := 1;
  cast := True;
  case GDConsts.spellTable[spell].target of
    1: ;
    2: begin
         CharHlp.DisplayNoncombatInterface;
         if GDVars.castTarget <> nil then GDVars.spellTargetList[1] := GDVars.castTarget;
         CharHlp.SelectChar('Cast Spell on whom', True, 1, Pointer(GDVars.spellTargetList[1]));
         GDVars.castTarget := GDVars.spellTargetList[1];
         if GDVars.spellTargetList[1] = nil then begin
           GDVars.spellTargetTotal := 0;
           cast := False
         end
       end;
    3: begin
         GDVars.spellTargetList[GDVars.spellTargetTotal] := GDVars.creatureListHead;
         while GDVars.spellTargetList[GDVars.spellTargetTotal]^.next <> nil do begin
           GDVars.spellTargetList[GDVars.spellTargetTotal + 1] := GDVars.spellTargetList[GDVars.spellTargetTotal]^.next;
           Inc(GDVars.spellTargetTotal)
         end
       end else
    cast := False
  end
end;

procedure CastSpell(spell, b, ai: Byte; var sel: Boolean);
var
  ok: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  x: ShortInt;
  y: ShortInt;
  k: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mr: Byte;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  buf: array[0..3] of Byte;
  pace: Byte;
begin
  p := GDVars.currentChar;
  ok := True;
  if (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (GDConsts.spellTable[spell].target = 0) then begin
    if GDVars.castFromItem = 0 then begin
      TextRend.DisplayString(1, 19, 10, 0, GDConsts.spellNames[spell]);
      TextRend.DisplayString(1, 20, 10, 0, GDConsts.cantCastHereMsg);
      if MenuCore.YesNoMenu(GDConsts.loseItemPrompt, GDConsts.yesChoice) = GDConsts.yesChoice then
        CharHlp.RemoveSpell(p, spell)
    end else begin
      TextRend.DisplayString(1, 19, 10, 0, GDConsts.thatItemMsg);
      TextRend.DisplayString(1, 20, 10, 0, GDConsts.combatOnlyItemMsg);
      if MenuCore.YesNoMenu(GDConsts.useItemPrompt, GDConsts.yesChoice) = GDConsts.yesChoice then
        sel := True
    end;
    ai := 0;
    ok := False
  end;
  if (ai <> 0) and (GDVars.castFromItem = 0) then Magic.PrintCastSpellMsg(p, GDConsts.castsWord, spell);
  while ok do begin
    GDVars.spellFps.castMenu(spell, b, sel);
    if sel then begin
      ok := False;
      if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (spell <> 124) then begin
        if spell in [47, 64, 74, 115] then
          Blit.BuildIconFrames(30)
        else
          Blit.BuildIconFrames(17);
        x := CbtMap.CombatCellX(Types.PCharRecord(p));
        y := CbtMap.CombatCellY(Types.PCharRecord(p));
        k := 0;
        while not Pathing.IsDirToward(x, y, GDVars.gTargetX, GDVars.gTargetY, k) do Inc(k);
        if spell in [47, 64, 74, 115] then begin
          pace := 1;
          CharHlp.BuildIconFacingsDir(k, 30)
        end else
          pace := 4;
        GDVars.combatGfxOn := 1;
        CbtMap.SetCreatureFacing(Types.PCharRecord(p), k, 1, 0);
        case spell of
          47: Music.SendSoundCommand(GDConsts.soundIds[Magic.SOUND_FIREBALL]);
          51: Music.SendSoundCommand(GDConsts.soundIds[Magic.SOUND_LIGHTNING])
        else
          Music.SendSoundCommand(GDConsts.soundIds[Magic.SOUND_SPELL])
        end;
        CharHlp.CombatAnimateMovingIcon(x, y, GDVars.gTargetX, GDVars.gTargetY, pace, 30);
        case spell of
          34: CharHlp.ScatterCombatIcon(1, 25, Byte(GDConsts.soundIds[Magic.SOUND_FIREBALL]));
          91: CharHlp.ScatterCombatIcon(1, 26, Byte(GDConsts.soundIds[Magic.SOUND_FIREBALL]));
          64, 47, 115:
            if (GDVars.vmBand.zone0^.inDungeon = 0) or (spell = 64) then
              CharHlp.ScatterCombatIcon(2, 23, Byte(GDConsts.soundIds[Magic.SOUND_FIREBALL]))
            else
              CharHlp.ScatterCombatIcon(3, 23, Byte(GDConsts.soundIds[Magic.SOUND_FIREBALL]));
          87: CharHlp.ScatterCombatIcon(2, 24, Byte(GDConsts.soundIds[Magic.SOUND_FIREBALL]))
        end;
        if CbtMap.CombatIconVisible(Types.PCharRecord(p), 0) then begin
          CbtMap.SetCreatureFacing(Types.PCharRecord(p), p^.combatAddr^.direction, 1, 1);
          CbtMap.SetCreatureFacing(Types.PCharRecord(p), p^.combatAddr^.direction, 0, 0)
        end
      end;
      FxEngine.RemoveInvisibility(p);
      if (GDVars.castFromItem = 0) and (spell > 0) then CharHlp.RemoveSpell(p, spell);
      GDVars.spellBeingCast := spell;
      GDVars.spellFps.spells[GDVars.spellBeingCast];
      GDVars.spellBeingCast := 0;
      GDVars.gMultiTarget := 0
    end else if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
      ok := False
    else if (b <> 0) or
      (MenuCore.YesNoMenu(GDConsts.abortSpellPrompt, GDConsts.yesChoice) = GDConsts.yesChoice) then begin
      CharHlp.PrintBottomLine(GDConsts.spellAbortedMsg);
      if (GDVars.castFromItem = 0) and (spell > 0) then CharHlp.RemoveSpell(p, spell);
      ok := False
    end
  end;
  CharHlp.ClearMessageWindow;
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then Border.ClearBox(0, 23, 39, 23)
end;

{ Fills the spell targets with the creatures, other than the caster, on a line from the origin through the aimed cell,
  extended to the cone's length and cut short by walls, and with two or three rays on one or two more lines to cells
  beside its end; 255 rays take instead the creatures within 3 cells of the line's end. Note: once a creature has been
  met twice on the main line, no later creature on it is added; and the area list of 255 rays overwrites the line's list
  without ending it, so creatures past its length stay.
  @param(x The column of the cone's origin.)
  @param(y The row of the cone's origin.)
  @param(tx The column of the aimed cell.)
  @param(ty The row of the aimed cell.)
  @param(rays The number of lines (1, 2 or 3), or 255 for an area at the end.)
  @param(reach The cone's length in cells.) }
procedure CollectConeTargets(x, y, tx, ty: ShortInt; rays, reach: Byte);
var
  side2X: ShortInt;
  side2Y: ShortInt;
  side1X: ShortInt;
  side1Y: ShortInt;
  req: Types.TLineWalk;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  walkOk: Boolean;
  i: Byte;
  n: Byte;
  lastDirIdx: Byte;
  dirs: array[0..49] of Byte;
  list: array[0..30] of Byte;
  terrIdx: Byte;
  listCount: Byte;
  destIdx: Byte;
  centerDir: Byte;
  walkDist: Word;
  found: Boolean;

  { Starts a line walk from (sx, sy) to (ex, ey). }
  procedure SetLine(sx, sy, ex, ey: ShortInt);
  begin
    req.x0 := sx; req.y0 := sy; req.x1 := ex; req.y1 := ey;
    Pathing.PathFind(req)
  end;

  { Keeps a cell inside the arena. }
  procedure ClampCell(var cx, cy: ShortInt);
  begin
    if cx > 49 then cx := 49 else if cx < 0 then cx := 0;
    if cy > 24 then cy := 24 else if cy < 0 then cy := 0
  end;

  { Adds each creature on the rest of the walked line to the list, once. }
  procedure CollectAlong;
  var
    j: Byte;
    cfound: Boolean;
  begin
    repeat
      done := not Pathing.NextPathStep(req);
      if not done then begin
        CbtMap.GetArenaContents(req.currentX, req.currentY, list[0], terrIdx);
        j := 1; cfound := False;
        if list[0] > 0 then
          repeat
            if list[j] = list[0] then cfound := True
            else if list[j] = 0 then begin
              list[j] := list[0]; cfound := True
            end else Inc(j)
          until cfound
      end
    until done
  end;
begin
  n := 0;
  SetLine(x, y, tx, ty);
  repeat
    done := not Pathing.NextPathStep(req);
    if not done then begin dirs[n] := req.direction; Inc(n) end
  until done;
  lastDirIdx := n - 1;
  n := 0;
  reach := reach shl 1;
  i := req.movementCost;
  done := False;
  while (i < reach) and not done do begin
    if (tx < 49) and (tx > 0) and (ty < 24) and (ty > 0) then begin
      case dirs[n] of
        0, 2, 4, 6: Inc(i, 2);
        1, 3, 5, 7: Inc(i, 3)
      end;
      Inc(tx, GDConsts.dirDeltaX[dirs[n]]);
      Inc(ty, GDConsts.dirDeltaY[dirs[n]]);
      if n = lastDirIdx then n := 0 else Inc(n)
    end else done := True
  end;
  ClampCell(tx, ty);
  walkDist := reach;
  walkOk := Pathing.WalkLine(x, y, tx, ty, walkDist);
  SetLine(x, y, tx, ty);
  GameIo.ZeroFill(list[1], SizeOf(list) - SizeOf(list[0]));
  listCount := 1;
  repeat
    done := not Pathing.NextPathStep(req);
    if not done then begin
      CbtMap.GetArenaContents(req.currentX, req.currentY, list[0], terrIdx);
      if list[0] > 0 then begin
        if listCount > 1 then begin
          for GDVars.scratchIndex := 1 to listCount - 1 do
            if list[GDVars.scratchIndex] = list[0] then found := True
        end else found := False;
        if not found then begin list[listCount] := list[0]; Inc(listCount) end;
        centerDir := req.direction
      end
    end
  until done;
  if (rays > 1) and (rays <> $FF) then begin
    side2X := tx + GDConsts.coneSideRays.dx1[centerDir];
    side2Y := ty + GDConsts.coneSideRays.dy1[centerDir];
    ClampCell(side2X, side2Y);
    side1X := tx + GDConsts.coneSideRays.dx2[centerDir];
    side1Y := ty + GDConsts.coneSideRays.dy2[centerDir];
    ClampCell(side1X, side1Y);
    SetLine(x, y, side1X, side1Y);
    CollectAlong;
    if rays > 2 then begin SetLine(x, y, side2X, side2Y); CollectAlong end
  end;
  if rays = $FF then begin
    Pathing.BuildTargetList(tx, ty, 3, $FF, 1);
    for GDVars.scratchIndex := 1 to GDVars.rankedTargetCount do
      list[GDVars.scratchIndex] := GDVars.rankedTargets[GDVars.scratchIndex].ent
  end;
  listCount := 1;
  destIdx := 1;
  GDVars.spellTargetTotal := 0;
  if list[1] <> 0 then
    repeat
      if GDVars.slotCreatures[list[listCount]] <> GDVars.currentChar then begin
        Inc(GDVars.spellTargetTotal);
        GDVars.spellTargetList[destIdx] := GDVars.slotCreatures[list[listCount]];
        Inc(destIdx)
      end;
      Inc(listCount)
    until list[listCount] = 0
end;

{ Lays the current spell's effect on every target, each with a saving throw at saveMod, and sends a bolt from the caster
  to each target after the first. Monsters always resist Hold Person, a creature without the animal flag resists Hold
  Animal, and the last target of Faerie Fire or Charm Monsters always saves. Charm Monsters records the caster's side in
  the effect.
  @param(saveMod The modifier to each target's save.)
  @param(msg The message.) }
procedure ApplyEffectToTargets(saveMod: ShortInt; msg: Types.TStr40);
var
  tgt: Types.PCharRecord;
  saved: Boolean;
  i: Byte;
  saveNegates: Boolean;
  effLevel: Byte;
  onRemove: Boolean;
begin
  onRemove := False;
  for i := GDVars.spellTargetTotal downto 1 do
    if GDVars.spellTargetList[i] <> nil then begin
      tgt := GDVars.spellTargetList[i];
      if i < GDVars.spellTargetTotal then begin
        Music.SendSoundCommand(GDConsts.soundIds[Magic.SOUND_SPELL]);
        Blit.BuildIconFrames(17);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.currentChar),
                                        CbtMap.CombatCellY(GDVars.currentChar),
                                            CbtMap.CombatCellX(Types.PCharRecord(tgt)),
                                        CbtMap.CombatCellY(Types.PCharRecord(tgt)), 4, 30)
      end;
      if ((GDVars.spellBeingCast = 79) or (GDVars.spellBeingCast = 81)) and (i = GDVars.spellTargetTotal) then begin
        saved := True;
        saveNegates := True
      end else begin
        saved := FxEngine.RollSavingThrow(tgt, GDConsts.spellTable[GDVars.spellBeingCast].saveType, saveMod);
        saveNegates := Boolean(GDConsts.spellTable[GDVars.spellBeingCast].saveResult)
      end;
      if (tgt^.race = C_Race.MONSTER) and ((GDVars.spellBeingCast = 23) or (GDVars.spellBeingCast = 49)) then
        saved := True;
      if ((tgt^.creatureType and $40) = 0) and (GDVars.spellBeingCast = 108) then
        saved := True;
      if GDVars.spellBeingCast = 81 then begin
        effLevel := GDVars.currentChar^.side * 128 + CharHlp.GetCasterLevel(GDVars.spellBeingCast, True);
        onRemove := True
      end else
        effLevel := CharHlp.GetCasterLevel(GDVars.spellBeingCast, True);
      FxEngine.AddEffectWithMessage(tgt, GDConsts.spellTable[GDVars.spellBeingCast].effect,
                                    Magic.CalcSpellDuration(GDVars.spellBeingCast), effLevel, Byte(onRemove),
                                    Byte(saveNegates), Byte(saved), msg)
    end
end;

{ Resolves the current spell on the targets of one side; Bless in combat also skips a target with an enemy next to it.
  @param(hostFlag The side affected.)
  @param(msg The effect's message.) }
procedure CastOneSide(hostFlag: ShortInt; msg: Types.TStr40);
var
  i: Byte;
begin
  GDVars.gMultiTarget := 1;
  for i := 1 to GDVars.spellTargetTotal do
    if (GDVars.spellTargetList[i]^.side <> hostFlag) or
        ((GDVars.spellBeingCast = 1) and (GDVars.interfaceState = C_Ifc.IN_COMBAT) and
         (CharHlp.CountTargets(GDVars.spellTargetList[i], 1, False) > 0)) then
      GDVars.spellTargetList[i] := nil;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, msg)
end;

procedure SpellBless;
begin
  Magic.CastOneSide(GDVars.currentChar^.side, GDConsts.isWord + GDConsts.effectNames[C_Effect.BLESS])
end;

procedure SpellCurse;
begin
  Magic.CastOneSide(CharHlp.EnemyTeam(GDVars.currentChar), GDConsts.isWord + GDConsts.effectNames[C_Effect.CURSE])
end;

procedure SpellCureLightWounds;
begin
  if GDVars.spellTargetTotal = 0 then begin
  end else
    if FxEngine.RestoreHitPoints(GDVars.spellTargetList[1], FxEngine.RollDice(1, 8), False) then
      CharHlp.AnnounceHealStatus(GDVars.spellTargetList[1])
end;

procedure SpellCauseLightWounds;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, FxEngine.RollDamageDice(1, 8), 8, '')
end;

procedure SpellDetection;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is affected')
end;

procedure SpellProtection;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is protected')
end;

procedure SpellResistCold;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is cold-resistant')
end;

procedure SpellBurningHands;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, CharHlp.GetCasterLevel(GDVars.spellBeingCast, False), 9, '')
end;

procedure SpellCharmPerson;
var
  eff: Pointer;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  if tgt <> nil then
    if ((tgt^.race = C_Race.MONSTER) and ((tgt^.creatureType and 2) = 0)) or (tgt^.iconDimensions > 1) then
      CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
    else begin
      Magic.ResolveSpell(GDVars.spellBeingCast,
                         GDVars.currentChar^.side * 128 + CharHlp.GetCasterLevel(GDVars.spellBeingCast, True), True, 0,
                         0, 'is charmed');
      if CharHlp.HasEffect(tgt, C_Effect.CHARM, eff) then
        FxEngine.CallEffectHandler(C_Effect.CHARM, tgt, eff, False)
    end
end;

procedure SpellEnlarge;
var
  enc: Byte;
  tgt: Types.PCharRecord;
  eff: Pointer;
begin
  tgt := GDVars.spellTargetList[1];
  GDVars.spellTemp1 := 18;
  GDVars.spellTemp2 := 0;
  case CharHlp.GetCasterLevel(GDVars.spellBeingCast, False) of
    1: GDVars.spellTemp2 := 0;
    2: GDVars.spellTemp2 := 1;
    3: GDVars.spellTemp2 := 51;
    4: GDVars.spellTemp2 := 76;
    5: GDVars.spellTemp2 := 91;
    6: GDVars.spellTemp2 := 100;
    7: GDVars.spellTemp1 := 19;
    8: GDVars.spellTemp1 := 20;
    9: GDVars.spellTemp1 := 21;
  else GDVars.spellTemp1 := 22
  end;
  if FxEngine.AdjustForNewStrength(tgt, GDVars.spellTemp1, GDVars.spellTemp2, enc) and
      not CharHlp.HasEffect(tgt, C_Effect.GLOBE_OF_INVULNERABILITY, eff) and not CharHlp.HasEffect(tgt,
          C_Effect.MINOR_GLOBE, eff) then begin
    CharHlp.PrintCreatureMessage(tgt, 'is stronger', 10, True);
    FxEngine.AddEffect(tgt, C_Effect.ENLARGE, Magic.CalcSpellDuration(GDVars.spellBeingCast), enc, True);
    FxEngine.RecalcAbility(tgt, C_Stat.STRENGTH)
  end else
    CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
end;

procedure SpellReduce;
var
  eff: Pointer;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  if tgt <> nil then
    if GDVars.spellTargetTotal > 0 then
      if not FxEngine.RollSavingThrow(tgt, 4, 0) then
        if CharHlp.HasEffect(tgt, C_Effect.ENLARGE, eff) then begin
          FxEngine.RemoveEffect(tgt, C_Effect.ENLARGE, nil);
          FxEngine.RecalcAbility(tgt, C_Stat.STRENGTH);
          CharHlp.PrintCreatureMessage(tgt, 'has been reduced', 10, True)
        end
end;

procedure SpellFriends;
var
  { Unused in this version; see the other implementations of this routine. }
  oldCha: Byte;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, FxEngine.RollDice(2, 4), True, 0, 0, 'is friendly');
  FxEngine.RecalcAbility(GDVars.currentChar, C_Stat.CHARISMA)
end;

procedure SpellMagicMissile;
var
  casterLevel: Byte;
begin
  casterLevel := CharHlp.GetCasterLevel(GDVars.spellBeingCast, False) + 1;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, casterLevel div 2 + FxEngine.RollDamageDice(casterLevel div 2, 4),
                     8, '')
end;

procedure SpellShield;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is shielded')
end;

procedure SpellShockingGrasp;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False,
                     FxEngine.RollDamageDice(1, 8) + CharHlp.GetCasterLevel(GDVars.spellBeingCast, False), $0C, '')
end;

procedure SpellSleep;
var
  i: Byte;
  eff: Pointer;
begin
  GDVars.gMultiTarget := 1;
  GDVars.spellTemp1 := FxEngine.RollDice(4, 4);
  for i := 1 to GDVars.spellTargetTotal do begin
    case GDVars.spellTargetList[i]^.hitDice of
      0..1: GDVars.spellTemp2 := 1;
      2: GDVars.spellTemp2 := 2;
      3: GDVars.spellTemp2 := 4;
      4: GDVars.spellTemp2 := 6;
      5: if GDVars.spellTargetList[i]^.race = C_Race.MONSTER then GDVars.spellTemp2 := 10
         else GDVars.spellTemp2 := 20;
    else
      GDVars.spellTemp2 := 20
    end;
    if (GDVars.spellTargetList[i]^.status <> C_Status.ANIMATED) and (not CharHlp.HasEffect(GDVars.spellTargetList[i],
        C_Effect.ASLEEP, eff)) and
        (GDVars.spellTemp1 >= GDVars.spellTemp2) then
      Dec(GDVars.spellTemp1, GDVars.spellTemp2)
    else
      GDVars.spellTargetList[i] := nil
  end;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'falls asleep')
end;

procedure SpellHold;
var
  saveMod: ShortInt;
begin
  case GDVars.spellTargetTotal of
    1: if GDVars.spellBeingCast = 23 then saveMod := -2 else saveMod := -3;
    2: saveMod := -1;
    3, 4: saveMod := 0
  end;
  Magic.ApplyEffectToTargets(saveMod, 'is held')
end;

procedure SpellResistFire;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is fire resistant')
end;

procedure SpellSilence;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is silenced')
end;

procedure SpellSlowPoison;
var
  eff: Pointer;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  if tgt^.status = C_Status.ANIMATED then
    GDVars.spellTargetList[1] := nil
  else if CharHlp.HasEffect(tgt, C_Effect.POISONED, eff) then begin
    if tgt^.hpCur = 0 then tgt^.hpCur := 1;
    tgt^.status := C_Status.OKAY;
    tgt^.inPlay := 1;
    Magic.ResolveSpell(GDVars.spellBeingCast, $FF, True, 0, 0, 'is affected');
    FxEngine.AddEffect(tgt, C_Effect.SLOW_POISON_HIT, 10, $FF, True)
  end
end;

procedure SpellSnakeCharm;
var
  p: Types.PCharRecord;
  eff: Pointer;
begin
  GDVars.spellTemp1 := GDVars.currentChar^.hpCur;
  GDVars.spellTargetTotal := 0;
  p := GDVars.creatureListHead;
  while p <> nil do begin
    if ((p^.creatureType and $10) <> 0) and (p^.inPlay <> 0) and
        (not CharHlp.HasEffect(p, C_Effect.HELPLESS_51, eff)) and (GDVars.spellTemp1 >= p^.hpCur) then begin
      GDVars.spellTemp1 := GDVars.spellTemp1 - p^.hpCur;
      Inc(GDVars.spellTargetTotal);
      GDVars.spellTargetList[GDVars.spellTargetTotal] := p
    end;
    p := p^.next
  end;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, GDConsts.isWord + GDConsts.effectNames[C_Effect.CHARM])
end;

procedure SpellSpiritualHammer;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, True, 0, 0, '');
  FxEngine.CallEffectHandler(C_Effect.SPIRITUAL_HAMMER, GDVars.spellTargetList[1], nil, False)
end;

procedure SpellInvisibility;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is invisible')
end;

procedure SpellKnock;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'Knock-Knock')
end;

procedure SpellMirrorImage;
var
  strength: Byte;
begin
  strength := FxEngine.RollDice(1, 4) shl 5;
  strength := strength or CharHlp.GetCasterLevel(GDVars.spellBeingCast, True);
  Magic.ResolveSpell(GDVars.spellBeingCast, strength, False, 0, 0, 'is duplicated')
end;

procedure SpellRayOfEnfeeblement;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is weakened')
end;

procedure SpellStinkingCloud;
var
  cellX: Integer;
  cellY: Integer;
  p: Pointer;
  dir: Byte;
  count: Byte;
  terrIdx: Byte;
  j: Byte;
  i: Byte;
  crIdx: Byte;
  dirs: array[1..9] of Byte;
begin
  GameIo.ZeroFill(dirs, SizeOf(dirs));
  GetMem(p, SizeOf(Types.TCellPatch));
  GameIo.ZeroFill(p^, SizeOf(Types.TCellPatch));
  with Types.PCellPatch(p)^ do begin
    x := GDVars.gTargetX;
    y := GDVars.gTargetY;
    owner := GDVars.currentChar;
    casterLevel := CharHlp.GetCasterLevel(GDVars.spellBeingCast, True);
    ttl := casterLevel;
    case GDVars.spellBeingCast of
      34: begin count := 4; paintTerrain := C_Terr.TERRAIN_STINKING_CLOUD end;
      91: begin count := 9; paintTerrain := C_Terr.TERRAIN_CLOUDKILL end;
      101: begin
        count := 4;
        paintTerrain := C_Terr.TERRAIN_BLADE_BARRIER;
        ttl := ttl * 3
      end
    end;
    for i := 1 to count do begin
      dir := GDConsts.patchDirs[i];
      cellX := x + GDConsts.dirDeltaX[dir];
      cellY := y + GDConsts.dirDeltaY[dir];
      if (cellX >= 0) and (cellX <= 49) and (cellY >= 0) and (cellY <= 24) then begin
        CbtMap.GetArenaContents(cellX, cellY, crIdx, terrIdx);
        for j := 1 to i - 1 do
          if dirs[j] = crIdx then crIdx := 0;
        dirs[i] := crIdx;
        terrIdx := CbtMap.ResolveTerrain(cellX, cellY);
        used[i] := Byte((terrIdx > 0) and (GDConsts.terrainTable[terrIdx].cost < C_Terr.TERRAIN_IMPASSABLE));
        terrainIndex[i] := terrIdx;
        if used[i] <> 0 then
          GDVars.arenaPtr^.cells[cellY, cellX] := paintTerrain
      end else
        used[i] := 0
    end;
  end;
  Types.PCellPatch(p)^.next := GDVars.cellPatchList;
  GDVars.cellPatchList := Types.PCellPatch(p);
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, $FF, C_Dir.CENTER);
  for i := 1 to count do
    if dirs[i] > 0 then
      FxEngine.ConsiderTerrainEffects(GDVars.slotCreatures[dirs[i]], True, False);
end;

procedure SpellStrength;
var
  tgt: Types.PCharRecord;
  pct: Byte;
  hd: Byte;
  base: Byte;
  strEff: Byte;
begin
  pct := 0;
  tgt := GDVars.spellTargetList[1];
  if tgt^.classLevels[C_Class.MAGE] > 0 then
    hd := FxEngine.RollDice(1, 4);
  if (tgt^.classLevels[C_Class.CLERIC] > 0) or (tgt^.classLevels[C_Class.THIEF] > 0) then
    hd := FxEngine.RollDice(1, 6);
  if (tgt^.classLevels[C_Class.FIGHTER] > 0) or (tgt^.classLevels[C_Class.RANGER] > 0) or
      (tgt^.classLevels[C_Class.PALADIN] > 0) then
    hd := FxEngine.RollDice(1, 8);
  base := tgt^.stats[C_Stat.STRENGTH].cur + hd;
  if base > 18 then
    if (tgt^.classLevels[C_Class.FIGHTER] > 0) or (tgt^.classLevels[C_Class.RANGER] > 0) or
        (tgt^.classLevels[C_Class.PALADIN] > 0) then begin
      pct := tgt^.strExcCur + (base - 18) * 10;
      if pct > 100 then pct := 100;
      base := 18
    end else
      base := 18;
  if FxEngine.AdjustForNewStrength(tgt, base, pct, strEff) then begin
    strEff := hd + 100;
    FxEngine.AddEffect(tgt, C_Effect.STRENGTH, Magic.CalcSpellDuration(GDVars.spellBeingCast), strEff, True);
    FxEngine.RecalcAbility(tgt, C_Stat.STRENGTH)
  end
end;

{ Removes the first spell target's diseases, with the effect lock set: Diseased, and the Strength-draining disease (with
  its hit-point and helpless effects, then the target's Strength is recalculated).
  @returns(True when one was removed.) }
function RemoveDiseaseEffects: Boolean;
begin
  RemoveDiseaseEffects := False;
  GDVars.effectLock := 1;
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargetList[1], C_Effect.DISEASED) then
    RemoveDiseaseEffects := True;
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargetList[1], C_Effect.DISEASE_STRENGTH) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(GDVars.spellTargetList[1], C_Effect.DISEASE_HIT_POINTS, nil);
    FxEngine.RemoveEffect(GDVars.spellTargetList[1], C_Effect.HELPLESS, nil);
    FxEngine.RecalcAbility(GDVars.spellTargetList[1], C_Stat.STRENGTH)
  end;
  GDVars.effectLock := 0
end;

procedure SpellHeal;
var
  tgt: Types.PCharRecord;
  hp: Byte;
begin
  tgt := GDVars.spellTargetList[1];
  if Magic.RemoveDiseaseEffects then
    CharHlp.PrintCreatureMessage(tgt, GDConsts.isWord + 'cured', 10, False);
  if FxEngine.RemoveEffectWithMessage(tgt, C_Effect.BLIND) then
    CharHlp.PrintCreatureMessage(tgt, GDConsts.isWord + 'no longer blind', 10, False);
  if FxEngine.RemoveEffectWithMessage(tgt, C_Effect.FEEBLEMIND) then begin
    CharHlp.PrintCreatureMessage(tgt, 'regains intellect', 10, False);
    FxEngine.RecalcAbility(tgt, C_Stat.INTELLIGENCE);
    FxEngine.RecalcAbility(tgt, C_Stat.WISDOM)
  end;
  hp := FxEngine.RollDice(1, 4);
  if tgt^.hpCur + hp > tgt^.hpMax then
    hp := 0
  else
    hp := tgt^.hpMax - tgt^.hpCur - hp;
  if FxEngine.RestoreHitPoints(tgt, hp, False) then
    CharHlp.PrintCreatureMessage(tgt, 'is healed', 10, False)
end;

procedure SpellCureBlindness;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargetList[1], C_Effect.BLIND) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargetList[1], True, 'can see')
end;

procedure SpellCauseBlindness;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is blind')
end;

procedure SpellCureDisease;
begin
  if Magic.RemoveDiseaseEffects then
    CharHlp.PrintCreatureMessage(GDVars.spellTargetList[1], GDConsts.isWord + 'cured', 10, False)
end;

procedure SpellCauseDisease;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, True, 0, 0, GDConsts.isWord + GDConsts.effectNames[C_Effect.DISEASED])
end;

procedure SpellDispelMagic;
var
  i: Byte;
  casterLevel: Byte;
  tgt: Types.PCharRecord;
  removed: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
  eff: Types.PEffectRec;
  nextEff: Types.PEffectRec;
  x: ShortInt;
  y: ShortInt;
  terrIdx: Byte;
  crIdx: Byte;
  node: Types.PCellPatch;

  { The dispel roll against a cloud cast at level. }
  function CloudDispelled(level: Byte): Boolean;
  begin
    if casterLevel > level then
      GDVars.spellTemp1 := (casterLevel - level) * 5 + 50
    else if casterLevel < level then
      GDVars.spellTemp1 := 50 - (GDVars.spellTemp2 - casterLevel) * 2
    else
      GDVars.spellTemp1 := 50;
    CloudDispelled := FxEngine.RollDice(1, 100) <= GDVars.spellTemp1
  end;

begin
  GDVars.gMultiTarget := 1;
  casterLevel := CharHlp.GetCasterLevel(GDVars.spellBeingCast, False);
  for i := 1 to GDVars.spellTargetTotal do begin
    removed := False;
    tgt := GDVars.spellTargetList[i];
    eff := tgt^.effects;
    while eff <> nil do begin
      nextEff := eff^.next;
      if eff^.strength < $FF then begin
        GDVars.spellTemp2 := eff^.strength and $1F;
        if casterLevel > GDVars.spellTemp2 then
          GDVars.spellTemp1 := (casterLevel - GDVars.spellTemp2) * 5 + 50
        else if casterLevel < GDVars.spellTemp2 then
          GDVars.spellTemp1 := 50 - (GDVars.spellTemp2 - casterLevel) * 2
        else
          GDVars.spellTemp1 := 50;
        if FxEngine.RollDice(1, 100) <= GDVars.spellTemp1 then begin
          FxEngine.RemoveEffect(tgt, eff^.id, eff);
          removed := True
        end
      end;
      eff := nextEff
    end;
    if removed then
      CharHlp.PrintNameStringAnim(tgt, True, 'is affected')
  end;
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    for GDVars.scratchIndex := 0 to 8 do begin
      x := GDVars.gTargetX + GDConsts.dirDeltaX[GDVars.scratchIndex];
      y := GDVars.gTargetY + GDConsts.dirDeltaY[GDVars.scratchIndex];
      CbtMap.GetArenaContents(x, y, crIdx, terrIdx);
      if (terrIdx = C_Terr.TERRAIN_STINKING_CLOUD) or (terrIdx = C_Terr.TERRAIN_CLOUDKILL) then begin
        node := GDVars.cellPatchList;
        if terrIdx = C_Terr.TERRAIN_STINKING_CLOUD then crIdx := 4 else crIdx := 9;
        while node <> nil do begin
          for i := 1 to crIdx do
            if (x = node^.x + GDConsts.dirDeltaX[GDConsts.patchDirs[i]]) and
                (y = node^.y + GDConsts.dirDeltaY[GDConsts.patchDirs[i]]) and CloudDispelled(node^.casterLevel) then
              node^.ttl := -1;
          node := node^.next
        end;
        CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 3, C_Dir.CENTER)
      end;
    end;
    FxEngine.CountDownAreaEffects(True)
  end
end;

procedure SpellPrayer;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast,
                     GDVars.currentChar^.side * 128 + CharHlp.GetCasterLevel(GDVars.spellBeingCast, True), False, 0, 0,
                     'is praying')
end;

procedure SpellRemoveCurse;
var
  item: Types.PItemRec;
  found: Boolean;
  i: Byte;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargetList[1], C_Effect.DISEASE_STRENGTH) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargetList[1], True, 'is un-cursed')
  else begin
    found := False;
    item := Types.PItemRec(GDVars.spellTargetList[1]^.items);
    while (item <> nil) and not found do begin
      if item^.definition.cursed <> 0 then begin
        found := True;
        item^.definition.equipped := 0;
        if item^.definition.special > $7F then begin
          GDVars.sharedScratch.itemEffectOverride := 1;
          FxEngine.CallEffectHandler(item^.definition.special, GDVars.spellTargetList[1], item, True);
          for i := C_Stat.STRENGTH to C_Stat.CHARISMA do FxEngine.RecalcAbility(GDVars.spellTargetList[1], i)
        end
      end;
      item := item^.next
    end;
    if found then
      CharHlp.PrintNameStringAnim(GDVars.spellTargetList[1], True, 'has an item un-cursed')
  end
end;

procedure SpellBestowCurse;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'has been cursed!')
end;

procedure SpellBlink;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is blinking')
end;

procedure SpellFireball;
var
  range: Byte;
  bonus: Byte;
  i: Byte;
begin
  GDVars.gMultiTarget := 1;
  if GDVars.spellBeingCast = 64 then
    range := FxEngine.RollDice(1, 3) * 2 + 1
  else
    range := CharHlp.GetCasterLevel(GDVars.spellBeingCast, False);
  if GDVars.vmBand.zone0^.inDungeon = 0 then begin
    Pathing.BuildTargetList(GDVars.gTargetX, GDVars.gTargetY, 2, $FF, 1);
    for i := 1 to GDVars.rankedTargetCount do
      GDVars.spellTargetList[i] := GDVars.slotCreatures[GDVars.rankedTargets[i].ent];
    GDVars.spellTargetTotal := GDVars.rankedTargetCount
  end;
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 0, C_Dir.CENTER);
  if GDVars.spellBeingCast = 115 then bonus := range else bonus := 0;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, FxEngine.RollDamageDice(range, 6) + bonus, 9, '')
end;

{ Resolves Haste or Slow for up to the casting level of targets on one team, dropping the rest. A kept target with the
  opposing effect only loses it; the others take the spell's effect and have their movement and attack-rate effects run
  again.
  @param(effectId The opposing effect, Slowed or Hasted.)
  @param(side The team to keep: 0 the party's side, 1 the hostiles.)
  @param(msg The effect message.) }
procedure HasteSlowLogic(effectId: Byte; side: ShortInt; msg: Types.TStr40);
var
  casterLevel: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  affected: Byte;
begin
  GDVars.gMultiTarget := 1;
  casterLevel := CharHlp.GetCasterLevel(GDVars.spellBeingCast, False);
  for i := 1 to GDVars.spellTargetTotal do
    if (GDVars.spellTargetList[i]^.side = side) and (casterLevel > 0) then begin
      Dec(casterLevel);
      if FxEngine.RemoveEffectWithMessage(GDVars.spellTargetList[i], effectId) then
        GDVars.spellTargetList[i] := nil
    end else
      GDVars.spellTargetList[i] := nil;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, msg);
  for i := 1 to GDVars.spellTargetTotal do
    if GDVars.spellTargetList[i] <> nil then
      FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, GDVars.spellTargetList[i])
end;

procedure SpellHaste;
begin
  Magic.HasteSlowLogic(C_Effect.SLOWED, GDVars.currentChar^.side, 'is Hasted')
end;

{ Strikes the creature at a cell, if any, with lightning; a save halves the damage.
  @param(x The column.)
  @param(y The row.)
  @param(damage The damage.) }
procedure LightningAttackAt(x, y: ShortInt; damage: Word);
var
  crIdx: Byte;
  terrIdx: Byte;
  tgt: Types.PCharRecord;
begin
  CbtMap.GetArenaContents(x, y, crIdx, terrIdx);
  if crIdx > 0 then begin
    tgt := GDVars.slotCreatures[crIdx];
    FxEngine.InflictNonWeaponDamage(tgt, damage, 2, FxEngine.RollSavingThrow(tgt, 4, 0));
    Blit.BuildIconFrames(18)
  end
end;

{ Runs a lightning bolt from the target point away from the caster for count cells, striking each creature it crosses
  once. Indoors the bolt rebounds off a wall back toward the caster; with flag, a first rebound off a wall near the
  caster costs the bolt double length.
  @param(count The bolt's length in cells.)
  @param(damage The damage.)
  @param(flag True makes a first rebound near the caster cost double.) }
procedure LightningPath(count, damage: Word; flag: Boolean);
var
  spent: Byte;
  prevCr: Byte;
  terrIdx: Byte;
  crIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedCell: array[0..3] of Byte;
  sign: ShortInt;
  prevX: ShortInt;
  prevY: ShortInt;
  oldX: Integer;
  oldY: Integer;
  x0: Integer;
  tx: Integer;
  y0: Integer;
  ty: Integer;
  req2: Types.TLineWalk;
  req: Types.TLineWalk;
  valid: Boolean;

begin
  Blit.BuildIconFrames(18);
  x0 := CbtMap.CombatCellX(GDVars.currentChar);
  y0 := CbtMap.CombatCellY(GDVars.currentChar);
  tx := GDVars.gTargetX;
  ty := GDVars.gTargetY;
  Magic.LightningAttackAt(tx, ty, damage);
  CbtMap.GetArenaContents(tx, ty, prevCr, terrIdx);
  count := count * 2;
  GDVars.gMultiTarget := 1;
  spent := 0;
  sign := 1;
  while count > 0 do begin
    GameIo.ZeroFill(req, SizeOf(req));
    req.x0 := tx;
    req.y0 := ty;
    req.x1 := tx + (tx - x0) * sign * count;
    req.y1 := ty + (ty - y0) * sign * count;
    Pathing.PathFind(req);
    repeat
      prevX := req.currentX;
      prevY := req.currentY;
      if (req.x0 <> req.x1) or (req.y0 <> req.y1) then
        repeat
          oldX := req.currentX;
          oldY := req.currentY;
          valid := Pathing.NextPathStep(req);
          CbtMap.GetArenaContents(req.currentX, req.currentY, crIdx, terrIdx)
        until (not valid) or ((crIdx > 0) and (crIdx <> prevCr)) or (terrIdx = 0) or
            (GDConsts.terrainTable[terrIdx].cost > 1) or (req.movementCost >= count);
      if terrIdx = 0 then count := 0;
      if (req.currentX < 0) or (req.currentX > 49) or (req.currentY < 0) or (req.currentY > 24) then begin
        req.currentX := oldX;
        req.currentY := oldY
      end;
      CharHlp.CombatAnimateMovingIcon(prevX, prevY, req.currentX, req.currentY, 4, 50);
      if prevCr <> crIdx then
        Magic.LightningAttackAt(req.currentX, req.currentY, damage);
      prevCr := crIdx;
      if (GDConsts.terrainTable[terrIdx].cost > 1) and (GDVars.vmBand.zone0^.inDungeon = 1) then begin
        tx := req.currentX;
        ty := req.currentY;
        sign := -1;
        GameIo.ZeroFill(req2, SizeOf(req2));
        req2.x0 := tx;
        req2.y0 := ty;
        req2.x1 := x0;
        req2.y1 := y0;
        Pathing.PathFind(req2);
        while Pathing.NextPathStep(req2) do ;
        if flag and (req2.movementCost <= 8) then
          req.movementCost := req.movementCost * 2;
        flag := False
      end;
      spent := req.movementCost - spent;
      if spent < 2 then spent := 2;
      if spent < count then Dec(count, spent) else count := 0;
      spent := req.movementCost
    until (count = 0) or ((GDConsts.terrainTable[terrIdx].cost > 1) and (GDVars.vmBand.zone0^.inDungeon = 1))
  end;
  GDVars.gMultiTarget := 0
end;

procedure SpellLightningBolt;
var
  damage: Word;
  { Unused in this version; see the other implementations of this routine. }
  direction: Byte;
begin
  GDVars.elementMask := $0C;
  damage := FxEngine.RollDamageDice(CharHlp.GetCasterLevel(GDVars.spellBeingCast, False), 6);
  Magic.LightningPath(7, damage, True)
end;

procedure SpellSlow;
begin
  Magic.HasteSlowLogic(C_Effect.HASTED, CharHlp.EnemyTeam(GDVars.currentChar), 'is Slowed')
end;

procedure SpellHarm;
var
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  GDVars.elementMask := 8;
  FxEngine.AddEffectWithMessage(tgt, C_Effect.DISEASED, 0, 0, 0, 0, 0, '');
  CharHlp.PrintCreatureMessage(tgt, GDConsts.isWord + GDConsts.effectNames[C_Effect.DISEASED], 10, True);
  FxEngine.InflictNonWeaponDamage(tgt, tgt^.hpCur - FxEngine.RollDice(1, 4), 0, False)
end;

procedure SpellPotionOfSpeed;
begin
  if not FxEngine.RemoveEffectWithMessage(GDVars.spellTargetList[1], C_Effect.SLOWED) then
    Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is Speedy')
end;

procedure SpellCureSeriousWounds;
begin
  if GDVars.spellTargetTotal = 0 then Exit;
  if FxEngine.RestoreHitPoints(GDVars.spellTargetList[1], FxEngine.RollDice(2, 8) + 1, False) then
    CharHlp.AnnounceHealStatus(GDVars.spellTargetList[1])
end;

procedure SpellGiantStrength;
var
  effStrength: Byte;
  { Unused in this version; see the other implementations of this routine. }
  oldStrength: Byte;
begin
  if FxEngine.AdjustForNewStrength(GDVars.spellTargetList[1], 21, 0, effStrength) then
    CharHlp.PrintCreatureMessage(GDVars.spellTargetList[1], 'is stronger', 10, True);
  FxEngine.AddEffect(GDVars.spellTargetList[1], C_Effect.GIANT_STRENGTH, FxEngine.RollDice(1, 4) * 10 + 40, effStrength,
                     True);
  FxEngine.RecalcAbility(GDVars.spellTargetList[1], C_Stat.STRENGTH)
end;

procedure SpellJavelinOfLightning;
var
  { Unused in this version; see the other implementations of this routine. }
  blocked: Byte;
begin
  GDVars.elementMask := $0C;
  Magic.LightningPath(3, 20, False)
end;

procedure SpellWandOfParalyzation;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is paralyzed')
end;

procedure SpellPotionOfHealing;
begin
  if FxEngine.RestoreHitPoints(GDVars.spellTargetList[1], FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargetList[1], True, 'is Healed')
end;

procedure SpellYouth;
var
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.currentChar;
  tgt^.age := tgt^.age - (FxEngine.RollDice(1, 4) + 1);
  if tgt^.age < 18 then begin
    tgt^.age := 18;
    CharHlp.PrintCreatureMessage(tgt, 'is now 18 years old', 10, True)
  end else
    CharHlp.PrintCreatureMessage(tgt, 'becomes younger', 10, True)
end;

procedure SpellWandOfMagicMissiles;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, FxEngine.RollDamageDice(2, 4) + 2, 8, '')
end;

procedure SpellCauseSeriousWounds;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, FxEngine.RollDamageDice(2, 8) + 1, 8, '')
end;

procedure SpellNeutralizePoison;
var
  tgt: Types.PCharRecord;
  eff: Pointer;
begin
  tgt := GDVars.spellTargetList[1];
  if tgt^.status = C_Status.ANIMATED then
    GDVars.spellTargetList[1] := nil
  else if CharHlp.HasEffect(tgt, C_Effect.POISONED, eff) then begin
    if tgt^.hpCur = 0 then tgt^.hpCur := 1;
    GDVars.effectLock := 1;
    FxEngine.RemoveEffect(tgt, C_Effect.POISONED, nil);
    FxEngine.RemoveEffect(tgt, C_Effect.SLOW_POISON_END, nil);
    FxEngine.RemoveEffect(tgt, C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectLock := 0;
    CharHlp.PrintCreatureMessage(tgt, 'is unpoisoned', 10, True);
    tgt^.inPlay := 1;
    tgt^.status := C_Status.OKAY
  end else
    CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
end;

procedure SpellPoison;
var
  effectNode: Pointer;
  p: Pointer;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 8, '');
  p := GDVars.currentChar^.combatAddr^.other;
  GDVars.pendingEffectId := C_Effect.DEADLY_POISON_ATTACK;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, p);
  if GDVars.pendingEffectId = C_Effect.DEADLY_POISON_ATTACK then
    FxEngine.CallEffectHandler(C_Effect.DEADLY_POISON_ATTACK, GDVars.currentChar, effectNode, False)
end;

procedure SpellSticksToSnakes;
var
  eff: Pointer;
begin
  if GDVars.spellTargetList[1]^.hitDice < 6 then begin
    Magic.ResolveSpell(GDVars.spellBeingCast, CharHlp.GetCasterLevel(GDVars.spellBeingCast, True), False, 0, 8, '');
    if CharHlp.HasEffect(GDVars.spellTargetList[1], C_Effect.SNAKE_HARASS, eff) then
      FxEngine.CallEffectHandler(C_Effect.SNAKE_HARASS, GDVars.spellTargetList[1], eff, False)
  end else if not CharHlp.IsHelpless(GDVars.spellTargetList[1]) then
    CharHlp.PrintCreatureMessage(GDVars.spellTargetList[1], 'smashes them flat', 10, True)
end;

procedure SpellCureCriticalWounds;
begin
  if GDVars.spellTargetTotal = 0 then Exit;
  if FxEngine.RestoreHitPoints(GDVars.spellTargetList[1], FxEngine.RollDice(3, 8) + 3, False) then
    CharHlp.AnnounceHealStatus(GDVars.spellTargetList[1])
end;

procedure SpellCauseCriticalWounds;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, FxEngine.RollDamageDice(3, 8) + 3, 8, '')
end;

procedure SpellDispelEvil;
begin
  FxEngine.AddEffectWithMessage(GDVars.currentChar, C_Effect.DISPEL_EVIL, Magic.CalcSpellDuration(73), 0, 0, 0, 0, '');
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is affected')
end;

procedure SpellFlameStrike;
begin
  GDVars.gMultiTarget := 1;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, FxEngine.RollDamageDice(6, 8), 9, '')
end;

procedure SpellRaiseDead;
var
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  if ((tgt^.status = C_Status.DEAD_STATUS) or (tgt^.status = C_Status.ANIMATED)) and
      (tgt^.stats[C_Stat.CONSTITUTION].base > 0) and (tgt^.race <> C_Race.ELF) then begin
    GDVars.effectLock := 1;
    FxEngine.RemoveEffect(tgt, C_Effect.POISONED, nil);
    GDVars.effectLock := 0;
    tgt^.status := C_Status.OKAY;
    tgt^.inPlay := 1;
    Dec(tgt^.stats[C_Stat.CONSTITUTION].base);
    FxEngine.RecalcAbility(tgt, C_Stat.CONSTITUTION);
    tgt^.hpCur := 1;
    CharHlp.PrintCreatureMessage(tgt, 'is raised', 10, True)
  end
end;

procedure SpellSlayLiving;
var
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  GDVars.elementMask := $40;
  GDVars.pendingDamage := 67;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, tgt);
  if GDVars.pendingDamage <> 0 then begin
    if (not FxEngine.RollSavingThrow(tgt, 4, 0)) and ((tgt^.immunities and 8) = 0) then
      FxEngine.KillCreature(tgt, C_Status.DEAD_STATUS, 'is slain')
    else begin
      GDVars.elementMask := 8;
      FxEngine.InflictNonWeaponDamage(tgt, FxEngine.RollDamageDice(2, 8) + 1, 0, False)
    end
  end else
    CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
end;

procedure SpellEntangle;
var
  tgt: Types.PCharRecord;
  i: Byte;
  saved: Boolean;
begin
  GDVars.gMultiTarget := 1;
  if GDVars.vmBand.zone0^.inDungeon = 0 then
    for i := 1 to GDVars.spellTargetTotal do
      if GDVars.spellTargetList[i] <> nil then begin
        tgt := GDVars.spellTargetList[i];
        saved := FxEngine.RollSavingThrow(tgt, 4, 0);
        FxEngine.AddEffectWithMessage(tgt, C_Effect.CONFUSED_LOSE_TURN, Magic.CalcSpellDuration(78), 0, 0, 1,
                                      Byte(saved), 'is entangled')
      end;
  GDVars.gMultiTarget := 0
end;

procedure SpellFaerieFire;
begin
  Magic.ApplyEffectToTargets(0, 'is highlighted')
end;

procedure SpellInvisibilityToAnimals;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is invisible')
end;

procedure SpellCharmMonsters;
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  charmCount: Integer;
  eff: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  charmInfo: array[0..2] of Byte;
begin
  Magic.ApplyEffectToTargets(0, 'is charmed');
  for i := 1 to GDVars.spellTargetTotal do
    if CharHlp.HasEffect(GDVars.spellTargetList[i], C_Effect.CHARM, eff) then
      FxEngine.CallEffectHandler(C_Effect.CHARM, GDVars.spellTargetList[i], eff, False)
end;

procedure SpellConfusion;
var
  i: Byte;
  saved: Boolean;
  tgt: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  eff: array[0..3] of Byte;
  maxTargets: Byte;
begin
  GDVars.gMultiTarget := 1;
  maxTargets := FxEngine.RollDice(2, 8);
  if GDVars.spellTargetTotal > maxTargets then GDVars.spellTargetTotal := maxTargets;
  for i := 1 to GDVars.spellTargetTotal do
    if GDVars.spellTargetList[i] <> nil then begin
      tgt := GDVars.spellTargetList[i];
      saved := FxEngine.RollSavingThrow(tgt, 4, 0);
      FxEngine.AddEffectWithMessage(tgt, C_Effect.CONFUSED, Magic.CalcSpellDuration(82), 0, 0, 1, Byte(saved),
                                    'is confused')
    end;
  GDVars.gMultiTarget := 0
end;

procedure SpellDimensionDoor;
var
  caster: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  target: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  locOk: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
begin
  caster := GDVars.currentChar;
  CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(Types.PCharRecord(caster)));
  locOk := CbtMap.IsValidCreatureLoc(Types.PCharRecord(caster), GDVars.gTargetX, GDVars.gTargetY, False);
  CbtMap.ScrollView(CbtMap.CombatCellX(Types.PCharRecord(caster)), CbtMap.CombatCellY(Types.PCharRecord(caster)), 0,
                    C_Dir.CENTER);
  CharHlp.PrintCreatureMessage(caster, 'teleports', 10, True)
end;

procedure SpellFear;
var
  caster: Types.PCharRecord;
  tgt: Types.PCharRecord;
  i: Byte;
  saved: Boolean;
  eff: Pointer;
begin
  GDVars.gMultiTarget := 1;
  caster := GDVars.currentChar;
  Magic.CollectConeTargets(CbtMap.CombatCellX(Types.PCharRecord(caster)), CbtMap.CombatCellY(Types.PCharRecord(caster)),
                     GDVars.gTargetX, GDVars.gTargetY, 3, 6);
  for i := 1 to GDVars.spellTargetTotal do begin
    tgt := GDVars.spellTargetList[i];
    saved := FxEngine.RollSavingThrow(tgt, 4, 0);
    if not saved then begin
      FxEngine.AddEffectWithMessage(tgt, C_Effect.FRIGHTENED, Magic.CalcSpellDuration(84), 0, 1, 1, Byte(saved),
                                    'runs in terror');
      if CharHlp.HasEffect(tgt, C_Effect.FRIGHTENED, eff) then begin
        tgt^.combatAddr^.turned := 1;
        tgt^.quickfight := 1;
        if tgt^.npc <= $7F then tgt^.npc := C_Npc.ANIMATED_PLAYER;
        tgt^.combatAddr^.other := nil
      end
    end else
      CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
  end;
  GDVars.gMultiTarget := 0
end;

procedure SpellFireShield;
var
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  ext: Boolean;
  done: Boolean;
begin
  done := False;
  repeat
    if GDVars.currentChar^.quickfight <> 0 then
      ch := Chr(FxEngine.RollDice(1, 2) - 1)
    else begin
      MenuCore.ResetMenuSlots(1);
      ch := MenuCore.MenuHorizontal(GDConsts.flameTypePrompt, GDConsts.hotColdMenu, False, False)
    end;
    case Ord(ch) of
      0: begin
        FxEngine.AddEffectWithMessage(GDVars.currentChar, C_Effect.FIRE_SHIELD_HOT, Magic.CalcSpellDuration(85), 0, 0,
                                      0, 0, GDConsts.isWord + GDConsts.protectedMsg);
        FxEngine.AddEffectWithMessage(GDVars.currentChar, C_Effect.FIRE_SHIELD, Magic.CalcSpellDuration(85), 0, 0, 0, 0,
                                      '');
        done := True
      end;
      1: begin
        FxEngine.AddEffectWithMessage(GDVars.currentChar, C_Effect.FIRE_SHIELD_COLD, Magic.CalcSpellDuration(85), 0, 0,
                                      0, 0, GDConsts.isWord + GDConsts.protectedMsg);
        FxEngine.AddEffectWithMessage(GDVars.currentChar, C_Effect.FIRE_SHIELD, Magic.CalcSpellDuration(85), 0, 0, 0, 0,
                                      '');
        done := True
      end else
      done := MenuCore.YesNoMenu(GDConsts.abortSpellPrompt, GDConsts.yesChoice) = GDConsts.yesChoice
    end
  until done
end;

procedure SpellFumble;
var
  tgt: Types.PCharRecord;
  eff: Pointer;
begin
  tgt := GDVars.spellTargetList[1];
  GDVars.elementMask := $40;
  if not FxEngine.RollSavingThrow(tgt, 4, 0) then begin
    FxEngine.AddEffectWithMessage(tgt, C_Effect.CONFUSED_LOSE_TURN, Magic.CalcSpellDuration(86), 0, 0, 0, 0,
                                  'is clumsy');
    if CharHlp.HasEffect(tgt, C_Effect.CONFUSED_LOSE_TURN, eff) then
      FxEngine.CallEffectHandler(C_Effect.CONFUSED_LOSE_TURN, tgt, nil, False)
  end else begin
    FxEngine.AddEffectWithMessage(tgt, C_Effect.SLOWED, Magic.CalcSpellDuration(86), 0, 0, 0, 0, 'is slowed');
    if CharHlp.HasEffect(tgt, C_Effect.SLOWED, eff) then
      FxEngine.CallEffectHandler(C_Effect.SLOWED, tgt, nil, False)
  end;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, True, 0, 0, 'is clumsy')
end;

procedure SpellIceStorm;
begin
  GDVars.gMultiTarget := 1;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, FxEngine.RollDamageDice(3, 10), 8, '')
end;

procedure SpellMinorGlobeOfInvulnerability;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is protected')
end;

procedure SpellBarkskin;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is toughened')
end;

procedure SpellConeOfCold;
var
  caster: Types.PCharRecord;
  reach: Byte;
  lvl: Byte;
begin
  GDVars.gMultiTarget := 1;
  caster := GDVars.currentChar;
  lvl := CharHlp.GetCasterLevel(GDVars.spellBeingCast, False);
  reach := (CharHlp.GetCasterLevel(GDVars.spellBeingCast, False) + 1) shr 1;
  if reach < 1 then reach := 1;
  Magic.CollectConeTargets(CbtMap.CombatCellX(Types.PCharRecord(caster)), CbtMap.CombatCellY(Types.PCharRecord(caster)),
                     GDVars.gTargetX, GDVars.gTargetY, 2, reach);
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, lvl + FxEngine.RollDamageDice(lvl, 4), 10, '')
end;

procedure SpellFeeblemind;
var
  i: Byte;
  saved: Byte;
  tgt: Types.PCharRecord;
  eff: Pointer;
begin
  tgt := GDVars.spellTargetList[1];
  saved := tgt^.saves[4];
  case tgt^.charClass of
    C_Class.CLERIC: Dec(tgt^.saves[4]);
    C_Class.MAGE: Inc(tgt^.saves[4], 4)
  else
    Inc(tgt^.saves[4], 2)
  end;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, '');
  if CharHlp.HasEffect(tgt, C_Effect.FEEBLEMIND, eff) then begin
    FxEngine.CallEffectHandler(C_Effect.FEEBLEMIND, tgt, nil, False);
    for i := 0 to 140 do
      if (tgt^.spells[i] and C_Spell.PENDING_FLAG) <> 0 then
        tgt^.spells[i] := 0
  end;
  tgt^.saves[4] := saved
end;

procedure SpellScrollOfProtection;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, '')
end;

procedure SpellCharmPersonOrMammal;
var
  eff: Pointer;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  if tgt <> nil then
    if (tgt^.race < C_Race.MONSTER) or ((tgt^.creatureType and 2) <> 0) then begin
      Magic.ResolveSpell(GDVars.spellBeingCast,
                         GDVars.currentChar^.side * 128 + CharHlp.GetCasterLevel(GDVars.spellBeingCast, True), True, 0,
                         0, GDConsts.isWord + GDConsts.effectNames[C_Effect.CHARM]);
      if CharHlp.HasEffect(tgt, C_Effect.CHARM, eff) then
        FxEngine.CallEffectHandler(C_Effect.CHARM, tgt, eff, False)
    end else
      CharHlp.PrintCreatureMessage(tgt, GDConsts.isWord + 'not ' + GDConsts.effectNames[C_Effect.CHARM], 10, True)
end;

procedure SpellPotionOfInvisibility;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, '')
end;

procedure SpellDruidCureLightWounds;
begin
  if GDVars.spellTargetTotal = 0 then Exit;
  if FxEngine.RestoreHitPoints(GDVars.spellTargetList[1], FxEngine.RollDice(1, 8), False) then
    CharHlp.AnnounceHealStatus(GDVars.spellTargetList[1])
end;

procedure SpellPotionOfExtraHealing;
begin
  if FxEngine.RestoreHitPoints(GDVars.spellTargetList[1], FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargetList[1], True, 'is Healed')
end;

procedure SpellMageBestowCurse;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, '')
end;

procedure SpellRestoration;
var
  cls: ShortInt;
  i: ShortInt;
  minXp: LongInt;
  tgt: Types.PCharRecord;
  diff: Byte;
  gain: Byte;
  lostLevels: Byte;
  bonus: Byte;
  classCount: Byte;
begin
  lostLevels := 0;
  tgt := GDVars.spellTargetList[1];
  cls := C_Class.NO_CLASS;
  minXp := $7FFFFFFF;
  classCount := 0;
  for i := C_Class.CLERIC to C_Class.THIEF do
    if tgt^.peakClassLevels[i] > 0 then Inc(classCount);
  for i := C_Class.CLERIC to C_Class.THIEF do
    if tgt^.classLevels[i] < tgt^.peakClassLevels[i] then begin
      diff := tgt^.peakClassLevels[i] - tgt^.classLevels[i];
      Inc(lostLevels, diff);
      if ClassCal.XpForLevel(Types.PCharRecord(tgt), Succ(tgt^.classLevels[i]), i) <= minXp then begin
        minXp := ClassCal.XpForLevel(Types.PCharRecord(tgt), Succ(tgt^.classLevels[i]), i);
        cls := i
      end
    end;
  if cls <> C_Class.NO_CLASS then begin
    if tgt^.hpMax < tgt^.oldHpMax then begin
      gain := (tgt^.oldHpMax - tgt^.hpMax) div lostLevels;
      if tgt^.classLevels[cls] + 1 < GDConsts.firstFixedHpLevel[cls] then
        bonus := CharHlp.ClassConAdj(tgt, cls) div classCount
      else
        bonus := 0;
      Inc(tgt^.hpCur, gain);
      Inc(tgt^.hpRolled, gain - bonus);
      Inc(tgt^.hpMax, gain)
    end;
    Inc(tgt^.classLevels[cls]);
    ClassCal.RecalcClassStats(Types.PCharRecord(tgt));
    if (lostLevels = 1) and (tgt^.experience < tgt^.oldExperience) then
      tgt^.experience := tgt^.oldExperience
    else
      tgt^.experience := minXp
  end;
  tgt^.levelCapped := Byte(CharHlp.CanLevelUp(tgt))
end;

procedure SpellEnergyDrain;
begin
  GDVars.currentChar^.combatAddr^.other := GDVars.spellTargetList[1];
  GDVars.effectFns[C_Effect.DRAIN_ONE_LEVEL](GDVars.currentChar, nil, False)
end;

procedure SpellDestruction;
var
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  GDVars.elementMask := $48;
  GDVars.pendingDamage := $FF;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, tgt);
  if ((tgt^.immunities and 8) = 0) and (GDVars.pendingDamage <> 0) then
    FxEngine.KillCreature(tgt, C_Status.GONE, 'is destroyed')
  else
    CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
end;

procedure SpellResurrection;
var
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  if (tgt^.status = C_Status.DEAD_STATUS) and (tgt^.stats[C_Stat.CONSTITUTION].base > 0) and
      (tgt^.race > C_Race.ELF) then begin
    FxEngine.RemoveEffect(tgt, C_Effect.POISONED, nil);
    tgt^.status := C_Status.OKAY;
    tgt^.inPlay := 1;
    tgt^.hpCur := tgt^.hpMax;
    CharHlp.PrintCreatureMessage(tgt, GDConsts.isWord + 'ressurected', 10, True)
  end
end;

procedure SpellHoldAnimal;
var
  saveMod: ShortInt;
begin
  case GDVars.spellTargetTotal of
    1: saveMod := -4;
    2: saveMod := -2;
    3: saveMod := -1
  else
    saveMod := 0
  end;
  Magic.ApplyEffectToTargets(saveMod, 'is held')
end;

procedure SpellProtectionFromFire;
var
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  if tgt <> nil then
    if ClassCal.EffectiveClassLevel(Types.PCharRecord(tgt), C_Class.RANGER) > 0 then
      FxEngine.AddEffectWithMessage(tgt, C_Effect.RESIST_FIRE_DRUID, 0, CharHlp.GetCasterLevel(109, False), 0, 0, 0,
                                    GDConsts.isWord + GDConsts.protectedMsg)
    else
      FxEngine.AddEffectWithMessage(tgt, C_Effect.RESIST_FIRE, Magic.CalcSpellDuration(109),
                                    ClassCal.EffectiveClassLevel(Types.PCharRecord(tgt), C_Class.RANGER), 0, 0,
                                    0, GDConsts.isWord + GDConsts.protectedMsg)
end;

procedure SpellDeathSpell;
var
  tgt: Types.PCharRecord;
  i: Byte;
begin
  GDVars.gMultiTarget := 1;
  GDVars.elementMask := $40;
  GDVars.spellTemp1 := FxEngine.RollDice(4, 20) * 2;
  for i := 1 to GDVars.spellTargetTotal do begin
    tgt := GDVars.spellTargetList[i];
    case tgt^.hitDice of
      0: GDVars.spellTemp2 := 1;
      1: GDVars.spellTemp2 := 2;
      2..3: GDVars.spellTemp2 := 8;
      4..5: GDVars.spellTemp2 := 16;
      6: if tgt^.hpMax <= 51 then GDVars.spellTemp2 := 16
         else GDVars.spellTemp2 := 20;
      7..8: GDVars.spellTemp2 := 20
    else
      GDVars.spellTemp2 := 162
    end;
    GDVars.pendingDamage := 100;
    FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, tgt);
    if ((tgt^.immunities and 8) = 0) and (GDVars.pendingDamage <> 0) and
        (GDVars.spellTemp1 >= GDVars.spellTemp2) then begin
      Dec(GDVars.spellTemp1, GDVars.spellTemp2);
      FxEngine.KillCreature(tgt, C_Status.DEAD_STATUS, 'drops dead')
    end else
      GDVars.spellTargetList[i] := nil
  end
end;

procedure SpellDisintegrate;
var
  saved: Boolean;
  tgt: Types.PCharRecord;
begin
  GDVars.elementMask := $48;
  tgt := GDVars.spellTargetList[1];
  GDVars.pendingDamage := $FF;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, tgt);
  if GDVars.pendingDamage <> 0 then begin
    saved := FxEngine.RollSavingThrow(tgt, 4, 0);
    if not saved then begin
      FxEngine.KillCreature(tgt, C_Status.DEAD_STATUS, 'disintegrates');
      while tgt^.items <> nil do
        CharHlp.RemoveItem(tgt, tgt^.items)
    end else
      CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
  end else
    CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
end;

procedure SpellGlobeOfInvulnerability;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, GDConsts.isWord + 'protected')
end;

procedure SpellStoneToFlesh;
var
  tgt: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  key: Byte;
  i: Byte;
  j: Byte;
begin
  tgt := GDVars.spellTargetList[1];
  if tgt^.status = C_Status.PETRIFIED then begin
    tgt^.status := C_Status.OKAY;
    tgt^.inPlay := 1;
    tgt^.hpCur := 1;
    CharHlp.PrintCreatureMessage(tgt, GDConsts.isWord + 'no longer a statue', 10, False);
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      i := 1;
      while GDVars.downedList[i].cr <> tgt do Inc(i);
      GDVars.arenaPtr^.cells[GDVars.downedList[i].y, GDVars.downedList[i].x] := GDVars.downedList[i].terrain;
      for j := i to GDVars.downedListCount - 1 do
        GDVars.downedList[j] := GDVars.downedList[j + 1];
      Dec(GDVars.downedListCount);
      if CbtMap.IsValidCreatureLoc(Types.PCharRecord(tgt), CbtMap.CombatCellX(Types.PCharRecord(tgt)),
                                   CbtMap.CombatCellY(Types.PCharRecord(tgt)), True) then
        CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 0, C_Dir.CENTER)
    end
  end;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, '')
end;

procedure SpellFleshToStone;
var
  saved: Boolean;
  tgt: Types.PCharRecord;
begin
  GDVars.elementMask := $40;
  tgt := GDVars.spellTargetList[1];
  GDVars.pendingDamage := $FF;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, tgt);
  if GDVars.pendingDamage <> 0 then begin
    saved := FxEngine.RollSavingThrow(tgt, 4, 0);
    if not saved then
      FxEngine.KillCreature(tgt, C_Status.PETRIFIED, GDConsts.isWord + 'turned to stone')
  end
end;

procedure SpellMassInvisibility;
var
  i: Byte;
begin
  GDVars.gMultiTarget := 1;
  for i := 1 to GDVars.spellTargetTotal do begin
    if (GDVars.spellTargetList[i]^.side <> GDVars.currentChar^.side) or
        ((GDVars.interfaceState = C_Ifc.IN_COMBAT) and
         (CharHlp.CountTargets(GDVars.spellTargetList[i], 1, False) > 0)) then
      GDVars.spellTargetList[i] := nil
  end;
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, GDConsts.isWord + GDConsts.effectNames[C_Effect.INVISIBLE])
end;

procedure SpellPowerWordStun;
var
  duration: Byte;
  tgt: Types.PCharRecord;
begin
  GDVars.gMultiTarget := 1;
  tgt := GDVars.spellTargetList[1];
  case tgt^.hpCur of
    1..30: duration := FxEngine.RollDice(4, 4);
    31..60: duration := FxEngine.RollDice(2, 4);
    61..90: duration := FxEngine.RollDice(1, 4)
  else
    duration := 0
  end;
  FxEngine.AddEffectWithMessage(tgt, GDConsts.spellTable[117].effect, duration, CharHlp.GetCasterLevel(117, True), 0,
                                GDConsts.spellTable[117].saveResult, 0,
                                GDConsts.isWord + GDConsts.effectNames[C_Effect.STUNNED])
end;

procedure SpellFireTouch;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is covered in flame')
end;

procedure SpellIronSkin;
begin
  Magic.ResolveSpell(GDVars.spellBeingCast, 0, False, 0, 0, 'is protected')
end;

procedure SpellMassCharm;
var
  eff: Pointer;
  tgt: Types.PCharRecord;
  done: Boolean;
  i: Byte;
  cost: Byte;
  total: Byte;
  limit: Byte;
begin
  GDVars.gMultiTarget := 1;
  done := False;
  total := 0;
  i := 1;
  limit := CharHlp.GetCasterLevel(GDVars.spellBeingCast, False) * 2;
  while (i <= GDVars.spellTargetTotal) and not done do begin
    tgt := GDVars.spellTargetList[i];
    if tgt <> nil then
      if ((tgt^.immunities and 2) = 0) or (tgt^.iconDimensions > 1) or (tgt^.side = GDVars.currentChar^.side) then
        CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
      else begin
        cost := tgt^.hitDice;
        if cost + total <= limit then begin
          Inc(total, cost);
          done := total = limit;
          FxEngine.AddEffectWithMessage(tgt, C_Effect.CHARM, Magic.CalcSpellDuration(GDVars.spellBeingCast),
                                        GDVars.currentChar^.side * 128 +
                                        CharHlp.GetCasterLevel(GDVars.spellBeingCast, True), 1, 1,
                                        Byte(FxEngine.RollSavingThrow(tgt, 4, -2)), 'is charmed');
          if CharHlp.HasEffect(tgt, C_Effect.CHARM, eff) then
            FxEngine.CallEffectHandler(C_Effect.CHARM, tgt, eff, False)
        end
      end;
    Inc(i)
  end
end;

procedure SpellIrresistibleDance;
var
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargetList[1];
  CharHlp.RecalcStats(tgt);
  FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_ARMOR_CLASS, tgt);
  if FxEngine.AttackRoll(GDVars.currentChar, tgt, tgt^.armorClass[0]) then begin
    FxEngine.AddEffectWithMessage(tgt, C_Effect.CONFUSED_LOSE_TURN, Magic.CalcSpellDuration(121),
                                  CharHlp.GetCasterLevel(121, True), 0, 0, 0, GDConsts.emptyQuery);
    FxEngine.AddEffectWithMessage(tgt, C_Effect.DANCING, Magic.CalcSpellDuration(121), CharHlp.GetCasterLevel(121,
        True), 0, 0, 0,
                                  'begins to dance wildly')
  end
end;

procedure SpellPowerWordBlind;
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
  tgt: Types.PCharRecord;
  duration: Byte;
  i: Byte;
  totalHp: Byte;
begin
  GDVars.gMultiTarget := 1;
  i := 1;
  totalHp := 0;
  while (i <= GDVars.spellTargetTotal) and (totalHp <= 100) do begin
    tgt := GDVars.spellTargetList[i];
    if (tgt^.hpMax <= 100) and (tgt^.hpMax + totalHp <= 100) then
      Inc(totalHp, tgt^.hpMax);
    Inc(i)
  end;
  duration := FxEngine.RollDice(1, 4) + 1;
  if totalHp < 51 then
    duration := duration * 10;
  i := 1;
  totalHp := 0;
  while (i <= GDVars.spellTargetTotal) and (totalHp <= 100) do begin
    tgt := GDVars.spellTargetList[i];
    if (tgt^.hpMax <= 100) and (tgt^.hpMax + totalHp <= 100) then begin
      Inc(totalHp, tgt^.hpMax);
      FxEngine.AddEffectWithMessage(tgt, C_Effect.BLIND, Magic.CalcSpellDuration(GDVars.spellBeingCast), 0, 0, 0, 0,
                                    'is blinded')
    end;
    Inc(i)
  end
end;

procedure SpellMeteorSwarm;
var
  caster: Types.PCharRecord;
  origX: ShortInt;
  origY: ShortInt;
  casterX: ShortInt;
  casterY: ShortInt;
  newX: ShortInt;
  newY: ShortInt;
  dir: Byte;
  oldCount: Byte;
  mode: Byte;
  i: Byte;
  reach: Word;
  ok: Boolean;

  { Picks a meteor's landing cell for a direction and mode, and tells whether the caster can see it. }
  function TryAim(direction, mode: Byte): Boolean;
  begin
    reach := $FF;
    case direction of
      1: begin
           newX := origX + GDConsts.aimDeltas.dx[mode];
           newY := origY + GDConsts.aimDeltas.dy[mode]
         end;
      2: newX := origX;
      3: begin
           newX := origX + GDConsts.aimDeltas.dx[mode];
           newY := origY
         end;
      4: newX := origX
    end;
    TryAim := Pathing.WalkLine(casterX, casterY, newX, newY, reach);
    reach := reach div 2
  end;

begin
  GDVars.gMultiTarget := 1;
  GDVars.elementMask := 9;
  caster := GDVars.currentChar;
  casterX := CbtMap.CombatCellX(Types.PCharRecord(caster));
  casterY := CbtMap.CombatCellY(Types.PCharRecord(caster));
  origX := GDVars.gTargetX;
  origY := GDVars.gTargetY;
  for mode := 1 to 4 do begin
    GameIo.ZeroFill(GDVars.spellTargetList, SizeOf(GDVars.spellTargetList));
    i := 1;
    repeat
      ok := TryAim(i, mode);
      Inc(i)
    until (i > 4) or ok;
    while not Pathing.IsDirToward(casterX, casterY, GDVars.gTargetX, GDVars.gTargetY, dir) do Inc(dir);
    GDVars.combatGfxOn := 1;
    CbtMap.SetCreatureFacing(Types.PCharRecord(caster), dir, 1, 0);
    Blit.BuildIconFrames(30);
    CharHlp.BuildIconFacingsDir(dir, 30);
    CharHlp.CombatAnimateMovingIcon(casterX, casterY, newX, newY, 1, 30);
    GDVars.gTargetX := newX;
    GDVars.gTargetY := newY;
    CharHlp.ScatterCombatIcon(1, 23, Byte(GDConsts.soundIds[Magic.SOUND_FIREBALL]));
    Magic.CollectConeTargets(casterX, casterY, newX, newY, 1, Byte(reach));
    oldCount := GDVars.spellTargetTotal;
    Pathing.BuildTargetList(newX, newY, 1, $FF, 1);
    for i := 1 to GDVars.rankedTargetCount do begin
      Inc(GDVars.spellTargetTotal);
      GDVars.spellTargetList[GDVars.spellTargetTotal] := GDVars.slotCreatures[GDVars.rankedTargets[i].ent]
    end;
    for i := 1 to GDVars.spellTargetTotal do
      if (GDVars.spellTargetList[i] <> nil) and (GDVars.spellTargetList[i]^.inPlay <> 0) then
        if i <= oldCount then
          FxEngine.InflictNonWeaponDamage(GDVars.spellTargetList[i], FxEngine.RollDamageDice(10, 4), 0, False)
        else
          FxEngine.InflictNonWeaponDamage(GDVars.spellTargetList[i], FxEngine.RollDamageDice(10, 4), 2,
                                          FxEngine.RollSavingThrow(GDVars.spellTargetList[i], 4, 0));
    if CbtMap.CombatIconVisible(Types.PCharRecord(caster), 0) then begin
      CbtMap.SetCreatureFacing(Types.PCharRecord(caster), caster^.combatAddr^.direction, 1, 1);
      CbtMap.SetCreatureFacing(Types.PCharRecord(caster), caster^.combatAddr^.direction, 0, 0)
    end
  end
end;

procedure SpellPowerWordKill;
var
  i: Byte;
begin
  GDVars.gMultiTarget := 1;
  if GDVars.spellTargetTotal > 0 then
    if (GDVars.spellTargetList[1] <> nil) and (GDVars.spellTargetList[1]^.hpMax <= 60) and
        (GDVars.spellTargetList[1]^.hpMax > 10) then begin
      GDVars.pendingDamage := $FF;
      FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, GDVars.spellTargetList[1]);
      if GDVars.pendingDamage <> 0 then
        FxEngine.KillCreature(GDVars.spellTargetList[1], C_Status.DEAD_STATUS, 'is slain')
    end else
      for i := 1 to GDVars.spellTargetTotal do
        if (GDVars.spellTargetList[i] <> nil) and (GDVars.spellTargetList[i]^.hpMax <= 10) then begin
          GDVars.pendingDamage := $FF;
          FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, GDVars.spellTargetList[i]);
          if GDVars.pendingDamage <> 0 then
            FxEngine.KillCreature(GDVars.spellTargetList[i], C_Status.DEAD_STATUS, 'is slain')
        end
end;

procedure SpellMonsterSummoning;
var
  x: ShortInt;
  y: ShortInt;
  newX: ShortInt;
  newY: ShortInt;
  dir: ShortInt;
  candidate: Types.PCharRecord;
  walker: Types.PCharRecord;
  done: Boolean;
  found: Boolean;
  placed: Byte;
  terrIdx: Byte;
  crIdx: Byte;
  wantedTerrain: Byte;
  slot: Byte;
begin
  walker := GDVars.creatureListHead;
  candidate := GDVars.creatureListHead;
  done := False;
  dir := 0;
  placed := 0;
  if GDVars.vmBand.zone0^.inDungeon <> 0 then wantedTerrain := 23
  else wantedTerrain := 69;
  while (walker <> nil) and (walker^.status <> 9) do
    walker := walker^.next;
  repeat
    if dir > 7 then begin
      if (candidate = nil) or (candidate^.next = nil) or (candidate^.status = 9) then begin
        candidate := GDVars.currentChar;
        done := True
      end else
        candidate := candidate^.next;
      dir := 0
    end;
    if (walker = nil) or (placed = 2) then
      done := True
    else begin
      walker^.side := GDVars.currentChar^.side;
      x := CbtMap.CombatCellX(Types.PCharRecord(candidate));
      y := CbtMap.CombatCellY(Types.PCharRecord(candidate));
      found := False;
      repeat
        newX := x + GDConsts.dirDeltaX[dir];
        newY := y + GDConsts.dirDeltaY[dir];
        if (newX <= 49) and (newX >= 0) and (newY <= 24) and (newY >= 0) then begin
          CbtMap.GetArenaContents(newX, newY, crIdx, terrIdx);
          if (crIdx = 0) and (terrIdx = wantedTerrain) then begin
            slot := CbtMap.CombatSlot(Types.PCharRecord(walker));
            GDVars.arenaSlots[slot].sizeCode := walker^.iconDimensions and 7;
            GDVars.arenaSlots[slot].x := newX;
            GDVars.arenaSlots[slot].y := newY;
            found := FxEngine.ReviveDeadCreature(walker, walker^.hpMax, 'gates in');
            if found then begin
              Inc(placed);
              walker := walker^.next;
              if (walker = nil) or (walker^.status <> 9) then done := True
            end
          end;
          Inc(dir)
        end;
      until found or (dir > 7)
    end
  until done;
  if placed = 0 then
    CharHlp.PrintCreatureMessage(GDVars.currentChar, 'summons is not answered', 10, True)
end;

procedure EffBreathePoison(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  x: ShortInt;
  y: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  targetCell: array[1..2] of Byte;
  accepted: Boolean;
  saved: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
  tgt: Types.PCharRecord;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  retained: array[1..30] of Byte;
  dir: Byte;
begin
  GDVars.gMultiTarget := 1;
  if GDVars.combatRound = 0 then
    Types.PEffectRec(eff)^.strength := 3;
  if Types.PEffectRec(eff)^.strength > 0 then begin
    x := CbtMap.CombatCellX(Types.PCharRecord(cr));
    y := CbtMap.CombatCellY(Types.PCharRecord(cr));
    GDVars.spellFps.castMenu(61, 1, accepted);
    if accepted then begin
      Magic.CollectConeTargets(x, y, GDVars.gTargetX, GDVars.gTargetY, $FF, 3);
      if GDVars.spellTargetTotal > 0 then begin
        GDVars.elementMask := $20;
        CharHlp.PrintCreatureMessage(cr, 'breathes poison', 10, True);
        dir := CbtMap.DirectionToward(Types.PCharRecord(cr), GDVars.spellTargetList[1]);
        CharHlp.CombatPrintCreatureInfo(cr);
        CbtMap.SetCreatureFacing(Types.PCharRecord(cr), dir, 1, 0);
        Blit.BuildIconFrames(17);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(cr)),
                                        CbtMap.CombatCellY(Types.PCharRecord(cr)),
                                        CbtMap.CombatCellX(GDVars.spellTargetList[1]),
                                        CbtMap.CombatCellY(GDVars.spellTargetList[1]), 1, 30);
        for i := 1 to GDVars.spellTargetTotal do
          if GDVars.spellTargetList[i] <> nil then begin
            tgt := GDVars.spellTargetList[i];
            saved := FxEngine.RollSavingThrow(tgt, 3, 0);
            FxEngine.InflictNonWeaponDamage(tgt, Types.PCharRecord(cr)^.hpMax, 2, saved)
          end;
        Dec(Types.PEffectRec(eff)^.strength);
        actionsEnded := CharHlp.EndActions(cr)
      end
    end
  end;
  GDVars.gMultiTarget := 0
end;

procedure EffBreatheLightning(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
  x: ShortInt;
  y: ShortInt;
  dir: Byte;
begin
  if (GDVars.combatRound = 0) or (Types.PEffectRec(eff)^.strength > 3) then
    Types.PEffectRec(eff)^.strength := 3;
  if Types.PEffectRec(eff)^.strength > 0 then begin
    GDVars.elementMask := $24;
    x := CbtMap.CombatCellX(Types.PCharRecord(cr));
    y := CbtMap.CombatCellY(Types.PCharRecord(cr));
    GDVars.spellFps.castMenu(51, 1, GDVars.scratchFlag);
    if GDVars.scratchFlag then begin
      CharHlp.PrintCreatureMessage(cr, 'breathes lightning', 10, True);
      dir := CbtMap.DirectionToward(Types.PCharRecord(cr), GDVars.spellTargetList[1]);
      CharHlp.CombatPrintCreatureInfo(cr);
      CbtMap.SetCreatureFacing(Types.PCharRecord(cr), dir, 1, 0);
      Blit.BuildIconFrames(18);
      CharHlp.CombatAnimateMovingIcon(x, y, GDVars.gTargetX, GDVars.gTargetY, 4, 50);
      Magic.LightningPath(9, Types.PCharRecord(cr)^.hpMax, False);
      Dec(Types.PEffectRec(eff)^.strength);
      actionsEnded := CharHlp.EndActions(cr)
    end
  end
end;

procedure EffDragonBreath(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
  x: ShortInt;
  y: ShortInt;
  i: Byte;
  tgt: Types.PCharRecord;
  saved: Boolean;
  rays: Byte;
  reach: Byte;
  elementName: String[20];
  breathDamage: Word;
  dir: Byte;
begin
  GDVars.gMultiTarget := 1;
  if (GDVars.combatRound = 0) or (Types.PEffectRec(eff)^.strength > 3) then
    Types.PEffectRec(eff)^.strength := 3;
  if Types.PEffectRec(eff)^.strength > 0 then begin
    breathDamage := Types.PCharRecord(cr)^.hpMax;
    case Types.PEffectRec(eff)^.id of
      C_Effect.RED_DRAGON_BREATH, C_Effect.BIG_RED_DRAGON_BREATH:
        begin
          GDVars.elementMask := $21;
          rays := 3;
          reach := 9;
          elementName := 'Fire';
          if Types.PEffectRec(eff)^.id = C_Effect.BIG_RED_DRAGON_BREATH then
            breathDamage := FxEngine.RollDamageDice(24, 10) + 12
        end;
      C_Effect.WHITE_DRAGON_BREATH:
        begin
          GDVars.elementMask := $22;
          rays := 3;
          reach := 7;
          elementName := 'cold'
        end;
      C_Effect.BLACK_DRAGON_BREATH:
        begin
          GDVars.elementMask := $20;
          rays := 1;
          reach := 6;
          elementName := 'acid'
        end
    end;
    x := CbtMap.CombatCellX(Types.PCharRecord(cr));
    y := CbtMap.CombatCellY(Types.PCharRecord(cr));
    GDVars.spellFps.castMenu(23, 1, GDVars.scratchFlag);
    if GDVars.scratchFlag then begin
      Magic.CollectConeTargets(x, y, GDVars.gTargetX, GDVars.gTargetY, rays, reach);
      for i := 1 to GDVars.spellTargetTotal do
        if CharHlp.EnemyTeam(cr) <> GDVars.spellTargetList[i]^.side then
          GDVars.scratchFlag := False;
      if (GDVars.spellTargetTotal > 0) and (GDVars.scratchFlag) then begin
        CharHlp.PrintCreatureMessage(cr, 'breathes ' + elementName, 10, True);
        dir := CbtMap.DirectionToward(Types.PCharRecord(cr), GDVars.spellTargetList[1]);
        CharHlp.CombatPrintCreatureInfo(cr);
        CbtMap.SetCreatureFacing(Types.PCharRecord(cr), dir, 1, 0);
        Blit.BuildIconFrames(17);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(cr)),
                                        CbtMap.CombatCellY(Types.PCharRecord(cr)),
                                        CbtMap.CombatCellX(GDVars.spellTargetList[1]),
                                        CbtMap.CombatCellY(GDVars.spellTargetList[1]), 1, 30);
        for i := 1 to GDVars.spellTargetTotal do
          if GDVars.spellTargetList[i] <> nil then begin
            tgt := GDVars.spellTargetList[i];
            saved := FxEngine.RollSavingThrow(tgt, 3, 0);
            FxEngine.InflictNonWeaponDamage(tgt, breathDamage, 2, saved)
          end;
        Dec(Types.PEffectRec(eff)^.strength);
        actionsEnded := CharHlp.EndActions(cr)
      end
    end
  end;
  GDVars.gMultiTarget := 0
end;

procedure EffGazeCharm(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  accepted: Boolean;
  dir: Byte;
begin
  GDVars.spellFps.castMenu(10, 1, accepted);
  if not accepted then Exit;
  GDVars.gMultiTarget := 1;
  GDVars.elementMask := $10;
  CharHlp.PrintCreatureMessage(cr, 'gazes', 10, True);
  dir := CbtMap.DirectionToward(Types.PCharRecord(cr), GDVars.spellTargetList[1]);
  CbtMap.SetCreatureFacing(Types.PCharRecord(cr), dir, 1, 0);
  Blit.BuildIconFrames(17);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)),
                                  GDVars.gTargetX, GDVars.gTargetY, 4, 50);
  GDVars.spellBeingCast := 10;
  GDVars.spellFps.spells[10];
  GDVars.gMultiTarget := 0
end;

function ItemReadable(it: Pointer): Boolean;
begin
  if (it <> nil) and
      ((Types.PItemRec(it)^.definition.itemType = 39) or (Types.PItemRec(it)^.definition.itemType = 40)) then
    ItemReadable := True
  else
    ItemReadable := False
end;

procedure RemoveSpellFromScroll(cr, it: Pointer; sp: Byte);
var
  spell: Byte;
  i: Byte;
  found: Byte;
begin
  spell := sp;
  found := 0;
  for i := 1 to 3 do
    if (Types.PItemRec(it)^.definition.scrollSpells[i] and C_Spell.ID_MASK) = spell then
      found := i;
  if found = 0 then Exit;
  Types.PItemRec(it)^.definition.scrollSpells[found] := 0;
  Dec(Types.PItemRec(it)^.definition.nameIds[1]);
  if Types.PItemRec(it)^.definition.nameIds[1] < 100 then
    CharHlp.RemoveItem(cr, it)
end;

procedure PrintCastSpellMsg(cr: Pointer; s: Types.TStr40; id: Byte);
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    CharHlp.PrintCreatureMessage(cr, 'Casts a Spell', 10, True);
    Border.ClearBox(0, 23, 39, 23);
    TextRend.DisplayString(0, 23, 10, 0, 'Spell:' + GDConsts.spellNames[id])
  end else begin
    Border.ClearBox(1, 18, 38, 22);
    CharHlp.DisplayCreatureName(cr, 1, 19, False);
    TextRend.DisplayString(Length(Types.PCharRecord(cr)^.name) + 2, 19, 10, 0, s);
    TextRend.DisplayString(1, 20, 10, 0, GDConsts.spellNames[id]);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow
  end
end;

procedure InitSpellFns;
begin
  @GDVars.spellFps.castMenu := @Magic.NoncombatCastTargetMenu;
  GDVars.effectLock := 0;
  GDVars.castFromItem := 0;
  GDVars.itemsMenuRedraw := 1;
  @GDVars.spellFps.spells[1] := @Magic.SpellBless;
  @GDVars.spellFps.spells[2] := @Magic.SpellCurse;
  @GDVars.spellFps.spells[3] := @Magic.SpellCureLightWounds;
  @GDVars.spellFps.spells[4] := @Magic.SpellCauseLightWounds;
  @GDVars.spellFps.spells[5] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[6] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[7] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[8] := @Magic.SpellResistCold;
  @GDVars.spellFps.spells[9] := @Magic.SpellBurningHands;
  @GDVars.spellFps.spells[10] := @Magic.SpellCharmPerson;
  @GDVars.spellFps.spells[11] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[12] := @Magic.SpellEnlarge;
  @GDVars.spellFps.spells[13] := @Magic.SpellReduce;
  @GDVars.spellFps.spells[14] := @Magic.SpellFriends;
  @GDVars.spellFps.spells[15] := @Magic.SpellMagicMissile;
  @GDVars.spellFps.spells[16] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[17] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[18] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[19] := @Magic.SpellShield;
  @GDVars.spellFps.spells[20] := @Magic.SpellShockingGrasp;
  @GDVars.spellFps.spells[21] := @Magic.SpellSleep;
  @GDVars.spellFps.spells[22] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[23] := @Magic.SpellHold;
  @GDVars.spellFps.spells[24] := @Magic.SpellResistFire;
  @GDVars.spellFps.spells[25] := @Magic.SpellSilence;
  @GDVars.spellFps.spells[26] := @Magic.SpellSlowPoison;
  @GDVars.spellFps.spells[27] := @Magic.SpellSnakeCharm;
  @GDVars.spellFps.spells[28] := @Magic.SpellSpiritualHammer;
  @GDVars.spellFps.spells[29] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[30] := @Magic.SpellInvisibility;
  @GDVars.spellFps.spells[31] := @Magic.SpellKnock;
  @GDVars.spellFps.spells[32] := @Magic.SpellMirrorImage;
  @GDVars.spellFps.spells[33] := @Magic.SpellRayOfEnfeeblement;
  @GDVars.spellFps.spells[34] := @Magic.SpellStinkingCloud;
  @GDVars.spellFps.spells[35] := @Magic.SpellStrength;
  @GDVars.spellFps.spells[36] := @Magic.SpellHeal;
  @GDVars.spellFps.spells[37] := @Magic.SpellCureBlindness;
  @GDVars.spellFps.spells[38] := @Magic.SpellCauseBlindness;
  @GDVars.spellFps.spells[39] := @Magic.SpellCureDisease;
  @GDVars.spellFps.spells[40] := @Magic.SpellCauseDisease;
  @GDVars.spellFps.spells[41] := @Magic.SpellDispelMagic;
  @GDVars.spellFps.spells[42] := @Magic.SpellPrayer;
  @GDVars.spellFps.spells[43] := @Magic.SpellRemoveCurse;
  @GDVars.spellFps.spells[44] := @Magic.SpellBestowCurse;
  @GDVars.spellFps.spells[45] := @Magic.SpellBlink;
  @GDVars.spellFps.spells[46] := @Magic.SpellDispelMagic;
  @GDVars.spellFps.spells[47] := @Magic.SpellFireball;
  @GDVars.spellFps.spells[48] := @Magic.SpellHaste;
  @GDVars.spellFps.spells[49] := @Magic.SpellHold;
  @GDVars.spellFps.spells[50] := @Magic.SpellInvisibility;
  @GDVars.spellFps.spells[51] := @Magic.SpellLightningBolt;
  @GDVars.spellFps.spells[52] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[53] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[54] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[55] := @Magic.SpellSlow;
  @GDVars.spellFps.spells[56] := @Magic.SpellHarm;
  @GDVars.spellFps.spells[57] := @Magic.SpellPotionOfSpeed;
  @GDVars.spellFps.spells[58] := @Magic.SpellCureSeriousWounds;
  @GDVars.spellFps.spells[59] := @Magic.SpellGiantStrength;
  @GDVars.spellFps.spells[60] := @Magic.SpellJavelinOfLightning;
  @GDVars.spellFps.spells[61] := @Magic.SpellWandOfParalyzation;
  @GDVars.spellFps.spells[62] := @Magic.SpellPotionOfHealing;
  @GDVars.spellFps.spells[63] := @Magic.SpellYouth;
  @GDVars.spellFps.spells[64] := @Magic.SpellFireball;
  @GDVars.spellFps.spells[65] := @Magic.SpellWandOfMagicMissiles;
  @GDVars.spellFps.spells[66] := @Magic.SpellCauseSeriousWounds;
  @GDVars.spellFps.spells[67] := @Magic.SpellNeutralizePoison;
  @GDVars.spellFps.spells[68] := @Magic.SpellPoison;
  @GDVars.spellFps.spells[69] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[70] := @Magic.SpellSticksToSnakes;
  @GDVars.spellFps.spells[71] := @Magic.SpellCureCriticalWounds;
  @GDVars.spellFps.spells[72] := @Magic.SpellCauseCriticalWounds;
  @GDVars.spellFps.spells[73] := @Magic.SpellDispelEvil;
  @GDVars.spellFps.spells[74] := @Magic.SpellFlameStrike;
  @GDVars.spellFps.spells[75] := @Magic.SpellRaiseDead;
  @GDVars.spellFps.spells[76] := @Magic.SpellSlayLiving;
  @GDVars.spellFps.spells[77] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[78] := @Magic.SpellEntangle;
  @GDVars.spellFps.spells[79] := @Magic.SpellFaerieFire;
  @GDVars.spellFps.spells[80] := @Magic.SpellInvisibilityToAnimals;
  @GDVars.spellFps.spells[81] := @Magic.SpellCharmMonsters;
  @GDVars.spellFps.spells[82] := @Magic.SpellConfusion;
  @GDVars.spellFps.spells[83] := @Magic.SpellDimensionDoor;
  @GDVars.spellFps.spells[84] := @Magic.SpellFear;
  @GDVars.spellFps.spells[85] := @Magic.SpellFireShield;
  @GDVars.spellFps.spells[86] := @Magic.SpellFumble;
  @GDVars.spellFps.spells[87] := @Magic.SpellIceStorm;
  @GDVars.spellFps.spells[88] := @Magic.SpellMinorGlobeOfInvulnerability;
  @GDVars.spellFps.spells[89] := @Magic.SpellRemoveCurse;
  @GDVars.spellFps.spells[90] := @Magic.SpellBarkskin;
  @GDVars.spellFps.spells[91] := @Magic.SpellStinkingCloud;
  @GDVars.spellFps.spells[92] := @Magic.SpellConeOfCold;
  @GDVars.spellFps.spells[93] := @Magic.SpellFeeblemind;
  @GDVars.spellFps.spells[94] := @Magic.SpellHold;
  @GDVars.spellFps.spells[95] := @Magic.SpellScrollOfProtection;
  @GDVars.spellFps.spells[96] := @Magic.SpellCharmPersonOrMammal;
  @GDVars.spellFps.spells[97] := @Magic.SpellPotionOfInvisibility;
  @GDVars.spellFps.spells[98] := @Magic.SpellDruidCureLightWounds;
  @GDVars.spellFps.spells[99] := @Magic.SpellPotionOfExtraHealing;
  @GDVars.spellFps.spells[100] := @Magic.SpellMageBestowCurse;
  @GDVars.spellFps.spells[101] := @Magic.SpellStinkingCloud;
  @GDVars.spellFps.spells[102] := @Magic.SpellRestoration;
  @GDVars.spellFps.spells[103] := @Magic.SpellEnergyDrain;
  @GDVars.spellFps.spells[104] := @Magic.SpellDestruction;
  @GDVars.spellFps.spells[105] := @Magic.SpellResurrection;
  @GDVars.spellFps.spells[106] := @Magic.SpellCureDisease;
  @GDVars.spellFps.spells[107] := @Magic.SpellNeutralizePoison;
  @GDVars.spellFps.spells[108] := @Magic.SpellHoldAnimal;
  @GDVars.spellFps.spells[109] := @Magic.SpellProtectionFromFire;
  @GDVars.spellFps.spells[110] := @Magic.SpellDeathSpell;
  @GDVars.spellFps.spells[111] := @Magic.SpellDisintegrate;
  @GDVars.spellFps.spells[112] := @Magic.SpellGlobeOfInvulnerability;
  @GDVars.spellFps.spells[113] := @Magic.SpellStoneToFlesh;
  @GDVars.spellFps.spells[114] := @Magic.SpellFleshToStone;
  @GDVars.spellFps.spells[115] := @Magic.SpellFireball;
  @GDVars.spellFps.spells[116] := @Magic.SpellMassInvisibility;
  @GDVars.spellFps.spells[117] := @Magic.SpellPowerWordStun;
  @GDVars.spellFps.spells[118] := @Magic.SpellFireTouch;
  @GDVars.spellFps.spells[119] := @Magic.SpellIronSkin;
  @GDVars.spellFps.spells[120] := @Magic.SpellMassCharm;
  @GDVars.spellFps.spells[121] := @Magic.SpellIrresistibleDance;
  @GDVars.spellFps.spells[122] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[123] := @Magic.SpellPowerWordBlind;
  @GDVars.spellFps.spells[124] := @Magic.SpellMeteorSwarm;
  @GDVars.spellFps.spells[125] := @Magic.SpellPowerWordKill;
  @GDVars.spellFps.spells[126] := @Magic.SpellMonsterSummoning;
  @GDVars.effectFns[C_Effect.BLUE_DRAGON_BREATH] := @Magic.EffBreatheLightning;
  @GDVars.effectFns[C_Effect.RED_DRAGON_BREATH] := @Magic.EffDragonBreath;
  @GDVars.effectFns[C_Effect.BIG_RED_DRAGON_BREATH] := @Magic.EffDragonBreath;
  @GDVars.effectFns[C_Effect.WHITE_DRAGON_BREATH] := @Magic.EffDragonBreath;
  @GDVars.effectFns[C_Effect.GREEN_DRAGON_BREATH] := @Magic.EffBreathePoison;
  @GDVars.effectFns[C_Effect.BLACK_DRAGON_BREATH] := @Magic.EffDragonBreath;
  @GDVars.effectFns[Magic.EFF_CHARM_GAZE] := @Magic.EffGazeCharm;
end;
begin
end.
