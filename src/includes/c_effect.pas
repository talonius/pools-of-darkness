{ Effect IDs: TEffectRec ids, indices into GDConsts.effectNames and FxEngine's handler table. Each comment is the
  effect's name as the character screen shows it. }
unit C_Effect;

interface

const
  { Blessed }
  BLESS = 1;
  { Cursed }
  CURSE = 2;
  { Harrassed by Snakes }
  SNAKE_HARASS = 3;
  { Dispelling Evil }
  DISPEL_EVIL = 4;
  { Detecting Magic }
  DETECT_MAGIC = 5;
  { Immune to Electricity }
  IMMUNE_ELECTRICITY = 6;
  { Gnome thac0 bonus }
  GNOME_THAC0_BONUS = 7;
  { Protected from Evil }
  PROTECTION_FROM_EVIL = 8;
  { Protected from Good }
  PROTECTION_FROM_GOOD = 9;
  { Resistant to Cold }
  RESIST_COLD = 10;
  { Charmed }
  CHARM = 11;
  { Enlarged }
  ENLARGE = 12;
  { Barkskin }
  BARKSKIN = 13;
  { Friendly }
  FRIENDS = 14;
  { Slow Poison }
  SLOW_POISON_HIT = 15;
  { Reading Magic }
  READ_MAGIC = 16;
  { Shielded }
  SHIELD = 17;
  { 30% resistant to charm }
  RESIST_CHARM_30 = 18;
  { Able to Find Traps }
  FIND_TRAPS = 19;
  { Fire Resistant (spell) }
  RESIST_FIRE = 20;
  { Silenced }
  SILENCE = 21;
  { Slow poison wears off }
  SLOW_POISON_END = 22;
  { Carries Spiritual Hammer }
  SPIRITUAL_HAMMER = 23;
  { Sees Invisible }
  SEE_INVISIBLE = 24;
  { Invisible (spell) }
  INVISIBLE = 25;
  { Dwarf thac0 bonus }
  DWARF_THAC0_BONUS = 26;
  { Confused. Lose Turn }
  CONFUSED_LOSE_TURN = 27;
  { Duplicated }
  MIRROR_IMAGE = 28;
  { Enfeebled }
  ENFEEBLE = 29;
  { Nauseated }
  STINKING_CLOUD_COUGH = 30;
  { Helpless Effect # 31 }
  HELPLESS = 31;
  { Dispel Evil On }
  DISPEL_EVIL_TOUCH = 32;
  { Blind }
  BLIND = 33;
  { Diseased }
  DISEASED = 34;
  { Confused }
  CONFUSED = 35;
  { Accursed }
  BESTOW_CURSE = 36;
  { Blinking }
  BLINKING = 37;
  { Strengthened }
  STRENGTH = 38;
  { Hastened }
  HASTED = 39;
  { Rakshasa Protection }
  RAKSHASA_PROTECTION = 40;
  { Protected from Normal Missiles }
  PROTECTION_FROM_MISSILES = 41;
  { Slowed }
  SLOWED = 42;
  { Disease Strength Lose }
  DISEASE_STRENGTH = 43;
  { Disease Health Lose }
  DISEASE_HIT_POINTS = 44;
  { Protected from Evil, 10' Radius }
  PROTECTION_FROM_EVIL_10_FOOT = 45;
  { Protected from Good, 10' Radius }
  PROTECTION_FROM_GOOD_10_FOOT = 46;
  { Dwarf Giant Bonus }
  DWARF_GIANT_BONUS = 47;
  { Gnome Large Monster Bonus }
  GNOME_LARGE_MONSTER_BONUS = 48;
  { Affected by Prayer }
  PRAYER = 49;
  { Fire Shield, Hot flames }
  FIRE_SHIELD_HOT = 50;
  { Helpless Effect #51 }
  HELPLESS_51 = 51;
  { Held }
  HELD = 52;
  { Asleep }
  ASLEEP = 53;
  { Fire Shield, Cold flames }
  FIRE_SHIELD_COLD = 54;
  { POISONED }
  POISONED = 55;
  { Invisible (ring) }
  INVISIBLE_RING = 56;
  { Enveloped in Globe of Invulnerability }
  GLOBE_OF_INVULNERABILITY = 57;
  { Petrification Gaze Attack }
  PETRIFY_GAZE = 58;
  { +3 weapons or better to hit }
  HIT_BY_PLUS_3_ONLY = 60;
  { Fire Resistant (ring) }
  RESIST_FIRE_RING = 61;
  { Regeneration }
  REGENERATION = 62;
  { Within Minor Globe of Invulnerability }
  MINOR_GLOBE = 63;
  { Deadly Poison Attack }
  DEADLY_POISON_ATTACK = 64;
  { Petrification Touch Attack }
  PETRIFY_TOUCH = 65;
  { half damage from pierce/cut weapons }
  HALF_DAMAGE_PIERCE_CUT = 66;
  { half damage from crushing weapons }
  HALF_DAMAGE_CRUSH = 67;
  { Mentally Enfeebled }
  FEEBLEMIND = 68;
  { Invisible to Animals }
  INVISIBLE_TO_ANIMALS = 69;
  { confusion gaze }
  CONFUSION_GAZE = 70;
  { Magically Highlighted }
  HIGHLIGHTED = 71;
  { Immune to Dragon Breath }
  IMMUNE_DRAGON_BREATH = 73;
  { Wearing Magical Boots }
  MAGIC_BOOTS = 74;
  { giant slaying sword }
  GIANT_SLAYING_SWORD = 75;
  { Immune to Disease }
  IMMUNE_DISEASE = 76;
  { Confused }
  CONFUSED_BERSERK = 77;
  { iron golem spell immunity }
  IRON_GOLEM_IMMUNITY = 79;
  { luck stone }
  LUCK_STONE = 80;
  { half damage fro weapons < +3 }
  HALF_DAMAGE_WEAPONS_UNDER_PLUS_3 = 81;
  { killed by blessed crossbow bolts }
  BLESSED_BOLT_KILLS = 82;
  { big red dragon breath }
  BIG_RED_DRAGON_BREATH = 83;
  { red dragon breath }
  RED_DRAGON_BREATH = 84;
  { white dragon breath }
  WHITE_DRAGON_BREATH = 85;
  { deadly poison -2 }
  DEADLY_POISON_MINUS_2 = 86;
  { paralzing poison }
  PARALYZING_POISON = 88;
  { Wearing Magical Cloak }
  MAGIC_CLOAK = 89;
  { green dragon breath }
  GREEN_DRAGON_BREATH = 90;
  { blue dragon breath }
  BLUE_DRAGON_BREATH = 91;
  { immune to fear }
  IMMUNE_FEAR = 92;
  { immune to fire }
  IMMUNE_FIRE = 93;
  { dwarven save bonus }
  CON_POISON_SAVE_BONUS = 94;
  { 90% resistant to sleep/charm }
  RESIST_SLEEP_CHARM_90 = 95;
  { black dragon breath }
  BLACK_DRAGON_BREATH = 96;
  { dwarven save bonus }
  CON_SPELL_SAVE_BONUS = 97;
  { immune to cold }
  IMMUNE_COLD = 98;
  { bullet rake attack }
  BULLET_RAKE = 99;
  { dragon fear attack }
  DRAGON_FEAR_ATTACK = 100;
  { drain 1 level }
  DRAIN_ONE_LEVEL = 101;
  { drain 2 levels }
  DRAIN_TWO_LEVELS = 102;
  { immune to nonmagical weapons }
  IMMUNE_NONMAGIC = 103;
  { +4d6 fire damage }
  FIRE_DAMAGE_4D6 = 104;
  { bonus damage from rangers }
  RANGER_BONUS_DAMAGE = 105;
  { Stunned }
  STUNNED = 106;
  { Berserk }
  BERSERK = 107;
  { +2d6 fire damage }
  FIRE_DAMAGE_2D6 = 108;
  { paladin can heal }
  RECENT_HEAL = 109;
  { paladin cant't remove curse }
  RECENT_CURE = 110;
  { FRIGHTENED }
  FRIGHTENED = 111;
  { fire shield }
  FIRE_SHIELD = 112;
  { Giant Strength }
  GIANT_STRENGTH = 113;
  { vorpal weapon }
  VORPAL = 115;
  { multiple attacks by new weapons }
  MULTI_ATTACK_NEW_WEAPONS = 116;
  { Effect #117 }
  BEHOLDER_EYE_RAYS = 117;
  { Dancing }
  DANCING = 118;
  { Resist Fire (Druid) }
  RESIST_FIRE_DRUID = 119;
  { affected by dragon fear }
  DRAGON_FEARED = 120;
  { Fire Touch }
  FIRE_TOUCH = 121;
  { Iron Skin }
  IRON_SKIN = 122;
  { Shielded by Mind Blank }
  MIND_BLANK = 123;
  { immune to weapons < +2 }
  IMMUNE_WEAPONS_UNDER_PLUS_2 = 125;
  { immune to gaze attacks }
  IMMUNE_GAZE = 126;
  { effect 127 }
  ITEM_EFFECT = 127;

implementation

end.
