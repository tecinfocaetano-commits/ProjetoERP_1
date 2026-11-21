unit uProducaoBipagem;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Motor de bipagem de talão (compartilhado)
  ------------------------------------------------------------
  Contém a regra de negócio da bipagem extraída de
  TProducaoService.BiparTalao para poder ser usada tanto pelo
  desktop (TSessao) quanto pela API REST (JWT), sem duplicar a
  máquina de estados.

  Diferenças em relação à versão do service:
    - recebe AConnection/ATransaction e AEmpresaId/AUsuarioId
      explícitos (a API não tem TSessao — ela é global e daria
      race condition entre threads do Horse);
    - NÃO gerencia transação: quem chama abre/confirma/cancela
      (desktop: TConexao; API: conexão do pool);
    - auditoria via RegistrarAuditoriaConexao (uAuditoria).

  Regra (espelho de TProducaoService.BiparTalao):
    GERADO/IMPRESSO -> EM_PRODUCAO (etapa INICIO)
    EM_PRODUCAO     -> CONCLUIDO   (etapa CONCLUSAO)
  Rejeitadas: INVALIDO (não encontrado/cancelado) e DUPLICADO
  (talão ou mapa já concluído), sempre auditadas em TALAO_BIPAGEM.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, IBConnection;

type
  { Resultado de uma bipagem de talão. }
  TBipagemTalao = record
    TalaoId: Int64;
    NumeroTalao: Integer;
    CodigoBarras: string;
    Produto: string;
    Quantidade: Double;
    MapaId: Int64;
    MapaNumero: Integer;
    StatusAnterior: string;  { status do talão antes da bipagem }
    StatusNovo: string;      { status após a bipagem }
    Etapa: string;           { INICIO | CONCLUSAO | BIPAGEM }
    Resultado: string;       { OK | DUPLICADO | INVALIDO }
    Mensagem: string;        { mensagem amigável para o operador }
    MapaConcluido: Boolean;  { esta bipagem concluiu o mapa }
  end;

{ Executa a bipagem dentro da transação já aberta pelo chamador.
  AEmpresaId/AUsuarioId vêm da sessão (desktop) ou do JWT (API). }
function ExecutarBipagemTalao(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  const ACodigoBarras, AOrigem: string): TBipagemTalao;

{ Versões parametrizadas dos auxiliares que o service usa em outras
  operações (mapa, cancelamento de talão). O TProducaoService delega
  para cá para manter uma única implementação. }
procedure ProducaoAtualizarStatusConsumo(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  AMapaId: Int64);
procedure ProducaoReavaliarPedido(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  APedidoId: Int64);
procedure ProducaoAplicarStatusPedido(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  APedidoId: Int64; const ANovoStatus: string);

implementation

uses
  uPedidoStatus, uAuditoria;

const
  { mesma tolerância usada por TProducaoService }
  TOLERANCIA_BIPAGEM = 0.0001;

function NovaConsulta(AConnection: TIBConnection;
  ATransaction: TSQLTransaction): TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := AConnection;
  Result.Transaction := ATransaction;
end;

procedure GravarBipagem(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  ATalaoId: Int64; const AEtapa, AOrigem, AResultado,
  AObservacao: string);
var
  LIns: TSQLQuery;
begin
  LIns := NovaConsulta(AConnection, ATransaction);
  try
    LIns.SQL.Text :=
      'INSERT INTO TALAO_BIPAGEM ' +
      '  (TALAO_ID, USUARIO_ID, DATA_HORA, ETAPA, ORIGEM, RESULTADO, OBSERVACAO) ' +
      'VALUES ' +
      '  (:TAL, :USR, CURRENT_TIMESTAMP, :ETAPA, :ORI, :RES, :OBS)';
    LIns.ParamByName('TAL').AsLargeInt := ATalaoId;
    LIns.ParamByName('USR').AsLargeInt := AUsuarioId;
    LIns.ParamByName('ETAPA').AsString := AEtapa;
    LIns.ParamByName('ORI').AsString := AOrigem;
    LIns.ParamByName('RES').AsString := AResultado;
    if AObservacao = '' then
      LIns.ParamByName('OBS').Clear
    else
      LIns.ParamByName('OBS').AsString := AObservacao;
    LIns.ExecSQL;
  finally
    LIns.Free;
  end;
end;

procedure Auditoria(AConnection: TIBConnection; ATransaction: TSQLTransaction;
  AEmpresaId, AUsuarioId: Int64; const ATabela, AOperacao: string;
  ARegistroId: Int64; const ADadosAnteriores, ADadosNovos: string);
begin
  RegistrarAuditoriaConexao(AConnection, ATransaction, AEmpresaId,
    AUsuarioId, ATabela, AOperacao, ARegistroId,
    ADadosAnteriores, ADadosNovos);
end;

{ aplica o andamento dos talões do mapa no STATUS_PRODUCAO dos
  consumos de material (port de TProducaoService.
  AtualizarStatusProducaoConsumo) }
procedure ProducaoAtualizarStatusConsumo(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  AMapaId: Int64);
var
  LQry, LUpd: TSQLQuery;
  LTotal, LConcluidos: Integer;
  LNovoStatus: string;
begin
  if AMapaId <= 0 then
    Exit;

  LQry := NovaConsulta(AConnection, ATransaction);
  LUpd := NovaConsulta(AConnection, ATransaction);
  try
    LQry.SQL.Text :=
      'SELECT COUNT(*) AS TOTAL, ' +
      '  SUM(CASE WHEN T.STATUS = ''CONCLUIDO'' THEN 1 ELSE 0 END) AS CONCLUIDOS ' +
      'FROM TALAO T ' +
      '  JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
      '  JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
      'WHERE MI.MAPA_PRODUCAO_ID = :MAPA AND T.STATUS <> ''CANCELADO'' ' +
      '  AND M.EMPRESA_ID = :EMP';
    LQry.ParamByName('MAPA').AsLargeInt := AMapaId;
    LQry.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQry.Open;
    LTotal := LQry.FieldByName('TOTAL').AsInteger;
    LConcluidos := LQry.FieldByName('CONCLUIDOS').AsInteger;
    LQry.Close;

    if (LTotal > 0) and (LConcluidos >= LTotal) then
      LNovoStatus := 'CONCLUIDO'
    else if LConcluidos > 0 then
      LNovoStatus := 'PARCIALMENTE_CONCLUIDO'
    else
      LNovoStatus := 'ABERTO';

    LUpd.SQL.Text :=
      'UPDATE CONSUMO_MATERIAL_ITEM SET STATUS_PRODUCAO = :NOVO ' +
      'WHERE CONSUMO_MATERIAL_ID IN ' +
      '  (SELECT ID FROM CONSUMO_MATERIAL WHERE MAPA_PRODUCAO_ID = :MAPA ' +
      '     AND EMPRESA_ID = :EMP) ' +
      '  AND COALESCE(STATUS_PRODUCAO, '''') <> :NOVO';
    LUpd.ParamByName('NOVO').AsString := LNovoStatus;
    LUpd.ParamByName('MAPA').AsLargeInt := AMapaId;
    LUpd.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LUpd.ExecSQL;

    Auditoria(AConnection, ATransaction, AEmpresaId, AUsuarioId,
      'CONSUMO_MATERIAL_ITEM', 'STATUS_PRODUCAO', AMapaId,
      '', LNovoStatus + '; CONCLUIDOS=' + IntToStr(LConcluidos) +
      '; TOTAL=' + IntToStr(LTotal));
  finally
    LQry.Free;
    LUpd.Free;
  end;
end;

{ grava o novo status do pedido validando a transição
  (port de TProducaoService.AplicarStatusPedido) }
procedure ProducaoAplicarStatusPedido(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  APedidoId: Int64; const ANovoStatus: string);
var
  LQuery: TSQLQuery;
  LAtual: string;
begin
  LQuery := NovaConsulta(AConnection, ATransaction);
  try
    LQuery.SQL.Text :=
      'SELECT STATUS FROM PEDIDO_VENDA WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise Exception.Create('Pedido de venda não encontrado (ID ' +
        IntToStr(APedidoId) + ').');
    LAtual := Trim(LQuery.FieldByName('STATUS').AsString);
    LQuery.Close;

    if LAtual = ANovoStatus then
      Exit;

    ValidarTransicao(LAtual, ANovoStatus);

    LQuery.SQL.Text :=
      'UPDATE PEDIDO_VENDA SET STATUS = :STATUS ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('STATUS').AsString := ANovoStatus;
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ExecSQL;

    Auditoria(AConnection, ATransaction, AEmpresaId, AUsuarioId,
      'PEDIDO_VENDA', 'STATUS', APedidoId,
      'STATUS=' + LAtual,
      'STATUS=' + ANovoStatus + ' (' + DescricaoDoStatus(ANovoStatus) + ')');
  finally
    LQuery.Free;
  end;
end;

{ decide o status do pedido a partir do andamento da produção
  (port de TProducaoService.ReavaliarPedido) }
procedure ProducaoReavaliarPedido(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  APedidoId: Int64);
var
  LQuery: TSQLQuery;
  LAtual: string;
  LAtivos: Integer;
  LProduzido, LTotal: Double;
  LNovo: string;
begin
  LAtivos := 0;
  LProduzido := 0;
  LTotal := 0;

  LQuery := NovaConsulta(AConnection, ATransaction);
  try
    LQuery.SQL.Text :=
      'SELECT STATUS, ' +
      '  (SELECT COUNT(*) FROM MAPA_PRODUCAO M ' +
      '     WHERE M.PEDIDO_VENDA_ID = :PED AND M.STATUS IN (''ABERTO'', ''EM_PRODUCAO'') ' +
      '       AND M.EMPRESA_ID = :EMP) AS ATIVOS, ' +
      '  CAST(COALESCE((SELECT SUM(MI.QUANTIDADE) FROM MAPA_PRODUCAO_ITEM MI ' +
      '      JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
      '      WHERE M.PEDIDO_VENDA_ID = :PED AND M.STATUS <> ''CANCELADO'' ' +
      '        AND M.EMPRESA_ID = :EMP), 0) AS NUMERIC(18,4)) AS TOTAL, ' +
      '  CAST(COALESCE((SELECT SUM(T.QUANTIDADE) FROM TALAO T ' +
      '      JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
      '      JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
      '      WHERE M.PEDIDO_VENDA_ID = :PED AND T.STATUS = ''CONCLUIDO'' ' +
      '        AND M.EMPRESA_ID = :EMP), 0) AS NUMERIC(18,4)) AS PRODUZIDO ' +
      'FROM PEDIDO_VENDA WHERE ID = :PED AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('PED').AsLargeInt := APedidoId;
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      Exit;
    LAtual := Trim(LQuery.FieldByName('STATUS').AsString);
    LAtivos := LQuery.FieldByName('ATIVOS').AsInteger;
    LTotal := LQuery.FieldByName('TOTAL').AsFloat;
    LProduzido := LQuery.FieldByName('PRODUZIDO').AsFloat;
    LQuery.Close;
  finally
    LQuery.Free;
  end;

  { Pedido faturado ou cancelado não é alterado pela produção }
  if (LAtual = PEDIDO_STATUS_FATURADO) or (LAtual = PEDIDO_STATUS_CANCELADO) then
    Exit;

  if LAtivos > 0 then
    LNovo := PEDIDO_STATUS_EM_PRODUCAO
  else if (LTotal > TOLERANCIA_BIPAGEM) and
          (LProduzido >= LTotal - TOLERANCIA_BIPAGEM) then
    LNovo := PEDIDO_STATUS_PRODUZIDO
  else if LProduzido > TOLERANCIA_BIPAGEM then
    LNovo := PEDIDO_STATUS_EM_PRODUCAO
  else
    LNovo := PEDIDO_STATUS_PENDENTE;

  ProducaoAplicarStatusPedido(AConnection, ATransaction, AEmpresaId,
    AUsuarioId, APedidoId, LNovo);
end;

function ExecutarBipagemTalao(AConnection: TIBConnection;
  ATransaction: TSQLTransaction; AEmpresaId, AUsuarioId: Int64;
  const ACodigoBarras, AOrigem: string): TBipagemTalao;
var
  LTalao, LUpd: TSQLQuery;
  LCodigo: string;
  LTalaoId, LItemId, LMapaId, LPedidoId: Int64;
  LNumero, LMapaNumero: Integer;
  LStatus, LStatusMapa: string;
  LConcluiuMapa: Boolean;
begin
  { resultado padrão: inválido — preenchido conforme a análise }
  Result.TalaoId := 0;
  Result.NumeroTalao := 0;
  Result.CodigoBarras := Trim(UpperCase(ACodigoBarras));
  Result.Produto := '';
  Result.Quantidade := 0;
  Result.MapaId := 0;
  Result.MapaNumero := 0;
  Result.StatusAnterior := '';
  Result.StatusNovo := '';
  Result.Etapa := 'BIPAGEM';
  Result.Resultado := 'INVALIDO';
  Result.Mensagem := '';
  Result.MapaConcluido := False;

  LCodigo := Result.CodigoBarras;
  if LCodigo = '' then
  begin
    Result.Mensagem := 'Informe o código de barras do talão.';
    Exit;
  end;

  { digitação manual só com o número (ex.: "3") vira o formato T000003 }
  if (Length(LCodigo) <= 9) and (LCodigo[1] >= '0') and (LCodigo[1] <= '9') then
    LCodigo := Format('T%.6d', [StrToIntDef(LCodigo, 0)]);
  Result.CodigoBarras := LCodigo;

  LTalao := NovaConsulta(AConnection, ATransaction);
  LUpd := NovaConsulta(AConnection, ATransaction);
  try
    try
      LTalao.SQL.Text :=
        'SELECT T.ID, T.NUMERO, T.STATUS, T.QUANTIDADE, ' +
        '  T.MAPA_PRODUCAO_ITEM_ID, ' +
        '  M.ID AS MAPA_ID, M.NUMERO AS MAPA_NUMERO, M.STATUS AS MAPA_STATUS, ' +
        '  M.PEDIDO_VENDA_ID, PR.DESCRICAO AS PRODUTO ' +
        'FROM TALAO T ' +
        '  JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
        '  JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
        '  LEFT JOIN PRODUTO PR ON PR.ID = MI.PRODUTO_ID ' +
        'WHERE T.CODIGO_BARRAS = :COD AND T.EMPRESA_ID = :EMP';
      LTalao.ParamByName('COD').AsString := LCodigo;
      LTalao.ParamByName('EMP').AsLargeInt := AEmpresaId;
      LTalao.Open;

      if LTalao.IsEmpty then
      begin
        { tentativa de leitura inválida fica registrada para rastreio;
          TALAO_ID = 0 marca "código inexistente" (sem FK na tabela) }
        GravarBipagem(AConnection, ATransaction, AEmpresaId, AUsuarioId,
          0, 'BIPAGEM', AOrigem, 'INVALIDO',
          'Código não encontrado: ' + LCodigo);
        Auditoria(AConnection, ATransaction, AEmpresaId, AUsuarioId,
          'TALAO_BIPAGEM', 'BIPAGEM', 0, '',
          'CODIGO=' + LCodigo + '; RESULTADO=INVALIDO; ORIGEM=' + AOrigem);
        Result.Mensagem := Format(
          'Código de barras "%s" não corresponde a nenhum talão.', [LCodigo]);
        Exit;
      end;

      LTalaoId := LTalao.FieldByName('ID').AsLargeInt;
      LNumero := LTalao.FieldByName('NUMERO').AsInteger;
      LStatus := Trim(LTalao.FieldByName('STATUS').AsString);
      LItemId := LTalao.FieldByName('MAPA_PRODUCAO_ITEM_ID').AsLargeInt;
      LMapaId := LTalao.FieldByName('MAPA_ID').AsLargeInt;
      LMapaNumero := LTalao.FieldByName('MAPA_NUMERO').AsInteger;
      LStatusMapa := Trim(LTalao.FieldByName('MAPA_STATUS').AsString);
      LPedidoId := LTalao.FieldByName('PEDIDO_VENDA_ID').AsLargeInt;

      Result.TalaoId := LTalaoId;
      Result.NumeroTalao := LNumero;
      Result.Quantidade := LTalao.FieldByName('QUANTIDADE').AsFloat;
      Result.Produto := Trim(LTalao.FieldByName('PRODUTO').AsString);
      Result.MapaId := LMapaId;
      Result.MapaNumero := LMapaNumero;
      Result.StatusAnterior := LStatus;
      Result.StatusNovo := LStatus;
      LTalao.Close;

      { --- bipagens rejeitadas (mas auditadas) ----------------------- }
      if (LStatusMapa = 'CANCELADO') or (LStatus = 'CANCELADO') then
      begin
        GravarBipagem(AConnection, ATransaction, AEmpresaId, AUsuarioId,
          LTalaoId, 'BIPAGEM', AOrigem, 'INVALIDO',
          'Talão ou mapa cancelado');
        Auditoria(AConnection, ATransaction, AEmpresaId, AUsuarioId,
          'TALAO_BIPAGEM', 'BIPAGEM', LTalaoId, LStatus,
          'RESULTADO=INVALIDO; MOTIVO=CANCELADO');
        Result.Mensagem := Format(
          'Talão %d não pode ser bipado: está cancelado.', [LNumero]);
        Exit;
      end;

      if LStatusMapa = 'CONCLUIDO' then
      begin
        GravarBipagem(AConnection, ATransaction, AEmpresaId, AUsuarioId,
          LTalaoId, 'BIPAGEM', AOrigem, 'DUPLICADO',
          'Mapa já concluído');
        Result.Mensagem := Format(
          'Talão %d não pode ser bipado: o mapa nº %d já foi concluído.',
          [LNumero, LMapaNumero]);
        Result.Resultado := 'DUPLICADO';
        Exit;
      end;

      if LStatus = 'CONCLUIDO' then
      begin
        GravarBipagem(AConnection, ATransaction, AEmpresaId, AUsuarioId,
          LTalaoId, 'BIPAGEM', AOrigem, 'DUPLICADO',
          'Talão já concluído');
        Auditoria(AConnection, ATransaction, AEmpresaId, AUsuarioId,
          'TALAO_BIPAGEM', 'BIPAGEM', LTalaoId, LStatus,
          'RESULTADO=DUPLICADO; MOTIVO=JA_CONCLUIDO');
        Result.Resultado := 'DUPLICADO';
        Result.Mensagem := Format(
          'Talão %d já foi concluído anteriormente.', [LNumero]);
        Exit;
      end;

      { --- bipagens válidas: transição de status --------------------- }
      if (LStatus = 'GERADO') or (LStatus = 'IMPRESSO') then
      begin
        { INICIO: talão entra em produção }
        LUpd.SQL.Text :=
          'UPDATE TALAO SET STATUS = ''EM_PRODUCAO'', ' +
          '  DATA_INICIO = CURRENT_TIMESTAMP ' +
          'WHERE ID = :ID';
        LUpd.ParamByName('ID').AsLargeInt := LTalaoId;
        LUpd.ExecSQL;
        Auditoria(AConnection, ATransaction, AEmpresaId, AUsuarioId,
          'TALAO', 'BIPAGEM', LTalaoId, LStatus, 'EM_PRODUCAO');

        { item: pendente -> em produção }
        LUpd.Close;
        LUpd.SQL.Text :=
          'UPDATE MAPA_PRODUCAO_ITEM SET STATUS = ''EM_PRODUCAO'' ' +
          'WHERE ID = :ID AND STATUS = ''PENDENTE''';
        LUpd.ParamByName('ID').AsLargeInt := LItemId;
        LUpd.ExecSQL;

        { mapa: aberto -> em produção (fica registrado o início) }
        LUpd.Close;
        LUpd.SQL.Text :=
          'UPDATE MAPA_PRODUCAO SET STATUS = ''EM_PRODUCAO'', ' +
          '  DATA_INICIO = COALESCE(DATA_INICIO, CURRENT_TIMESTAMP) ' +
          'WHERE ID = :ID AND STATUS = ''ABERTO''';
        LUpd.ParamByName('ID').AsLargeInt := LMapaId;
        LUpd.ExecSQL;

        { andamento do consumo do mapa acompanha o início do talão }
        ProducaoAtualizarStatusConsumo(AConnection, ATransaction,
          AEmpresaId, AUsuarioId, LMapaId);

        Result.Etapa := 'INICIO';
        Result.StatusNovo := 'EM_PRODUCAO';
        Result.Mensagem := Format('Talão %d iniciado. Bom trabalho!',
          [LNumero]);
      end
      else
      begin
        { EM_PRODUCAO -> CONCLUSAO }
        LUpd.SQL.Text :=
          'UPDATE TALAO SET STATUS = ''CONCLUIDO'', ' +
          '  DATA_CONCLUSAO = CURRENT_TIMESTAMP ' +
          'WHERE ID = :ID';
        LUpd.ParamByName('ID').AsLargeInt := LTalaoId;
        LUpd.ExecSQL;
        Auditoria(AConnection, ATransaction, AEmpresaId, AUsuarioId,
          'TALAO', 'BIPAGEM', LTalaoId, 'EM_PRODUCAO', 'CONCLUIDO');

        { o item termina quando todos os seus talões forem concluídos }
        LUpd.Close;
        LUpd.SQL.Text :=
          'SELECT COUNT(*) AS FALTAM FROM TALAO ' +
          'WHERE MAPA_PRODUCAO_ITEM_ID = :ITEM ' +
          '  AND STATUS NOT IN (''CONCLUIDO'', ''CANCELADO'')';
        LUpd.ParamByName('ITEM').AsLargeInt := LItemId;
        LUpd.Open;
        if LUpd.FieldByName('FALTAM').AsInteger = 0 then
        begin
          LUpd.Close;
          LUpd.SQL.Text :=
            'UPDATE MAPA_PRODUCAO_ITEM SET STATUS = ''CONCLUIDO'' ' +
            'WHERE ID = :ID';
          LUpd.ParamByName('ID').AsLargeInt := LItemId;
          LUpd.ExecSQL;
          Auditoria(AConnection, ATransaction, AEmpresaId, AUsuarioId,
            'MAPA_PRODUCAO_ITEM', 'BIPAGEM', LItemId,
            'EM_PRODUCAO', 'CONCLUIDO');
        end
        else
          LUpd.Close;

        { o mapa termina quando todos os itens estiverem finalizados }
        LUpd.SQL.Text :=
          'SELECT COUNT(*) AS FALTAM FROM MAPA_PRODUCAO_ITEM ' +
          'WHERE MAPA_PRODUCAO_ID = :MAPA ' +
          '  AND STATUS NOT IN (''CONCLUIDO'', ''CANCELADO'')';
        LUpd.ParamByName('MAPA').AsLargeInt := LMapaId;
        LUpd.Open;
        LConcluiuMapa := LUpd.FieldByName('FALTAM').AsInteger = 0;
        LUpd.Close;

        if LConcluiuMapa then
        begin
          LUpd.SQL.Text :=
            'UPDATE MAPA_PRODUCAO SET STATUS = ''CONCLUIDO'', ' +
            '  DATA_FIM = CURRENT_TIMESTAMP ' +
            'WHERE ID = :ID';
          LUpd.ParamByName('ID').AsLargeInt := LMapaId;
          LUpd.ExecSQL;
          Auditoria(AConnection, ATransaction, AEmpresaId, AUsuarioId,
            'MAPA_PRODUCAO', 'CONCLUSAO', LMapaId,
            'EM_PRODUCAO', 'CONCLUIDO');
          Result.MapaConcluido := True;
        end;

        { o pedido é sempre reavaliado após uma conclusão de talão }
        ProducaoReavaliarPedido(AConnection, ATransaction, AEmpresaId,
          AUsuarioId, LPedidoId);

        { andamento do consumo do mapa acompanha a conclusão }
        ProducaoAtualizarStatusConsumo(AConnection, ATransaction,
          AEmpresaId, AUsuarioId, LMapaId);

        Result.Etapa := 'CONCLUSAO';
        Result.StatusNovo := 'CONCLUIDO';
        Result.Mensagem := Format('Talão %d concluído com sucesso.',
          [LNumero]);
        if LConcluiuMapa then
          Result.Mensagem := Result.Mensagem + sLineBreak +
            Format('Mapa nº %d concluído — produção finalizada!',
              [LMapaNumero]);
      end;

      { registro da bipagem aceita }
      GravarBipagem(AConnection, ATransaction, AEmpresaId, AUsuarioId,
        LTalaoId, Result.Etapa, AOrigem, 'OK', '');
      Result.Resultado := 'OK';
    except
      raise;
    end;
  finally
    LTalao.Free;
    LUpd.Free;
  end;
end;

end.
