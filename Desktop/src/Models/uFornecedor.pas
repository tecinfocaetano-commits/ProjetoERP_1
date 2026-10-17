unit uFornecedor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uModelBase;

type
  TFornecedor = class(TModelBase)
  private
    FTipoPessoa: Char;
    FRazaoSocial: string;
    FNomeFantasia: string;
    FCpfCnpj: string;
    FIe: string;
    FEndereco: string;
    FNumero: string;
    FComplemento: string;
    FBairro: string;
    FCidade: string;
    FUf: string;
    FCep: string;
    FTelefone: string;
    FCelular: string;
    FEmail: string;
    FContato: string;
    FObservacoes: string;
    FAtivo: Char;
  public
    constructor Create; override;
    property TipoPessoa: Char read FTipoPessoa write FTipoPessoa;
    property RazaoSocial: string read FRazaoSocial write FRazaoSocial;
    property NomeFantasia: string read FNomeFantasia write FNomeFantasia;
    property CpfCnpj: string read FCpfCnpj write FCpfCnpj;
    property Ie: string read FIe write FIe;
    property Endereco: string read FEndereco write FEndereco;
    property Numero: string read FNumero write FNumero;
    property Complemento: string read FComplemento write FComplemento;
    property Bairro: string read FBairro write FBairro;
    property Cidade: string read FCidade write FCidade;
    property Uf: string read FUf write FUf;
    property Cep: string read FCep write FCep;
    property Telefone: string read FTelefone write FTelefone;
    property Celular: string read FCelular write FCelular;
    property Email: string read FEmail write FEmail;
    property Contato: string read FContato write FContato;
    property Observacoes: string read FObservacoes write FObservacoes;
    property Ativo: Char read FAtivo write FAtivo;
  end;

implementation

constructor TFornecedor.Create;
begin
  inherited Create;
  FTipoPessoa := 'J';
  FAtivo := 'A';
end;

end.
