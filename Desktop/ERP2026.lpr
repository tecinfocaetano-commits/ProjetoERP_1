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
  Forms, Controls,
  // Config
  uConexao,
  uSessao,
  // Models
  uModelBase,
  uEmpresa,
  uUsuario,
  uGrupo,
  uCliente,
  uFornecedor,
  uProduto,
  uCategoria,
  uUnidade,
  uEstoque,
  uPedidoVenda,
  // Models - fase 1 redesenho (suprimentos/fiscal/financeiro)
  uProdutoFiscal,
  uMaterial,
  uCor,
  // Repositories
  uRepositoryBase,
  // Services
  uServiceBase,
  uClienteService,
  uProdutoFiscalService,
  uMaterialService,
  uCorService,
  uACBrHelper,
  // Utils
  uValidacoes,
  uTraducao,
  // Views - Fase 2
  uFrmLogin,
  uFrmPrincipal,
  uFrmCadastroBase,
  uFrmClientes,
  uFrmFornecedores,
  uFrmProdutos,
  uFrmCategorias,
  uFrmUsuarios,
  // Views - fase 1 (redesenho): cadastros novos
  uFrmProdutoFiscal,
  uFrmMaterial,
  uFrmMovimentoFinanceiro,
  uFrmCompras,
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

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  AplicarIdiomaPortugues;   // diálogos do LCL em português (Sim/Não, títulos)

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
