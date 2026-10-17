unit uModelBase;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model Base
  Descrição: Classe base para todas as entidades do sistema
  Padrão: Entity Base Class
  ============================================================ }

interface

uses
  Classes, SysUtils;

type
  { TModelBase - Entidade base com campos comuns }
  TModelBase = class
  private
    FId: Int64;
    FEmpresaId: Int64;
    FDataCadastro: TDateTime;
  public
    constructor Create; virtual;

    property Id: Int64 read FId write FId;
    property EmpresaId: Int64 read FEmpresaId write FEmpresaId;
    property DataCadastro: TDateTime read FDataCadastro write FDataCadastro;
  end;

implementation

{ TModelBase }

constructor TModelBase.Create;
begin
  inherited Create;
  FId := 0;
  FEmpresaId := 0;
  FDataCadastro := Now;
end;

end.
