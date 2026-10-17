unit uFrmPDV;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 5 - Frente de Caixa / PDV
  Descrição: Ponto de Venda com leitura de código de barras
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, Grids, DB, SQLDB, ComCtrls,
  uConexao, uSessao;

type
  { TfrmPDV }
  TfrmPDV = class(TForm)
    pnlTopo: TPanel;
    lblEmpresa: TLabel;
    lblOperador: TLabel;
    lblCaixa: TLabel;
    pnlBarras: TPanel;
    lblCodigo: TLabel;
    edtCodigo: TEdit;
    lblProdutoDesc: TLabel;
    pnlItens: TPanel;
    sgItens: TStringGrid;
    pnlDireita: TPanel;
    pnlTotal: TPanel;
    lblTotalLabel: TLabel;
    lblTotalValor: TLabel;
    lblSubtotalLabel: TLabel;
    lblSubtotalValor: TLabel;
    lblDescontoLabel: TLabel;
    edtDesconto: TEdit;
    lblItensLabel: TLabel;
    lblItensQtd: TLabel;
    pnlPagamento: TPanel;
    lblFormaPag: TLabel;
    cmbFormaPag: TComboBox;
    lblRecebido: TLabel;
    edtRecebido: TEdit;
    lblTroco: TLabel;
    lblTrocoValor: TLabel;
    pnlAcoes: TPanel;
    btnFinalizar: TBitBtn;
    btnCancelarVenda: TBitBtn;
    btnCancelarItem: TBitBtn;
    btnSangria: TBitBtn;
    btnSuprimento: TBitBtn;
    btnFecharCaixa: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtCodigoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtRecebidoExit(Sender: TObject);
    procedure edtDescontoExit(Sender: TObject);
    procedure btnFinalizarClick(Sender: TObject);
    procedure btnCancelarVendaClick(Sender: TObject);
    procedure btnCancelarItemClick(Sender: TObject);
    procedure btnSangriaClick(Sender: TObject);
    procedure btnSuprimentoClick(Sender: TObject);
    procedure btnFecharCaixaClick(Sender: TObject);
  private
    FConexao: TConexao;
    FCaixaId: Int64;
    FVendaNumero: Integer;
    procedure ConfigurarGrid;
    procedure BuscarProduto(const ACodigo: string);
    procedure RecalcularTotais;
    procedure LimparVenda;
    function VerificarCaixaAberto: Boolean;
    procedure AbrirCaixa;
    procedure RegistrarMovimentoCaixa(ATipo: Char; AValor: Double; const ADesc: string);
  end;

var
  frmPDV: TfrmPDV;

implementation

{$R *.lfm}

procedure TfrmPDV.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    // Iniciar conexão com o banco
    if not FConexao.Conectado then
      FConexao.Conectar;
    FCaixaId := 0;

    ConfigurarGrid;
    lblOperador.Caption := 'Operador: ' + TSessao.GetInstance.UsuarioNome;

    if not VerificarCaixaAberto then
      AbrirCaixa;

    FVendaNumero := 1;
    edtCodigo.SetFocus;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPDV.ConfigurarGrid;
begin
  sgItens.ColCount := 6;
  sgItens.RowCount := 1;
  sgItens.FixedRows := 1;
  sgItens.Cells[0, 0] := 'Item';
  sgItens.Cells[1, 0] := 'Código';
  sgItens.Cells[2, 0] := 'Descrição';
  sgItens.Cells[3, 0] := 'Qtd';
  sgItens.Cells[4, 0] := 'Vlr Unit.';
  sgItens.Cells[5, 0] := 'Total';
  sgItens.ColWidths[0] := 40;
  sgItens.ColWidths[1] := 100;
  sgItens.ColWidths[2] := 280;
  sgItens.ColWidths[3] := 60;
  sgItens.ColWidths[4] := 90;
  sgItens.ColWidths[5] := 90;
end;

function TfrmPDV.VerificarCaixaAberto: Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID FROM CAIXA WHERE USUARIO_ID = :USR AND STATUS = ''A'' ' +
      'AND DATA_ABERTURA >= CURRENT_DATE';
    LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      FCaixaId := LQuery.FieldByName('ID').AsLargeInt;
      Result := True;
      lblCaixa.Caption := 'Caixa: ' + IntToStr(FCaixaId) + ' (Aberto)';
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmPDV.AbrirCaixa;
var
  LQuery: TSQLQuery;
  LValor: string;
begin
  if not InputQuery('Abertura de Caixa', 'Valor inicial:', LValor) then
  begin
    Close;
    Exit;
  end;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text :=
      'INSERT INTO CAIXA (EMPRESA_ID, USUARIO_ID, VALOR_ABERTURA, STATUS) ' +
      'VALUES (:EMP, :USR, :VLR, ''A'')';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
    LQuery.ParamByName('VLR').AsFloat := StrToFloatDef(LValor, 0);
    LQuery.ExecSQL;
    FConexao.Confirmar;

    LQuery.SQL.Text := 'SELECT GEN_ID(GEN_CAIXA_ID, 0) FROM RDB$DATABASE';
    LQuery.Open;
    FCaixaId := LQuery.Fields[0].AsLargeInt;
    lblCaixa.Caption := 'Caixa: ' + IntToStr(FCaixaId) + ' (Aberto)';
    MessageDlg('Caixa aberto com sucesso!', mtInformation, [mbOK], 0);
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

procedure TfrmPDV.BuscarProduto(const ACodigo: string);
var
  LQuery: TSQLQuery;
  LRow: Integer;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID, CODIGO, DESCRICAO, PRECO_VENDA FROM PRODUTO ' +
      'WHERE (CODIGO = :COD OR CODIGO_BARRAS = :COD) AND ATIVO = ''A''';
    LQuery.ParamByName('COD').AsString := ACodigo;
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      LRow := sgItens.RowCount;
      sgItens.RowCount := LRow + 1;
      sgItens.Cells[0, LRow] := IntToStr(LRow);
      sgItens.Cells[1, LRow] := LQuery.FieldByName('CODIGO').AsString;
      sgItens.Cells[2, LRow] := LQuery.FieldByName('DESCRICAO').AsString;
      sgItens.Cells[3, LRow] := '1';
      sgItens.Cells[4, LRow] := FormatFloat('#,##0.00', LQuery.FieldByName('PRECO_VENDA').AsFloat);
      sgItens.Cells[5, LRow] := FormatFloat('#,##0.00', LQuery.FieldByName('PRECO_VENDA').AsFloat);

      lblProdutoDesc.Caption := LQuery.FieldByName('DESCRICAO').AsString +
        ' - R$ ' + FormatFloat('#,##0.00', LQuery.FieldByName('PRECO_VENDA').AsFloat);

      RecalcularTotais;
    end
    else
    begin
      lblProdutoDesc.Caption := 'Produto não encontrado!';
      // MessageBeep removido para compatibilidade multi-plataforma
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmPDV.RecalcularTotais;
var
  I: Integer;
  LSub: Double;
  LDesc: Double;
  LRecebido: Double;
begin
  LSub := 0;
  for I := 1 to sgItens.RowCount - 1 do
    LSub := LSub + StrToFloatDef(sgItens.Cells[5, I], 0);

  LDesc := StrToFloatDef(edtDesconto.Text, 0);
  lblSubtotalValor.Caption := 'R$ ' + FormatFloat('#,##0.00', LSub);
  lblTotalValor.Caption := 'R$ ' + FormatFloat('#,##0.00', LSub - LDesc);
  lblItensQtd.Caption := IntToStr(sgItens.RowCount - 1);

  // Calcular troco
  LRecebido := StrToFloatDef(edtRecebido.Text, 0);
  if LRecebido > 0 then
    lblTrocoValor.Caption := 'R$ ' + FormatFloat('#,##0.00', LRecebido - (LSub - LDesc))
  else
    lblTrocoValor.Caption := 'R$ 0,00';
end;

procedure TfrmPDV.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    113: btnFinalizarClick(nil);       // F2 = Finalizar
    114: btnCancelarItemClick(nil);    // F3 = Cancelar item
    115: btnSangriaClick(nil);         // F4 = Sangria
    116: btnSuprimentoClick(nil);      // F5 = Suprimento
    117: btnCancelarVendaClick(nil);   // F6 = Cancelar venda
    27:  edtCodigo.SetFocus;           // ESC = Foco no código
  end;
end;

procedure TfrmPDV.edtCodigoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 13 then
  begin
    if Trim(edtCodigo.Text) <> '' then
    begin
      BuscarProduto(Trim(edtCodigo.Text));
      edtCodigo.Clear;
    end;
  end;
end;

procedure TfrmPDV.edtRecebidoExit(Sender: TObject);
begin
  RecalcularTotais;
end;

procedure TfrmPDV.edtDescontoExit(Sender: TObject);
begin
  RecalcularTotais;
end;

procedure TfrmPDV.btnFinalizarClick(Sender: TObject);
var
  LQuery: TSQLQuery;
  I: Integer;
  LTotal: Double;
  LPedidoId: Int64;
  LCodigo: string;
  LQtd, LPreco: Double;
  LProdutoId: Int64;
begin
  if sgItens.RowCount <= 1 then
  begin
    MessageDlg('Nenhum item na venda.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if cmbFormaPag.ItemIndex < 0 then
  begin
    MessageDlg('Selecione a forma de pagamento.', mtWarning, [mbOK], 0);
    Exit;
  end;

  LTotal := StrToFloatDef(
    StringReplace(StringReplace(lblTotalValor.Caption, 'R$ ', '', []), '.', '', [rfReplaceAll]),
    0);

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;

    // Criar pedido de venda tipo PDV
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, USUARIO_ID, STATUS, ' +
      'SUBTOTAL, DESCONTO, TOTAL, OBSERVACOES) ' +
      'VALUES (:EMP, :USR, ''F'', :SUB, :DESC, :TOT, ''PDV'')';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
    LQuery.ParamByName('SUB').AsFloat := StrToFloatDef(
      StringReplace(StringReplace(lblSubtotalValor.Caption, 'R$ ', '', []), '.', '', [rfReplaceAll]), 0);
    LQuery.ParamByName('DESC').AsFloat := StrToFloatDef(edtDesconto.Text, 0);
    LQuery.ParamByName('TOT').AsFloat := LTotal;
    LQuery.ExecSQL;

    // Obter ID do pedido gerado
    LQuery.SQL.Text := 'SELECT GEN_ID(GEN_PEDIDO_VENDA_ID, 0) FROM RDB$DATABASE';
    LQuery.Open;
    LPedidoId := LQuery.Fields[0].AsLargeInt;
    LQuery.Close;

    // Salvar itens do pedido
    for I := 1 to sgItens.RowCount - 1 do
    begin
      LCodigo := sgItens.Cells[1, I];
      LQtd := StrToFloatDef(sgItens.Cells[3, I], 0);
      LPreco := StrToFloatDef(
        StringReplace(StringReplace(sgItens.Cells[4, I], '.', '', [rfReplaceAll]), ',', '.', [rfReplaceAll]),
        0);

      // Buscar ID do produto pelo código
      LQuery.SQL.Text := 'SELECT ID FROM PRODUTO WHERE CODIGO = :COD OR CODIGO_BARRAS = :COD';
      LQuery.ParamByName('COD').AsString := LCodigo;
      LQuery.Open;

      if not LQuery.IsEmpty then
      begin
        LProdutoId := LQuery.FieldByName('ID').AsLargeInt;
        LQuery.Close;
        // Inserir item do pedido
        LQuery.SQL.Text :=
          'INSERT INTO ITEM_PEDIDO_VENDA (PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE, PRECO_UNITARIO, TOTAL) ' +
          'VALUES (:PEDIDO, :PROD, :QTD, :PRECO, :TOTAL)';
        LQuery.ParamByName('PEDIDO').AsLargeInt := LPedidoId;
        LQuery.ParamByName('PROD').AsLargeInt := LProdutoId;
        LQuery.ParamByName('QTD').AsFloat := LQtd;
        LQuery.ParamByName('PRECO').AsFloat := LPreco;
        LQuery.ParamByName('TOTAL').AsFloat := LQtd * LPreco;
        LQuery.ExecSQL;
      end
      else
        LQuery.Close;
    end;

    // Registrar movimento no caixa
    RegistrarMovimentoCaixa('V', LTotal, 'Venda PDV');

    FConexao.Confirmar;
    MessageDlg('Venda finalizada! Total: R$ ' + FormatFloat('#,##0.00', LTotal),
      mtInformation, [mbOK], 0);
    LimparVenda;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

procedure TfrmPDV.RegistrarMovimentoCaixa(ATipo: Char; AValor: Double; const ADesc: string);
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text :=
      'INSERT INTO MOVIMENTO_CAIXA (CAIXA_ID, TIPO, VALOR, DESCRICAO) ' +
      'VALUES (:CX, :TIPO, :VLR, :DESC)';
    LQuery.ParamByName('CX').AsLargeInt := FCaixaId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.ParamByName('VLR').AsFloat := AValor;
    LQuery.ParamByName('DESC').AsString := ADesc;
    LQuery.ExecSQL;
    FConexao.Confirmar;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      raise;
    end;
  end;
  LQuery.Free;
end;

procedure TfrmPDV.btnCancelarItemClick(Sender: TObject);
var
  I: Integer;
begin
  if (sgItens.Row < 1) or (sgItens.RowCount <= 1) then Exit;
  for I := sgItens.Row to sgItens.RowCount - 2 do
    sgItens.Rows[I].Assign(sgItens.Rows[I + 1]);
  sgItens.RowCount := sgItens.RowCount - 1;
  RecalcularTotais;
end;

procedure TfrmPDV.btnCancelarVendaClick(Sender: TObject);
begin
  if sgItens.RowCount <= 1 then Exit;
  if MessageDlg('Cancelar a venda atual?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    LimparVenda;
end;

procedure TfrmPDV.btnSangriaClick(Sender: TObject);
var
  LValor: string;
begin
  if not InputQuery('Sangria de Caixa', 'Valor da sangria:', LValor) then Exit;
  if StrToFloatDef(LValor, 0) <= 0 then
  begin
    MessageDlg('Valor inválido.', mtWarning, [mbOK], 0);
    Exit;
  end;
  try
    RegistrarMovimentoCaixa('S', StrToFloatDef(LValor, 0), 'Sangria');
    MessageDlg('Sangria registrada: R$ ' + LValor, mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPDV.btnSuprimentoClick(Sender: TObject);
var
  LValor: string;
begin
  if not InputQuery('Suprimento de Caixa', 'Valor do suprimento:', LValor) then Exit;
  if StrToFloatDef(LValor, 0) <= 0 then
  begin
    MessageDlg('Valor inválido.', mtWarning, [mbOK], 0);
    Exit;
  end;
  try
    RegistrarMovimentoCaixa('E', StrToFloatDef(LValor, 0), 'Suprimento');
    MessageDlg('Suprimento registrado: R$ ' + LValor, mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmPDV.btnFecharCaixaClick(Sender: TObject);
var
  LQuery: TSQLQuery;
  LSaldo: Double;
begin
  if MessageDlg('Fechar o caixa?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;

    // Calcular valor de fechamento
    LQuery.SQL.Text :=
      'SELECT COALESCE(C.VALOR_ABERTURA, 0) + ' +
      'COALESCE((SELECT SUM(CASE WHEN MC.TIPO IN (''V'',''E'') THEN MC.VALOR ELSE -MC.VALOR END) ' +
      'FROM MOVIMENTO_CAIXA MC WHERE MC.CAIXA_ID = C.ID), 0) AS SALDO ' +
      'FROM CAIXA C WHERE C.ID = :CX';
    LQuery.ParamByName('CX').AsLargeInt := FCaixaId;
    LQuery.Open;

    LSaldo := LQuery.FieldByName('SALDO').AsFloat;
    if LQuery.Active then
      LQuery.Close;

    LQuery.SQL.Text :=
      'UPDATE CAIXA SET STATUS = ''F'', DATA_FECHAMENTO = CURRENT_TIMESTAMP, ' +
      'VALOR_FECHAMENTO = :VLR WHERE ID = :CX';
    LQuery.ParamByName('VLR').AsFloat := LSaldo;
    LQuery.ParamByName('CX').AsLargeInt := FCaixaId;
    LQuery.ExecSQL;
    FConexao.Confirmar;

    MessageDlg('Caixa fechado! Saldo: R$ ' + FormatFloat('#,##0.00', LSaldo),
      mtInformation, [mbOK], 0);
    Close;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

procedure TfrmPDV.LimparVenda;
begin
  sgItens.RowCount := 1;
  edtCodigo.Clear;
  edtDesconto.Text := '0,00';
  edtRecebido.Clear;
  lblProdutoDesc.Caption := '';
  lblSubtotalValor.Caption := 'R$ 0,00';
  lblTotalValor.Caption := 'R$ 0,00';
  lblTrocoValor.Caption := 'R$ 0,00';
  lblItensQtd.Caption := '0';
  cmbFormaPag.ItemIndex := -1;
  Inc(FVendaNumero);
  edtCodigo.SetFocus;
end;

end.
