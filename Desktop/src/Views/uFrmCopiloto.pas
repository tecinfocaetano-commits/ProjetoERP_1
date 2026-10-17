unit uFrmCopiloto;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 9 - Formulário do Copiloto IA
  Descrição: Interface de chat com o Copiloto ERP
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, ComCtrls,
  uConexao;

type
  { TfrmCopiloto }
  TfrmCopiloto = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlChat: TPanel;
    mmoChat: TMemo;
    pnlInput: TPanel;
    edtPergunta: TEdit;
    btnEnviar: TBitBtn;
    pnlAtalhos: TPanel;
    lblAtalhos: TLabel;
    btnFaturamento: TBitBtn;
    btnInadimplentes: TBitBtn;
    btnEstoqueBaixo: TBitBtn;
    btnTopProdutos: TBitBtn;
    btnTopClientes: TBitBtn;
    btnFluxoCaixa: TBitBtn;
    btnSugestaoCompra: TBitBtn;
    btnAlertasFinanc: TBitBtn;
    btnFechar: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnEnviarClick(Sender: TObject);
    procedure edtPerguntaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnFaturamentoClick(Sender: TObject);
    procedure btnInadimplentesClick(Sender: TObject);
    procedure btnEstoqueBaixoClick(Sender: TObject);
    procedure btnTopProdutosClick(Sender: TObject);
    procedure btnTopClientesClick(Sender: TObject);
    procedure btnFluxoCaixaClick(Sender: TObject);
    procedure btnSugestaoCompraClick(Sender: TObject);
    procedure btnAlertasFinancClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    procedure EnviarPergunta(const APergunta: string);
    procedure AdicionarMensagem(const ARemetente, AMensagem: string);
  end;

var
  frmCopiloto: TfrmCopiloto;

implementation

{$R *.lfm}

procedure TfrmCopiloto.FormCreate(Sender: TObject);
begin
  mmoChat.Clear;
  AdicionarMensagem('COPILOTO',
    'Olá! Sou o Copiloto ERP. Módulo de Inteligência Artificial em desenvolvimento.' + #13#10 +
    'Em breve você poderá fazer perguntas como: "Qual meu faturamento do mês?", "Quais clientes inadimplentes?"');
end;

procedure TfrmCopiloto.FormDestroy(Sender: TObject);
begin
  // Nada a destruir
end;

procedure TfrmCopiloto.AdicionarMensagem(const ARemetente, AMensagem: string);
begin
  mmoChat.Lines.Add('');
  mmoChat.Lines.Add('[' + ARemetente + '] ' + FormatDateTime('hh:nn:ss', Now));
  mmoChat.Lines.Add(AMensagem);
  mmoChat.Lines.Add('─────────────────────────────────');
  // Scroll para o final
  mmoChat.SelStart := Length(mmoChat.Text);
end;

procedure TfrmCopiloto.EnviarPergunta(const APergunta: string);
begin
  AdicionarMensagem('VOCÊ', APergunta);
  AdicionarMensagem('COPILOTO', 'Módulo de IA em desenvolvimento. Esta funcionalidade estará disponível em breve.');
end;

procedure TfrmCopiloto.btnEnviarClick(Sender: TObject);
begin
  if Trim(edtPergunta.Text) = '' then Exit;
  EnviarPergunta(edtPergunta.Text);
  edtPergunta.Clear;
  edtPergunta.SetFocus;
end;

procedure TfrmCopiloto.edtPerguntaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 13 then btnEnviarClick(nil);
end;

procedure TfrmCopiloto.btnFaturamentoClick(Sender: TObject);
begin
  EnviarPergunta('Qual meu faturamento do mês?');
end;

procedure TfrmCopiloto.btnInadimplentesClick(Sender: TObject);
begin
  EnviarPergunta('Quais clientes estão inadimplentes?');
end;

procedure TfrmCopiloto.btnEstoqueBaixoClick(Sender: TObject);
begin
  EnviarPergunta('Quais produtos estão abaixo do estoque mínimo?');
end;

procedure TfrmCopiloto.btnTopProdutosClick(Sender: TObject);
begin
  EnviarPergunta('Quais são os produtos mais vendidos?');
end;

procedure TfrmCopiloto.btnTopClientesClick(Sender: TObject);
begin
  EnviarPergunta('Quais são os top 10 clientes?');
end;

procedure TfrmCopiloto.btnFluxoCaixaClick(Sender: TObject);
begin
  EnviarPergunta('Qual o fluxo de caixa dos próximos 30 dias?');
end;

procedure TfrmCopiloto.btnSugestaoCompraClick(Sender: TObject);
begin
  AdicionarMensagem('VOCÊ', 'Sugestão de compras');
  AdicionarMensagem('COPILOTO', 'Módulo de IA em desenvolvimento. Esta funcionalidade estará disponível em breve.');
end;

procedure TfrmCopiloto.btnAlertasFinancClick(Sender: TObject);
begin
  AdicionarMensagem('VOCÊ', 'Alertas financeiros');
  AdicionarMensagem('COPILOTO', 'Módulo de IA em desenvolvimento. Esta funcionalidade estará disponível em breve.');
end;

procedure TfrmCopiloto.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
