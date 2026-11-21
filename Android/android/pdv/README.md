# ERP 2026 PDV — app Android de frente de caixa

App Android (`com.example.erp2026_pdv`) para operar o PDV pelo celular:
busca de produtos, carrinho de venda, pagamento com troco e gestão do
caixa (suprimento, sangria e fechamento). Toda a regra de negócio fica
na API (`/api/pdv/*` → `TPDVService`); o app só coleta e exibe dados.

## Funcionalidades

- Login com as mesmas credenciais do ERP (`/api/login`, JWT por empresa;
  campo opcional de empresa quando o login existe em mais de uma).
- Status do caixa na tela: número, valor de abertura e saldo atual.
- Busca de produtos por código, código de barras ou descrição
  (`GET /api/pdv/produtos?busca=`) e leitura pela câmera
  (`GET /api/pdv/produtos/buscar?codigo=` — ZXing).
- Carrinho: toque no resultado adiciona; botões ＋/－/Remover ajustam o
  item selecionado; desconto opcional; total calculado no aparelho.
- Pagamento: lista as formas ativas (`GET /api/pdv/formas-pagamento`),
  valor pago com troco calculado na hora. **Dinheiro** registra direto
  via `POST /api/pdv/vendas`. **Cartão/PIX/outros** viram cobrança
  eletrônica (`POST /api/pdv/pagamentos/iniciar`): o app mostra a tela
  "Aguardando pagamento" com polling de `GET .../status` a cada 4s,
  exibe o payload/QR devolvido pelo provedor e permite cancelar
  (`POST .../cancelar`). **O cupom/PDF só é gerado depois que o
  servidor confirma APROVADO e grava a venda** (itens + movimento 'V',
  mesma transação e auditoria do PDV desktop). Recusa/cancelamento/
  expiração não geram venda nem cupom.
- Provedor de pagamento: resolvido no servidor pela config
  `PAG_PROVIDER` (padrão `SIMULADO`, que aprova ~8s após o início —
  apenas para testes, sem PSP real). Adapters reais (Asaas,
  MercadoPago, EFI, TEF) entram em `uPagamentoService.pas`.
- Cupom não fiscal exibido após a venda, com opções de **compartilhar**
  texto (WhatsApp etc.) e **PDF** (`CupomPdf.java`, PdfDocument nativo,
  compartilhado via FileProvider — sem dependência nova).
- Caixa: abrir (valor inicial), suprimento ('E'), sangria ('S') e
  fechamento com saldo apurado — tudo via `/api/pdv/caixa/*`.
- Sessão expirada (HTTP 401) volta ao login automaticamente.

## Build

```bat
cd Android\android
gradlew.bat :pdv:assembleDebug
```

APK gerado em `pdv\build\outputs\apk\debug\pdv-debug.apk`.

## Como usar

1. Suba a API (`API\bin\ERP2026API.exe`, porta 9000) na rede local.
2. Abra o app → informe o servidor (ex.: `http://192.168.0.10:9000`),
   usuário e senha.
3. Abra o caixa: sem caixa aberto o botão **Fechar** vira **Abrir** e
   pede o valor inicial; com caixa aberto ele fecha o caixa.
4. Busque/adiciona produtos, ajuste quantidades, informe desconto,
   **FINALIZAR VENDA**, escolha a forma e confirme.

## Fora de escopo (fase 1)

- NFC-e / emissão fiscal — fica no desktop (modo homologação não se
  aplica aqui).
- TEF, múltiplas formas de pagamento por venda, cliente identificado
  (usa sempre o "Consumidor Final" da empresa).
- Impressão térmica direta — o PDF pode ser enviado a qualquer app de
  impressão; cupom dedicado 80mm fica para uma fase futura.
- Funciona **somente online** (vendas exigem a API no ar).
