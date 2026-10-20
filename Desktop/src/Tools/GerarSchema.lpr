program GerarSchema;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Gerador de schema canônico
  Descrição: Lê o metadata do DADOS.FDB (RDB$*) via SQLDB e
  emite um script SQL único que recria o schema real:
  domains, generators, tabelas (colunas/tipos/defaults),
  PRIMARY KEY, FOREIGN KEY, UNIQUE, índices e triggers.

  Por que existe: 004_tables.sql e banco_simplificado.sql ficaram
  defasados em relação ao banco real (Produção e Notas vieram por
  scripts incrementais 009..012). Este gerador espelha o banco que
  está em uso e pode ser regenerado sempre que o schema mudar.

  Uso:  Scripts\gerar_schema.bat
  Saída: Banco\schema_canonico.sql
  ============================================================ }

uses
  Classes, SysUtils, SQLDB, uConexao;

type
  TStrArr = array of string;

  TConstrRec = record
    Tab, Nome, Tipo, Idx: string;
    { FK: colunas da tabela referenciada, resolvidas a partir do
      índice da constraint unique/pk referida (RDB$CONST_NAME_UQ) }
    RefTab, RefCampos, UpdRule, DelRule: string;
    { CHECK: expressão completa (ex.: "CHECK (STATUS IN ('A','I'))") }
    CheckExpr: string;
  end;
  TConstrArr = array of TConstrRec;

  TTrigRec = record
    Nome, Tab, Src: string;
    Tipo, Inativo, Seq: Integer;
  end;
  TTrigArr = array of TTrigRec;

var
  Q, Q2: TSQLQuery;
  OutF: TStringList;

{ Primeira coluna da primeira linha (ou vazio). }
function Q1(const ASql: string): string;
begin
  Q.Close;
  Q.SQL.Text := ASql;
  Q.Open;
  if Q.IsEmpty then
    Result := ''
  else
    Result := Trim(Q.Fields[0].AsString);
end;

function Esc(const S: string): string;
begin
  Result := StringReplace(S, '''', '''''', [rfReplaceAll]);
end;

{ Colapsa quebras de linha dos fontes de DEFAULT/trigger em espaço. }
function Limpa(const S: string): string;
begin
  Result := StringReplace(S, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := Trim(Result);
end;

{ Mapeia o código RDB$FIELD_TYPE do Firebird para DDL legível. }
function TipoDe(AType, ALen, AScale, APrec: Integer): string;
begin
  case AType of
    7:  if AScale < 0 then Result := Format('NUMERIC(9,%d)', [-AScale])
        else Result := 'SMALLINT';
    8:  if AScale < 0 then Result := Format('NUMERIC(9,%d)', [-AScale])
        else Result := 'INTEGER';
    12: Result := 'DATE';
    13: Result := 'TIME';
    14: Result := Format('CHAR(%d)', [ALen]);
    16: if (APrec = 0) and (AScale = 0) then
          { precisão 0 = metadado degenerado (ex.: DM_ID): BIGINT é o
            tipo numérico inteiro mais largo e seguro }
          Result := 'BIGINT'
        else if APrec = 0 then
          Result := Format('NUMERIC(18,%d)', [-AScale])
        else
          Result := Format('NUMERIC(%d,%d)', [APrec, -AScale]);
    10, 11, 27: Result := 'DOUBLE PRECISION';
    29: Result := 'FLOAT';
    35: Result := 'TIMESTAMP';
    37: Result := Format('VARCHAR(%d)', [ALen]);
  else
    Result := Format('VARCHAR(1) /*tipo %d nao mapeado*/', [AType]);
  end;
end;

{ Lê a primeira coluna de toda a lista de resultados, já com Trim. }
function ListaNomes(const ASql: string): TStrArr;
var
  N: Integer;
begin
  Q.Close;
  Q.SQL.Text := ASql;
  Q.Open;
  SetLength(Result, 0);
  N := 0;
  while not Q.EOF do
  begin
    SetLength(Result, N + 1);
    Result[N] := Trim(Q.Fields[0].AsString);
    Inc(N);
    Q.Next;
  end;
end;

{ Campos de um índice, na ordem das posições. }
function Segmentos(const AIndex: string): string;
begin
  Result := '';
  Q.Close;
  Q.SQL.Text :=
    'SELECT SG.RDB$FIELD_NAME FROM RDB$INDEX_SEGMENTS SG ' +
    'WHERE SG.RDB$INDEX_NAME = ''' + Esc(AIndex) + ''' ' +
    'ORDER BY SG.RDB$FIELD_POSITION';
  Q.Open;
  while not Q.EOF do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Trim(Q.Fields[0].AsString);
    Q.Next;
  end;
end;

{ Mesmo que Segmentos, mas sobre o cursor auxiliar Q2 — usado dentro
  do laço de constraints, onde Q já está ocupado pela consulta externa. }
function Segmentos2(const AIndex: string): string;
begin
  Result := '';
  Q2.Close;
  Q2.SQL.Text :=
    'SELECT SG.RDB$FIELD_NAME FROM RDB$INDEX_SEGMENTS SG ' +
    'WHERE SG.RDB$INDEX_NAME = ''' + Esc(AIndex) + ''' ' +
    'ORDER BY SG.RDB$FIELD_POSITION';
  Q2.Open;
  while not Q2.EOF do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Trim(Q2.Fields[0].AsString);
    Q2.Next;
  end;
end;

{ Código do gatilho -> cláusula BEFORE/AFTER ... }
function TipoGatilho(ATipo: Integer): string;
begin
  case ATipo of
    1: Result := 'BEFORE INSERT';
    2: Result := 'AFTER INSERT';
    3: Result := 'BEFORE UPDATE';
    4: Result := 'AFTER UPDATE';
    5: Result := 'BEFORE DELETE';
    6: Result := 'AFTER DELETE';
  else
    Result := Format('/*tipo %d*/', [ATipo]);
  end;
end;

var
  Tabs, Gens, Idxs: TStrArr;
  Cons: TConstrArr;
  Trigs: TTrigArr;
  I, K, N: Integer;
  LTab, LNome, LIdx, LLinha, LDef, LComp, LDom: string;
  LUniq, LInat2: string;
  LCampo, LTipoCampo: string;
  LTipoNum, LLen, LEscala, LPrec, LNullC, LNullF: Integer;
  LTabRef, LUpd, LDel, LUq, LCamposRef: string;
  LSeq: Integer;
  LArq: string;
  LDB: string;
  NDom: Integer;
  LTmp: TStringList;

begin
  if ParamCount >= 1 then
    LArq := ParamStr(1)
  else
    LArq := 'Banco\schema_canonico.sql';

  { 2º parâmetro opcional: caminho do .fdb que o script irá criar/
    conectar (usado pelo teste round-trip num banco descartável) }
  if ParamCount >= 2 then
    LDB := ParamStr(2)
  else
    LDB := 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb';

  Q := TSQLQuery.Create(nil);
  { consulta auxiliar: as consultas de FK/índice precisam de um cursor
    próprio para não destruir o cursor do laço externo de constraints }
  Q2 := TSQLQuery.Create(nil);
  OutF := TStringList.Create;
  try
    TConexao.GetInstance.Conectar;
    TConexao.GetInstance.IniciarTransacao;
    Q.DataBase := TConexao.GetInstance.Connection;
    Q.Transaction := TConexao.GetInstance.Transaction;
    Q2.DataBase := TConexao.GetInstance.Connection;
    Q2.Transaction := TConexao.GetInstance.Transaction;

    OutF.Add('/* ============================================================');
    OutF.Add('   ERP 2026 - SCHEMA CANONICO (gerado do banco real)');
    OutF.Add('   Gerado por: Scripts\gerar_schema.bat');
    OutF.Add('   Fonte: Banco\DADOS.FDB (metadata RDB$*)');
    OutF.Add('');
    OutF.Add('   Este script recria o schema que esta de fato em uso.');
    OutF.Add('   Substitui 004_tables.sql e banco_simplificado.sql, que');
    OutF.Add('   ficaram defasados (Producao e Notas vieram depois por');
    OutF.Add('   scripts incrementais). Regenerar apos qualquer DDL.');
    OutF.Add('   ============================================================ */');
    OutF.Add('');
    OutF.Add('CREATE DATABASE ''' + LDB + '''');
    OutF.Add('  PAGE_SIZE 16384 DEFAULT CHARACTER SET UTF8;');
    OutF.Add('COMMIT;');
    OutF.Add('CONNECT ''' + LDB + '''');
    OutF.Add('  USER ''SYSDBA'' PASSWORD ''masterkey'';');
    OutF.Add('');

    { ---------------- DOMAINS ---------------- }
    OutF.Add('/* ---------------- DOMAINS ---------------- */');
    Q.Close;
    Q.SQL.Text :=
      'SELECT F.RDB$FIELD_NAME, F.RDB$FIELD_TYPE, ' +
      'COALESCE(F.RDB$CHARACTER_LENGTH,0), F.RDB$FIELD_SCALE, ' +
      'COALESCE(F.RDB$FIELD_PRECISION,0), COALESCE(F.RDB$NULL_FLAG,0), ' +
      'F.RDB$DEFAULT_SOURCE ' +
      'FROM RDB$FIELDS F ' +
      'WHERE F.RDB$FIELD_NAME NOT STARTING WITH ''RDB$'' ' +
      '  AND F.RDB$FIELD_NAME NOT STARTING WITH ''MON$'' ' +
      '  AND F.RDB$FIELD_NAME NOT STARTING WITH ''SEC$'' ' +
      '  AND EXISTS (SELECT 1 FROM RDB$RELATION_FIELDS RF ' +
      '              WHERE RF.RDB$FIELD_SOURCE = F.RDB$FIELD_NAME) ' +
      'ORDER BY F.RDB$FIELD_NAME';
    Q.Open;
    NDom := 0;
    while not Q.EOF do
    begin
      Inc(NDom);
      LNome := Trim(Q.Fields[0].AsString);
      LTipoNum := Q.Fields[1].AsInteger;
      LLen := Q.Fields[2].AsInteger;
      LEscala := Q.Fields[3].AsInteger;
      LPrec := Q.Fields[4].AsInteger;
      LNullF := Q.Fields[5].AsInteger;
      LDef := Limpa(Q.Fields[6].AsString);

      LLinha := 'CREATE DOMAIN ' + LNome + ' AS ' + TipoDe(LTipoNum, LLen, LEscala, LPrec);
      if LDef <> '' then
        LLinha := LLinha + ' ' + LDef;
      if LNullF = 1 then
        LLinha := LLinha + ' NOT NULL';
      OutF.Add(LLinha + ';');
      Q.Next;
    end;
    OutF.Add('');

    { ---------------- GENERATORS ---------------- }
    OutF.Add('/* ---------------- GENERATORS ---------------- */');
    Gens := ListaNomes(
      'SELECT G.RDB$GENERATOR_NAME FROM RDB$GENERATORS G ' +
      'WHERE COALESCE(G.RDB$SYSTEM_FLAG,0)=0 ' +
      'ORDER BY G.RDB$GENERATOR_NAME');
    for I := 0 to High(Gens) do
      OutF.Add('CREATE GENERATOR ' + Gens[I] + ';');
    OutF.Add('COMMIT;');
    OutF.Add('');

    { ---------------- CONSTRAINTS (materializa antes das tabelas) ------
      Precisa vir antes do CREATE TABLE para que PK/FK/UNIQUE possam ser
      emitidos inline. Emitir como ALTER com o nome original (INTEG_n)
      quebrava: o Firebird já cria a constraint automática com esse mesmo
      nome dentro do CREATE TABLE. }
    Q.Close;
    Q.SQL.Text :=
      'SELECT RC.RDB$RELATION_NAME, RC.RDB$CONSTRAINT_NAME, ' +
      'RC.RDB$CONSTRAINT_TYPE, RC.RDB$INDEX_NAME ' +
      'FROM RDB$RELATION_CONSTRAINTS RC ' +
      'JOIN RDB$RELATIONS R ON R.RDB$RELATION_NAME = RC.RDB$RELATION_NAME ' +
      'WHERE COALESCE(R.RDB$SYSTEM_FLAG,0)=0 ' +
      'ORDER BY RC.RDB$RELATION_NAME, ' +
      '         CASE RC.RDB$CONSTRAINT_TYPE ' +
      '           WHEN ''PRIMARY KEY'' THEN 0 WHEN ''UNIQUE'' THEN 1 ' +
      '           WHEN ''FOREIGN KEY'' THEN 2 ELSE 3 END, ' +
      '         RC.RDB$CONSTRAINT_NAME';
    Q.Open;
    SetLength(Cons, 0);
    N := 0;
    while not Q.EOF do
    begin
      SetLength(Cons, N + 1);
      Cons[N].Tab := Trim(Q.Fields[0].AsString);
      Cons[N].Nome := Trim(Q.Fields[1].AsString);
      Cons[N].Tipo := Trim(Q.Fields[2].AsString);
      Cons[N].Idx := Trim(Q.Fields[3].AsString);
      Cons[N].RefTab := '';
      Cons[N].RefCampos := '';
      Cons[N].UpdRule := 'NO ACTION';
      Cons[N].DelRule := 'NO ACTION';
      Cons[N].CheckExpr := '';

      { CHECK: a expressão vive no fonte do trigger interno
        (RDB$CHECK_CONSTRAINTS -> RDB$TRIGGERS.RDB$TRIGGER_SOURCE) e já
        vem como "CHECK (...)" completo. }
      if Cons[N].Tipo = 'CHECK' then
      begin
        Q2.Close;
        Q2.SQL.Text :=
          'SELECT T.RDB$TRIGGER_SOURCE FROM RDB$CHECK_CONSTRAINTS CC ' +
          'JOIN RDB$TRIGGERS T ON T.RDB$TRIGGER_NAME = CC.RDB$TRIGGER_NAME ' +
          'WHERE CC.RDB$CONSTRAINT_NAME = ''' + Esc(Cons[N].Nome) + '''';
        Q2.Open;
        if not Q2.IsEmpty then
          Cons[N].CheckExpr := Limpa(Q2.Fields[0].AsString);
      end
      else if Cons[N].Tipo = 'FOREIGN KEY' then
      begin
        { regras de update/delete + nome da constraint unique/pk referida }
        Q2.Close;
        Q2.SQL.Text :=
          'SELECT R.RDB$UPDATE_RULE, R.RDB$DELETE_RULE, R.RDB$CONST_NAME_UQ ' +
          'FROM RDB$REF_CONSTRAINTS R ' +
          'WHERE R.RDB$CONSTRAINT_NAME = ''' + Esc(Cons[N].Nome) + '''';
        Q2.Open;
        if not Q2.IsEmpty then
        begin
          Cons[N].UpdRule := Trim(Q2.Fields[0].AsString);
          Cons[N].DelRule := Trim(Q2.Fields[1].AsString);
          LUq := Trim(Q2.Fields[2].AsString);

          { tabela referenciada + colunas: sai do índice da constraint }
          Q2.Close;
          Q2.SQL.Text :=
            'SELECT RC2.RDB$RELATION_NAME, RC2.RDB$INDEX_NAME ' +
            'FROM RDB$RELATION_CONSTRAINTS RC2 ' +
            'WHERE RC2.RDB$CONSTRAINT_NAME = ''' + Esc(LUq) + '''';
          Q2.Open;
          if not Q2.IsEmpty then
          begin
            Cons[N].RefTab := Trim(Q2.Fields[0].AsString);
            Cons[N].RefCampos := Segmentos2(Trim(Q2.Fields[1].AsString));
          end;
        end;
      end;

      Inc(N);
      Q.Next;
    end;

    { ---------------- TABELAS ---------------- }
    Tabs := ListaNomes(
      'SELECT R.RDB$RELATION_NAME FROM RDB$RELATIONS R ' +
      'WHERE COALESCE(R.RDB$SYSTEM_FLAG,0)=0 AND R.RDB$VIEW_BLR IS NULL ' +
      'ORDER BY R.RDB$RELATION_NAME');

    OutF.Add('/* ---------------- TABELAS ---------------- */');
    for I := 0 to High(Tabs) do
    begin
      LTab := Tabs[I];
      OutF.Add('');
      OutF.Add('CREATE TABLE ' + LTab + ' (');
      Q.Close;
      Q.SQL.Text :=
        'SELECT RF.RDB$FIELD_NAME, F.RDB$FIELD_NAME, F.RDB$FIELD_TYPE, ' +
        'COALESCE(F.RDB$CHARACTER_LENGTH,0), F.RDB$FIELD_SCALE, ' +
        'COALESCE(F.RDB$FIELD_PRECISION,0), COALESCE(RF.RDB$NULL_FLAG,0), ' +
        'RF.RDB$DEFAULT_SOURCE, F.RDB$COMPUTED_SOURCE ' +
        'FROM RDB$RELATION_FIELDS RF ' +
        'JOIN RDB$FIELDS F ON F.RDB$FIELD_NAME = RF.RDB$FIELD_SOURCE ' +
        'WHERE RF.RDB$RELATION_NAME = ''' + Esc(LTab) + ''' ' +
        '  AND COALESCE(RF.RDB$SYSTEM_FLAG,0)=0 ' +
        'ORDER BY RF.RDB$FIELD_POSITION';
      Q.Open;
      N := 0;
      LTmp := TStringList.Create;
      try
        while not Q.EOF do
        begin
        LCampo := Trim(Q.Fields[0].AsString);
        LDom := Trim(Q.Fields[1].AsString);
        LTipoNum := Q.Fields[2].AsInteger;
        LLen := Q.Fields[3].AsInteger;
        LEscala := Q.Fields[4].AsInteger;
        LPrec := Q.Fields[5].AsInteger;
        LNullC := Q.Fields[6].AsInteger;
        LDef := Limpa(Q.Fields[7].AsString);
        LComp := Limpa(Q.Fields[8].AsString);

        if Copy(LDom, 1, 3) = 'DM_' then
          LTipoCampo := LDom
        else
          LTipoCampo := TipoDe(LTipoNum, LLen, LEscala, LPrec);

        LLinha := '  ' + LCampo + ' ' + LTipoCampo;
        if LComp <> '' then
          LLinha := '  ' + LCampo + ' COMPUTED BY ' + LComp
        else
        begin
          if LDef <> '' then
            LLinha := LLinha + ' ' + LDef;
          if LNullC = 1 then
            LLinha := LLinha + ' NOT NULL';
        end;

        Inc(N);
        Q.Next;
        LTmp.Add(LLinha);
      end;
      Q.Close;

      { constraints inline: PK/UNIQUE/FK desta tabela (sem nome — o
        Firebird gera um, evitando colisão de INTEG_n) }
      for K := 0 to High(Cons) do
        if Cons[K].Tab = LTab then
        begin
          if Cons[K].Tipo = 'PRIMARY KEY' then
            LTmp.Add('  PRIMARY KEY (' + Segmentos(Cons[K].Idx) + ')')
          else if Cons[K].Tipo = 'UNIQUE' then
            LTmp.Add('  UNIQUE (' + Segmentos(Cons[K].Idx) + ')')
          else if (Cons[K].Tipo = 'FOREIGN KEY') and (Cons[K].RefTab <> '') then
            LTmp.Add('  FOREIGN KEY (' + Segmentos(Cons[K].Idx) +
                     ') REFERENCES ' + Cons[K].RefTab +
                     ' (' + Cons[K].RefCampos + ')' +
                     ' ON UPDATE ' + Cons[K].UpdRule +
                     ' ON DELETE ' + Cons[K].DelRule)
          else if (Cons[K].Tipo = 'CHECK') and (Cons[K].CheckExpr <> '') then
            { CheckExpr já vem como "CHECK (...)" completo do fonte interno }
            LTmp.Add('  ' + Cons[K].CheckExpr);
        end;

      { junta com vírgula entre itens, sem vírgula sobrando no fim }
      LLinha := '';
      for K := 0 to LTmp.Count - 1 do
      begin
        if K > 0 then
          LLinha := LLinha + ',' + LineEnding;
        LLinha := LLinha + LTmp[K];
      end;
      OutF.Add(LLinha);
      OutF.Add(');');
      finally
        LTmp.Free;
      end;
    end;
    OutF.Add('COMMIT;');
    OutF.Add('');

    { ---------------- ÍNDICES (fora de constraint) ---------------- }
    Idxs := ListaNomes(
      'SELECT I.RDB$INDEX_NAME FROM RDB$INDICES I ' +
      'JOIN RDB$RELATIONS R ON R.RDB$RELATION_NAME = I.RDB$RELATION_NAME ' +
      'WHERE COALESCE(R.RDB$SYSTEM_FLAG,0)=0 ' +
      '  AND I.RDB$INDEX_NAME NOT STARTING WITH ''RDB$'' ' +
      '  AND NOT EXISTS (SELECT 1 FROM RDB$RELATION_CONSTRAINTS RC ' +
      '                  WHERE RC.RDB$INDEX_NAME = I.RDB$INDEX_NAME) ' +
      'ORDER BY I.RDB$RELATION_NAME, I.RDB$INDEX_NAME');

    OutF.Add('/* ---------------- INDICES ---------------- */');
    for I := 0 to High(Idxs) do
    begin
      LIdx := Idxs[I];
      { lê relação / unique / inactive de uma vez, evitando 3 queries }
      Q.Close;
      Q.SQL.Text :=
        'SELECT I.RDB$RELATION_NAME, COALESCE(I.RDB$UNIQUE_FLAG,0), ' +
        'COALESCE(I.RDB$INDEX_INACTIVE,0) FROM RDB$INDICES I ' +
        'WHERE I.RDB$INDEX_NAME = ''' + Esc(LIdx) + '''';
      Q.Open;
      LTab := '';
      LUniq := '0';
      LInat2 := '0';
      if not Q.IsEmpty then
      begin
        LTab := Trim(Q.Fields[0].AsString);
        LUniq := Trim(Q.Fields[1].AsString);
        LInat2 := Trim(Q.Fields[2].AsString);
      end;

      LLinha := 'CREATE ';
      if LUniq = '1' then
        LLinha := LLinha + 'UNIQUE ';
      LLinha := LLinha + 'INDEX ' + LIdx + ' ON ' + LTab +
                ' (' + Segmentos(LIdx) + ')';
      if LInat2 = '1' then
        LLinha := LLinha + ' INACTIVE';
      OutF.Add(LLinha + ';');
    end;
    OutF.Add('COMMIT;');
    OutF.Add('');

    { ---------------- TRIGGERS ---------------- }
    Q.Close;
    Q.SQL.Text :=
      'SELECT T.RDB$TRIGGER_NAME, T.RDB$RELATION_NAME, T.RDB$TRIGGER_TYPE, ' +
      'COALESCE(T.RDB$TRIGGER_INACTIVE,0), COALESCE(T.RDB$TRIGGER_SEQUENCE,0), ' +
      'T.RDB$TRIGGER_SOURCE ' +
      'FROM RDB$TRIGGERS T ' +
      'JOIN RDB$RELATIONS R ON R.RDB$RELATION_NAME = T.RDB$RELATION_NAME ' +
      'WHERE COALESCE(R.RDB$SYSTEM_FLAG,0)=0 ' +
      '  AND COALESCE(T.RDB$SYSTEM_FLAG,0)=0 ' +
      '  AND T.RDB$TRIGGER_SOURCE IS NOT NULL ' +
      '  AND T.RDB$RELATION_NAME IS NOT NULL ' +
      'ORDER BY T.RDB$RELATION_NAME, T.RDB$TRIGGER_NAME';
    Q.Open;
    SetLength(Trigs, 0);
    N := 0;
    while not Q.EOF do
    begin
      SetLength(Trigs, N + 1);
      Trigs[N].Nome := Trim(Q.Fields[0].AsString);
      Trigs[N].Tab := Trim(Q.Fields[1].AsString);
      Trigs[N].Tipo := Q.Fields[2].AsInteger;
      Trigs[N].Inativo := Q.Fields[3].AsInteger;
      Trigs[N].Seq := Q.Fields[4].AsInteger;
      Trigs[N].Src := Trim(Q.Fields[5].AsString);
      Inc(N);
      Q.Next;
    end;

    OutF.Add('/* ---------------- TRIGGERS ---------------- */');
    OutF.Add('SET TERM ^ ;');
    for I := 0 to High(Trigs) do
    begin
      LLinha := 'CREATE TRIGGER ' + Trigs[I].Nome + ' FOR ' + Trigs[I].Tab + ' ';
      if Trigs[I].Inativo = 1 then
        LLinha := LLinha + 'INACTIVE '
      else
        LLinha := LLinha + 'ACTIVE ';
      { O fonte guardado em RDB$TRIGGER_SOURCE já traz o "AS"
        no início — não repetir aqui, senão vira "AS AS" }
      LLinha := LLinha + TipoGatilho(Trigs[I].Tipo) +
                ' POSITION ' + IntToStr(Trigs[I].Seq);
      OutF.Add(LLinha);
      OutF.Add(Trigs[I].Src);
      OutF.Add('^');
    end;
    OutF.Add('SET TERM ; ^');
    OutF.Add('COMMIT;');
    OutF.Add('');

    ForceDirectories(ExtractFilePath(ExpandFileName(LArq)));
    OutF.SaveToFile(LArq, TEncoding.ASCII);

    WriteLn('Schema canonico gravado em: ', LArq);
    WriteLn('  domains   : ', NDom);
    WriteLn('  generators: ', High(Gens) + 1);
    WriteLn('  tabelas   : ', High(Tabs) + 1);
    WriteLn('  constraints: ', High(Cons) + 1);
    WriteLn('  indices   : ', High(Idxs) + 1);
    WriteLn('  triggers  : ', High(Trigs) + 1);

    TConexao.GetInstance.Confirmar;
  finally
    OutF.Free;
    Q.Free;
    Q2.Free;
    TConexao.ReleaseInstance;
  end;
end.
