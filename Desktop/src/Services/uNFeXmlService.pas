unit uNFeXmlService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Importacao de XML de NF-e
  ------------------------------------------------------------
  Le o XML da NF-e (autorizada ou nao) sem depender do ACBr e
  importa como nota de entrada da empresa da sessao:

    - parser proprio de tags, tolerante a prefixo de namespace;
    - fornecedor localizado pelo CNPJ (somente digitos) e, na
      falta, pelo nome do emitente;
    - produto localizado por CODIGO/CODIGO_BARRAS (cProd/cEAN);
    - itens sem produto ficam gravados e sao contados para o
      usuario vincular depois (duplo clique na tela);
    - chave de acesso repetida na empresa e recusada;
    - se um item falhar, a nota parcial e removida.

  A gravacao do cabecalho/item (totais, auditoria e transacao)
  continua em TNotaEntradaService.
  ============================================================ }

interface

uses
  Classes, SysUtils;

type
  ENFeXml = class(Exception);

  TNFeXmlItem = record
    Codigo: string;
    Ean: string;
    Descricao: string;
    Ncm: string;
    Cfop: string;
    CstIcms: string;
    Unidade: string;
    Quantidade: Double;
    ValorUnitario: Double;
    Desconto: Double;
  end;

  TNFeXml = class
  public
    ChaveAcesso: string;
    Numero: string;
    Serie: string;
    Modelo: string;
    DataEmissao: TDate;
    NaturezaOperacao: string;
    Cfop: string;
    EmitenteNome: string;
    EmitenteCnpj: string;
    ValorProdutos: Double;
    ValorFrete: Double;
    ValorSeguro: Double;
    ValorDesconto: Double;
    ValorOutras: Double;
    ValorTotal: Double;
    Itens: array of TNFeXmlItem;
    { Acrescenta um item vazio e devolve o indice criado. }
    function AdicionarItem: Integer;
  end;

  { Leitura pura do XML: nao toca no banco. }
  TNFeXmlParser = class
  public
    { Remove BOM e prefixos de namespace (nfe:, ns2: ...), para que a
      leitura por tags funcione tanto no XML padrao quanto no prefixado. }
    class function Normalizar(const AXml: string): string;
    class function DeArquivo(const ACaminho: string): TNFeXml;
    class function DeTexto(const AXml: string): TNFeXml;
  end;

  { Importacao do XML como nota de entrada (status Aberta). }
  TNFeImportService = class
  public
    { Devolve True quando a nota foi criada. ANotaId recebe o ID da nota,
      AItensIncluidos o total de itens gravados e AItensSemProduto quantos
      ficaram sem vinculo com o cadastro de produtos. }
    class function Importar(const ACaminhoXML: string; out ANotaId: Int64;
      out AItensIncluidos, AItensSemProduto: Integer): Boolean;
  end;

implementation

uses
  StrUtils, SQLDB, uConexao, uSessao, uAuditoria, uNotaEntradaService;

function SomenteDigitos(const AValor: string): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := 1 to Length(AValor) do
    if AValor[LI] in ['0'..'9'] then
      Result := Result + AValor[LI];
end;

{ Entidades XML mais comuns (descricao de produto costuma vir com &amp;). }
function DecodificarXml(const AValor: string): string;
begin
  Result := StringReplace(AValor, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&apos;', '''', [rfReplaceAll]);
  // &amp; por ultimo para nao decodificar duas vezes (&amp;lt;)
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
end;

{ Texto interno da primeira tag encontrada. Aceita atributos na abertura
  (<tag ...>) e ignora tags cujo nome apenas comeca igual (ex.: detX). }
function TagTexto(const ATexto, ATag: string): string;
var
  LAbre, LFecha: string;
  LP1, LP2, LFim: Integer;
begin
  Result := '';
  LAbre := '<' + ATag;
  LFecha := '</' + ATag + '>';
  LP1 := 1;
  while True do
  begin
    LP1 := PosEx(LAbre, ATexto, LP1);
    if LP1 = 0 then
      Exit;
    if (LP1 + Length(LAbre) <= Length(ATexto)) and
       ((ATexto[LP1 + Length(LAbre)] = '>') or
        (ATexto[LP1 + Length(LAbre)] = ' ')) then
      Break;
    Inc(LP1, Length(LAbre));
  end;
  LFim := PosEx('>', ATexto, LP1);
  if LFim = 0 then
    Exit;
  LP2 := PosEx(LFecha, ATexto, LFim + 1);
  if LP2 = 0 then
    Exit;
  Result := DecodificarXml(Trim(Copy(ATexto, LFim + 1, LP2 - LFim - 1)));
end;

{ Todos os blocos de uma tag, na ordem do arquivo. }
function TagBlocos(const ATexto, ATag: string): TStringList;
var
  LAbre, LFecha: string;
  LP, LP1, LP2: Integer;
begin
  Result := TStringList.Create;
  LAbre := '<' + ATag;
  LFecha := '</' + ATag + '>';
  LP := 1;
  while True do
  begin
    LP1 := PosEx(LAbre, ATexto, LP);
    if LP1 = 0 then
      Break;
    if LP1 + Length(LAbre) > Length(ATexto) then
      Break;
    if not ((ATexto[LP1 + Length(LAbre)] = '>') or
            (ATexto[LP1 + Length(LAbre)] = ' ')) then
    begin
      LP := LP1 + Length(LAbre);
      Continue;
    end;
    LP1 := PosEx('>', ATexto, LP1) + 1;
    LP2 := PosEx(LFecha, ATexto, LP1);
    if LP2 = 0 then
      Break;
    Result.Add(Copy(ATexto, LP1, LP2 - LP1));
    LP := LP2 + Length(LFecha);
  end;
end;

function NumXml(const AValor: string): Double;
var
  LTexto: string;
begin
  LTexto := Trim(AValor);
  if LTexto = '' then
    Exit(0);
  LTexto := StringReplace(LTexto, ' ', '', [rfReplaceAll]);
  if FormatSettings.DecimalSeparator = ',' then
    LTexto := StringReplace(LTexto, '.', ',', [rfReplaceAll])
  else
    LTexto := StringReplace(LTexto, ',', '.', [rfReplaceAll]);
  Result := StrToFloatDef(LTexto, 0);
end;

function DataXml(const AValor: string): TDate;
var
  LAno, LMes, LDia: Integer;
begin
  Result := 0;
  // Formato NF-e: 2026-10-17T13:50:48-03:00 ou 2026-10-17
  if Length(AValor) < 10 then
    Exit;
  LAno := StrToIntDef(Copy(AValor, 1, 4), 0);
  LMes := StrToIntDef(Copy(AValor, 6, 2), 0);
  LDia := StrToIntDef(Copy(AValor, 9, 2), 0);
  if (LAno > 1900) and (LMes >= 1) and (LMes <= 12) and
     (LDia >= 1) and (LDia <= 31) then
    Result := EncodeDate(LAno, LMes, LDia);
end;

function ChaveDoXml(const ATexto: string): string;
var
  LP, LFim: Integer;
begin
  Result := '';
  LP := Pos('Id="', ATexto);
  if LP = 0 then
    Exit;
  Result := Copy(ATexto, LP + 4, 60);
  LFim := Pos('"', Result);
  if LFim > 0 then
    Result := Copy(Result, 1, LFim - 1);
  Result := Trim(Result);
  if (Length(Result) > 3) and (Copy(Result, 1, 3) = 'NFe') then
    Result := Copy(Result, 4, Length(Result));
end;

{ ------------------------------------------------------------------
  TNFeXml
  ------------------------------------------------------------------ }

function TNFeXml.AdicionarItem: Integer;
begin
  Result := Length(Itens);
  SetLength(Itens, Result + 1);
end;

{ ------------------------------------------------------------------
  TNFeXmlParser
  ------------------------------------------------------------------ }

class function TNFeXmlParser.Normalizar(const AXml: string): string;
var
  LI, LJ: Integer;
begin
  Result := '';
  LI := 1;
  // BOM UTF-8
  if (Length(AXml) >= 3) and (AXml[1] = #$EF) and
     (AXml[2] = #$BB) and (AXml[3] = #$BF) then
    LI := 4;
  while LI <= Length(AXml) do
  begin
    if AXml[LI] = '<' then
    begin
      Result := Result + '<';
      Inc(LI);
      if (LI <= Length(AXml)) and (AXml[LI] = '/') then
      begin
        Result := Result + '/';
        Inc(LI);
      end;
      // pula o prefixo de namespace (nfe:, ns2: ...)
      LJ := LI;
      while (LJ <= Length(AXml)) and
            (AXml[LJ] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.']) do
        Inc(LJ);
      if (LJ <= Length(AXml)) and (AXml[LJ] = ':') then
        LI := LJ + 1;
    end
    else
    begin
      Result := Result + AXml[LI];
      Inc(LI);
    end;
  end;
end;

class function TNFeXmlParser.DeTexto(const AXml: string): TNFeXml;
var
  LTexto, LBloco, LEmit, LTotal, LDet, LProd, LImposto, LCst: string;
  LLista: TStringList;
  LI, LIndice: Integer;
  LItem: TNFeXmlItem;
begin
  if Trim(AXml) = '' then
    raise ENFeXml.Create('Arquivo XML vazio ou ilegível.');

  LTexto := Normalizar(AXml);

  LLista := TagBlocos(LTexto, 'infNFe');
  try
    if LLista.Count = 0 then
      raise ENFeXml.Create('XML não parece ser uma NF-e (tag infNFe ausente).');
    LBloco := LLista[0];
  finally
    LLista.Free;
  end;

  Result := TNFeXml.Create;
  try
    Result.ChaveAcesso := ChaveDoXml(LTexto);
    Result.Numero := TagTexto(LBloco, 'nNF');
    Result.Serie := TagTexto(LBloco, 'serie');
    Result.Modelo := TagTexto(LBloco, 'mod');
    if Trim(Result.Modelo) = '' then
      Result.Modelo := '55';
    Result.DataEmissao := DataXml(TagTexto(LBloco, 'dhEmi'));
    if Result.DataEmissao <= 0 then
      Result.DataEmissao := DataXml(TagTexto(LBloco, 'dEmi'));
    Result.NaturezaOperacao := TagTexto(LBloco, 'natOp');

    LEmit := TagTexto(LBloco, 'emit');
    if LEmit <> '' then
    begin
      Result.EmitenteNome := TagTexto(LEmit, 'xNome');
      Result.EmitenteCnpj := TagTexto(LEmit, 'CNPJ');
      if Trim(Result.EmitenteCnpj) = '' then
        Result.EmitenteCnpj := TagTexto(LEmit, 'CPF');
    end;

    { totais vem do bloco ICMSTot; sem ele, tenta no proprio infNFe }
    LTotal := TagTexto(LBloco, 'ICMSTot');
    if Trim(LTotal) = '' then
      LTotal := LBloco;
    Result.ValorProdutos := NumXml(TagTexto(LTotal, 'vProd'));
    Result.ValorFrete := NumXml(TagTexto(LTotal, 'vFrete'));
    Result.ValorSeguro := NumXml(TagTexto(LTotal, 'vSeg'));
    Result.ValorDesconto := NumXml(TagTexto(LTotal, 'vDesc'));
    Result.ValorOutras := NumXml(TagTexto(LTotal, 'vOutro'));
    Result.ValorTotal := NumXml(TagTexto(LTotal, 'vNF'));

    LLista := TagBlocos(LBloco, 'det');
    try
      for LI := 0 to LLista.Count - 1 do
      begin
        LDet := LLista[LI];
        LProd := TagTexto(LDet, 'prod');
        if Trim(LProd) = '' then
          LProd := LDet;

        LItem.Codigo := TagTexto(LProd, 'cProd');
        LItem.Ean := TagTexto(LProd, 'cEAN');
        LItem.Descricao := TagTexto(LProd, 'xProd');
        LItem.Ncm := TagTexto(LProd, 'NCM');
        LItem.Cfop := TagTexto(LProd, 'CFOP');
        LItem.CstIcms := '';
        LItem.Unidade := TagTexto(LProd, 'uCom');
        LItem.Quantidade := NumXml(TagTexto(LProd, 'qCom'));
        LItem.ValorUnitario := NumXml(TagTexto(LProd, 'vUnCom'));
        LItem.Desconto := NumXml(TagTexto(LProd, 'vDesc'));

        LImposto := TagTexto(LDet, 'ICMS');
        if Trim(LImposto) <> '' then
        begin
          LCst := TagTexto(LImposto, 'CST');
          if Trim(LCst) = '' then
            LCst := TagTexto(LImposto, 'CSOSN');
          LItem.CstIcms := LCst;
        end;

        if LItem.Quantidade <= 0 then
          LItem.Quantidade := 1;

        LIndice := Result.AdicionarItem;
        Result.Itens[LIndice] := LItem;
      end;
    finally
      LLista.Free;
    end;

    if Length(SomenteDigitos(Result.ChaveAcesso)) <> 44 then
      raise ENFeXml.Create('XML sem chave de acesso válida (44 dígitos).');
    if Trim(Result.Numero) = '' then
      raise ENFeXml.Create('XML sem o número da nota (nNF).');
    if Length(Result.Itens) = 0 then
      raise ENFeXml.Create('XML sem itens (det).');
    if (Trim(Result.EmitenteCnpj) = '') and
       (Trim(Result.EmitenteNome) = '') then
      raise ENFeXml.Create('XML sem emitente (CNPJ/nome).');

    Result.Cfop := Result.Itens[0].Cfop;
  except
    Result.Free;
    raise;
  end;
end;

class function TNFeXmlParser.DeArquivo(const ACaminho: string): TNFeXml;
var
  LArquivo: TStringList;
begin
  if not FileExists(ACaminho) then
    raise ENFeXml.Create('Arquivo XML não encontrado: ' + ACaminho);
  LArquivo := TStringList.Create;
  try
    LArquivo.LoadFromFile(ACaminho);
    Result := DeTexto(LArquivo.Text);
  finally
    LArquivo.Free;
  end;
end;

{ ------------------------------------------------------------------
  TNFeImportService
  ------------------------------------------------------------------ }

function LocalizarFornecedor(const ANFe: TNFeXml;
  AQuery: TSQLQuery): Int64;
var
  LDOC: string;
begin
  Result := 0;
  LDOC := SomenteDigitos(ANFe.EmitenteCnpj);
  if LDOC <> '' then
  begin
    AQuery.Close;
    AQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM PESSOA WHERE TIPO = ''F'' AND ' +
      'EMPRESA_ID = :EMP AND ' +
      'REPLACE(REPLACE(REPLACE(CAST(COALESCE(CPF_CNPJ, '''') AS VARCHAR(40)), ' +
      '''.'', ''''), ''/'', ''''), ''-'', '''') = CAST(:DOC AS VARCHAR(40)) ' +
      'ORDER BY ID';
    AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    AQuery.ParamByName('DOC').AsString := LDOC;
    AQuery.Open;
    if not AQuery.IsEmpty then
      Result := AQuery.FieldByName('ID').AsLargeInt;
    AQuery.Close;
  end;

  if (Result = 0) and (Trim(ANFe.EmitenteNome) <> '') then
  begin
    AQuery.Close;
    AQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM PESSOA WHERE TIPO = ''F'' AND ' +
      'EMPRESA_ID = :EMP AND ' +
      '(UPPER(COALESCE(NOME, NOME_FANTASIA)) = UPPER(:NOME) OR ' +
      ' UPPER(COALESCE(NOME_FANTASIA, NOME)) = UPPER(:NOME)) ORDER BY ID';
    AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    AQuery.ParamByName('NOME').AsString := Trim(ANFe.EmitenteNome);
    AQuery.Open;
    if not AQuery.IsEmpty then
      Result := AQuery.FieldByName('ID').AsLargeInt;
    AQuery.Close;
  end;
end;

function LocalizarProduto(const AItem: TNFeXmlItem;
  AQuery: TSQLQuery): Int64;
var
  LEan: string;
begin
  Result := 0;
  if Trim(AItem.Codigo) <> '' then
  begin
    AQuery.Close;
    AQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM PRODUTO WHERE EMPRESA_ID = :EMP AND ' +
      '(CODIGO = :C OR CODIGO_BARRAS = :C) ORDER BY ID';
    AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    AQuery.ParamByName('C').AsString := Trim(AItem.Codigo);
    AQuery.Open;
    if not AQuery.IsEmpty then
      Result := AQuery.FieldByName('ID').AsLargeInt;
    AQuery.Close;
  end;

  if Result = 0 then
  begin
    LEan := Trim(AItem.Ean);
    if (LEan <> '') and (UpperCase(LEan) <> 'SEM GTIN') then
    begin
      AQuery.Close;
      AQuery.SQL.Text :=
        'SELECT FIRST 1 ID FROM PRODUTO WHERE EMPRESA_ID = :EMP AND ' +
        'CODIGO_BARRAS = :C ORDER BY ID';
      AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      AQuery.ParamByName('C').AsString := LEan;
      AQuery.Open;
      if not AQuery.IsEmpty then
        Result := AQuery.FieldByName('ID').AsLargeInt;
      AQuery.Close;
    end;
  end;
end;

function NotaDaChave(const AChave: string; AQuery: TSQLQuery): Int64;
begin
  Result := 0;
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT FIRST 1 ID FROM NOTA_ENTRADA WHERE EMPRESA_ID = :EMP AND ' +
    'CHAVE_ACESSO = :CHAVE AND STATUS <> ''C'' ORDER BY ID';
  AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  AQuery.ParamByName('CHAVE').AsString := AChave;
  AQuery.Open;
  if not AQuery.IsEmpty then
    Result := AQuery.FieldByName('ID').AsLargeInt;
  AQuery.Close;
end;

procedure RemoverNotaParcial(ANotaId: Int64; AQuery: TSQLQuery;
  AConexao: TConexao);
begin
  if ANotaId <= 0 then
    Exit;
  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID';
    AQuery.ParamByName('ID').AsLargeInt := ANotaId;
    AConexao.IniciarTransacao;
    AQuery.ExecSQL;
    AConexao.Confirmar;

    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM NOTA_ENTRADA WHERE ID = :ID AND STATUS = ''A''';
    AQuery.ParamByName('ID').AsLargeInt := ANotaId;
    AConexao.IniciarTransacao;
    AQuery.ExecSQL;
    AConexao.Confirmar;
  except
    // compensacao best effort: nao esconde o erro original
  end;
end;

class function TNFeImportService.Importar(const ACaminhoXML: string;
  out ANotaId: Int64; out AItensIncluidos, AItensSemProduto: Integer): Boolean;
var
  LNFe: TNFeXml;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LNota: TNotaEntradaService;
  LDados: TNotaEntradaCabecalho;
  LFornecedorId, LProdutoId, LNotaExistente: Int64;
  LI: Integer;
begin
  Result := False;
  ANotaId := 0;
  AItensIncluidos := 0;
  AItensSemProduto := 0;

  LNFe := TNFeXmlParser.DeArquivo(ACaminhoXML);
  try
    LConexao := TConexao.GetInstance;
    LQuery := TSQLQuery.Create(nil);
    try
      LQuery.DataBase := LConexao.Connection;
      LQuery.Transaction := LConexao.Transaction;

      LNotaExistente := NotaDaChave(LNFe.ChaveAcesso, LQuery);
      if LNotaExistente > 0 then
        raise ENFeXml.Create(Format(
          'Esta NF-e já foi importada (nota de entrada %d).',
          [LNotaExistente]));

      LFornecedorId := LocalizarFornecedor(LNFe, LQuery);
      if LFornecedorId <= 0 then
        raise ENFeXml.Create(Format(
          'Fornecedor "%s" (CNPJ %s) não encontrado no cadastro da empresa. ' +
          'Cadastre-o e importe novamente.',
          [Trim(LNFe.EmitenteNome), Trim(LNFe.EmitenteCnpj)]));

      LDados.FornecedorId := LFornecedorId;
      LDados.Numero := LNFe.Numero;
      LDados.Serie := LNFe.Serie;
      LDados.Modelo := LNFe.Modelo;
      LDados.ChaveAcesso := LNFe.ChaveAcesso;
      LDados.DataEmissao := LNFe.DataEmissao;
      if LDados.DataEmissao <= 0 then
        LDados.DataEmissao := Date;
      LDados.DataEntrada := Date;
      LDados.NaturezaOperacao := LNFe.NaturezaOperacao;
      LDados.Cfop := LNFe.Cfop;
      LDados.ValorFrete := LNFe.ValorFrete;
      LDados.ValorSeguro := LNFe.ValorSeguro;
      LDados.ValorOutras := LNFe.ValorOutras;
      LDados.ValorDesconto := LNFe.ValorDesconto;
      LDados.CondicaoPagamentoId := 0;

      LNota := TNotaEntradaService.Create;
      try
        ANotaId := LNota.SalvarCabecalho(0, LDados);
        try
          for LI := 0 to High(LNFe.Itens) do
          begin
            LProdutoId := LocalizarProduto(LNFe.Itens[LI], LQuery);
            if LProdutoId <= 0 then
              Inc(AItensSemProduto);
            LNota.SalvarItem(ANotaId, 0, LProdutoId,
              LNFe.Itens[LI].Descricao, LNFe.Itens[LI].Quantidade,
              LNFe.Itens[LI].ValorUnitario, LNFe.Itens[LI].Desconto,
              LNFe.Itens[LI].Ncm, LNFe.Itens[LI].Cfop,
              LNFe.Itens[LI].CstIcms, -1);
            Inc(AItensIncluidos);
          end;

          { guarda o nome do XML para rastrear a origem da nota }
          LQuery.Close;
          LQuery.SQL.Text :=
            'UPDATE NOTA_ENTRADA SET XML_ARQUIVO = :ARQ ' +
            'WHERE ID = :ID AND STATUS = ''A''';
          LQuery.ParamByName('ARQ').AsString := ExtractFileName(ACaminhoXML);
          LQuery.ParamByName('ID').AsLargeInt := ANotaId;
          LConexao.IniciarTransacao;
          LQuery.ExecSQL;
          LConexao.Confirmar;

          RegistrarAuditoria('XML_FISCAL', 'IMPORTACAO_XML', ANotaId, '',
            'Arquivo=' + ExtractFileName(ACaminhoXML) +
            '; Chave=' + LNFe.ChaveAcesso +
            '; Itens=' + IntToStr(AItensIncluidos) +
            '; SemProduto=' + IntToStr(AItensSemProduto));

          Result := True;
        except
          RemoverNotaParcial(ANotaId, LQuery, LConexao);
          ANotaId := 0;
          AItensIncluidos := 0;
          AItensSemProduto := 0;
          raise;
        end;
      finally
        LNota.Free;
      end;
    finally
      LQuery.Free;
    end;
  finally
    LNFe.Free;
  end;
end;

end.
