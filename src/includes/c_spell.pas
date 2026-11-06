{ Spell values: the spell lists, and the pending flag and id mask of a spell byte. }
unit C_Spell;

interface

const
  { The spell list a spell belongs to (TSpellRec.castClass), also the first index of a character's spell slots: cleric,
    druid, magic-user, and spells cast from magic items. }
  CLERIC_LIST = 0;
  DRUID_LIST = 1;
  MAGIC_USER_LIST = 2;
  ITEM_LIST = 3;
  { Spell bytes hold the spell ID in bits 0..6; bit 7 marks a spell still being memorized or scribed. }
  PENDING_FLAG = $80;
  ID_MASK = $7F;

implementation

end.
