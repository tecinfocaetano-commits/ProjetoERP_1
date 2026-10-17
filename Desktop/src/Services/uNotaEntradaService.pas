unit uNotaEntradaService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 1 - Nota de Entrada (compra de mercadoria)
  ------------------------------------------------------------
  Concentra as regras de negócio da nota de entrada:

    - PrimeiroItemSemProduto / QuantidadeItens: validações;
    - RecalcularTotais: totais do cabeçalho a partir dos itens;
    - Processar: dá entrada no estoque (MOVIMENTO_ESTOQUE), atualiza
      o custo médio e gera as parcelas em CONTA_PAGAR;
    - Cancelar: apenas enquanto a nota está Aberta;
    - ExcluirItem.

  O saldo de ESTOQUE é mantido pelo trigger TRG_MOVEST_AI a partir
  de MOVIMENTO_ESTOQUE; aqui apenas gravamos os movimentos.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, DB, uConexao;

type
  ENotaEntrada = class(Exception);

  TNotaEntradaService = class
  private
    FConexao: TConexao;
    function  NovaConsulta: TSQLQuery;
    function  LerSaldo(AEmpresaId, AProdutoId: Int64;
      out AQuantidade, ACustoMedio: Double): Boolean;
    function  GarantirFinanceiro(const ATipo, ADescricao: string): Int64;
    procedure GerarContasPagar(ANotaId: Int64);
  public
    constructor Create;

    function  QuantidadeItens(ANotaId: Int64): Integer;
    function  PrimeiroItemSemProduto(ANotaId: Int64): string;
    procedure RecalcularTotais(ANotaId: Int64);
    procedure Processar(ANotaId: Int64);
    procedure Cancelar(ANotaId: Int64);
    procedure ExcluirItem(AItemId: Int64);
  end;

implementation

uses
  Math, DateUtils, uSessao;

type
  TItemNota = record
    Id: Int64;
    ProdutoId: Int64;
    Descricao: string;
    Quantidade: Double;
    ValorUnitario: Double;
    AtualizaEstoque: Boolean;
    AtualizaCusto: Boolean;
  end;

constructor TNotaEntradaService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TNotaEntradaService.NovaConsulta: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConexao.Connection;
  Result.Transaction := FConexao.Transaction;
end;

// Localiza (ou cria) o registro do plano financeiro usado pelas contas a
// pagar/receber da empresa. Necessário porque CONTA_PAGAR.FINANCEIRO_ID usa o
// domínio DM_ID, que é NOT NULL.
function TNotaEntradaService.GarantirFinanceiro(const ATipo,
  ADescricao: string): Int64;
var
  LQuery: TSQLQuery;
begin
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM FINANCEIRO ' +
      'WHERE EMPRESA_ID = :EMP AND TIPO = :TIPO ORDER BY ID';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt
    else
    begin
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO FINANCEIRO (EMPRESA_ID, TIPO, DESCRICAO, STATUS) ' +
        'VALUES (:EMP, :TIPO, :DESC, ''A'') RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('TIPO').AsString := ATipo;
      LQuery.ParamByName('DESC').AsString := ADescricao;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
    end;
  finally
    LQuery.Free;
  end;
end;

function TNotaEntradaService.QuantidadeItens(ANotaId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COUNT(*) AS TOTAL FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    Result := LQuery.FieldByName('TOTAL').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TNotaEntradaService.PrimeiroItemSemProduto(ANotaId: Int64): string;
var
  LQuery: TSQLQuery;
begin
  Result := '';
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT FIRST 1 DESCRICAO FROM NOTA_ENTRADA_ITEM ' +
      'WHERE NOTA_ENTRADA_ID = :ID AND (PRODUTO_ID IS NULL OR PRODUTO_ID = 0) ' +
      'AND ATUALIZA_ESTOQUE = ''S'' ORDER BY ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('DESCRICAO').AsString);
  finally
    LQuery.Free;
  end;
end;

procedure TNotaEntradaService.RecalcularTotais(ANotaId: Int64);
var
  LQuery: TSQLQuery;
  LProdutos, LDesconto: Double;
begin
  LQuery := NovaConsulta;
  try
    // ATENÇÃO: o SQLDB (Firebird) não lê corretamente expressões monetárias
    // cujo resultado tem escala maior que 4 (ex.: NUMERIC(18,4) * NUMERIC(18,4)
    // gera NUMERIC(18,8) -> TFMTBCDField -> volta como NULL). Por isso o CAST.
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(QUANTIDADE * VALOR_UNITARIO), 0) AS NUMERIC(18,4)) AS PRODUTOS, ' +
      '       CAST(COALESCE(SUM(DESCONTO), 0) AS NUMERIC(18,4)) AS DESCONTO ' +
      'FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    LProdutos := LQuery.FieldByName('PRODUTOS').AsFloat;
    LDesconto := LQuery.FieldByName('DESCONTO').AsFloat;
    LQuery.Close;

    // Total = produtos + frete + seguro + outras despesas - desconto
    LQuery.SQL.Text :=
      'UPDATE NOTA_ENTRADA SET VALOR_PRODUTOS = :PROD, ' +
      '  VALOR_TOTAL = :PROD + ' +
      '    COALESCE(VALOR_FRETE, 0) + COALESCE(VALOR_SEGURO, 0) + ' +
      '    COALESCE(VALOR_OUTRAS, 0) - COALESCE(VALOR_DESCONTO, 0) ' +
      'WHERE ID = :ID';
    LQuery.ParamByName('PROD').AsFloat := LProdutos;
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

function TNotaEntradaService.LerSaldo(AEmpresaId, AProdutoId: Int64;
  out AQuantidade, ACustoMedio: Double): Boolean;
var
  LQuery: TSQLQuery;
begin
  AQuantidade := 0;
  ACustoMedio := 0;
  Result := False;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT QUANTIDADE, CUSTO_MEDIO FROM ESTOQUE ' +
      'WHERE EMPRESA_ID = :EMP AND PRODUTO_ID = :PROD';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      AQuantidade := LQuery.FieldByName('QUANTIDADE').AsFloat;
      ACustoMedio := LQuery.FieldByName('CUSTO_MEDIO').AsFloat;
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TNotaEntradaService.ExcluirItem(AItemId: Int64);
var
  LQuery: TSQLQuery;
begin
  FConexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'DELETE FROM NOTA_ENTRADA_ITEM WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AItemId;
    LQuery.ExecSQL;
    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LQuery.Free;
    raise;
  end;
  LQuery.Free;
end;

procedure TNotaEntradaService.GerarContasPagar(ANotaId: Int64);
var
  LCab: TSQLQuery;
  LTot: TSQLQuery;
  LParcelas, LDias, LIndice: Integer;
  LTotal, LValorParcela, LAcumulado: Double;
  LVencimento: TDate;
  LEmpresaId, LFornecedorId, LCondicaoId: Int64;
  LFinanceiroId: Int64;
  LNumero: string;
begin
  LCab := NovaConsulta;
  LTot := NovaConsulta;
  try
    LCab.SQL.Text :=
      'SELECT EMPRESA_ID, FORNECEDOR_ID, CONDICAO_PAGAMENTO_ID, NUMERO, ' +
      '       VALOR_TOTAL, COALESCE(DATA_ENTRADA, CURRENT_DATE) AS DATA_BASE ' +
      'FROM NOTA_ENTRADA WHERE ID = :ID';
    LCab.ParamByName('ID').AsLargeInt := ANotaId;
    LCab.Open;
    if LCab.IsEmpty then
      raise ENotaEntrada.Create('Nota de entrada não encontrada.');

    LEmpresaId     := LCab.FieldByName('EMPRESA_ID').AsLargeInt;
    LFornecedorId  := LCab.FieldByName('FORNECEDOR_ID').AsLargeInt;
    LCondicaoId    := LCab.FieldByName('CONDICAO_PAGAMENTO_ID').AsLargeInt;
    LNumero        := Trim(LCab.FieldByName('NUMERO').AsString);
    LTotal         := LCab.FieldByName('VALOR_TOTAL').AsFloat;
    LVencimento    := LCab.FieldByName('DATA_BASE').AsDateTime;

    // Só gera contas a pagar se houver fornecedor informado
    if (LFornecedorId = 0) or (LTotal <= 0) then
      Exit;

    LFinanceiroId := GarantirFinanceiro('P', 'Contas a pagar de compras');

    LParcelas := 1;
    LDias := 0;
    if LCondicaoId > 0 then
    begin
      LTot.SQL.Text :=
        'SELECT PARCELAS, DIAS_ENTRE_PARCELAS FROM CONDICAO_PAGAMENTO WHERE ID = :ID';
      LTot.ParamByName('ID').AsLargeInt := LCondicaoId;
      LTot.Open;
      if not LTot.IsEmpty then
      begin
        LParcelas := LTot.FieldByName('PARCELAS').AsInteger;
        LDias := LTot.FieldByName('DIAS_ENTRE_PARCELAS').AsInteger;
        if LParcelas < 1 then
          LParcelas := 1;
      end;
      LTot.Close;
    end;

    LValorParcela := ROUNDTo(LTotal / LParcelas, -2);
    if LValorParcela <= 0 then
      LValorParcela := LTotal;
    LAcumulado := 0;

    for LIndice := 1 to LParcelas do
    begin
      // A última parcela absorve a diferença de arredondamento
      if LIndice = LParcelas then
        LValorParcela := LTotal - LAcumulado;
      LAcumulado := LAcumulado + LValorParcela;

      LTot.SQL.Text :=
        'INSERT INTO CONTA_PAGAR ' +
        '  (EMPRESA_ID, FINANCEIRO_ID, FORNECEDOR_ID, DESCRICAO, VALOR, ' +
        '   DATA_VENCIMENTO, STATUS, PARCELA) ' +
        'VALUES (:EMP, :FIN, :FORN, :DESC, :VALOR, :VENC, ''A'', :PARC)';
      LTot.ParamByName('EMP').AsLargeInt := LEmpresaId;
      LTot.ParamByName('FIN').AsLargeInt := LFinanceiroId;
      LTot.ParamByName('FORN').AsLargeInt := LFornecedorId;
      LTot.ParamByName('DESC').AsString :=
        'NF de entrada ' + LNumero + ' (' + IntToStr(LIndice) + '/' + IntToStr(LParcelas) + ')';
      LTot.ParamByName('VALOR').AsFloat := LValorParcela;
      LTot.ParamByName('VENC').AsDate := IncDay(LVencimento, LIndice * LDias);
      LTot.ParamByName('PARC').AsInteger := LIndice;
      LTot.ExecSQL;
    end;
  finally
    LCab.Free;
    LTot.Free;
  end;
end;

procedure TNotaEntradaService.Processar(ANotaId: Int64);
var
  LCab: TSQLQuery;
  LMov: TSQLQuery;
  LUpd: TSQLQuery;
  LItens: array of TItemNota;
  LStatus, LModelo, LSerie, LNumero, LDocumento: string;
  LStatusItem: string;
  LEmpresaId, LUsuarioId, LIndice: Integer;
  LDataEntrada: TDate;
  LQuantidade, LValorUnitario, LSaldo, LCustoMedio, LNovoCusto: Double;
  LAtualEstoque, LAtualCusto: Boolean;
  LReg: TSQLQuery;
begin
  FConexao.IniciarTransacao;
  LCab := NovaConsulta;
  LReg := NovaConsulta;
  LMov := NovaConsulta;
  LUpd := NovaConsulta;
  try
    // --- Cabeçalho -------------------------------------------------------
    LCab.SQL.Text :=
      'SELECT STATUS, MODELO, SERIE, NUMERO, EMPRESA_ID, COALESCE(DATA_ENTRADA, CURRENT_DATE) AS DATA_ENTRADA ' +
      'FROM NOTA_ENTRADA WHERE ID = :ID';
    LCab.ParamByName('ID').AsLargeInt := ANotaId;
    LCab.Open;
    if LCab.IsEmpty then
      raise ENotaEntrada.Create('Nota de entrada não encontrada.');

    LStatus := Trim(LCab.FieldByName('STATUS').AsString);
    if LStatus <> 'A' then
      raise ENotaEntrada.Create(
        'Somente notas com status "Aberta" podem ser processadas.');
    LModelo      := Trim(LCab.FieldByName('MODELO').AsString);
    LSerie       := Trim(LCab.FieldByName('SERIE').AsString);
    LNumero      := Trim(LCab.FieldByName('NUMERO').AsString);
    LEmpresaId   := LCab.FieldByName('EMPRESA_ID').AsLargeInt;
    LDataEntrada := LCab.FieldByName('DATA_ENTRADA').AsDateTime;

    if LEmpresaId = 0 then
      LEmpresaId := TSessao.GetInstance.EmpresaId;
    LUsuarioId := TSessao.GetInstance.UsuarioId;

    // --- Itens -----------------------------------------------------------
    LReg.SQL.Text :=
      'SELECT ID, PRODUTO_ID, DESCRICAO, QUANTIDADE, VALOR_UNITARIO, ' +
      '       ATUALIZA_ESTOQUE, ATUALIZA_CUSTO ' +
      'FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID ORDER BY ID';
    LReg.ParamByName('ID').AsLargeInt := ANotaId;
    LReg.Open;
    SetLength(LItens, 0);
    while not LReg.EOF do
    begin
      SetLength(LItens, Length(LItens) + 1);
      with LItens[High(LItens)] do
      begin
        Id := LReg.FieldByName('ID').AsLargeInt;
        ProdutoId := LReg.FieldByName('PRODUTO_ID').AsLargeInt;
        Descricao := Trim(LReg.FieldByName('DESCRICAO').AsString);
        Quantidade := LReg.FieldByName('QUANTIDADE').AsFloat;
        ValorUnitario := LReg.FieldByName('VALOR_UNITARIO').AsFloat;
        LStatusItem := Trim(LReg.FieldByName('ATUALIZA_ESTOQUE').AsString);
        AtualizaEstoque := (LStatusItem = '') or (LStatusItem = 'S');
        LStatusItem := Trim(LReg.FieldByName('ATUALIZA_CUSTO').AsString);
        AtualizaCusto := (LStatusItem = '') or (LStatusItem = 'S');
      end;
      LReg.Next;
    end;
    LReg.Close;

    if Length(LItens) = 0 then
      raise ENotaEntrada.Create('A nota não possui itens para processar.');

    LDocumento := 'NF ENTRADA';
    if LNumero <> '' then
      LDocumento := LDocumento + ' ' + LModelo + '/' + LSerie + '-' + LNumero;

    // --- Movimentos de estoque + custo médio ------------------------------
    for LIndice := 0 to High(LItens) do
    begin
      if not LItens[LIndice].AtualizaEstoque then
        Continue;
      if (LItens[LIndice].ProdutoId = 0) then
        raise ENotaEntrada.Create(
          'O item "' + LItens[LIndice].Descricao + '" não está ligado a um produto.');

      LQuantidade := LItens[LIndice].Quantidade;
      LValorUnitario := LItens[LIndice].ValorUnitario;

      LerSaldo(LEmpresaId, LItens[LIndice].ProdutoId, LSaldo, LCustoMedio);

      // O trigger TRG_MOVEST_AI atualiza ESTOQUE.QUANTIDADE
      LMov.SQL.Text :=
        'INSERT INTO MOVIMENTO_ESTOQUE ' +
        '  (EMPRESA_ID, PRODUTO_ID, TIPO, QUANTIDADE, CUSTO_UNITARIO, ' +
        '   DOCUMENTO, OBSERVACAO, DATA_MOVIMENTO, USUARIO_ID) ' +
        'VALUES (:EMP, :PROD, ''E'', :QTD, :CUSTO, :DOC, :OBS, :DATA, :USU)';
      LMov.ParamByName('EMP').AsLargeInt := LEmpresaId;
      LMov.ParamByName('PROD').AsLargeInt := LItens[LIndice].ProdutoId;
      LMov.ParamByName('QTD').AsFloat := LQuantidade;
      LMov.ParamByName('CUSTO').AsFloat := LValorUnitario;
      LMov.ParamByName('DOC').AsString := LDocumento;
      LMov.ParamByName('OBS').AsString := 'Entrada por nota de compra';
      LMov.ParamByName('DATA').AsDate := LDataEntrada;
      LMov.ParamByName('USU').AsLargeInt := LUsuarioId;
      LMov.ExecSQL;

      // Custo médio ponderado. Se o saldo atual tem custo desconhecido
      // (ESTOQUE.CUSTO_MEDIO = 0, ex.: saldo inicial importado sem custo), o
      // preço desta compra vira o novo custo médio - caso contrário um saldo
      // grande e sem custo diluiria o custo da compra a quase zero.
      if LItens[LIndice].AtualizaCusto and (LSaldo + LQuantidade > 0) then
      begin
        if LCustoMedio > 0 then
          LNovoCusto :=
            ((LSaldo * LCustoMedio) + (LQuantidade * LValorUnitario)) /
            (LSaldo + LQuantidade)
        else
          LNovoCusto := LValorUnitario;

        LUpd.SQL.Text :=
          'UPDATE ESTOQUE SET CUSTO_MEDIO = :CUSTO ' +
          'WHERE EMPRESA_ID = :EMP AND PRODUTO_ID = :PROD';
        LUpd.ParamByName('CUSTO').AsFloat := LNovoCusto;
        LUpd.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LUpd.ParamByName('PROD').AsLargeInt := LItens[LIndice].ProdutoId;
        LUpd.ExecSQL;

        LUpd.SQL.Text :=
          'UPDATE PRODUTO SET PRECO_CUSTO = :CUSTO WHERE ID = :PROD';
        LUpd.ParamByName('CUSTO').AsFloat := LNovoCusto;
        LUpd.ParamByName('PROD').AsLargeInt := LItens[LIndice].ProdutoId;
        LUpd.ExecSQL;
      end;
    end;

    // --- Financeiro -------------------------------------------------------
    GerarContasPagar(ANotaId);

    // --- Fecha a nota -----------------------------------------------------
    LUpd.SQL.Text :=
      'UPDATE NOTA_ENTRADA SET STATUS = ''P'', DATA_PROCESSAMENTO = CURRENT_TIMESTAMP ' +
      'WHERE ID = :ID';
    LUpd.ParamByName('ID').AsLargeInt := ANotaId;
    LUpd.ExecSQL;

    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LCab.Free;
    LReg.Free;
    LMov.Free;
    LUpd.Free;
    raise;
  end;

  LCab.Free;
  LReg.Free;
  LMov.Free;
  LUpd.Free;
end;

procedure TNotaEntradaService.Cancelar(ANotaId: Int64);
var
  LQuery: TSQLQuery;
  LStatus: string;
begin
  FConexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'SELECT STATUS FROM NOTA_ENTRADA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise ENotaEntrada.Create('Nota de entrada não encontrada.');
    LStatus := Trim(LQuery.FieldByName('STATUS').AsString);
    LQuery.Close;

    if LStatus = 'P' then
      raise ENotaEntrada.Create(
        'Esta nota já foi processada. Cancele a movimentação de estoque ' +
        'e as contas a pagar manualmente.');
    if LStatus = 'C' then
      raise ENotaEntrada.Create('Esta nota já está cancelada.');

    LQuery.SQL.Text := 'UPDATE NOTA_ENTRADA SET STATUS = ''C'' WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.ExecSQL;
    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LQuery.Free;
    raise;
  end;
  LQuery.Free;
end;

end.
