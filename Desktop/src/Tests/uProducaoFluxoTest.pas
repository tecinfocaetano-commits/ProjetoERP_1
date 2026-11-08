unit uProducaoFluxoTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes do FLUXO de Producao (Fase 8)
  ------------------------------------------------------------
  O uProducaoTest cobre estrutura/permissoes/auditoria; este arquivo
  cobre as regras de negocio do TProducaoService com banco real:

    - FichaTecnicaDoProduto / GravarFichaTecnica (upsert, itens
      substituidos, validacoes);
    - CriarMapa (status do pedido, quantidade pendente, parcial,
      item de outro pedido, empresa herdada do pedido);
    - GerarTaloes (modos ITEM/UNIDADE, codigo de barras, status);
    - BiparTalao (INICIO -> CONCLUSAO, duplicado, invalido,
      mapa/pedido concluidos);
    - CancelarMapa / CancelarTalao;
    - GerarConsumoMaterial / ConfirmarConsumo / EstornarConsumo
      (base produzido x planejado, ficha obrigatoria, saldo,
      movimentos 'S'/'E' no estoque).

  Dados com sufixo de timestamp; a limpeza apaga somente os IDs
  criados por este arquivo (nunca DELETE geral por empresa).
  ============================================================ }

interface

uses
  Classes, SysUtils, DB, SQLDB, uAssert, uConexao, uSessao,
  uProducaoService;

type
  TProducaoFluxoTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

class procedure TProducaoFluxoTest.RunAllTests(ASuite: TTestSuite);
type
  TInt64s = array of Int64;
var
  LConexao: TConexao;
  LSessao: TSessao;
  LService: TProducaoService;
  LQuery: TSQLQuery;
  LSufixo: string;
  LSeq: Integer;
  LLogAntes: Int64;
  LPessoas: TInt64s;
  LProdutos: TInt64s;
  LPedidos: TInt64s;
  LMapas: TInt64s;
  LCliente: Int64;

  function QuaseIgual(A, B: Double): Boolean;
  begin
    Result := Abs(A - B) < 0.001;
  end;

  function NovoNome(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + ' ' + LSufixo + '-' + IntToStr(LSeq);
  end;

  function NovoCodigo(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + Copy(LSufixo, 1, 8) + IntToStr(LSeq);
  end;

  procedure RegistrarId(var AIds: TInt64s; AId: Int64);
  var
    LLen: Integer;
  begin
    LLen := Length(AIds);
    SetLength(AIds, LLen + 1);
    AIds[LLen] := AId;
  end;

  function IdsParaIn(const AIds: TInt64s): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 0 to High(AIds) do
    begin
      if I > 0 then
        Result := Result + ',';
      Result := Result + IntToStr(AIds[I]);
    end;
  end;

  // ------------------------------------------------------------------
  // Fixtures
  // ------------------------------------------------------------------

  function CriarPessoa(const ANome, ATipo: string;
    AEmpresaId: Int64): Int64;
  var
    LDoc: string;
  begin
    Inc(LSeq);
    LDoc := Copy(LSufixo, 1, 14) + IntToStr(LSeq);
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PESSOA (EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, CPF_CNPJ, ' +
      '  ATIVO, DATA_CADASTRO) ' +
      'VALUES (:EMP, :TIPO, ''F'', :NOME, :DOC, ''A'', CURRENT_TIMESTAMP) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.ParamByName('NOME').AsString := ANome;
    LQuery.ParamByName('DOC').AsString := LDoc;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
    RegistrarId(LPessoas, Result);
  end;

  function CriarProduto(const ACodigo, ADescricao: string;
    APrecoCusto, APrecoVenda: Double;
    AEmpresaId: Int64): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PRODUTO (EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, ' +
      '  DESCRICAO, PRECO_CUSTO, PRECO_VENDA, CONTROLA_ESTOQUE, ATIVO) ' +
      'VALUES (:EMP, 1, 1, :COD, :DESC, :PCUSTO, :PVENDA, ''S'', ''A'') ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('COD').AsString := ACodigo;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('PCUSTO').AsFloat := APrecoCusto;
    LQuery.ParamByName('PVENDA').AsFloat := APrecoVenda;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
    RegistrarId(LProdutos, Result);
  end;

  procedure DefinirEstoque(AProdutoId: Int64; AQuantidade: Double);
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM ESTOQUE WHERE PRODUTO_ID = :PROD';
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    if LQuery.IsEmpty then
    begin
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO ESTOQUE (EMPRESA_ID, PRODUTO_ID, QUANTIDADE) ' +
        'VALUES (:EMP, :PROD, :QTD)';
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
      LQuery.ParamByName('QTD').AsFloat := AQuantidade;
      LQuery.ExecSQL;
    end
    else
    begin
      LQuery.Close;
      LQuery.SQL.Text :=
        'UPDATE ESTOQUE SET QUANTIDADE = :QTD WHERE PRODUTO_ID = :PROD';
      LQuery.ParamByName('QTD').AsFloat := AQuantidade;
      LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
      LQuery.ExecSQL;
    end;
    LConexao.Confirmar;
  end;

  function SaldoEstoque(AProdutoId: Int64): Double;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(E.QUANTIDADE, 0) AS DOUBLE PRECISION) AS SALDO ' +
      'FROM PRODUTO P LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
      'WHERE P.ID = :PROD';
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('SALDO').AsFloat;
    LQuery.Close;
  end;

  function CriarPedido(AClienteId: Int64; const AStatus: string;
    AEmpresaId: Int64): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, CLIENTE_ID, USUARIO_ID, ' +
      '  NUMERO, STATUS, SUBTOTAL, DESCONTO, TOTAL) ' +
      'VALUES (:EMP, :CLI, :USR, :NUM, :ST, 0, 0, 0) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('CLI').AsLargeInt := AClienteId;
    LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
    Inc(LSeq);
    LQuery.ParamByName('NUM').AsString := 'PF' + Copy(LSufixo, 1, 10) +
      IntToStr(LSeq);
    LQuery.ParamByName('ST').AsString := AStatus;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
    RegistrarId(LPedidos, Result);
  end;

  function AdicionarItem(APedidoId, AProdutoId: Int64;
    AQtd, AValor: Double): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO ITEM_PEDIDO (PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE, ' +
      '  PRECO_UNITARIO, VALOR_UNITARIO, DESCONTO, VALOR_TOTAL, CFOP) ' +
      'VALUES (:PED, :PROD, :QTD, :VLR, :VLR, 0, :TOT, ''5102'') ' +
      'RETURNING ID';
    LQuery.ParamByName('PED').AsLargeInt := APedidoId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.ParamByName('QTD').AsFloat := AQtd;
    LQuery.ParamByName('VLR').AsFloat := AValor;
    LQuery.ParamByName('TOT').AsFloat := AQtd * AValor;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  // ------------------------------------------------------------------
  // Leituras auxiliares
  // ------------------------------------------------------------------

  function CampoTexto(const ATabela, ACampo: string; AId: Int64): string;
  begin
    Result := '';
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(' + ACampo + ' AS VARCHAR(100)) AS VALOR FROM ' +
      ATabela + ' WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
    LQuery.Close;
  end;

  function CampoInteiro(const ATabela, ACampo: string; AId: Int64): Int64;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM ' + ATabela + ' WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsLargeInt;
    LQuery.Close;
  end;

  function IdItemDoMapa(AMapaId: Int64): Int64;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM MAPA_PRODUCAO_ITEM ' +
      'WHERE MAPA_PRODUCAO_ID = :MAPA ORDER BY ID';
    LQuery.ParamByName('MAPA').AsLargeInt := AMapaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
  end;

  function IdTalaoDoItem(AItemMapaId: Int64; out ACodigo: string;
    out ANumero: Integer; out AQuantidade: Double): Int64;
  begin
    Result := 0;
    ACodigo := '';
    ANumero := 0;
    AQuantidade := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID, CODIGO_BARRAS, NUMERO, QUANTIDADE FROM TALAO ' +
      'WHERE MAPA_PRODUCAO_ITEM_ID = :ITEM ORDER BY ID';
    LQuery.ParamByName('ITEM').AsLargeInt := AItemMapaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      Result := LQuery.FieldByName('ID').AsLargeInt;
      ACodigo := Trim(LQuery.FieldByName('CODIGO_BARRAS').AsString);
      ANumero := LQuery.FieldByName('NUMERO').AsInteger;
      AQuantidade := LQuery.FieldByName('QUANTIDADE').AsFloat;
    end;
    LQuery.Close;
  end;

  function IdItemConsumo(AConsumoId: Int64): Int64;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM CONSUMO_MATERIAL_ITEM ' +
      'WHERE CONSUMO_MATERIAL_ID = :CONS ORDER BY ID';
    LQuery.ParamByName('CONS').AsLargeInt := AConsumoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
  end;

  function QtdPrevistaConsumo(AItemId: Int64): Double;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(QTD_PREVISTA AS DOUBLE PRECISION) AS VALOR ' +
      'FROM CONSUMO_MATERIAL_ITEM WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AItemId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function QtdRealConsumo(AItemId: Int64): Double;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(QTD_REAL AS DOUBLE PRECISION) AS VALOR ' +
      'FROM CONSUMO_MATERIAL_ITEM WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AItemId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function ContarConsumos(AMapaId: Int64): Integer;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM CONSUMO_MATERIAL WHERE MAPA_PRODUCAO_ID = :MAPA';
    LQuery.ParamByName('MAPA').AsLargeInt := AMapaId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function ContaMovimento(AProdutoId: Int64; const ATipo,
    ADocumento: string): Integer;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM MOVIMENTO_ESTOQUE WHERE PRODUTO_ID = :PROD ' +
      'AND TIPO = :TIPO AND DOCUMENTO CONTAINING :DOC';
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.ParamByName('DOC').AsString := ADocumento;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  // ------------------------------------------------------------------
  // "Deve falhar" helpers
  // ------------------------------------------------------------------

  function FichaFalhou(AProdutoId: Int64; ABase: Double;
    const AItens: TItensFichaTecnica): Boolean;
  begin
    Result := False;
    try
      LService.GravarFichaTecnica(AProdutoId, 'X', ABase, AItens);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function MapaFalhou(APedidoId: Int64; AItemPedidoId: Int64;
    AQtd: Double): Boolean;
  var
    LItens: TItensMapa;
  begin
    Result := False;
    SetLength(LItens, 1);
    LItens[0].ItemPedidoId := AItemPedidoId;
    LItens[0].ProdutoId := 0;
    LItens[0].Quantidade := AQtd;
    try
      LService.CriarMapa(APedidoId, LItens, '', 0);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function TaloesFalhou(AItemMapaId: Int64; const AModo: string): Boolean;
  var
    LGerados: Integer;
  begin
    Result := False;
    try
      LService.GerarTaloes(AItemMapaId, AModo, LGerados);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function ConsumoGeradoFalhou(AMapaId: Int64; APlanejado: Boolean): Boolean;
  begin
    Result := False;
    try
      LService.GerarConsumoMaterial(AMapaId, 'TESTE', APlanejado);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function ConfirmarFalhou(AConsumoId: Int64;
    const AItens: TItensConsumoConfirmar): Boolean;
  begin
    Result := False;
    try
      LService.ConfirmarConsumo(AConsumoId, AItens);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function EstornoFalhou(AConsumoId: Int64; const AMotivo: string): Boolean;
  begin
    Result := False;
    try
      LService.EstornarConsumo(AConsumoId, AMotivo);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function CancelarMapaFalhou(AMapaId: Int64; const AMotivo: string): Boolean;
  begin
    Result := False;
    try
      LService.CancelarMapa(AMapaId, AMotivo);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function CancelarTalaoFalhou(ATalaoId: Int64; const AMotivo: string): Boolean;
  begin
    Result := False;
    try
      LService.CancelarTalao(ATalaoId, AMotivo);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  // ------------------------------------------------------------------
  // Cenarios compostos
  // ------------------------------------------------------------------

  { Monta: produto acabado com ficha (base 1: 3un material +10% perda),
    material com 100 un de estoque, pedido de 2 un, mapa e — quando
    AComProducao — talão bipado duas vezes (mapa CONCLUIDO). }
  procedure MontarCenarioConsumo(out AMapaId: Int64;
    out ALProdAcabado: Int64; out ALMaterial: Int64;
    AComProducao: Boolean);
  var
    LPed, LItem, LItemMapa, LTalaoId: Int64;
    LItens: TItensMapa;
    LItensFicha: TItensFichaTecnica;
    LGerados: Integer;
    LBip: TBipagemTalao;
    LCodigo: string;
    LAQt: Double;
    LNumero: Integer;
  begin
    ALProdAcabado := CriarProduto(NovoCodigo('CPD'),
      NovoNome('PROD ACABADO'), 20, 50, LSessao.EmpresaId);
    ALMaterial := CriarProduto(NovoCodigo('CPM'),
      NovoNome('MATERIAL CONS'), 2, 4, LSessao.EmpresaId);
    DefinirEstoque(ALMaterial, 100);

    SetLength(LItensFicha, 1);
    LItensFicha[0].MaterialId := ALMaterial;
    LItensFicha[0].Quantidade := 3;
    LItensFicha[0].PerdaPercentual := 10;
    LService.GravarFichaTecnica(ALProdAcabado, 'FICHA ' + LSufixo,
      1, LItensFicha);

    LPed := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
    LItem := AdicionarItem(LPed, ALProdAcabado, 2, 50);
    SetLength(LItens, 1);
    LItens[0].ItemPedidoId := LItem;
    LItens[0].ProdutoId := ALProdAcabado;
    LItens[0].Quantidade := 2;
    AMapaId := LService.CriarMapa(LPed, LItens, '', 0);
    RegistrarId(LMapas, AMapaId);
    LItemMapa := IdItemDoMapa(AMapaId);

    if AComProducao then
    begin
      LGerados := 0;
      LService.GerarTaloes(LItemMapa, 'ITEM', LGerados);
      LTalaoId := IdTalaoDoItem(LItemMapa, LCodigo, LNumero, LAQt);
      LBip := LService.BiparTalao(LCodigo, 'MANUAL');  { INICIO }
      LBip := LService.BiparTalao(LCodigo, 'MANUAL');  { CONCLUSAO }
    end;
  end;

  // ------------------------------------------------------------------
  // Testes
  // ------------------------------------------------------------------

  procedure TestFichaValidacoes;
  var
    LProd, LMat, LMat2: Int64;
    LItens, LItensDup: TItensFichaTecnica;
  begin
    try
      LProd := CriarProduto(NovoCodigo('FPF'), NovoNome('PROD FICHA'),
        5, 10, LSessao.EmpresaId);
      LMat := CriarProduto(NovoCodigo('FPM'), NovoNome('MAT FICHA'),
        1, 2, LSessao.EmpresaId);
      LMat2 := CriarProduto(NovoCodigo('FPM'), NovoNome('MAT FICHA 2'),
        1, 2, LSessao.EmpresaId);

      SetLength(LItens, 1);
      LItens[0].MaterialId := LMat;
      LItens[0].Quantidade := 1;
      LItens[0].PerdaPercentual := 0;

      AssertTrue(FichaFalhou(0, 1, LItens), 'produto invalido deve falhar');
      AssertTrue(FichaFalhou(LProd, 0, LItens), 'base zero deve falhar');
      AssertTrue(FichaFalhou(LProd, 1, nil),
        'ficha sem itens deve falhar');

      LItens[0].MaterialId := LProd;
      AssertTrue(FichaFalhou(LProd, 1, LItens),
        'produto nao pode ser material da propria ficha');
      LItens[0].MaterialId := LMat;

      LItens[0].Quantidade := 0;
      AssertTrue(FichaFalhou(LProd, 1, LItens),
        'quantidade zero deve falhar');
      LItens[0].Quantidade := 1;
      LItens[0].PerdaPercentual := -1;
      AssertTrue(FichaFalhou(LProd, 1, LItens),
        'perda negativa deve falhar');
      LItens[0].PerdaPercentual := 0;

      SetLength(LItensDup, 2);
      LItensDup[0] := LItens[0];
      LItensDup[1] := LItens[0];
      AssertTrue(FichaFalhou(LProd, 1, LItensDup),
        'material duplicado deve falhar');
      SetLength(LItensDup, 2);
      LItensDup[0] := LItens[0];
      LItensDup[1].MaterialId := LMat2;
      LItensDup[1].Quantidade := 2;
      LItensDup[1].PerdaPercentual := 10;
      AssertFalse(FichaFalhou(LProd, 1, LItensDup),
        'dois materiais distintos devem passar');

      ASuite.AddResult('TestFichaValidacoes', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestFichaValidacoes', False, E.Message);
    end;
  end;

  procedure TestFichaGravarELer;
  var
    LProd, LMat, LMat2, LFicha, LFicha2: Int64;
    LItens, LItens2, LItensLidos: TItensFichaTecnica;
    LDesc, LDesc2: string;
    LBase: Double;
    LProdSemFicha: Int64;
  begin
    try
      LProd := CriarProduto(NovoCodigo('FPG'),
        NovoNome('PROD FICHA GRAVAR'), 5, 10, LSessao.EmpresaId);
      LMat := CriarProduto(NovoCodigo('FPG'), NovoNome('MAT FICHA A'),
        1, 2, LSessao.EmpresaId);
      LMat2 := CriarProduto(NovoCodigo('FPG'), NovoNome('MAT FICHA B'),
        1, 2, LSessao.EmpresaId);
      LProdSemFicha := CriarProduto(NovoCodigo('FPG'),
        NovoNome('PROD SEM FICHA'), 5, 10, LSessao.EmpresaId);

      SetLength(LItens, 2);
      LItens[0].MaterialId := LMat;
      LItens[0].Quantidade := 2;
      LItens[0].PerdaPercentual := 5;
      LItens[1].MaterialId := LMat2;
      LItens[1].Quantidade := 1;
      LItens[1].PerdaPercentual := 0;

      LFicha := LService.GravarFichaTecnica(LProd,
        'FICHA ' + LSufixo, 10, LItens);
      AssertTrue(LFicha > 0, 'GravarFichaTecnica deve devolver o ID');

      LItensLidos := LService.FichaTecnicaDoProduto(LProd, LDesc, LBase);
      AssertEquals('FICHA ' + LSufixo, LDesc, 'descricao da ficha');
      AssertTrue(QuaseIgual(10, LBase), 'quantidade base');
      AssertEquals('2', IntToStr(Length(LItensLidos)),
        'dois itens de material');
      AssertTrue(
        ((LItensLidos[0].MaterialId = LMat) and
         QuaseIgual(2, LItensLidos[0].Quantidade) and
         QuaseIgual(5, LItensLidos[0].PerdaPercentual)) or
        ((LItensLidos[1].MaterialId = LMat) and
         QuaseIgual(2, LItensLidos[1].Quantidade) and
         QuaseIgual(5, LItensLidos[1].PerdaPercentual)),
        'primeiro material gravado com qtd/perda');

      { upsert: mesma ficha, itens substituidos por completo }
      SetLength(LItens2, 1);
      LItens2[0].MaterialId := LMat2;
      LItens2[0].Quantidade := 4;
      LItens2[0].PerdaPercentual := 2;
      LFicha2 := LService.GravarFichaTecnica(LProd, 'FICHA NOVA', 5, LItens2);
      AssertEquals(IntToStr(LFicha), IntToStr(LFicha2),
        'upsert deve manter o mesmo ID de ficha');

      LItensLidos := LService.FichaTecnicaDoProduto(LProd, LDesc2, LBase);
      AssertEquals('FICHA NOVA', LDesc2, 'descricao atualizada');
      AssertTrue(QuaseIgual(5, LBase), 'base atualizada');
      AssertEquals('1', IntToStr(Length(LItensLidos)),
        'itens antigos substituidos');
      AssertTrue((LItensLidos[0].MaterialId = LMat2) and
        QuaseIgual(4, LItensLidos[0].Quantidade), 'novo item gravado');

      LItensLidos := LService.FichaTecnicaDoProduto(LProdSemFicha,
        LDesc2, LBase);
      AssertEquals('0', IntToStr(Length(LItensLidos)),
        'produto sem ficha deve devolver lista vazia');

      ASuite.AddResult('TestFichaGravarELer', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestFichaGravarELer', False, E.Message);
    end;
  end;

  procedure TestMapaValidacoes;
  var
    LPedCancel, LPed, LPed2, LItem, LItem2, LProd: Int64;
  begin
    try
      LProd := CriarProduto(NovoCodigo('MPV'), NovoNome('PROD MAPA VAL'),
        5, 10, LSessao.EmpresaId);

      LPedCancel := CriarPedido(LCliente, 'C', LSessao.EmpresaId);
      LItem := AdicionarItem(LPedCancel, LProd, 5, 10);
      AssertTrue(MapaFalhou(LPedCancel, LItem, 1),
        'pedido cancelado nao pode gerar mapa');

      LPed := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
      LItem := AdicionarItem(LPed, LProd, 10, 10);

      AssertTrue(MapaFalhou(LPed, 999999999, 1),
        'item inexistente deve falhar');
      AssertTrue(MapaFalhou(LPed, LItem, 0),
        'quantidade zero deve falhar');
      AssertTrue(MapaFalhou(LPed, LItem, 11),
        'quantidade acima do pendente deve falhar');

      LPed2 := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
      LItem2 := AdicionarItem(LPed2, LProd, 3, 10);
      AssertTrue(MapaFalhou(LPed, LItem2, 1),
        'item de outro pedido deve falhar');

      ASuite.AddResult('TestMapaValidacoes', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestMapaValidacoes', False, E.Message);
    end;
  end;

  procedure TestMapaCriarParciais;
  var
    LPed, LItem, LMapa1, LMapa2, LItemMapa, LProd: Int64;
    LItens: TItensMapa;
    LProduzido, LEmProducao, LTotal: Double;
  begin
    try
      LProd := CriarProduto(NovoCodigo('MPC'), NovoNome('PROD MAPA PARC'),
        5, 10, LSessao.EmpresaId);
      LPed := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
      LItem := AdicionarItem(LPed, LProd, 10, 10);

      SetLength(LItens, 1);
      LItens[0].ItemPedidoId := LItem;
      LItens[0].ProdutoId := LProd;
      LItens[0].Quantidade := 4;
      LMapa1 := LService.CriarMapa(LPed, LItens, 'MAPA TESTE', 0);
      AssertTrue(LMapa1 > 0, 'CriarMapa deve devolver o ID');
      RegistrarId(LMapas, LMapa1);

      AssertEquals('ABERTO', CampoTexto('MAPA_PRODUCAO', 'STATUS', LMapa1),
        'mapa novo deve estar ABERTO');
      AssertTrue(QuaseIgual(4, LService.QuantidadeMapeadaDoItem(LItem)),
        'quantidade mapeada = 4');
      AssertTrue(QuaseIgual(6, LService.QuantidadePendenteDoItem(LItem)),
        'pendente = 6');
      AssertEquals('E', CampoTexto('PEDIDO_VENDA', 'STATUS', LPed),
        'pedido deve ir para EM_PRODUCAO');
      AssertTrue(LService.ProgressoMapa(LMapa1, LProduzido,
        LEmProducao, LTotal), 'ProgressoMapa deve responder');
      AssertTrue(QuaseIgual(4, LTotal) and QuaseIgual(0, LProduzido),
        'progresso: total 4, produzido 0');

      LItemMapa := IdItemDoMapa(LMapa1);
      AssertTrue(LItemMapa > 0, 'item do mapa gravado');
      AssertEquals('PENDENTE',
        CampoTexto('MAPA_PRODUCAO_ITEM', 'STATUS', LItemMapa),
        'item do mapa nasce PENDENTE');

      { segunda parcial: 7 > pendente 6 deve falhar; 6 deve passar }
      LItens[0].Quantidade := 7;
      AssertTrue(MapaFalhou(LPed, LItem, 7),
        'segundo mapa acima do pendente deve falhar');
      LItens[0].Quantidade := 6;
      LMapa2 := LService.CriarMapa(LPed, LItens, '', 0);
      AssertTrue(LMapa2 > 0, 'segundo mapa parcial deve ser criado');
      RegistrarId(LMapas, LMapa2);
      AssertTrue(QuaseIgual(0, LService.QuantidadePendenteDoItem(LItem)),
        'pendente deve zerar');

      ASuite.AddResult('TestMapaCriarParciais', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestMapaCriarParciais', False, E.Message);
    end;
  end;

  procedure TestMapaEscopoEmpresa;
  var
    LPed, LItem, LMapa, LProdOutra, LClienteOutra: Int64;
    LItens: TItensMapa;
  begin
    try
      { pedido de OUTRA empresa: o mapa herda a empresa do pedido }
      LClienteOutra := CriarPessoa(NovoNome('CLI OUTRA'), 'C', 999999);
      LProdOutra := CriarProduto(NovoCodigo('MPE'),
        NovoNome('PROD OUTRA EMP'), 5, 10, 999999);
      LPed := CriarPedido(LClienteOutra, 'P', 999999);
      LItem := AdicionarItem(LPed, LProdOutra, 2, 10);

      SetLength(LItens, 1);
      LItens[0].ItemPedidoId := LItem;
      LItens[0].ProdutoId := LProdOutra;
      LItens[0].Quantidade := 2;
      LMapa := LService.CriarMapa(LPed, LItens, '', 0);
      AssertTrue(LMapa > 0, 'mapa de outra empresa deve ser criado');
      RegistrarId(LMapas, LMapa);
      AssertEquals('999999',
        IntToStr(CampoInteiro('MAPA_PRODUCAO', 'EMPRESA_ID', LMapa)),
        'mapa deve herdar EMPRESA_ID do pedido');

      ASuite.AddResult('TestMapaEscopoEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestMapaEscopoEmpresa', False, E.Message);
    end;
  end;

  procedure TestTaloesGerar;
  var
    LPed, LItem, LMapa, LItemMapa, LTalaoId, LProd: Int64;
    LItem2, LMapa2, LItemMapa2: Int64;
    LItens: TItensMapa;
    LCodigo: string;
    LAQt: Double;
    LNumero: Integer;
    LGerados, LGerados2: Integer;
  begin
    try
      LProd := CriarProduto(NovoCodigo('TAL'), NovoNome('PROD TALAO'),
        5, 10, LSessao.EmpresaId);
      LPed := CriarPedido(LCliente, 'P', LSessao.EmpresaId);

      { --- modo ITEM: um talão com toda a quantidade ------------ }
      LItem := AdicionarItem(LPed, LProd, 3, 10);
      SetLength(LItens, 1);
      LItens[0].ItemPedidoId := LItem;
      LItens[0].ProdutoId := LProd;
      LItens[0].Quantidade := 3;
      LMapa := LService.CriarMapa(LPed, LItens, '', 0);
      RegistrarId(LMapas, LMapa);
      LItemMapa := IdItemDoMapa(LMapa);

      LGerados := 0;
      LService.GerarTaloes(LItemMapa, 'ITEM', LGerados);
      AssertEquals('1', IntToStr(LGerados), 'modo ITEM gera 1 talão');
      LTalaoId := IdTalaoDoItem(LItemMapa, LCodigo, LNumero, LAQt);
      AssertTrue(LTalaoId > 0, 'talão gravado');
      AssertTrue(QuaseIgual(3, LAQt), 'talão ITEM com a quantidade toda');
      AssertEquals('T' + Copy(Format('%.6d', [LNumero]), 1, 7),
        LCodigo, 'codigo = T + numero com 6 digitos');
      AssertEquals('GERADO', CampoTexto('TALAO', 'STATUS', LTalaoId),
        'talão nasce GERADO');
      AssertEquals('EM_PRODUCAO',
        CampoTexto('MAPA_PRODUCAO_ITEM', 'STATUS', LItemMapa),
        'item vai para EM_PRODUCAO');
      AssertEquals('EM_PRODUCAO',
        CampoTexto('MAPA_PRODUCAO', 'STATUS', LMapa),
        'mapa vai para EM_PRODUCAO');

      { gerar de novo sem saldo de talões deve falhar }
      AssertTrue(TaloesFalhou(LItemMapa, 'ITEM'),
        'item totalmente taloado nao aceita novos talões');
      AssertTrue(TaloesFalhou(LItemMapa, 'XXXX'),
        'modo invalido deve falhar');

      { --- modo UNIDADE: 1 talão por unidade -------------------- }
      LItem2 := AdicionarItem(LPed, LProd, 3, 10);
      LItens[0].ItemPedidoId := LItem2;
      LMapa2 := LService.CriarMapa(LPed, LItens, '', 0);
      AssertTrue(LMapa2 > 0, 'segundo mapa parcial criado');
      RegistrarId(LMapas, LMapa2);
      LItemMapa2 := IdItemDoMapa(LMapa2);
      LGerados2 := 0;
      LService.GerarTaloes(LItemMapa2, 'UNIDADE', LGerados2);
      AssertEquals('3', IntToStr(LGerados2), 'modo UNIDADE gera 3 talões');

      ASuite.AddResult('TestTaloesGerar', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestTaloesGerar', False, E.Message);
    end;
  end;

  procedure TestBiparFluxoCompleto;
  var
    LPed, LItem, LMapa, LItemMapa, LTalaoId, LProd: Int64;
    LItens: TItensMapa;
    LCodigo: string;
    LAQt: Double;
    LNumero: Integer;
    LGerados: Integer;
    LBip: TBipagemTalao;
    LProduzido, LEmProducao, LTotal: Double;
  begin
    try
      LProd := CriarProduto(NovoCodigo('BIP'), NovoNome('PROD BIPAGEM'),
        5, 10, LSessao.EmpresaId);
      LPed := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
      LItem := AdicionarItem(LPed, LProd, 2, 10);
      SetLength(LItens, 1);
      LItens[0].ItemPedidoId := LItem;
      LItens[0].ProdutoId := LProd;
      LItens[0].Quantidade := 2;
      LMapa := LService.CriarMapa(LPed, LItens, '', 0);
      RegistrarId(LMapas, LMapa);
      LItemMapa := IdItemDoMapa(LMapa);
      LGerados := 0;
      LService.GerarTaloes(LItemMapa, 'ITEM', LGerados);
      LTalaoId := IdTalaoDoItem(LItemMapa, LCodigo, LNumero, LAQt);
      AssertTrue(LTalaoId > 0, 'talão gerado para o teste');

      { 1a bipagem: INICIO }
      LBip := LService.BiparTalao(LCodigo, 'MANUAL');
      AssertEquals('OK', LBip.Resultado, 'primeira bipagem OK');
      AssertEquals('INICIO', LBip.Etapa, 'etapa INICIO');
      AssertEquals('EM_PRODUCAO', LBip.StatusNovo, 'talão EM_PRODUCAO');
      AssertFalse(LBip.MapaConcluido, 'mapa ainda não concluiu');

      { 2a bipagem: CONCLUSAO e mapa inteiro conclui }
      LBip := LService.BiparTalao(LCodigo, 'MANUAL');
      AssertEquals('OK', LBip.Resultado, 'segunda bipagem OK');
      AssertEquals('CONCLUSAO', LBip.Etapa, 'etapa CONCLUSAO');
      AssertEquals('CONCLUIDO', LBip.StatusNovo, 'talão CONCLUIDO');
      AssertTrue(LBip.MapaConcluido, 'mapa deve concluir no último talão');
      AssertEquals('CONCLUIDO',
        CampoTexto('MAPA_PRODUCAO', 'STATUS', LMapa), 'mapa CONCLUIDO');
      AssertEquals('D', CampoTexto('PEDIDO_VENDA', 'STATUS', LPed),
        'pedido deve virar Produzido');

      { 3a bipagem: duplicado }
      LBip := LService.BiparTalao(LCodigo, 'MANUAL');
      AssertEquals('DUPLICADO', LBip.Resultado,
        're-bipar concluído = DUPLICADO');

      { código inexistente e vazio: INVALIDO }
      LBip := LService.BiparTalao('T999999', 'MANUAL');
      AssertEquals('INVALIDO', LBip.Resultado,
        'código inexistente INVALIDO');
      LBip := LService.BiparTalao('', 'MANUAL');
      AssertEquals('INVALIDO', LBip.Resultado, 'código vazio INVALIDO');

      AssertTrue(LService.ProgressoMapa(LMapa, LProduzido,
        LEmProducao, LTotal), 'progresso após conclusão');
      AssertTrue(QuaseIgual(2, LProduzido) and QuaseIgual(2, LTotal),
        'produzido = total = 2');

      ASuite.AddResult('TestBiparFluxoCompleto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestBiparFluxoCompleto', False, E.Message);
    end;
  end;

  procedure TestCancelarMapaETalao;
  var
    LPed, LPed2, LItem, LItem2, LMapa, LItemMapa, LTalaoId, LProd: Int64;
    LItens: TItensMapa;
    LCodigo: string;
    LAQt: Double;
    LNumero: Integer;
    LGerados: Integer;
    LBip: TBipagemTalao;
  begin
    try
      LProd := CriarProduto(NovoCodigo('CNC'), NovoNome('PROD CANCELA'),
        5, 10, LSessao.EmpresaId);
      LPed := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
      LItem := AdicionarItem(LPed, LProd, 4, 10);
      SetLength(LItens, 1);
      LItens[0].ItemPedidoId := LItem;
      LItens[0].ProdutoId := LProd;
      LItens[0].Quantidade := 4;
      LMapa := LService.CriarMapa(LPed, LItens, '', 0);
      RegistrarId(LMapas, LMapa);

      { motivo vazio deve falhar antes de tocar no mapa }
      AssertTrue(CancelarMapaFalhou(LMapa, ''),
        'cancelar sem motivo deve falhar');

      { mapa sem talões concluídos cancela normal }
      LService.CancelarMapa(LMapa, 'TESTE CANCELA');
      AssertEquals('CANCELADO',
        CampoTexto('MAPA_PRODUCAO', 'STATUS', LMapa), 'mapa CANCELADO');
      AssertEquals('CANCELADO',
        CampoTexto('MAPA_PRODUCAO_ITEM', 'STATUS', IdItemDoMapa(LMapa)),
        'item do mapa CANCELADO');
      AssertEquals('P', CampoTexto('PEDIDO_VENDA', 'STATUS', LPed),
        'pedido volta a PENDENTE');
      AssertTrue(CancelarMapaFalhou(LMapa, 'de novo'),
        'cancelar mapa já cancelado deve falhar');

      { mapa com talão CONCLUIDO não pode ser cancelado (outro pedido:
        este já tem um mapa concluído em outro cenario? nao - usa novo) }
      LPed2 := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
      LItem2 := AdicionarItem(LPed2, LProd, 4, 10);
      LItens[0].ItemPedidoId := LItem2;
      LMapa := LService.CriarMapa(LPed2, LItens, '', 0);
      AssertTrue(LMapa > 0, 'mapa com talão para teste de cancelamento');
      RegistrarId(LMapas, LMapa);
      LItemMapa := IdItemDoMapa(LMapa);
      LGerados := 0;
      LService.GerarTaloes(LItemMapa, 'ITEM', LGerados);
      LTalaoId := IdTalaoDoItem(LItemMapa, LCodigo, LNumero, LAQt);
      LBip := LService.BiparTalao(LCodigo, 'MANUAL');  { INICIO }
      LBip := LService.BiparTalao(LCodigo, 'MANUAL');  { CONCLUSAO }
      AssertEquals('CONCLUIDO', CampoTexto('TALAO', 'STATUS', LTalaoId),
        'talão concluído para o teste');
      AssertTrue(CancelarMapaFalhou(LMapa, 'tarde demais'),
        'mapa com talão concluído não pode ser cancelado');

      { talão GERADO cancela; já cancelado não (novo pedido) }
      LPed := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
      LItem := AdicionarItem(LPed, LProd, 4, 10);
      LItens[0].ItemPedidoId := LItem;
      LMapa := LService.CriarMapa(LPed, LItens, '', 0);
      AssertTrue(LMapa > 0, 'mapa para teste de cancelamento de talão');
      RegistrarId(LMapas, LMapa);
      LItemMapa := IdItemDoMapa(LMapa);
      LGerados := 0;
      LService.GerarTaloes(LItemMapa, 'ITEM', LGerados);
      LTalaoId := IdTalaoDoItem(LItemMapa, LCodigo, LNumero, LAQt);
      AssertTrue(CancelarTalaoFalhou(LTalaoId, ''),
        'cancelar talão sem motivo deve falhar');
      LService.CancelarTalao(LTalaoId, 'TESTE');
      AssertEquals('CANCELADO', CampoTexto('TALAO', 'STATUS', LTalaoId),
        'talão GERADO cancelado');
      AssertTrue(CancelarTalaoFalhou(LTalaoId, 'de novo'),
        'cancelar talão já cancelado deve falhar');

      ASuite.AddResult('TestCancelarMapaETalao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCancelarMapaETalao', False, E.Message);
    end;
  end;

  procedure TestConsumoSemFicha;
  var
    LPed, LItem, LMapa, LItemMapa, LTalaoId, LProd: Int64;
    LItens: TItensMapa;
    LCodigo: string;
    LAQt: Double;
    LNumero: Integer;
    LGerados: Integer;
    LBip: TBipagemTalao;
  begin
    try
      { produto SEM ficha: concluído, mas consumo não pode ser gerado }
      LProd := CriarProduto(NovoCodigo('SNF'), NovoNome('PROD SEM FICHA'),
        20, 50, LSessao.EmpresaId);
      LPed := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
      LItem := AdicionarItem(LPed, LProd, 1, 50);
      SetLength(LItens, 1);
      LItens[0].ItemPedidoId := LItem;
      LItens[0].ProdutoId := LProd;
      LItens[0].Quantidade := 1;
      LMapa := LService.CriarMapa(LPed, LItens, '', 0);
      RegistrarId(LMapas, LMapa);
      LItemMapa := IdItemDoMapa(LMapa);
      LGerados := 0;
      LService.GerarTaloes(LItemMapa, 'ITEM', LGerados);
      LTalaoId := IdTalaoDoItem(LItemMapa, LCodigo, LNumero, LAQt);
      LBip := LService.BiparTalao(LCodigo, 'MANUAL');
      LBip := LService.BiparTalao(LCodigo, 'MANUAL');

      AssertTrue(ConsumoGeradoFalhou(LMapa, False),
        'produto sem ficha nao pode gerar consumo');
      AssertTrue(ConsumoGeradoFalhou(LMapa, True),
        'planejado tambem exige ficha');

      ASuite.AddResult('TestConsumoSemFicha', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestConsumoSemFicha', False, E.Message);
    end;
  end;

  procedure TestConsumoPlanejadoSemProducao;
  var
    LMapa, LProd, LMat, LItem, LConsumo, LConsumo2, LItemConsumo: Int64;
    LItens: TItensMapa;
    LItensFicha: TItensFichaTecnica;
    LPed: Int64;
  begin
    try
      LProd := CriarProduto(NovoCodigo('CPP'), NovoNome('PROD PLANEJ'),
        20, 50, LSessao.EmpresaId);
      LMat := CriarProduto(NovoCodigo('CPM'), NovoNome('MAT PLANEJ'),
        2, 4, LSessao.EmpresaId);
      SetLength(LItensFicha, 1);
      LItensFicha[0].MaterialId := LMat;
      LItensFicha[0].Quantidade := 3;
      LItensFicha[0].PerdaPercentual := 10;
      LService.GravarFichaTecnica(LProd, 'FICHA ' + LSufixo, 1, LItensFicha);

      { mapa ABERTO, nenhum talão: só o modo PLANEJADO calcula }
      LPed := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
      LItem := AdicionarItem(LPed, LProd, 2, 50);
      SetLength(LItens, 1);
      LItens[0].ItemPedidoId := LItem;
      LItens[0].ProdutoId := LProd;
      LItens[0].Quantidade := 2;
      LMapa := LService.CriarMapa(LPed, LItens, '', 0);
      RegistrarId(LMapas, LMapa);

      AssertTrue(ConsumoGeradoFalhou(LMapa, False),
        'sem produção concluída o modo PRODUZIDO não calcula');
      LConsumo := LService.GerarConsumoMaterial(LMapa, 'PLANEJADO', True);
      AssertTrue(LConsumo > 0, 'consumo planejado deve ser gerado');
      AssertEquals(IntToStr(LConsumo),
        IntToStr(LService.ConsumoAtivoDoMapa(LMapa)),
        'ConsumoAtivoDoMapa deve achar o PENDENTE');
      AssertEquals('PENDENTE',
        CampoTexto('CONSUMO_MATERIAL', 'STATUS', LConsumo),
        'consumo nasce PENDENTE');

      LItemConsumo := IdItemConsumo(LConsumo);
      AssertTrue(LItemConsumo > 0, 'item do consumo gravado');
      { (2 / base 1) * 3 * (1 + 10%) = 6.6 }
      AssertTrue(QuaseIgual(6.6, QtdPrevistaConsumo(LItemConsumo)),
        'QTD_PREVISTA = 6.6 (2 x 3 x 1.1)');

      { gerar de novo substitui o PENDENTE: continua existindo 1 só }
      LConsumo2 := LService.GerarConsumoMaterial(LMapa, 'PLANEJADO 2', True);
      AssertTrue(LConsumo2 > 0, 'novo consumo gerado');
      AssertEquals('1', IntToStr(ContarConsumos(LMapa)),
        'consumo pendente é substituído (fica só 1)');
      AssertEquals(IntToStr(LConsumo2),
        IntToStr(LService.ConsumoAtivoDoMapa(LMapa)),
        'o ativo é o mais recente');

      ASuite.AddResult('TestConsumoPlanejadoSemProducao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestConsumoPlanejadoSemProducao', False, E.Message);
    end;
  end;

  procedure TestConsumoConfirmarEstornar;
  var
    LMapa, LProdAcab, LMaterial, LConsumo, LConsumo2: Int64;
    LItemConsumo, LItemConsumo2, LPedidoId: Int64;
    LAItens: TItensConsumoConfirmar;
    LSaldo: Double;
  begin
    try
      { cenário: produção concluída (2 un) + ficha + 100 un material }
      LMapa := 0;
      LProdAcab := 0;
      LMaterial := 0;
      MontarCenarioConsumo(LMapa, LProdAcab, LMaterial, True);
      AssertTrue(LMapa > 0, 'mapa do cenário montado');
      AssertTrue(QuaseIgual(100, SaldoEstoque(LMaterial)),
        'material com 100 un antes do consumo');
      LPedidoId := CampoInteiro('MAPA_PRODUCAO', 'PEDIDO_VENDA_ID', LMapa);
      AssertEquals('D', CampoTexto('PEDIDO_VENDA', 'STATUS', LPedidoId),
        'pedido Produzido após concluir o mapa');

      { consumo pela produção concluída: 2 x 3 x 1.1 = 6.6 }
      LConsumo := LService.GerarConsumoMaterial(LMapa, 'TESTE CONF', False);
      AssertTrue(LConsumo > 0, 'consumo do produzido gerado');
      LItemConsumo := IdItemConsumo(LConsumo);
      AssertTrue(LItemConsumo > 0, 'item do consumo gravado');
      AssertTrue(QuaseIgual(6.6, QtdPrevistaConsumo(LItemConsumo)),
        'prevista 6.6 para 2 un produzidas');

      { quantidade real zero deve falhar }
      SetLength(LAItens, 1);
      LAItens[0].ItemId := LItemConsumo;
      LAItens[0].QtdReal := 0;
      AssertTrue(ConfirmarFalhou(LConsumo, LAItens),
        'quantidade real zero deve falhar');
      AssertEquals('PENDENTE',
        CampoTexto('CONSUMO_MATERIAL', 'STATUS', LConsumo),
        'consumo continua PENDENTE após falha');

      { confirma com quantidade real = 1 (menos que a prevista) }
      LAItens[0].QtdReal := 1;
      LService.ConfirmarConsumo(LConsumo, LAItens);
      AssertEquals('CONFIRMADO',
        CampoTexto('CONSUMO_MATERIAL', 'STATUS', LConsumo),
        'consumo CONFIRMADO');
      AssertTrue(QuaseIgual(1, QtdRealConsumo(LItemConsumo)),
        'QTD_REAL gravada');
      AssertTrue(QuaseIgual(99, SaldoEstoque(LMaterial)),
        'estoque baixou 1 un (100 -> 99)');
      AssertTrue(ContaMovimento(LMaterial, 'S', 'CONSUMO MAPA') >= 1,
        'movimento S de baixa gravado');

      { confirmar de novo deve falhar }
      AssertTrue(ConfirmarFalhou(LConsumo, nil),
        'confirmar consumo já CONFIRMADO deve falhar');

      { gerar novo consumo com CONFIRMADO exige estorno prévio }
      AssertTrue(ConsumoGeradoFalhou(LMapa, False),
        'consumo CONFIRMADO bloqueia novo consumo');

      { estorno: devolve ao estoque e marca ESTORNADO }
      AssertTrue(EstornoFalhou(LConsumo, ''),
        'estornar sem motivo deve falhar');
      LService.EstornarConsumo(LConsumo, 'TESTE ESTORNO');
      AssertEquals('ESTORNADO',
        CampoTexto('CONSUMO_MATERIAL', 'STATUS', LConsumo),
        'consumo ESTORNADO');
      AssertTrue(QuaseIgual(100, SaldoEstoque(LMaterial)),
        'estoque devolvido (volta a 100)');
      AssertTrue(ContaMovimento(LMaterial, 'E', 'ESTORNO CONSUMO') >= 1,
        'movimento E de estorno gravado');
      AssertTrue(EstornoFalhou(LConsumo, 'de novo'),
        'estornar consumo já ESTORNADO deve falhar');

      { depois do estorno, novo consumo pode ser gerado e confirmado
        com a quantidade prevista (sem AItens) }
      LConsumo2 := LService.GerarConsumoMaterial(LMapa, 'TESTE 2', False);
      AssertTrue(LConsumo2 > 0, 'novo consumo após estorno');
      LItemConsumo2 := IdItemConsumo(LConsumo2);
      LSaldo := SaldoEstoque(LMaterial);
      LService.ConfirmarConsumo(LConsumo2, nil);
      AssertEquals('CONFIRMADO',
        CampoTexto('CONSUMO_MATERIAL', 'STATUS', LConsumo2),
        'segundo consumo CONFIRMADO');
      AssertTrue(QuaseIgual(6.6, QtdRealConsumo(LItemConsumo2)),
        'sem AItens consome a QTD_PREVISTA (6.6)');
      AssertTrue(QuaseIgual(LSaldo - 6.6, SaldoEstoque(LMaterial)),
        'estoque baixou pela prevista');

      ASuite.AddResult('TestConsumoConfirmarEstornar', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestConsumoConfirmarEstornar', False, E.Message);
    end;
  end;

  procedure TestConsumoSemSaldo;
  var
    LMapa, LProd, LMat, LConsumo, LItem, LItemConsumo: Int64;
    LItens: TItensMapa;
    LItensFicha: TItensFichaTecnica;
    LPed: Int64;
  begin
    try
      { material SEM estoque: confirmação deve exigir saldo }
      LProd := CriarProduto(NovoCodigo('CSL'), NovoNome('PROD SEM SALDO'),
        20, 50, LSessao.EmpresaId);
      LMat := CriarProduto(NovoCodigo('CSM'), NovoNome('MAT SEM SALDO'),
        2, 4, LSessao.EmpresaId);
      SetLength(LItensFicha, 1);
      LItensFicha[0].MaterialId := LMat;
      LItensFicha[0].Quantidade := 1;
      LItensFicha[0].PerdaPercentual := 0;
      LService.GravarFichaTecnica(LProd, 'FICHA ' + LSufixo, 1, LItensFicha);

      LPed := CriarPedido(LCliente, 'P', LSessao.EmpresaId);
      LItem := AdicionarItem(LPed, LProd, 1, 50);
      SetLength(LItens, 1);
      LItens[0].ItemPedidoId := LItem;
      LItens[0].ProdutoId := LProd;
      LItens[0].Quantidade := 1;
      LMapa := LService.CriarMapa(LPed, LItens, '', 0);
      RegistrarId(LMapas, LMapa);

      LConsumo := LService.GerarConsumoMaterial(LMapa, 'SEM SALDO', True);
      AssertTrue(LConsumo > 0, 'consumo planejado gerado');
      LItemConsumo := IdItemConsumo(LConsumo);
      AssertTrue(LItemConsumo > 0, 'item do consumo');

      AssertTrue(ConfirmarFalhou(LConsumo, nil),
        'sem saldo de material a confirmação deve falhar');
      AssertEquals('PENDENTE',
        CampoTexto('CONSUMO_MATERIAL', 'STATUS', LConsumo),
        'consumo continua PENDENTE');
      AssertTrue(QuaseIgual(0, SaldoEstoque(LMat)),
        'estoque do material permanece zero');

      ASuite.AddResult('TestConsumoSemSaldo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestConsumoSemSaldo', False, E.Message);
    end;
  end;

begin
  LConexao := TConexao.GetInstance;
  if not LConexao.Conectado then
    LConexao.Conectar;
  LSessao := TSessao.GetInstance;
  LService := TProducaoService.Create;
  LQuery := TSQLQuery.Create(nil);
  LQuery.DataBase := LConexao.Connection;
  LQuery.Transaction := LConexao.Transaction;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSeq := 0;
  LPessoas := nil;
  LProdutos := nil;
  LPedidos := nil;
  LMapas := nil;

  { topo do LOG_SISTEMA: no fim apaga so a auditoria gerada aqui }
  LQuery.Close;
  LQuery.SQL.Text := 'SELECT FIRST 1 ID FROM LOG_SISTEMA ORDER BY ID DESC';
  LQuery.Open;
  if LQuery.IsEmpty then
    LLogAntes := 0
  else
    LLogAntes := LQuery.FieldByName('ID').AsLargeInt;
  LQuery.Close;

  { cliente reaproveitado pelos pedidos de teste }
  LCliente := CriarPessoa(NovoNome('CLIENTE PROD'), 'C',
    LSessao.EmpresaId);

  try
    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DO FLUXO DE PRODUCAO');
    WriteLn('========================================');

    TestFichaValidacoes;
    TestFichaGravarELer;
    TestMapaValidacoes;
    TestMapaCriarParciais;
    TestMapaEscopoEmpresa;
    TestTaloesGerar;
    TestBiparFluxoCompleto;
    TestCancelarMapaETalao;
    TestConsumoSemFicha;
    TestConsumoPlanejadoSemProducao;
    TestConsumoConfirmarEstornar;
    TestConsumoSemSaldo;
  finally
    { limpeza: somente os IDs criados por este arquivo }
    try
      if Length(LPedidos) > 0 then
      begin
        LQuery.SQL.Text :=
          'DELETE FROM CONSUMO_MATERIAL_ITEM WHERE CONSUMO_MATERIAL_ID IN ' +
          '(SELECT ID FROM CONSUMO_MATERIAL WHERE MAPA_PRODUCAO_ID IN ' +
          '(SELECT ID FROM MAPA_PRODUCAO WHERE PEDIDO_VENDA_ID IN (' +
          IdsParaIn(LPedidos) + ')))';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM CONSUMO_MATERIAL WHERE MAPA_PRODUCAO_ID IN ' +
          '(SELECT ID FROM MAPA_PRODUCAO WHERE PEDIDO_VENDA_ID IN (' +
          IdsParaIn(LPedidos) + '))';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM TALAO_BIPAGEM WHERE TALAO_ID IN ' +
          '(SELECT T.ID FROM TALAO T ' +
          ' JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
          ' JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
          ' WHERE M.PEDIDO_VENDA_ID IN (' + IdsParaIn(LPedidos) + '))';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM TALAO WHERE MAPA_PRODUCAO_ITEM_ID IN ' +
          '(SELECT MI.ID FROM MAPA_PRODUCAO_ITEM MI ' +
          ' JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
          ' WHERE M.PEDIDO_VENDA_ID IN (' + IdsParaIn(LPedidos) + '))';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM MAPA_PRODUCAO_ITEM WHERE MAPA_PRODUCAO_ID IN ' +
          '(SELECT ID FROM MAPA_PRODUCAO WHERE PEDIDO_VENDA_ID IN (' +
          IdsParaIn(LPedidos) + '))';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM MAPA_PRODUCAO WHERE PEDIDO_VENDA_ID IN (' +
          IdsParaIn(LPedidos) + ')';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID IN (' +
          IdsParaIn(LPedidos) + ')';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM PEDIDO_VENDA WHERE ID IN (' + IdsParaIn(LPedidos) + ')';
        LQuery.ExecSQL;
      end;
      if Length(LProdutos) > 0 then
      begin
        LQuery.SQL.Text :=
          'DELETE FROM FICHA_TECNICA_ITEM WHERE FICHA_TECNICA_ID IN ' +
          '(SELECT ID FROM FICHA_TECNICA WHERE PRODUTO_ID IN (' +
          IdsParaIn(LProdutos) + '))';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM FICHA_TECNICA WHERE PRODUTO_ID IN (' +
          IdsParaIn(LProdutos) + ')';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM MOVIMENTO_ESTOQUE WHERE PRODUTO_ID IN (' +
          IdsParaIn(LProdutos) + ')';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM ESTOQUE WHERE PRODUTO_ID IN (' + IdsParaIn(LProdutos) + ')';
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM PRODUTO WHERE ID IN (' + IdsParaIn(LProdutos) + ')';
        LQuery.ExecSQL;
      end;
      if Length(LPessoas) > 0 then
      begin
        LQuery.SQL.Text :=
          'DELETE FROM PESSOA WHERE ID IN (' + IdsParaIn(LPessoas) + ')';
        LQuery.ExecSQL;
      end;
      LQuery.SQL.Text :=
        'DELETE FROM LOG_SISTEMA WHERE ID > :TOP AND TABELA IN ' +
        '(''MAPA_PRODUCAO'',''MAPA_PRODUCAO_ITEM'',''TALAO'',''TALAO_BIPAGEM'',' +
        '''FICHA_TECNICA'',''CONSUMO_MATERIAL'',''CONSUMO_MATERIAL_ITEM'',' +
        '''PEDIDO_VENDA'',''ITEM_PEDIDO'')';
      LQuery.ParamByName('TOP').AsLargeInt := LLogAntes;
      LQuery.ExecSQL;
      LConexao.Confirmar;
    except
    end;
    LQuery.Free;
    LService.Free;
  end;
end;

end.
