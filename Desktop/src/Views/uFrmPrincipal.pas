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
    mnuSuprimentos: TMenuItem;
    mnuSupMateriais: TMenuItem;
    mnuSupCompras: TMenuItem;
    mnuCadastros: TMenuItem;
    mnuCadPessoas: TMenuItem;
    mnuCadProdutos: TMenuItem;
    mnuCadCategorias: TMenuItem;
    mnuCadGrades: TMenuItem;
    mnuCadPaises: TMenuItem;
    mnuCadEstados: TMenuItem;
    mnuCadCidades: TMenuItem;
    mnuSep1: TMenuItem;
    mnuCadUsuarios: TMenuItem;
    mnuEstoque: TMenuItem;
    mnuEstMovimentacao: TMenuItem;
    mnuEstInventario: TMenuItem;
    mnuEstKardex: TMenuItem;
    mnuComNotaEntrada: TMenuItem;
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
    mnuFinProdutoFiscal: TMenuItem;
    mnuFinMovimentacao: TMenuItem;
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
    procedure VerificarApiEmBackground;
    procedure ProcessarResultadoApi(AOk: Boolean; const AUrl: string);
    procedure AvisarApiOffline(const AUrl: string);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure mnuCadPessoasClick(Sender: TObject);
    procedure mnuCadProdutosClick(Sender: TObject);
    procedure mnuCadCategoriasClick(Sender: TObject);
    procedure mnuCadGradesClick(Sender: TObject);
    procedure mnuCadPaisesClick(Sender: TObject);
    procedure mnuCadEstadosClick(Sender: TObject);
    procedure mnuCadCidadesClick(Sender: TObject);
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
    procedure mnuFinProdutoFiscalClick(Sender: TObject);
    procedure mnuFinMovimentacaoClick(Sender: TObject);
    procedure mnuSupMateriaisClick(Sender: TObject);
    procedure mnuSupComprasClick(Sender: TObject);
    procedure mnuFisNFeClick(Sender: TObject);
    procedure mnuIACopilotoClick(Sender: TObject);
    procedure mnuRelCentralClick(Sender: TObject);
    procedure mnuSisConfiguracoesClick(Sender: TObject);
    procedure mnuSisPermissoesClick(Sender: TObject);
    procedure mnuSisSairClick(Sender: TObject);
  private
    procedure AtualizarStatusBar;
    procedure AbrirFormulario(AFormClass: TFormClass);
    { Habilita no menu apenas as telas que o usuário pode visualizar. }
    procedure AplicarPermissoesNoMenu;
  public
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

uses
  uFrmPessoas, uFrmProdutos, uFrmCategorias, uFrmUsuarios,
  uFrmMovEstoque, uFrmKardex, uFrmInventario,
  uFrmNotaEntrada, uFrmNotaSaida, uFrmMapaProducao, uFrmBipagem,
  uFrmFichaTecnica, uFrmConsumoMaterial,
  uFrmPedidoVenda, uFrmListaPedidos, uFrmOrcamento,
  uFrmPDV, uFrmContasReceber, uFrmContasPagar,
  uFrmNFe, uFrmCopiloto,
  uFrmProdutoFiscal, uFrmMaterial,
  uFrmMovimentoFinanceiro, uFrmCompras,
  uFrmPais, uFrmEstado, uFrmCidade, uFrmGrade,
  uFrmCaixa, uFrmConfiguracoes, uFrmPermissoes, uFrmCentralRelatorios,
  uApiSaude;

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
  AplicarPermissoesNoMenu;
  AtualizarStatusBar;
  VerificarApiEmBackground;
end;

{ Confere se a API REST esta no ar sem travar a abertura da tela.
  Se estiver fora: em localhost oferece subir a API local; em URL
  remota (servidor) apenas avisa — nao da para ligar remotamente. }
procedure TfrmPrincipal.VerificarApiEmBackground;
var
  LUrl: string;
begin
  LUrl := ApiUrlPadrao;
  TApiCheckThread.Create(LUrl, @ProcessarResultadoApi).Start;
end;

{ Callback na thread da UI (Synchronize dentro de TApiCheckThread). }
procedure TfrmPrincipal.ProcessarResultadoApi(AOk: Boolean;
  const AUrl: string);
begin
  if not AOk then
    AvisarApiOffline(AUrl);
end;

procedure TfrmPrincipal.AvisarApiOffline(const AUrl: string);
var
  LResp: TModalResult;
begin
  if ApiEhLocal(AUrl) then
  begin
    LResp := MessageDlg(
      'A API REST não está respondendo em ' + AUrl + '.' + sLineBreak +
      'Os apps móveis (PDV/Bipe) ficarão indisponíveis.' + sLineBreak +
      'Deseja iniciar a API local agora?',
      mtConfirmation, [mbYes, mbNo], 0);
    if LResp = mrYes then
      if IniciarApiLocal then
        MessageDlg('API iniciada com sucesso.', mtInformation,
          [mbOK], 0)
      else
        MessageDlg('Não foi possível iniciar a API automaticamente.' +
          sLineBreak + 'Abra Scripts\run_api.bat manualmente.',
          mtWarning, [mbOK], 0);
  end
  else
    MessageDlg(
      'Não foi possível contatar a API em ' + AUrl + '.' + sLineBreak +
      'Verifique a rede ou se o servidor está ligado.' + sLineBreak +
      'Os apps móveis (PDV/Bipe) ficarão indisponíveis.',
      mtWarning, [mbOK], 0);
end;

{ Cada item do menu aponta para uma tela do catálogo de permissões.
  Sem permissão de visualizar, o item fica desabilitado — o usuário não
  precisa descobrir a recusa só depois de clicar. }
procedure TfrmPrincipal.AplicarPermissoesNoMenu;
var
  LPar: array[0..32] of TMenuItem;
  LClasses: array[0..32] of TFormClass;
  I: Integer;
  LModulo, LTela: string;

  procedure Marcar(AItem: TMenuItem; AClass: TFormClass);
  begin
    AItem.Enabled := False;
    if PermissaoDaTela(AClass.ClassName, LModulo, LTela) then
      AItem.Enabled := TemPermissao(LModulo, LTela, PERM_VISUALIZAR);
  end;

begin
  LPar[0] := mnuSupMateriais;       LClasses[0] := TfrmMaterial;
  LPar[1] := mnuSupCompras;         LClasses[1] := TfrmCompras;
  LPar[2] := mnuProConsumo;         LClasses[2] := TfrmConsumoMaterial;
  LPar[3] := mnuCadProdutos;        LClasses[3] := TfrmProdutos;
  LPar[4] := mnuVenPedidos;         LClasses[4] := TfrmPedidoVenda;
  LPar[5] := mnuVenOrcamentos;      LClasses[5] := TfrmOrcamento;
  LPar[6] := mnuVenListaPedidos;    LClasses[6] := TfrmListaPedidos;
  LPar[7] := mnuProMapaProducao;    LClasses[7] := TfrmMapaProducao;
  LPar[8] := mnuProBipagem;         LClasses[8] := TfrmBipagem;
  LPar[9] := mnuProFichaTecnica;    LClasses[9] := TfrmFichaTecnica;
  LPar[10] := mnuFinContasReceber;  LClasses[10] := TfrmContasReceber;
  LPar[11] := mnuFinContasPagar;    LClasses[11] := TfrmContasPagar;
  LPar[12] := mnuFinCaixa;          LClasses[12] := TfrmCaixa;
  LPar[13] := mnuFinProdutoFiscal;  LClasses[13] := TfrmProdutoFiscal;
  LPar[14] := mnuFinMovimentacao;   LClasses[14] := TfrmMovimentoFinanceiro;
  LPar[15] := mnuVenNotaSaida;      LClasses[15] := TfrmNotaSaida;
  LPar[16] := mnuComNotaEntrada;    LClasses[16] := TfrmNotaEntrada;
  LPar[17] := mnuFisNFe;            LClasses[17] := TfrmNFe;
  LPar[18] := mnuCadPessoas;        LClasses[18] := TfrmPessoas;
  LPar[19] := mnuCadCategorias;     LClasses[19] := TfrmCategorias;
  LPar[20] := mnuCadGrades;         LClasses[20] := TfrmGrade;
  LPar[21] := mnuCadPaises;         LClasses[21] := TfrmPais;
  LPar[22] := mnuCadEstados;        LClasses[22] := TfrmEstado;
  LPar[23] := mnuCadCidades;        LClasses[23] := TfrmCidade;
  LPar[24] := mnuCadUsuarios;       LClasses[24] := TfrmUsuarios;
  LPar[25] := mnuEstMovimentacao;   LClasses[25] := TfrmMovEstoque;
  LPar[26] := mnuEstInventario;     LClasses[26] := TfrmInventario;
  LPar[27] := mnuEstKardex;         LClasses[27] := TfrmKardex;
  LPar[28] := mnuPDVAbrirPDV;       LClasses[28] := TfrmPDV;
  LPar[29] := mnuRelCentral;        LClasses[29] := TfrmCentralRelatorios;
  LPar[30] := mnuIACopiloto;        LClasses[30] := TfrmCopiloto;
  LPar[31] := mnuSisConfiguracoes;  LClasses[31] := TfrmConfiguracoes;
  LPar[32] := mnuSisPermissoes;     LClasses[32] := TfrmPermissoes;

  for I := Low(LPar) to High(LPar) do
    Marcar(LPar[I], LClasses[I]);
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
  LModulo, LTela: string;
begin
  { Guarda de acesso (T1): toda tela do menu tem uma linha no catálogo
    de permissões. Sem permissão de visualizar, a tela não abre. Tela
    fora do catálogo é bloqueada (falha fechada): assim uma tela nova
    nunca abre sem permissão configurada. }
  if not PermissaoDaTela(AFormClass.ClassName, LModulo, LTela) then
  begin
    MessageDlg('Esta tela não tem permissão cadastrada.' + #13#10 +
      'Fale com o administrador do sistema.',
      mtError, [mbOK], 0);
    Exit;
  end;

  if not TemPermissao(LModulo, LTela, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar esta tela.' +
      #13#10 + '(' + LModulo + '/' + LTela + ')',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  LForm := AFormClass.Create(Application);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

// === CADASTROS ===
procedure TfrmPrincipal.mnuCadPessoasClick(Sender: TObject);
begin
  AbrirFormulario(TfrmPessoas);
end;

procedure TfrmPrincipal.mnuCadProdutosClick(Sender: TObject);
begin
  AbrirFormulario(TfrmProdutos);
end;

procedure TfrmPrincipal.mnuCadCategoriasClick(Sender: TObject);
begin
  AbrirFormulario(TfrmCategorias);
end;

procedure TfrmPrincipal.mnuCadGradesClick(Sender: TObject);
begin
  AbrirFormulario(TfrmGrade);
end;

procedure TfrmPrincipal.mnuCadPaisesClick(Sender: TObject);
begin
  AbrirFormulario(TfrmPais);
end;

procedure TfrmPrincipal.mnuCadEstadosClick(Sender: TObject);
begin
  AbrirFormulario(TfrmEstado);
end;

procedure TfrmPrincipal.mnuCadCidadesClick(Sender: TObject);
begin
  AbrirFormulario(TfrmCidade);
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

procedure TfrmPrincipal.mnuFinProdutoFiscalClick(Sender: TObject);
begin
  AbrirFormulario(TfrmProdutoFiscal);
end;

procedure TfrmPrincipal.mnuFinMovimentacaoClick(Sender: TObject);
begin
  AbrirFormulario(TfrmMovimentoFinanceiro);
end;

procedure TfrmPrincipal.mnuSupMateriaisClick(Sender: TObject);
begin
  AbrirFormulario(TfrmMaterial);
end;

procedure TfrmPrincipal.mnuSupComprasClick(Sender: TObject);
begin
  AbrirFormulario(TfrmCompras);
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
