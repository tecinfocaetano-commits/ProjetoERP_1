package com.example.erp2026_mobile;

/**
 * Cliente guardado no banco local (cache do servidor ou cadastro feito
 * off-line aguardando sincronizacao).
 */
public class ClienteLocal {

    /** id local (auto-incremento). 0 = ainda nao gravado. */
    public long id;

    /** id no servidor (PESSOA.ID). null enquanto o cadastro nao subiu. */
    public Long idServidor;

    public String nome = "";
    public String cpfCnpj = "";
    public String endereco = "";
    public String cidade = "";
    public String uf = "";
    public String cep = "";
    public String telefone = "";
    public String email = "";
    public String ativo = "A";

    /** true quando o registro ja existe igual no servidor. */
    public boolean sincronizado;

    /** millis da ultima alteracao local. */
    public long atualizadoEm;

    public ClienteLocal() {
    }

    public ClienteLocal(String nome, String cpfCnpj) {
        this.nome = nome == null ? "" : nome;
        this.cpfCnpj = cpfCnpj == null ? "" : cpfCnpj;
    }

    /** Linha curta para as listas (nome + cidade/UF + telefone). */
    public String resumo() {
        StringBuilder sb = new StringBuilder(nome);
        String local = Fmt.cidadeUf(cidade, uf);
        if (!local.isEmpty()) {
            sb.append("\n").append(local);
        }
        String tel = Fmt.limpar(telefone);
        if (!tel.isEmpty()) {
            sb.append("  -  ").append(tel);
        }
        String doc = Fmt.limpar(cpfCnpj);
        String mail = Fmt.limpar(email);
        if (!doc.isEmpty() || !mail.isEmpty()) {
            sb.append("\n").append(doc);
            if (!mail.isEmpty()) {
                sb.append("  -  ").append(mail);
            }
        }
        return sb.toString();
    }
}
