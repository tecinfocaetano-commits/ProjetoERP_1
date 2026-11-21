# PROMPT — Integração de Pagamentos no PDV (TEF + PIX confirmado)

> Cole o bloco abaixo em uma nova sessão de agente. Ele foi preparado para
> ser executado por qualquer agente que assuma a tarefa. A tarefa é complexa:
> envolve pagamentos reais, certificação e segurança — **não execute em
> produção sem autorização explícita do usuário**.

---

```
CONTEXTO DO PROJETO

Você é um agente especialista em um ERP brasileiro em produção:
- Repositório: C:\Users\Charles\Documents\ProjetoERP_1 (GitHub privado:
  tecinfocaetano-commits/ProjetoERP_1, branch master)
- Stack: Lazarus/Free Pascal + Firebird 5.0, REST API (Horse) na porta 9000,
  clientes Android (módulos Gradle em Android/android: :app, :bipe, :pdv)
- App PDV mobile: módulo :pdv (Java), já funcional para vendas à vista com
  pagamento manual. O cupom/PDF só é gerado depois da confirmação.

LEITURA OBRIGATÓRIA ANTES DE COMEÇAR
- CHECKPOINT.md
- Documentacao/PLANO_E_LOG.md (último marco)
- Documentacao/COMUNICACAO_AGENTES.md (canal entre agentes — registre-se lá)
- Documentacao/INSTRUCOES_AGENTE.md
- Android/android/pdv/README.md
- Desktop/src/Services/uPDVService.pas
- API/src/Rotas/uRotasPDV.pas
- API/src/Rotas/uMiddlewareSessao.pas

REGRAS INEGOCIÁVEIS
- Regras de negócio ficam em Services compartilhados (Desktop/src/Services),
  nunca duplicadas em rotas API ou em Activities Android.
- SQL sempre parametrizado (ParamByName), isolamento por EMPRESA_ID em toda
  query, mutações transacionais (IniciarTransacao/Confirmar/Cancelar) e
  auditadas (LogOperacao/RegistrarAuditoria).
- Nunca commitar segredos: credenciais de PSP/adquirente ficam em
  CONFIGURACAO ou variáveis de ambiente, jamais em código ou docs.
- Não instalar dependências novas (Gradle/npm/etc.) sem avisar o usuário.
- Não tocar em: Android/android/bipe/**, arquivos fiscais
  (uConfiguracaoService.pas, uNFeTest.pas, uFrmConfiguracoes.*,
  uACBrHelper.pas), nem no cenário fiscal talão 533/mapa 1014/pedido 3581.
- Commits em português com o trailer Devin; push ao final de cada marco.
- Atualizar COMUNICACAO_AGENTES.md a cada marco e PLANO_E_LOG.md no fim.

OBJETIVO

Evoluir o PDV para pagamentos eletrônicos REAIS, substituindo a confirmação
manual atual ("Aprovado — gerar cupom") por confirmação automática:

1. CARTÃO (TEF): a venda só é registrada quando a maquininha/terminal
   APROVAR a transação.
2. PIX: a venda só é registrada quando o PSP confirmar o recebimento
   (webhook ou polling). QR expira/cancela → venda não é criada.
3. DINHEIRO: comportamento atual mantido (confirmação direta).
4. Em TODOS os casos de falha/recusa/cancelamento/expiração: nenhuma
   PEDIDO_VENDA, nenhum MOVIMENTO_CAIXA, nenhum cupom é gerado.
5. Idempotência: retry, webhook duplicado ou timeout NUNCA pode gerar
   venda/cupom/movimento duplicado.

ARQUITETURA SUGERIDA (decida e documente desvios)

A) Máquina de estados de pagamento (tabela nova PAGAMENTO ou colunas em
   PEDIDO_VENDA — avaliar o que o schema comporta sem breaking change;
   se criar tabela, documentar migração para Firebird):
   PENDENTE → PROCESSANDO → APROVADO | RECUSADO | CANCELADO | EXPIRADO

B) Camada de adaptadores provider-neutral em Desktop/src/Services:
   interface IPaymentProvider com operações IniciarCobranca,
   ConsultarStatus, Cancelar. Implementações concretas por provedor
   (ex.: uPagamentoAsaas.pas, uPagamentoMercadoPago.pas,
   uPagamentoEfí.pas, uTEFSitef.pas, uTEFPayGo.pas).
   A rota API e o app Android NUNCA falam direto com o PSP.

C) Novos endpoints na API (estender uRotasPDV.pas — coordenar no canal):
   - POST /api/pdv/pagamentos/iniciar   { pedido_id?, itens, forma_id, valor }
     → cria cobrança pendente e retorna instruções (link/QR/status)
   - GET  /api/pdv/pagamentos/{id}/status → estado atual
   - POST /api/pdv/pagamentos/{id}/cancelar
   - POST /api/pdv/pagamentos/webhook/{provedor} → confirmação assíncrona
     (validar assinatura do PSP! SEM autenticação JWT — o PSP não tem token;
      usar segredo compartilhado/assinatura do provedor)
   - POST /api/pdv/vendas continua existindo para DINHEIRO e como
     "finalizar venda de pagamento já aprovado" (reutilizar TPDVService)

D) App Android :pdv:
   - Tela "Aguardando pagamento" com polling de status (a cada 3-5s)
     ou deep link/webhook refletido via polling.
   - Exibir QR PIX (gerar bitmap a partir do payload EMV/BR Code —
     pode usar biblioteca ZXing core já presente no projeto, sem dep nova).
   - Timeout/expiração com botão "Cancelar cobrança" e "Tentar novamente".
   - Nunca gerar cupom/PDF fora do caminho APROVADO → POST venda → 201.

E) Segurança:
   - Credenciais do PSP por empresa em CONFIGURACAO (chaves prefixadas
     PAG_*, ex.: PAG_ASAAS_APIKEY) ou arquivo de ambiente cifrado.
   - Webhook SEMPRE validado (assinatura HMAC/token do PSP).
   - Valores monetários em CENTAVOS/inteiro no contrato com o PSP;
     conversão só na borda, com teste de arredondamento.
   - Logs de pagamento: NUNCA registrar PAN/dados de cartão; só
     transaction id, status e valor.

PRINCIPAIS PROVEDORES A PREPARAR (pesquise APIs atuais antes de codar)

PIX (API-first, sandbox disponível — RECOMENDADO COMEÇAR POR AQUI):
- Mercado Pago (preferencial: boa doc, sandbox, QR dinâmico, webhooks)
- Asaas (sandbox, webhook, PIX + boleto + cartão)
- Efí/Gerencianet (Pix API oficial BACEN-style, webhooks)
- PagBank/PagSeguro, Cora, Sicoob/Sicredi (APIs próprias ou via PSP)
Cartão online (se o PDV um dia vender por link): Mercado Pago, Asaas.

TEF presencial (depende de contrato com adquirente — NÃO implementar sem
modelo de terminal definido; deixar adapter stub + documentação):
- Stone, Getnet (Santander), Rede, Cielo, PagSeguro/PagBank maquininha,
  Ton/InfinitePay — cada um tem SDK/próprio protocolo (alguns via TEF
  Sitef/PayGo que exigem homologação no TEF do adquirente)
- Alternativa realista fase 1: maquininha "smart" com app do banco —
  manter confirmação manual atual como fallback declarado.

FASES SUGERIDAS
Fase 0 — Descoberta: perguntar ao usuário QUAL provedor/PSP e QUAL
         maquininha o cliente usa; obter credenciais de sandbox.
         Sem isso, implementar apenas o esqueleto (interface + stub
         SIMULADO para testes, claramente marcado como fake).
Fase 1 — PIX via PSP com sandbox: iniciar cobrança → QR → webhook/
         polling → APROVADO → venda+cupom. Homologar expiração/cancelamento.
Fase 2 — TEF/adquirente escolhido: adapter real, conforme documentação
         do provedor; manter stub SIMULADO para CI/testes.
Fase 3 — Relatórios: conciliação PSP × MOVIMENTO_CAIXA, estorno/chargeback.

TESTES OBRIGATÓRIOS (banco de teste/sandbox apenas)
- Aprovação PIX → venda criada 1x → cupom gerado.
- Webhook duplicado → venda NÃO duplica (idempotency key).
- QR expirado → nenhum registro de venda.
- Cartão recusado → nenhum registro; operador pode trocar forma.
- Falha de rede no meio → retomada sem duplicidade.
- Dinheiro continua funcionando exatamente como hoje.

ENTREGÁVEIS
- Código + migração de banco documentada (se houver).
- Atualização de README do :pdv, PLANO_E_LOG.md, COMUNICACAO_AGENTES.md.
- Lista explícita do que é real vs. stub/simulado.
- Nenhum segredo commitado.
```

---

## Notas para o usuário (fora do prompt)

- **Fase 0 é indispensável:** antes de qualquer código real, precisamos
  saber qual banco/PSP você usa (recomendação: Mercado Pago ou Asaas para
  PIX — ambos têm sandbox gratuito) e qual maquininha (Stone, Cielo, Rede,
  PagBank...). Sem isso, o agente só consegue entregar o esqueleto com
  adaptador simulado.
- O esqueleto (máquina de estados + endpoints + tela de espera + stub
  SIMULADO) **pode ser implementado já**, sem credenciais — quer que eu
  peça a um agente para fazer essa Fase 0+esqueleto agora?
