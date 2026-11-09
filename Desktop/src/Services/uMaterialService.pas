unit uMaterialService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service: Material
  Descrição: Regras de negócio para Materiais (insumos)
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uMaterial,
  uSessao;

type
  { TMaterialService }
  TMaterialService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    function CodigoExiste(const ACodigo: string; AExcluirId: Int64 = 0): Boolean;
    procedure Validar(AObj: TMaterial);
    procedure GarantirDaEmpresa(AId: Int64);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TMaterial;
    function BuscarTodos(const AFiltro: string = ''): TSQLQuery;
    function Inserir(AObj: TMaterial): Int64;
    function Atualizar(AObj: TMaterial): Boolean;
    function Excluir(AId: Int64): Boolean;
    function Pesquisar(const ATermo: string): TSQLQuery;
  end;

implementation

{ TMaterialService }

constructor TMaterialService.Create;
begin
  FRepo := TRepositoryBase.Create('MATERIAL');
  inherited Create(FRepo);
end;

destructor TMaterialService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

procedure TMaterialService.Validar(AObj: TMaterial);
begin
  ValidarCampoObrigatorio(AObj.Descricao, 'Descrição');
  if CodigoExiste(AObj.Codigo, AObj.Id) then
    raise Exception.Create('Já existe um material com este código.');
end;

function TMaterialService.CodigoExiste(const ACodigo: string;
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

function TMaterialService.BuscarPorId(AId: Int64): TMaterial;
var
  LQuery: TSQLQuery;
begin
  Result := nil;
  LQuery := FRepo.BuscarPorId(AId);
  try
    if not LQuery.IsEmpty then
    begin
      Result := TMaterial.Create;
      Result.Id := LQuery.FieldByName('ID').AsLargeInt;
      Result.EmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
      Result.ProdutoFiscalId := LQuery.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt;
      Result.UnidadeId := LQuery.FieldByName('UNIDADE_ID').AsLargeInt;
      Result.Codigo := LQuery.FieldByName('CODIGO').AsString;
      Result.CodigoBarras := LQuery.FieldByName('CODIGO_BARRAS').AsString;
      Result.Descricao := LQuery.FieldByName('DESCRICAO').AsString;
      Result.PrecoCusto := LQuery.FieldByName('PRECO_CUSTO').AsCurrency;
      Result.ControlaEstoque := LQuery.FieldByName('CONTROLA_ESTOQUE').AsString = 'S';
      Result.EstoqueMinimo := LQuery.FieldByName('ESTOQUE_MINIMO').AsFloat;
      Result.Ativo := LQuery.FieldByName('ATIVO').AsString[1];
      Result.Observacoes := LQuery.FieldByName('OBSERVACOES').AsString;
    end;
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TMaterialService.BuscarTodos(const AFiltro: string): TSQLQuery;
begin
  Result := FRepo.BuscarTodosParam(
    'EMPRESA_ID = :EMP',
    ['EMP'],
    [IntToStr(TSessao.GetInstance.EmpresaId)],
    'DESCRICAO');
end;

function TMaterialService.Inserir(AObj: TMaterial): Int64;
const
  CAMPOS = 'EMPRESA_ID, PRODUTO_FISCAL_ID, UNIDADE_ID, CODIGO, ' +
           'CODIGO_BARRAS, DESCRICAO, PRECO_CUSTO, CONTROLA_ESTOQUE, ' +
           'ESTOQUE_MINIMO, ATIVO, OBSERVACOES';
  VALORES_PARAM = ':EMP, :PFISCAL, :UNID, :COD, ' +
                  ':CBARRAS, :DESC, :PCUSTO, :CTRL, ' +
                  ':EMIN, :ATIVO, :OBS';
var
  LCtrl: string;
begin
  Validar(AObj);
  if AObj.ControlaEstoque then LCtrl := 'S' else LCtrl := 'N';
  Result := FRepo.InserirParam(
    CAMPOS, VALORES_PARAM,
    ['EMP', 'PFISCAL', 'UNID', 'COD',
     'CBARRAS', 'DESC', 'PCUSTO', 'CTRL',
     'EMIN', 'ATIVO', 'OBS'],
    [IntToStr(AObj.EmpresaId), IntToStr(AObj.ProdutoFiscalId),
     IntToStr(AObj.UnidadeId), AObj.Codigo,
     AObj.CodigoBarras, AObj.Descricao, CurrToStr(AObj.PrecoCusto),
     LCtrl,
     FloatToStr(AObj.EstoqueMinimo), AObj.Ativo, AObj.Observacoes]);

  LogOperacao('MATERIAL', 'I', Result);
end;

procedure TMaterialService.GarantirDaEmpresa(AId: Int64);
var
  LQuery: TSQLQuery;
begin
  { escrita/leitura por ID só vale para registro da empresa da sessão }
  LQuery := FRepo.BuscarPorId(AId);
  try
    if LQuery.IsEmpty or
       (LQuery.FieldByName('EMPRESA_ID').AsLargeInt <>
        TSessao.GetInstance.EmpresaId) then
      raise Exception.Create('Material não encontrado para a empresa atual.');
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TMaterialService.Atualizar(AObj: TMaterial): Boolean;
const
  CAMPOS_PARAM = 'PRODUTO_FISCAL_ID = :PFISCAL, UNIDADE_ID = :UNID, ' +
                 'CODIGO = :COD, CODIGO_BARRAS = :CBARRAS, ' +
                 'DESCRICAO = :DESC, PRECO_CUSTO = :PCUSTO, ' +
                 'CONTROLA_ESTOQUE = :CTRL, ESTOQUE_MINIMO = :EMIN, ' +
                 'ATIVO = :ATIVO, OBSERVACOES = :OBS';
var
  LCtrl: string;
begin
  ValidarId(AObj.Id, 'Material');
  GarantirDaEmpresa(AObj.Id);
  Validar(AObj);
  if AObj.ControlaEstoque then LCtrl := 'S' else LCtrl := 'N';

  Result := FRepo.AtualizarParam(
    AObj.Id, CAMPOS_PARAM,
    ['PFISCAL', 'UNID', 'COD', 'CBARRAS', 'DESC', 'PCUSTO', 'CTRL',
     'EMIN', 'ATIVO', 'OBS'],
    [IntToStr(AObj.ProdutoFiscalId), IntToStr(AObj.UnidadeId),
     AObj.Codigo, AObj.CodigoBarras, AObj.Descricao,
     CurrToStr(AObj.PrecoCusto), LCtrl,
     FloatToStr(AObj.EstoqueMinimo), AObj.Ativo, AObj.Observacoes]);

  LogOperacao('MATERIAL', 'U', AObj.Id);
end;

function TMaterialService.Excluir(AId: Int64): Boolean;
begin
  ValidarId(AId, 'Material');
  GarantirDaEmpresa(AId);
  Result := FRepo.Excluir(AId);
  LogOperacao('MATERIAL', 'D', AId);
end;

function TMaterialService.Pesquisar(const ATermo: string): TSQLQuery;
begin
  { CAST + CONTAINING: o termo pode ser maior que CODIGO (30) ou
    CODIGO_BARRAS (20) e o CONTAINING direto estoura com "string
    right truncation". O CAST amplia a coluna para o tamanho do termo. }
  Result := FRepo.BuscarTodosParam(
    'EMPRESA_ID = :EMP AND ' +
    '(UPPER(CAST(DESCRICAO AS VARCHAR(1000))) CONTAINING UPPER(:T) OR ' +
    'UPPER(CAST(CODIGO AS VARCHAR(200))) CONTAINING UPPER(:T) OR ' +
    'UPPER(CAST(CODIGO_BARRAS AS VARCHAR(200))) CONTAINING UPPER(:T))',
    ['EMP', 'T'],
    [IntToStr(TSessao.GetInstance.EmpresaId), ATermo],
    'DESCRICAO');
end;

end.
