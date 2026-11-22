# PROMPT DE CONTINUIDADE — PDV Mobile + Pagamentos Eletrônicos

> Cole o bloco abaixo em uma nova sessão após reiniciar a máquina.
> Captura o estado exato do trabalho em 21/11/2026 (noite).

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
1. CHECKPOINT.md — estado consolidado (últimos marcos ~3.90)
2. Documentacao/PLANO_E_LOG.md — marcos 3.82 a 3.90
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

Backend de pagamentos (esqueleto multi-provedor, marcos 3.85/3.90):
- Banco\022_pdv_pagamentos.sql + 023_pdv_pagamento_bandeira.sql
  APLICADAS → tabela PAGAMENTO (PENDENTE/PROCESSANDO/APROVADO/
  RECUSADO/CANCELADO/EXPIRADO, IDEMPOTENCY_KEY única/empresa,
  PROVEDOR_TXID imutável, BANDEIRA p/ cartão, DADOS_JSON=carrinho,
  PEDIDO_VENDA_ID só após aprovação)
- Desktop\src\Services\uPagamentoTipos.pas — tipos/providers
  compartilhados (TStatusPagamento, TProviderCobranca, TPaymentProvider)
- Desktop\src\Services\uPagamentoService.pas — service + factory
  ProvedorPagamento (config PAG_PROVIDER, padrão SIMULADO ~8s)
- Desktop\src\Services\uPagamentoMercadoPago.pas — adapter PIX real
  (POST /v1/payments, QR point_of_interaction, cancel PUT;
  credenciais PAG_MERCADOPAGO_* em CONFIGURACAO; sem token = erro
  limpo; webhook HMAC ainda pendente)
- API\src\Rotas\uRotasPDV.pas — iniciar/status/cancelar/webhook +
  GET /api/pdv/pagamentos (conciliação c/ filtros)
- Validado: PIX SIMULADO → venda automática; idempotência e webhook
  duplicado OK; bandeira MASTERCARD persistida (pagamento 7→venda 6693);
  PAG_PROVIDER=MERCADOPAGO sem token → erro controlado
- BUG CRÍTICO JÁ CORRIGIDO (`b3dc8b6`): PEDIDO_VENDA_ID fora de
  transação era revertido → vendas duplicadas. Claim atômico
  APROVADO→PROCESSANDO + transação explícita. Lição: mutação sem
  transação explícita é revertida pelo pool da API.

API estável (marco 3.86, outro agente): pool corrigido — conexão
viva volta ao pool, ping real, health 503 se banco falhar.
60/60 logins concorrentes OK.

WATCHDOG DA API (marco novo, `7d0b7f5` — testado ao vivo):
- Atalho "ERP2026 API.lnk" na pasta Inicializar do Windows → API
  sobe no login do Windows (antes do ERP).
- Desktop\src\Utils\uApiSaude.pas + uFrmPrincipal: ao abrir o ERP,
  checa /api/health em background; se local caiu → pergunta e sobe
  API\bin\ERP2026API.exe (ShellExecute, poll até ~12s); se URL
  remota falha → só avisa. URL via CONFIGURACAO.API_URL
  (padrão http://127.0.0.1:9000) — preparado p/ API em servidor.
- ATENÇÃO se testar de novo: NÃO usar ExtractFilePath 3x p/ subir
  diretório (não funciona) — usar ExpandFileName+.. (ver código).

COMO SUBIR O AMBIENTE APÓS REINICIAR
1. git pull origin master (ou git status para conferir)
2. Firebird é serviço AUTO_START — já sobe com o Windows.
   API também sobe sozinha no login do Windows (atalho Inicializar).
   Verificar: curl http://localhost:9000/api/health
   → {"status":"ok","banco":"ok",...}
   Se não estiver: Scripts\run_api.bat OU abrir o ERP desktop e
   logar (o watchdog oferece subir a API).
3. Celular: adb connect 192.168.100.126:43511
   adb reverse tcp:9000 tcp:9000
   No app: servidor http://127.0.0.1:9000, login admin,
   senha admin123, empresa_id=1

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
- Baseline a manter: suíte desktop 388/388, builds Android OK.

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

- Senha do `admin` de desenvolvimento: `admin123` (login `admin`).
- Se o adb Wi-Fi cair: `adb kill-server && adb start-server`,
  reconectar pelo USB ou `adb connect` no IP do celular.
- `tmp_shots/` é untracked (screenshots de teste) — ignorar.
- Fila offline do Bipe e demais apps não são afetados pelo reboot.
