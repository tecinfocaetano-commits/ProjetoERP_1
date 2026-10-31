unit uProdutoFinanceiroService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service: Produto Financeiro
  Descrição: Regras de negócio para produtos financeiros
             (serviço/outros)
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uProdutoFinanceiro,
  uSessao;

type
  { TProdutoFinanceiroService }
  TProdutoFinanceiroService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    function CodigoExiste(const ACodigo: string; AExcluirId: Int64 = 0): Boolean;
    procedure Validar(AObj: TProdutoFinanceiro);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TProdutoFinanceiro;
    function BuscarTodos(const AFiltro: string = ''): TSQLQuery;
    function Inserir(AObj: TProdutoFinanceiro): Int64;
    function Atualizar(AObj: TProdutoFinanceiro): Boolean;
    function Excluir(AId: Int64): Boolean;
    function Pesquisar(const ATermo: string): TSQLQuery;
  end;

implementation

{ TProdutoFinanceiroService }

constructor TProdutoFinanceiroService.Create;
begin
  FRepo := TRepositoryBase.Create('PRODUTO_FINANCEIRO');
  inherited Create(FRepo);
end;

destructor TProdutoFinanceiroService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

procedure TProdutoFinanceiroService.Validar(AObj: TProdutoFinanceiro);
begin
  ValidarCampoObrigatorio(AObj.Descricao, 'Descrição');
  if not (AObj.Tipo in ['S', 'O']) then
    raise Exception.Create('Tipo deve ser S (serviço) ou O (outros).');
  if CodigoExiste(AObj.Codigo, AObj.Id) then
    raise Exception.Create('Já existe um produto financeiro com este código.');
end;

function TProdutoFinanceiroService.CodigoExiste(const ACodigo: string;
  AExcluirId: Int64): Boolean;
var
  LCond: string;
  LNome: array of string;
  LVal: array of string;
begin
  if Trim(ACodigo) = '' then
  begin
    Result := False;
    Exit;
  end;

  if AExcluirId > 0 then
  begin
    LCond := 'CODIGO = :COD AND ID <> :EXC';
    LNome := ['COD', 'EXC'];
    LVal := [ACodigo, IntToStr(AExcluirId)];
  end
  else
  begin
    LCond := 'CODIGO = :COD';
    LNome := ['COD'];
    LVal := [ACodigo];
  end;
  Result := FRepo.ContarParam(LCond, LNome, LVal) > 0;
end;

function TProdutoFinanceiroService.BuscarPorId(AId: Int64): TProdutoFinanceiro;
var
  LQuery: TSQLQuery;
begin
  Result := nil;
  LQuery := FRepo.BuscarPorId(AId);
  try
    if not LQuery.IsEmpty then
    begin
      Result := TProdutoFinanceiro.Create;
      Result.Id := LQuery.FieldByName('ID').AsLargeInt;
      Result.EmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
      Result.ProdutoFiscalId := LQuery.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt;
      Result.Codigo := LQuery.FieldByName('CODIGO').AsString;
      Result.Descricao := LQuery.FieldByName('DESCRICAO').AsString;
      Result.Tipo := LQuery.FieldByName('TIPO').AsString[1];
      Result.Valor := LQuery.FieldByName('VALOR').AsCurrency;
      Result.Ativo := LQuery.FieldByName('ATIVO').AsString[1];
      Result.Observacoes := LQuery.FieldByName('OBSERVACOES').AsString;
    end;
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TProdutoFinanceiroService.BuscarTodos(const AFiltro: string): TSQLQuery;
begin
  Result := FRepo.BuscarTodosParam(
    'EMPRESA_ID = :EMP',
    ['EMP'],
    [IntToStr(TSessao.GetInstance.EmpresaId)],
    'DESCRICAO');
end;

function TProdutoFinanceiroService.Inserir(AObj: TProdutoFinanceiro): Int64;
const
  CAMPOS = 'EMPRESA_ID, PRODUTO_FISCAL_ID, CODIGO, DESCRICAO, TIPO, ' +
           'VALOR, ATIVO, OBSERVACOES';
  VALORES_PARAM = ':EMP, :PFISCAL, :COD, :DESC, :TIPO, ' +
                  ':VALOR, :ATIVO, :OBS';
begin
  Validar(AObj);
  Result := FRepo.InserirParam(
    CAMPOS, VALORES_PARAM,
    ['EMP', 'PFISCAL', 'COD', 'DESC', 'TIPO',
     'VALOR', 'ATIVO', 'OBS'],
    [IntToStr(AObj.EmpresaId), IntToStr(AObj.ProdutoFiscalId),
     AObj.Codigo, AObj.Descricao, AObj.Tipo,
     CurrToStr(AObj.Valor), AObj.Ativo, AObj.Observacoes]);

  LogOperacao('PRODUTO_FINANCEIRO', 'I', Result);
end;

function TProdutoFinanceiroService.Atualizar(AObj: TProdutoFinanceiro): Boolean;
const
  CAMPOS_PARAM = 'PRODUTO_FISCAL_ID = :PFISCAL, CODIGO = :COD, ' +
                 'DESCRICAO = :DESC, TIPO = :TIPO, VALOR = :VALOR, ' +
                 'ATIVO = :ATIVO, OBSERVACOES = :OBS';
begin
  ValidarId(AObj.Id, 'Produto Financeiro');
  Validar(AObj);

  Result := FRepo.AtualizarParam(
    AObj.Id, CAMPOS_PARAM,
    ['PFISCAL', 'COD', 'DESC', 'TIPO', 'VALOR', 'ATIVO', 'OBS'],
    [IntToStr(AObj.ProdutoFiscalId), AObj.Codigo, AObj.Descricao,
     AObj.Tipo, CurrToStr(AObj.Valor), AObj.Ativo, AObj.Observacoes]);

  LogOperacao('PRODUTO_FINANCEIRO', 'U', AObj.Id);
end;

function TProdutoFinanceiroService.Excluir(AId: Int64): Boolean;
begin
  ValidarId(AId, 'Produto Financeiro');
  Result := FRepo.Excluir(AId);
  LogOperacao('PRODUTO_FINANCEIRO', 'D', AId);
end;

function TProdutoFinanceiroService.Pesquisar(const ATermo: string): TSQLQuery;
begin
  Result := FRepo.BuscarTodosParam(
    '(UPPER(DESCRICAO) CONTAINING UPPER(:T) OR CODIGO CONTAINING :T)',
    ['T'], [ATermo],
    'DESCRICAO');
end;

end.
