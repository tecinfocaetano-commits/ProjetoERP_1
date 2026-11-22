# PROMPT — Testes fiscais gratuitos (sem MEI, sem SEFAZ) — ERP 2026

> Entregável: qualquer agente deve conseguir executar, sozinho, uma bateria de
> testes fiscais **locais e gratuitos**, o mais próxima da realidade que o
> ambiente permite, e ao final registrar as melhorias futuras de NFS-e e de
> nota de entrada. **Não é homologação real**: nada é enviado à SEFAZ.

Copie este arquivo como instrução de trabalho. Não é necessário conhecimento
prévio do projeto além dos comandos e regras abaixo.

---

## 0. Regras de ouro (não negociáveis)

1. **Nunca enviar nada à SEFAZ.** Mantenha `NFE_MODO=SIMULADO` (ou a chave
   ausente, que já vale como simulado). `NFE_AMBIENTE=2` apenas deixa o XML
   com `tpAmb=2` (homologação); **não** configure `NFE_MODO=REAL`.
2. **Não usar dados de terceiros.** Não pegue CNPJ, IE, e-CNPJ ou CSC de
   ninguém "emprestado", nem em homologação. O CNPJ/IE de demonstração do
   banco (`00000000000191` / `111111111111`) é suficiente para a simulação.
3. **Pedido de teste: `1003` (`PV-TESTE-5`).** Não use `3581` /
   `CEN-FISCAL-01` (cenário do outro agente: talão 533 / mapa 1014).
4. **Não commitar** certificados (`.pfx`, `.p12`), senhas,
   `Desktop\bin\nfe\*` nem `tmp_shots/`. Certificados ficam **fora** do repo.
5. **Não tocar** em `Android\android\pdv\**`, `Android\android\bipe\**`,
   `HistoricoActivity.java`, `API\src\Rotas\uRotasPDV.pas` ou
   `Android\android\settings.gradle`. O `:pdv` **já está** em
   `Scripts\build_pdv.bat`, no CI/bateria e nos docs (marco 3.91, usuário
   autorizou em 21/11) — não precisa mais pedir licença para incluí-lo,
   mas não edite o código dele sem pedido específico.
6. **Comunicação:** ler e escrever `Documentacao\COMUNICACAO_AGENTES.md` no
   início e no fim do bloco, antes de mexer em arquivo compartilhado e antes
   de parar/reiniciar a API na porta 9000. Deixar recado mesmo que seja
   "sem novidades".
7. **Não prometer o que não existe:** o PDF gerado localmente é DANFE/cupom
   **off-line, sem protocolo de autorização**. Cupom NFC-e autorizado exige
   certificado ICP-Brasil, CSC e dados fiscais reais — hoje indisponíveis.

---

## 1. Pré-requisitos

| Item | Valor / comando |
|---|---|
| Repositório | `C:\Users\Charles\Documents\ProjetoERP_1` |
| Desktop | `Desktop\bin\ERP2026.exe` (compilado com `-dACBR`, já configurado no `.lpi`). Se faltar: `Scripts\build_desktop.bat` |
| Firebird 5 | `C:\Program Files\Firebird\Firebird_5_0\isql.exe`, usuário `SYSDBA`, senha `masterkey`, banco `Banco\dados.fdb` |
| Login do ERP | `admin` / `admin123` |
| Certificado local | `C:\certificados\teste.pfx`, senha `teste123` (gerado por `Scripts\gerar_certificado_teste.ps1`) |
| Kit externo (opcional) | `C:\Users\Charles\AppData\Local\Temp\opencode\cert_kit\`, senha `123456` — 3 `.pfx` **autoassinados** (válido, vencido e "homologação") |
| Schemas | `Desktop\bin\schemas` (já presentes) |

Os certificados acima são **autoassinados**: servem para assinar e validar o
XML localmente. **Nenhum deles é aceito pela SEFAZ, nem em homologação.**
Não importe o `.pfx` no armazenamento do Windows e não o copie para o repo.

---

## 2. Conferir a configuração fiscal (somente leitura)

```sql
-- salve como temp/config_fiscal.sql e rode com:
-- isql Banco\dados.fdb -user SYSDBA -password masterkey -ch UTF8 -i temp\config_fiscal.sql -q
SELECT EMPRESA_ID, CHAVE, VALOR
FROM CONFIGURACAO
WHERE CHAVE LIKE 'NFE_%' OR CHAVE LIKE 'NFCE_%'
ORDER BY CHAVE;
```

Hoje **não há** chaves `NFE_*`/`NFCE_*` na `CONFIGURACAO`: isso é correto para
a simulação (o padrão do `TACBrHelper` é `FAmbiente=2` e
`FModoSimulado=True`). Se encontrar `NFE_MODO=REAL`, anote o valor original,
troque para `SIMULADO` apenas durante a bateria e **restaure no final**. Se
encontrar `NFE_AMBIENTE=1`, troque para `2` e restaure depois — nunca deixe
`REAL` ligado sem certificado ICP-Brasil.

Não crie coluna/tabela/estado novo para "homologação": a decisão do projeto
é reutilizar `CONFIGURACAO` (`NFE_AMBIENTE=2` + `NFE_MODO=REAL` liga;
`NFE_MODO=SIMULADO` desliga).

---

## 3. Bateria (execute em ordem)

### 3.1 Suíte desktop — cobre NFC-e e importação de XML

```bat
cd /d C:\Users\Charles\Documents\ProjetoERP_1
Scripts\run_tests.bat
```

Esperado: `Total: 385 | Passou: 385 | Falhou: 0`.

Testes relevantes dentro dela:
- `TestNFeGerarNFCe` — emissão simulada de NFC-e (`GerarNFCe` →
  `GerarSimulada`, sem envio);
- `TestNFeDestinatarioOpcionalNFCe` — na NFC-e (modelo 65) o destinatário é
  opcional; na NF-e (55) endereço é obrigatório; a validação local de NFC-e
  usa `IdCSC`/`CSC` fictícios (`ID-TESTE`/`CSC-TESTE`) apenas em memória;
- `TestImportarXmlNotaEntrada` — XML com prefixo de namespace, fornecedor por
  CNPJ, produto por código, NCM/CFOP/CST/quantidade conferidos, chave
  duplicada recusada e auditoria `XML_FISCAL/IMPORTACAO_XML`;
- testes de CC-e, inutilização, manifestação e DANFE (a "baixa" e a geração
  de XML da rotina fiscal).

### 3.2 Assinar e validar um XML de NF-e real (modelo 55, `tpAmb=2`)

```bat
Scripts\validar_nfe.bat 1003 C:\certificados\teste.pfx teste123
REM alternativa com o kit externo:
Scripts\validar_nfe.bat 1003 C:\Users\Charles\AppData\Local\Temp\opencode\cert_kit\certificado_valido-123456.pfx 123456
```

Esperado (exit code `0`):

```
OK
Numero=5
Serie=1
Chave=<44 dígitos>
Motivo=XML assinado e validado localmente (não enviado à SEFAZ)
```

Artefatos em `Desktop\bin\nfe\`: `validacao_1003.txt` e `<chave>-nfe.xml`.
O XML é um documento 4.00 completo, assinado e validado contra os schemas —
é o teste local mais próximo da realidade. **Não tem protocolo da SEFAZ.**

> Nota de gap: o validador atual **não checa validade do certificado**. O
> `.pfx` vencido do kit também passa. Registre isso como melhoria futura.

### 3.3 Gerar o PDF (DANFE off-line)

```bat
Desktop\bin\ERP2026.exe --danfe=<chave de 44 dígitos>
```

Esperado: `Desktop\bin\nfe\danfe_<chave>.txt` com `OK: DANFE gerado...` e o
arquivo `<chave>-nfe.pdf`. Para o XML do passo 3.2 isso é um **DANFE de NF-e
modelo 55**. A rotina `GerarDANFEPDF` também atende modelo 65 (cupom), mas
hoje não existe CLI `--validar-nfce`: `ValidarNFCe` só é chamada pelos testes.

### 3.4 Venda no PDV desktop (pagamento + NFC-e simulada)

1. Abra `Desktop\bin\ERP2026.exe`, entre com `admin`/`admin123`.
2. Vá em **PDV**, escolha produto, forma de pagamento (ex.: Dinheiro),
   finalize a venda.
3. Com `NFE_MODO=SIMULADO`, `TACBrHelper.GerarNFCe` chama `GerarSimulada`:
   não há XML schema-válido, não há protocolo e **não é gerado PDF de cupom**
   nesse modo (o PDF do PDV desktop só sai de NFC-e autorizada). Isso é
   comportamento esperado, não falha.
4. Anote o número da venda e o recibo/cupom de tela como evidência.

### 3.5 Importar XML de nota de entrada (manual)

1. Use o XML assinado do passo 3.2 ou um XML de exemplo com `<infNFe>` e
   `mod=55` (o teste 3.1 contém um modelo com namespace prefixado).
2. No ERP: **Fiscal > NF-e > Importar XML**, selecione o arquivo.
3. Esperado: `NOTA_ENTRADA` criada como **Aberta**, fornecedor localizado pelo
   CNPJ do `<emit>`, itens com `cProd`/`xProd`/`NCM`/`CFOP`/`CST_ICMS`/
   quantidade/valor, total igual a `ICMSTot/vNF`, auditoria
   `XML_FISCAL/IMPORTACAO_XML` e recusa de chave repetida numa 2ª importação.
4. O parser aceita BOM e prefixos de namespace (`nfe:`, `ns2:`). Hoje ele
   **só entende `infNFe`** (modelo 55/65); veja a melhoria futura na §5.

### 3.6 Saúde da API (opcional, não é fiscal)

```bat
Scripts\testes\api_todos.ps1
```

Esperado: `API-TODOS CONCLUIDO: 6 smokes OK` e `GET /api/health` com
`"status":"ok"` **e** `"banco":"ok"`. Se o banco falhar, o health deve
devolver HTTP 503 (foi justamente o fix feito no pool/health).

---

## 4. Relatório do agente (modelo curto)

```
Data/hora:
Commit/PID da API:
Suíte desktop: 385/385
validação local 1003: OK / chave ...
DANFE: <caminho do PDF>
Importação de XML: NOTA_ENTRADA id=..., itens=..., duplicata recusada sim/não
API: 6 smokes OK, health banco=ok
git status: nenhum certificado/PDF/tmp_shots commitado
Limitações encontradas:
```

---

## 5. NFS-e de prefeitura — geração off-line CONCLUÍDA no marco 3.92

> Já entregue (22/11): preferências `NFSE_*`, DPS nacional 1.01 em
> `NFSE_MODO=SIMULADO` (sem certificado/assinatura/envio), tabela
> `NOTA_SAIDA_SERVICO`, retenções, auditoria e dedupe.Para conferir, rode
> `Scripts\run_tests.bat` e veja os 9 testes `TestNFSe*` e os 3 testes
> `Test*NFS_e*` do parser/importação (suíte 400/400). O XSD oficial está em
> `Schemas\NFSe\1.01` e é copiado por `Scripts\preparar_nfse.bat`.
> **Concluído no 3.93:** tela resumida de nota de serviço e NFS-e no parser
> da nota de entrada. **Ainda é plano:** emissão com protocolo, adapters
> Sigcorp/Beta e integração homologada.

Motivo: nota de serviço está em alta e, a partir de 2026, o padrão nacional
de NFS-e passou a ser exigido (confirmar prazos específicos no portal oficial
/ com o contador). Ainda assim existem prefeituras com emissor próprio
(exemplos citados pelo usuário: **Sigcorp**, **Beta**).

Plano proposto:

1. **Preferências** na mesma tela *Sistema > Configurações*, reaproveitando
   `CONFIGURACAO` (empresa antes da linha global, sem estado redundante):
   - `NFSE_PROVEDOR` — **Código do provedor** (ex.: `SIGCORP`, `BETA`,
     `NACIONAL`, `OUTRO`);
   - `NFSE_MUNICIPIO_IBGE`, `NFSE_INSCRICAO_MUNICIPAL`;
   - `NFSE_AMBIENTE` (1 produção / 2 homologação) e `NFSE_MODO`
     (`SIMULADO`/`REAL`, o mesmo padrão de NF-e/NFC-e);
   - `NFSE_SERIE`, `NFSE_RPS_SEQUENCIA`, usuário/token do provedor — **senha
     nunca em claro no banco**, seguir o padrão de pedir na hora do envio.
2. **Arquitetura**: preferir o **layout nacional** como adapter principal e
   manter adapters por provedor (Sigcorp/Beta) apenas como legado/fallback;
   um `TNFSeHelper` paralelo ao `TACBrHelper`, com `GerarRPS`,
   `Emitir`, `Consultar`, `Cancelar`, `GerarPDF`.
3. **Regras de serviço**: reter ISS (e PIS/COFINS/INSS conforme regime),
   código de serviço/CMC, município do fato gerador; **sem baixa de estoque**
   e sem contas a receber automáticas sem decisão do usuário.
4. **Auditoria**: `LOG_SISTEMA` com provedor, ambiente, chave/RPS e resultado;
   dedupe por chave + provedor.
5. **Testes locais gratuitos**: validar XML contra schemas do padrão
   nacional/adapter com token fictício, sem envio; estender a suíte sem
   quebrar os 397 testes atuais.

---

## 6. Melhoria futura — nota de entrada aceitar serviços e notas de prefeitura

Hoje `TNFeXmlParser.DeTexto` exige `<infNFe>` e `TNFeImportService.Importar`
grava `Modelo='55'`: apenas NF-e/NFC-e de produtos.

Plano proposto (implementar depois do ciclo atual de pagamentos/API):

1. **Detecção do tipo de documento** pela tag raiz: `infNFe` (55/65),
   `infNFS-e` / `RPS` / `InfDeclaracaoPrestacaoServico` (NFS-e municipal ou
   nacional), `infCTe` (CT-e, se quiser depois), `infCFe` (CF-e).
2. **Modelo interno comum** `TDocumentoEntradaServico`: chave, emitente
   (CNPJ/CPF/IM), data, município, código de serviço/CMC, descrição, valor,
   ISS/PIS/COFINS/INSS, provider. Adapter por provedor + fallback genérico.
3. **Serviços de comunicação e internet** (o usuário escreveu "cominação e
   internet" — confirmar o termo na execução) entram como **item de serviço**:
   sem NCM/CFOP obrigatórios, sem quantidade de estoque, sem movimento de
   estoque. O cadastro de produto pode ganhar `TIPO='S'` com
   `CONTROLA_ESTOQUE='N'`.
4. **Banco (migração aditiva)**: `NOTA_ENTRADA_ITEM` ganha `TIPO`,
   `CODIGO_SERVICO`, `MUNICIPIO_ID`, `ALIQUOTA_ISS`; `NOTA_ENTRADA` ganha
   `TIPO_DOCUMENTO` e `PROVEDOR`. Nada de rename (convenção do projeto).
5. **Auditoria e dedupe**: `XML_FISCAL/IMPORTACAO_XML` passa a registrar o
   tipo e o provedor; chave repetida só é recusada dentro do mesmo tipo.
6. **Testes**: XMLs sintéticos de NFS-e nacional + Sigcorp/Beta, com e sem
   ISS, e a garantia de que os 397 testes atuais continuam verdes.

---

## 7. Limites que **não** devem ser inventados como "feitos"

- Certificado autoassinado (local ou kit) **nunca** autoriza nota na SEFAZ.
- PDF local não tem protocolo e não substitui cupom autorizado.
- Homologação real exige CNPJ/IE regulares, e-CNPJ A1 ICP-Brasil,
  habilitação do contribuinte na SEFAZ e IdCSC/CSC — o usuário não tem e não
  quer usar dados de terceiros.
- O app `:pdv` não emite NFC-e na fase atual; emissão fiscal continua no
  desktop.
