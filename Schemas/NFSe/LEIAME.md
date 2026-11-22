# Schemas XML da NFS-e Nacional (SNNFSe)

Pacote oficial **NFSe-ESQUEMAS_XSD-v1.01-20260209**, baixado da página
[Documentação Atual (Produção)](https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/documentacao-atual)
do Portal da Nota Fiscal de Serviço eletrônica (gov.br).

- Versão dos esquemas: **1.01** (vigente desde 09/02/2026).
- Documento principal usado pelo ERP: `1.01/DPS_v1.01.xsd`
  (Declaração de Prestação de Serviços), com os includes/imports locais.
- `1.01/xmldsig-core-schema.xsd` é necessário para a assinatura XML.
- Os arquivos foram copiados sem alteração. Não versionar PDFs, XLSX ou
  certificados nesta pasta.

O ERP copia estes arquivos para `Desktop\bin\schemas\nfse` através de
`Scripts\preparar_nfse.bat`, sem misturar com os schemas da NF-e/NFC-e.
