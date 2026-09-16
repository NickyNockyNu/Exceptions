{
  Exceptions.OS.pas
    Exception handling for OS errors
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

unit Exceptions.OS;

interface

uses
  Exceptions.Base;

type
  EOSError = class(Exception)
  public
    constructor Create(const ADetails: String = ''; AErrorCode: Integer = 0);

    class function GetErrorMessage(AErrorCode: Integer): String; overload;
    class function GetErrorMessage:                      String; overload;

    class function Check(AResult: Boolean): Boolean;

    class procedure RaiseLast(const ADetails: String = ''; AClear: Boolean = False; AIgnoreSuccess: Boolean = False);

    class procedure Clear;
  end;

implementation

uses
  Winapi.Windows;

constructor EOSError.Create;
var
  Msg: String;
begin
  if AErrorCode = 0 then
    AErrorCode := GetLastError;

  Msg := GetErrorMessage(AErrorCode);

  if Length(ADetails) > 0 then
    Msg := ADetails + #13#10 + Msg;

  inherited Create(Msg, AErrorCode);
end;

class function EOSError.GetErrorMessage(AErrorCode: Integer): String;
var
  Buffer: PChar;
  Len: Integer;
begin
  Len := FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS, nil, AErrorCode, 0, @Buffer, 0, nil);
  try
    if Len > 0 then
      Result := Buffer
    else
      Result := 'Unknown OS Error';
  finally
    LocalFree(HLOCAL(Buffer));
  end;
end;

class function EOSError.GetErrorMessage: String;
begin
  Result := GetErrorMessage(GetLastError);
end;

class function EOSError.Check;
begin
  Result := AResult;

  if not Result then
    raise EOSError.Create at ReturnAddress;
end;

class procedure EOSError.RaiseLast;
begin
  if (GetLastError = 0) and AIgnoreSuccess then
    Exit;

  try
    raise EOSError.Create(ADetails) at ReturnAddress;
  finally
    if AClear then
      Clear;
  end;
end;

class procedure EOSError.Clear;
begin
  SetLastError(0);
end;

end.
