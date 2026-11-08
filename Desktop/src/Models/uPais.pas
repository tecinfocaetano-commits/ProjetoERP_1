unit uPais;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Model: País
  Geográfico global (sem EMPRESA_ID) - ver migration 015.
  Colunas reais: NOME, CODIGO (ISO 3166 ex. BRA), DDI (ex. 55).
  ============================================================ }

interface

type
  TPais = class
  private
    FId: Int64;
    FNome: string;
    FCodigo: string;
    FDdi: string;
    FAtivo: Char;
  public
    property Id: Int64 read FId write FId;
    property Nome: string read FNome write FNome;
    property Codigo: string read FCodigo write FCodigo;
    property Ddi: string read FDdi write FDdi;
    property Ativo: Char read FAtivo write FAtivo;
  end;

implementation

end.
