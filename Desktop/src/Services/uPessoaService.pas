unit uPessoaService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - D3 (unificação) - Service: Pessoa
  CRUD parametrizado com filtro por TIPO, validações e auditoria.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uPessoa, uSessao;

type
  { TPessoaService }
  TPessoaService = class(TServiceBase)
  private
    FPessoaRepo: TRepositoryBase;
    function CpfCnpjExiste(const ACpfCnpj: string; ATipo: Char;
      AEmpresaId: Int64; AExcluirId: Int64 = 0): Boolean;
    procedure PreencherParametros(LQuery: TSQLQuery; AObj: TPessoa;
      const ATipoPessoa: string);
    procedure Validar(AObj: TPessoa);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TPessoa;
    function BuscarTodos(ATipo: Char = #0; const AFiltro: string = ''): TSQLQuery;
    function Pesquisar(const ATermo: string; ATipo: Char = #0): TSQLQuery;
    function Inserir(AObj: TPessoa): Int64;
    function Atualizar(AObj: TPessoa): Boolean;
    function Excluir(AId: Int64): Boolean;
  end;

implementation

{ TPessoaService }

constructor TPessoaService.Create;
begin
  FPessoaRepo := TRepositoryBase.Create('PESSOA');
  inherited Create(FPessoaRepo);
end;

destructor TPessoaService.Destroy;
begin
  FPessoaRepo.Free;
  inherited Destroy;
end;

procedure TPessoaService.Validar(AObj: TPessoa);
var
  LEmpresaId: Int64;
begin
  ValidarCampoObrigatorio(AObj.Nome, 'Nome');
  ValidarCampoObrigatorio(AObj.CpfCnpj, 'CPF/CNPJ');

  if not (AObj.Tipo in ['C', 'F']) then
    raise Exception.Create('O tipo deve ser C (cliente) ou F (fornecedor).');

  LEmpresaId := AObj.EmpresaId;
  if LEmpresaId <= 0 then
    LEmpresaId := TSessao.GetInstance.EmpresaId;

  if CpfCnpjExiste(AObj.CpfCnpj, AObj.Tipo, LEmpresaId, AObj.Id) then
    raise Exception.Create('Já existe uma pessoa deste tipo com este CPF/CNPJ.');
end;

function TPessoaService.CpfCnpjExiste(const ACpfCnpj: string; ATipo: Char;
  AEmpresaId: Int64; AExcluirId: Int64): Boolean;
var
  LCondicao: string;
  LNome, LVal: array of string;
begin
  LCondicao := 'EMPRESA_ID = :EMP AND CPF_CNPJ = :CPFCNPJ AND TIPO = :TIPO';
  if AExcluirId > 0 then
    LCondicao := LCondicao + ' AND ID <> :EXC';

  SetLength(LNome, 4);
  SetLength(LVal, 4);
  LNome[0] := 'EMP';     LVal[0] := IntToStr(AEmpresaId);
  LNome[1] := 'CPFCNPJ'; LVal[1] := ACpfCnpj;
  LNome[2] := 'TIPO';    LVal[2] := ATipo;
  LNome[3] := 'EXC';     LVal[3] := IntToStr(AExcluirId);

  if AExcluirId > 0 then
    SetLength(LNome, 4)
  else
  begin
    SetLength(LNome, 3);
    SetLength(LVal, 3);
  end;

  Result := FPessoaRepo.ContarParam(LCondicao, LNome, LVal) > 0;
end;

function TPessoaService.BuscarPorId(AId: Int64): TPessoa;
var
  LQuery: TSQLQuery;
begin
  Result := nil;
  LQuery := FPessoaRepo.BuscarPorId(AId);
  try
    if not LQuery.IsEmpty then
    begin
      Result := TPessoa.Create;
      Result.Id := LQuery.FieldByName('ID').AsLargeInt;
      Result.EmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
      Result.Tipo := LQuery.FieldByName('TIPO').AsString[1];
      if Trim(LQuery.FieldByName('TIPO_PESSOA').AsString) <> '' then
        Result.TipoPessoa := LQuery.FieldByName('TIPO_PESSOA').AsString[1]
      else
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
      Result.CidadeId := LQuery.FieldByName('CIDADE_ID').AsLargeInt;
      Result.Uf := LQuery.FieldByName('UF').AsString;
      Result.Cep := LQuery.FieldByName('CEP').AsString;
      Result.Telefone := LQuery.FieldByName('TELEFONE').AsString;
      Result.Celular := LQuery.FieldByName('CELULAR').AsString;
      Result.Email := LQuery.FieldByName('EMAIL').AsString;
      Result.Contato := LQuery.FieldByName('CONTATO').AsString;
      Result.DataNascimento := LQuery.FieldByName('DATA_NASCIMENTO').AsDateTime;
      Result.LimiteCredito := LQuery.FieldByName('LIMITE_CREDITO').AsCurrency;
      if Trim(LQuery.FieldByName('ATIVO').AsString) <> '' then
        Result.Ativo := LQuery.FieldByName('ATIVO').AsString[1]
      else
        Result.Ativo := 'A';
      Result.Observacoes := LQuery.FieldByName('OBSERVACOES').AsString;
      Result.DataCadastro := LQuery.FieldByName('DATA_CADASTRO').AsDateTime;
    end;
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TPessoaService.BuscarTodos(ATipo: Char; const AFiltro: string): TSQLQuery;
var
  LCondicao, LOrdem: string;
  LNome, LVal: array of string;
  LCount: Integer;
begin
  LCondicao := 'EMPRESA_ID = :EMP';
  SetLength(LNome, 4);
  SetLength(LVal, 4);
  LNome[0] := 'EMP';
  LVal[0] := IntToStr(TSessao.GetInstance.EmpresaId);
  LCount := 1;

  if ATipo in ['C', 'F'] then
  begin
    LCondicao := LCondicao + ' AND TIPO = :TIPO';
    LNome[LCount] := 'TIPO';
    LVal[LCount] := ATipo;
    Inc(LCount);
  end;

  if AFiltro <> '' then
  begin
    LCondicao := LCondicao + ' AND (UPPER(NOME) CONTAINING UPPER(:F1) ' +
      'OR CPF_CNPJ CONTAINING :F2)';
    LNome[LCount] := 'F1';
    LVal[LCount] := AFiltro;
    Inc(LCount);
    LNome[LCount] := 'F2';
    LVal[LCount] := AFiltro;
    Inc(LCount);
  end;

  SetLength(LNome, LCount);
  SetLength(LVal, LCount);
  LOrdem := 'NOME';

  Result := FPessoaRepo.BuscarTodosParam(LCondicao, LNome, LVal, LOrdem);
end;

function TPessoaService.Pesquisar(const ATermo: string; ATipo: Char): TSQLQuery;
var
  LCondicao, LOrdem: string;
  LNome, LVal: array of string;
  LCount: Integer;
begin
  LCondicao := 'EMPRESA_ID = :EMP AND (UPPER(NOME) CONTAINING UPPER(:T) ' +
    'OR CPF_CNPJ CONTAINING :T OR UPPER(CIDADE) CONTAINING UPPER(:T))';
  SetLength(LNome, 3);
  SetLength(LVal, 3);
  LNome[0] := 'EMP';
  LVal[0] := IntToStr(TSessao.GetInstance.EmpresaId);
  LNome[1] := 'T';
  LVal[1] := ATermo;
  LCount := 2;

  if ATipo in ['C', 'F'] then
  begin
    LCondicao := LCondicao + ' AND TIPO = :TIPO';
    LNome[LCount] := 'TIPO';
    LVal[LCount] := ATipo;
    Inc(LCount);
  end;

  SetLength(LNome, LCount);
  SetLength(LVal, LCount);
  LOrdem := 'NOME';

  Result := FPessoaRepo.BuscarTodosParam(LCondicao, LNome, LVal, LOrdem);
end;

function TPessoaService.Inserir(AObj: TPessoa): Int64;
var
  LQuery: TSQLQuery;
  LGerador: TSQLQuery;
  LTipo: string;
begin
  if AObj.EmpresaId <= 0 then
    AObj.EmpresaId := TSessao.GetInstance.EmpresaId;

  Validar(AObj);

  LTipo := UpperCase(Trim(AObj.TipoPessoa));
  if LTipo = '' then
    LTipo := 'F';

  // INSERT direto (em vez de InserirParam) porque DATA_NASCIMENTO é DATE:
  // o repositório genérico trabalha só com strings e o SQLDB recusa
  // converter 'yyyy-mm-dd' para ftDate ("Invalid variant type cast").
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    LQuery.SQL.Text :=
      'INSERT INTO PESSOA (ID, EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, NOME_FANTASIA, ' +
      'CPF_CNPJ, RG_IE, ENDERECO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, CIDADE_ID, UF, ' +
      'CEP, TELEFONE, CELULAR, EMAIL, CONTATO, DATA_NASCIMENTO, LIMITE_CREDITO, ' +
      'OBSERVACOES, ATIVO) VALUES (GEN_ID(GEN_PESSOA_ID, 1), :EMP, :TIPO, :TIPO_PESSOA, ' +
      ':NOME, :NOME_FANTASIA, :CPF_CNPJ, :RGIE, :ENDERECO, :NUMERO, :COMPLEMENTO, ' +
      ':BAIRRO, :CIDADE, :CIDADE_ID, :UF, :CEP, :TELEFONE, :CELULAR, :EMAIL, :CONTATO, ' +
      ':DATA_NASC, :LIMITE, :OBS, :ATIVO)';
    PreencherParametros(LQuery, AObj, LTipo);
    LQuery.ExecSQL;
    Conexao.Confirmar;
  finally
    LQuery.Free;
  end;

  LGerador := TSQLQuery.Create(nil);
  try
    LGerador.DataBase := Conexao.Connection;
    LGerador.Transaction := Conexao.Transaction;
    LGerador.SQL.Text := 'SELECT GEN_ID(GEN_PESSOA_ID, 0) FROM RDB$DATABASE';
    LGerador.Open;
    Result := LGerador.Fields[0].AsLargeInt;
  finally
    LGerador.Free;
  end;

  LogOperacao('PESSOA', 'I', Result);
end;

function TPessoaService.Atualizar(AObj: TPessoa): Boolean;
var
  LQuery: TSQLQuery;
  LTipoAtual: Char;
  LTipo: string;
begin
  ValidarId(AObj.Id, 'Pessoa');

  if AObj.EmpresaId <= 0 then
    AObj.EmpresaId := TSessao.GetInstance.EmpresaId;

  Validar(AObj);

  // Bloquear troca de TIPO
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    LQuery.SQL.Text := 'SELECT TIPO FROM PESSOA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AObj.Id;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise Exception.Create('Pessoa não encontrada.');
    LTipoAtual := LQuery.FieldByName('TIPO').AsString[1];
  finally
    LQuery.Free;
  end;

  if LTipoAtual <> AObj.Tipo then
    raise Exception.Create('Não é permitido alterar o tipo de pessoa (cliente/fornecedor).');

  LTipo := UpperCase(Trim(AObj.TipoPessoa));
  if LTipo = '' then
    LTipo := 'F';

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    LQuery.SQL.Text :=
      'UPDATE PESSOA SET TIPO = :TIPO, TIPO_PESSOA = :TIPO_PESSOA, NOME = :NOME, ' +
      'NOME_FANTASIA = :NOME_FANTASIA, CPF_CNPJ = :CPF_CNPJ, RG_IE = :RGIE, ' +
      'ENDERECO = :ENDERECO, NUMERO = :NUMERO, COMPLEMENTO = :COMPLEMENTO, ' +
      'BAIRRO = :BAIRRO, CIDADE = :CIDADE, CIDADE_ID = :CIDADE_ID, UF = :UF, ' +
      'CEP = :CEP, TELEFONE = :TELEFONE, CELULAR = :CELULAR, EMAIL = :EMAIL, ' +
      'CONTATO = :CONTATO, DATA_NASCIMENTO = :DATA_NASC, LIMITE_CREDITO = :LIMITE, ' +
      'OBSERVACOES = :OBS, ATIVO = :ATIVO WHERE ID = :ID';
    PreencherParametros(LQuery, AObj, LTipo);
    LQuery.ParamByName('ID').AsLargeInt := AObj.Id;
    LQuery.ExecSQL;
    Conexao.Confirmar;
  finally
    LQuery.Free;
  end;

  LogOperacao('PESSOA', 'U', AObj.Id);
  Result := True;
end;

procedure TPessoaService.PreencherParametros(LQuery: TSQLQuery; AObj: TPessoa;
  const ATipoPessoa: string);
begin
  if LQuery.Params.FindParam('EMP') <> nil then
    LQuery.ParamByName('EMP').AsLargeInt := AObj.EmpresaId;
  LQuery.ParamByName('TIPO').AsString := AObj.Tipo;
  LQuery.ParamByName('TIPO_PESSOA').AsString := ATipoPessoa;
  LQuery.ParamByName('NOME').AsString := AObj.Nome;
  LQuery.ParamByName('NOME_FANTASIA').AsString := AObj.NomeFantasia;
  LQuery.ParamByName('CPF_CNPJ').AsString := AObj.CpfCnpj;
  LQuery.ParamByName('RGIE').AsString := AObj.RgIe;
  LQuery.ParamByName('ENDERECO').AsString := AObj.Endereco;
  LQuery.ParamByName('NUMERO').AsString := AObj.Numero;
  LQuery.ParamByName('COMPLEMENTO').AsString := AObj.Complemento;
  LQuery.ParamByName('BAIRRO').AsString := AObj.Bairro;
  LQuery.ParamByName('CIDADE').AsString := AObj.Cidade;
  LQuery.ParamByName('CIDADE_ID').AsLargeInt := AObj.CidadeId;
  LQuery.ParamByName('UF').AsString := AObj.Uf;
  LQuery.ParamByName('CEP').AsString := AObj.Cep;
  LQuery.ParamByName('TELEFONE').AsString := AObj.Telefone;
  LQuery.ParamByName('CELULAR').AsString := AObj.Celular;
  LQuery.ParamByName('EMAIL').AsString := AObj.Email;
  LQuery.ParamByName('CONTATO').AsString := AObj.Contato;

  if AObj.DataNascimento > 0 then
    LQuery.ParamByName('DATA_NASC').AsDateTime := AObj.DataNascimento
  else
    LQuery.ParamByName('DATA_NASC').Clear;

  LQuery.ParamByName('LIMITE').AsCurrency := AObj.LimiteCredito;
  LQuery.ParamByName('OBS').AsString := AObj.Observacoes;
  LQuery.ParamByName('ATIVO').AsString := AObj.Ativo;
end;

function TPessoaService.Excluir(AId: Int64): Boolean;
var
  LQuery: TSQLQuery;
  LUsos: string;

  procedure Verificar(const ATabela, ACampo: string; AQuantidade: Int64);
  begin
    if AQuantidade > 0 then
    begin
      if LUsos <> '' then
        LUsos := LUsos + ', ';
      LUsos := LUsos + ATabela + ' (' + ACampo + ')';
    end;
  end;

begin
  ValidarId(AId, 'Pessoa');

  // Bloquear exclusão se houver referência em qualquer coluna CLIENTE_ID/FORNECEDOR_ID.
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ' +
      '(SELECT COUNT(*) FROM CONTA_RECEBER WHERE CLIENTE_ID = :ID) AS CONTA_RECEBER, ' +
      '(SELECT COUNT(*) FROM CONTA_PAGAR WHERE FORNECEDOR_ID = :ID) AS CONTA_PAGAR, ' +
      '(SELECT COUNT(*) FROM NOTA_ENTRADA WHERE FORNECEDOR_ID = :ID) AS NOTA_ENTRADA, ' +
      '(SELECT COUNT(*) FROM NOTA_SAIDA WHERE CLIENTE_ID = :ID) AS NOTA_SAIDA, ' +
      '(SELECT COUNT(*) FROM PEDIDO_COMPRA WHERE FORNECEDOR_ID = :ID) AS PEDIDO_COMPRA, ' +
      '(SELECT COUNT(*) FROM PEDIDO_VENDA WHERE CLIENTE_ID = :ID) AS PEDIDO_VENDA, ' +
      '(SELECT COUNT(*) FROM PRODUTO WHERE FORNECEDOR_ID = :ID) AS PRODUTO, ' +
      '(SELECT COUNT(*) FROM FINANCEIRO WHERE CLIENTE_ID = :ID) AS FINANCEIRO_CLIENTE, ' +
      '(SELECT COUNT(*) FROM FINANCEIRO WHERE FORNECEDOR_ID = :ID) AS FINANCEIRO_FORNECEDOR ' +
      'FROM RDB$DATABASE';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;

    LUsos := '';
    Verificar('Contas a receber', 'cliente', LQuery.FieldByName('CONTA_RECEBER').AsLargeInt);
    Verificar('Contas a pagar', 'fornecedor', LQuery.FieldByName('CONTA_PAGAR').AsLargeInt);
    Verificar('Notas de entrada', 'fornecedor', LQuery.FieldByName('NOTA_ENTRADA').AsLargeInt);
    Verificar('Notas de saída', 'cliente', LQuery.FieldByName('NOTA_SAIDA').AsLargeInt);
    Verificar('Pedidos de compra', 'fornecedor', LQuery.FieldByName('PEDIDO_COMPRA').AsLargeInt);
    Verificar('Pedidos de venda', 'cliente', LQuery.FieldByName('PEDIDO_VENDA').AsLargeInt);
    Verificar('Produtos', 'fornecedor', LQuery.FieldByName('PRODUTO').AsLargeInt);
    Verificar('Financeiro', 'cliente', LQuery.FieldByName('FINANCEIRO_CLIENTE').AsLargeInt);
    Verificar('Financeiro', 'fornecedor', LQuery.FieldByName('FINANCEIRO_FORNECEDOR').AsLargeInt);

    if LUsos <> '' then
      raise Exception.Create('Esta pessoa não pode ser excluída pois é usada em: ' + LUsos);
  finally
    LQuery.Free;
  end;

  Result := FPessoaRepo.Excluir(AId);
  LogOperacao('PESSOA', 'D', AId);
end;

end.
