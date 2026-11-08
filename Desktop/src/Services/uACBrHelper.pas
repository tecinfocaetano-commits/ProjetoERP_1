unit uACBrHelper;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 6 - ACBr Helper
  Descrição: Wrapper para integração com ACBr (NF-e, NFC-e)
  Nota: Requer ACBr instalado no Lazarus
  ============================================================ }

interface

uses
  Classes, SysUtils;

type
  TACBrStatusNFe = (ansNenhum, ansPendente, ansAutorizada, ansCancelada, ansDenegada);

  TACBrDadosNFe = record
    Numero: Integer;
    Serie: Integer;
    NaturezaOperacao: string;
    CFOP: string;
    ChaveAcesso: string;
    Status: TACBrStatusNFe;
    Protocolo: string;
    XML: string;
  end;

  { TACBrHelper }
  TACBrHelper = class
  private
    FCaminhoSchemas: string;
    FCaminhoCertificado: string;
    FSenhaCertificado: string;
    FAmbiente: Integer; // 1=Produção, 2=Homologação
    FUF: string;
    procedure ValidarConfiguracao;
  public
    constructor Create;

    procedure Configurar(const ACaminhoCert, ASenha, AUF: string; AAmbiente: Integer);

    function GerarNFe(APedidoId: Int64): TACBrDadosNFe;
    function GerarNFCe(APedidoId: Int64): TACBrDadosNFe;
    function ConsultarNFe(const AChave: string): TACBrDadosNFe;
    function CancelarNFe(const AChave, AJustificativa: string): Boolean;
    function ImportarXML(const ACaminhoXML: string): Int64;
    function ManifestarNFe(const AChave: string; ATipoManifestacao: Integer): Boolean;

    property CaminhoSchemas: string read FCaminhoSchemas write FCaminhoSchemas;
    property CaminhoCertificado: string read FCaminhoCertificado;
    property Ambiente: Integer read FAmbiente;
    property UF: string read FUF;
  end;

implementation

uses
  uConexao, SQLDB, uAuditoria, uSessao;

constructor TACBrHelper.Create;
begin
  inherited Create;
  FAmbiente := 2; // Homologação por padrão
  FUF := 'SP';
end;

procedure TACBrHelper.Configurar(const ACaminhoCert, ASenha, AUF: string; AAmbiente: Integer);
begin
  FCaminhoCertificado := ACaminhoCert;
  FSenhaCertificado := ASenha;
  FUF := AUF;
  FAmbiente := AAmbiente;
end;

procedure TACBrHelper.ValidarConfiguracao;
begin
  if FCaminhoCertificado = '' then
    raise Exception.Create('Certificado digital não configurado.');
  if FSenhaCertificado = '' then
    raise Exception.Create('Senha do certificado não informada.');
end;

function TACBrHelper.GerarNFe(APedidoId: Int64): TACBrDadosNFe;
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
begin
  ValidarConfiguracao;
  LConexao := TConexao.GetInstance;
  Result.Status := ansPendente;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    // Carregar dados do pedido
    LQuery.SQL.Text :=
      'SELECT PV.*, C.NOME, C.CPF_CNPJ, C.ENDERECO, C.NUMERO, C.BAIRRO, ' +
      'C.CIDADE, C.UF, C.CEP, E.RAZAO_SOCIAL AS EMPRESA_RAZAO, E.CNPJ AS EMPRESA_CNPJ ' +
      'FROM PEDIDO_VENDA PV ' +
      'JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
      '  AND C.EMPRESA_ID = PV.EMPRESA_ID ' +
      'JOIN EMPRESA E ON E.ID = PV.EMPRESA_ID ' +
      'WHERE PV.ID = :ID AND PV.EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;

    if LQuery.IsEmpty then
      raise Exception.Create('Pedido não encontrado.');

    // Gerar próximo número
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT COALESCE(MAX(NUMERO_NFE), 0) + 1 FROM PEDIDO_VENDA ' +
      'WHERE NUMERO_NFE IS NOT NULL AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    Result.Numero := LQuery.Fields[0].AsInteger;
    Result.Serie := 1;
    Result.NaturezaOperacao := 'VENDA';
    Result.CFOP := '5102';

    { ====================================================================
      INTEGRAÇÃO ACBr - DESCOMENTAR QUANDO ACBr ESTIVER INSTALADO:

      ACBrNFe1.NotasFiscais.Clear;
      with ACBrNFe1.NotasFiscais.Add.NFe do
      begin
        Ide.NatOp := Result.NaturezaOperacao;
        Ide.Serie := Result.Serie;
        Ide.nNF := Result.Numero;
        Ide.tpAmb := FAmbiente;
        // ... preencher emitente, destinatário, itens
      end;
      ACBrNFe1.Enviar(1);
      Result.ChaveAcesso := ACBrNFe1.NotasFiscais[0].NFe.procNFe.chNFe;
      Result.Protocolo := ACBrNFe1.NotasFiscais[0].NFe.procNFe.nProt;
      Result.XML := ACBrNFe1.NotasFiscais[0].XMLOriginal;
      Result.Status := ansAutorizada;
    ==================================================================== }

    // Simulação para ambiente sem ACBr
    Result.ChaveAcesso := Format('%s%s%s%s',
      [FormatDateTime('yymm', Now),
       IntToStr(Result.Numero),
       IntToStr(Random(999999)),
       IntToStr(Random(999999))]);
    Result.Protocolo := 'SIM' + IntToStr(Random(9999999));
    Result.Status := ansPendente;
    Result.XML := '<nfeProc><!-- XML será gerado pelo ACBr --></nfeProc>';

    // Atualizar pedido com dados da NF-e (transação + auditoria)
    LQuery.Close;
    LQuery.SQL.Text :=
      'UPDATE PEDIDO_VENDA SET NUMERO_NFE = :NUM, CHAVE_NFE = :CHAVE ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('NUM').AsInteger := Result.Numero;
    LQuery.ParamByName('CHAVE').AsString := Result.ChaveAcesso;
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LConexao.IniciarTransacao;
    try
      LQuery.ExecSQL;
      RegistrarAuditoria('PEDIDO_VENDA', 'NFE', APedidoId, '',
        ResumoAuditoria(['NUMERO_NFE=' + IntToStr(Result.Numero),
          'CHAVE=' + Result.ChaveAcesso]));
      LConexao.Confirmar;
    except
      LConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TACBrHelper.GerarNFCe(APedidoId: Int64): TACBrDadosNFe;
begin
  // NFC-e usa modelo 65 (consumidor final)
  Result := GerarNFe(APedidoId);
  Result.NaturezaOperacao := 'VENDA AO CONSUMIDOR';
end;

function TACBrHelper.ConsultarNFe(const AChave: string): TACBrDadosNFe;
begin
  ValidarConfiguracao;
  Result.ChaveAcesso := AChave;
  Result.Status := ansPendente;

  { INTEGRAÇÃO ACBr:
    ACBrNFe1.Consultar(AChave);
    Result.Status := TACBrStatusNFe(ACBrNFe1.NotasFiscais[0].NFe.procNFe.cStat);
    Result.Protocolo := ACBrNFe1.NotasFiscais[0].NFe.procNFe.nProt;
  }
end;

function TACBrHelper.CancelarNFe(const AChave, AJustificativa: string): Boolean;
begin
  ValidarConfiguracao;
  Result := False;

  if Length(AJustificativa) < 15 then
    raise Exception.Create('Justificativa deve ter no mínimo 15 caracteres.');

  { INTEGRAÇÃO ACBr:
    ACBrNFe1.Cancelamento.Justificativa := AJustificativa;
    ACBrNFe1.Cancelamento.CNPJ := Empresa.CNPJ;
    Result := ACBrNFe1.Cancelar(AChave, AJustificativa);
  }
end;

function TACBrHelper.ImportarXML(const ACaminhoXML: string): Int64;
begin
  Result := 0;
  if not FileExists(ACaminhoXML) then
    raise Exception.Create('Arquivo XML não encontrado: ' + ACaminhoXML);

  { auditoria via uAuditoria (SQL parametrizado, empresa/usuário da sessão,
    dentro da transação corrente): o INSERT antigo usava colunas inexistentes
    em LOG_SISTEMA (MODULO/ACAO/DESCRICAO) e estourava "Column unknown" }
  RegistrarAuditoria('XML_FISCAL', 'IMPORTACAO_XML', 0, '',
    'XML importado: ' + ExtractFileName(ACaminhoXML));
  TConexao.GetInstance.Confirmar;

  Result := 1;
end;

function TACBrHelper.ManifestarNFe(const AChave: string; ATipoManifestacao: Integer): Boolean;
begin
  ValidarConfiguracao;
  Result := False;

  { INTEGRAÇÃO ACBr:
    Tipos: 210200=Confirmação, 210210=Ciência, 210220=Desconhecimento, 210240=Recusa
    ACBrNFe1.EventoNFe.Evento[0].InfEvento.tpEvento := ATipoManifestacao;
    ACBrNFe1.EventoNFe.Evento[0].InfEvento.chNFe := AChave;
    Result := ACBrNFe1.EnviarEvento;
  }
end;

end.
