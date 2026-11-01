unit uCliente;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model: Cliente
  Descrição: Entidade de Cliente
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TCliente }
  TCliente = class(TModelBase)
  private
    FTipoPessoa: Char;
    FNome: string;
    FNomeFantasia: string;
    FCpfCnpj: string;
    FRgIe: string;
    FEndereco: string;
    FNumero: string;
    FComplemento: string;
    FBairro: string;
    FCidade: string;
    FCidadeId: Int64;
    FUf: string;
    FCep: string;
    FTelefone: string;
    FCelular: string;
    FEmail: string;
    FDataNascimento: TDateTime;
    FLimiteCredito: Currency;
    FObservacoes: string;
    FAtivo: Char;
  public
    constructor Create; override;

    property TipoPessoa: Char read FTipoPessoa write FTipoPessoa;
    property Nome: string read FNome write FNome;
    property NomeFantasia: string read FNomeFantasia write FNomeFantasia;
    property CpfCnpj: string read FCpfCnpj write FCpfCnpj;
    property RgIe: string read FRgIe write FRgIe;
    property Endereco: string read FEndereco write FEndereco;
    property Numero: string read FNumero write FNumero;
    property Complemento: string read FComplemento write FComplemento;
    property Bairro: string read FBairro write FBairro;
    property Cidade: string read FCidade write FCidade;
    property CidadeId: Int64 read FCidadeId write FCidadeId;
    property Uf: string read FUf write FUf;
    property Cep: string read FCep write FCep;
    property Telefone: string read FTelefone write FTelefone;
    property Celular: string read FCelular write FCelular;
    property Email: string read FEmail write FEmail;
    property DataNascimento: TDateTime read FDataNascimento write FDataNascimento;
    property LimiteCredito: Currency read FLimiteCredito write FLimiteCredito;
    property Observacoes: string read FObservacoes write FObservacoes;
    property Ativo: Char read FAtivo write FAtivo;
  end;

implementation

{ TCliente }

constructor TCliente.Create;
begin
  inherited Create;
  FTipoPessoa := 'F';
  FAtivo := 'A';
  FLimiteCredito := 0;
end;

end.
