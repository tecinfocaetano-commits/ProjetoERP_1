# PROMPT DE CONTINUIDADE — PDV Mobile + Pagamentos Eletrônicos

> Cole o bloco abaixo em uma nova sessão após reiniciar a máquina.
> Captura o estado exato do trabalho em 21/11/2026.

---

```
CONTEXTO DO PROJETO

Você é um agente continuando o ERP 2026:
- Repositório: C:\Users\Charles\Documents\ProjetoERP_1
  (GitHub privado: tecinfocaetano-commits/ProjetoERP_1, branch master)
- Stack: Lazarus/FPC 3.2.2 + Firebird 5.0 (Banco\DADOS.FDB) +
  API REST Horse na porta 9000 (API\bin\ERP2026API.exe) +
  Android Gradle (Android\android: módulos :app, :bipe, :pdv)
- Celular de teste: Samsung A55 via adb Wi-Fi
  (192.168.100.126:43511; também aparece como USB RQCX40A28AD)

LEITURA OBRIGATÓRIA ANTES DE QUALQUER COISA
1. CHECKPOINT.md — estado consolidado (últimos marcos 3.86/3.85)
2. Documentacao/PLANO_E_LOG.md — marcos 3.82 a 3.86
3. Documentacao/COMUNICACAO_AGENTES.md — canal vivo com o outro
   agente (ele trabalha no desktop/testes; coordenar sempre)
4. Documentacao/INSTRUCOES_AGENTE.md
5. Android/android/pdv/README.md
6. Documentacao/PROMPT_EXECUCAO_PAGAMENTOS.md — plano das próximas
   fases de pagamento (Fase 1 PIX real, Fase 2 TEF)
7. Documentacao/PROMPT_PAGAMENTOS_TEF_PIX.md — arquitetura alvo

O QUE JÁ ESTÁ PRONTO E TESTADO (não refazer)

App :pdv (com.example.erp2026_pdv) — PDV mobile completo:
- Login (URL + usuário + senha + empresa opcional)
- Caixa: status, abrir, fechar, suprimento, sangria
- Produtos: busca texto/código de barras/câmera ZXing
- Carrinho: quantidades, remover, desconto, total ao vivo
- DINHEIRO: POST /api/pdv/vendas direto, troco, cupom texto +
  PDF (CupomPdf.java) + compartilhar
- CARTÃO/PIX/outros: cobrança eletrônica —
  POST /api/pdv/pagamentos/iniciar → tela "Aguardando pagamento"
  (dialog_espera_pagamento.xml, polling 4s, QR/payload, botão
  "Cancelar cobrança") → GET .../status → APROVADO → cupom.
  RECUSADO/CANCELADO/EXPIRADO não geram venda nem cupom.
- APK instalado no Samsung (pdv-debug.apk)

Backend de pagamentos (esqueleto multi-provedor, marco 3.85):
- Banco\022_pdv_pagamentos.sql APLICADA → tabela PAGAMENTO
  (PENDENTE/PROCESSANDO/APROVADO/RECUSADO/CANCELADO/EXPIRADO,
  IDEMPOTENCY_KEY única/empresa, PROVEDOR_TXID imutável,
  DADOS_JSON=carrinho, PEDIDO_VENDA_ID só após aprovação)
- Desktop\src\Services\uPagamentoService.pas — TPaymentProvider
  abstrato + ProvedorPagamento (config PAG_PROVIDER, padrão
  SIMULADO que aprova ~8s — SÓ TESTE, sem PSP real)
- API\src\Rotas\uRotasPDV.pas — iniciar/status/cancelar/webhook
  (webhook pública, auth por PAG_WEBHOOK_SECRET em CONFIGURACAO)
- Validado ao vivo: PIX SIMULADO → APROVADO gerou vendas 6383,
  6384, 6462; webhook duplicado = aplicado:false (idempotente)

API estável (marco 3.86, outro agente): pool corrigido — conexão
viva volta ao pool, ping real, health 503 se banco falhar.
60/60 logins concorrentes OK. API rodando PID 18576 na :9000.

COMO SUBIR O AMBIENTE APÓS REINICIAR
1. git pull origin master (ou git status para conferir)
2. Subir Firebird (serviço) e a API:
   cd C:\Users\Charles\Documents\ProjetoERP_1
   API\bin\ERP2026API.exe   (deixar rodando em background)
   Verificar: curl http://localhost:9000/api/health
   → {"status":"ok","banco":"ok",...}
3. Celular: adb connect 192.168.100.126:43511
   adb reverse tcp:9000 tcp:9000
   No app: servidor http://127.0.0.1:9000, admin/senha do usuário,
   empresa_id=1

PENDÊNCIAS IMEDIATAS (em ordem)

A) ~~TESTAR PIX SIMULADO~~ — FEITO (21/11): fluxo completo validado
   no Samsung (venda → PIX → espera → cupom) + bug crítico de
   idempotência corrigido (`b3dc8b6`). Bandeiras de cartão e botão
   "Já paguei — verificar" também entregues (`5686a72`).

B) DECISÃO JÁ TOMADA (21/11): PIX = **Mercado Pago**, cartão =
   **Cielo** (depois do PIX). Adapter `uPagamentoMercadoPago.pas`
   JÁ IMPLEMENTADO e registrado no factory (`PAG_PROVIDER`).
   **PENDENTE — só falta o usuário criar as credenciais sandbox:**
   conta de desenvolvedor MP → aplicação → credenciais `TEST-`
   (access token) + conta de comprador de teste. Quando ele tiver:
   1. Gravar `PAG_MERCADOPAGO_ACCESS_TOKEN`,
      `PAG_MERCADOPAGO_PAYER_EMAIL`, `PAG_PROVIDER=MERCADOPAGO`
      em CONFIGURACAO (empresa 1) — NUNCA commitar o token.
   2. Implementar validação HMAC do webhook (`x-signature` MP).
   3. Testar PIX real ponta a ponta no Samsung (QR verdadeiro,
      webhook confirma → cupom sem polling).
   4. Depois: Cielo/TEF (fase posterior, precisa contrato).
   Em produção: conta PJ dedicada + HTTPS + rotina de estorno.

C) Fallback SEM credenciais — ENTREGUE (`5686a72`): conciliação
   `GET /api/pdv/pagamentos?status=&de=&ate=` + botão "Já paguei —
   verificar" no app. Nada mais a fazer aqui.

REGRAS INEGOCIÁVEIS
- Regras de negócio em Services; SQL parametrizado; EMPRESA_ID
  em toda query; mutações transacionais + auditadas; sem segredos
  no git (credenciais PSP só em CONFIGURACAO PAG_*).
- Não tocar: Android\android\bipe\**, arquivos fiscais
  (uConfiguracaoService, uNFeTest, uFrmConfiguracoes*,
  uACBrHelper), cenário fiscal talão 533/mapa 1014/pedido 3581.
- Coordenar restart da API :9000 pelo COMUNICACAO_AGENTES.md —
  o outro agente também a usa.
- Commits em português com trailer Devin; push a cada marco;
  atualizar COMUNICACAO_AGENTES.md a cada etapa.
- Não instalar dependências novas sem avisar o usuário.
- Baseline a manter: suíte desktop 385/385, builds Android OK.

TESTES RÁPIDOS DE API (após subir)
  curl http://localhost:9000/api/health
  TOKEN=$(curl -s -X POST http://localhost:9000/api/login
    -H "Content-Type: application/json"
    -d '{"login":"admin","senha":"<senha>","empresa_id":1}'
    | sed 's/.*"token" *: *"\([^"]*\)".*/\1/')
  curl -s http://localhost:9000/api/pdv/status -H "Authorization: Bearer $TOKEN"
  curl -s -X POST http://localhost:9000/api/pdv/pagamentos/iniciar
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json"
    -d '{"itens":[{"produto_id":1,"quantidade":1}],
         "forma_pagamento_id":4,"idempotency_key":"CONT-$RANDOM",
         "tipo_cobranca":"PIX"}'
  # aguardar ~8s e consultar:
  curl -s http://localhost:9000/api/pdv/pagamentos/<id>/status
    -H "Authorization: Bearer $TOKEN"
```

---

## Notas rápidas pós-reboot

- Senha do `admin`: a de desenvolvimento documentada no repositório
  (não colar em docs públicos).
- Se o adb Wi-Fi cair: `adb kill-server && adb start-server`,
  reconectar pelo USB ou `adb connect` no IP do celular.
- `tmp_shots/` é untracked (screenshots de teste) — ignorar.
- Fila offline do Bipe e demais apps não são afetados pelo reboot.
