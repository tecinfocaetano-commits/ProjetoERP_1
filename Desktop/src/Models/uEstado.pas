unit uEstado;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Model: Estado
  Geográfico global (sem EMPRESA_ID) - ver migration 015.
  Colunas reais: PAIS_ID, NOME, UF (char 2), CODIGO_IBGE.
  ============================================================ }

interface

type
  TEstado = class
  private
    FId: Int64;
    FPaisId: Int64;
    FNome: string;
    FUf: string;
    FCodigoIbge: string;
  public
    property Id: Int64 read FId write FId;
    property PaisId: Int64 read FPaisId write FPaisId;
    property Nome: string read FNome write FNome;
    property Uf: string read FUf write FUf;
    property CodigoIbge: string read FCodigoIbge write FCodigoIbge;
  end;

implementation

end.
