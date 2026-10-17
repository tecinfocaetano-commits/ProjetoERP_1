unit uAssert;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Framework Simples de Asserts para Testes
  Descrição: Funções de assert para testes unitários
  ============================================================ }

interface

uses
  Classes, SysUtils;

type
  TAssertException = class(Exception);

  { TTestResult }
  TTestResult = record
    TestName: string;
    Passed: Boolean;
    Message: string;
  end;

  { TTestSuite }
  TTestSuite = class
  private
    FResults: array of TTestResult;
    FPassedCount: Integer;
    FFailedCount: Integer;
  public
    constructor Create;
    procedure AddResult(const ATestName: string; APassed: Boolean; const AMessage: string = '');
    procedure PrintResults;
    property PassedCount: Integer read FPassedCount;
    property FailedCount: Integer read FFailedCount;
  end;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string = '');
procedure AssertFalse(const ACondition: Boolean; const AMessage: string = '');
procedure AssertEquals(const AExpected, AActual: string; const AMessage: string = '');
procedure AssertNotNull(const AValue: Pointer; const AMessage: string = '');
procedure AssertNil(const AValue: Pointer; const AMessage: string = '');
procedure AssertFail(const AMessage: string = '');

implementation

{ TTestSuite }

constructor TTestSuite.Create;
begin
  FPassedCount := 0;
  FFailedCount := 0;
  SetLength(FResults, 0);
end;

procedure TTestSuite.AddResult(const ATestName: string; APassed: Boolean; const AMessage: string = '');
begin
  SetLength(FResults, Length(FResults) + 1);
  FResults[High(FResults)].TestName := ATestName;
  FResults[High(FResults)].Passed := APassed;
  FResults[High(FResults)].Message := AMessage;

  if APassed then
    Inc(FPassedCount)
  else
    Inc(FFailedCount);
end;

procedure TTestSuite.PrintResults;
var
  I: Integer;
begin
  WriteLn('========================================');
  WriteLn('RESULTADOS DOS TESTES');
  WriteLn('========================================');
  for I := 0 to High(FResults) do
  begin
    if FResults[I].Passed then
      WriteLn('[PASS] ', FResults[I].TestName)
    else
      WriteLn('[FAIL] ', FResults[I].TestName, ' - ', FResults[I].Message);
  end;
  WriteLn('========================================');
  WriteLn('Total: ', Length(FResults), ' | Passou: ', FPassedCount, ' | Falhou: ', FFailedCount);
  WriteLn('========================================');
end;

{ Assert Functions }

procedure AssertTrue(const ACondition: Boolean; const AMessage: string = '');
begin
  if not ACondition then
  begin
    if AMessage <> '' then
      raise TAssertException.Create('Expected True, but was False. ' + AMessage)
    else
      raise TAssertException.Create('Expected True, but was False.');
  end;
end;

procedure AssertFalse(const ACondition: Boolean; const AMessage: string = '');
begin
  if ACondition then
  begin
    if AMessage <> '' then
      raise TAssertException.Create('Expected False, but was True. ' + AMessage)
    else
      raise TAssertException.Create('Expected False, but was True.');
  end;
end;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string = '');
begin
  if AExpected <> AActual then
  begin
    if AMessage <> '' then
      raise TAssertException.Create('Expected "' + AExpected + '", but was "' + AActual + '". ' + AMessage)
    else
      raise TAssertException.Create('Expected "' + AExpected + '", but was "' + AActual + '".');
  end;
end;

procedure AssertNotNull(const AValue: Pointer; const AMessage: string = '');
begin
  if AValue = nil then
  begin
    if AMessage <> '' then
      raise TAssertException.Create('Expected not nil, but was nil. ' + AMessage)
    else
      raise TAssertException.Create('Expected not nil, but was nil.');
  end;
end;

procedure AssertNil(const AValue: Pointer; const AMessage: string = '');
begin
  if AValue <> nil then
  begin
    if AMessage <> '' then
      raise TAssertException.Create('Expected nil, but was not nil. ' + AMessage)
    else
      raise TAssertException.Create('Expected nil, but was not nil.');
  end;
end;

procedure AssertFail(const AMessage: string = '');
begin
  if AMessage <> '' then
    raise TAssertException.Create(AMessage)
  else
    raise TAssertException.Create('Test failed intentionally.');
end;

end.
