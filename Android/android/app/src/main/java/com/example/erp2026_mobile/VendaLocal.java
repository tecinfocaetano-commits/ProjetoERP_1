package com.example.erp2026_mobile;

/**
 * Venda (pedido) guardada no cache local para consulta sem conexao.
 *
 * <p>E somente leitura: vendas sao criadas no desktop/API. O cache e
 * substituido a cada sincronizacao.
 */
public class VendaLocal {

    public long id;
    public Long idServidor;
    public String numero = "";
    public String clienteNome = "";
    public double total;
    public String data = "";
    public String status = "";

    public VendaLocal() {
    }

    /** Duas linhas da lista de vendas. */
    public String resumo() {
        StringBuilder linha = new StringBuilder(
                numero == null || numero.isEmpty() ? "Pedido" : numero);
        String cliente = Fmt.limpar(clienteNome);
        if (!cliente.isEmpty()) {
            linha.append(" - ").append(cliente);
        }
        linha.append("\n").append(Fmt.moeda(total));
        String emissao = Fmt.limpar(data);
        if (!emissao.isEmpty()) {
            linha.append("   Emissão: ").append(emissao);
        }
        String situacao = Fmt.limpar(status);
        if (!situacao.isEmpty()) {
            linha.append("   ").append(situacao);
        }
        return linha.toString();
    }
}
