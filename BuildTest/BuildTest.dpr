program BuildTest;

{.$APPTYPE CONSOLE}
{.$R *.res}
{$ASSERTIONS ON}

uses
  Exceptions.Base in '..\Exceptions.Base.pas',
  Exceptions.Assertions in '..\Exceptions.Assertions.pas',
  Exceptions.OS in '..\Exceptions.OS.pas';

var
  p: PInteger;
begin
  p := PInteger($11223344);

  // Write access violation:
  //p^ := 10;

  // Read access violation:
  Writeln(p^);
end.
