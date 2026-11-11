program ERP2026;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Programa Principal
  Descrição: Aplicação ERP Desktop Completa (Fases 1-9)
  IDE: Lazarus
  Banco: Firebird 5
  ============================================================ }

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Controls, SysUtils,
  // Config
  uConexao,
  uSessao,
  // Models
  uModelBase,
  uEmpresa,
  uUsuario,
  uGrupo,
  uPessoa,
  uProduto,
  uCategoria,
  uUnidade,
  uEstoque,
  uPedidoVenda,
  uPedidoStatus,
  uMapaProducaoStatus,
  uPais,
  uEstado,
  uCidade,
  uGrade,
  // Models - fase 1 redesenho (suprimentos/fiscal/financeiro)
  uProdutoFiscal,
  uMaterial,
  uCor,
  // Repositories
  uRepositoryBase,
  // Services
  uServiceBase,
  uPessoaService,
  uMovimentoFinanceiroService,
  uInventarioService,
  uKardexService,
  uProdutoFiscalService,
  uMaterialService,
  uCorService,
  uPaisService,
  uEstadoService,
  uCidadeService,
  uGradeService,
  uACBrHelper,
  // Utils
  uValidacoes,
  uTraducao,
  // Views - Fase 2
  uFrmLogin,
  uFrmPrincipal,
  uFrmCadastroBase,
  uFrmPessoas,
  uFrmProdutos,
  uFrmCategorias,
  uFrmUsuarios,
  // Views - fase 1 (redesenho): cadastros novos
  uFrmProdutoFiscal,
  uFrmMaterial,
  uFrmMovimentoFinanceiro,
  uFrmCompras,
  uFrmPais,
  uFrmEstado,
  uFrmCidade,
  uFrmGrade,
  uFrmGradeQuantidades,
  // Views - Fase 3
  uFrmMovEstoque,
  uFrmKardex,
  uFrmInventario,
  // Views - Fase 4
  uFrmPedidoVenda,
  uFrmListaPedidos,
  uFrmMapaProducao,
  uFrmBipagem,
  // Views - Produção Fase 5
  uFrmFichaTecnica,
  uFrmConsumoMaterial,
  uFrmOrcamento,
  // Views - Fase 5
  uFrmPDV,
  uFrmContasReceber,
  uFrmContasPagar,
  // Views - Fase 6
  uFrmNFe,
  // Views - Fase 9
  uFrmCopiloto,
  // Views - telas de administração (menu Sistema / Financeiro / Relatórios)
  uFrmCaixa,
  uFrmConfiguracoes,
  uFrmPermissoes,
  uFrmCentralRelatorios;

{$R *.res}

{ Validação local da NF-e (sem SEFAZ):
    ERP2026.exe --validar-nfe=<id do pedido> [--cert=<pfx>] [--senha=<senha>]
  Monta o XML e valida contra os schemas. Com um certificado (mesmo
  autoassinado de teste) a nota é assinada e o XML completo é validado;
  sem certificado apenas os dados fiscais são conferidos. O resultado
  vai para bin\nfe\validacao_<id>.txt. Nada é enviado à SEFAZ.
  O certificado e a senha também podem vir das variáveis de ambiente
  ERP_NFE_CERT e ERP_NFE_SENHA. }
function ParametroOuAmbiente(const APrefixo, AVariavel: string): string;
var
  LIndice: Integer;
begin
  for LIndice := 1 to ParamCount do
    if Pos(APrefixo, ParamStr(LIndice)) = 1 then
      Exit(Copy(ParamStr(LIndice), Length(APrefixo) + 1, MaxInt));

  Result := GetEnvironmentVariable(AVariavel);
end;

procedure ValidarNFePorLinhaDeComando(const AArg: string);
const
  PREFIXO = '--validar-nfe=';
var
  LId: Int64;
  LHelper: TACBrHelper;
  LDados: TACBrDadosNFe;
  LArquivo: TextFile;
  LCaminho, LBase, LErro: string;
  LOk: Boolean;
begin
  LId := StrToInt64Def(Copy(AArg, Length(PREFIXO) + 1, MaxInt), 0);
  if LId <= 0 then
  begin
    WriteLn('Uso: ERP2026.exe --validar-nfe=<id do pedido> ' +
      '[--cert=<pfx>] [--senha=<senha>]');
    Halt(2);
  end;

  LBase := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  ForceDirectories(LBase + 'nfe');
  LCaminho := LBase + 'nfe' + PathDelim + 'validacao_' + IntToStr(LId) + '.txt';
  LOk := False;
  LErro := '';

  TConexao.GetInstance.Conectar;
  TSessao.GetInstance.Logar(1, 1, 1, 'Validador NFe', 'validador', True);
  LHelper := TACBrHelper.Create;
  try
    try
      LHelper.ModoSimulado := False;
      LHelper.CaminhoSchemas := LBase + 'schemas';
      LHelper.CaminhoSalvar := LBase + 'nfe';
      LHelper.Configurar(
        ParametroOuAmbiente('--cert=', 'ERP_NFE_CERT'),
        ParametroOuAmbiente('--senha=', 'ERP_NFE_SENHA'),
        'SP', 2);
      LDados := LHelper.ValidarNFe(LId);
      LOk := True;

      AssignFile(LArquivo, LCaminho);
      Rewrite(LArquivo);
      try
        WriteLn(LArquivo, 'OK');
        WriteLn(LArquivo, 'Numero=' + IntToStr(LDados.Numero));
        WriteLn(LArquivo, 'Serie=' + IntToStr(LDados.Serie));
        WriteLn(LArquivo, 'Chave=' + LDados.ChaveAcesso);
        WriteLn(LArquivo, 'Motivo=' + LDados.Motivo);
      finally
        CloseFile(LArquivo);
      end;
    except
      on E: Exception do
      begin
        LErro := E.Message;
        AssignFile(LArquivo, LCaminho);
        Rewrite(LArquivo);
        try
          WriteLn(LArquivo, 'ERRO=' + LErro);
        finally
          CloseFile(LArquivo);
        end;
      end;
    end;
  finally
    LHelper.Free;
    TSessao.GetInstance.Deslogar;
    TConexao.GetInstance.Desconectar;
  end;

  if LOk then
  begin
    WriteLn('OK: XML valido. Veja ' + LCaminho);
    Halt(0);
  end
  else
  begin
    WriteLn('ERRO: ' + LErro);
    Halt(1);
  end;
end;

begin
  // Todo o sistema trata AnsiString como UTF-8 (fonte, LCL e Firebird com
  // CharSet=UTF8). Sem isto, o SQLDB converte os literais acentuados de
  // CP1252 para UTF-8 e grava "NF de saÃ­da".
  SetMultiByteConversionCodePage(CP_UTF8);
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  AplicarIdiomaPortugues;   // diálogos do LCL em português (Sim/Não, títulos)

  // Ferramenta de diagnóstico: valida o XML da NF-e sem enviar à SEFAZ.
  if (ParamCount >= 1) and (Pos('--validar-nfe=', ParamStr(1)) = 1) then
    ValidarNFePorLinhaDeComando(ParamStr(1));

  // Login
  Application.CreateForm(TfrmLogin, frmLogin);
  if frmLogin.ShowModal = mrOk then
  begin
    frmLogin.Free;
    // Tela principal
    Application.CreateForm(TfrmPrincipal, frmPrincipal);
    Application.Run;
  end
  else
    Application.Terminate;
end.
