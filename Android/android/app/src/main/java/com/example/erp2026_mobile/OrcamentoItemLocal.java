package com.example.erp2026_mobile;

/**
 * Item de um orcamento local.
 *
 * <p>{@code produtoId} e o id do produto no servidor; quando o orcamento e
 * montado off-line sem catalogo, {@code descricao} carrega o texto livre.
 */
public class OrcamentoItemLocal {

    public long id;
    public long orcamentoLocalId;
    public Long produtoId;
    public String descricao = "";
    public double quantidade = 1;
    public double valorUnitario;
    public double desconto;
    public double total;

    public OrcamentoItemLocal() {
    }

    public OrcamentoItemLocal(String descricao, double quantidade, double valorUnitario) {
        this.descricao = descricao == null ? "" : descricao;
        this.quantidade = quantidade;
        this.valorUnitario = valorUnitario;
        recalcular();
    }

    /** total = quantidade x valor unitario - desconto (nunca negativo). */
    public void recalcular() {
        total = (quantidade * valorUnitario) - desconto;
        if (total < 0) {
            total = 0;
        }
    }
}
