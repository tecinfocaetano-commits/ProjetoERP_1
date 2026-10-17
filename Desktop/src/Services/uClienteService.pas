unit uClienteService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service: Cliente
  Descrição: Regras de negócio para Clientes
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uCliente;

type
  { TClienteService }
  TClienteService = class(TServiceBase)
  private
    FClienteRepo: TRepositoryBase;
    function CpfCnpjExiste(const ACpfCnpj: string; AExcluirId: Int64 = 0): Boolean;
    procedure Validar(ACliente: TCliente);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TCliente;
    function BuscarTodos(const AFiltro: string = ''): TSQLQuery;
    function Inserir(ACliente: TCliente): Int64;
    function Atualizar(ACliente: TCliente): Boolean;
    function Excluir(AId: Int64): Boolean;
    function Pesquisar(const ATermo: string): TSQLQuery;
  end;

implementation

{ TClienteService }

constructor TClienteService.Create;
begin
  FClienteRepo := TRepositoryBase.Create('CLIENTE');
  inherited Create(FClienteRepo);
end;

destructor TClienteService.Destroy;
begin
  FClienteRepo.Free;
  inherited Destroy;
end;

procedure TClienteService.Validar(ACliente: TCliente);
begin
  ValidarCampoObrigatorio(ACliente.Nome, 'Nome');
  ValidarCampoObrigatorio(ACliente.CpfCnpj, 'CPF/CNPJ');

  if CpfCnpjExiste(ACliente.CpfCnpj, ACliente.Id) then
    raise Exception.Create('Já existe um cliente com este CPF/CNPJ.');
end;

function TClienteService.CpfCnpjExiste(const ACpfCnpj: string;
  AExcluirId: Int64): Boolean;
var
  LCondicao: string;
begin
  LCondicao := Format('CPF_CNPJ = ''%s''', [ACpfCnpj]);
  if AExcluirId > 0 then
    LCondicao := LCondicao + Format(' AND ID <> %d', [AExcluirId]);
  Result := FClienteRepo.Contar(LCondicao) > 0;
end;

function TClienteService.BuscarPorId(AId: Int64): TCliente;
var
  LQuery: TSQLQuery;
begin
  Result := nil;
  LQuery := FClienteRepo.BuscarPorId(AId);
  try
    if not LQuery.IsEmpty then
    begin
      Result := TCliente.Create;
      Result.Id := LQuery.FieldByName('ID').AsLargeInt;
      Result.EmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
      // TIPO_PESSOA não existe no banco, usar valor padrão
      Result.TipoPessoa := 'F';
      Result.Nome := LQuery.FieldByName('NOME').AsString;
      Result.NomeFantasia := LQuery.FieldByName('NOME_FANTASIA').AsString;
      Result.CpfCnpj := LQuery.FieldByName('CPF_CNPJ').AsString;
      Result.RgIe := LQuery.FieldByName('RG_IE').AsString;
      Result.Endereco := LQuery.FieldByName('ENDERECO').AsString;
      Result.Numero := LQuery.FieldByName('NUMERO').AsString;
      Result.Complemento := LQuery.FieldByName('COMPLEMENTO').AsString;
      Result.Bairro := LQuery.FieldByName('BAIRRO').AsString;
      Result.Cidade := LQuery.FieldByName('CIDADE').AsString;
      Result.Uf := LQuery.FieldByName('UF').AsString;
      Result.Cep := LQuery.FieldByName('CEP').AsString;
      Result.Telefone := LQuery.FieldByName('TELEFONE').AsString;
      // CELULAR não existe no banco
      Result.Celular := '';
      Result.Email := LQuery.FieldByName('EMAIL').AsString;
      // LIMITE_CREDITO não existe no banco
      Result.LimiteCredito := 0;
      Result.Ativo := LQuery.FieldByName('ATIVO').AsString[1];
    end;
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TClienteService.BuscarTodos(const AFiltro: string): TSQLQuery;
var
  LCondicao: string;
begin
  LCondicao := '';
  if AFiltro <> '' then
    LCondicao := Format('EMPRESA_ID = %d', [Conexao.Connection.Tag]);
  Result := FClienteRepo.BuscarTodos(LCondicao, 'NOME');
end;

function TClienteService.Inserir(ACliente: TCliente): Int64;
var
  LCampos, LValores: string;
begin
  Validar(ACliente);

  LCampos := 'EMPRESA_ID, NOME, NOME_FANTASIA, CPF_CNPJ, RG_IE, ' +
             'ENDERECO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, UF, CEP, ' +
             'TELEFONE, EMAIL, ATIVO';

  LValores := Format('%d, ''%s'', ''%s'', ''%s'', ''%s'', ' +
                     '''%s'', ''%s'', ''%s'', ''%s'', ''%s'', ''%s'', ''%s'', ' +
                     '''%s'', ''%s'', ''%s''',
    [ACliente.EmpresaId, ACliente.Nome,
     ACliente.NomeFantasia, ACliente.CpfCnpj, ACliente.RgIe,
     ACliente.Endereco, ACliente.Numero, ACliente.Complemento,
     ACliente.Bairro, ACliente.Cidade, ACliente.Uf, ACliente.Cep,
     ACliente.Telefone, ACliente.Email, ACliente.Ativo]);

  Result := FClienteRepo.Inserir(LCampos, LValores);
  LogOperacao('CLIENTE', 'I', Result);
end;

function TClienteService.Atualizar(ACliente: TCliente): Boolean;
var
  LCamposValores: string;
begin
  ValidarId(ACliente.Id, 'Cliente');
  Validar(ACliente);

  LCamposValores := Format(
    'NOME = ''%s'', NOME_FANTASIA = ''%s'', ' +
    'CPF_CNPJ = ''%s'', RG_IE = ''%s'', ENDERECO = ''%s'', ' +
    'NUMERO = ''%s'', COMPLEMENTO = ''%s'', BAIRRO = ''%s'', ' +
    'CIDADE = ''%s'', UF = ''%s'', CEP = ''%s'', ' +
    'TELEFONE = ''%s'', EMAIL = ''%s'', ATIVO = ''%s''',
    [ACliente.Nome, ACliente.NomeFantasia,
     ACliente.CpfCnpj, ACliente.RgIe, ACliente.Endereco,
     ACliente.Numero, ACliente.Complemento, ACliente.Bairro,
     ACliente.Cidade, ACliente.Uf, ACliente.Cep,
     ACliente.Telefone, ACliente.Email, ACliente.Ativo]);

  Result := FClienteRepo.Atualizar(ACliente.Id, LCamposValores);
  LogOperacao('CLIENTE', 'U', ACliente.Id);
end;

function TClienteService.Excluir(AId: Int64): Boolean;
begin
  ValidarId(AId, 'Cliente');
  Result := FClienteRepo.Excluir(AId);
  LogOperacao('CLIENTE', 'D', AId);
end;

function TClienteService.Pesquisar(const ATermo: string): TSQLQuery;
var
  LCondicao: string;
begin
  LCondicao := Format(
    '(UPPER(NOME) CONTAINING UPPER(''%s'') OR ' +
    'CPF_CNPJ CONTAINING ''%s'' OR ' +
    'UPPER(CIDADE) CONTAINING UPPER(''%s''))',
    [ATermo, ATermo, ATermo]);
  Result := FClienteRepo.BuscarTodos(LCondicao, 'NOME');
end;

end.
