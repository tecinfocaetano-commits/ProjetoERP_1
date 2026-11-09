unit uProdutoService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service: Produto
  Descrição: Regras de negócio para o cadastro de Produtos
             (produto de produção/venda; CATEGORIA_ID e
             UNIDADE_ID são obrigatórios — domínio DM_ID NOT NULL;
             GRADE_ID é anulável).
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uProduto,
  uSessao;

type
  { TProdutoService }
  TProdutoService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    procedure Validar(AObj: TProduto);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TProduto;
    function BuscarTodos(const AFiltro: string = ''): TSQLQuery;
    function Inserir(AObj: TProduto): Int64;
    function Atualizar(AObj: TProduto): Boolean;
    function Excluir(AId: Int64): Boolean;
    function Pesquisar(const ATermo: string): TSQLQuery;
  end;

implementation

{ TProdutoService }

constructor TProdutoService.Create;
begin
  FRepo := TRepositoryBase.Create('PRODUTO');
  inherited Create(FRepo);
end;

destructor TProdutoService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

procedure TProdutoService.Validar(AObj: TProduto);
begin
  ValidarCampoObrigatorio(AObj.Descricao, 'Descrição');
  if AObj.CategoriaId <= 0 then
    raise Exception.Create('Selecione a Categoria do produto.');
  if AObj.UnidadeId <= 0 then
    raise Exception.Create('Selecione a Unidade do produto.');
  if AObj.PrecoVenda <= 0 then
    raise Exception.Create('O Preço de Venda deve ser maior que zero.');
end;

function TProdutoService.BuscarPorId(AId: Int64): TProduto;
var
  LQuery: TSQLQuery;
begin
  Result := nil;
  LQuery := FRepo.BuscarPorId(AId);
  try
    if not LQuery.IsEmpty then
    begin
      Result := TProduto.Create;
      Result.Id := LQuery.FieldByName('ID').AsLargeInt;
      Result.EmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
      Result.CategoriaId := LQuery.FieldByName('CATEGORIA_ID').AsLargeInt;
      Result.UnidadeId := LQuery.FieldByName('UNIDADE_ID').AsLargeInt;
      Result.Codigo := LQuery.FieldByName('CODIGO').AsString;
      Result.CodigoBarras := LQuery.FieldByName('CODIGO_BARRAS').AsString;
      Result.Descricao := LQuery.FieldByName('DESCRICAO').AsString;
      Result.DescricaoPDV := LQuery.FieldByName('DESCRICAO_PDV').AsString;
      Result.Ncm := LQuery.FieldByName('NCM').AsString;
      Result.Cest := LQuery.FieldByName('CEST').AsString;
      Result.CfopVenda := LQuery.FieldByName('CFOP_VENDA').AsString;
      if LQuery.FindField('CFOP_COMPRA') <> nil then
        Result.CfopCompra := LQuery.FieldByName('CFOP_COMPRA').AsString;
      Result.PrecoCusto := LQuery.FieldByName('PRECO_CUSTO').AsCurrency;
      Result.PrecoVenda := LQuery.FieldByName('PRECO_VENDA').AsCurrency;
      Result.MargemLucro := LQuery.FieldByName('MARGEM_LUCRO').AsFloat;
      Result.EstoqueMinimo := LQuery.FieldByName('ESTOQUE_MINIMO').AsFloat;
      Result.EstoqueMaximo := LQuery.FieldByName('ESTOQUE_MAXIMO').AsFloat;
      Result.ControlaEstoque :=
        LQuery.FieldByName('CONTROLA_ESTOQUE').AsString = 'S';
      Result.Ativo := LQuery.FieldByName('ATIVO').AsString[1];
      Result.Observacoes := LQuery.FieldByName('OBSERVACOES').AsString;
      if (LQuery.FindField('GRADE_ID') <> nil) and
         (not LQuery.FieldByName('GRADE_ID').IsNull) then
        Result.GradeId := LQuery.FieldByName('GRADE_ID').AsLargeInt;
      if (LQuery.FindField('PRODUTO_FISCAL_ID') <> nil) and
         (not LQuery.FieldByName('PRODUTO_FISCAL_ID').IsNull) then
        Result.ProdutoFiscalId :=
          LQuery.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt;
    end;
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TProdutoService.BuscarTodos(const AFiltro: string): TSQLQuery;
begin
  Result := FRepo.BuscarTodosParam(
    'EMPRESA_ID = :EMP',
    ['EMP'],
    [IntToStr(TSessao.GetInstance.EmpresaId)],
    'DESCRICAO');
end;

function TProdutoService.Inserir(AObj: TProduto): Int64;
const
  CAMPOS = 'EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, ' +
           'CODIGO_BARRAS, DESCRICAO, DESCRICAO_PDV, NCM, CEST, ' +
           'CFOP_VENDA, PRECO_CUSTO, PRECO_VENDA, MARGEM_LUCRO, ' +
           'ESTOQUE_MINIMO, ESTOQUE_MAXIMO, CONTROLA_ESTOQUE, ATIVO, ' +
           'OBSERVACOES, GRADE_ID';
  VALORES_PARAM = ':EMP, :CAT, :UNID, :COD, :BAR, :DESC, :PDV, ' +
                  ':NCM, :CEST, :CFOP, :CUSTO, :VENDA, :MARGEM, ' +
                  ':MIN, :MAX, :CTRL, :ATIVO, :OBS, :GRADE';
var
  LNulls: array of string;
  LCtrl: string;
begin
  Validar(AObj);
  if AObj.ControlaEstoque then LCtrl := 'S' else LCtrl := 'N';
  { GRADE_ID é anulável: 0 vira NULL ("sem grade padrão") }
  if AObj.GradeId <= 0 then
  begin
    SetLength(LNulls, 1);
    LNulls[0] := 'GRADE';
  end;

  Result := FRepo.InserirParamN(
    CAMPOS, VALORES_PARAM,
    ['EMP', 'CAT', 'UNID', 'COD', 'BAR', 'DESC', 'PDV',
     'NCM', 'CEST', 'CFOP', 'CUSTO', 'VENDA', 'MARGEM',
     'MIN', 'MAX', 'CTRL', 'ATIVO', 'OBS', 'GRADE'],
    [IntToStr(AObj.EmpresaId), IntToStr(AObj.CategoriaId),
     IntToStr(AObj.UnidadeId), AObj.Codigo, AObj.CodigoBarras,
     AObj.Descricao, AObj.DescricaoPDV, AObj.Ncm, AObj.Cest,
     AObj.CfopVenda, CurrToStr(AObj.PrecoCusto), CurrToStr(AObj.PrecoVenda),
     FloatToStr(AObj.MargemLucro), FloatToStr(AObj.EstoqueMinimo),
     FloatToStr(AObj.EstoqueMaximo), LCtrl, AObj.Ativo,
     AObj.Observacoes, IntToStr(AObj.GradeId)],
    LNulls);

  LogOperacao('PRODUTO', 'I', Result);
end;

function TProdutoService.Atualizar(AObj: TProduto): Boolean;
const
  CAMPOS_PARAM = 'CATEGORIA_ID = :CAT, UNIDADE_ID = :UNID, ' +
                 'CODIGO = :COD, CODIGO_BARRAS = :BAR, ' +
                 'DESCRICAO = :DESC, DESCRICAO_PDV = :PDV, ' +
                 'NCM = :NCM, CEST = :CEST, CFOP_VENDA = :CFOP, ' +
                 'PRECO_CUSTO = :CUSTO, PRECO_VENDA = :VENDA, ' +
                 'MARGEM_LUCRO = :MARGEM, ESTOQUE_MINIMO = :MIN, ' +
                 'ESTOQUE_MAXIMO = :MAX, CONTROLA_ESTOQUE = :CTRL, ' +
                 'ATIVO = :ATIVO, OBSERVACOES = :OBS, GRADE_ID = :GRADE';
var
  LNulls: array of string;
  LCtrl: string;
begin
  ValidarId(AObj.Id, 'Produto');
  Validar(AObj);
  if AObj.ControlaEstoque then LCtrl := 'S' else LCtrl := 'N';
  if AObj.GradeId <= 0 then
  begin
    SetLength(LNulls, 1);
    LNulls[0] := 'GRADE';
  end;

  Result := FRepo.AtualizarParamN(
    AObj.Id, CAMPOS_PARAM,
    ['CAT', 'UNID', 'COD', 'BAR', 'DESC', 'PDV',
     'NCM', 'CEST', 'CFOP', 'CUSTO', 'VENDA', 'MARGEM',
     'MIN', 'MAX', 'CTRL', 'ATIVO', 'OBS', 'GRADE'],
    [IntToStr(AObj.CategoriaId), IntToStr(AObj.UnidadeId),
     AObj.Codigo, AObj.CodigoBarras, AObj.Descricao, AObj.DescricaoPDV,
     AObj.Ncm, AObj.Cest, AObj.CfopVenda, CurrToStr(AObj.PrecoCusto),
     CurrToStr(AObj.PrecoVenda), FloatToStr(AObj.MargemLucro),
     FloatToStr(AObj.EstoqueMinimo), FloatToStr(AObj.EstoqueMaximo),
     LCtrl, AObj.Ativo, AObj.Observacoes, IntToStr(AObj.GradeId)],
    LNulls);

  LogOperacao('PRODUTO', 'U', AObj.Id);
end;

function TProdutoService.Excluir(AId: Int64): Boolean;
begin
  ValidarId(AId, 'Produto');
  Result := FRepo.Excluir(AId);
  LogOperacao('PRODUTO', 'D', AId);
end;

function TProdutoService.Pesquisar(const ATermo: string): TSQLQuery;
begin
  { CAST + CONTAINING: o termo pode ser maior que CODIGO/CODIGO_BARRAS
    e o CONTAINING direto estoura com "string right truncation". }
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
