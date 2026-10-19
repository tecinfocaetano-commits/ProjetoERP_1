unit uClienteService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service: Cliente
  Descrição: Regras de negócio para Clientes
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uCliente, uSessao;

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
begin
  { CPF/CNPJ vem do usuário: entra como parâmetro, nunca no texto da
    SQL. A condição "ID <> :EXC" evita o falso positivo contra o
    próprio registro durante a edição. }
  if AExcluirId > 0 then
    Result := FClienteRepo.ContarParam(
      'CPF_CNPJ = :CPFCNPJ AND ID <> :EXC',
      ['CPFCNPJ', 'EXC'],
      [ACpfCnpj, IntToStr(AExcluirId)]) > 0
  else
    Result := FClienteRepo.ContarParam(
      'CPF_CNPJ = :CPFCNPJ',
      ['CPFCNPJ'],
      [ACpfCnpj]) > 0;
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
begin
  { lista os clientes da empresa logada. (O código anterior filtrava
    por Connection.Tag, que nunca é preenchido — ficava EMPRESA_ID = 0
    e a lista saía vazia; AFiltro era só um sinalizador ligado/desligado.) }
  Result := FClienteRepo.BuscarTodosParam(
    'EMPRESA_ID = :EMP',
    ['EMP'],
    [IntToStr(TSessao.GetInstance.EmpresaId)],
    'NOME');
end;

function TClienteService.Inserir(ACliente: TCliente): Int64;
const
  CAMPOS = 'EMPRESA_ID, NOME, NOME_FANTASIA, CPF_CNPJ, RG_IE, ' +
           'ENDERECO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, UF, CEP, ' +
           'TELEFONE, EMAIL, ATIVO';
  VALORES_PARAM = ':EMP, :NOME, :FANTASIA, :CPFCNPJ, :RGIE, ' +
                  ':END, :NUM, :COMPL, :BAIRRO, :CID, :UF, :CEP, ' +
                  ':TEL, :EMAIL, :ATIVO';
begin
  Validar(ACliente);

  Result := FClienteRepo.InserirParam(
    CAMPOS, VALORES_PARAM,
    ['EMP', 'NOME', 'FANTASIA', 'CPFCNPJ', 'RGIE',
     'END', 'NUM', 'COMPL', 'BAIRRO', 'CID', 'UF', 'CEP',
     'TEL', 'EMAIL', 'ATIVO'],
    [IntToStr(ACliente.EmpresaId), ACliente.Nome,
     ACliente.NomeFantasia, ACliente.CpfCnpj, ACliente.RgIe,
     ACliente.Endereco, ACliente.Numero, ACliente.Complemento,
     ACliente.Bairro, ACliente.Cidade, ACliente.Uf, ACliente.Cep,
     ACliente.Telefone, ACliente.Email, ACliente.Ativo]);

  LogOperacao('CLIENTE', 'I', Result);
end;

function TClienteService.Atualizar(ACliente: TCliente): Boolean;
const
  CAMPOS_PARAM = 'NOME = :NOME, NOME_FANTASIA = :FANTASIA, ' +
                 'CPF_CNPJ = :CPFCNPJ, RG_IE = :RGIE, ENDERECO = :END, ' +
                 'NUMERO = :NUM, COMPLEMENTO = :COMPL, BAIRRO = :BAIRRO, ' +
                 'CIDADE = :CID, UF = :UF, CEP = :CEP, ' +
                 'TELEFONE = :TEL, EMAIL = :EMAIL, ATIVO = :ATIVO';
begin
  ValidarId(ACliente.Id, 'Cliente');
  Validar(ACliente);

  Result := FClienteRepo.AtualizarParam(
    ACliente.Id, CAMPOS_PARAM,
    ['NOME', 'FANTASIA', 'CPFCNPJ', 'RGIE', 'END',
     'NUM', 'COMPL', 'BAIRRO', 'CID', 'UF', 'CEP',
     'TEL', 'EMAIL', 'ATIVO'],
    [ACliente.Nome, ACliente.NomeFantasia,
     ACliente.CpfCnpj, ACliente.RgIe, ACliente.Endereco,
     ACliente.Numero, ACliente.Complemento, ACliente.Bairro,
     ACliente.Cidade, ACliente.Uf, ACliente.Cep,
     ACliente.Telefone, ACliente.Email, ACliente.Ativo]);

  LogOperacao('CLIENTE', 'U', ACliente.Id);
end;

function TClienteService.Excluir(AId: Int64): Boolean;
begin
  ValidarId(AId, 'Cliente');
  Result := FClienteRepo.Excluir(AId);
  LogOperacao('CLIENTE', 'D', AId);
end;

function TClienteService.Pesquisar(const ATermo: string): TSQLQuery;
begin
  { termo do usuário entra como parâmetro em TODAS as posições — antes
    era concatenado três vezes em CONTAINING '%s' (quebra com apóstrofo
    e vetor de injeção). UPPER(:T) funciona: o parâmetro string é
    convertido pelo SQLDB conforme a coluna. }
  Result := FClienteRepo.BuscarTodosParam(
    '(UPPER(NOME) CONTAINING UPPER(:T) OR ' +
    'CPF_CNPJ CONTAINING :T OR ' +
    'UPPER(CIDADE) CONTAINING UPPER(:T))',
    ['T'], [ATermo],
    'NOME');
end;

end.
