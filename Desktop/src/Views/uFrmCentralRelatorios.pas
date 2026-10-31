unit uFrmCentralRelatorios;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Relatórios > Central de Relatórios
  Descrição: lista os relatórios do sistema com o arquivo .lrf de
  cada modelo (I/II), mostra qual modelo está ativo e se o arquivo
  existe - e leva para a tela do Mapa de Produção, onde os
  relatórios são de fato executados.

  Suposição: a execução dos relatórios continua na tela do Mapa
  (ela é que tem os datasets do mapa/talões selecionados); esta
  central não duplica lógica de impressão - só diagnóstico e atalho.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, Grids,
  uConexao, uPermissao, uProducaoService, uFrmMapaProducao;

type
  { TfrmCentralRelatorios }
  TfrmCentralRelatorios = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    lblModelos: TLabel;
    gridRelatorios: TStringGrid;
    pnlBotoes: TPanel;
    btnAbrirMapa: TBitBtn;
    btnAtualizar: TBitBtn;
    btnFechar: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnAbrirMapaClick(Sender: TObject);
    procedure btnAtualizarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    FConexao: TConexao;
    FService: TProducaoService;
    procedure ConfigurarGrade;
    function  VersaoModelo(AModelo: Integer): string;
    function  SituacaoArquivo(const ACaminho: string; AAtivo: Boolean): string;
    procedure PreencherLista;
  end;

var
  frmCentralRelatorios: TfrmCentralRelatorios;

implementation

{$R *.lfm}

{ TfrmCentralRelatorios }

procedure TfrmCentralRelatorios.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TProducaoService.Create;

    lblTitulo.Caption := 'Central de Relatórios';
    Caption := 'Central de Relatórios';
    ConfigurarGrade;

    Position := poScreenCenter;
    BorderStyle := bsSizeable;

    PreencherLista;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmCentralRelatorios.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FService);
end;

procedure TfrmCentralRelatorios.ConfigurarGrade;
begin
  gridRelatorios.FixedCols := 0;
  gridRelatorios.FixedRows := 1;
  gridRelatorios.RowCount := 5;
  gridRelatorios.ColCount := 4;
  gridRelatorios.Options := [goFixedVertLine, goFixedHorzLine, goVertLine,
    goHorzLine, goRangeSelect, goThumbTracking];
  gridRelatorios.ColWidths[0] := 200;
  gridRelatorios.ColWidths[1] := 90;
  gridRelatorios.ColWidths[2] := 470;
  gridRelatorios.ColWidths[3] := 130;

  gridRelatorios.Cells[0, 0] := 'Relatório';
  gridRelatorios.Cells[1, 0] := 'Versão';
  gridRelatorios.Cells[2, 0] := 'Arquivo .lrf';
  gridRelatorios.Cells[3, 0] := 'Situação';
end;

function TfrmCentralRelatorios.VersaoModelo(AModelo: Integer): string;
begin
  if AModelo = 2 then
    Result := 'Modelo II'
  else
    Result := 'Modelo I';
end;

function TfrmCentralRelatorios.SituacaoArquivo(const ACaminho: string;
  AAtivo: Boolean): string;
begin
  if FileExists(ACaminho) then
  begin
    if AAtivo then
      Result := 'OK (ativo)'
    else
      Result := 'OK';
  end
  else
    Result := 'AUSENTE';
end;

procedure TfrmCentralRelatorios.PreencherLista;
var
  LTalaoAtivo, LMapaAtivo: Integer;
  LCaminho: string;

  procedure Linha(ARow: Integer; const ANome: string; AModelo: Integer;
    const ACaminho: string; AAtivo: Boolean);
  begin
    gridRelatorios.Cells[0, ARow] := ANome;
    gridRelatorios.Cells[1, ARow] := VersaoModelo(AModelo);
    gridRelatorios.Cells[2, ARow] := ACaminho;
    gridRelatorios.Cells[3, ARow] := SituacaoArquivo(ACaminho, AAtivo);
  end;

begin
  LTalaoAtivo := FService.ModeloAtivo(CFG_TALAO_MODELO);
  LMapaAtivo := FService.ModeloAtivo(CFG_MAPA_MODELO);

  Linha(1, 'Talão de produção', LTalaoAtivo,
    FService.CaminhoRelatorioTalaoModelo(LTalaoAtivo), True);

  { os dois arquivos do talão, para conferir a troca de modelo }
  if LTalaoAtivo = 2 then
    LCaminho := FService.CaminhoRelatorioTalaoModelo(1)
  else
    LCaminho := FService.CaminhoRelatorioTalaoModelo(2);
  Linha(2, 'Talão de produção', 3 - LTalaoAtivo, LCaminho, False);

  Linha(3, 'Mapa de Produção', LMapaAtivo,
    FService.CaminhoRelatorioMapaModelo(LMapaAtivo), True);

  if LMapaAtivo = 2 then
    LCaminho := FService.CaminhoRelatorioMapaModelo(1)
  else
    LCaminho := FService.CaminhoRelatorioMapaModelo(2);
  Linha(4, 'Mapa de Produção', 3 - LMapaAtivo, LCaminho, False);

  lblModelos.Caption :=
    'Modelo ativo: talão = ' + VersaoModelo(LTalaoAtivo) +
    '   |   mapa = ' + VersaoModelo(LMapaAtivo) +
    '   (trocar na tela do Mapa: Relatório ▼ → Modelo I/II)';
end;

procedure TfrmCentralRelatorios.btnAbrirMapaClick(Sender: TObject);
var
  LForm: TfrmMapaProducao;
begin
  if not TemPermissao(MODULO_PRODUCAO, TELA_MAPA_PRODUCAO, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar o Módulo de Produção.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  LForm := TfrmMapaProducao.Create(Application);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;

  { voltou da tela do Mapa: o modelo pode ter sido trocado lá }
  try
    PreencherLista;
  except
    on E: Exception do
      MessageDlg('Erro ao atualizar a lista: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmCentralRelatorios.btnAtualizarClick(Sender: TObject);
begin
  try
    PreencherLista;
  except
    on E: Exception do
      MessageDlg('Erro ao atualizar a lista: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmCentralRelatorios.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
