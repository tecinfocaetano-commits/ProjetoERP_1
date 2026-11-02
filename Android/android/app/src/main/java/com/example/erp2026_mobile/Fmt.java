package com.example.erp2026_mobile;

import java.text.NumberFormat;
import java.util.Locale;

/**
 * Formatacao de valores no padrao brasileiro (pt-BR).
 */
public final class Fmt {

    private static final Locale BR = new Locale("pt", "BR");

    private Fmt() { }

    /** 1234.5 -> "R$ 1.234,50" */
    public static String moeda(double valor) {
        NumberFormat nf = NumberFormat.getCurrencyInstance(BR);
        return nf.format(valor);
    }

    /** 20.0 -> "20" | 9.5 -> "9,5" | 9.456 -> "9,46" */
    public static String quantidade(double valor) {
        if (valor == Math.rint(valor)) {
            return String.format(BR, "%.0f", valor);
        }
        return String.format(BR, "%.2f", valor);
    }

    /** Remove espaços de preenchimento vindos do banco (CHAR(n)). */
    public static String limpar(String texto) {
        return texto == null ? "" : texto.trim();
    }

    /** Monta "Cidade/UF" ignorando as partes vazias. */
    public static String cidadeUf(String cidade, String uf) {
        String c = limpar(cidade);
        String u = limpar(uf);
        if (c.isEmpty()) {
            return u;
        }
        if (u.isEmpty()) {
            return c;
        }
        return c + "/" + u;
    }
}
