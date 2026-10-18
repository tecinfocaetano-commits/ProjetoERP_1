unit uFrmBipagem;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 3 - Produção - Bipagem de Talões (Fase 4)

  Tela do operador de produção:
    - o código de barras do talão é lido pelo leitor (modo teclado,
      termina com Enter) ou digitado manualmente;
    - cada bipagem move o talão:
        GERADO/IMPRESSO -> EM_PRODUCAO  (etapa INICIO)
        EM_PRODUCAO     -> CONCLUIDO    (etapa CONCLUSAO)
    - o resultado aparece em destaque (cor por situação) e as
      últimas bipagens ficam registradas na grade inferior.

  A tela não decide nada: toda regra de negócio está no
  TProducaoService.BiparTalao. Bipagens inválidas e duplicadas
  também são auditadas pelo service.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, Grids, DBGrids, DB, SQLDB,
  uConexao, uSessao, uProducaoService, uPermissao;

type
  { TfrmBipagem }
  TfrmBipagem = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlEntrada: TPanel;
    lblCodigo: TLabel;
    edtCodigo: TEdit;
    chkManual: TCheckBox;
    btnBipar: TButton;
    pnlFeedback: TPanel;
    lblFeedback: TLabel;
    pnlDetalhes: TPanel;
    lblDetTalaoTit: TLabel;
    lblDetTalao: TLabel;
    lblDetMapaTit: TLabel;
    lblDetMapa: TLabel;
    lblDetStatusTit: TLabel;
    lblDetStatus: TLabel;
    lblDetProdutoTit: TLabel;
    lblDetProduto: TLabel;
    lblDetQtdTit: TLabel;
    lblDetQtd: TLabel;
    pnlHistorico: TPanel;
    lblHistoricoTitulo: TLabel;
    dbGridBipagens: TDBGrid;
    pnlRodape: TPanel;
    lblPermissao: TLabel;
    btnFechar: TButton;
    DataSourceBipagens: TDataSource;
    procedure btnBiparClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure dbGridBipagensDblClick(Sender: TObject);
    procedure edtCodigoKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FConexao: TConexao;
    FBipagens: TSQLQuery;
    FService: TProducaoService;
    FPodeBipar: Boolean;
    procedure CarregarHistorico;
    procedure ExibirResultado(const ABipagem: TBipagemTalao);
    procedure LimparResultado;
  end;

var
  frmBipagem: TfrmBipagem;

implementation

{$R *.lfm}

procedure TfrmBipagem.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;

  FBipagens := TSQLQuery.Create(Self);
  FBipagens.DataBase := FConexao.Connection;
  FBipagens.Transaction := FConexao.Transaction;
  DataSourceBipagens.DataSet := FBipagens;

  FService := TProducaoService.Create;
  FPodeBipar := False;
end;

procedure TfrmBipagem.FormShow(Sender: TObject);
begin
  // permissão de acesso à tela
  if not TemPermissao(MODULO_PRODUCAO, TELA_BIPAGEM, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar a Bipagem de Talões.',
      mtError, [mbOK], 0);
    Close;
    Exit;
  end;

  FPodeBipar := TemPermissao(MODULO_PRODUCAO, TELA_BIPAGEM, PERM_INSERIR);
  btnBipar.Enabled := FPodeBipar;
  edtCodigo.Enabled := FPodeBipar;
  if FPodeBipar then
    lblPermissao.Caption := ''
  else
    lblPermissao.Caption :=
      'Somente consulta: seu usuário não pode registrar bipagens.';

  LimparResultado;
  CarregarHistorico;

  if FPodeBipar then
    edtCodigo.SetFocus;
end;

procedure TfrmBipagem.CarregarHistorico;
var
  LField: TField;
begin
  if FBipagens.Active then
    FBipagens.Close;

  FBipagens.SQL.Text :=
    'SELECT B.DATA_HORA, ' +
    '  CASE WHEN B.TALAO_ID = 0 THEN NULL ELSE T.NUMERO END AS TALAO, ' +
    '  PR.DESCRICAO AS PRODUTO, ' +
    '  M.NUMERO AS MAPA, ' +
    '  B.ETAPA, B.ORIGEM, B.RESULTADO, ' +
    '  U.LOGIN AS USUARIO, ' +
    '  B.OBSERVACAO ' +
    'FROM TALAO_BIPAGEM B ' +
    '  LEFT JOIN TALAO T ON T.ID = B.TALAO_ID ' +
    '  LEFT JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
    '  LEFT JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
    '  LEFT JOIN PRODUTO PR ON PR.ID = MI.PRODUTO_ID ' +
    '  LEFT JOIN USUARIO U ON U.ID = B.USUARIO_ID ' +
    'ORDER BY B.ID DESC ' +
    'ROWS 50';
  FBipagens.Open;

  LField := FBipagens.FieldByName('DATA_HORA');
  if LField is TDateTimeField then
    TDateTimeField(LField).DisplayFormat := 'dd/mm/yy hh:nn:ss';
end;

procedure TfrmBipagem.LimparResultado;
begin
  pnlFeedback.Color := clNavy;
  lblFeedback.Font.Color := clWhite;
  lblFeedback.Caption := 'Aguardando a leitura do código de barras...';
  lblDetTalao.Caption := '-';
  lblDetMapa.Caption := '-';
  lblDetStatus.Caption := '-';
  lblDetProduto.Caption := '-';
  lblDetQtd.Caption := '-';
end;

procedure TfrmBipagem.ExibirResultado(const ABipagem: TBipagemTalao);
begin
  { cor de fundo comunica o resultado à distância: o operador de
    chão de fábrica lê a tela de longe }
  if (ABipagem.Resultado = 'OK') and (ABipagem.Etapa = 'CONCLUSAO') then
    pnlFeedback.Color := clGreen
  else if ABipagem.Resultado = 'OK' then
    pnlFeedback.Color := clNavy
  else if ABipagem.Resultado = 'DUPLICADO' then
    pnlFeedback.Color := clOlive
  else
    pnlFeedback.Color := clRed;

  if ABipagem.Resultado = 'OK' then
    lblFeedback.Caption := ABipagem.Mensagem
  else if ABipagem.Resultado = 'DUPLICADO' then
    lblFeedback.Caption := 'BIPAGEM IGNORADA - ' + ABipagem.Mensagem
  else
    lblFeedback.Caption := 'BIPAGEM INVÁLIDA - ' + ABipagem.Mensagem;

  lblFeedback.Font.Color := clWhite;

  if ABipagem.TalaoId > 0 then
  begin
    lblDetTalao.Caption := Format('T%d (%d peças)',
      [ABipagem.NumeroTalao, Round(ABipagem.Quantidade)]);
    lblDetMapa.Caption := Format('nº %d', [ABipagem.MapaNumero]);
    lblDetProduto.Caption := ABipagem.Produto;
    if ABipagem.StatusAnterior <> ABipagem.StatusNovo then
      lblDetStatus.Caption := ABipagem.StatusAnterior + '  →  ' +
        ABipagem.StatusNovo
    else
      lblDetStatus.Caption := ABipagem.StatusAnterior;
    lblDetQtd.Caption := FormatFloat('0.####', ABipagem.Quantidade);
  end
  else
  begin
    lblDetTalao.Caption := '-';
    lblDetMapa.Caption := '-';
    lblDetProduto.Caption := '-';
    lblDetStatus.Caption := '-';
    lblDetQtd.Caption := '-';
  end;
end;

procedure TfrmBipagem.btnBiparClick(Sender: TObject);
var
  LBipagem: TBipagemTalao;
  LOrigem: string;
begin
  if Trim(edtCodigo.Text) = '' then
  begin
    lblFeedback.Caption := 'Informe ou leia o código de barras do talão.';
    lblFeedback.Font.Color := clYellow;
    edtCodigo.SetFocus;
    Exit;
  end;

  if chkManual.Checked then
    LOrigem := 'MANUAL'
  else
    LOrigem := 'LEITOR';

  Screen.Cursor := crHourGlass;
  try
    try
      LBipagem := FService.BiparTalao(edtCodigo.Text, LOrigem);
      ExibirResultado(LBipagem);
    except
      on E: Exception do
      begin
        pnlFeedback.Color := clRed;
        lblFeedback.Font.Color := clWhite;
        lblFeedback.Caption := 'ERRO - ' + E.Message;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  { recarrega o histórico sempre (a transação fecha os cursores) }
  CarregarHistorico;

  edtCodigo.Clear;
  if FPodeBipar and edtCodigo.CanFocus then
    edtCodigo.SetFocus;
end;

procedure TfrmBipagem.edtCodigoKeyPress(Sender: TObject; var Key: Char);
begin
  { o leitor de código de barras em modo teclado termina com Enter:
    a mesma tecla confirma a digitação manual }
  if Key = #13 then
  begin
    Key := #0;
    btnBiparClick(Sender);
  end;
end;

procedure TfrmBipagem.dbGridBipagensDblClick(Sender: TObject);
begin
  { duplo clique numa linha do histórico: prepara o código do talão
    para uma nova leitura (reimpressão / correção de bipagem) }
  if (not FBipagens.Active) or FBipagens.IsEmpty then
    Exit;
  if FBipagens.FieldByName('TALAO').IsNull then
    Exit;
  if not FPodeBipar then
    Exit;
  edtCodigo.Text := Format('T%.6d', [FBipagens.FieldByName('TALAO').AsInteger]);
  if edtCodigo.CanFocus then
    edtCodigo.SetFocus;
end;

procedure TfrmBipagem.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
