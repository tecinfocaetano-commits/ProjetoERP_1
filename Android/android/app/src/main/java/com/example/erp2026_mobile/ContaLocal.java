package com.example.erp2026_mobile;

/**
 * Conta a receber ou a pagar guardada no cache local (somente leitura).
 * O tipo e definido pela tabela de origem: {@code receber = true} para
 * contas a receber e {@code false} para contas a pagar.
 */
public class ContaLocal {

    public long id;
    public Long idServidor;
    public String pessoaNome = "";
    public String descricao = "";
    public double valor;
    public String vencimento = "";
    public String status = "";

    public ContaLocal() {
    }

    /** Linha da lista financeira, igual para receber e pagar. */
    public String resumo(boolean receber) {
        StringBuilder linha = new StringBuilder(receber ? "A RECEBER  -  " : "A PAGAR  -  ");
        linha.append(Fmt.limpar(pessoaNome));
        linha.append("\n").append(Fmt.limpar(descricao));
        linha.append("\n").append(Fmt.moeda(valor));
        linha.append("   Venc.: ").append(Fmt.limpar(vencimento));
        return linha.toString();
    }
}
