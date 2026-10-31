unit uFrmPrincipal;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Formulário Principal (Completo Fases 1-9)
  Descrição: Tela principal com menu do sistema
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus,
  ComCtrls, ExtCtrls, StdCtrls, uSessao, uPermissao;

type
  { TfrmPrincipal }
  TfrmPrincipal = class(TForm)
    MainMenu1: TMainMenu;
    mnuCadastros: TMenuItem;
    mnuCadClientes: TMenuItem;
    mnuCadFornecedores: TMenuItem;
    mnuCadProdutos: TMenuItem;
    mnuCadCategorias: TMenuItem;
    mnuSep1: TMenuItem;
    mnuCadUsuarios: TMenuItem;
    mnuEstoque: TMenuItem;
    mnuEstMovimentacao: TMenuItem;
    mnuEstInventario: TMenuItem;
    mnuEstKardex: TMenuItem;
    mnuCompras: TMenuItem;
    mnuComNotaEntrada: TMenuItem;
    mnuVendas: TMenuItem;
    mnuVenPedidos: TMenuItem;
    mnuVenOrcamentos: TMenuItem;
    mnuSep3: TMenuItem;
    mnuVenListaPedidos: TMenuItem;
    mnuVenNotaSaida: TMenuItem;
    mnuProducao: TMenuItem;
    mnuProMapaProducao: TMenuItem;
    mnuProBipagem: TMenuItem;
    mnuSep4: TMenuItem;
    mnuProFichaTecnica: TMenuItem;
    mnuProConsumo: TMenuItem;
    mnuPDV: TMenuItem;
    mnuPDVAbrirPDV: TMenuItem;
    mnuFinanceiro: TMenuItem;
    mnuFinContasReceber: TMenuItem;
    mnuFinContasPagar: TMenuItem;
    mnuFinCaixa: TMenuItem;
    mnuFiscal: TMenuItem;
    mnuFisNFe: TMenuItem;
    mnuRelatorios: TMenuItem;
    mnuRelCentral: TMenuItem;
    mnuIA: TMenuItem;
    mnuIACopiloto: TMenuItem;
    mnuSistema: TMenuItem;
    mnuSisConfiguracoes: TMenuItem;
    mnuSisPermissoes: TMenuItem;
    mnuSep2: TMenuItem;
    mnuSisSair: TMenuItem;
    StatusBar1: TStatusBar;
    pnlTopo: TPanel;
    lblBemVindo: TLabel;
    lblEmpresa: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure mnuCadClientesClick(Sender: TObject);
    procedure mnuCadFornecedoresClick(Sender: TObject);
    procedure mnuCadProdutosClick(Sender: TObject);
    procedure mnuCadCategoriasClick(Sender: TObject);
    procedure mnuCadUsuariosClick(Sender: TObject);
    procedure mnuEstMovimentacaoClick(Sender: TObject);
    procedure mnuEstInventarioClick(Sender: TObject);
    procedure mnuEstKardexClick(Sender: TObject);
    procedure mnuComNotaEntradaClick(Sender: TObject);
    procedure mnuVenPedidosClick(Sender: TObject);
    procedure mnuVenOrcamentosClick(Sender: TObject);
    procedure mnuVenListaPedidosClick(Sender: TObject);
procedure mnuVenNotaSaidaClick(Sender: TObject);
    procedure mnuProMapaProducaoClick(Sender: TObject);
    procedure mnuProBipagemClick(Sender: TObject);
    procedure mnuProConsumoClick(Sender: TObject);
    procedure mnuProFichaTecnicaClick(Sender: TObject);
    procedure mnuPDVAbrirPDVClick(Sender: TObject);
    procedure mnuFinContasReceberClick(Sender: TObject);
    procedure mnuFinContasPagarClick(Sender: TObject);
    procedure mnuFinCaixaClick(Sender: TObject);
    procedure mnuFisNFeClick(Sender: TObject);
    procedure mnuIACopilotoClick(Sender: TObject);
    procedure mnuRelCentralClick(Sender: TObject);
    procedure mnuSisConfiguracoesClick(Sender: TObject);
    procedure mnuSisPermissoesClick(Sender: TObject);
    procedure mnuSisSairClick(Sender: TObject);
  private
    procedure AtualizarStatusBar;
    procedure AbrirFormulario(AFormClass: TFormClass);
  public
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

uses
  uFrmClientes, uFrmFornecedores, uFrmProdutos, uFrmCategorias, uFrmUsuarios,
  uFrmMovEstoque, uFrmKardex, uFrmInventario,
  uFrmNotaEntrada, uFrmNotaSaida, uFrmMapaProducao, uFrmBipagem,
  uFrmFichaTecnica, uFrmConsumoMaterial,
  uFrmPedidoVenda, uFrmListaPedidos, uFrmOrcamento,
  uFrmPDV, uFrmContasReceber, uFrmContasPagar,
  uFrmNFe, uFrmCopiloto,
  uFrmCaixa, uFrmConfiguracoes, uFrmPermissoes, uFrmCentralRelatorios;

{$R *.lfm}

{ TfrmPrincipal }

procedure TfrmPrincipal.FormCreate(Sender: TObject);
begin
  Position := poScreenCenter;
  WindowState := wsMaximized;
  Caption := 'ERP 2026 - Sistema de Gestão Empresarial';
end;

procedure TfrmPrincipal.FormShow(Sender: TObject);
var
  LSessao: TSessao;
begin
  LSessao := TSessao.GetInstance;
  lblBemVindo.Caption := 'Bem-vindo, ' + LSessao.UsuarioNome;
  AtualizarStatusBar;
end;

procedure TfrmPrincipal.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if MessageDlg('Deseja realmente sair do sistema?', mtConfirmation,
    [mbYes, mbNo], 0) = mrNo then
    CloseAction := caNone
  else
  begin
    TSessao.GetInstance.Deslogar;
    CloseAction := caFree;
  end;
end;

procedure TfrmPrincipal.AtualizarStatusBar;
var
  LSessao: TSessao;
begin
  LSessao := TSessao.GetInstance;
  StatusBar1.Panels[0].Text := 'Usuário: ' + LSessao.UsuarioNome;
  StatusBar1.Panels[1].Text := 'Data: ' + DateToStr(Now);
  StatusBar1.Panels[2].Text := 'Hora: ' + TimeToStr(Now);
end;

procedure TfrmPrincipal.AbrirFormulario(AFormClass: TFormClass);
var
  LForm: TForm;
begin
  LForm := AFormClass.Create(Application);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

// === CADASTROS ===
procedure TfrmPrincipal.mnuCadClientesClick(Sender: TObject);
begin
  AbrirFormulario(TfrmClientes);
end;

procedure TfrmPrincipal.mnuCadFornecedoresClick(Sender: TObject);
begin
  AbrirFormulario(TfrmFornecedores);
end;

procedure TfrmPrincipal.mnuCadProdutosClick(Sender: TObject);
begin
  AbrirFormulario(TfrmProdutos);
end;

procedure TfrmPrincipal.mnuCadCategoriasClick(Sender: TObject);
begin
  AbrirFormulario(TfrmCategorias);
end;

procedure TfrmPrincipal.mnuCadUsuariosClick(Sender: TObject);
begin
  AbrirFormulario(TfrmUsuarios);
end;

// === ESTOQUE ===
procedure TfrmPrincipal.mnuEstMovimentacaoClick(Sender: TObject);
begin
  AbrirFormulario(TfrmMovEstoque);
end;

procedure TfrmPrincipal.mnuEstInventarioClick(Sender: TObject);
begin
  AbrirFormulario(TfrmInventario);
end;

procedure TfrmPrincipal.mnuEstKardexClick(Sender: TObject);
begin
  AbrirFormulario(TfrmKardex);
end;

// === COMPRAS ===
procedure TfrmPrincipal.mnuComNotaEntradaClick(Sender: TObject);
begin
  AbrirFormulario(TfrmNotaEntrada);
end;

// === VENDAS ===
procedure TfrmPrincipal.mnuVenPedidosClick(Sender: TObject);
begin
  AbrirFormulario(TfrmPedidoVenda);
end;

procedure TfrmPrincipal.mnuVenOrcamentosClick(Sender: TObject);
begin
  AbrirFormulario(TfrmOrcamento);
end;

procedure TfrmPrincipal.mnuVenListaPedidosClick(Sender: TObject);
begin
  AbrirFormulario(TfrmListaPedidos);
end;

procedure TfrmPrincipal.mnuVenNotaSaidaClick(Sender: TObject);
begin
  AbrirFormulario(TfrmNotaSaida);
end;

// === Produção ===
procedure TfrmPrincipal.mnuProMapaProducaoClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_PRODUCAO, TELA_MAPA_PRODUCAO, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar o Módulo de Produção.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  AbrirFormulario(TfrmMapaProducao);
end;

procedure TfrmPrincipal.mnuProBipagemClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_PRODUCAO, TELA_BIPAGEM, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar a Bipagem de Talões.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  AbrirFormulario(TfrmBipagem);
end;

procedure TfrmPrincipal.mnuProFichaTecnicaClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_PRODUCAO, TELA_FICHA_TECNICA, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar a Ficha Técnica.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  AbrirFormulario(TfrmFichaTecnica);
end;

procedure TfrmPrincipal.mnuProConsumoClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_PRODUCAO, TELA_CONSUMO, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar o Consumo de Materiais.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  AbrirFormulario(TfrmConsumoMaterial);
end;

// === PDV ===
procedure TfrmPrincipal.mnuPDVAbrirPDVClick(Sender: TObject);
begin
  AbrirFormulario(TfrmPDV);
end;

// === FINANCEIRO ===
procedure TfrmPrincipal.mnuFinContasReceberClick(Sender: TObject);
begin
  AbrirFormulario(TfrmContasReceber);
end;

procedure TfrmPrincipal.mnuFinContasPagarClick(Sender: TObject);
begin
  AbrirFormulario(TfrmContasPagar);
end;

procedure TfrmPrincipal.mnuFinCaixaClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_FINANCEIRO, TELA_CAIXA, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar o Caixa.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  AbrirFormulario(TfrmCaixa);
end;

// === FISCAL ===
procedure TfrmPrincipal.mnuFisNFeClick(Sender: TObject);
begin
  AbrirFormulario(TfrmNFe);
end;

// === IA COPILOTO ===
procedure TfrmPrincipal.mnuIACopilotoClick(Sender: TObject);
begin
  AbrirFormulario(TfrmCopiloto);
end;

// === RELATORIOS ===
procedure TfrmPrincipal.mnuRelCentralClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_RELATORIOS, TELA_CENTRAL_RELATORIOS,
    PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para abrir a Central de Relatórios.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  AbrirFormulario(TfrmCentralRelatorios);
end;

// === SISTEMA ===
procedure TfrmPrincipal.mnuSisConfiguracoesClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_SISTEMA, TELA_CONFIGURACOES, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar as Configurações.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  AbrirFormulario(TfrmConfiguracoes);
end;

procedure TfrmPrincipal.mnuSisPermissoesClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_SISTEMA, TELA_PERMISSOES, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar as Permissões.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  AbrirFormulario(TfrmPermissoes);
end;

procedure TfrmPrincipal.mnuSisSairClick(Sender: TObject);
begin
  Close;
end;

end.
