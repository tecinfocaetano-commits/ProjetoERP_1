unit uGrade;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 2 - Model: GRADE
  Grade = conjunto de tamanhos de um produto (calçado, confecção,
  grupo ou outro). O número de tamanhos é variável.

  GRADE         -> nome + tipo (CALCADO/CONFECCAO/GRUPO/OUTRO)
  GRADE_TAMANHO -> tamanhos da grade (ordem + ativo)
  Nas grades efetivas (ITEM_PEDIDO_GRADE / MAPA_PRODUCAO_ITEM_GRADE)
  cada tamanho carrega a sua QUANTIDADE.
  ============================================================ }

interface

type
  TGradeTamanho = record
    Id: Int64;
    Tamanho: string;
    Ordem: Integer;
    Quantidade: Double;   // usada só nas grades efetivas (pedido/mapa)
    Ativo: string;
  end;
  TGradeTamanhos = array of TGradeTamanho;

  TGrade = class
  private
    FId: Int64;
    FEmpresaId: Int64;
    FNome: string;
    FTipo: string;
    FAtivo: string;
    FObservacao: string;
    FTamanhos: TGradeTamanhos;
  public
    property Id: Int64 read FId write FId;
    property EmpresaId: Int64 read FEmpresaId write FEmpresaId;
    property Nome: string read FNome write FNome;
    property Tipo: string read FTipo write FTipo;
    property Ativo: string read FAtivo write FAtivo;
    property Observacao: string read FObservacao write FObservacao;
    property Tamanhos: TGradeTamanhos read FTamanhos write FTamanhos;
  end;

const
  GRADE_TIPOS: array[0..3] of string =
    ('CALCADO', 'CONFECCAO', 'GRUPO', 'OUTRO');

  GRADE_TIPOS_DESCRICAO: array[0..3] of string =
    ('Calçado', 'Confecção', 'Grupo', 'Outro');

function DescricaoTipoGrade(const ATipo: string): string;
function IndiceTipoGrade(const ATipo: string): Integer;
function TipoGradePorIndice(AIndice: Integer): string;

{ soma as quantidades de uma grade efetiva (total do item) }
function SomarQuantidades(const ATamanhos: TGradeTamanhos): Double;

implementation

function DescricaoTipoGrade(const ATipo: string): string;
var
  I: Integer;
begin
  for I := 0 to High(GRADE_TIPOS) do
    if ATipo = GRADE_TIPOS[I] then
    begin
      Result := GRADE_TIPOS_DESCRICAO[I];
      Exit;
    end;
  Result := 'Outro';
end;

function IndiceTipoGrade(const ATipo: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(GRADE_TIPOS) do
    if ATipo = GRADE_TIPOS[I] then
    begin
      Result := I;
      Exit;
    end;
  Result := High(GRADE_TIPOS);   // OUTRO
end;

function TipoGradePorIndice(AIndice: Integer): string;
begin
  if (AIndice >= 0) and (AIndice <= High(GRADE_TIPOS)) then
    Result := GRADE_TIPOS[AIndice]
  else
    Result := 'OUTRO';
end;

function SomarQuantidades(const ATamanhos: TGradeTamanhos): Double;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(ATamanhos) do
    Result := Result + ATamanhos[I].Quantidade;
end;

end.
