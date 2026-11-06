{ DAX archive and file services: locating data files across the install and floppy paths, reading and decompressing DAX
  archive entries, file-name cleanup, and BIOS text output for the bottom-line disk prompts. }
{$O+,F+}
{$I-}
unit DaxIo;

interface

uses Dos, GameIo, SoundDrv, Types, GDConsts, GDVars, C_Driver;

type
  TString20 = string[20];
  TString2 = string[2];

{ Prepare for disk access: remember the driver state and, if the sound driver is in use, send the reset request and set
  it idle. Note: SoundDrv.SoundCommand accepts only ids 2..12, so the reset request is ignored and only the flag
  changes. }
procedure DiskBegin;

{ Ends disk access: restores the driver state DiskBegin saved, calling SoundDrv.StartSound if the sound driver is in
  use. }
procedure DiskEnd;

{ Writes copies of a character through the video BIOS.
  @param(col The first column.)
  @param(row The row.)
  @param(attr The text attribute.)
  @param(count The number of copies.)
  @param(ch The character code.) }
procedure WriteChar(col, row, attr, count, ch: Byte);

{ Writes a string in text mode through the video BIOS, one character per column.
  @param(col Text column of the first character.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(source The text.) }
procedure WriteString(col, row, attr: Byte; source: string);

{ Writes a run of solid block characters through the BIOS.
  @param(col Column of the first block.)
  @param(row Row of the run.)
  @param(attr Text attribute.)
  @param(count Number of blocks.) }
procedure WriteBlock(col, row, attr, count: Byte);

{ Shows a message on the bottom text row over a cleared bar, waits for a key, then clears the bar.
  @param(attr Attribute of the message.)
  @param(message The message.) }
procedure PromptBox(attr: Byte; message: Types.TStr40);

{ Erases a file if it exists.
  @param(name The file's name.) }
procedure DeleteIfPresent(name: Types.TStr80);

{ Renames a file if it exists.
  @param(oldName The file.)
  @param(newName Its new name.) }
procedure RenameIfExists(oldName, newName: Types.TStr80);

{ Waits until game.ovr can be found, asking for the overlay disk after each miss. }
procedure OverlayPrompt;

{ Reads a drive's volume label. The FindFirst status is not checked: the name buffer is cleared first, so a failed
  search leaves it empty.
  @param(drive The drive letter.)
  @returns(The label, or an empty string when it has none.) }
function GetVolumeLabel(drive: TString2): Types.TStr40;

{ Opens a file for reading in one-byte records. A name with no directory is looked for on the current data path; on a
  miss the two data paths are swapped, so later opens search the drive that held the file first. With prompts enabled, a
  file still missing on a floppy drive asks for the disk (the prompt plus the drive letter) and retries, and one missing
  on a hard drive reports a bad install and aborts.
  @param(fileName The file.)
  @param(promptMsg The disk prompt, before the drive letter.)
  @param(noPrompt Anything but zero returns False at once on a miss instead of prompting.)
  @param(f Receives the opened file.)
  @returns(True when the file was found and opened.) }
function OpenWithRetry(fileName, promptMsg: Types.TStr80; noPrompt: Byte; var f: file): Boolean;

{ Tells whether a normal file matching a name exists.
  @param(name The file name or pattern; an empty name never exists.)
  @returns(True when one exists.) }
function FileExists(name: Types.TStr80): Boolean;

{ Removes the occurrences of one string from another. Note: the scan limit is computed once from the starting lengths
  and the scan moves on after each deletion, so a match shifted into the current position survives, and a substring
  longer than the string wraps the limit round to a large byte value.
  @param(src The string.)
  @param(del The text to remove.)
  @returns(The string without the text.) }
function SanitizeString(src, del: string): string;

{ Makes a file name from a string: removes the characters a DOS file name cannot hold, in SanitizeString's single pass,
  keeps the first eight characters and uppercases them.
  @param(name The string.)
  @returns(The file name.) }
function SanitizeFileName(name: string): Types.TStr80;

{ Decodes a run-length packed entry. A control byte 0..$7E copies the next control+1 bytes; -127..-1 repeats the next
  byte -control times. Note: controls $7F and $80 do nothing, so a stream holding one makes no progress, and
  `decodedSize` is checked only between runs, so bad data can overrun the buffer by one run.
  @param(dst The buffer that receives the decoded bytes.)
  @param(decodedSize The number of bytes to decode.)
  @param(archiveFile The archive, positioned at the entry.) }
procedure DecompressDax(var dst: Types.PBytes; var decodedSize: Word; var archiveFile: file);

{ Opens an archive twice, one handle for its entry directory from the start and one positioned at the first data byte.
  Note: if the second open fails, the first handle is left open.
  @param(archiveName The archive's base name.)
  @param(ext Its extension.)
  @param(dataStart Receives the offset of the first data byte.)
  @param(dataFile Receives the handle positioned at the data.)
  @param(directoryFile Receives the handle that reads the directory.)
  @returns(True when both opens succeeded.) }
function OpenDax(archiveName, ext: TString20; var dataStart: Word; var dataFile, directoryFile: file): Boolean;

{ Closes both handles of a DAX archive.
  @param(dataFile The data handle.)
  @param(directoryFile The directory handle.) }
procedure CloseDax(var dataFile, directoryFile: file);

{ Loads an archive entry into a fresh heap block, inside DiskBegin and DiskEnd. A directory entry is id, a four-byte
  data offset, the decoded size and the compressed size, which is not needed.
  @param(archiveName The archive's base name.)
  @param(ext Its extension.)
  @param(wantedId The entry's id.)
  @param(decodedSize Receives the entry's size; 0 when the archive or the entry is missing.)
  @param(decodedData Receives the block; nil when the archive or the entry is missing.) }
procedure LoadDax(archiveName, ext: Types.TStr80; wantedId: Byte; var decodedSize: Word; var decodedData: Types.PBytes);

implementation

const
  { video BIOS functions, passed in AH }
  VIDEO_SET_CURSOR = 2;
  VIDEO_WRITE_CHAR_ATTR = 9;

procedure DiskBegin;
begin
  GDVars.savedDriverState := GDVars.driverState;
  if GDVars.driverState = C_Driver.SOUND_EFFECTS then begin
    SoundDrv.SoundCommand(GDConsts.soundReset);
    GDVars.driverState := C_Driver.NO_DRIVER;
  end;
end;

procedure DiskEnd;
begin
  GDVars.driverState := GDVars.savedDriverState;
  if GDVars.driverState = C_Driver.SOUND_EFFECTS then
    SoundDrv.StartSound;
end;

procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  GDVars.interruptRegs.ah := DaxIo.VIDEO_SET_CURSOR;
  GDVars.interruptRegs.bh := 0;
  GDVars.interruptRegs.dh := row;
  GDVars.interruptRegs.dl := col;
  Intr($10, Registers(GDVars.interruptRegs));
  GDVars.interruptRegs.ah := DaxIo.VIDEO_WRITE_CHAR_ATTR;
  GDVars.interruptRegs.al := ch;
  GDVars.interruptRegs.bh := 0;
  GDVars.interruptRegs.bl := attr;
  GDVars.interruptRegs.cx := count;
  Intr($10, Registers(GDVars.interruptRegs));
end;

procedure WriteString(col, row, attr: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin
  n := Length(source);
  for i := 1 to n do begin
    DaxIo.WriteChar(col, row, attr, 1, Ord(source[i]));
    Inc(col);
  end;
end;

procedure WriteBlock(col, row, attr, count: Byte);
begin
  DaxIo.WriteChar(col, row, attr, count, 219);
end;

procedure PromptBox(attr: Byte; message: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  DaxIo.WriteBlock(0, 24, 0, 40);
  DaxIo.WriteString(0, 24, attr, message);
  key := GameIo.ReadGameKey;
  DaxIo.WriteBlock(0, 24, 0, 40);
end;

procedure DeleteIfPresent(name: Types.TStr80);
begin
  if DaxIo.FileExists(name) then begin
    Assign(GDVars.scratchFile, name);
    Close(GDVars.scratchFile);
    Erase(GDVars.scratchFile);
  end;
end;

procedure RenameIfExists(oldName, newName: Types.TStr80);
begin
  if DaxIo.FileExists(oldName) then begin
    Assign(GDVars.scratchFile, oldName);
    Close(GDVars.scratchFile);
    Rename(GDVars.scratchFile, newName);
  end;
end;

procedure OverlayPrompt;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
  found: Boolean;
begin
  repeat
    found := DaxIo.FileExists('game.ovr');
    if not found then begin
      WriteLn('Please insert overlay disk.');
      key := GameIo.ReadGameKey;
    end;
  until found;
end;

function GetVolumeLabel(drive: TString2): Types.TStr40;
var sr: SearchRec;
begin
  GameIo.ZeroFill(sr.Name, SizeOf(sr.Name));
  FindFirst(drive + ':\*.*', VolumeID, sr);
  GetVolumeLabel := sr.Name;
end;

function OpenWithRetry(fileName, promptMsg: Types.TStr80; noPrompt: Byte; var f: file): Boolean;
var
  found: Boolean;
  swapTmp: String[79];
  dir: DirStr; name: NameStr; ext: ExtStr;
begin
  FSplit(fileName, dir, name, ext);
  if dir = '' then
    dir := GDVars.currentDataPath;
  repeat
    found := DaxIo.FileExists(dir + name + ext);
    if not found then
      if dir = GDVars.currentDataPath then begin
        swapTmp := GDVars.currentDataPath;
        GDVars.currentDataPath := GDVars.alternateDataPath;
        GDVars.alternateDataPath := swapTmp;
        dir := GDVars.currentDataPath;
        found := DaxIo.FileExists(dir + name + ext);
      end;
    if (not found) and (noPrompt = 0) then
      if dir[1] < 'C' then
        DaxIo.PromptBox(14, promptMsg + GDVars.promptDrive + ': <ENTER>')
      else begin
        DaxIo.PromptBox(14, 'Couldn''t find ' + name + ext + '. Check install.');
        GameIo.ExitGame(0);
      end;
  until found or (noPrompt <> 0);
  if found then begin
    Assign(f, dir + name + ext);
    Reset(f, SizeOf(Byte));
  end;
  OpenWithRetry := found;
end;

function FileExists(name: Types.TStr80): Boolean;
var sr: SearchRec;
begin
  FindFirst(name, 0, sr);
  FileExists := (DosError = 0) and (name <> '');
end;

function SanitizeString(src, del: string): string;
var
  limit: Byte;
  delLen: Byte;
  i: Byte;
begin
  delLen := Length(del);
  limit := Length(src) - delLen + 1;
  for i := 1 to limit do
    if Copy(src, i, delLen) = del then
      Delete(src, i, delLen);
  SanitizeString := src;
end;

function SanitizeFileName(name: string): Types.TStr80;
var i: Byte;
begin
  for i := 1 to 10 do
    name := DaxIo.SanitizeString(name, GDConsts.invalidFileChars[i]);
  name := Copy(name, 1, 8);
  for i := 1 to Length(name) do
    name[i] := UpCase(name[i]);
  SanitizeFileName := name;
end;

procedure DecompressDax(var dst: Types.PBytes; var decodedSize: Word; var archiveFile: file);
var
  { Unused in this version; see the other implementations of this routine. }
  preservedSourceIndex: Word;
  dstIdx: Word;
  control: ShortInt;
  fillByte: Byte;
  { Unused in this version; see the other implementations of this routine. }
  buf: array[1..512] of Byte;
  bytesRead: Word;
begin
  preservedSourceIndex := 0;
  dstIdx := 0;
  repeat
    BlockRead(archiveFile, control, SizeOf(control));
    case control of
      0..126: begin
        BlockRead(archiveFile, dst^[dstIdx], control + 1, bytesRead);
        Inc(dstIdx, control + 1);
      end;
      -127..-1: begin
        control := -control;
        BlockRead(archiveFile, fillByte, SizeOf(fillByte), bytesRead);
        FillChar(dst^[dstIdx], control, fillByte);
        Inc(dstIdx, control);
      end;
    end;
  until dstIdx >= decodedSize;
end;

function OpenDax(archiveName, ext: TString20; var dataStart: Word; var dataFile, directoryFile: file): Boolean;
var bytesRead: Word;
    { Unused in this version; see the other implementations of this routine. }
    ioStatus: array[1..2] of Byte;
begin
  if DaxIo.OpenWithRetry(archiveName + ext, GDConsts.insertDisk2Prompt, GDVars.suppressDiskPrompt, dataFile) then begin
    if not DaxIo.OpenWithRetry(archiveName + ext, GDConsts.insertDisk2Prompt, GDVars.suppressDiskPrompt,
                               directoryFile) then begin
      OpenDax := False;
      Exit;
    end;
    BlockRead(directoryFile, dataStart, SizeOf(dataStart), bytesRead);
    Inc(dataStart, SizeOf(dataStart));
    Seek(dataFile, dataStart);
    OpenDax := True;
  end else
    OpenDax := False;
end;

procedure CloseDax(var dataFile, directoryFile: file);
begin
  Close(dataFile);
  Close(directoryFile);
end;

procedure LoadDax(archiveName, ext: Types.TStr80; wantedId: Byte; var decodedSize: Word; var decodedData: Types.PBytes);
var compressedSize: Word; dataOffset: LongInt; entryId: Byte; bytesRead: Word;
    dataFile: file;
    directoryFile: file; dataStart: Word;
    { Unused in this version; see the other implementations of this routine. }
    numStr: array[1..8] of Byte;
begin
  DaxIo.DiskBegin;
  if not DaxIo.OpenDax(archiveName, ext, dataStart, dataFile, directoryFile) then begin
    decodedSize := 0;
    decodedData := nil;
    DaxIo.DiskEnd;
    Exit;
  end;
  repeat
    BlockRead(directoryFile, entryId, SizeOf(entryId), bytesRead);
    BlockRead(directoryFile, dataOffset, SizeOf(dataOffset), bytesRead);
    BlockRead(directoryFile, decodedSize, SizeOf(decodedSize), bytesRead);
    BlockRead(directoryFile, compressedSize, SizeOf(compressedSize), bytesRead);
  until (entryId = wantedId) or (FilePos(directoryFile) >= dataStart);
  if entryId <> wantedId then begin
    decodedSize := 0;
    decodedData := nil;
    DaxIo.CloseDax(dataFile, directoryFile);
    DaxIo.DiskEnd;
  end else begin
    GetMem(decodedData, decodedSize);
    FillChar(decodedData^, decodedSize, 0);
    Seek(dataFile, dataStart + dataOffset);
    DaxIo.DecompressDax(decodedData, decodedSize, dataFile);
    DaxIo.CloseDax(dataFile, directoryFile);
    DaxIo.DiskEnd;
  end;
end;

begin
end.
