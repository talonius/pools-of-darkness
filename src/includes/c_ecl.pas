{ ECL script opcodes: the opcode EclVm dispatches on. }
unit C_Ecl;

interface

const
  OP_GOTO = $01;
  GOSUB = $02;
  COMPARE = $03;
  ADD = $04;
  MULTIPLY = $07;
  OP_RANDOM = $08;
  SAVE = $09;
  LOAD_CHARACTER = $0A;
  LOAD_MONSTER = $0B;
  SETUP_MONSTER = $0C;
  PICTURE = $0E;
  INPUT_NUMBER = $0F;
  INPUT_STRING = $10;
  PRINT = $11;
  PRINT_CLEAR = $12;
  COMPARE_AND = $14;
  JOURNAL_ENTRY = $1F;
  NEW_ECL = $20;
  LOAD_FILES = $21;
  ROB = $28;
  GET_TABLE = $2A;
  { a music piece (bit 7 set) or a sound effect }
  PLAY_SOUND = $2C;
  CALL = $2D;
  DAMAGE = $2E;
  OP_AND = $2F;
  OP_OR = $30;
  FIND_ITEM = $32;
  CLOCK = $34;
  SAVE_TABLE = $35;
  ADD_NPC = $36;
  { a party NPC's place, found by name }
  FIND_NPC = $37;
  OP_PROGRAM = $38;
  WHO = $39;
  SPELL = $3B;
  { a store stocked with a category's items }
  STORE = $3C;
  HAS_EFFECT = $3F;
  TAKE_ITEMS = $40;
  AWARD_EXPERIENCE = $41;

implementation

end.
