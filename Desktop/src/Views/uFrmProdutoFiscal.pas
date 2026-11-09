unit uFrmProdutoFiscal;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Formulário: Produto Fiscal
  Descrição: CRUD do PRODUTO_FISCAL (unificado). Cobre a
             classificação fiscal (NCM/CEST/CFOP/CST/alíquotas) E os
             itens financeiros (serviço/outro) via TIPO + VALOR — o
             antigo "Produto Financeiro" foi fundido aqui (decisão:
             "produto fiscal e financeiro é o mesmo").
             Reaproveitada por Material, Produto e itens de nota.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uSessao,
  uProdutoFiscalService, uProdutoFiscal;

type
  { TfrmProdutoFiscal }
  TfrmProdutoFiscal = class(TfrmCadastroBase)
    lblCodigo: TLabel;
    edtCodigo: TEdit;
    lblDescricao: TLabel;
    edtDescricao: TEdit;
    lblNcm: TLabel;
    edtNcm: TEdit;
    lblCest: TLabel;
    edtCest: TEdit;
    lblCfop: TLabel;
    edtCfop: TEdit;
    lblCfopVenda: TLabel;
    edtCfopVenda: TEdit;
    lblCfopCompra: TLabel;
    edtCfopCompra: TEdit;
    lblCstIcms: TLabel;
    edtCstIcms: TEdit;
    lblCstPis: TLabel;
    edtCstPis: TEdit;
    lblCstCofins: TLabel;
    edtCstCofins: TEdit;
    lblAliqIcms: TLabel;
    edtAliqIcms: TEdit;
    lblAliqPis: TLabel;
    edtAliqPis: TEdit;
    lblAliqCofins: TLabel;
    edtAliqCofins: TEdit;
    lblPesoLiquido: TLabel;
    edtPesoLiquido: TEdit;
    lblPesoBruto: TLabel;
    edtPesoBruto: TEdit;
    lblStatus: TLabel;
    cmbStatus: TComboBox;
    lblTipo: TLabel;
    cmbTipo: TComboBox;
    lblValor: TLabel;
    edtValor: TEdit;
    lblObservacoes: TLabel;
    mmoObservacoes: TMemo;
    procedure FormCreate(Sender: TObject);
  public
    destructor Destroy; override;
  protected
    procedure HabilitarCampos(AHabilitar: Boolean); override;
    procedure LimparCampos; override;
    procedure PreencherCampos; override;
    procedure PreencherObjeto; override;
    function Validar: Boolean; override;
    procedure CarregarDados(const AFiltro: string = ''); override;
    function Salvar: Boolean; override;
    function Excluir: Boolean; override;
  private
    FQuery: TSQLQuery;
    FService: TProdutoFiscalService;
    procedure ConfigurarGrid;
    function TipoSelecionado: string;      // '', 'S' ou 'O'
    procedure SelecionarTipo(const ATipo: string);
  end;

var
  frmProdutoFiscal: TfrmProdutoFiscal;

implementation

{$R *.lfm}

{ TfrmProdutoFiscal }

destructor TfrmProdutoFiscal.Destroy;
begin
  FreeAndNil(FService);
  inherited Destroy;
end;

procedure TfrmProdutoFiscal.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;
    FService := TProdutoFiscalService.Create;

    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Cadastro de Produto Fiscal';
    Caption := 'Produto Fiscal';
    ConfigurarGrid;

    cmbStatus.Items.Clear;
    cmbStatus.Items.Add('Ativo');
    cmbStatus.Items.Add('Inativo');
    cmbStatus.ItemIndex := 0;

    cmbTipo.Items.Clear;
    cmbTipo.Items.Add('Classificação');
    cmbTipo.Items.Add('Serviço');
    cmbTipo.Items.Add('Outros');
    cmbTipo.ItemIndex := 0;

    FEstado := efNavegando;
    Position := poScreenCenter;
    BorderStyle := bsSizeable;
    CarregarDados;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

function TfrmProdutoFiscal.TipoSelecionado: string;
begin
  case cmbTipo.ItemIndex of
    1: Result := 'S';
    2: Result := 'O';
  else
    Result := '';
  end;
end;

procedure TfrmProdutoFiscal.SelecionarTipo(const ATipo: string);
begin
  if ATipo = 'S' then
    cmbTipo.ItemIndex := 1
  else if ATipo = 'O' then
    cmbTipo.ItemIndex := 2
  else
    cmbTipo.ItemIndex := 0;
end;

procedure TfrmProdutoFiscal.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Código'; FieldName := 'CODIGO'; Width := 80; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Descrição'; FieldName := 'DESCRICAO'; Width := 200; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Tipo'; FieldName := 'TIPO'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Valor'; FieldName := 'VALOR'; Width := 80; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'NCM'; FieldName := 'NCM'; Width := 80; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'CFOP'; FieldName := 'CFOP'; Width := 60; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Aliq ICMS'; FieldName := 'ALIQ_ICMS'; Width := 80; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Ativo'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmProdutoFiscal.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL := 'SELECT ID, CODIGO, DESCRICAO, TIPO, VALOR, NCM, CFOP, ALIQ_ICMS, ATIVO FROM PRODUTO_FISCAL WHERE EMPRESA_ID = :EMP';
  if AFiltro <> '' then
    LSQL := LSQL + ' AND (UPPER(DESCRICAO) CONTAINING UPPER(:FILTRO) OR CODIGO CONTAINING :FILTRO2 OR NCM CONTAINING :FILTRO3)';
  LSQL := LSQL + ' ORDER BY DESCRICAO';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  FQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  if AFiltro <> '' then
  begin
    FQuery.ParamByName('FILTRO').AsString := AFiltro;
    FQuery.ParamByName('FILTRO2').AsString := AFiltro;
    FQuery.ParamByName('FILTRO3').AsString := AFiltro;
  end;
  FQuery.Open;
  DataSource1.DataSet := FQuery;
end;

procedure TfrmProdutoFiscal.HabilitarCampos(AHabilitar: Boolean);
begin
  edtCodigo.Enabled := AHabilitar;
  edtDescricao.Enabled := AHabilitar;
  edtNcm.Enabled := AHabilitar;
  edtCest.Enabled := AHabilitar;
  edtCfop.Enabled := AHabilitar;
  edtCfopVenda.Enabled := AHabilitar;
  edtCfopCompra.Enabled := AHabilitar;
  edtCstIcms.Enabled := AHabilitar;
  edtCstPis.Enabled := AHabilitar;
  edtCstCofins.Enabled := AHabilitar;
  edtAliqIcms.Enabled := AHabilitar;
  edtAliqPis.Enabled := AHabilitar;
  edtAliqCofins.Enabled := AHabilitar;
  edtPesoLiquido.Enabled := AHabilitar;
  edtPesoBruto.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
  cmbTipo.Enabled := AHabilitar;
  edtValor.Enabled := AHabilitar;
  mmoObservacoes.Enabled := AHabilitar;
end;

procedure TfrmProdutoFiscal.LimparCampos;
begin
  edtCodigo.Clear;
  edtDescricao.Clear;
  edtNcm.Clear;
  edtCest.Clear;
  edtCfop.Clear;
  edtCfopVenda.Clear;
  edtCfopCompra.Clear;
  edtCstIcms.Clear;
  edtCstPis.Clear;
  edtCstCofins.Clear;
  edtAliqIcms.Text := '0,00';
  edtAliqPis.Text := '0,00';
  edtAliqCofins.Text := '0,00';
  edtPesoLiquido.Text := '0,0000';
  edtPesoBruto.Text := '0,0000';
  cmbStatus.ItemIndex := 0;
  cmbTipo.ItemIndex := 0;
  edtValor.Text := '0,00';
  mmoObservacoes.Clear;
end;

procedure TfrmProdutoFiscal.PreencherCampos;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT * FROM PRODUTO_FISCAL WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      edtCodigo.Text := LQuery.FieldByName('CODIGO').AsString;
      edtDescricao.Text := LQuery.FieldByName('DESCRICAO').AsString;
      edtNcm.Text := LQuery.FieldByName('NCM').AsString;
      edtCest.Text := LQuery.FieldByName('CEST').AsString;
      edtCfop.Text := LQuery.FieldByName('CFOP').AsString;
      edtCfopVenda.Text := LQuery.FieldByName('CFOP_VENDA').AsString;
      edtCfopCompra.Text := LQuery.FieldByName('CFOP_COMPRA').AsString;
      edtCstIcms.Text := LQuery.FieldByName('CST_ICMS').AsString;
      edtCstPis.Text := LQuery.FieldByName('CST_PIS').AsString;
      edtCstCofins.Text := LQuery.FieldByName('CST_COFINS').AsString;
      edtAliqIcms.Text := FormatFloat('#,##0.00', LQuery.FieldByName('ALIQ_ICMS').AsFloat);
      edtAliqPis.Text := FormatFloat('#,##0.00', LQuery.FieldByName('ALIQ_PIS').AsFloat);
      edtAliqCofins.Text := FormatFloat('#,##0.00', LQuery.FieldByName('ALIQ_COFINS').AsFloat);
      edtPesoLiquido.Text := FormatFloat('#,##0.0000', LQuery.FieldByName('PESO_LIQUIDO').AsFloat);
      edtPesoBruto.Text := FormatFloat('#,##0.0000', LQuery.FieldByName('PESO_BRUTO').AsFloat);
      SelecionarTipo(LQuery.FieldByName('TIPO').AsString);
      edtValor.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR').AsFloat);

      if LQuery.FieldByName('ATIVO').AsString = 'A' then
        cmbStatus.ItemIndex := 0
      else
        cmbStatus.ItemIndex := 1;

      mmoObservacoes.Text := LQuery.FieldByName('OBSERVACOES').AsString;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmProdutoFiscal.PreencherObjeto;
begin
  // montado direto no Salvar
end;

function TfrmProdutoFiscal.Validar: Boolean;
begin
  Result := False;

  if Trim(edtDescricao.Text) = '' then
  begin
    MessageDlg('O campo Descrição é obrigatório.', mtWarning, [mbOK], 0);
    edtDescricao.SetFocus;
    Exit;
  end;

  Result := True;
end;

function TfrmProdutoFiscal.Salvar: Boolean;
var
  LFiscal: TProdutoFiscal;
begin
  Result := False;
  LFiscal := TProdutoFiscal.Create;
  try
    if FEstado = efInserindo then
      LFiscal.Id := 0
    else
      LFiscal.Id := FIdSelecionado;
    LFiscal.EmpresaId := TSessao.GetInstance.EmpresaId;
    LFiscal.Codigo := Trim(edtCodigo.Text);
    LFiscal.Descricao := Trim(edtDescricao.Text);
    LFiscal.Ncm := Trim(edtNcm.Text);
    LFiscal.Cest := Trim(edtCest.Text);
    LFiscal.Cfop := Trim(edtCfop.Text);
    LFiscal.CfopVenda := Trim(edtCfopVenda.Text);
    LFiscal.CfopCompra := Trim(edtCfopCompra.Text);
    LFiscal.CstIcms := Trim(edtCstIcms.Text);
    LFiscal.CstPis := Trim(edtCstPis.Text);
    LFiscal.CstCofins := Trim(edtCstCofins.Text);
    LFiscal.AliqIcms := StrToFloatDef(edtAliqIcms.Text, 0);
    LFiscal.AliqPis := StrToFloatDef(edtAliqPis.Text, 0);
    LFiscal.AliqCofins := StrToFloatDef(edtAliqCofins.Text, 0);
    LFiscal.PesoLiquido := StrToFloatDef(edtPesoLiquido.Text, 0);
    LFiscal.PesoBruto := StrToFloatDef(edtPesoBruto.Text, 0);
    LFiscal.Tipo := TipoSelecionado;
    LFiscal.Valor := StrToFloatDef(edtValor.Text, 0);
    LFiscal.Observacoes := mmoObservacoes.Text;
    if cmbStatus.ItemIndex = 0 then
      LFiscal.Ativo := 'A'
    else
      LFiscal.Ativo := 'I';

    if LFiscal.Id = 0 then
      LFiscal.Id := FService.Inserir(LFiscal)
    else
      FService.Atualizar(LFiscal);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
  end;
  LFiscal.Free;
end;

function TfrmProdutoFiscal.Excluir: Boolean;
begin
  Result := False;
  try
    FService.Excluir(FIdSelecionado);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao excluir: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

end.
