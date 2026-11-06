{ TCharRecord.npc values. }
unit C_Npc;

interface

const
  { TCharRecord.npc packing: bit 7 marks a creature that is not a player character; bits 0..6 hold its morale }
  NON_PLAYER = $80;
  MORALE_MASK = $7F;
  { a party member fighting under computer control (charmed, confused, berserk or frightened); clearing the effect
    resets it to 0 }
  ANIMATED_PLAYER = $B3;

implementation

end.
