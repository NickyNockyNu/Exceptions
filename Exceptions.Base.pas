{
  Exceptions.Base.pas
    Exceptions without SysUtils
    Copyright (c) 2026 Nicholas Smith (writetonik@gmail.com)
    https://github.com/NickyNockyNu/Exceptions

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

unit Exceptions.Base;

interface

type
  TExceptionProc = function(const AErrorMessage: String; AExceptionObject: TObject; AExceptionAddress: Pointer): Integer;

  TExceptionClass = class of Exception;

  {$REGION 'Exception'}
  Exception = class
  private
    FDetails:   String;
    FErrorCode: Integer;
    FAddress:   Pointer;

    class constructor Create;

    class function GetExceptionClass (AExceptionRecord: PExceptionRecord): TExceptionClass; static;
    class function GetExceptionObject(AExceptionRecord: PExceptionRecord): Exception;       static;

    class function  GetHandler:          TExceptionProc;  static;
    class procedure SetHandler(AHandler: TExceptionProc); static;
  public
    constructor Create(const ADetails: String; AErrorCode: Integer = -1; AAddress: Pointer = nil);

    class procedure HandleException(AExceptionObject: TObject; AExceptionAddress: Pointer = nil); static;

    function ToString: String; override;

    property Details:   String  read FDetails;
    property ErrorCode: Integer read FErrorCode;
    property Address:   Pointer read FAddress;

    class property Handler: TExceptionProc read GetHandler write SetHandler;
  end;
  {$ENDREGION}

  {$REGION 'Errors'}
  EUnknown         = class(Exception);
  EIOError         = class(Exception);
  EDivideByZero    = class(Exception);
  EOutOfBounds     = class(Exception);
  EOverflow        = class(Exception);
  EInvalidOp       = class(Exception);
  EPrivilegedOp    = class(Exception);
  EStackOverflow   = class(Exception);
  EOutOfMemory     = class(Exception);
  EAccessViolation = class(Exception);

  ERuntimeError = class(Exception)
  private
    class constructor Create;
    class procedure HandleRuntimeError(AErrorCode: Byte; AErrorAddress: Pointer); static;
  end;

  ESafecallError = class(Exception)
  private
    class constructor Create;
    class procedure HandleSafecallError(AErrorCode: HResult; AErrorAddress: Pointer); static;
  end;

  EAbstractError = class(Exception)
  private
    class constructor Create;
    class procedure HandleAbstractError; static;
  end;
  {$ENDREGION}

implementation

uses
  Winapi.Windows;

{$REGION 'String Helpers'}
function IntToStr(AValue: Integer): String;
var
  s: ShortString;
begin
  Str(AValue, s);
  Result := String(s);
end;

function PtrToStr(AValue: Pointer): String;
const
  HexChars = '0123456789ABCDEF';
var
  Size: Integer;
  Addr: UIntPtr;
begin
  Addr := UIntPtr(AValue);
  Size := SizeOf(Addr) shl 1;

  SetLength(Result, Size);

  for var i := 1 to Size do
  begin
    Result[Size - i + 1] := HexChars[(Addr and $F) + 1];
    Addr := Addr shr 4;
  end;
end;

function ExeFile: String;
begin
  Result := ParamStr(0);

  for var i := Length(Result) downto 1 do
    if (Result[i] = '\') or (Result[i] = '/') then
    begin
      Result := Copy(Result, i + 1, Length(Result));
      Break;
    end;
end;
{$ENDREGION}

{$REGION 'Exception'}
var
  _Handler: TExceptionProc = nil;

class constructor Exception.Create;
begin
  ExceptionClass := Exception;

  ExceptClsProc := @GetExceptionClass;
  ExceptObjProc := @GetExceptionObject;

  ExceptProc := @HandleException;
end;

class function Exception.GetExceptionClass;
begin
  case AExceptionRecord^.ExceptionCode of
    EXCEPTION_FLT_DIVIDE_BY_ZERO,
    EXCEPTION_INT_DIVIDE_BY_ZERO:    Result := EDivideByZero;
    EXCEPTION_ARRAY_BOUNDS_EXCEEDED: Result := EOutOfBounds;
    EXCEPTION_FLT_OVERFLOW,
    EXCEPTION_FLT_UNDERFLOW,
    EXCEPTION_INT_OVERFLOW:          Result := EOverflow;
    EXCEPTION_FLT_INEXACT_RESULT,
    EXCEPTION_FLT_INVALID_OPERATION,
    EXCEPTION_FLT_DENORMAL_OPERAND,
    EXCEPTION_FLT_STACK_CHECK:       Result := EInvalidOp;
    EXCEPTION_PRIV_INSTRUCTION:      Result := EPrivilegedOp;
    EXCEPTION_ACCESS_VIOLATION:      Result := EAccessViolation;
    EXCEPTION_STACK_OVERFLOW:        Result := EStackOverflow;
    STATUS_NO_MEMORY:                Result := EOutOfMemory;
  else
    Result := EUnknown;
  end;
end;

class function Exception.GetExceptionObject;
const
  EXCEPTION_ACCESS_VIOLATION = DWORD($C0000005);
var
  Details: String;
begin
  if AExceptionRecord^.ExceptionCode = EXCEPTION_ACCESS_VIOLATION then
  begin
    case AExceptionRecord^.ExceptionInformation[0] of
      0: Details := 'Read from address '  + PtrToStr(Pointer(AExceptionRecord^.ExceptionInformation[1]));
      1: Details := 'Write to address '   + PtrToStr(Pointer(AExceptionRecord^.ExceptionInformation[1]));
      8: Details := 'Execute at address ' + PtrToStr(Pointer(AExceptionRecord^.ExceptionInformation[1]));
    else
      Details := 'Access address ' + PtrToStr(Pointer(AExceptionRecord^.ExceptionInformation[1]));
    end;
  end
  else
    Details := '';

  Result := GetExceptionClass(AExceptionRecord).Create(Details, 0, AExceptionRecord^.ExceptionAddress);
end;

class function Exception.GetHandler: TExceptionProc;
begin
  Result := _Handler;
end;

class procedure Exception.SetHandler(AHandler: TExceptionProc);
begin
  _Handler := AHandler;
end;

constructor Exception.Create;
begin
  inherited Create;

  if AAddress = nil then
    AAddress := ReturnAddress;

  FDetails   := ADetails;
  FErrorCode := AErrorCode;
  FAddress   := AAddress;
end;

class procedure Exception.HandleException;
var
  Details:   String;
  ErrorCode: Integer;
begin
  if AExceptionObject is Exception then
  begin
    ErrorCode := Exception(AExceptionObject).ErrorCode;

    if AExceptionAddress = nil then
      AExceptionAddress := Exception(AExceptionObject).FAddress;
  end
  else
    ErrorCode := 0;

  Details := ExeFile + ' Raised an exception: ' + AExceptionObject.ClassName;

  if ErrorCode <> 0 then
    Details := Details + ' (code ' + IntToStr(ErrorCode) + ')';

  Details := Details + ' at ' + PtrToStr(AExceptionAddress) + #13#10 + AExceptionObject.ToString;

  if Assigned(_Handler) then
  begin
    ErrorCode := _Handler(Details, AExceptionObject, AExceptionAddress);

    if ErrorCode = 0 then
      Exit;
  end;

  if IsConsole then
  begin
    AllocConsole;
    Writeln(ErrOutput, Details);
    Readln;
  end
  else
    MessageBox(0, PChar(Details), PChar('Error'), MB_OK or MB_ICONERROR or MB_SYSTEMMODAL);

  Halt(ErrorCode);
end;

function Exception.ToString;
begin
  Result := FDetails;
end;
{$ENDREGION}

{$REGION 'Errors'}
class constructor ERuntimeError.Create;
begin
  ErrorProc := HandleRuntimeError;
end;

class procedure ERuntimeError.HandleRuntimeError;
var
  ExitCode:   Integer;
  Details:    String;
  EClass:     TExceptionClass;
begin
  ExitCode := AErrorCode;

  if ExitCode = 0 then
  begin
    ExitCode := IOResult;
    EClass   := EIOError;

    Details := 'IO Error #' + IntToStr(AErrorCode);

    case ExitCode of
      2: Details := Details + #13#10 + 'File not found';
      3: Details := Details + #13#10 + 'Invalid file name';
      4: Details := Details + #13#10 + 'Too many open files';
      5: Details := Details + #13#10 + 'Access denied';

      100: Details := Details + #13#10 + 'Read beyone end of file';
      101: Details := Details + #13#10 + 'Disk full';
      105: Details := Details + #13#10 + 'Invalid handle';
      106: Details := Details + #13#10 + 'Invalid numeric input';
    else
      if ExitCode = 0 then
        ExitCode := -1;
    end;
  end
  else
  begin
    case TRuntimeError(AErrorCode) of
      reOutOfMemory:     EClass := EOutOfMemory;
      reDivByZero,
      reZeroDivide:      EClass := EDivideByZero;
      reRangeError:      EClass := EOutOfBounds;
      reIntOverflow,
      reOverflow,
      reUnderflow:       EClass := EOverflow;
      reInvalidOp:       EClass := EInvalidOp;
      reAccessViolation: EClass := EAccessViolation;
      rePrivInstruction: EClass := EPrivilegedOp;
      reSafeCallError:   EClass := ESafecallError;
    else
      Details := 'Runtime error #' + IntToStr(AErrorCode);

      EClass := ERuntimeError;
    end;
  end;

  raise EClass.Create(Details, ExitCode) at AErrorAddress;
end;

class constructor ESafecallError.Create;
begin
  SafecallErrorProc := HandleSafecallError;
end;

class procedure ESafecallError.HandleSafecallError;
begin
  raise ESafecallError.Create('Safecall error #'  + IntToStr(AErrorCode), AErrorCode) at AErrorAddress;
end;

class constructor EAbstractError.Create;
begin
  AbstractErrorProc := HandleAbstractError;
end;

class procedure EAbstractError.HandleAbstractError;
begin
  raise EAbstractError.Create('Abstract error');
end;
{$ENDREGION}

initialization
  Exception     .ClassName;
  ERuntimeError .ClassName;
  ESafecallError.ClassName;
  EAbstractError.ClassName;
end.
