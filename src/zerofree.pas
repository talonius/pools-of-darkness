{ Clears a heap block before giving it back, so no stale game data survives in freed memory. }
{$F+,O-,S-,R-,V-,B-,I-}
unit ZeroFree;

interface

uses GameIo, Types;

{ Zero-fills a heap block through GameIo.ZeroFill, then releases it with FreeMem.
  @param(p The block to free.)
  @param(n Its size in bytes.) }
procedure PrefixFree(p: Pointer; n: Word);

implementation

procedure PrefixFree(p: Pointer; n: Word);
begin
  GameIo.ZeroFill(Types.PBytes(p)^, n);
  FreeMem(p, n);
end;

begin
end.
