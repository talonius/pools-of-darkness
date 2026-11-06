{ Effect trigger conditions: the id FxEngine.TriggerEffectsWithCondition dispatches on. }
unit C_Cond;

interface

const
  { the attacker's side of the attack check, run with its target set to the defender; no effect answers it }
  ATTACKER_VETO = 0;
  { the target's effects, which may veto an attack on it }
  TARGET_VETO = 1;
  ATTACKER_WEAPON_DAMAGE = 4;
  DEFENDER_WEAPON_DAMAGE = 5;
  { a creature's turn, before the initiative test }
  TURN_START = 7;
  COMBAT_START = 8;
  { an effect about to be applied; blocking effects clear GDVars.pendingEffectId }
  EFFECT_ADDED = 9;
  { the defender's effects, run before an attack roll against it }
  DEFENDER_ARMOR_CLASS = 11;
  { a creature dropping to 0 hit points or below }
  ZERO_HIT_POINTS = 13;
  { gazes, dragon breath and the beholder's eye rays }
  MONSTER_SPECIAL = 14;
  { a creature's turn, before it acts }
  ACTION_START = 15;
  MORALE_CHECK = 17;
  { haste, slow and the other effects on movement and attacks }
  MOVE_ATTACK_RATE = 18;
  ROUND_END = 19;

implementation

end.
