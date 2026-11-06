{ Item values: TBaseItem's weapon-property bits and the special-power byte of an item. }
unit C_Item;

interface

const
  { TBaseItem.props weapon-property bit flags }
  { relates to arrow ammunition (a bow shoots it, or the item is arrows) }
  USES_ARROWS = $01;
  { the Strength adjustments apply }
  STRENGTH_BONUS = $04;
  { a launcher: fires separate ammunition (bow or crossbow) }
  FIRES_AMMO = $08;
  { a thrown weapon: it is its own ammunition }
  THROWN = $10;
  { relates to quarrel ammunition (a crossbow shoots it, or the item is quarrels) }
  USES_QUARRELS = $80;
  { a Strength-adjusted weapon that can also be thrown; tested as a pair }
  THROWABLE = C_Item.THROWN or C_Item.STRENGTH_BONUS;
  { TItemDef.special: a value above SPECIAL_POWER_BASE marks an item with a special power, its code in the low seven
    bits }
  SPECIAL_POWER_BASE = $80;
  SPECIAL_POWER_MASK = $7F;

implementation

end.
