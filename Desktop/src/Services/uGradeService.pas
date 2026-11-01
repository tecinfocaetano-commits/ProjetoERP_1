unit uGradeService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 2 - Service: GRADE
  Regras da grade (cadastro, tamanhos, config USA_GRADE e grades
  efetivas do item do pedido / do item do mapa).

  Tabelas (migração 016):
    GRADE, GRADE_TAMANHO, ITEM_PEDIDO_GRADE,
    MAPA_PRODUCAO_ITEM_GRADE, PRODUTO.GRADE_ID,
    CONFIGURACAO.USA_GRADE.

  Regras:
    - USA_GRADE é o único interruptor: 'N' (padrão) => a grade não
      aparece nem no pedido nem no mapa;
    - a grade efetiva do pedido é um snapshot (tamanho + quantidade);
      a do mapa é editável e pode ser copiada do pedido;
    - o total do item é a soma das quantidades da grade;
    - SQL parametrizado; gravações em transação + auditoria.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uGrade, uSessao;

type
  TGradeService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;

    function NovaConsulta: TSQLQuery;
    procedure Validar(AObj: TGrade);
    procedure ValidarTamanhos(const ATamanhos: TGradeTamanhos;
      AExigirPeloMenosUm: Boolean);
    procedure GravarTamanhos(AGradeId: Int64; const ATamanhos: TGradeTamanhos);
    function LerTamanhos(AGradeId: Int64): TGradeTamanhos;
    procedure GravarGradeEfetiva(const ATabela, ACampoDono: string;
      ADonoId: Int64; const ATamanhos: TGradeTamanhos);
    function LerGradeEfetiva(const ATabela, ACampoDono: string;
      ADonoId: Int64): TGradeTamanhos;
    function ValorConfiguracao(const AChave: string; out AValor: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { cadastro }
    function BuscarPorId(AId: Int64): TGrade;
    procedure Carregar(AQuery: TSQLQuery; const AFiltro: string = '');
    function Inserir(AObj: TGrade): Int64;
    function Atualizar(AObj: TGrade): Boolean;
    function Excluir(AId: Int64): Boolean;
    function ListarTamanhos(AGradeId: Int64): TGradeTamanhos;

    { preferência da empresa }
    function UsaGrade: Boolean;
    procedure DefinirUsaGrade(AUsar: Boolean);

    { grade efetiva: item do pedido }
    function GradeDoItemPedido(AItemPedidoId: Int64): TGradeTamanhos;
    procedure SalvarGradeItemPedido(AItemPedidoId: Int64;
      const ATamanhos: TGradeTamanhos);
    { copia os tamanhos da grade (quantidade 0) para o item do pedido }
    function CopiarGradeParaItemPedido(AItemPedidoId, AGradeId: Int64): Integer;

    { grade efetiva: item do mapa (editável) }
    function GradeDoMapaItem(AMapaItemId: Int64): TGradeTamanhos;
    procedure SalvarGradeMapaItem(AMapaItemId: Int64;
      const ATamanhos: TGradeTamanhos);
    { item do pedido ligado ao item do mapa (0 quando não houver) }
    function ItemPedidoDoMapaItem(AMapaItemId: Int64): Int64;
    { copia a grade (com quantidades) do item do pedido para o item do mapa }
    function CopiarGradeDoPedidoParaMapa(AMapaItemId: Int64): Integer;

    { grade padrão do produto (PRODUTO.GRADE_ID) }
    function GradeDoProduto(AProdutoId: Int64): Int64;
    procedure DefinirGradeDoProduto(AProdutoId, AGradeId: Int64);
  end;

implementation

constructor TGradeService.Create;
begin
  FRepo := TRepositoryBase.Create('GRADE');
  inherited Create(FRepo);
end;

destructor TGradeService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

function TGradeService.NovaConsulta: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := Conexao.Connection;
  Result.Transaction := Conexao.Transaction;
end;

procedure TGradeService.ValidarTamanhos(const ATamanhos: TGradeTamanhos;
  AExigirPeloMenosUm: Boolean);
var
  LLista: TStringList;
  LTam: string;
  I: Integer;
begin
  LLista := TStringList.Create;
  try
    LLista.CaseSensitive := False;
    for I := 0 to High(ATamanhos) do
    begin
      LTam := Trim(ATamanhos[I].Tamanho);
      if LTam = '' then
        Continue;
      if Length(LTam) > 10 then
        raise Exception.CreateFmt(
          'O tamanho "%s" tem mais de 10 caracteres.', [LTam]);
      if LLista.IndexOf(LTam) >= 0 then
        raise Exception.CreateFmt('O tamanho "%s" está repetido na grade.', [LTam]);
      LLista.Add(LTam);
    end;

    if AExigirPeloMenosUm and (LLista.Count = 0) then
      raise Exception.Create('Informe pelo menos um tamanho na grade.');
  finally
    LLista.Free;
  end;
end;

procedure TGradeService.Validar(AObj: TGrade);
begin
  ValidarCampoObrigatorio(AObj.Nome, 'Nome');
  if Length(Trim(AObj.Nome)) > 60 then
    raise Exception.Create('O nome da grade pode ter no máximo 60 caracteres.');
  if (AObj.Tipo <> 'CALCADO') and (AObj.Tipo <> 'CONFECCAO') and
     (AObj.Tipo <> 'GRUPO') and (AObj.Tipo <> 'OUTRO') then
    raise Exception.CreateFmt('Tipo de grade inválido: "%s".', [AObj.Tipo]);
  ValidarTamanhos(AObj.Tamanhos, True);
end;

function TGradeService.BuscarPorId(AId: Int64): TGrade;
var
  LQuery: TSQLQuery;
begin
  Result := TGrade.Create;
  try
    LQuery := FRepo.BuscarPorId(AId);
    try
      if not LQuery.IsEmpty then
      begin
        Result.Id := LQuery.FieldByName('ID').AsLargeInt;
        Result.EmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
        Result.Nome := LQuery.FieldByName('NOME').AsString;
        Result.Tipo := Trim(LQuery.FieldByName('TIPO').AsString);
        Result.Ativo := LQuery.FieldByName('ATIVO').AsString;
        Result.Observacao := LQuery.FieldByName('OBSERVACAO').AsString;
        Result.Tamanhos := LerTamanhos(AId);
      end
      else
        FreeAndNil(Result);
    finally
      LQuery.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TGradeService.Carregar(AQuery: TSQLQuery; const AFiltro: string);
var
  LTermo: string;
begin
  if AQuery = nil then
    raise Exception.Create('Carregar: query não informada.');

  LTermo := Trim(AFiltro);
  AQuery.Close;
  if LTermo = '' then
    AQuery.SQL.Text :=
      'SELECT ID, NOME, TIPO, ATIVO FROM GRADE WHERE EMPRESA_ID = :EMP ' +
      'ORDER BY NOME'
  else
    AQuery.SQL.Text :=
      'SELECT ID, NOME, TIPO, ATIVO FROM GRADE WHERE EMPRESA_ID = :EMP ' +
      'AND UPPER(NOME) CONTAINING UPPER(:FILTRO) ORDER BY NOME';

  AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  if LTermo <> '' then
    AQuery.ParamByName('FILTRO').AsString := LTermo;
  AQuery.Open;
end;

function TGradeService.LerTamanhos(AGradeId: Int64): TGradeTamanhos;
var
  LQuery: TSQLQuery;
begin
  Result := nil;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT ID, TAMANHO, ORDEM, ATIVO FROM GRADE_TAMANHO ' +
      'WHERE GRADE_ID = :ID ORDER BY ORDEM, TAMANHO';
    LQuery.ParamByName('ID').AsLargeInt := AGradeId;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)].Id := LQuery.FieldByName('ID').AsLargeInt;
      Result[High(Result)].Tamanho := Trim(LQuery.FieldByName('TAMANHO').AsString);
      Result[High(Result)].Ordem := LQuery.FieldByName('ORDEM').AsInteger;
      Result[High(Result)].Ativo := LQuery.FieldByName('ATIVO').AsString;
      Result[High(Result)].Quantidade := 0;
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

function TGradeService.ListarTamanhos(AGradeId: Int64): TGradeTamanhos;
begin
  Result := LerTamanhos(AGradeId);
end;

procedure TGradeService.GravarTamanhos(AGradeId: Int64;
  const ATamanhos: TGradeTamanhos);
var
  LQuery: TSQLQuery;
  I, LOrdem: Integer;
begin
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'DELETE FROM GRADE_TAMANHO WHERE GRADE_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AGradeId;
    LQuery.ExecSQL;

    LOrdem := 0;
    for I := 0 to High(ATamanhos) do
    begin
      if Trim(ATamanhos[I].Tamanho) = '' then
        Continue;
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO GRADE_TAMANHO (GRADE_ID, TAMANHO, ORDEM, ATIVO) ' +
        'VALUES (:GRADE, :TAM, :ORDEM, :ATIVO)';
      LQuery.ParamByName('GRADE').AsLargeInt := AGradeId;
      LQuery.ParamByName('TAM').AsString := Trim(ATamanhos[I].Tamanho);
      LQuery.ParamByName('ORDEM').AsInteger := LOrdem;
      if ATamanhos[I].Ativo = 'I' then
        LQuery.ParamByName('ATIVO').AsString := 'I'
      else
        LQuery.ParamByName('ATIVO').AsString := 'A';
      LQuery.ExecSQL;
      Inc(LOrdem);
    end;
  finally
    LQuery.Free;
  end;
end;

function TGradeService.Inserir(AObj: TGrade): Int64;
var
  LQuery: TSQLQuery;
begin
  Validar(AObj);
  Result := 0;
  Conexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    try
      LQuery.SQL.Text :=
        'INSERT INTO GRADE (EMPRESA_ID, NOME, TIPO, ATIVO, OBSERVACAO) ' +
        'VALUES (:EMP, :NOME, :TIPO, :ATIVO, :OBS)';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('NOME').AsString := Trim(AObj.Nome);
      LQuery.ParamByName('TIPO').AsString := AObj.Tipo;
      if AObj.Ativo = 'I' then
        LQuery.ParamByName('ATIVO').AsString := 'I'
      else
        LQuery.ParamByName('ATIVO').AsString := 'A';
      LQuery.ParamByName('OBS').AsString := Trim(AObj.Observacao);
      LQuery.ExecSQL;

      LQuery.Close;
      LQuery.SQL.Text := 'SELECT GEN_ID(GEN_GRADE_ID, 0) AS ID FROM RDB$DATABASE';
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;

      GravarTamanhos(Result, AObj.Tamanhos);
      Conexao.Confirmar;
      LogOperacao('GRADE', 'INSERIR', Result, '', Trim(AObj.Nome));
    except
      Conexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TGradeService.Atualizar(AObj: TGrade): Boolean;
var
  LQuery: TSQLQuery;
begin
  Validar(AObj);
  ValidarId(AObj.Id, 'Grade');
  Result := False;
  Conexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    try
      LQuery.SQL.Text :=
        'UPDATE GRADE SET NOME = :NOME, TIPO = :TIPO, ATIVO = :ATIVO, ' +
        'OBSERVACAO = :OBS WHERE ID = :ID';
      LQuery.ParamByName('NOME').AsString := Trim(AObj.Nome);
      LQuery.ParamByName('TIPO').AsString := AObj.Tipo;
      if AObj.Ativo = 'I' then
        LQuery.ParamByName('ATIVO').AsString := 'I'
      else
        LQuery.ParamByName('ATIVO').AsString := 'A';
      LQuery.ParamByName('OBS').AsString := Trim(AObj.Observacao);
      LQuery.ParamByName('ID').AsLargeInt := AObj.Id;
      LQuery.ExecSQL;

      GravarTamanhos(AObj.Id, AObj.Tamanhos);
      Conexao.Confirmar;
      LogOperacao('GRADE', 'ATUALIZAR', AObj.Id, '', Trim(AObj.Nome));
      Result := True;
    except
      Conexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TGradeService.Excluir(AId: Int64): Boolean;
var
  LQuery: TSQLQuery;
  LUsos: Int64;
begin
  ValidarId(AId, 'Grade');
  Result := False;
  LQuery := NovaConsulta;
  try
    { grade padrão de produto não pode ser excluída (referência lógica) }
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM PRODUTO WHERE GRADE_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    LUsos := LQuery.Fields[0].AsLargeInt;
    LQuery.Close;
    if LUsos > 0 then
      raise Exception.Create(
        'Esta grade está vinculada a produto(s) e não pode ser excluída.');

    Conexao.IniciarTransacao;
    try
      LQuery.SQL.Text := 'DELETE FROM GRADE_TAMANHO WHERE GRADE_ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := AId;
      LQuery.ExecSQL;
      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM GRADE WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := AId;
      LQuery.ExecSQL;
      Conexao.Confirmar;
      LogOperacao('GRADE', 'EXCLUIR', AId, '', '');
      Result := True;
    except
      Conexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TGradeService.ValorConfiguracao(const AChave: string;
  out AValor: string): Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  AValor := '';
  LQuery := NovaConsulta;
  try
    { empresa da sessão primeiro; NULL = padrão do sistema }
    LQuery.SQL.Text :=
      'SELECT FIRST 1 VALOR FROM CONFIGURACAO ' +
      'WHERE CHAVE = :CHAVE AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL) ' +
      'ORDER BY EMPRESA_ID DESC';
    LQuery.ParamByName('CHAVE').AsString := AChave;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      AValor := UpperCase(Trim(LQuery.FieldByName('VALOR').AsString));
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TGradeService.UsaGrade: Boolean;
var
  LValor: string;
begin
  Result := ValorConfiguracao('USA_GRADE', LValor) and (LValor = 'S');
end;

procedure TGradeService.DefinirUsaGrade(AUsar: Boolean);
var
  LQuery: TSQLQuery;
  LValor, LAnterior: string;
  LExiste: Boolean;
begin
  if AUsar then LValor := 'S' else LValor := 'N';
  if not ValorConfiguracao('USA_GRADE', LAnterior) then
    LAnterior := '';

  Conexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    try
      LQuery.SQL.Text :=
        'SELECT COUNT(*) AS QTD FROM CONFIGURACAO WHERE CHAVE = :CHAVE ' +
        'AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL)';
      LQuery.ParamByName('CHAVE').AsString := 'USA_GRADE';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.Open;
      LExiste := LQuery.FieldByName('QTD').AsInteger > 0;
      LQuery.Close;

      if LExiste then
      begin
        LQuery.SQL.Text :=
          'UPDATE CONFIGURACAO SET VALOR = :VALOR WHERE CHAVE = :CHAVE ' +
          'AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL)';
        LQuery.ParamByName('VALOR').AsString := LValor;
        LQuery.ParamByName('CHAVE').AsString := 'USA_GRADE';
        LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQuery.ExecSQL;
      end
      else
      begin
        LQuery.SQL.Text :=
          'INSERT INTO CONFIGURACAO (EMPRESA_ID, CHAVE, VALOR, DESCRICAO) ' +
          'VALUES (:EMP, :CHAVE, :VALOR, :DESC)';
        LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQuery.ParamByName('CHAVE').AsString := 'USA_GRADE';
        LQuery.ParamByName('VALOR').AsString := LValor;
        LQuery.ParamByName('DESC').AsString :=
          'Usa grade de tamanhos no pedido e no mapa';
        LQuery.ExecSQL;
      end;

      Conexao.Confirmar;
      LogOperacao('CONFIGURACAO', 'ALTERACAO', 0,
        'USA_GRADE=' + LAnterior, 'USA_GRADE=' + LValor);
    except
      Conexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

{ ---------------- grade efetiva (pedido / mapa) ---------------- }

function TGradeService.LerGradeEfetiva(const ATabela, ACampoDono: string;
  ADonoId: Int64): TGradeTamanhos;
var
  LQuery: TSQLQuery;
  LSQL: string;
begin
  Result := nil;
  LQuery := NovaConsulta;
  try
    LSQL := Format(
      'SELECT ID, TAMANHO, QUANTIDADE, ORDEM FROM %s ' +
      'WHERE %s = :DONO ORDER BY ORDEM, TAMANHO', [ATabela, ACampoDono]);
    LQuery.SQL.Text := LSQL;
    LQuery.ParamByName('DONO').AsLargeInt := ADonoId;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)].Id := LQuery.FieldByName('ID').AsLargeInt;
      Result[High(Result)].Tamanho := Trim(LQuery.FieldByName('TAMANHO').AsString);
      Result[High(Result)].Quantidade := LQuery.FieldByName('QUANTIDADE').AsFloat;
      Result[High(Result)].Ordem := LQuery.FieldByName('ORDEM').AsInteger;
      Result[High(Result)].Ativo := 'A';
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TGradeService.GravarGradeEfetiva(const ATabela, ACampoDono: string;
  ADonoId: Int64; const ATamanhos: TGradeTamanhos);
var
  LQuery: TSQLQuery;
  LSQL: string;
  I, LOrdem: Integer;
  LQtd: Double;
  LPropria: Boolean;
begin
  ValidarTamanhos(ATamanhos, False);

  { transação composta: se o chamador (ex.: save do pedido) já abriu
    transação, a grade entra nela e NÃO commita no meio; só quem abriu
    a transação confirma/cancela. A auditoria é sempre gravada. }
  LPropria := not Conexao.EmTransacao;
  if LPropria then
    Conexao.IniciarTransacao;

  LQuery := NovaConsulta;
  try
    try
      LSQL := Format('DELETE FROM %s WHERE %s = :DONO', [ATabela, ACampoDono]);
      LQuery.SQL.Text := LSQL;
      LQuery.ParamByName('DONO').AsLargeInt := ADonoId;
      LQuery.ExecSQL;

      LOrdem := 0;
      for I := 0 to High(ATamanhos) do
      begin
        if Trim(ATamanhos[I].Tamanho) = '' then
          Continue;
        LQtd := ATamanhos[I].Quantidade;
        if LQtd < 0 then
          raise Exception.CreateFmt('Quantidade negativa no tamanho "%s".',
            [Trim(ATamanhos[I].Tamanho)]);

        LQuery.Close;
        LSQL := Format(
          'INSERT INTO %s (%s, TAMANHO, QUANTIDADE, ORDEM) ' +
          'VALUES (:DONO, :TAM, :QTD, :ORDEM)', [ATabela, ACampoDono]);
        LQuery.SQL.Text := LSQL;
        LQuery.ParamByName('DONO').AsLargeInt := ADonoId;
        LQuery.ParamByName('TAM').AsString := Trim(ATamanhos[I].Tamanho);
        LQuery.ParamByName('QTD').AsFloat := LQtd;
        LQuery.ParamByName('ORDEM').AsInteger := LOrdem;
        LQuery.ExecSQL;
        Inc(LOrdem);
      end;

      if LPropria then
        Conexao.Confirmar;
      LogOperacao(ATabela, 'GRAVAR', ADonoId, '',
        Format('%d tamanho(s), total %.4f', [LOrdem, SomarQuantidades(ATamanhos)]));
    except
      if LPropria then
        Conexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TGradeService.GradeDoItemPedido(AItemPedidoId: Int64): TGradeTamanhos;
begin
  Result := LerGradeEfetiva('ITEM_PEDIDO_GRADE', 'ITEM_PEDIDO_ID', AItemPedidoId);
end;

procedure TGradeService.SalvarGradeItemPedido(AItemPedidoId: Int64;
  const ATamanhos: TGradeTamanhos);
begin
  if AItemPedidoId <= 0 then
    raise Exception.Create('Grade do pedido: item inválido.');
  GravarGradeEfetiva('ITEM_PEDIDO_GRADE', 'ITEM_PEDIDO_ID', AItemPedidoId, ATamanhos);
end;

function TGradeService.CopiarGradeParaItemPedido(AItemPedidoId,
  AGradeId: Int64): Integer;
var
  LOrigem, LDestino: TGradeTamanhos;
  I: Integer;
begin
  Result := 0;
  if AItemPedidoId <= 0 then
    raise Exception.Create('Grade do pedido: item inválido.');
  if AGradeId <= 0 then
    Exit;

  LOrigem := LerTamanhos(AGradeId);
  LDestino := nil;
  for I := 0 to High(LOrigem) do
    if LOrigem[I].Ativo <> 'I' then
    begin
      SetLength(LDestino, Length(LDestino) + 1);
      LDestino[High(LDestino)].Tamanho := LOrigem[I].Tamanho;
      LDestino[High(LDestino)].Quantidade := 0;
      LDestino[High(LDestino)].Ordem := Length(LDestino) - 1;
      LDestino[High(LDestino)].Ativo := 'A';
    end;

  SalvarGradeItemPedido(AItemPedidoId, LDestino);
  Result := Length(LDestino);
end;

function TGradeService.GradeDoMapaItem(AMapaItemId: Int64): TGradeTamanhos;
begin
  Result := LerGradeEfetiva('MAPA_PRODUCAO_ITEM_GRADE',
    'MAPA_PRODUCAO_ITEM_ID', AMapaItemId);
end;

procedure TGradeService.SalvarGradeMapaItem(AMapaItemId: Int64;
  const ATamanhos: TGradeTamanhos);
begin
  if AMapaItemId <= 0 then
    raise Exception.Create('Grade do mapa: item inválido.');
  GravarGradeEfetiva('MAPA_PRODUCAO_ITEM_GRADE', 'MAPA_PRODUCAO_ITEM_ID',
    AMapaItemId, ATamanhos);
end;

function TGradeService.ItemPedidoDoMapaItem(AMapaItemId: Int64): Int64;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  if AMapaItemId <= 0 then
    Exit;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT ITEM_PEDIDO_ID FROM MAPA_PRODUCAO_ITEM WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AMapaItemId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ITEM_PEDIDO_ID').AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

function TGradeService.CopiarGradeDoPedidoParaMapa(AMapaItemId: Int64): Integer;
var
  LItemPedidoId: Int64;
  LTamanhos: TGradeTamanhos;
begin
  Result := 0;
  if AMapaItemId <= 0 then
    raise Exception.Create('Grade do mapa: item inválido.');

  LItemPedidoId := ItemPedidoDoMapaItem(AMapaItemId);
  if LItemPedidoId <= 0 then
    Exit;

  LTamanhos := GradeDoItemPedido(LItemPedidoId);
  if Length(LTamanhos) = 0 then
    Exit;

  SalvarGradeMapaItem(AMapaItemId, LTamanhos);
  Result := Length(LTamanhos);
end;

{ ---------------- grade padrão do produto ---------------- }

function TGradeService.GradeDoProduto(AProdutoId: Int64): Int64;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'SELECT GRADE_ID FROM PRODUTO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AProdutoId;
    LQuery.Open;
    if (not LQuery.IsEmpty) and (not LQuery.FieldByName('GRADE_ID').IsNull) then
      Result := LQuery.FieldByName('GRADE_ID').AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

procedure TGradeService.DefinirGradeDoProduto(AProdutoId, AGradeId: Int64);
var
  LQuery: TSQLQuery;
begin
  ValidarId(AProdutoId, 'Produto');
  Conexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    try
      LQuery.SQL.Text := 'UPDATE PRODUTO SET GRADE_ID = :GRADE WHERE ID = :ID';
      if AGradeId > 0 then
        LQuery.ParamByName('GRADE').AsLargeInt := AGradeId
      else
        LQuery.ParamByName('GRADE').Clear;
      LQuery.ParamByName('ID').AsLargeInt := AProdutoId;
      LQuery.ExecSQL;
      Conexao.Confirmar;
      LogOperacao('PRODUTO', 'ATUALIZAR', AProdutoId, '',
        Format('GRADE_ID=%d', [AGradeId]));
    except
      Conexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

end.
