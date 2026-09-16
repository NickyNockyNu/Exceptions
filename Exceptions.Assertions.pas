{
  Exceptions.Assertions.pas
    Assertion support without SysUtils
    Copyright (c) 2026 Nicholas Smith (writetonik@gmail.com)
    https://github.com/NickyNockyNu/

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
}

unit Exceptions.Assertions;

interface

uses
  Exceptions.Base;

type
  EAssertion = class(Exception)
  private
    FFilename:   String;
    FLineNumber: Integer;

    class constructor Create;
  public
    constructor Create(const ADetails, AFilename: String; ALineNumber: Integer);

    class procedure HandleAssertion(ADetails, AFilename: String; ALineNumber: Integer); static;

    function ToString: String; override;

    property Filename:   String  read FFilename;
    property LineNumber: Integer read FLinenumber;
  end;

implementation

class constructor EAssertion.Create;
begin
  AssertErrorProc := @HandleAssertion;
end;

constructor EAssertion.Create;
begin
  FFilename   := AFilename;
  FLineNumber := ALineNumber;

  inherited Create(ADetails, -2);
end;

class procedure EAssertion.HandleAssertion;
begin
  raise EAssertion.Create(ADetails, AFilename, ALineNumber);
end;

function EAssertion.ToString;
var
  SLineNumber: ShortString;
begin
  Result := inherited;

  Str(FLineNumber, SLineNumber);
  Result := FFilename + '(' + String(SLineNumber) + '): '  + Result;
end;

initialization
  EAssertion.ClassName;
end.
