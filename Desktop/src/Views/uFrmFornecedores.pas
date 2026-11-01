unit uFrmFornecedores;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 2 - Formulário de Fornecedores
  Descrição: CRUD completo de Fornecedores
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uValidacoes, uSessao, uGeoCombos;

type
  { TfrmFornecedores }
  TfrmFornecedores = class(TfrmCadastroBase)
    lblTipoPessoa: TLabel;
    cmbTipoPessoa: TComboBox;
    lblRazaoSocial: TLabel;
    edtRazaoSocial: TEdit;
    lblNomeFantasia: TLabel;
    edtNomeFantasia: TEdit;
    lblCpfCnpj: TLabel;
    edtCpfCnpj: TEdit;
    lblIe: TLabel;
    edtIe: TEdit;
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
    FQuery: TSQLQuery;
    FAtualizandoGeo: Boolean;
    procedure ConfigurarGrid;
    procedure CarregarUFs;
    procedure CarregarGeoInicial;
  end;

var
  frmFornecedores: TfrmFornecedores;

implementation

{$R *.lfm}

{ TfrmFornecedores }

procedure TfrmFornecedores.FormCreate(Sender: TObject);
begin
  try
    // Inicializar FConexao primeiro (como faz a classe base)
    FConexao := TConexao.GetInstance;

    // Iniciar conexão com o banco
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    // Criar DataSource1 se não existir
    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Cadastro de Fornecedores';
    Caption := 'Fornecedores';
    CarregarUFs;
    CarregarGeoInicial;
    ConfigurarGrid;

    // Inicializar ComboBox de tipo de pessoa
    cmbTipoPessoa.Items.Clear;
    cmbTipoPessoa.Items.Add('Física');
    cmbTipoPessoa.Items.Add('Jurídica');
    cmbTipoPessoa.ItemIndex := 1;

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

procedure TfrmFornecedores.FormDestroy(Sender: TObject);
begin
  inherited;
end;

procedure TfrmFornecedores.CarregarUFs;
begin
  cmbUf.Items.Clear;
  cmbUf.Items.AddStrings([
    'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO',
    'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR',
    'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO'
  ]);
end;

procedure TfrmFornecedores.CarregarGeoInicial;
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

procedure TfrmFornecedores.cmbPaisChange(Sender: TObject);
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

procedure TfrmFornecedores.cmbEstadoChange(Sender: TObject);
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

procedure TfrmFornecedores.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Razão Social'; FieldName := 'RAZAO_SOCIAL'; Width := 200; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'CNPJ/CPF'; FieldName := 'CPF_CNPJ'; Width := 130; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Cidade'; FieldName := 'CIDADE'; Width := 120; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'UF'; FieldName := 'UF'; Width := 35; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Telefone'; FieldName := 'TELEFONE'; Width := 110; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Status'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmFornecedores.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL := 'SELECT ID, RAZAO_SOCIAL, CPF_CNPJ, CIDADE, UF, TELEFONE, ATIVO FROM FORNECEDOR';
  if AFiltro <> '' then
    LSQL := LSQL + ' WHERE UPPER(RAZAO_SOCIAL) CONTAINING UPPER(:FILTRO) OR CPF_CNPJ CONTAINING :FILTRO2';
  LSQL := LSQL + ' ORDER BY RAZAO_SOCIAL';

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

procedure TfrmFornecedores.HabilitarCampos(AHabilitar: Boolean);
begin
  cmbTipoPessoa.Enabled := AHabilitar;
  edtRazaoSocial.Enabled := AHabilitar;
  edtNomeFantasia.Enabled := AHabilitar;
  edtCpfCnpj.Enabled := AHabilitar;
  edtIe.Enabled := AHabilitar;
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
  edtContato.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
  mmoObservacoes.Enabled := AHabilitar;
end;

procedure TfrmFornecedores.LimparCampos;
begin
  cmbTipoPessoa.ItemIndex := 1;
  edtRazaoSocial.Clear;
  edtNomeFantasia.Clear;
  edtCpfCnpj.Clear;
  edtIe.Clear;
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
  cmbStatus.ItemIndex := 0;
  mmoObservacoes.Clear;
end;

procedure TfrmFornecedores.PreencherCampos;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT * FROM FORNECEDOR WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      if LQuery.FieldByName('TIPO_PESSOA').AsString = 'F' then
        cmbTipoPessoa.ItemIndex := 0
      else
        cmbTipoPessoa.ItemIndex := 1;

      edtRazaoSocial.Text := LQuery.FieldByName('RAZAO_SOCIAL').AsString;
      edtNomeFantasia.Text := LQuery.FieldByName('NOME_FANTASIA').AsString;
      edtCpfCnpj.Text := LQuery.FieldByName('CPF_CNPJ').AsString;
      edtIe.Text := LQuery.FieldByName('IE').AsString;
      edtEndereco.Text := LQuery.FieldByName('ENDERECO').AsString;
      edtNumero.Text := LQuery.FieldByName('NUMERO').AsString;
      edtComplemento.Text := LQuery.FieldByName('COMPLEMENTO').AsString;
      edtBairro.Text := LQuery.FieldByName('BAIRRO').AsString;
      FAtualizandoGeo := True;
      try
        CarregarComboPaises(cmbPais);
        if LQuery.FieldByName('CIDADE_ID').AsLargeInt > 0 then
          SelecionarCidade(cmbPais, cmbEstado, cmbCidade,
            LQuery.FieldByName('CIDADE_ID').AsLargeInt)
        else
        begin
          CarregarComboEstados(cmbEstado, IdDoCombo(cmbPais));
          CarregarComboCidades(cmbCidade, 0);
          MostrarCidadeLivre(cmbCidade, LQuery.FieldByName('CIDADE').AsString);
        end;
      finally
        FAtualizandoGeo := False;
      end;
      cmbUf.Text := LQuery.FieldByName('UF').AsString;
      edtCep.Text := LQuery.FieldByName('CEP').AsString;
      edtTelefone.Text := LQuery.FieldByName('TELEFONE').AsString;
      edtCelular.Text := LQuery.FieldByName('CELULAR').AsString;
      edtEmail.Text := LQuery.FieldByName('EMAIL').AsString;
      edtContato.Text := LQuery.FieldByName('CONTATO').AsString;

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

procedure TfrmFornecedores.PreencherObjeto;
begin
  // Objeto é montado diretamente no Salvar via SQL
end;

function TfrmFornecedores.Validar: Boolean;
begin
  Result := False;

  if Trim(edtRazaoSocial.Text) = '' then
  begin
    MessageDlg('O campo Razão Social é obrigatório.', mtWarning, [mbOK], 0);
    edtRazaoSocial.SetFocus;
    Exit;
  end;

  if Trim(edtCpfCnpj.Text) = '' then
  begin
    MessageDlg('O campo CPF/CNPJ é obrigatório.', mtWarning, [mbOK], 0);
    edtCpfCnpj.SetFocus;
    Exit;
  end;

  Result := True;
end;

function TfrmFornecedores.Salvar: Boolean;
var
  LQuery: TSQLQuery;
  LTipo: Char;
begin
  Result := False;
  if cmbTipoPessoa.ItemIndex = 0 then LTipo := 'F' else LTipo := 'J';

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;

    if FEstado = efInserindo then
    begin
      LQuery.SQL.Text :=
        'INSERT INTO FORNECEDOR (EMPRESA_ID, TIPO_PESSOA, RAZAO_SOCIAL, NOME_FANTASIA, ' +
        'CPF_CNPJ, IE, ENDERECO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, CIDADE_ID, UF, CEP, ' +
        'TELEFONE, CELULAR, EMAIL, CONTATO, ATIVO, OBSERVACOES) ' +
        'VALUES (:EMPRESA_ID, :TIPO, :RAZAO, :FANTASIA, :CPF, :IE, :END, :NUM, :COMP, ' +
        ':BAIRRO, :CIDADE, :CIDADE_ID, :UF, :CEP, :TEL, :CEL, :EMAIL, :CONTATO, :ATIVO, :OBS)';
    end
    else
    begin
      LQuery.SQL.Text :=
        'UPDATE FORNECEDOR SET TIPO_PESSOA = :TIPO, RAZAO_SOCIAL = :RAZAO, ' +
        'NOME_FANTASIA = :FANTASIA, CPF_CNPJ = :CPF, IE = :IE, ENDERECO = :END, ' +
        'NUMERO = :NUM, COMPLEMENTO = :COMP, BAIRRO = :BAIRRO, CIDADE = :CIDADE, ' +
        'CIDADE_ID = :CIDADE_ID, UF = :UF, CEP = :CEP, TELEFONE = :TEL, ' +
        'CELULAR = :CEL, EMAIL = :EMAIL, ' +
        'CONTATO = :CONTATO, ATIVO = :ATIVO, OBSERVACOES = :OBS WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    end;

    if FEstado = efInserindo then
      LQuery.ParamByName('EMPRESA_ID').AsLargeInt := TSessao.GetInstance.EmpresaId;

    LQuery.ParamByName('TIPO').AsString := LTipo;
    LQuery.ParamByName('RAZAO').AsString := edtRazaoSocial.Text;
    LQuery.ParamByName('FANTASIA').AsString := edtNomeFantasia.Text;
    LQuery.ParamByName('CPF').AsString := edtCpfCnpj.Text;
    LQuery.ParamByName('IE').AsString := edtIe.Text;
    LQuery.ParamByName('END').AsString := edtEndereco.Text;
    LQuery.ParamByName('NUM').AsString := edtNumero.Text;
    LQuery.ParamByName('COMP').AsString := edtComplemento.Text;
    LQuery.ParamByName('BAIRRO').AsString := edtBairro.Text;
    LQuery.ParamByName('CIDADE').AsString := cmbCidade.Text;
    LQuery.ParamByName('CIDADE_ID').AsLargeInt := IdDoCombo(cmbCidade);
    LQuery.ParamByName('UF').AsString := cmbUf.Text;
    LQuery.ParamByName('CEP').AsString := edtCep.Text;
    LQuery.ParamByName('TEL').AsString := edtTelefone.Text;
    LQuery.ParamByName('CEL').AsString := edtCelular.Text;
    LQuery.ParamByName('EMAIL').AsString := edtEmail.Text;
    LQuery.ParamByName('CONTATO').AsString := edtContato.Text;
    LQuery.ParamByName('OBS').AsString := mmoObservacoes.Text;

    if cmbStatus.ItemIndex = 0 then
      LQuery.ParamByName('ATIVO').AsString := 'A'
    else
      LQuery.ParamByName('ATIVO').AsString := 'I';

    LQuery.ExecSQL;
    FConexao.Confirmar;
    Result := True;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

function TfrmFornecedores.Excluir: Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text := 'DELETE FROM FORNECEDOR WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.ExecSQL;
    FConexao.Confirmar;
    Result := True;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro ao excluir: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

end.
