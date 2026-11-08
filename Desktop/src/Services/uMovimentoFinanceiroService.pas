unit uMovimentoFinanceiroService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service da movimentação financeira
  ------------------------------------------------------------
  Regras que antes estavam dentro de uFrmMovimentoFinanceiro:

    - tipo somente 'E' (entrada) ou 'S' (saída);
    - descrição obrigatória (até 120), categoria até 30;
    - valor maior que zero e data de movimento válida;
    - documento opcional (0 = nulo) e não negativo;
    - inclusão grava EMPRESA_ID/USUARIO_ID da sessão e DATA_CADASTRO
      pela trigger TRG_MOVIMENTO_FINANCEIRO_BI;
    - alteração e exclusão só alcançam registro da empresa da sessão
      (antes a tela atualizava/apagava qualquer ID e listava todas as
      empresas);
    - listagem no escopo da empresa, com pesquisa por
      descrição/categoria/documento e ordem decrescente de data e ID.

  Toda escrita abre e confirma a própria transação e registra
  auditoria em LOG_SISTEMA.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao;

type
  { Dados de um movimento financeiro (usado na tela e nos testes). }
  TMovimentoFinanceiroDados = record
    Id: Int64;
    DataMovimento: TDateTime;
    Tipo: Char;
    Categoria: string;
    Descricao: string;
    Valor: Double;
    DocumentoId: Int64;
  end;

  { TMovimentoFinanceiroService }
  TMovimentoFinanceiroService = class
  private
    FConexao: TConexao;

    procedure Validar(const ADados: TMovimentoFinanceiroDados);
    function CarregarDoEmpresa(AId: Int64;
      out ADados: TMovimentoFinanceiroDados): Boolean;
  public
    constructor Create;

    { Inclui (Id = 0) ou altera um movimento e devolve o ID. }
    function SalvarMovimento(
      const ADados: TMovimentoFinanceiroDados): Int64;

    { Exclui um movimento da empresa da sessão. }
    procedure ExcluirMovimento(AId: Int64);

    { Carrega um movimento da empresa; False quando não existe. }
    function BuscarMovimento(AId: Int64;
      out ADados: TMovimentoFinanceiroDados): Boolean;

    { Preenche AQuery com os movimentos da empresa. AFiltro pesquisa
      descrição, categoria e documento. }
    procedure CarregarMovimentos(AQuery: TSQLQuery;
      const AFiltro: string = '');

    { Sugestões da tela (o tipo guarda 'E'/'S' em Objects). }
    procedure CarregarTipos(AItems: TStrings);
    procedure CarregarCategorias(AItems: TStrings);
  end;

{ Tipo de movimento financeiro válido: 'E' (entrada) ou 'S' (saída). }
function TipoMovimentoFinanceiroValido(ATipo: Char): Boolean;

implementation

uses
  uSessao, uAuditoria;

const
  TAMANHO_CATEGORIA = 30;
  TAMANHO_DESCRICAO = 120;
  { O CAST do parâmetro evita "string right truncation" no filtro. }
  SQL_FILTRO_TEXTO = 'VARCHAR(1000)';

function TipoMovimentoFinanceiroValido(ATipo: Char): Boolean;
begin
  Result := (ATipo = 'E') or (ATipo = 'S');
end;

constructor TMovimentoFinanceiroService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

procedure TMovimentoFinanceiroService.Validar(
  const ADados: TMovimentoFinanceiroDados);
begin
  if not TipoMovimentoFinanceiroValido(ADados.Tipo) then
    raise Exception.Create('Tipo de movimento inválido (use E ou S).');
  if Trim(ADados.Descricao) = '' then
    raise Exception.Create('O campo Descrição é obrigatório.');
  if Length(Trim(ADados.Descricao)) > TAMANHO_DESCRICAO then
    raise Exception.CreateFmt('A descrição deve ter no máximo %d caracteres.',
      [TAMANHO_DESCRICAO]);
  if Length(Trim(ADados.Categoria)) > TAMANHO_CATEGORIA then
    raise Exception.CreateFmt('A categoria deve ter no máximo %d caracteres.',
      [TAMANHO_CATEGORIA]);
  if ADados.DataMovimento = 0 then
    raise Exception.Create('Informe uma data válida para o movimento.');
  if ADados.Valor <= 0 then
    raise Exception.Create('O valor do movimento deve ser maior que zero.');
  if ADados.DocumentoId < 0 then
    raise Exception.Create('O documento não pode ser negativo.');
end;

function TMovimentoFinanceiroService.CarregarDoEmpresa(AId: Int64;
  out ADados: TMovimentoFinanceiroDados): Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  ADados.Id := 0;
  ADados.DataMovimento := 0;
  ADados.Tipo := 'E';
  ADados.Categoria := '';
  ADados.Descricao := '';
  ADados.Valor := 0;
  ADados.DocumentoId := 0;
  if AId <= 0 then
    Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID, DATA_MOVIMENTO, TIPO, CATEGORIA, DESCRICAO, VALOR, ' +
      '  DOCUMENTO_ID FROM MOVIMENTO_FINANCEIRO ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      ADados.Id := LQuery.FieldByName('ID').AsLargeInt;
      ADados.DataMovimento :=
        LQuery.FieldByName('DATA_MOVIMENTO').AsDateTime;
      ADados.Tipo := 'E';
      if Trim(LQuery.FieldByName('TIPO').AsString) = 'S' then
        ADados.Tipo := 'S';
      ADados.Categoria := Trim(LQuery.FieldByName('CATEGORIA').AsString);
      ADados.Descricao := LQuery.FieldByName('DESCRICAO').AsString;
      ADados.Valor := LQuery.FieldByName('VALOR').AsFloat;
      ADados.DocumentoId := LQuery.FieldByName('DOCUMENTO_ID').AsLargeInt;
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TMovimentoFinanceiroService.SalvarMovimento(
  const ADados: TMovimentoFinanceiroDados): Int64;
var
  LQuery: TSQLQuery;
  LAntes: TMovimentoFinanceiroDados;
  LDescricao, LCategoria: string;
begin
  Validar(ADados);

  LDescricao := Trim(ADados.Descricao);
  LCategoria := Trim(ADados.Categoria);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;

      if ADados.Id > 0 then
      begin
        if not CarregarDoEmpresa(ADados.Id, LAntes) then
          raise Exception.Create('Movimento não encontrado nesta empresa.');

        LQuery.SQL.Text :=
          'UPDATE MOVIMENTO_FINANCEIRO SET DATA_MOVIMENTO = :DATA, ' +
          '  TIPO = :TIPO, CATEGORIA = :CAT, DESCRICAO = :DESC, ' +
          '  VALOR = :VALOR, DOCUMENTO_ID = :DOC ' +
          'WHERE ID = :ID AND EMPRESA_ID = :EMP';
        LQuery.ParamByName('ID').AsLargeInt := ADados.Id;
        LQuery.ParamByName('EMP').AsLargeInt :=
          TSessao.GetInstance.EmpresaId;
      end
      else
      begin
        LQuery.SQL.Text :=
          'INSERT INTO MOVIMENTO_FINANCEIRO (EMPRESA_ID, DATA_MOVIMENTO, ' +
          '  TIPO, CATEGORIA, DESCRICAO, VALOR, DOCUMENTO_ID, USUARIO_ID) ' +
          'VALUES (:EMP, :DATA, :TIPO, :CAT, :DESC, :VALOR, :DOC, :USR) ' +
          'RETURNING ID';
        LQuery.ParamByName('EMP').AsLargeInt :=
          TSessao.GetInstance.EmpresaId;
        LQuery.ParamByName('USR').AsLargeInt :=
          TSessao.GetInstance.UsuarioId;
      end;

      LQuery.ParamByName('DATA').AsDate := Trunc(ADados.DataMovimento);
      LQuery.ParamByName('TIPO').AsString := ADados.Tipo;
      if LCategoria <> '' then
        LQuery.ParamByName('CAT').AsString := LCategoria
      else
        LQuery.ParamByName('CAT').Clear;
      LQuery.ParamByName('DESC').AsString := LDescricao;
      LQuery.ParamByName('VALOR').AsFloat := ADados.Valor;
      if ADados.DocumentoId > 0 then
        LQuery.ParamByName('DOC').AsLargeInt := ADados.DocumentoId
      else
        LQuery.ParamByName('DOC').Clear;

      if ADados.Id > 0 then
      begin
        LQuery.ExecSQL;
        if LQuery.RowsAffected <> 1 then
          raise Exception.Create(
            'Não foi possível alterar o movimento: ele mudou de empresa.');
        Result := ADados.Id;
        RegistrarAuditoriaSegura('MOVIMENTO_FINANCEIRO', 'UPDATE', Result,
          ResumoAuditoria([
            'TIPO=' + LAntes.Tipo,
            'CATEGORIA=' + LAntes.Categoria,
            'DESCRICAO=' + LAntes.Descricao,
            'VALOR=' + FloatToStr(LAntes.Valor)]),
          ResumoAuditoria([
            'TIPO=' + ADados.Tipo,
            'CATEGORIA=' + LCategoria,
            'DESCRICAO=' + LDescricao,
            'VALOR=' + FloatToStr(ADados.Valor)]));
      end
      else
      begin
        LQuery.Open;
        Result := LQuery.FieldByName('ID').AsLargeInt;
        LQuery.Close;
        RegistrarAuditoriaSegura('MOVIMENTO_FINANCEIRO', 'INSERT', Result, '',
          ResumoAuditoria([
            'DATA_MOVIMENTO=' + DateToStr(Trunc(ADados.DataMovimento)),
            'TIPO=' + ADados.Tipo,
            'CATEGORIA=' + LCategoria,
            'DESCRICAO=' + LDescricao,
            'VALOR=' + FloatToStr(ADados.Valor),
            'DOCUMENTO_ID=' + IntToStr(ADados.DocumentoId)]));
      end;

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroService.ExcluirMovimento(AId: Int64);
var
  LQuery: TSQLQuery;
  LAntes: TMovimentoFinanceiroDados;
begin
  if AId <= 0 then
    raise Exception.Create('Selecione um movimento para excluir.');
  if not CarregarDoEmpresa(AId, LAntes) then
    raise Exception.Create('Movimento não encontrado nesta empresa.');

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'DELETE FROM MOVIMENTO_FINANCEIRO ' +
        'WHERE ID = :ID AND EMPRESA_ID = :EMP';
      LQuery.ParamByName('ID').AsLargeInt := AId;
      LQuery.ParamByName('EMP').AsLargeInt :=
        TSessao.GetInstance.EmpresaId;
      LQuery.ExecSQL;
      if LQuery.RowsAffected <> 1 then
        raise Exception.Create(
          'Não foi possível excluir o movimento: ele mudou de empresa.');

      RegistrarAuditoriaSegura('MOVIMENTO_FINANCEIRO', 'DELETE', AId,
        ResumoAuditoria([
          'DATA_MOVIMENTO=' + DateToStr(Trunc(LAntes.DataMovimento)),
          'TIPO=' + LAntes.Tipo,
          'CATEGORIA=' + LAntes.Categoria,
          'DESCRICAO=' + LAntes.Descricao,
          'VALOR=' + FloatToStr(LAntes.Valor)]),
        '');
      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TMovimentoFinanceiroService.BuscarMovimento(AId: Int64;
  out ADados: TMovimentoFinanceiroDados): Boolean;
begin
  Result := CarregarDoEmpresa(AId, ADados);
end;

procedure TMovimentoFinanceiroService.CarregarMovimentos(AQuery: TSQLQuery;
  const AFiltro: string);
var
  LSQL: string;
begin
  if AQuery = nil then
    raise Exception.Create('CarregarMovimentos: query não informada.');

  LSQL :=
    'SELECT ID, DATA_MOVIMENTO, TIPO, CATEGORIA, DESCRICAO, VALOR, ' +
    '  DOCUMENTO_ID FROM MOVIMENTO_FINANCEIRO WHERE EMPRESA_ID = :EMP';

  if Trim(AFiltro) <> '' then
    LSQL := LSQL +
      ' AND (UPPER(COALESCE(DESCRICAO, '''')) CONTAINING ' +
      'UPPER(CAST(:PESQ AS ' + SQL_FILTRO_TEXTO + '))' +
      ' OR UPPER(COALESCE(CATEGORIA, '''')) CONTAINING ' +
      'UPPER(CAST(:PESQ2 AS ' + SQL_FILTRO_TEXTO + '))' +
      ' OR CAST(DOCUMENTO_ID AS VARCHAR(20)) CONTAINING :PESQ3)';

  LSQL := LSQL + ' ORDER BY DATA_MOVIMENTO DESC, ID DESC';

  AQuery.Close;
  AQuery.SQL.Text := LSQL;
  AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  if Trim(AFiltro) <> '' then
  begin
    AQuery.ParamByName('PESQ').AsString := Trim(AFiltro);
    AQuery.ParamByName('PESQ2').AsString := Trim(AFiltro);
    AQuery.ParamByName('PESQ3').AsString := Trim(AFiltro);
  end;
  AQuery.Open;
end;

procedure TMovimentoFinanceiroService.CarregarTipos(AItems: TStrings);
begin
  if AItems = nil then
    raise Exception.Create('CarregarTipos: lista não informada.');
  AItems.Clear;
  AItems.AddObject('Entrada', TObject(PtrInt(Ord('E'))));
  AItems.AddObject('Saída', TObject(PtrInt(Ord('S'))));
end;

procedure TMovimentoFinanceiroService.CarregarCategorias(AItems: TStrings);
begin
  if AItems = nil then
    raise Exception.Create('CarregarCategorias: lista não informada.');
  AItems.Clear;
  AItems.Add('RECEBIMENTO');
  AItems.Add('PAGAMENTO');
  AItems.Add('TRANSFERENCIA');
  AItems.Add('OUTRAS');
end;

end.
