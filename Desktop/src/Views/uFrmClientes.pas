unit uFrmClientes;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 2 - Formulário de Clientes
  Descrição: CRUD completo de Clientes herdando CadastroBase
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls, MaskEdit,
  uFrmCadastroBase, uClienteService, uCliente, uValidacoes, uSessao, uConexao,
  uGeoCombos;

type
  { TfrmClientes }
  TfrmClientes = class(TfrmCadastroBase)
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
    FService: TClienteService;
    FCliente: TCliente;
    FQuery: TSQLQuery;
    FAtualizandoGeo: Boolean;
    procedure ConfigurarGrid;
    procedure CarregarUFs;
    procedure CarregarGeoInicial;
  end;

var
  frmClientes: TfrmClientes;

implementation

{$R *.lfm}

{ TfrmClientes }

procedure TfrmClientes.FormCreate(Sender: TObject);
begin
  try
    // Inicializar FConexao primeiro (como faz a classe base)
    FConexao := TConexao.GetInstance;

    // Iniciar conexão com o banco
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TClienteService.Create;
    FCliente := TCliente.Create;
    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    // Criar DataSource1 se não existir
    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Cadastro de Clientes';
    Caption := 'Clientes';

    CarregarUFs;
    CarregarGeoInicial;
    ConfigurarGrid;

    // Inicializar ComboBox de tipo de pessoa
    cmbTipoPessoa.Items.Clear;
    cmbTipoPessoa.Items.Add('Física');
    cmbTipoPessoa.Items.Add('Jurídica');
    cmbTipoPessoa.ItemIndex := 0;

    // Inicializar ComboBox de status
    cmbStatus.Items.Clear;
    cmbStatus.Items.Add('Ativo');
    cmbStatus.Items.Add('Inativo');
    cmbStatus.ItemIndex := 0;

    // Configurar estado inicial (como faz a classe base)
    FEstado := efNavegando;
    Position := poScreenCenter;
    BorderStyle := bsSizeable;

    // Agora carregar os dados
    CarregarDados;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmClientes.FormDestroy(Sender: TObject);
begin
  FCliente.Free;
  FService.Free;
  inherited;
end;

procedure TfrmClientes.CarregarUFs;
begin
  cmbUf.Items.Clear;
  cmbUf.Items.AddStrings([
    'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO',
    'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR',
    'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO'
  ]);
end;

procedure TfrmClientes.CarregarGeoInicial;
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

procedure TfrmClientes.cmbPaisChange(Sender: TObject);
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

procedure TfrmClientes.cmbEstadoChange(Sender: TObject);
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

procedure TfrmClientes.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;

  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'Nome'; FieldName := 'NOME'; Width := 200; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'CPF/CNPJ'; FieldName := 'CPF_CNPJ'; Width := 130; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'Cidade'; FieldName := 'CIDADE'; Width := 120; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'UF'; FieldName := 'UF'; Width := 35; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'Telefone'; FieldName := 'TELEFONE'; Width := 110; end;
  with dbGrid.Columns.Add do begin Field := nil; Title.Caption := 'Status'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmClientes.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL := 'SELECT ID, NOME, CPF_CNPJ, CIDADE, UF, TELEFONE, ATIVO FROM CLIENTE';
  if AFiltro <> '' then
    LSQL := LSQL + ' WHERE UPPER(NOME) CONTAINING UPPER(:FILTRO) OR CPF_CNPJ CONTAINING :FILTRO2';
  LSQL := LSQL + ' ORDER BY NOME';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  if AFiltro <> '' then
  begin
    FQuery.ParamByName('FILTRO').AsString := AFiltro;
    FQuery.ParamByName('FILTRO2').AsString := AFiltro;
  end;
  FQuery.Open;
  DataSource1.DataSet := FQuery;
end;

procedure TfrmClientes.HabilitarCampos(AHabilitar: Boolean);
begin
  cmbTipoPessoa.Enabled := AHabilitar;
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
  edtLimiteCredito.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
  mmoObservacoes.Enabled := AHabilitar;
end;

procedure TfrmClientes.LimparCampos;
begin
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
  edtLimiteCredito.Text := '0,00';
  cmbStatus.ItemIndex := 0;
  mmoObservacoes.Clear;
end;

procedure TfrmClientes.PreencherCampos;
var
  LCliente: TCliente;
begin
  LCliente := FService.BuscarPorId(FIdSelecionado);
  if LCliente = nil then
  begin
    MessageDlg('Registro não encontrado.', mtError, [mbOK], 0);
    Exit;
  end;

  try
    if LCliente.TipoPessoa = 'F' then
      cmbTipoPessoa.ItemIndex := 0
    else
      cmbTipoPessoa.ItemIndex := 1;

    edtNome.Text := LCliente.Nome;
    edtNomeFantasia.Text := LCliente.NomeFantasia;
    edtCpfCnpj.Text := LCliente.CpfCnpj;
    edtRgIe.Text := LCliente.RgIe;
    edtEndereco.Text := LCliente.Endereco;
    edtNumero.Text := LCliente.Numero;
    edtComplemento.Text := LCliente.Complemento;
    edtBairro.Text := LCliente.Bairro;
    FAtualizandoGeo := True;
    try
      CarregarComboPaises(cmbPais);
      if LCliente.CidadeId > 0 then
        SelecionarCidade(cmbPais, cmbEstado, cmbCidade, LCliente.CidadeId)
      else
      begin
        CarregarComboEstados(cmbEstado, IdDoCombo(cmbPais));
        CarregarComboCidades(cmbCidade, 0);
        MostrarCidadeLivre(cmbCidade, LCliente.Cidade);
      end;
    finally
      FAtualizandoGeo := False;
    end;
    cmbUf.Text := LCliente.Uf;
    edtCep.Text := LCliente.Cep;
    edtTelefone.Text := LCliente.Telefone;
    edtCelular.Text := LCliente.Celular;
    edtEmail.Text := LCliente.Email;
    edtLimiteCredito.Text := CurrToStr(LCliente.LimiteCredito);

    if LCliente.Ativo = 'A' then
      cmbStatus.ItemIndex := 0
    else
      cmbStatus.ItemIndex := 1;

    mmoObservacoes.Text := LCliente.Observacoes;
  finally
    LCliente.Free;
  end;
end;

procedure TfrmClientes.PreencherObjeto;
begin
  FCliente.Id := FIdSelecionado;
  FCliente.EmpresaId := TSessao.GetInstance.EmpresaId;

  if cmbTipoPessoa.ItemIndex = 0 then
    FCliente.TipoPessoa := 'F'
  else
    FCliente.TipoPessoa := 'J';

  FCliente.Nome := Trim(edtNome.Text);
  FCliente.NomeFantasia := Trim(edtNomeFantasia.Text);
  FCliente.CpfCnpj := Trim(edtCpfCnpj.Text);
  FCliente.RgIe := Trim(edtRgIe.Text);
  FCliente.Endereco := Trim(edtEndereco.Text);
  FCliente.Numero := Trim(edtNumero.Text);
  FCliente.Complemento := Trim(edtComplemento.Text);
  FCliente.Bairro := Trim(edtBairro.Text);
  FCliente.Cidade := Trim(cmbCidade.Text);
  FCliente.CidadeId := IdDoCombo(cmbCidade);
  FCliente.Uf := cmbUf.Text;
  FCliente.Cep := Trim(edtCep.Text);
  FCliente.Telefone := Trim(edtTelefone.Text);
  FCliente.Celular := Trim(edtCelular.Text);
  FCliente.Email := Trim(edtEmail.Text);
  FCliente.LimiteCredito := StrToCurrDef(edtLimiteCredito.Text, 0);
  FCliente.Observacoes := mmoObservacoes.Text;

  if cmbStatus.ItemIndex = 0 then
    FCliente.Ativo := 'A'
  else
    FCliente.Ativo := 'I';
end;

function TfrmClientes.Validar: Boolean;
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

  // Validar CPF ou CNPJ
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

  // Validar email se preenchido
  if (Trim(edtEmail.Text) <> '') and (not ValidarEmail(edtEmail.Text)) then
  begin
    MessageDlg('E-mail inválido.', mtWarning, [mbOK], 0);
    edtEmail.SetFocus;
    Exit;
  end;

  Result := True;
end;

function TfrmClientes.Salvar: Boolean;
begin
  Result := False;
  try
    if FEstado = efInserindo then
      FService.Inserir(FCliente)
    else
      FService.Atualizar(FCliente);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

function TfrmClientes.Excluir: Boolean;
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
