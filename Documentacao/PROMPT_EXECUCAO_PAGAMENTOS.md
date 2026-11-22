# PROMPT — Execução dos Pagamentos Reais no PDV (PIX PSP + TEF)

> **STATUS ATUALIZADO (21/11 noite):** decisões tomadas — PIX =
> **Mercado Pago**, cartão = **Cielo** (depois). Adapter
> `uPagamentoMercadoPago.pas` JÁ IMPLEMENTADO e registrado no
> factory; `uPagamentoTipos.pas` extraiu os tipos compartilhados;
> `PAGAMENTO.BANDEIRA` criada (migração 023); conciliação
> `GET /api/pdv/pagamentos` no ar; app tem seletor de bandeira
> (só p/ CARTAO) + botão "Já paguei — verificar". **Falta apenas:**
> credenciais sandbox MP do usuário → configurar PAG_MERCADOPAGO_*
> → implementar HMAC do webhook → testar PIX real. Depois Cielo.
>
> Prompt de execução para o próximo agente/sessão. O esqueleto
> (Fase 0) já está implementado e testado — este prompt cobre a
> Fase 1 (PIX real com sandbox) e a Fase 2 (TEF/adquirente).

---

```
CONTEXTO

ERP 2026 (Lazarus/FPC + Firebird 5 + API Horse :9000 + Android Gradle).
Repo: C:\Users\Charles\Documents\ProjetoERP_1 → GitHub privado
tecinfocaetano-commits/ProjetoERP_1, branch master.

O esqueleto de pagamentos eletrônicos JÁ EXISTE e está no ar
(marco 3.85/3.86):
- Banco\022_pdv_pagamentos.sql aplicada → tabela PAGAMENTO
  (PENDENTE/PROCESSANDO/APROVADO/RECUSADO/CANCELADO/EXPIRADO,
  IDEMPOTENCY_KEY única/empresa, PROVEDOR_TXID imutável, DADOS_JSON
  com o carrinho, PEDIDO_VENDA_ID preenchido só após aprovação).
- Desktop\src\Services\uPagamentoService.pas — TPaymentProvider
  abstrato + factory ProvedorPagamento (config PAG_PROVIDER,
  padrão SIMULADO que aprova ~8s) + finalização via TPDVService.
- API\src\Rotas\uRotasPDV.pas — POST /api/pdv/pagamentos/iniciar,
  GET /:id/status, POST /:id/cancelar, POST /webhook (pública,
  auth por PAG_WEBHOOK_SECRET).
- App :pdv — tela "Aguardando pagamento" com polling 4s + QR payload
  + cancelar; cupom/PDF só após APROVADO.
- Smoke validado: webhook idempotente, venda auto-gerada (6462).

LEITURA OBRIGATÓRIA
- CHECKPOINT.md, Documentacao/PLANO_E_LOG.md (marcos 3.85 e 3.86)
- Documentacao/COMUNICACAO_AGENTES.md (canal vivo — registre-se)
- Documentacao/PROMPT_PAGAMENTOS_TEF_PIX.md (arquitetura alvo)
- Desktop/src/Services/uPagamentoService.pas
- API/src/Rotas/uRotasPDV.pas
- Android/android/pdv/README.md

REGRAS INEGOCIÁVEIS (as mesmas do projeto)
- Regras em Services compartilhados; SQL parametrizado; EMPRESA_ID em
  toda query; mutações transacionais + auditadas; sem segredos no git
  (credenciais PSP só em CONFIGURACAO chaves PAG_* ou env).
- Não tocar: bipe/**, fiscal (uConfiguracaoService, uNFeTest,
  uFrmConfiguracoes*, uACBrHelper), cenário 533/1014/3581.
- Commits em português + push a cada marco; atualizar
  COMUNICACAO_AGENTES.md a cada etapa e PLANO_E_LOG.md no fim.
- Não instalar dependências novas sem avisar o usuário.
- API na porta 9000: coordenar restart pelo canal antes de derrubar.

FASE 0 — DECISÕES DO USUÁRIO (bloqueante para adapters reais)
Antes de codar integração real, confirmar com o usuário:
1. PSP de PIX: Mercado Pago ou Asaas (recomendados, sandbox grátis).
   Pedir: ACCESS TOKEN de teste/sandbox + confirmação de webhook.
2. Adquirente de cartão: Cielo, Stone, Rede, Getnet, PagBank...
   Pedir: modelo da maquininha + credenciais de homologação/TEF.
3. Se o usuário não tiver credenciais ainda: seguir para o item
   "fallback" abaixo (tudo menos o adapter real).

FASE 1 — PIX REAL VIA PSP (sandbox)
Implementar UM adapter real escolhendo o PSP confirmado. Exemplo
Asaas (API REST simples, webhook nativo):

- Nova unit Desktop/src/Services/uPagamentoAsaas.pas herdando
  TPaymentProvider:
  * Codigo = 'ASAAS'
  * IniciarCobranca: POST /v3/payments {billingType:'PIX', value,
    externalReference=txid} com header access_token (de CONFIGURACAO
    PAG_ASAAS_APIKEY); devolve id em TxId, PIX copia-e-cola em
    QrPayload, link do QR em QrImagemUrl.
  * ConsultarStatus: GET /v3/payments/{id} → CONFIRMED→spAprovado,
    REFUSED/OVERDUE→spRecusado/spExpirado, demais→spProcessando.
  * Cancelar: POST /v3/payments/{id}/cancel (só PENDING/OVERDUE).
- Registrar 'ASAAS' em ProvedorPagamento (uPagamentoService.pas).
- Chaves CONFIGURACAO por empresa: PAG_PROVIDER=ASAAS,
  PAG_ASAAS_APIKEY, PAG_ASAAS_WEBHOOK_TOKEN.
- Webhook: adaptar PostPagamentoWebhook para validar o token do
  provedor (header/payment autenticado conforme doc do PSP) — manter
  compatibilidade com o formato atual {provedor,txid,status,assinatura}.
- Testes sandbox obrigatórios:
  * PIX aprovado no app do banco de teste → venda + cupom.
  * Webhook duplicado → aplicado:false, sem venda dupla.
  * QR expirado (configurar expiração curta) → EXPIRADO, sem venda.
  * Cancelar cobrança → CANCELADO, sem venda.
  * Idempotency key → sem duplicidade.
- App :pdv: exibir QR como imagem se QrImagemUrl vier (baixar bitmap)
  ou payload copia-e-cola selecionável (já existe); botão "Já paguei,
  verificar" para forçar consulta imediata além do polling.

FASE 1B — PROVAR O REGISTRY (multi-provedor)
Implementar um SEGUNDO PSP PIX (o outro da lista: se foi Asaas, fazer
Mercado Pago; se foi MP, fazer Asaas) para provar que trocar
PAG_PROVIDER basta — sem tocar em venda/cupom/app.

FASE 2 — TEF / MAQUININHA (somente após o usuário definir o
adquirente e modelo)
- Estudar a doc oficial do provedor (Sitef/PayGo SDK, ou SDK Android
  do fabricante para smart POS).
- Adapter TPaymentProvider específico (ex.: uTEFStone.pas) com fluxo
  assíncrono: IniciarCobranca dispara a cobrança no terminal;
  ConsultarStatus faz polling do resultado; Cancelar envia
  cancelamento.
- Se a maquininha for "dumb" (não integrada): manter o fallback de
  confirmação manual documentado — NÃO fingir integração.
- Nunca armazenar PAN/dados de cartão (PCI-DSS); só txid/status/valor.

FALLBACK SEM CREDENCIAIS (se o usuário adiar a escolha)
- App: para PIX mostrar QR fake já funciona; adicionar botão
  "Já paguei, verificar" + mensagem clara "MODO SIMULAÇÃO".
- Desktop PDV: avaliar mesma máquina de estados para NFC-e/TEF
  futuro — apenas documentação, sem implementação.
- Relatório de conciliação: endpoint/listagem de PAGAMENTO por
  status/período (GET /api/pdv/pagamentos?status=&de=&ate=) — útil
  desde já e independente de PSP.

TESTE NO CELULAR (Samsung A55, adb Wi-Fi 192.168.100.126:43511)
1. adb reverse tcp:9000 tcp:9000 + URL http://127.0.0.1:9000 no login.
2. Venda → forma PIX → "Confirmar pagamento" → tela de espera.
3. No PSP sandbox, aprovar o PIX (ou aguardar SIMULADO ~8s).
4. Cupom/PDF deve aparecer só após APROVADO.
5. Repetir com cancelamento e com expiração.
6. Conferir no banco: PAGAMENTO + PEDIDO_VENDA + MOVIMENTO_CAIXA
   consistentes, uma única venda por cobrança.

ENTREGÁVEIS
- Adapter(s) real(is) + registro no factory + chaves documentadas.
- Testes sandbox documentados (com prints/logs, sem segredos).
- Atualização README :pdv, PLANO_E_LOG, COMUNICACAO_AGENTES.
- Lista explícita: o que é real vs. o que segue simulado.
```

---

## Notas para o usuário

- **Antes de rodar este prompt**, defina: PSP de PIX (sugiro
  **Mercado Pago** ou **Asaas** — crie a conta de teste/sandbox e pegue
  o access token) e, se já tiver, a maquininha/adquirente de cartão.
- Com só o PSP de PIX definido, o agente entrega a **Fase 1 + 1B**
  (dois adapters provando o registry) e deixa TEF para depois.
- O APK atual já tem a tela de espera funcionando com o SIMULADO —
  dá para testar o fluxo visual no celular agora, sem credencial.
