unit uImportacaoXmlMapService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service: mapeamento de produtos do XML importado
  ------------------------------------------------------------
  Marco 3.88. A importacao de XML nunca cria produto sozinha:
  ela grava em IMPORTACAO_XML_ITEM a descricao original, o CNPJ
  do fornecedor, o codigo do produto da nota e a classificacao
  fiscal recebida. Quando nao ha correspondencia exata no
  cadastro, o registro fica PENDENTE e a tela de mapeamento
  deixa o usuario escolher um produto compativel ou cadastrar
  um novo (origem CADASTRO_MANUAL).

  Regras:
    - isolamento por EMPRESA_ID da sessao em todas as consultas;
    - UPSERT por (EMPRESA_ID, CHAVE, CODIGO_PRODUTO_NOTA) permite
      reaproveitar um mapeamento anterior ao reprocessar o XML;
    - toda escrita em transacao explicita, com LogOperacao na
      mesma transacao (vide uServiceBase.LogOperacao).
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uConexao,
  uSessao, uProduto, uProdutoService;

type
  EImportacaoXmlMap = class(Exception);

  { Item importado pronto para exibir na tela de mapeamento. }
  TItemMapaXML = record
    Id: Int64;
    NotaEntradaId: Int64;
    NotaItemId: Int64;
    Chave: string;
    Cnpj: string;
    DescricaoOriginal: string;
    CodigoNota: string;
    Classificacao: string;
    Ncm: string;
    Cfop: string;
    Cst: string;
    Unidade: string;
    ProdutoId: Int64;
    Situacao: string;
  end;

  TImportacaoXmlMapService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    function BuscarExistente(const AChave, ACodigoNota: string): Int64;
  public
    constructor Create;
    destructor Destroy; override;

    { Texto curto e estavel da classificacao fiscal que veio no XML. }
    class function ClassificacaoDoItem(const ANcm, ACfop, ACst,
      ACest: string): string;

    { Grava o rastro do item importado. Se o par (chave, codigo) ja
      existir, atualiza os dados do documento mas preserva o produto
      escolhido e a situacao ja resolvida. }
    function RegistrarItem(const AChave, ATipoDocumento, AProvedor,
      ACnpj, ADescricaoOriginal, ACodigoNota, AClassificacao, ANcm,
      ACfop, ACst, ACest, AUnidade: string; AQuantidade,
      AValorUnitario: Double; ANotaId, ANotaItemId, AProdutoId: Int64;
      const ASituacao: string): Int64;

    { Consultas usadas pela tela de mapeamento. }
    function ListarPendentes(ANotaId: Int64): TSQLQuery;
    function ObterItem(AId: Int64): TItemMapaXML;
    function BuscarCompativeis(const ATermo, ANcm: string): TSQLQuery;
    function PrimeiraCategoriaAtiva: Int64;
    function IdUnidade(const ASigla: string): Int64;

    { Aplica a escolha ao rastro e ao item da nota de entrada.
      AOrigem: 'XML' (correspondencia automatica) ou
               'CADASTRO_MANUAL' (produto novo criado pelo usuario). }
    procedure AplicarMapeamento(AItemMapId, AProdutoId: Int64;
      const AOrigem: string; const ASituacao: string = 'MAPEADO');
    procedure Ignorar(AItemMapId: Int64);

    { Cria produto a partir dos dados do XML e ja aplica o mapeamento. }
    function CriarProdutoDoItem(AItemMapId: Int64;
      APrecoSugerido: Double): Int64;
  end;

implementation

uses
  uAuditoria;

{ ------------------------------------------------------------------
  TImportacaoXmlMapService
  ------------------------------------------------------------------ }

constructor TImportacaoXmlMapService.Create;
begin
  FRepo := TRepositoryBase.Create('IMPORTACAO_XML_ITEM');
  inherited Create(FRepo);
end;

destructor TImportacaoXmlMapService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

class function TImportacaoXmlMapService.ClassificacaoDoItem(const ANcm,
  ACfop, ACst, ACest: string): string;
begin
  Result := '';
  if Trim(ANcm) <> '' then Result := 'NCM ' + Trim(ANcm);
  if Trim(ACfop) <> '' then
  begin
    if Result <> '' then Result := Result + '; ';
    Result := Result + 'CFOP ' + Trim(ACfop);
  end;
  if Trim(ACst) <> '' then
  begin
    if Result <> '' then Result := Result + '; ';
    Result := Result + 'CST ' + Trim(ACst);
  end;
  if Trim(ACest) <> '' then
  begin
    if Result <> '' then Result := Result + '; ';
    Result := Result + 'CEST ' + Trim(ACest);
  end;
end;

function TImportacaoXmlMapService.BuscarExistente(const AChave,
  ACodigoNota: string): Int64;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  if (Trim(AChave) = '') or (Trim(ACodigoNota) = '') then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM IMPORTACAO_XML_ITEM ' +
      'WHERE EMPRESA_ID = :EMP AND CHAVE = :CHAVE AND ' +
      'CODIGO_PRODUTO_NOTA = :COD ORDER BY ID';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('CHAVE').AsString := AChave;
    LQuery.ParamByName('COD').AsString := ACodigoNota;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
  finally
    LQuery.Free;
  end;
end;

function TImportacaoXmlMapService.RegistrarItem(const AChave,
  ATipoDocumento, AProvedor, ACnpj, ADescricaoOriginal, ACodigoNota,
  AClassificacao, ANcm, ACfop, ACst, ACest, AUnidade: string;
  AQuantidade, AValorUnitario: Double; ANotaId, ANotaItemId,
  AProdutoId: Int64; const ASituacao: string): Int64;
var
  LQuery: TSQLQuery;
  LDescricao, LCodigo: string;
begin
  LDescricao := Copy(Trim(ADescricaoOriginal), 1, 250);
  LCodigo := Copy(Trim(ACodigoNota), 1, 60);
  if (LDescricao = '') and (LCodigo = '') then
  begin
    Result := 0;
    Exit;
  end;
  if LCodigo = '' then
    LCodigo := 'SEM_CODIGO_' + IntToStr(ANotaItemId);

  Result := BuscarExistente(AChave, LCodigo);
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    Conexao.IniciarTransacao;
    try
      if Result > 0 then
      begin
        { reprocessamento: mantem o produto e a situacao ja decididos }
        LQuery.Close;
        LQuery.SQL.Text :=
          'UPDATE IMPORTACAO_XML_ITEM SET ' +
          ' NOTA_ENTRADA_ID = :NOTA, NOTA_ITEM_ID = :ITEM, ' +
          ' FORNECEDOR_CNPJ = CASE WHEN :CNPJ = '''' THEN FORNECEDOR_CNPJ ' +
          '   ELSE :CNPJ END, DESCRICAO_ORIGINAL = :DESC, ' +
          ' CODIGO_PRODUTO_NOTA = :COD, ' +
          ' CLASSIFICACAO_FISCAL = :CLASSF, NCM = :NCM, CFOP = :CFOP, ' +
          ' CST_ICMS = :CST, CEST = :CEST, UNIDADE = :UNID, ' +
          ' QUANTIDADE = :QTD, VALOR_UNITARIO = :VLR, ' +
          ' PRODUTO_ID = COALESCE(PRODUTO_ID, :PROD), ' +
          ' SITUACAO = CASE WHEN SITUACAO = ''PENDENTE'' ' +
          '   THEN :SIT ELSE SITUACAO END, ' +
          ' DATA_IMPORTACAO = CURRENT_TIMESTAMP ' +
          'WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := Result;
        if AProdutoId > 0 then
          LQuery.ParamByName('PROD').AsLargeInt := AProdutoId
        else
          LQuery.ParamByName('PROD').Clear;
        LQuery.ParamByName('SIT').AsString := ASituacao;
      end
      else
      begin
        LQuery.Close;
        LQuery.SQL.Text :=
          'INSERT INTO IMPORTACAO_XML_ITEM ' +
          ' (EMPRESA_ID, NOTA_ENTRADA_ID, NOTA_ITEM_ID, CHAVE, ' +
          '  TIPO_DOCUMENTO, PROVEDOR, FORNECEDOR_CNPJ, ' +
          '  DESCRICAO_ORIGINAL, CODIGO_PRODUTO_NOTA, ' +
          '  CLASSIFICACAO_FISCAL, NCM, CFOP, CST_ICMS, CEST, UNIDADE, ' +
          '  QUANTIDADE, VALOR_UNITARIO, PRODUTO_ID, SITUACAO, ' +
          '  USUARIO_ID, DATA_IMPORTACAO) ' +
          'VALUES (:EMP, :NOTA, :ITEM, :CHAVE, :TIPO, :PROVEDOR, :CNPJ, ' +
          '  :DESC, :COD, :CLASSF, :NCM, :CFOP, :CST, :CEST, :UNID, ' +
          '  :QTD, :VLR, :PROD, :SIT, :USR, CURRENT_TIMESTAMP) ' +
          'RETURNING ID';
        LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQuery.ParamByName('CHAVE').AsString := AChave;
        LQuery.ParamByName('TIPO').AsString := Copy(ATipoDocumento, 1, 12);
        LQuery.ParamByName('PROVEDOR').AsString := Copy(AProvedor, 1, 20);
        LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
        if AProdutoId > 0 then
          LQuery.ParamByName('PROD').AsLargeInt := AProdutoId
        else
          LQuery.ParamByName('PROD').Clear;
        LQuery.ParamByName('SIT').AsString := ASituacao;
      end;
      LQuery.ParamByName('NOTA').AsLargeInt := ANotaId;
      LQuery.ParamByName('ITEM').AsLargeInt := ANotaItemId;
      LQuery.ParamByName('CNPJ').AsString := Copy(ACnpj, 1, 14);
      LQuery.ParamByName('DESC').AsString := LDescricao;
      LQuery.ParamByName('COD').AsString := LCodigo;
      LQuery.ParamByName('CLASSF').AsString :=
        Copy(AClassificacao, 1, 80);
      LQuery.ParamByName('NCM').AsString := Copy(ANcm, 1, 8);
      LQuery.ParamByName('CFOP').AsString := Copy(ACfop, 1, 4);
      LQuery.ParamByName('CST').AsString := Copy(ACst, 1, 3);
      LQuery.ParamByName('CEST').AsString := Copy(ACest, 1, 7);
      LQuery.ParamByName('UNID').AsString := Copy(AUnidade, 1, 6);
      LQuery.ParamByName('QTD').AsFloat := AQuantidade;
      LQuery.ParamByName('VLR').AsFloat := AValorUnitario;

      if Result > 0 then
        LQuery.ExecSQL
      else
      begin
        LQuery.Open;
        Result := LQuery.FieldByName('ID').AsLargeInt;
        LQuery.Close;
      end;

      LogOperacao('IMPORTACAO_XML', 'IMPORTACAO_ITEM', Result, '',
        'Chave=' + AChave + '; Codigo=' + LCodigo +
        '; Descricao=' + LDescricao + '; Situacao=' + ASituacao);
      Conexao.Confirmar;
    except
      Conexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TImportacaoXmlMapService.ListarPendentes(ANotaId: Int64): TSQLQuery;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  LQuery.DataBase := Conexao.Connection;
  LQuery.Transaction := Conexao.Transaction;
  LQuery.Close;
  LQuery.SQL.Text :=
    'SELECT ID, NOTA_ENTRADA_ID, NOTA_ITEM_ID, CHAVE, FORNECEDOR_CNPJ, ' +
    ' DESCRICAO_ORIGINAL, CODIGO_PRODUTO_NOTA, CLASSIFICACAO_FISCAL, ' +
    ' NCM, CFOP, CST_ICMS, UNIDADE, QUANTIDADE, VALOR_UNITARIO, ' +
    ' PRODUTO_ID, SITUACAO ' +
    'FROM IMPORTACAO_XML_ITEM WHERE EMPRESA_ID = :EMP ' +
    'AND NOTA_ENTRADA_ID = :NOTA AND SITUACAO = ''PENDENTE'' ' +
    'ORDER BY ID';
  LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  LQuery.ParamByName('NOTA').AsLargeInt := ANotaId;
  LQuery.Open;
  Result := LQuery;
end;

function TImportacaoXmlMapService.ObterItem(AId: Int64): TItemMapaXML;
var
  LQuery: TSQLQuery;
begin
  FillChar(Result, SizeOf(Result), 0);
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ID, NOTA_ENTRADA_ID, NOTA_ITEM_ID, CHAVE, FORNECEDOR_CNPJ, ' +
      ' DESCRICAO_ORIGINAL, CODIGO_PRODUTO_NOTA, CLASSIFICACAO_FISCAL, ' +
      ' NCM, CFOP, CST_ICMS, UNIDADE, PRODUTO_ID, SITUACAO ' +
      'FROM IMPORTACAO_XML_ITEM WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise EImportacaoXmlMap.CreateFmt(
        'Mapeamento %d não encontrado para a empresa atual.', [AId]);
    Result.Id := LQuery.FieldByName('ID').AsLargeInt;
    Result.NotaEntradaId := LQuery.FieldByName('NOTA_ENTRADA_ID').AsLargeInt;
    Result.NotaItemId := LQuery.FieldByName('NOTA_ITEM_ID').AsLargeInt;
    Result.Chave := LQuery.FieldByName('CHAVE').AsString;
    Result.Cnpj := LQuery.FieldByName('FORNECEDOR_CNPJ').AsString;
    Result.DescricaoOriginal := LQuery.FieldByName('DESCRICAO_ORIGINAL').AsString;
    Result.CodigoNota := LQuery.FieldByName('CODIGO_PRODUTO_NOTA').AsString;
    Result.Classificacao := LQuery.FieldByName('CLASSIFICACAO_FISCAL').AsString;
    Result.Ncm := LQuery.FieldByName('NCM').AsString;
    Result.Cfop := LQuery.FieldByName('CFOP').AsString;
    Result.Cst := LQuery.FieldByName('CST_ICMS').AsString;
    Result.Unidade := LQuery.FieldByName('UNIDADE').AsString;
    Result.ProdutoId := LQuery.FieldByName('PRODUTO_ID').AsLargeInt;
    Result.Situacao := LQuery.FieldByName('SITUACAO').AsString;
    LQuery.Close;
  finally
    LQuery.Free;
  end;
end;

function TImportacaoXmlMapService.BuscarCompativeis(const ATermo,
  ANcm: string): TSQLQuery;
var
  LQuery: TSQLQuery;
  LTermo: string;
begin
  LQuery := TSQLQuery.Create(nil);
  LQuery.DataBase := Conexao.Connection;
  LQuery.Transaction := Conexao.Transaction;
  LTermo := UpperCase(Trim(ATermo));
  LQuery.Close;
  LQuery.SQL.Text :=
    'SELECT ID, CODIGO, DESCRICAO, NCM, PRECO_VENDA FROM PRODUTO ' +
    'WHERE EMPRESA_ID = :EMP AND ' +
    '((:TERMO <> '''' AND (UPPER(COALESCE(DESCRICAO, '''')) CONTAINING :TERMO ' +
    '  OR UPPER(COALESCE(CODIGO, '''')) CONTAINING :TERMO)) ' +
    ' OR (:NCM <> '''' AND COALESCE(NCM, '''') = :NCM)) ' +
    'ORDER BY DESCRICAO';
  LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  LQuery.ParamByName('TERMO').AsString := LTermo;
  LQuery.ParamByName('NCM').AsString := Trim(ANcm);
  LQuery.Open;
  Result := LQuery;
end;

function TImportacaoXmlMapService.PrimeiraCategoriaAtiva: Int64;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM CATEGORIA WHERE ATIVO = ''A'' ORDER BY ID';
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
  finally
    LQuery.Free;
  end;
end;

function TImportacaoXmlMapService.IdUnidade(const ASigla: string): Int64;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT FIRST 1 ID FROM UNIDADE WHERE SIGLA = :S';
    LQuery.ParamByName('S').AsString := Trim(ASigla);
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
  finally
    LQuery.Free;
  end;
  if Result = 0 then
  begin
    LQuery := TSQLQuery.Create(nil);
    try
      LQuery.DataBase := Conexao.Connection;
      LQuery.Transaction := Conexao.Transaction;
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT FIRST 1 ID FROM UNIDADE ORDER BY ID';
      LQuery.Open;
      if not LQuery.IsEmpty then
        Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;
    finally
      LQuery.Free;
    end;
  end;
end;

procedure TImportacaoXmlMapService.AplicarMapeamento(AItemMapId,
  AProdutoId: Int64; const AOrigem, ASituacao: string);
var
  LItem: TItemMapaXML;
  LQuery: TSQLQuery;
begin
  if AItemMapId <= 0 then
    raise EImportacaoXmlMap.Create('Item de importação inválido.');
  if AProdutoId <= 0 then
    raise EImportacaoXmlMap.Create('Escolha um produto antes de confirmar.');

  LItem := ObterItem(AItemMapId);
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    Conexao.IniciarTransacao;
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'UPDATE IMPORTACAO_XML_ITEM SET PRODUTO_ID = :PROD, ' +
        ' SITUACAO = :SIT, USUARIO_ID = :USR WHERE ID = :ID ' +
        'AND EMPRESA_ID = :EMP';
      LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
      LQuery.ParamByName('SIT').AsString := ASituacao;
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.ParamByName('ID').AsLargeInt := AItemMapId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ExecSQL;

      if LItem.NotaItemId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text :=
          'UPDATE NOTA_ENTRADA_ITEM SET PRODUTO_ID = :PROD, ' +
          ' NCM = :NCM, CFOP = :CFOP, CST_ICMS = :CST WHERE ID = :ID';
        if AProdutoId > 0 then
          LQuery.ParamByName('PROD').AsLargeInt := AProdutoId
        else
          LQuery.ParamByName('PROD').Clear;
        LQuery.ParamByName('NCM').AsString := LItem.Ncm;
        LQuery.ParamByName('CFOP').AsString := LItem.Cfop;
        LQuery.ParamByName('CST').AsString := LItem.Cst;
        LQuery.ParamByName('ID').AsLargeInt := LItem.NotaItemId;
        LQuery.ExecSQL;
      end;

      LogOperacao('IMPORTACAO_XML', 'MAPEAMENTO_PRODUTO', AItemMapId,
        'Situacao=' + LItem.Situacao + '; Produto=' +
        IntToStr(LItem.ProdutoId),
        'Produto=' + IntToStr(AProdutoId) + '; Origem=' + AOrigem +
        '; CodigoNota=' + LItem.CodigoNota +
        '; Descricao=' + LItem.DescricaoOriginal);
      if LItem.NotaItemId > 0 then
        LogOperacao('NOTA_ENTRADA_ITEM', 'U', LItem.NotaItemId,
          'Produto=' + IntToStr(LItem.ProdutoId),
          'Produto=' + IntToStr(AProdutoId) + '; Origem=' + AOrigem);
      Conexao.Confirmar;
    except
      Conexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TImportacaoXmlMapService.Ignorar(AItemMapId: Int64);
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    Conexao.IniciarTransacao;
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'UPDATE IMPORTACAO_XML_ITEM SET SITUACAO = ''IGNORADO'', ' +
        ' USUARIO_ID = :USR WHERE ID = :ID AND EMPRESA_ID = :EMP';
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.ParamByName('ID').AsLargeInt := AItemMapId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ExecSQL;
      LogOperacao('IMPORTACAO_XML', 'MAPEAMENTO_IGNORADO', AItemMapId, '',
        'Usuario=' + IntToStr(TSessao.GetInstance.UsuarioId));
      Conexao.Confirmar;
    except
      Conexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TImportacaoXmlMapService.CriarProdutoDoItem(AItemMapId: Int64;
  APrecoSugerido: Double): Int64;
var
  LItem: TItemMapaXML;
  LProd: TProduto;
  LService: TProdutoService;
  LCategoria, LUnidade: Int64;
  LCodigo: string;
begin
  LItem := ObterItem(AItemMapId);
  LCategoria := PrimeiraCategoriaAtiva;
  LUnidade := IdUnidade(LItem.Unidade);
  if LCategoria <= 0 then
    raise EImportacaoXmlMap.Create(
      'Cadastre ao menos uma categoria ativa antes de criar o produto.');
  if LUnidade <= 0 then
    raise EImportacaoXmlMap.Create(
      'Cadastre ao menos uma unidade antes de criar o produto.');

  LCodigo := Trim(LItem.CodigoNota);
  if LCodigo = '' then
    LCodigo := 'XML' + IntToStr(LItem.Id);

  LProd := TProduto.Create;
  LService := TProdutoService.Create;
  try
    LProd.EmpresaId := TSessao.GetInstance.EmpresaId;
    LProd.CategoriaId := LCategoria;
    LProd.UnidadeId := LUnidade;
    LProd.Codigo := Copy(LCodigo, 1, 60);
    LProd.CodigoBarras := '';
    LProd.Descricao := Copy(LItem.DescricaoOriginal, 1, 120);
    LProd.DescricaoPDV := Copy(LItem.DescricaoOriginal, 1, 60);
    LProd.Ncm := Copy(LItem.Ncm, 1, 8);
    LProd.CfopCompra := Copy(LItem.Cfop, 1, 4);
    LProd.CstIcms := Copy(LItem.Cst, 1, 3);
    if APrecoSugerido <= 0 then
      APrecoSugerido := 1;
    LProd.PrecoCusto := APrecoSugerido;
    LProd.PrecoVenda := APrecoSugerido;
    LProd.Ativo := 'A';
    LProd.ControlaEstoque := True;
    Result := LService.Inserir(LProd);
  finally
    LService.Free;
    LProd.Free;
  end;

  AplicarMapeamento(AItemMapId, Result, 'CADASTRO_MANUAL', 'NOVO');
end;

end.
