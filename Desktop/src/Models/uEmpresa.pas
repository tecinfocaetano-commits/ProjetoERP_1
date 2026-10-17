unit uEmpresa;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model Empresa
  Descrição: Entidade de empresas (multi-tenant)
  Padrão: Entity
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TEmpresa - Empresa do sistema }
  TEmpresa = class(TModelBase)
  private
    FRazaoSocial: string;
    FNomeFantasia: string;
    FCNPJ: string;
    FIE: string;
    FEndereco: string;
    FNumero: string;
    FComplemento: string;
    FBairro: string;
    FCidade: string;
    FUF: string;
    FCEP: string;
    FTelefone: string;
    FEmail: string;
    FAtivo: string;
  public
    constructor Create; override;

    property RazaoSocial: string read FRazaoSocial write FRazaoSocial;
    property NomeFantasia: string read FNomeFantasia write FNomeFantasia;
    property CNPJ: string read FCNPJ write FCNPJ;
    property IE: string read FIE write FIE;
    property Endereco: string read FEndereco write FEndereco;
    property Numero: string read FNumero write FNumero;
    property Complemento: string read FComplemento write FComplemento;
    property Bairro: string read FBairro write FBairro;
    property Cidade: string read FCidade write FCidade;
    property UF: string read FUF write FUF;
    property CEP: string read FCEP write FCEP;
    property Telefone: string read FTelefone write FTelefone;
    property Email: string read FEmail write FEmail;
    property Ativo: string read FAtivo write FAtivo;
  end;

implementation

{ TEmpresa }

constructor TEmpresa.Create;
begin
  inherited Create;
  FRazaoSocial := '';
  FNomeFantasia := '';
  FCNPJ := '';
  FIE := '';
  FEndereco := '';
  FNumero := '';
  FComplemento := '';
  FBairro := '';
  FCidade := '';
  FUF := '';
  FCEP := '';
  FTelefone := '';
  FEmail := '';
  FAtivo := 'A';
end;

end.
