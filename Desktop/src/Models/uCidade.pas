unit uCidade;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Model: Cidade
  Geográfico global (sem EMPRESA_ID) - ver migration 015.
  Colunas reais: ESTADO_ID, NOME, CODIGO_IBGE, CEP_PADRAO.
  ============================================================ }

interface

type
  TCidade = class
  private
    FId: Int64;
    FEstadoId: Int64;
    FNome: string;
    FCodigoIbge: string;
  public
    property Id: Int64 read FId write FId;
    property EstadoId: Int64 read FEstadoId write FEstadoId;
    property Nome: string read FNome write FNome;
    property CodigoIbge: string read FCodigoIbge write FCodigoIbge;
  end;

implementation

end.
