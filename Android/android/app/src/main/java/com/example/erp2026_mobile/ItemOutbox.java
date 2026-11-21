package com.example.erp2026_mobile;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Item da fila de sincronizacao (outbox).
 *
 * <p>Cada alteracao feita off-line vira uma linha aqui, com o JSON que deve ser
 * enviado para a API. Quando o servidor volta, a fila e processada em ordem e
 * a linha e removida. F9: falhas transitorias entram em backoff exponencial
 * ({@link #proximaTentativa}); apos {@link #MAX_TENTATIVAS} falhas, ou num erro
 * de validacao HTTP 4xx, a linha vira dead-letter ({@link #STATUS_DEAD}) e
 * aparece na tela de sincronizacao para o usuario decidir.
 */
public class ItemOutbox {

    public static final String TIPO_CLIENTE = "CLIENTE";
    public static final String TIPO_ORCAMENTO = "ORCAMENTO";

    public static final String ACAO_INSERIR = "INSERT";
    public static final String ACAO_ATUALIZAR = "UPDATE";

    /** Na fila, aguardando a proxima rodada. */
    public static final String STATUS_PENDENTE = "PENDENTE";
    /** Falhou e esta esperando o backoff expirar. */
    public static final String STATUS_ERRO = "ERRO";
    /** Falha definitiva: nao e reenviada ate o usuario intervir. */
    public static final String STATUS_DEAD = "DEAD";

    /** 5 falhas (1+2+4+8+16 min) antes do dead-letter. */
    public static final int MAX_TENTATIVAS = 5;
    public static final long BACKOFF_BASE_MS = 60_000L;

    public long id;
    public String tipo = "";
    public String acao = "";
    public Long referenciaLocal;
    public String payload = "";
    public long criadoEm;
    public int tentativas;
    public String ultimoErro = "";
    public long proximaTentativa;
    public String status = STATUS_PENDENTE;

    public ItemOutbox() {
    }

    public ItemOutbox(String tipo, String acao, Long referenciaLocal, String payload) {
        this.tipo = tipo;
        this.acao = acao;
        this.referenciaLocal = referenciaLocal;
        this.payload = payload;
        this.criadoEm = System.currentTimeMillis();
    }

    /** Backoff 1, 2, 4, 8, 16 minutos conforme o numero de falhas ja registradas. */
    public static long calcularProximaTentativa(int tentativasJaFeitas) {
        int expoente = Math.max(0, Math.min(tentativasJaFeitas - 1, 10));
        return System.currentTimeMillis() + (BACKOFF_BASE_MS << expoente);
    }

    public boolean emBackoff() {
        return proximaTentativa > System.currentTimeMillis();
    }

    public boolean podeTentar() {
        return !STATUS_DEAD.equals(status) && !emBackoff();
    }

    public String proximaTentativaTexto() {
        if (STATUS_DEAD.equals(status)) {
            return "falha definitiva";
        }
        if (!emBackoff()) {
            return "pronto para enviar";
        }
        try {
            SimpleDateFormat f = new SimpleDateFormat("dd/MM HH:mm", Locale.getDefault());
            return "tenta de novo em " + f.format(new Date(proximaTentativa));
        } catch (Exception e) {
            return "aguardando retry";
        }
    }

    /** Texto curto para a lista da tela de sincronizacao. */
    public String descricao() {
        StringBuilder sb = new StringBuilder();
        sb.append(TIPO_CLIENTE.equals(tipo) ? "Cliente" : "Orcamento");
        sb.append(" (").append(acao).append(") - ");
        if (STATUS_DEAD.equals(status)) {
            sb.append("FALHA DEFINITIVA");
        } else if (emBackoff()) {
            sb.append("aguardando retry");
        } else {
            sb.append("na fila");
        }
        if (tentativas > 0) {
            sb.append(" - ").append(tentativas).append(" tentativa(s)");
        }
        sb.append("\n").append(proximaTentativaTexto());
        if (ultimoErro != null && !ultimoErro.isEmpty()) {
            String erro = ultimoErro.length() > 120 ? ultimoErro.substring(0, 120) + "..." : ultimoErro;
            sb.append("\n").append(erro);
        }
        return sb.toString();
    }
}
