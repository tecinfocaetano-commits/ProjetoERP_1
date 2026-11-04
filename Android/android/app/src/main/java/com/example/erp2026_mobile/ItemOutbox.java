package com.example.erp2026_mobile;

/**
 * Item da fila de sincronizacao (outbox).
 *
 * <p>Cada alteracao feita off-line vira uma linha aqui, com o JSON que deve ser
 * enviado para a API. Quando o servidor volta, a fila e processada em ordem e
 * a linha e removida. {@code tentativas}/{@code ultimoErro} guardam o historico
 * para a tela de sincronizacao.
 */
public class ItemOutbox {

    public static final String TIPO_CLIENTE = "CLIENTE";
    public static final String TIPO_ORCAMENTO = "ORCAMENTO";

    public static final String ACAO_INSERIR = "INSERT";
    public static final String ACAO_ATUALIZAR = "UPDATE";

    public long id;
    public String tipo = "";
    public String acao = "";
    public Long referenciaLocal;
    public String payload = "";
    public long criadoEm;
    public int tentativas;
    public String ultimoErro = "";

    public ItemOutbox() {
    }

    public ItemOutbox(String tipo, String acao, Long referenciaLocal, String payload) {
        this.tipo = tipo;
        this.acao = acao;
        this.referenciaLocal = referenciaLocal;
        this.payload = payload;
        this.criadoEm = System.currentTimeMillis();
    }

    public String descricao() {
        StringBuilder sb = new StringBuilder();
        sb.append(TIPO_CLIENTE.equals(tipo) ? "Cliente" : "Orcamento");
        sb.append(" (").append(acao).append(")");
        if (tentativas > 0) {
            sb.append(" - ").append(tentativas).append(" tentativa(s)");
        }
        if (ultimoErro != null && !ultimoErro.isEmpty()) {
            sb.append("\n").append(ultimoErro);
        }
        return sb.toString();
    }
}
