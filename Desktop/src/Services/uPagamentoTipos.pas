unit uPagamentoTipos;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Tipos base do sistema de pagamentos eletronicos
  ------------------------------------------------------------
  Separado de uPagamentoService para que os adapters de provedor
  (uPagamentoMercadoPago, futuros uPagamentoAsaas/uTEF*) nao criem
  referencia circular: eles implementam TPaymentProvider daqui.
  ============================================================ }

interface

type
  { Status possiveis de PAGAMENTO.STATUS (espelha CK_PAG_STATUS). }
  TStatusPagamento = (
    spPendente, spProcessando, spAprovado, spRecusado,
    spCancelado, spExpirado);

  { Dados que o provedor devolve ao iniciar a cobranca. }
  TProviderCobranca = record
    TxId: string;
    QrPayload: string;
    QrImagemUrl: string;
    Instrucoes: string;
    { Bandeira do cartao quando o PSP/adquirente a informa
      (VISA/MASTERCARD/ELO/AMEX/OUTRO). Vazio para PIX. }
    Bandeira: string;
  end;

  { Contrato de um provedor de pagamento. Implementacoes reais
    (MercadoPago, Asaas, EFI, TEF...) herdam esta classe; a escolha
    do provedor ativo e por configuracao, nunca fixa no codigo. }
  TPaymentProvider = class
  public
    { Identificador estavel usado em PAGAMENTO.PROVEDOR. }
    function Codigo: string; virtual; abstract;

    { Inicia a cobranca no PSP. ADadosJson e o payload normalizado
      da intencao (valor, itens, descricao). }
    procedure IniciarCobranca(const ADadosJson: string;
      out ACobranca: TProviderCobranca); virtual; abstract;

    { Consulta o estado atual da cobranca no PSP. }
    function ConsultarStatus(const ATxId: string): TStatusPagamento;
      virtual; abstract;

    { Cancela/estorna a cobranca pendente. Implementacao padrao
      nao faz nada (provedores sem cancelamento remoto). }
    procedure Cancelar(const ATxId: string); virtual;
  end;

{ StatusPagamento -> texto gravado em PAGAMENTO.STATUS. }
function StatusParaTexto(AStatus: TStatusPagamento): string;

{ Texto -> TStatusPagamento (usado por webhook/rotas). }
function TextoParaStatus(const ATexto: string): TStatusPagamento;

implementation

uses
  SysUtils;

const
  STATUS_PENDENTE   = 'PENDENTE';
  STATUS_PROCESSANDO= 'PROCESSANDO';
  STATUS_APROVADO   = 'APROVADO';
  STATUS_RECUSADO   = 'RECUSADO';
  STATUS_CANCELADO  = 'CANCELADO';
  STATUS_EXPIRADO   = 'EXPIRADO';

procedure TPaymentProvider.Cancelar(const ATxId: string);
begin
  { provedores sem cancelamento remoto herdam este no-op }
end;

function StatusParaTexto(AStatus: TStatusPagamento): string;
begin
  case AStatus of
    spPendente:     Result := STATUS_PENDENTE;
    spProcessando:  Result := STATUS_PROCESSANDO;
    spAprovado:     Result := STATUS_APROVADO;
    spRecusado:     Result := STATUS_RECUSADO;
    spCancelado:    Result := STATUS_CANCELADO;
    spExpirado:     Result := STATUS_EXPIRADO;
  else
    Result := STATUS_PENDENTE;
  end;
end;

function TextoParaStatus(const ATexto: string): TStatusPagamento;
begin
  if SameText(ATexto, STATUS_PROCESSANDO) then
    Result := spProcessando
  else if SameText(ATexto, STATUS_APROVADO) then
    Result := spAprovado
  else if SameText(ATexto, STATUS_RECUSADO) then
    Result := spRecusado
  else if SameText(ATexto, STATUS_CANCELADO) then
    Result := spCancelado
  else if SameText(ATexto, STATUS_EXPIRADO) then
    Result := spExpirado
  else
    Result := spPendente;
end;

end.
