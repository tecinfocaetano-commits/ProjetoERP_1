unit uFrmGradeQuantidades;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 2 - Diálogo: quantidades por tamanho

  Mostra a grade efetiva (tamanho + quantidade) de um item do
  pedido ou do mapa. A coluna do tamanho é fixa (não editável);
  somente a quantidade é digitada.

  Usado por:
    uFrmPedidoVenda  -> monta a grade do item antes de salvar
    uFrmMapaProducao -> edita a grade do item do mapa
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, Grids, uGrade;

type
  { TfrmGradeQuantidades }
  TfrmGradeQuantidades = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    sgTamanhos: TStringGrid;
    lblTotal: TLabel;
    btnOK: TBitBtn;
    btnCancelar: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure sgTamanhosEditingDone(Sender: TObject);
  private
    FExigirQuantidade: Boolean;
    function GetTamanhos: TGradeTamanhos;
    function TotalInformado: Double;
    procedure AtualizarTotal;
  public
    { ATitulo aparece no topo; AExigirQuantidade = True impede OK
      com todas as quantidades zeradas (usado no pedido). }
    procedure Carregar(const ATamanhos: TGradeTamanhos;
      const ATitulo: string; AExigirQuantidade: Boolean = True);
    property Tamanhos: TGradeTamanhos read GetTamanhos;
  end;

var
  frmGradeQuantidades: TfrmGradeQuantidades;

implementation

{$R *.lfm}

function TextoParaFloat(const ATexto: string): Double;
var
  LTexto: string;
begin
  Result := 0;
  LTexto := Trim(ATexto);
  if LTexto = '' then
    Exit;
  LTexto := StringReplace(LTexto, ' ', '', [rfReplaceAll]);
  try
    Result := StrToFloat(LTexto);
  except
    try
      Result := StrToFloat(StringReplace(LTexto, ',', '.', [rfReplaceAll]));
    except
      Result := 0;
    end;
  end;
end;

procedure TfrmGradeQuantidades.FormCreate(Sender: TObject);
begin
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  FExigirQuantidade := True;

  sgTamanhos.ColCount := 2;
  sgTamanhos.FixedCols := 1;     { coluna 0 = tamanho (não editável) }
  sgTamanhos.FixedRows := 1;
  sgTamanhos.RowCount := 2;
  sgTamanhos.DefaultRowHeight := 22;
  sgTamanhos.Options := [goFixedVertLine, goFixedHorzLine, goVertLine,
    goHorzLine, goEditing, goTabs, goThumbTracking];
  sgTamanhos.ColWidths[0] := 110;
  sgTamanhos.ColWidths[1] := 110;
  sgTamanhos.Cells[0, 0] := 'Tamanho';
  sgTamanhos.Cells[1, 0] := 'Quantidade';
  sgTamanhos.Cells[0, 1] := '';
  sgTamanhos.Cells[1, 1] := '0';
end;

procedure TfrmGradeQuantidades.Carregar(const ATamanhos: TGradeTamanhos;
  const ATitulo: string; AExigirQuantidade: Boolean);
var
  I: Integer;
  LQtd: Double;
begin
  FExigirQuantidade := AExigirQuantidade;
  lblTitulo.Caption := ATitulo;

  if Length(ATamanhos) = 0 then
  begin
    sgTamanhos.RowCount := 2;
    sgTamanhos.Cells[0, 1] := '';
    sgTamanhos.Cells[1, 1] := '0';
  end
  else
  begin
    sgTamanhos.RowCount := Length(ATamanhos) + 1;
    for I := 0 to High(ATamanhos) do
    begin
      sgTamanhos.Cells[0, I + 1] := ATamanhos[I].Tamanho;
      LQtd := ATamanhos[I].Quantidade;
      if LQtd > 0 then
        sgTamanhos.Cells[1, I + 1] := FormatFloat('0.####', LQtd)
      else
        sgTamanhos.Cells[1, I + 1] := '0';
    end;
  end;

  AtualizarTotal;
  if sgTamanhos.RowCount > 1 then
  begin
    sgTamanhos.Row := 1;
    sgTamanhos.Col := 1;
  end;
end;

function TfrmGradeQuantidades.GetTamanhos: TGradeTamanhos;
var
  I: Integer;
  LTam: string;
  LQtd: Double;
begin
  Result := nil;
  for I := 1 to sgTamanhos.RowCount - 1 do
  begin
    LTam := Trim(sgTamanhos.Cells[0, I]);
    if LTam = '' then
      Continue;

    LQtd := TextoParaFloat(sgTamanhos.Cells[1, I]);
    if LQtd < 0 then
      LQtd := 0;

    SetLength(Result, Length(Result) + 1);
    with Result[High(Result)] do
    begin
      Id := 0;
      Tamanho := LTam;
      Ordem := Length(Result) - 1;
      Quantidade := LQtd;
      Ativo := 'A';
    end;
  end;
end;

function TfrmGradeQuantidades.TotalInformado: Double;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to sgTamanhos.RowCount - 1 do
    if Trim(sgTamanhos.Cells[0, I]) <> '' then
      Result := Result + TextoParaFloat(sgTamanhos.Cells[1, I]);
end;

procedure TfrmGradeQuantidades.AtualizarTotal;
begin
  lblTotal.Caption := 'Total: ' + FormatFloat('#,##0.####', TotalInformado);
end;

procedure TfrmGradeQuantidades.sgTamanhosEditingDone(Sender: TObject);
begin
  AtualizarTotal;
end;

procedure TfrmGradeQuantidades.btnOKClick(Sender: TObject);
begin
  if FExigirQuantidade and (TotalInformado <= 0) then
  begin
    MessageDlg('Informe a quantidade de pelo menos um tamanho.',
      mtWarning, [mbOK], 0);
    sgTamanhos.SetFocus;
    Exit;
  end;
  ModalResult := mrOk;
end;

end.
