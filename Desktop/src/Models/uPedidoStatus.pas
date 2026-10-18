unit uPedidoStatus;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 3 - Produção
  ------------------------------------------------------------
  Máquina de estados do PEDIDO_VENDA (coluna STATUS CHAR(1)).

    'P'  Pendente      criado, aguardando produção/faturamento
    'A'  Aprovado      liberado para produzir (legado)
    'E'  Em produção   possui mapa de produção ativo
    'D'  Produzido     produção concluída, pronto para faturar
    'F'  Faturado      nota de saída emitida
    'C'  Cancelado     pedido cancelado

  Unidade única para os códigos e as descrições (antes duplicados
  em uFrmListaPedidos, uFrmNFe, uFrmNotaSaida e uNotaSaidaService)
  e para as regras de transição/operação permitidas por status.

  Os códigos 'E' e 'D' foram acrescentados sem alterar os existentes,
  mantendo a compatibilidade com o módulo de vendas, PDV e NF-e.
  ============================================================ }

interface

uses
  SysUtils;

type
  EPedidoStatus = class(Exception);

  TPedidoStatus = (psPendente, psAprovado, psEmProducao, psProduzido,
    psFaturado, psCancelado);

const
  PEDIDO_STATUS_PENDENTE    = 'P';
  PEDIDO_STATUS_APROVADO    = 'A';
  PEDIDO_STATUS_EM_PRODUCAO = 'E';
  PEDIDO_STATUS_PRODUZIDO   = 'D';
  PEDIDO_STATUS_FATURADO    = 'F';
  PEDIDO_STATUS_CANCELADO   = 'C';

  { Transições válidas: origem -> destinos }
  TRANSICOES: array[TPedidoStatus] of string = (
    'AEFC', { psPendente   -> aprovado, em produção, faturado, cancelado }
    'EFC',  { psAprovado   -> em produção, faturado, cancelado          }
    'DFPC', { psEmProducao -> produzido, faturado, pendente, cancelado  }
    'FPC',  { psProduzido  -> faturado, pendente, cancelado             }
    'C',    { psFaturado   -> cancelado (com estorno)                   }
    ''      { psCancelado  -> final                                      }
  );

{ Converte entre código do banco e o tipo enumerado. }
function CodigoDoStatus(AStatus: TPedidoStatus): string;
function StatusDoCodigo(const ACodigo: string): TPedidoStatus;

{ Descrição para exibição. DescricaoDoStatus aceita o código cru
  (inclusive desconhecido) e devolve um texto amigável. }
function DescricaoDoStatus(const ACodigo: string): string;
function DescricaoDoStatusEnum(AStatus: TPedidoStatus): string;

{ Fragmento SQL que traduz o código do status do pedido em texto de
  exibição, gerado a partir das mesmas descrições acima. Use-o em
  grids/relatórios para manter um único padrão de rótulo:
      SqlCaseStatusPedido('PV.STATUS') + ' AS STATUS_DESC ' }
function SqlCaseStatusPedido(const ACampo: string): string;

function CodigoValido(const ACodigo: string): Boolean;

{ Regras de transição. TransicaoPermitida aceita ADe = APara.
  ValidarTransicao levanta EPedidoStatus quando a transição é inválida. }
function TransicaoPermitida(const ADe, APara: string): Boolean;
procedure ValidarTransicao(const ADe, APara: string);

{ Operações permitidas por status (usadas pelos serviços). }
function PodeGerarMapa(const ACodigo: string): Boolean;
function PodeCancelar(const ACodigo: string): Boolean;
function PodeFaturar(const ACodigo: string): Boolean;
function PodeConcluirProducao(const ACodigo: string): Boolean;

implementation

function CodigoDoStatus(AStatus: TPedidoStatus): string;
begin
  case AStatus of
    psPendente:    Result := PEDIDO_STATUS_PENDENTE;
    psAprovado:    Result := PEDIDO_STATUS_APROVADO;
    psEmProducao:  Result := PEDIDO_STATUS_EM_PRODUCAO;
    psProduzido:   Result := PEDIDO_STATUS_PRODUZIDO;
    psFaturado:    Result := PEDIDO_STATUS_FATURADO;
    psCancelado:   Result := PEDIDO_STATUS_CANCELADO;
  else
    Result := '';
  end;
end;

function StatusDoCodigo(const ACodigo: string): TPedidoStatus;
var
  LCodigo: string;
begin
  Result := psPendente;
  LCodigo := UpCase(Trim(ACodigo));
  if LCodigo = '' then
    Exit;
  case LCodigo[1] of
    'P': Result := psPendente;
    'A': Result := psAprovado;
    'E': Result := psEmProducao;
    'D': Result := psProduzido;
    'F': Result := psFaturado;
    'C': Result := psCancelado;
  end;
end;

function DescricaoDoStatusEnum(AStatus: TPedidoStatus): string;
begin
  case AStatus of
    psPendente:    Result := 'Pendente';
    psAprovado:    Result := 'Aprovado';
    psEmProducao:  Result := 'Em produção';
    psProduzido:   Result := 'Produzido';
    psFaturado:    Result := 'Faturado';
    psCancelado:   Result := 'Cancelado';
  else
    Result := 'Desconhecido';
  end;
end;

function DescricaoDoStatus(const ACodigo: string): string;
var
  LCodigo: string;
begin
  LCodigo := Trim(ACodigo);
  if LCodigo = '' then
    Exit('');
  case UpCase(LCodigo[1]) of
    'P': Result := 'Pendente';
    'A': Result := 'Aprovado';
    'E': Result := 'Em produção';
    'D': Result := 'Produzido';
    'F': Result := 'Faturado';
    'C': Result := 'Cancelado';
  else
    Result := LCodigo;
  end;
end;

function SqlCaseStatusPedido(const ACampo: string): string;
var
  LStatus: TPedidoStatus;
begin
  Result := 'CASE ' + ACampo;
  for LStatus := Low(TPedidoStatus) to High(TPedidoStatus) do
    Result := Result + ' WHEN ' + QuotedStr(CodigoDoStatus(LStatus)) +
      ' THEN ' + QuotedStr(DescricaoDoStatusEnum(LStatus));
  Result := Result + ' ELSE ' + ACampo + ' END';
end;

function CodigoValido(const ACodigo: string): Boolean;
var
  LCodigo: string;
begin
  LCodigo := UpCase(Trim(ACodigo));
  Result := (LCodigo = PEDIDO_STATUS_PENDENTE) or (LCodigo = PEDIDO_STATUS_APROVADO) or
            (LCodigo = PEDIDO_STATUS_EM_PRODUCAO) or (LCodigo = PEDIDO_STATUS_PRODUZIDO) or
            (LCodigo = PEDIDO_STATUS_FATURADO) or (LCodigo = PEDIDO_STATUS_CANCELADO);
end;

function TransicaoPermitida(const ADe, APara: string): Boolean;
var
  LDe, LPara: string;
begin
  LDe := UpCase(Trim(ADe));
  LPara := UpCase(Trim(APara));
  if (LDe = '') or (LPara = '') then
    Exit(False);
  if LDe = LPara then
    Exit(True);
  if not CodigoValido(LDe) or not CodigoValido(LPara) then
    Exit(False);
  Result := Pos(LPara, TRANSICOES[StatusDoCodigo(LDe)]) > 0;
end;

procedure ValidarTransicao(const ADe, APara: string);
begin
  if not TransicaoPermitida(ADe, APara) then
    raise EPedidoStatus.CreateFmt(
      'Transição de status do pedido não permitida: %s (%s) para %s (%s).',
      [DescricaoDoStatus(ADe), Trim(ADe), DescricaoDoStatus(APara), Trim(APara)]);
end;

function PodeGerarMapa(const ACodigo: string): Boolean;
begin
  Result := TransicaoPermitida(ACodigo, PEDIDO_STATUS_EM_PRODUCAO);
end;

function PodeCancelar(const ACodigo: string): Boolean;
begin
  Result := TransicaoPermitida(ACodigo, PEDIDO_STATUS_CANCELADO);
end;

function PodeFaturar(const ACodigo: string): Boolean;
begin
  Result := TransicaoPermitida(ACodigo, PEDIDO_STATUS_FATURADO);
end;

function PodeConcluirProducao(const ACodigo: string): Boolean;
begin
  Result := TransicaoPermitida(ACodigo, PEDIDO_STATUS_PRODUZIDO);
end;

end.
