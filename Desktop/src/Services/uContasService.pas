unit uContasService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service de contas a pagar e a receber
  ------------------------------------------------------------
  Regras que antes estavam dentro de uFrmContasPagar e
  uFrmContasReceber:

    - plano financeiro: usa o primeiro FINANCEIRO da empresa com
      TIPO 'P' (pagar) ou 'R' (receber); cria o plano padrão quando
      não existe. CONTA_PAGAR.FINANCEIRO_ID e
      CONTA_RECEBER.FINANCEIRO_ID usam o domínio DM_ID (NOT NULL),
      então precisam ser sempre informados (o formulário de contas
      a receber não gravava e a inclusão falhava);
    - criação: descrição obrigatória, valor maior que zero e
      vencimento informado; status 'A' e parcela 1;
    - baixa: só conta em aberto ('A'), grava STATUS 'P',
      DATA_PAGAMENTO = CURRENT_DATE e VALOR_PAGO = VALOR; conta
      inexistente ou já baixada/cancelada é recusada;
    - listagem: período de vencimento, filtro de status e pesquisa
      por fornecedor/cliente/descrição, sempre no escopo da empresa
      da sessão e em ordem de vencimento.

  Toda escrita abre e confirma a própria transação (mesmo padrão dos
  Services das notas) e registra auditoria em LOG_SISTEMA.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao;

type
  { TContasService }
  TContasService = class
  private
    FConexao: TConexao;

    function GarantirPlano(ATipo: Char; const ADescricao: string): Int64;
    procedure ValidarConta(const ADescricao: string; AValor: Double;
      AVencimento: TDateTime);
    procedure BaixarConta(const ATabela, AEntidade: string; AId: Int64);
    procedure CarregarContas(AQuery: TSQLQuery; ADataInicio, ADataFim: TDateTime;
      const AStatus, AFiltro: string; APagar: Boolean);
  public
    constructor Create;

    { Plano financeiro da empresa (cria o padrão quando não existe). }
    function GarantirFinanceiroPagar: Int64;
    function GarantirFinanceiroReceber: Int64;

    { Cria a conta em aberto e devolve o ID gerado. }
    function CriarContaPagar(const ADescricao: string; AValor: Double;
      AVencimento: TDateTime; AFornecedorId: Int64 = 0): Int64;
    function CriarContaReceber(const ADescricao: string; AValor: Double;
      AVencimento: TDateTime; AClienteId: Int64 = 0): Int64;

    { Baixa a conta em aberto (recusa inexistente/paga/cancelada). }
    procedure BaixarContaPagar(AId: Int64);
    procedure BaixarContaReceber(AId: Int64);

    { Preenche AQuery com as contas do período. AStatus: '' = todas,
      'A' = abertas, 'P' = pagas, 'C' = canceladas. AFiltro pesquisa
      no nome e na descrição. }
    procedure CarregarContasPagar(AQuery: TSQLQuery;
      ADataInicio, ADataFim: TDateTime;
      const AStatus: string = ''; const AFiltro: string = '');
    procedure CarregarContasReceber(AQuery: TSQLQuery;
      ADataInicio, ADataFim: TDateTime;
      const AStatus: string = ''; const AFiltro: string = '');
  end;

implementation

uses
  uSessao, uAuditoria;

const
  { CONTA_PAGAR e CONTA_RECEBER não têm coluna própria de filtro de
    texto: o CAST do parâmetro evita "string right truncation" quando
    o texto digitado é maior que a coluna (mesma lição do caixa). }
  SQL_FILTRO_TEXTO = 'VARCHAR(1000)';

constructor TContasService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TContasService.GarantirPlano(ATipo: Char;
  const ADescricao: string): Int64;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
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

function TContasService.GarantirFinanceiroPagar: Int64;
begin
  Result := GarantirPlano('P', 'Contas a pagar de compras');
end;

function TContasService.GarantirFinanceiroReceber: Int64;
begin
  Result := GarantirPlano('R', 'Contas a receber de vendas');
end;

procedure TContasService.ValidarConta(const ADescricao: string;
  AValor: Double; AVencimento: TDateTime);
begin
  if Trim(ADescricao) = '' then
    raise Exception.Create('Informe a descrição da conta.');
  if AValor <= 0 then
    raise Exception.Create('O valor da conta deve ser maior que zero.');
  if AVencimento = 0 then
    raise Exception.Create('Informe o vencimento da conta.');
end;

function TContasService.CriarContaPagar(const ADescricao: string;
  AValor: Double; AVencimento: TDateTime; AFornecedorId: Int64): Int64;
var
  LQuery: TSQLQuery;
  LFinanceiroId: Int64;
begin
  ValidarConta(ADescricao, AValor, AVencimento);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;

      { FINANCEIRO_ID e FORNECEDOR_ID são DM_ID (NOT NULL);
        0 = sem vínculo com fornecedor }
      LFinanceiroId := GarantirFinanceiroPagar;

      LQuery.SQL.Text :=
        'INSERT INTO CONTA_PAGAR (EMPRESA_ID, FINANCEIRO_ID, FORNECEDOR_ID, ' +
        '  DESCRICAO, VALOR, DATA_VENCIMENTO, STATUS, PARCELA) ' +
        'VALUES (:EMP, :FIN, :FOR, :DESC, :VLR, :VENC, ''A'', 1) ' +
        'RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('FIN').AsLargeInt := LFinanceiroId;
      LQuery.ParamByName('FOR').AsLargeInt := AFornecedorId;
      LQuery.ParamByName('DESC').AsString := Trim(ADescricao);
      LQuery.ParamByName('VLR').AsFloat := AValor;
      LQuery.ParamByName('VENC').AsDate := AVencimento;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      RegistrarAuditoriaSegura('CONTA_PAGAR', 'INSERT', Result, '',
        ResumoAuditoria([
          'DESCRICAO=' + Trim(ADescricao),
          'VALOR=' + FloatToStr(AValor),
          'VENCIMENTO=' + DateToStr(AVencimento),
          'STATUS=A']));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TContasService.CriarContaReceber(const ADescricao: string;
  AValor: Double; AVencimento: TDateTime; AClienteId: Int64): Int64;
var
  LQuery: TSQLQuery;
  LFinanceiroId: Int64;
begin
  ValidarConta(ADescricao, AValor, AVencimento);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;

      { FINANCEIRO_ID e CLIENTE_ID são DM_ID (NOT NULL);
        0 = sem vínculo com cliente }
      LFinanceiroId := GarantirFinanceiroReceber;

      LQuery.SQL.Text :=
        'INSERT INTO CONTA_RECEBER (EMPRESA_ID, FINANCEIRO_ID, CLIENTE_ID, ' +
        '  DESCRICAO, VALOR, DATA_VENCIMENTO, STATUS, PARCELA) ' +
        'VALUES (:EMP, :FIN, :CLI, :DESC, :VLR, :VENC, ''A'', 1) ' +
        'RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('FIN').AsLargeInt := LFinanceiroId;
      LQuery.ParamByName('CLI').AsLargeInt := AClienteId;
      LQuery.ParamByName('DESC').AsString := Trim(ADescricao);
      LQuery.ParamByName('VLR').AsFloat := AValor;
      LQuery.ParamByName('VENC').AsDate := AVencimento;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      RegistrarAuditoriaSegura('CONTA_RECEBER', 'INSERT', Result, '',
        ResumoAuditoria([
          'DESCRICAO=' + Trim(ADescricao),
          'VALOR=' + FloatToStr(AValor),
          'VENCIMENTO=' + DateToStr(AVencimento),
          'STATUS=A']));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TContasService.BaixarConta(const ATabela, AEntidade: string;
  AId: Int64);
var
  LQuery: TSQLQuery;
  LStatus: string;
begin
  if AId <= 0 then
    raise Exception.Create(AEntidade + ': ID inválido.');

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;

      LQuery.SQL.Text :=
        'SELECT STATUS FROM ' + ATabela +
        ' WHERE ID = :ID AND EMPRESA_ID = :EMP';
      LQuery.ParamByName('ID').AsLargeInt := AId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.Open;
      if LQuery.IsEmpty then
        raise Exception.Create(AEntidade + ' não encontrada.');
      LStatus := Trim(LQuery.FieldByName('STATUS').AsString);
      LQuery.Close;

      if LStatus <> 'A' then
        raise Exception.Create('Apenas contas em aberto podem ser baixadas.');

      LQuery.SQL.Text :=
        'UPDATE ' + ATabela + ' SET STATUS = ''P'', ' +
        '  DATA_PAGAMENTO = CURRENT_DATE, VALOR_PAGO = VALOR ' +
        'WHERE ID = :ID AND STATUS = ''A''';
      LQuery.ParamByName('ID').AsLargeInt := AId;
      LQuery.ExecSQL;
      if LQuery.RowsAffected <> 1 then
        raise Exception.Create('Apenas contas em aberto podem ser baixadas.');

      RegistrarAuditoriaSegura(ATabela, 'BAIXA', AId,
        'STATUS=A', 'STATUS=P; VALOR_PAGO=VALOR');

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TContasService.BaixarContaPagar(AId: Int64);
begin
  BaixarConta('CONTA_PAGAR', 'Conta a pagar', AId);
end;

procedure TContasService.BaixarContaReceber(AId: Int64);
begin
  BaixarConta('CONTA_RECEBER', 'Conta a receber', AId);
end;

procedure TContasService.CarregarContas(AQuery: TSQLQuery;
  ADataInicio, ADataFim: TDateTime; const AStatus, AFiltro: string;
  APagar: Boolean);
var
  LSQL: string;
  LTabela, Alias, Juncao, CampoNome, CampoTipo: string;
begin
  if AQuery = nil then
    raise Exception.Create('CarregarContas: query não informada.');
  if ADataFim < ADataInicio then
    raise Exception.Create('A data final não pode ser anterior à inicial.');

  if APagar then
  begin
    LTabela := 'CONTA_PAGAR';
    Alias := 'CP';
    Juncao := 'LEFT JOIN PESSOA F ON F.ID = CP.FORNECEDOR_ID AND F.TIPO = ''F''';
    CampoNome := 'COALESCE(F.NOME_FANTASIA, F.NOME)';
    CampoTipo := 'FORNECEDOR';
  end
  else
  begin
    LTabela := 'CONTA_RECEBER';
    Alias := 'CR';
    Juncao := 'LEFT JOIN PESSOA C ON C.ID = CR.CLIENTE_ID AND C.TIPO = ''C''';
    CampoNome := 'C.NOME';
    CampoTipo := 'CLIENTE';
  end;

  LSQL :=
    'SELECT ' + Alias + '.ID, ' + CampoNome + ' AS ' + CampoTipo + ', ' +
    Alias + '.DESCRICAO, ' + Alias + '.VALOR, ' +
    Alias + '.DATA_VENCIMENTO, ' + Alias + '.DATA_PAGAMENTO, ' +
    Alias + '.VALOR_PAGO, ' +
    'CASE ' + Alias + '.STATUS WHEN ''A'' THEN ''Aberta'' ' +
    'WHEN ''P'' THEN ''Paga'' WHEN ''C'' THEN ''Cancelada'' END AS STATUS_DESC ' +
    'FROM ' + LTabela + ' ' + Alias + ' ' + Juncao + ' ' +
    'WHERE ' + Alias + '.EMPRESA_ID = :EMP ' +
    '  AND ' + Alias + '.DATA_VENCIMENTO BETWEEN :DI AND :DF';

  if Trim(AStatus) <> '' then
    LSQL := LSQL + ' AND ' + Alias + '.STATUS = :STATUS';

  if Trim(AFiltro) <> '' then
    LSQL := LSQL + ' AND (UPPER(COALESCE(' + CampoNome + ', '''')) ' +
      'CONTAINING UPPER(CAST(:PESQ AS ' + SQL_FILTRO_TEXTO + '))' +
      ' OR UPPER(COALESCE(' + Alias + '.DESCRICAO, '''')) ' +
      'CONTAINING UPPER(CAST(:PESQ2 AS ' + SQL_FILTRO_TEXTO + ')))';

  LSQL := LSQL + ' ORDER BY ' + Alias + '.DATA_VENCIMENTO';

  AQuery.Close;
  AQuery.SQL.Text := LSQL;
  AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  AQuery.ParamByName('DI').AsDate := ADataInicio;
  AQuery.ParamByName('DF').AsDate := ADataFim;
  if Trim(AStatus) <> '' then
    AQuery.ParamByName('STATUS').AsString := Trim(AStatus);
  if Trim(AFiltro) <> '' then
  begin
    AQuery.ParamByName('PESQ').AsString := Trim(AFiltro);
    AQuery.ParamByName('PESQ2').AsString := Trim(AFiltro);
  end;
  AQuery.Open;
end;

procedure TContasService.CarregarContasPagar(AQuery: TSQLQuery;
  ADataInicio, ADataFim: TDateTime; const AStatus, AFiltro: string);
begin
  CarregarContas(AQuery, ADataInicio, ADataFim, AStatus, AFiltro, True);
end;

procedure TContasService.CarregarContasReceber(AQuery: TSQLQuery;
  ADataInicio, ADataFim: TDateTime; const AStatus, AFiltro: string);
begin
  CarregarContas(AQuery, ADataInicio, ADataFim, AStatus, AFiltro, False);
end;

end.
