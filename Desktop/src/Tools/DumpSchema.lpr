program DumpSchema;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Dump normalizado do schema (ferramenta de validação)
  Emite, para o banco conectado, uma linha por tabela/campo com
  tipo legível. Serve para comparar dois bancos (round-trip do
  schema_canonico.sql) diff a diff.

  Uso: DumpSchema.exe  ->  imprime no stdout (uma linha por campo)
  ============================================================ }

uses
  Classes, SysUtils, SQLDB, uConexao;

function TipoLegivel(AType, ALen, AScale, APrec: Integer): string;
begin
  case AType of
    7:  if AScale < 0 then Result := Format('NUMERIC(9,%d)', [-AScale])
        else Result := 'SMALLINT';
    8:  if AScale < 0 then Result := Format('NUMERIC(9,%d)', [-AScale])
        else Result := 'INTEGER';
    12: Result := 'DATE';
    13: Result := 'TIME';
    14: Result := Format('CHAR(%d)', [ALen]);
    16: if (APrec = 0) and (AScale = 0) then Result := 'BIGINT'
        else if APrec = 0 then Result := Format('NUMERIC(18,%d)', [-AScale])
        else Result := Format('NUMERIC(%d,%d)', [APrec, -AScale]);
    10, 11, 27: Result := 'DOUBLE PRECISION';
    29: Result := 'FLOAT';
    35: Result := 'TIMESTAMP';
    37: Result := Format('VARCHAR(%d)', [ALen]);
  else
    Result := Format('TIPO_%d', [AType]);
  end;
end;

var
  Q: TSQLQuery;
begin
  Q := TSQLQuery.Create(nil);
  try
    { parâmetro opcional: banco a inspecionar (padrão = DADOS.FDB) }
    if ParamCount >= 1 then
      TConexao.GetInstance.Database := ParamStr(1);
    TConexao.GetInstance.Conectar;
    TConexao.GetInstance.IniciarTransacao;
    Q.DataBase := TConexao.GetInstance.Connection;
    Q.Transaction := TConexao.GetInstance.Transaction;

    { tabela | campo | tipo | notnull | default }
    Q.SQL.Text :=
      'SELECT R.RDB$RELATION_NAME, RF.RDB$FIELD_NAME, ' +
      'F.RDB$FIELD_TYPE, COALESCE(F.RDB$CHARACTER_LENGTH,0), ' +
      'F.RDB$FIELD_SCALE, COALESCE(F.RDB$FIELD_PRECISION,0), ' +
      'COALESCE(RF.RDB$NULL_FLAG,0), ' +
      'COALESCE(F.RDB$DEFAULT_SOURCE, RF.RDB$DEFAULT_SOURCE, ''<sem>'') ' +
      'FROM RDB$RELATION_FIELDS RF ' +
      'JOIN RDB$RELATIONS R ON R.RDB$RELATION_NAME = RF.RDB$RELATION_NAME ' +
      'JOIN RDB$FIELDS F ON F.RDB$FIELD_NAME = RF.RDB$FIELD_SOURCE ' +
      'WHERE COALESCE(R.RDB$SYSTEM_FLAG,0)=0 ' +
      '  AND COALESCE(RF.RDB$SYSTEM_FLAG,0)=0 ' +
      '  AND R.RDB$VIEW_BLR IS NULL ' +
      'ORDER BY R.RDB$RELATION_NAME, RF.RDB$FIELD_POSITION';
    Q.Open;
    while not Q.EOF do
    begin
      WriteLn(Trim(Q.Fields[0].AsString), '|',
              Trim(Q.Fields[1].AsString), '|',
              TipoLegivel(Q.Fields[2].AsInteger,
                          Q.Fields[3].AsInteger,
                          Q.Fields[4].AsInteger,
                          Q.Fields[5].AsInteger), '|',
              Q.Fields[6].AsString, '|',
              Trim(Q.Fields[7].AsString));
      Q.Next;
    end;
    TConexao.GetInstance.Confirmar;
  finally
    Q.Free;
    TConexao.ReleaseInstance;
  end;
end.
