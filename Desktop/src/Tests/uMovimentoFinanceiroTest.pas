unit uMovimentoFinanceiroTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes do Movimento Financeiro
  ------------------------------------------------------------
  Cobre TMovimentoFinanceiroService:

    - validação: tipo somente 'E'/'S', descrição obrigatória
      (até 120), categoria até 30, data válida, valor > 0 e
      documento não negativo;
    - inclusão grava EMPRESA_ID/USUARIO_ID da sessão;
    - alteração e exclusão só alcançam registro da empresa da
      sessão (registro de outra empresa é recusado);
    - listagem no escopo da empresa, pesquisa por
      descrição/categoria/documento e ordem DATA_MOVIMENTO DESC,
      ID DESC;
    - sugestões de tipos ('E'/'S') e categorias.

  Padrão da suíte: dados com sufixo de timestamp, limpeza
  explícita no finally e nenhum mock de banco.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uMovimentoFinanceiroService;

type
  { TMovimentoFinanceiroTest }
  TMovimentoFinanceiroTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TMovimentoFinanceiroTest }

class procedure TMovimentoFinanceiroTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LService: TMovimentoFinanceiroService;
  LQuery: TSQLQuery;
  LLista: TSQLQuery;
  LSufixo: string;
  LSeq: Integer;
  LIds: TStringList;
  LIdsOutraEmpresa: TStringList;
  LId, LId3: Int64;
  LDados: TMovimentoFinanceiroDados;
  LDataA, LDataB: TDateTime;
  LCount: Integer;
  LItems: TStringList;

  function NovoTexto(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + ' ' + LSufixo + '-' + IntToStr(LSeq);
  end;

  procedure RegistrarId(ALista: TStrings; AId: Int64);
  begin
    ALista.Add(IntToStr(AId));
  end;

  // ------------------------------------------------------------------
  // Helpers de banco
  // ------------------------------------------------------------------

  function InserirMovimentoDireto(AEmpresaId, AUsuarioId: Int64;
    const AData: TDateTime; ATipo: Char; const ACategoria,
    ADescricao: string; AValor: Double; ADocumentoId: Int64): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO MOVIMENTO_FINANCEIRO (EMPRESA_ID, DATA_MOVIMENTO, ' +
      '  TIPO, CATEGORIA, DESCRICAO, VALOR, DOCUMENTO_ID, USUARIO_ID) ' +
      'VALUES (:EMP, :DATA, :TIPO, :CAT, :DESC, :VALOR, :DOC, :USR) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('DATA').AsDate := Trunc(AData);
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.ParamByName('CAT').AsString := ACategoria;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('VALOR').AsFloat := AValor;
    if ADocumentoId > 0 then
      LQuery.ParamByName('DOC').AsLargeInt := ADocumentoId
    else
      LQuery.ParamByName('DOC').Clear;
    LQuery.ParamByName('USR').AsLargeInt := AUsuarioId;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function CriarMovimento(const AData: TDateTime; ATipo: Char;
    const ACategoria, ADescricao: string; AValor: Double;
    ADocumentoId: Int64 = 0): Int64;
  begin
    LDados.Id := 0;
    LDados.DataMovimento := AData;
    LDados.Tipo := ATipo;
    LDados.Categoria := ACategoria;
    LDados.Descricao := ADescricao;
    LDados.Valor := AValor;
    LDados.DocumentoId := ADocumentoId;
    Result := LService.SalvarMovimento(LDados);
    RegistrarId(LIds, Result);
  end;

  procedure ApagarMovimentos(AIds: TStrings);
  var
    I: Integer;
  begin
    for I := 0 to AIds.Count - 1 do
    begin
      try
        LQuery.Close;
        LQuery.SQL.Text :=
          'DELETE FROM MOVIMENTO_FINANCEIRO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := StrToInt64(AIds[I]);
        LQuery.ExecSQL;
      except
      end;
    end;
    LConexao.Confirmar;
  end;

  function ContarLista: Integer;
  begin
    Result := 0;
    LLista.First;
    while not LLista.EOF do
    begin
      Inc(Result);
      LLista.Next;
    end;
  end;

  procedure MontarDadosValidos(out ADados: TMovimentoFinanceiroDados);
  begin
    ADados.Id := 0;
    ADados.DataMovimento := Now;
    ADados.Tipo := 'E';
    ADados.Categoria := 'RECEBIMENTO';
    ADados.Descricao := NovoTexto('MOVIMENTO');
    ADados.Valor := 100;
    ADados.DocumentoId := 0;
  end;

  // ------------------------------------------------------------------
  // Validação (cada sub-caso registra seu próprio resultado)
  // ------------------------------------------------------------------

  procedure TestValidar_TipoInvalido;
  begin
    try
      MontarDadosValidos(LDados);
      LDados.Tipo := 'X';
      try
        LService.SalvarMovimento(LDados);
        ASuite.AddResult('TestMFValidarTipoInvalido', False,
          'devia recusar tipo X');
      except
        on E: Exception do
          ASuite.AddResult('TestMFValidarTipoInvalido',
            Pos('Tipo de movimento inválido', E.Message) > 0, E.Message);
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFValidarTipoInvalido', False, E.Message);
    end;
  end;

  procedure TestValidar_DescricaoVazia;
  begin
    try
      MontarDadosValidos(LDados);
      LDados.Descricao := '   ';
      try
        LService.SalvarMovimento(LDados);
        ASuite.AddResult('TestMFValidarDescricaoVazia', False,
          'devia recusar descrição vazia');
      except
        on E: Exception do
          ASuite.AddResult('TestMFValidarDescricaoVazia',
            Pos('Descrição é obrigatório', E.Message) > 0, E.Message);
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFValidarDescricaoVazia', False, E.Message);
    end;
  end;

  procedure TestValidar_DescricaoMuitoLonga;
  begin
    try
      MontarDadosValidos(LDados);
      LDados.Descricao := StringOfChar('A', 121);
      try
        LService.SalvarMovimento(LDados);
        ASuite.AddResult('TestMFValidarDescricaoLonga', False,
          'devia recusar descrição com 121 caracteres');
      except
        on E: Exception do
          ASuite.AddResult('TestMFValidarDescricaoLonga',
            Pos('descrição deve ter no máximo', E.Message) > 0, E.Message);
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFValidarDescricaoLonga', False, E.Message);
    end;
  end;

  procedure TestValidar_CategoriaMuitoLonga;
  begin
    try
      MontarDadosValidos(LDados);
      LDados.Categoria := StringOfChar('A', 31);
      try
        LService.SalvarMovimento(LDados);
        ASuite.AddResult('TestMFValidarCategoriaLonga', False,
          'devia recusar categoria com 31 caracteres');
      except
        on E: Exception do
          ASuite.AddResult('TestMFValidarCategoriaLonga',
            Pos('categoria deve ter no máximo', E.Message) > 0, E.Message);
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFValidarCategoriaLonga', False, E.Message);
    end;
  end;

  procedure TestValidar_DataInvalida;
  begin
    try
      MontarDadosValidos(LDados);
      LDados.DataMovimento := 0;
      try
        LService.SalvarMovimento(LDados);
        ASuite.AddResult('TestMFValidarDataInvalida', False,
          'devia recusar data zero');
      except
        on E: Exception do
          ASuite.AddResult('TestMFValidarDataInvalida',
            Pos('data válida', E.Message) > 0, E.Message);
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFValidarDataInvalida', False, E.Message);
    end;
  end;

  procedure TestValidar_ValorZero;
  begin
    try
      MontarDadosValidos(LDados);
      LDados.Valor := 0;
      try
        LService.SalvarMovimento(LDados);
        ASuite.AddResult('TestMFValidarValorZero', False,
          'devia recusar valor zero');
      except
        on E: Exception do
          ASuite.AddResult('TestMFValidarValorZero',
            Pos('valor do movimento deve ser maior que zero',
              E.Message) > 0, E.Message);
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFValidarValorZero', False, E.Message);
    end;
  end;

  procedure TestValidar_ValorNegativo;
  begin
    try
      MontarDadosValidos(LDados);
      LDados.Valor := -50;
      try
        LService.SalvarMovimento(LDados);
        ASuite.AddResult('TestMFValidarValorNegativo', False,
          'devia recusar valor negativo');
      except
        on E: Exception do
          ASuite.AddResult('TestMFValidarValorNegativo',
            Pos('valor do movimento deve ser maior que zero',
              E.Message) > 0, E.Message);
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFValidarValorNegativo', False, E.Message);
    end;
  end;

  procedure TestValidar_DocumentoNegativo;
  begin
    try
      MontarDadosValidos(LDados);
      LDados.DocumentoId := -1;
      try
        LService.SalvarMovimento(LDados);
        ASuite.AddResult('TestMFValidarDocumentoNegativo', False,
          'devia recusar documento negativo');
      except
        on E: Exception do
          ASuite.AddResult('TestMFValidarDocumentoNegativo',
            Pos('documento não pode ser negativo', E.Message) > 0,
            E.Message);
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFValidarDocumentoNegativo', False,
          E.Message);
    end;
  end;

begin
  LConexao := TConexao.GetInstance;
  if not LConexao.Conectado then
    LConexao.Conectar;
  LSessao := TSessao.GetInstance;
  LService := TMovimentoFinanceiroService.Create;
  LQuery := TSQLQuery.Create(nil);
  LLista := TSQLQuery.Create(nil);
  LQuery.DataBase := LConexao.Connection;
  LQuery.Transaction := LConexao.Transaction;
  LLista.DataBase := LConexao.Connection;
  LLista.Transaction := LConexao.Transaction;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSeq := 0;
  LIds := TStringList.Create;
  LIdsOutraEmpresa := TStringList.Create;

  try
    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DO MOVIMENTO FINANCEIRO');
    WriteLn('========================================');

    TestValidar_TipoInvalido;
    TestValidar_DescricaoVazia;
    TestValidar_DescricaoMuitoLonga;
    TestValidar_CategoriaMuitoLonga;
    TestValidar_DataInvalida;
    TestValidar_ValorZero;
    TestValidar_ValorNegativo;
    TestValidar_DocumentoNegativo;

    // Inclusão grava empresa/usuário da sessão
    try
      LId := CriarMovimento(Now, 'E', 'RECEBIMENTO',
        NovoTexto('MF SESSAO'), 100, 55);
      AssertTrue(LId > 0, 'a inclusão deve devolver o ID');

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT EMPRESA_ID, USUARIO_ID, TIPO, CATEGORIA, VALOR, ' +
        '  DOCUMENTO_ID FROM MOVIMENTO_FINANCEIRO WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LId;
      LQuery.Open;
      if LQuery.IsEmpty then
        raise Exception.Create('movimento não gravado');
      AssertEquals(IntToStr(LSessao.EmpresaId),
        IntToStr(LQuery.FieldByName('EMPRESA_ID').AsLargeInt),
        'EMPRESA_ID deve ser o da sessão');
      AssertEquals(IntToStr(LSessao.UsuarioId),
        IntToStr(LQuery.FieldByName('USUARIO_ID').AsLargeInt),
        'USUARIO_ID deve ser o da sessão');
      AssertEquals('E', Trim(LQuery.FieldByName('TIPO').AsString),
        'TIPO deve ser E');
      AssertEquals('RECEBIMENTO',
        Trim(LQuery.FieldByName('CATEGORIA').AsString),
        'CATEGORIA deve ser RECEBIMENTO');
      AssertTrue(Abs(LQuery.FieldByName('VALOR').AsFloat - 100) < 0.001,
        'VALOR deve ser 100');
      AssertEquals('55',
        IntToStr(LQuery.FieldByName('DOCUMENTO_ID').AsLargeInt),
        'DOCUMENTO_ID deve ser 55');
      LQuery.Close;
      ASuite.AddResult('TestMFIncluirGravaSessao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestMFIncluirGravaSessao', False, E.Message);
    end;

    // Alteração só na mesma empresa
    try
      LId := CriarMovimento(Now, 'E', 'RECEBIMENTO',
        NovoTexto('MF ALTERAR'), 100);
      LDados.Id := LId;
      LDados.DataMovimento := EncodeDate(2026, 5, 10);
      LDados.Tipo := 'S';
      LDados.Categoria := 'PAGAMENTO';
      LDados.Descricao := NovoTexto('MF ALTERADO');
      LDados.Valor := 200;
      LDados.DocumentoId := 0;
      AssertEquals(IntToStr(LId),
        IntToStr(LService.SalvarMovimento(LDados)),
        'a alteração deve devolver o mesmo ID');
      AssertTrue(LService.BuscarMovimento(LId, LDados),
        'deve encontrar o movimento alterado');
      AssertEquals('S', LDados.Tipo, 'tipo deve ter virado S');
      AssertTrue(Abs(LDados.Valor - 200) < 0.001,
        'valor deve ter virado 200');
      ASuite.AddResult('TestMFAlterarMesmaEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestMFAlterarMesmaEmpresa', False, E.Message);
    end;

    // Alteração de registro de outra empresa é recusada
    try
      LId := InserirMovimentoDireto(999999, LSessao.UsuarioId,
        Now, 'E', 'RECEBIMENTO', NovoTexto('MF OUTRA EMP'), 100, 0);
      RegistrarId(LIdsOutraEmpresa, LId);
      LDados.Id := LId;
      LDados.DataMovimento := Now;
      LDados.Tipo := 'S';
      LDados.Categoria := 'PAGAMENTO';
      LDados.Descricao := 'TENTATIVA';
      LDados.Valor := 1;
      LDados.DocumentoId := 0;
      try
        LService.SalvarMovimento(LDados);
        ASuite.AddResult('TestMFAlterarOutraEmpresa', False,
          'devia recusar alteração em outra empresa');
      except
        on E: Exception do
          ASuite.AddResult('TestMFAlterarOutraEmpresa',
            Pos('não encontrado nesta empresa', E.Message) > 0,
            E.Message);
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFAlterarOutraEmpresa', False, E.Message);
    end;

    // Exclusão só na mesma empresa
    try
      LId := CriarMovimento(Now, 'E', 'RECEBIMENTO',
        NovoTexto('MF EXCLUIR'), 100);
      LService.ExcluirMovimento(LId);
      AssertFalse(LService.BuscarMovimento(LId, LDados),
        'o movimento excluído não deve mais ser encontrado');
      ASuite.AddResult('TestMFExcluirMesmaEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestMFExcluirMesmaEmpresa', False, E.Message);
    end;

    // Exclusão de registro de outra empresa é recusada
    try
      LId := InserirMovimentoDireto(999999, LSessao.UsuarioId,
        Now, 'E', 'RECEBIMENTO', NovoTexto('MF OUTRA EMP2'), 100, 0);
      RegistrarId(LIdsOutraEmpresa, LId);
      try
        LService.ExcluirMovimento(LId);
        ASuite.AddResult('TestMFExcluirOutraEmpresa', False,
          'devia recusar exclusão em outra empresa');
      except
        on E: Exception do
          ASuite.AddResult('TestMFExcluirOutraEmpresa',
            Pos('não encontrado nesta empresa', E.Message) > 0,
            E.Message);
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFExcluirOutraEmpresa', False, E.Message);
    end;

    // Listagem no escopo da empresa (filtro = sufixo único)
    try
      CriarMovimento(Now, 'E', 'RECEBIMENTO',
        NovoTexto('MF LISTA E'), 100);
      CriarMovimento(Now, 'S', 'PAGAMENTO',
        NovoTexto('MF LISTA S'), 200);
      RegistrarId(LIdsOutraEmpresa, InserirMovimentoDireto(999999,
        LSessao.UsuarioId, Now, 'E', 'RECEBIMENTO',
        LSufixo + ' OUTRA EMPRESA', 999, 0));

      LService.CarregarMovimentos(LLista, LSufixo);
      LCount := ContarLista;
      AssertTrue(LCount >= 2,
        'a listagem deve achar os movimentos de teste da empresa');
      ASuite.AddResult('TestMFListarEscopoEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestMFListarEscopoEmpresa', False, E.Message);
    end;

    // Pesquisa por descrição/categoria/documento
    try
      CriarMovimento(Now, 'E', 'RECEBIMENTO',
        NovoTexto('MF PESQ DESC'), 100, 12345);
      CriarMovimento(Now, 'S', 'TRANSFERENCIA',
        NovoTexto('MF PESQ CAT'), 100);

      LService.CarregarMovimentos(LLista, 'PESQ DESC ' + LSufixo);
      AssertEquals('1', IntToStr(ContarLista),
        'pesquisa por descrição deve achar 1 movimento');

      LService.CarregarMovimentos(LLista, 'TRANSFERENCIA');
      AssertTrue(ContarLista >= 1,
        'pesquisa por categoria deve achar o movimento');

      LService.CarregarMovimentos(LLista, '12345');
      AssertEquals('1', IntToStr(ContarLista),
        'pesquisa por documento deve achar 1 movimento');
      ASuite.AddResult('TestMFPesquisaFiltros', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestMFPesquisaFiltros', False, E.Message);
    end;

    // Ordem: DATA_MOVIMENTO DESC, ID DESC
    try
      LDataA := EncodeDate(2020, 1, 1);
      LDataB := EncodeDate(2020, 2, 1);
      LId3 := CriarMovimento(LDataA, 'E', 'RECEBIMENTO',
        NovoTexto('MF ORDEM A'), 10);
      LId := CriarMovimento(LDataB, 'E', 'RECEBIMENTO',
        NovoTexto('MF ORDEM B'), 10);
      LService.CarregarMovimentos(LLista, 'MF ORDEM');
      LLista.First;
      AssertTrue(not LLista.IsEmpty, 'a pesquisa deve retornar linhas');
      AssertEquals(IntToStr(LId),
        IntToStr(LLista.FieldByName('ID').AsLargeInt),
        'o primeiro registro deve ser o de data mais recente');
      ASuite.AddResult('TestMFOrdemDataDescIdDesc', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestMFOrdemDataDescIdDesc', False, E.Message);
    end;

    // Buscar inexistente
    try
      AssertFalse(LService.BuscarMovimento(999999999, LDados),
        'ID inexistente deve retornar False');
      ASuite.AddResult('TestMFBuscarNaoEncontrado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestMFBuscarNaoEncontrado', False, E.Message);
    end;

    // Tipos e categorias
    try
      LItems := TStringList.Create;
      try
        LService.CarregarTipos(LItems);
        AssertEquals('2', IntToStr(LItems.Count), 'devem existir 2 tipos');
        AssertEquals('Entrada', LItems[0], 'primeiro tipo');
        AssertEquals('Saída', LItems[1], 'segundo tipo');

        LService.CarregarCategorias(LItems);
        AssertEquals('4', IntToStr(LItems.Count),
          'devem existir 4 categorias');
        AssertEquals('RECEBIMENTO', LItems[0], 'primeira categoria');
        AssertEquals('PAGAMENTO', LItems[1], 'segunda categoria');
        AssertEquals('TRANSFERENCIA', LItems[2], 'terceira categoria');
        AssertEquals('OUTRAS', LItems[3], 'quarta categoria');
        ASuite.AddResult('TestMFTiposCategorias', True, '');
      finally
        LItems.Free;
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestMFTiposCategorias', False, E.Message);
    end;

  finally
    ApagarMovimentos(LIds);
    ApagarMovimentos(LIdsOutraEmpresa);
    LIds.Free;
    LIdsOutraEmpresa.Free;
    LLista.Free;
    LQuery.Free;
    LService.Free;
  end;
end;

end.
