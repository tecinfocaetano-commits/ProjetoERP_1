package com.example.erp2026_mobile;

/**
 * Orcamento guardado no banco local. Rascunhos criados off-line ficam com
 * {@code idServidor == null} e {@code sincronizado == false} ate a fila
 * ({@code outbox}) enviar para a API.
 */
public class OrcamentoLocal {

    /** Status local de um orcamento que ainda nao subiu. */
    public static final String STATUS_RASCUNHO = "RASCUNHO";

    public long id;
    public Long idServidor;
    public String numero = "";
    public Long clienteLocalId;
    public String clienteNome = "";
    public String data = "";
    public String validade = "";
    public double desconto;
    public double total;
    public String observacao = "";
    public String status = STATUS_RASCUNHO;
    public int qtdItens;
    public boolean sincronizado;
    public long criadoEm;
    public long atualizadoEm;

    public OrcamentoLocal() {
    }

    /** Linha curta para a lista de orcamentos. */
    public String resumo() {
        String titulo = numero == null || numero.isEmpty() ? "Orcamento #" + id : "Orcamento " + numero;
        String cliente = Fmt.limpar(clienteNome);
        StringBuilder sb = new StringBuilder(titulo);
        if (!cliente.isEmpty()) {
            sb.append("  -  ").append(cliente);
        }
        sb.append("\n").append(Fmt.moeda(total));
        if (!sincronizado) {
            sb.append("  -  ").append("aguardando sincronizacao");
        } else if (!status.isEmpty()) {
            sb.append("  -  ").append(status);
        }
        return sb.toString();
    }
}
