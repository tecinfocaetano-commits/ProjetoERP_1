package com.example.erp2026_mobile;

/**
 * Produto guardado no banco local, usado para montar orcamentos sem conexao.
 * E somente um cache: os produtos sao cadastrados no desktop.
 */
public class ProdutoLocal {

    /** id local (auto-incremento). 0 = ainda nao gravado. */
    public long id;

    /** id no servidor (PRODUTO.ID). */
    public Long idServidor;

    public String descricao = "";
    public double precoVenda;

    public ProdutoLocal() {
    }

    public ProdutoLocal(Long idServidor, String descricao, double precoVenda) {
        this.idServidor = idServidor;
        this.descricao = descricao == null ? "" : descricao;
        this.precoVenda = precoVenda;
    }
}
