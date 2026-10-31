unit uCaixaService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service da tela Financeiro > Caixa
  ------------------------------------------------------------
  Consulta dos caixas (CAIXA) e dos seus movimentos
  (MOVIMENTO_CAIXA). A escrita continua sendo do PDV
  (abertura do caixa, baixas de venda em RegistrarMovimentoCaixa);
  esta tela é só leitura.

  Regras:
    - saldo do caixa = entradas (TIPO 'E') menos saídas (TIPO 'S'),
      calculado no SQL;
    - CAST(COALESCE((subconsulta), 0) AS NUMERIC(18,4)): sem o CAST
      o Firebird devolve o campo como ftUnknown e a grade não mostra
      o valor (convenção já usada no resto do projeto);
    - escopo da empresa da sessão (mesma regra da CONFIGURACAO);
    - somente leitura: nada grava, nada audita.

  Suposição: PDV é o único responsável por abrir/fechar caixa e
  lançar movimentos - não há botão de abertura/fechamento aqui.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao;

type
  TCaixaService = class
  private
    FConexao: TConexao;
  public
    constructor Create;

    { Preenche AQuery (do chamador) com os caixas da empresa, já com o
      SALDO por caixa e o nome do usuário responsável. }
    procedure CarregarCaixas(AQuery: TSQLQuery);

    { Preenche AQuery (do chamador) com os movimentos de um caixa. }
    procedure CarregarMovimentos(AQuery: TSQLQuery; ACaixaId: Int64);

    { Preenche AQuery (do chamador) com ENTRADAS / SAIDAS / SALDO do caixa. }
    procedure CarregarResumo(AQuery: TSQLQuery; ACaixaId: Int64);
  end;

implementation

uses
  uSessao;

const
  { subconsulta de saldo: o CAST externo evita ftUnknown no Firebird }
  SQL_SALDO =
    'CAST(COALESCE((SELECT SUM(CASE MC.TIPO WHEN ''E'' THEN MC.VALOR ' +
    'WHEN ''S'' THEN -MC.VALOR ELSE 0 END) ' +
    'FROM MOVIMENTO_CAIXA MC WHERE MC.CAIXA_ID = C.ID), 0) ' +
    'AS NUMERIC(18,4))';

constructor TCaixaService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

procedure TCaixaService.CarregarCaixas(AQuery: TSQLQuery);
begin
  if AQuery = nil then
    raise Exception.Create('CarregarCaixas: query não informada.');

  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT C.ID, CAST(C.NUMERO AS VARCHAR(20)) AS NUMERO, ' +
    'U.NOME AS USUARIO, C.DATA_ABERTURA, C.VALOR_ABERTURA, C.STATUS, ' +
    'C.DATA_FECHAMENTO, C.VALOR_FECHAMENTO, ' +
    SQL_SALDO + ' AS SALDO ' +
    'FROM CAIXA C ' +
    'LEFT JOIN USUARIO U ON U.ID = C.USUARIO_ID ' +
    'WHERE (C.EMPRESA_ID = :EMP OR C.EMPRESA_ID IS NULL) ' +
    'ORDER BY C.ID DESC';
  AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  AQuery.Open;
end;

procedure TCaixaService.CarregarMovimentos(AQuery: TSQLQuery;
  ACaixaId: Int64);
begin
  if AQuery = nil then
    raise Exception.Create('CarregarMovimentos: query não informada.');
  if ACaixaId <= 0 then
    raise Exception.Create('Caixa inválido.');

  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT MC.ID, ' +
    'CASE MC.TIPO WHEN ''E'' THEN ''ENTRADA'' WHEN ''S'' THEN ''SAIDA'' ' +
    'ELSE MC.TIPO END AS TIPO, MC.VALOR, MC.DESCRICAO, MC.DATA_MOVIMENTO, ' +
    'U.NOME AS USUARIO FROM MOVIMENTO_CAIXA MC ' +
    'LEFT JOIN USUARIO U ON U.ID = MC.USUARIO_ID ' +
    'WHERE MC.CAIXA_ID = :CX ORDER BY MC.ID';
  AQuery.ParamByName('CX').AsLargeInt := ACaixaId;
  AQuery.Open;
end;

procedure TCaixaService.CarregarResumo(AQuery: TSQLQuery; ACaixaId: Int64);
begin
  if AQuery = nil then
    raise Exception.Create('CarregarResumo: query não informada.');
  if ACaixaId <= 0 then
    raise Exception.Create('Caixa inválido.');

  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT ' +
    'CAST(COALESCE(SUM(CASE WHEN MC.TIPO = ''E'' THEN MC.VALOR ELSE 0 END), 0) ' +
    'AS NUMERIC(18,4)) AS ENTRADAS, ' +
    'CAST(COALESCE(SUM(CASE WHEN MC.TIPO = ''S'' THEN MC.VALOR ELSE 0 END), 0) ' +
    'AS NUMERIC(18,4)) AS SAIDAS, ' +
    'CAST(COALESCE(SUM(CASE WHEN MC.TIPO = ''E'' THEN MC.VALOR ' +
    'WHEN MC.TIPO = ''S'' THEN -MC.VALOR ELSE 0 END), 0) ' +
    'AS NUMERIC(18,4)) AS SALDO ' +
    'FROM MOVIMENTO_CAIXA MC WHERE MC.CAIXA_ID = :CX';
  AQuery.ParamByName('CX').AsLargeInt := ACaixaId;
  AQuery.Open;
end;

end.
