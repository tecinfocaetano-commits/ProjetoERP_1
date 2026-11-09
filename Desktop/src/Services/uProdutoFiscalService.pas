unit uProdutoFiscalService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service: Produto Fiscal
  Descrição: Regras de negócio para classificação fiscal
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uProdutoFiscal,
  uSessao;

type
  { TProdutoFiscalService }
  TProdutoFiscalService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    function CodigoExiste(const ACodigo: string; AExcluirId: Int64 = 0): Boolean;
    procedure Validar(AObj: TProdutoFiscal);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TProdutoFiscal;
    function BuscarTodos(const AFiltro: string = ''): TSQLQuery;
    function Inserir(AObj: TProdutoFiscal): Int64;
    function Atualizar(AObj: TProdutoFiscal): Boolean;
    function Excluir(AId: Int64): Boolean;
    function Pesquisar(const ATermo: string): TSQLQuery;
  end;

implementation

{ TProdutoFiscalService }

constructor TProdutoFiscalService.Create;
begin
  FRepo := TRepositoryBase.Create('PRODUTO_FISCAL');
  inherited Create(FRepo);
end;

destructor TProdutoFiscalService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

procedure TProdutoFiscalService.Validar(AObj: TProdutoFiscal);
begin
  ValidarCampoObrigatorio(AObj.Descricao, 'Descrição');
  if CodigoExiste(AObj.Codigo, AObj.Id) then
    raise Exception.Create('Já existe um produto fiscal com este código.');
end;

function TProdutoFiscalService.CodigoExiste(const ACodigo: string;
  AExcluirId: Int64): Boolean;
var
  LCond: string;
  LNome: array of string;
  LVal: array of string;
begin
  { código vazio não pode barrar (campo opcional) }
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

function TProdutoFiscalService.BuscarPorId(AId: Int64): TProdutoFiscal;
var
  LQuery: TSQLQuery;
begin
  Result := nil;
  LQuery := FRepo.BuscarPorId(AId);
  try
    if not LQuery.IsEmpty then
    begin
      Result := TProdutoFiscal.Create;
      Result.Id := LQuery.FieldByName('ID').AsLargeInt;
      Result.EmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
      Result.Codigo := LQuery.FieldByName('CODIGO').AsString;
      Result.Descricao := LQuery.FieldByName('DESCRICAO').AsString;
      Result.Ncm := LQuery.FieldByName('NCM').AsString;
      Result.Cest := LQuery.FieldByName('CEST').AsString;
      Result.Cfop := LQuery.FieldByName('CFOP').AsString;
      Result.CfopVenda := LQuery.FieldByName('CFOP_VENDA').AsString;
      Result.CfopCompra := LQuery.FieldByName('CFOP_COMPRA').AsString;
      Result.CstIcms := LQuery.FieldByName('CST_ICMS').AsString;
      Result.CstPis := LQuery.FieldByName('CST_PIS').AsString;
      Result.CstCofins := LQuery.FieldByName('CST_COFINS').AsString;
      Result.AliqIcms := LQuery.FieldByName('ALIQ_ICMS').AsFloat;
      Result.AliqPis := LQuery.FieldByName('ALIQ_PIS').AsFloat;
      Result.AliqCofins := LQuery.FieldByName('ALIQ_COFINS').AsFloat;
      Result.PesoLiquido := LQuery.FieldByName('PESO_LIQUIDO').AsFloat;
      Result.PesoBruto := LQuery.FieldByName('PESO_BRUTO').AsFloat;
      if (LQuery.FindField('TIPO') <> nil) and
         (not LQuery.FieldByName('TIPO').IsNull) then
        Result.Tipo := Trim(LQuery.FieldByName('TIPO').AsString)
      else
        Result.Tipo := '';
      if LQuery.FindField('VALOR') <> nil then
        Result.Valor := LQuery.FieldByName('VALOR').AsFloat;
      Result.Ativo := LQuery.FieldByName('ATIVO').AsString[1];
      Result.Observacoes := LQuery.FieldByName('OBSERVACOES').AsString;
    end;
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TProdutoFiscalService.BuscarTodos(const AFiltro: string): TSQLQuery;
begin
  Result := FRepo.BuscarTodosParam(
    'EMPRESA_ID = :EMP',
    ['EMP'],
    [IntToStr(TSessao.GetInstance.EmpresaId)],
    'DESCRICAO');
end;

function TProdutoFiscalService.Inserir(AObj: TProdutoFiscal): Int64;
const
  CAMPOS = 'EMPRESA_ID, CODIGO, DESCRICAO, NCM, CEST, CFOP, CFOP_VENDA, ' +
           'CFOP_COMPRA, CST_ICMS, CST_PIS, CST_COFINS, ALIQ_ICMS, ' +
           'ALIQ_PIS, ALIQ_COFINS, PESO_LIQUIDO, PESO_BRUTO, TIPO, VALOR, ' +
           'ATIVO, OBSERVACOES';
  VALORES_PARAM = ':EMP, :COD, :DESC, :NCM, :CEST, :CFOP, :CFOPV, ' +
                  ':CFOPC, :CSTI, :CSTP, :CSTC, :ALII, ' +
                  ':ALIP, :ALIC, :PESOL, :PESOB, :TIPO, :VALOR, :ATIVO, ' +
                  ':OBS';
var
  LNulls: array of string;
begin
  Validar(AObj);
  { TIPO é anulável e o CHECK só aceita 'S'/'O' — string vazia vira NULL }
  if Trim(AObj.Tipo) = '' then
  begin
    SetLength(LNulls, 1);
    LNulls[0] := 'TIPO';
  end;
  Result := FRepo.InserirParamN(
    CAMPOS, VALORES_PARAM,
    ['EMP', 'COD', 'DESC', 'NCM', 'CEST', 'CFOP', 'CFOPV',
     'CFOPC', 'CSTI', 'CSTP', 'CSTC', 'ALII',
     'ALIP', 'ALIC', 'PESOL', 'PESOB', 'TIPO', 'VALOR', 'ATIVO',
     'OBS'],
    [IntToStr(AObj.EmpresaId), AObj.Codigo, AObj.Descricao, AObj.Ncm,
     AObj.Cest, AObj.Cfop, AObj.CfopVenda, AObj.CfopCompra,
     AObj.CstIcms, AObj.CstPis, AObj.CstCofins, FloatToStr(AObj.AliqIcms),
     FloatToStr(AObj.AliqPis), FloatToStr(AObj.AliqCofins),
     FloatToStr(AObj.PesoLiquido), FloatToStr(AObj.PesoBruto), AObj.Tipo,
     FloatToStr(AObj.Valor), AObj.Ativo,
     AObj.Observacoes],
    LNulls);

  LogOperacao('PRODUTO_FISCAL', 'I', Result);
end;

function TProdutoFiscalService.Atualizar(AObj: TProdutoFiscal): Boolean;
const
  CAMPOS_PARAM = 'CODIGO = :COD, DESCRICAO = :DESC, NCM = :NCM, ' +
                 'CEST = :CEST, CFOP = :CFOP, CFOP_VENDA = :CFOPV, ' +
                 'CFOP_COMPRA = :CFOPC, CST_ICMS = :CSTI, ' +
                 'CST_PIS = :CSTP, CST_COFINS = :CSTC, ' +
                 'ALIQ_ICMS = :ALII, ALIQ_PIS = :ALIP, ' +
                 'ALIQ_COFINS = :ALIC, PESO_LIQUIDO = :PESOL, ' +
                 'PESO_BRUTO = :PESOB, TIPO = :TIPO, VALOR = :VALOR, ' +
                 'ATIVO = :ATIVO, OBSERVACOES = :OBS';
var
  LNulls: array of string;
begin
  ValidarId(AObj.Id, 'Produto Fiscal');
  Validar(AObj);
  if Trim(AObj.Tipo) = '' then
  begin
    SetLength(LNulls, 1);
    LNulls[0] := 'TIPO';
  end;

  Result := FRepo.AtualizarParamN(
    AObj.Id, CAMPOS_PARAM,
    ['COD', 'DESC', 'NCM', 'CEST', 'CFOP', 'CFOPV',
     'CFOPC', 'CSTI', 'CSTP', 'CSTC', 'ALII',
     'ALIP', 'ALIC', 'PESOL', 'PESOB', 'TIPO', 'VALOR', 'ATIVO',
     'OBS'],
    [AObj.Codigo, AObj.Descricao, AObj.Ncm, AObj.Cest, AObj.Cfop,
     AObj.CfopVenda, AObj.CfopCompra, AObj.CstIcms, AObj.CstPis,
     AObj.CstCofins, FloatToStr(AObj.AliqIcms), FloatToStr(AObj.AliqPis),
     FloatToStr(AObj.AliqCofins), FloatToStr(AObj.PesoLiquido),
     FloatToStr(AObj.PesoBruto), AObj.Tipo, FloatToStr(AObj.Valor),
     AObj.Ativo, AObj.Observacoes],
    LNulls);

  LogOperacao('PRODUTO_FISCAL', 'U', AObj.Id);
end;

function TProdutoFiscalService.Excluir(AId: Int64): Boolean;
begin
  ValidarId(AId, 'Produto Fiscal');
  Result := FRepo.Excluir(AId);
  LogOperacao('PRODUTO_FISCAL', 'D', AId);
end;

function TProdutoFiscalService.Pesquisar(const ATermo: string): TSQLQuery;
begin
  { CAST + CONTAINING: o termo pode ser maior que NCM (10) e o
    CONTAINING direto estoura com "string right truncation". O CAST
    amplia a coluna para o tamanho do termo. }
  Result := FRepo.BuscarTodosParam(
    'EMPRESA_ID = :EMP AND ' +
    '(UPPER(CAST(DESCRICAO AS VARCHAR(1000))) CONTAINING UPPER(:T) OR ' +
    'UPPER(CAST(CODIGO AS VARCHAR(200))) CONTAINING UPPER(:T) OR ' +
    'UPPER(CAST(NCM AS VARCHAR(200))) CONTAINING UPPER(:T))',
    ['EMP', 'T'],
    [IntToStr(TSessao.GetInstance.EmpresaId), ATermo],
    'DESCRICAO');
end;

end.
