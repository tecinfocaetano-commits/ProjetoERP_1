unit uGeoCombos;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Helper de UI: combos geográficos
  ------------------------------------------------------------
  Preenche e lê os combos de País / Estado / Cidade usados em
  CLIENTE e FORNECEDOR. As consultas ficam nos services
  (uPaisService / uEstadoService / uCidadeService); aqui só há
  a cola com TComboBox.

  Convenção dos itens: o ID vai em Items.Objects (PtrInt) e o
  texto é o nome (estado no formato "UF - Nome").
  ============================================================ }

interface

uses
  Classes, SysUtils, StdCtrls;

{ Preenche o combo de países. Se ASelecionarId > 0 tenta selecioná-lo;
  senão seleciona o primeiro (Brasil na semente). }
procedure CarregarComboPaises(ACombo: TComboBox; ASelecionarId: Int64 = 0);

procedure CarregarComboEstados(ACombo: TComboBox; APaisId: Int64;
  ASelecionarId: Int64 = 0);

procedure CarregarComboCidades(ACombo: TComboBox; AEstadoId: Int64;
  ASelecionarId: Int64 = 0);

{ ID selecionado no combo (0 = nada / texto livre). }
function IdDoCombo(ACombo: TComboBox): Int64;

{ UF do estado selecionado ("SP" em "SP - São Paulo"). }
function UfDoComboEstado(ACombo: TComboBox): string;

function SelecionarItemPorId(ACombo: TComboBox; AId: Int64): Boolean;

{ Seleciona país -> estado -> cidade a partir do CIDADE_ID gravado.
  O chamador deve proteger os OnChange com um flag (evita recargas). }
procedure SelecionarCidade(AComboPais, AComboEstado, AComboCidade: TComboBox;
  ACidadeId: Int64);

{ Para registros antigos (só CIDADE texto, sem CIDADE_ID): mostra o
  texto como item livre, sem ID. }
procedure MostrarCidadeLivre(ACombo: TComboBox; const ANome: string);

implementation

uses
  SQLDB, uPaisService, uEstadoService, uCidadeService, uCidade, uEstado;

procedure CarregarComboPaises(ACombo: TComboBox; ASelecionarId: Int64);
var
  LService: TPaisService;
  LQuery: TSQLQuery;
begin
  ACombo.Items.BeginUpdate;
  try
    ACombo.Items.Clear;
    LService := TPaisService.Create;
    try
      LQuery := LService.BuscarTodos;
      try
        while not LQuery.EOF do
        begin
          ACombo.Items.AddObject(LQuery.FieldByName('NOME').AsString,
            TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
          LQuery.Next;
        end;
      finally
        LQuery.Close;
      end;
    finally
      LService.Free;
    end;
  finally
    ACombo.Items.EndUpdate;
  end;

  if not SelecionarItemPorId(ACombo, ASelecionarId) then
    if ACombo.Items.Count > 0 then
      ACombo.ItemIndex := 0;
end;

procedure CarregarComboEstados(ACombo: TComboBox; APaisId: Int64;
  ASelecionarId: Int64);
var
  LService: TEstadoService;
  LQuery: TSQLQuery;
begin
  ACombo.Items.BeginUpdate;
  try
    ACombo.Items.Clear;
    if APaisId > 0 then
    begin
      LService := TEstadoService.Create;
      try
        LQuery := LService.BuscarTodos(APaisId);
        try
          while not LQuery.EOF do
          begin
            ACombo.Items.AddObject(
              Trim(LQuery.FieldByName('UF').AsString) + ' - ' +
              LQuery.FieldByName('NOME').AsString,
              TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
            LQuery.Next;
          end;
        finally
          LQuery.Close;
        end;
      finally
        LService.Free;
      end;
    end;
  finally
    ACombo.Items.EndUpdate;
  end;

  ACombo.ItemIndex := -1;
  ACombo.Text := '';
  if ASelecionarId > 0 then
    SelecionarItemPorId(ACombo, ASelecionarId);
end;

procedure CarregarComboCidades(ACombo: TComboBox; AEstadoId: Int64;
  ASelecionarId: Int64);
var
  LService: TCidadeService;
  LQuery: TSQLQuery;
begin
  ACombo.Items.BeginUpdate;
  try
    ACombo.Items.Clear;
    if AEstadoId > 0 then
    begin
      LService := TCidadeService.Create;
      try
        LQuery := LService.BuscarTodos(AEstadoId);
        try
          while not LQuery.EOF do
          begin
            ACombo.Items.AddObject(LQuery.FieldByName('NOME').AsString,
              TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
            LQuery.Next;
          end;
        finally
          LQuery.Close;
        end;
      finally
        LService.Free;
      end;
    end;
  finally
    ACombo.Items.EndUpdate;
  end;

  ACombo.ItemIndex := -1;
  ACombo.Text := '';
  if ASelecionarId > 0 then
    SelecionarItemPorId(ACombo, ASelecionarId);
end;

function IdDoCombo(ACombo: TComboBox): Int64;
begin
  Result := 0;
  if (ACombo = nil) or (ACombo.ItemIndex < 0) then
    Exit;
  if ACombo.Items.Objects[ACombo.ItemIndex] <> nil then
    Result := PtrInt(ACombo.Items.Objects[ACombo.ItemIndex]);
end;

function UfDoComboEstado(ACombo: TComboBox): string;
begin
  Result := '';
  if (ACombo = nil) or (ACombo.ItemIndex < 0) then
    Exit;
  if Length(ACombo.Text) >= 2 then
    Result := Copy(ACombo.Text, 1, 2);
end;

function SelecionarItemPorId(ACombo: TComboBox; AId: Int64): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (ACombo = nil) or (AId <= 0) then
    Exit;
  for I := 0 to ACombo.Items.Count - 1 do
    if (ACombo.Items.Objects[I] <> nil) and
       (PtrInt(ACombo.Items.Objects[I]) = AId) then
    begin
      ACombo.ItemIndex := I;
      Result := True;
      Exit;
    end;
end;

procedure SelecionarCidade(AComboPais, AComboEstado, AComboCidade: TComboBox;
  ACidadeId: Int64);
var
  LCidadeService: TCidadeService;
  LEstadoService: TEstadoService;
  LCidade: TCidade;
  LEstado: TEstado;
begin
  if ACidadeId <= 0 then
    Exit;

  LCidade := nil;
  LEstado := nil;
  LCidadeService := TCidadeService.Create;
  try
    LCidade := LCidadeService.BuscarPorId(ACidadeId);
  finally
    LCidadeService.Free;
  end;
  if LCidade = nil then
    Exit;

  try
    LEstadoService := TEstadoService.Create;
    try
      LEstado := LEstadoService.BuscarPorId(LCidade.EstadoId);
    finally
      LEstadoService.Free;
    end;
    if LEstado = nil then
      Exit;

    try
      CarregarComboPaises(AComboPais, LEstado.PaisId);
      CarregarComboEstados(AComboEstado, LEstado.PaisId, LEstado.Id);
      CarregarComboCidades(AComboCidade, LEstado.Id, LCidade.Id);
    finally
      LEstado.Free;
    end;
  finally
    LCidade.Free;
  end;
end;

procedure MostrarCidadeLivre(ACombo: TComboBox; const ANome: string);
begin
  if (ACombo = nil) or (Trim(ANome) = '') then
    Exit;
  ACombo.Items.AddObject(Trim(ANome), nil);
  ACombo.ItemIndex := ACombo.Items.Count - 1;
end;

end.
