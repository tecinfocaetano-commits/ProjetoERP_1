unit uMapaProducaoStatus;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 3 - Produção
  ------------------------------------------------------------
  Máquina de estados do MAPA_PRODUCAO (coluna STATUS VARCHAR(20)).

    'ABERTO'             Aguardando início de produção
    'EM_PRODUCAO'        Em produção (talões gerados/iniciados)
    'CONCLUIDO'          Produção concluída
    'CANCELADO'          Mapa cancelado

  Unidade única para os códigos e as descrições (antes duplicados
  em uFrmMapaProducao e nas queries SQL) e para os fragmentos SQL
  de tradução de status em grids/relatórios.
  ============================================================ }

interface

uses
  SysUtils;

type
  EMapaStatus = class(Exception);

  TMapaStatus = (msAberto, msEmProducao, msConcluido, msCancelado);

const
  MAPA_STATUS_ABERTO       = 'ABERTO';
  MAPA_STATUS_EM_PRODUCAO  = 'EM_PRODUCAO';
  MAPA_STATUS_CONCLUIDO    = 'CONCLUIDO';
  MAPA_STATUS_CANCELADO    = 'CANCELADO';

{ Converte entre código do banco e o tipo enumerado. }
function CodigoDoStatus(AStatus: TMapaStatus): string;
function StatusDoCodigo(const ACodigo: string): TMapaStatus;

{ Descrição para exibição. DescricaoDoStatus aceita o código cru
  (inclusive desconhecido) e devolve um texto amigável. }
function DescricaoDoStatus(const ACodigo: string): string;
function DescricaoDoStatusEnum(AStatus: TMapaStatus): string;

{ Fragmento SQL que traduz o código do status do mapa em texto de
  exibição, gerado a partir das mesmas descrições acima. Use-o em
  grids/relatórios para manter um único padrão de rótulo:
      SqlCaseStatusMapa('M.STATUS') + ' AS STATUS_DESC ' }
function SqlCaseStatusMapa(const ACampo: string): string;

function CodigoValido(const ACodigo: string): Boolean;

implementation

function CodigoDoStatus(AStatus: TMapaStatus): string;
begin
  case AStatus of
    msAberto:       Result := MAPA_STATUS_ABERTO;
    msEmProducao:   Result := MAPA_STATUS_EM_PRODUCAO;
    msConcluido:    Result := MAPA_STATUS_CONCLUIDO;
    msCancelado:    Result := MAPA_STATUS_CANCELADO;
  else
    Result := '';
  end;
end;

function StatusDoCodigo(const ACodigo: string): TMapaStatus;
var
  LCodigo: string;
begin
  Result := msAberto;
  LCodigo := UpperCase(Trim(ACodigo));
  if LCodigo = '' then
    Exit;
  if LCodigo = MAPA_STATUS_ABERTO then
    Result := msAberto
  else if LCodigo = MAPA_STATUS_EM_PRODUCAO then
    Result := msEmProducao
  else if LCodigo = MAPA_STATUS_CONCLUIDO then
    Result := msConcluido
  else if LCodigo = MAPA_STATUS_CANCELADO then
    Result := msCancelado;
end;

function DescricaoDoStatusEnum(AStatus: TMapaStatus): string;
begin
  case AStatus of
    msAberto:       Result := 'Aberto';
    msEmProducao:   Result := 'Em produção';
    msConcluido:    Result := 'Concluído';
    msCancelado:    Result := 'Cancelado';
  else
    Result := 'Desconhecido';
  end;
end;

function DescricaoDoStatus(const ACodigo: string): string;
var
  LCodigo: string;
begin
  LCodigo := UpperCase(Trim(ACodigo));
  if LCodigo = '' then
    Exit('');
  if LCodigo = MAPA_STATUS_ABERTO then
    Result := 'Aberto'
  else if LCodigo = MAPA_STATUS_EM_PRODUCAO then
    Result := 'Em produção'
  else if LCodigo = MAPA_STATUS_CONCLUIDO then
    Result := 'Concluído'
  else if LCodigo = MAPA_STATUS_CANCELADO then
    Result := 'Cancelado'
  else
    Result := ACodigo;
end;

function SqlCaseStatusMapa(const ACampo: string): string;
var
  LStatus: TMapaStatus;
begin
  Result := 'CASE ' + ACampo;
  for LStatus := Low(TMapaStatus) to High(TMapaStatus) do
    Result := Result + ' WHEN ' + QuotedStr(CodigoDoStatus(LStatus)) +
      ' THEN ' + QuotedStr(DescricaoDoStatusEnum(LStatus));
  Result := Result + ' ELSE ' + ACampo + ' END';
end;

function CodigoValido(const ACodigo: string): Boolean;
var
  LCodigo: string;
begin
  LCodigo := UpperCase(Trim(ACodigo));
  Result := (LCodigo = MAPA_STATUS_ABERTO) or
            (LCodigo = MAPA_STATUS_EM_PRODUCAO) or
            (LCodigo = MAPA_STATUS_CONCLUIDO) or
            (LCodigo = MAPA_STATUS_CANCELADO);
end;

end.
