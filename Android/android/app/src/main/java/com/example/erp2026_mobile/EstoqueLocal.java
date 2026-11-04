package com.example.erp2026_mobile;

/**
 * Posicao de estoque guardada no cache local para consulta sem conexao.
 * Somente leitura: movimentos continuam sendo feitos no desktop/API.
 */
public class EstoqueLocal {

    public long id;
    public Long idServidor;
    public String codigo = "";
    public String descricao = "";
    public double quantidade;
    public double estoqueMinimo;
    public double valorEstoque;

    public EstoqueLocal() {
    }

    /** Duas linhas da lista de estoque, com aviso quando abaixo do minimo. */
    public String resumo() {
        StringBuilder linha = new StringBuilder(Fmt.limpar(descricao));
        linha.append("\nCód: ").append(Fmt.limpar(codigo));
        linha.append("   Qtd: ").append(Fmt.quantidade(quantidade));
        if (estoqueMinimo > 0 && quantidade <= estoqueMinimo) {
            linha.append("\nEstoque baixo (mínimo ")
                    .append(Fmt.quantidade(estoqueMinimo)).append(")");
        }
        return linha.toString();
    }
}
