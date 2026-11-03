unit uFrmPessoas;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - D3 (unificação) - Formulário de Pessoas
  Unificação de Clientes e Fornecedores com filtro por TIPO (C/F).
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls, MaskEdit,
  uFrmCadastroBase, uPessoaService, uPessoa, uValidacoes, uSessao, uConexao,
  uGeoCombos;

type
  { TfrmPessoas }
  TfrmPessoas = class(TfrmCadastroBase)
    lblFiltroTipo: TLabel;
    cmbFiltroTipo: TComboBox;
    lblTipo: TLabel;
    cmbTipo: TComboBox;
    lblTipoPessoa: TLabel;
    cmbTipoPessoa: TComboBox;
    lblNome: TLabel;
    edtNome: TEdit;
    lblNomeFantasia: TLabel;
    edtNomeFantasia: TEdit;
    lblCpfCnpj: TLabel;
    edtCpfCnpj: TEdit;
    lblRgIe: TLabel;
    edtRgIe: TEdit;
    lblEndereco: TLabel;
    edtEndereco: TEdit;
    lblNumero: TLabel;
    edtNumero: TEdit;
    lblComplemento: TLabel;
    edtComplemento: TEdit;
    lblBairro: TLabel;
    edtBairro: TEdit;
    lblPais: TLabel;
    cmbPais: TComboBox;
    lblEstado: TLabel;
    cmbEstado: TComboBox;
    lblCidade: TLabel;
    cmbCidade: TComboBox;
    lblUf: TLabel;
    cmbUf: TComboBox;
    lblCep: TLabel;
    edtCep: TEdit;
    lblTelefone: TLabel;
    edtTelefone: TEdit;
    lblCelular: TLabel;
    edtCelular: TEdit;
    lblEmail: TLabel;
    edtEmail: TEdit;
    lblContato: TLabel;
    edtContato: TEdit;
    lblDataNascimento: TLabel;
    edtDataNascimento: TEdit;
    lblLimiteCredito: TLabel;
    edtLimiteCredito: TEdit;
    lblStatus: TLabel;
    cmbStatus: TComboBox;
    lblObservacoes: TLabel;
    mmoObservacoes: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cmbPaisChange(Sender: TObject);
    procedure cmbEstadoChange(Sender: TObject);
    procedure cmbFiltroTipoChange(Sender: TObject);
    procedure cmbTipoChange(Sender: TObject);
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
    FService: TPessoaService;
    FPessoa: TPessoa;
    FQuery: TSQLQuery;
    FAtualizandoGeo: Boolean;
    FEditando: Boolean;
    function TipoSelecionado: Char;
    procedure AtualizarRotulos;
    procedure ConfigurarGrid;
    procedure CarregarUFs;
    procedure CarregarGeoInicial;
  end;

var
  frmPessoas: TfrmPessoas;

implementation

{$R *.lfm}

{ TfrmPessoas }

procedure TfrmPessoas.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TPessoaService.Create;
    FPessoa := TPessoa.Create;
    FEditando := False;
    FAtualizandoGeo := False;

    inherited;

    lblTitulo.Caption := 'Cadastro de Pessoas';
    Caption := 'Pessoas';

    CarregarUFs;
    ConfigurarGrid;

    cmbFiltroTipo.Items.Clear;
    cmbFiltroTipo.Items.Add('Todos');
    cmbFiltroTipo.Items.Add('Clientes');
    cmbFiltroTipo.Items.Add('Fornecedores');
    cmbFiltroTipo.ItemIndex := 0;

    cmbTipo.Items.Clear;
    cmbTipo.Items.Add('Cliente');
    cmbTipo.Items.Add('Fornecedor');
    cmbTipo.ItemIndex := 0;

    cmbTipoPessoa.Items.Clear;
    cmbTipoPessoa.Items.Add('Física');
    cmbTipoPessoa.Items.Add('Jurídica');
    cmbTipoPessoa.ItemIndex := 0;

    cmbStatus.Items.Clear;
    cmbStatus.Items.Add('Ativo');
    cmbStatus.Items.Add('Inativo');
    cmbStatus.ItemIndex := 0;

    CarregarGeoInicial;
    AtualizarRotulos;
    CarregarDados;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPessoas.FormDestroy(Sender: TObject);
begin
  if Assigned(DataSource1) then
    DataSource1.DataSet := nil;
  if Assigned(FPessoa) then
    FreeAndNil(FPessoa);
  if Assigned(FService) then
    FreeAndNil(FService);
  inherited;
end;

function TfrmPessoas.TipoSelecionado: Char;
begin
  if cmbTipo.ItemIndex = 1 then
    Result := 'F'
  else
    Result := 'C';
end;

procedure TfrmPessoas.AtualizarRotulos;
begin
  if TipoSelecionado = 'F' then
  begin
    lblNome.Caption := 'Razão social: *';
    lblRgIe.Caption := 'IE:';
  end
  else
  begin
    lblNome.Caption := 'Nome: *';
    lblRgIe.Caption := 'RG/IE:';
  end;
end;

procedure TfrmPessoas.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;

  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'Tipo'; FieldName := 'TIPO'; Width := 45; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'Nome'; FieldName := 'NOME'; Width := 220; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'CPF/CNPJ'; FieldName := 'CPF_CNPJ'; Width := 130; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'Cidade'; FieldName := 'CIDADE'; Width := 130; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'UF'; FieldName := 'UF'; Width := 35; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'Telefone'; FieldName := 'TELEFONE'; Width := 110; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'Status'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmPessoas.CarregarUFs;
begin
  cmbUf.Items.Clear;
  cmbUf.Items.AddStrings([
    'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO',
    'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR',
    'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO'
  ]);
end;

procedure TfrmPessoas.CarregarGeoInicial;
begin
  FAtualizandoGeo := True;
  try
    CarregarComboPaises(cmbPais);
    CarregarComboEstados(cmbEstado, IdDoCombo(cmbPais));
    CarregarComboCidades(cmbCidade, IdDoCombo(cmbEstado));
  finally
    FAtualizandoGeo := False;
  end;
end;

procedure TfrmPessoas.cmbPaisChange(Sender: TObject);
begin
  if FAtualizandoGeo then
    Exit;
  FAtualizandoGeo := True;
  try
    CarregarComboEstados(cmbEstado, IdDoCombo(cmbPais));
    CarregarComboCidades(cmbCidade, 0);
  finally
    FAtualizandoGeo := False;
  end;
  cmbUf.ItemIndex := -1;
end;

procedure TfrmPessoas.cmbEstadoChange(Sender: TObject);
begin
  if FAtualizandoGeo then
    Exit;
  FAtualizandoGeo := True;
  try
    CarregarComboCidades(cmbCidade, IdDoCombo(cmbEstado));
  finally
    FAtualizandoGeo := False;
  end;
  cmbUf.Text := UfDoComboEstado(cmbEstado);
end;

procedure TfrmPessoas.cmbFiltroTipoChange(Sender: TObject);
begin
  CarregarDados;
end;

procedure TfrmPessoas.cmbTipoChange(Sender: TObject);
begin
  AtualizarRotulos;
  if FEstado <> efNavegando then
  begin
    edtContato.Enabled := TipoSelecionado = 'F';
    edtLimiteCredito.Enabled := TipoSelecionado = 'C';
  end;
end;

procedure TfrmPessoas.HabilitarCampos(AHabilitar: Boolean);
begin
  edtNome.Enabled := AHabilitar;
  edtNomeFantasia.Enabled := AHabilitar;
  edtCpfCnpj.Enabled := AHabilitar;
  edtRgIe.Enabled := AHabilitar;
  edtEndereco.Enabled := AHabilitar;
  edtNumero.Enabled := AHabilitar;
  edtComplemento.Enabled := AHabilitar;
  edtBairro.Enabled := AHabilitar;
  cmbPais.Enabled := AHabilitar;
  cmbEstado.Enabled := AHabilitar;
  cmbCidade.Enabled := AHabilitar;
  cmbUf.Enabled := AHabilitar;
  edtCep.Enabled := AHabilitar;
  edtTelefone.Enabled := AHabilitar;
  edtCelular.Enabled := AHabilitar;
  edtEmail.Enabled := AHabilitar;
  edtContato.Enabled := AHabilitar and (TipoSelecionado = 'F');
  edtDataNascimento.Enabled := AHabilitar;
  edtLimiteCredito.Enabled := AHabilitar and (TipoSelecionado = 'C');
  cmbStatus.Enabled := AHabilitar;
  mmoObservacoes.Enabled := AHabilitar;

  // O tipo só pode ser alterado na inclusão.
  cmbTipo.Enabled := AHabilitar and (not FEditando);
  cmbTipoPessoa.Enabled := AHabilitar;
  cmbFiltroTipo.Enabled := not AHabilitar;

  AtualizarRotulos;
end;

procedure TfrmPessoas.LimparCampos;
begin
  cmbTipo.ItemIndex := 0;
  cmbTipoPessoa.ItemIndex := 0;
  edtNome.Clear;
  edtNomeFantasia.Clear;
  edtCpfCnpj.Clear;
  edtRgIe.Clear;
  edtEndereco.Clear;
  edtNumero.Clear;
  edtComplemento.Clear;
  edtBairro.Clear;
  CarregarGeoInicial;
  cmbUf.ItemIndex := -1;
  edtCep.Clear;
  edtTelefone.Clear;
  edtCelular.Clear;
  edtEmail.Clear;
  edtContato.Clear;
  edtDataNascimento.Clear;
  edtLimiteCredito.Text := '0,00';
  cmbStatus.ItemIndex := 0;
  mmoObservacoes.Clear;
  FEditando := False;
  AtualizarRotulos;
end;

procedure TfrmPessoas.PreencherCampos;
var
  LPessoa: TPessoa;
begin
  LPessoa := FService.BuscarPorId(FIdSelecionado);
  if LPessoa = nil then
  begin
    MessageDlg('Registro não encontrado.', mtError, [mbOK], 0);
    Exit;
  end;

  FPessoa.Free;
  FPessoa := LPessoa;

  if FPessoa.Tipo = 'F' then
    cmbTipo.ItemIndex := 1
  else
    cmbTipo.ItemIndex := 0;

  if FPessoa.TipoPessoa = 'J' then
    cmbTipoPessoa.ItemIndex := 1
  else
    cmbTipoPessoa.ItemIndex := 0;

  edtNome.Text := FPessoa.Nome;
  edtNomeFantasia.Text := FPessoa.NomeFantasia;
  edtCpfCnpj.Text := FPessoa.CpfCnpj;
  edtRgIe.Text := FPessoa.RgIe;
  edtEndereco.Text := FPessoa.Endereco;
  edtNumero.Text := FPessoa.Numero;
  edtComplemento.Text := FPessoa.Complemento;
  edtBairro.Text := FPessoa.Bairro;

  FAtualizandoGeo := True;
  try
    CarregarComboPaises(cmbPais);
    if FPessoa.CidadeId > 0 then
      SelecionarCidade(cmbPais, cmbEstado, cmbCidade, FPessoa.CidadeId)
    else
    begin
      CarregarComboEstados(cmbEstado, IdDoCombo(cmbPais));
      CarregarComboCidades(cmbCidade, IdDoCombo(cmbEstado));
      MostrarCidadeLivre(cmbCidade, FPessoa.Cidade);
    end;
  finally
    FAtualizandoGeo := False;
  end;

  cmbUf.Text := FPessoa.Uf;
  edtCep.Text := FPessoa.Cep;
  edtTelefone.Text := FPessoa.Telefone;
  edtCelular.Text := FPessoa.Celular;
  edtEmail.Text := FPessoa.Email;
  edtContato.Text := FPessoa.Contato;
  if FPessoa.DataNascimento > 0 then
    edtDataNascimento.Text := FormatDateTime('dd/mm/yyyy', FPessoa.DataNascimento)
  else
    edtDataNascimento.Clear;
  edtLimiteCredito.Text := CurrToStr(FPessoa.LimiteCredito);

  if FPessoa.Ativo = 'A' then
    cmbStatus.ItemIndex := 0
  else
    cmbStatus.ItemIndex := 1;

  mmoObservacoes.Text := FPessoa.Observacoes;

  FEditando := True;
  AtualizarRotulos;
end;

procedure TfrmPessoas.PreencherObjeto;
begin
  FPessoa.Id := FIdSelecionado;
  FPessoa.EmpresaId := TSessao.GetInstance.EmpresaId;

  FPessoa.Tipo := TipoSelecionado;

  if cmbTipoPessoa.ItemIndex = 0 then
    FPessoa.TipoPessoa := 'F'
  else
    FPessoa.TipoPessoa := 'J';

  FPessoa.Nome := Trim(edtNome.Text);
  FPessoa.NomeFantasia := Trim(edtNomeFantasia.Text);
  FPessoa.CpfCnpj := Trim(edtCpfCnpj.Text);
  FPessoa.RgIe := Trim(edtRgIe.Text);
  FPessoa.Endereco := Trim(edtEndereco.Text);
  FPessoa.Numero := Trim(edtNumero.Text);
  FPessoa.Complemento := Trim(edtComplemento.Text);
  FPessoa.Bairro := Trim(edtBairro.Text);
  FPessoa.Cidade := Trim(cmbCidade.Text);
  FPessoa.CidadeId := IdDoCombo(cmbCidade);
  FPessoa.Uf := Trim(cmbUf.Text);
  FPessoa.Cep := Trim(edtCep.Text);
  FPessoa.Telefone := Trim(edtTelefone.Text);
  FPessoa.Celular := Trim(edtCelular.Text);
  FPessoa.Email := Trim(edtEmail.Text);
  FPessoa.Contato := Trim(edtContato.Text);
  FPessoa.LimiteCredito := StrToCurrDef(edtLimiteCredito.Text, 0);
  FPessoa.Observacoes := mmoObservacoes.Text;

  if Trim(edtDataNascimento.Text) <> '' then
  begin
    try
      FPessoa.DataNascimento := StrToDate(edtDataNascimento.Text);
    except
      FPessoa.DataNascimento := 0;
    end;
  end
  else
    FPessoa.DataNascimento := 0;

  if cmbStatus.ItemIndex = 0 then
    FPessoa.Ativo := 'A'
  else
    FPessoa.Ativo := 'I';
end;

function TfrmPessoas.Validar: Boolean;
begin
  Result := False;

  if Trim(edtNome.Text) = '' then
  begin
    MessageDlg('O campo Nome é obrigatório.', mtWarning, [mbOK], 0);
    edtNome.SetFocus;
    Exit;
  end;

  if Trim(edtCpfCnpj.Text) = '' then
  begin
    MessageDlg('O campo CPF/CNPJ é obrigatório.', mtWarning, [mbOK], 0);
    edtCpfCnpj.SetFocus;
    Exit;
  end;

  if cmbTipoPessoa.ItemIndex = 0 then
  begin
    if not ValidarCPF(edtCpfCnpj.Text) then
    begin
      MessageDlg('CPF inválido.', mtWarning, [mbOK], 0);
      edtCpfCnpj.SetFocus;
      Exit;
    end;
  end
  else
  begin
    if not ValidarCNPJ(edtCpfCnpj.Text) then
    begin
      MessageDlg('CNPJ inválido.', mtWarning, [mbOK], 0);
      edtCpfCnpj.SetFocus;
      Exit;
    end;
  end;

  if (Trim(edtEmail.Text) <> '') and (not ValidarEmail(edtEmail.Text)) then
  begin
    MessageDlg('E-mail inválido.', mtWarning, [mbOK], 0);
    edtEmail.SetFocus;
    Exit;
  end;

  Result := True;
end;

procedure TfrmPessoas.CarregarDados(const AFiltro: string = '');
var
  LTipo: Char;
begin
  LTipo := #0;
  if cmbFiltroTipo.ItemIndex = 1 then
    LTipo := 'C'
  else if cmbFiltroTipo.ItemIndex = 2 then
    LTipo := 'F';

  FQuery := FService.BuscarTodos(LTipo, AFiltro);
  DataSource1.DataSet := FQuery;
end;

function TfrmPessoas.Salvar: Boolean;
begin
  Result := False;
  try
    if FEstado = efInserindo then
      Result := FService.Inserir(FPessoa) > 0
    else
      Result := FService.Atualizar(FPessoa);
  except
    on E: Exception do
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

function TfrmPessoas.Excluir: Boolean;
begin
  Result := False;
  try
    Result := FService.Excluir(FIdSelecionado);
  except
    on E: Exception do
      MessageDlg('Erro ao excluir: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

end.
