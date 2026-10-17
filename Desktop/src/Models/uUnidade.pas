unit uUnidade;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model Unidade
  Descrição: Entidade de unidades de medida
  Padrão: Entity
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TUnidade - Unidade de medida }
  TUnidade = class(TModelBase)
  private
    FNome: string;
    FAbreviatura: string;
    FAtivo: string;
  public
    constructor Create; override;

    property Nome: string read FNome write FNome;
    property Abreviatura: string read FAbreviatura write FAbreviatura;
    property Ativo: string read FAtivo write FAtivo;
  end;

implementation

{ TUnidade }

constructor TUnidade.Create;
begin
  inherited Create;
  FNome := '';
  FAbreviatura := '';
  FAtivo := 'A';
end;

end.
