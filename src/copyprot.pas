{ Copy protection: the journal word check. The player is shown a journal page and heading and must type the word at a
  given position after that heading; three tries are allowed. }
{$O+,F+,S-,R-,V-,B-,I-}
unit CopyProt;

interface

{ Asks for a journal word from a random page and word slot, with a fresh question after each wrong answer, at most three
  times. Each stage sets one of the four protection flags, which are cleared on entry; FixMain stops the game unless all
  four are set, so the check cannot simply be skipped.
  @returns(True when the last answer typed was right.) }
function CopyProtection: Boolean;

implementation

uses CharHlp, Border, TextRend, GameIo, Types, GDConsts, GDVars, C_Prot;

{ Decodes a journal string, stored with its characters in reverse order and the string's length added to every byte.
  @param(encodedText The stored string.)
  @returns(The plain text.) }
function DecodeJournalText(encodedText: String): String;
var
  decodedText: String;
  sourceIndex: Byte;
  encodedLength: Byte;
begin
  encodedLength := Length(encodedText);
  decodedText := '';
  for sourceIndex := encodedLength downto 1 do
    decodedText := decodedText + Chr(Ord(encodedText[sourceIndex]) - encodedLength);
  DecodeJournalText := decodedText;
end;

function CopyProtection: Boolean;
begin
  GameIo.ZeroFill(GDVars.protectionFlags, SizeOf(GDVars.protectionFlags));
  Border.DrawWindowFrame(1);
  GDVars.attemptNumber := 0;
  repeat
    Inc(GDVars.attemptNumber);
    GDVars.expectedWord := '';
    GDVars.protectionFlags.challengeSelected := 1;
    GDVars.challengeIndex := Random(SizeOf(GDConsts.journalChallenges) div SizeOf(Types.TJournalChallenge)) + 1;
    with GDConsts.journalChallenges[GDVars.challengeIndex] do begin
      { Pick one of the entry's words at random. Note: an entry with no words at all would loop here forever. }
      repeat
        GDVars.wordSlot := Random(SizeOf(wordNumbers) div SizeOf(wordNumbers[1])) + 1;
      until wordNumbers[GDVars.wordSlot] <> C_Prot.NO_WORD;
      GDVars.expectedWord := CopyProt.DecodeJournalText(encodedWords[GDVars.wordSlot]);

      TextRend.DisplayString(3, 2, 10, 0, ' journal, page ');
      TextRend.DisplayString(17, 2, 13, 0, ' (' + CharHlp.Uint8Str(pageNumber) + ')         ');
      TextRend.DisplayString(3, 4, 10, 0, ' what is word # ');
      TextRend.DisplayString(19, 4, 13, 0, CharHlp.Uint8Str(wordNumbers[GDVars.wordSlot]) + '     ');
      TextRend.DisplayString(3, 6, 10, 0, ' after the heading ');
      Border.ClearBox(4, 8, 38, 8);
      TextRend.DisplayString(4, 8, 13, 0, CopyProt.DecodeJournalText(encodedHeading));
    end;

    GDVars.enteredWord := TextRend.ReadString('Enter ', 14, 0, 20);

    GDVars.protectionFlags.answerEntered := 1;
  until not ((GDVars.attemptNumber <> 3) and (GDVars.enteredWord <> GDVars.expectedWord));
  GDVars.protectionFlags.retriesDone := 1;
  if GDVars.enteredWord = GDVars.expectedWord then
    CopyProtection := True
  else
    CopyProtection := False;
  GDVars.protectionFlags.resultReady := 1;
end;

begin
end.
