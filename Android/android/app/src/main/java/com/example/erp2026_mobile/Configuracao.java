package com.example.erp2026_mobile;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Configuracao por empresa (D9).
 *
 * <p>Cada empresa guarda a <b>sua</b> URL de servidor e o <b>seu</b> codigo de
 * usuario. A troca de empresa troca a configuracao usada pelas chamadas da API.
 *
 * <p>Chaves em {@link SharedPreferences} (locais do aparelho, nao vao para o
 * banco):
 * <ul>
 *   <li>{@code empresaAtual} - codigo da empresa em uso;</li>
 *   <li>{@code empresas} - conjunto de codigos cadastrados;</li>
 *   <li>{@code url_<empresa>} e {@code codigo_<empresa>}.</li>
 * </ul>
 */
public final class Configuracao {

    /** URL usada quando ainda nao existe configuracao (emulador -> maquina host). */
    public static final String URL_PADRAO = ApiClient.BASE_URL;

    private static final String PREFS = "erp2026_config";
    private static final String K_ATUAL = "empresaAtual";
    private static final String K_EMPRESAS = "empresas";
    private static final String P_URL = "url_";
    private static final String P_CODIGO = "codigo_";

    private final String empresa;
    private final String urlServidor;
    private final String codigoUsuario;

    public Configuracao(String empresa, String urlServidor, String codigoUsuario) {
        this.empresa = normalizarEmpresa(empresa);
        this.urlServidor = normalizarUrl(urlServidor);
        this.codigoUsuario = codigoUsuario == null ? "" : codigoUsuario.trim();
    }

    public String getEmpresa() {
        return empresa;
    }

    public String getUrlServidor() {
        return urlServidor;
    }

    public String getCodigoUsuario() {
        return codigoUsuario;
    }

    // ------------------------------------------------------------------
    // Normalizacao / validacao
    // ------------------------------------------------------------------

    public static String normalizarEmpresa(String valor) {
        return valor == null ? "" : valor.trim();
    }

    /**
     * Aceita "192.168.0.10:9000", "http://host:9000/", "host/erp" e devolve
     * sempre "http://host:porta[/caminho]" sem barra no fim.
     */
    public static String normalizarUrl(String valor) {
        String url = valor == null ? "" : valor.trim();
        while (url.endsWith("/")) {
            url = url.substring(0, url.length() - 1);
        }
        if (url.isEmpty()) {
            return "";
        }
        String minuscula = url.toLowerCase();
        if (!minuscula.startsWith("http://") && !minuscula.startsWith("https://")) {
            url = "http://" + url;
        }
        return url;
    }

    /** true quando ha esquema http/https, host e (se informada) porta valida. */
    public static boolean urlValida(String url) {
        String normalizada = normalizarUrl(url);
        if (normalizada.isEmpty()) {
            return false;
        }
        String minuscula = normalizada.toLowerCase();
        if (!minuscula.startsWith("http://") && !minuscula.startsWith("https://")) {
            return false;
        }
        String resto = normalizada.substring(normalizada.indexOf("://") + 3);
        int barra = resto.indexOf('/');
        String hostPorta = barra >= 0 ? resto.substring(0, barra) : resto;
        if (hostPorta.isEmpty()) {
            return false;
        }
        int doisPontos = hostPorta.indexOf(':');
        if (doisPontos >= 0) {
            String host = hostPorta.substring(0, doisPontos);
            String porta = hostPorta.substring(doisPontos + 1);
            if (host.isEmpty() || porta.isEmpty()) {
                return false;
            }
            try {
                int numero = Integer.parseInt(porta);
                if (numero < 1 || numero > 65535) {
                    return false;
                }
            } catch (NumberFormatException e) {
                return false;
            }
        }
        return true;
    }

    // ------------------------------------------------------------------
    // Persistencia
    // ------------------------------------------------------------------

    private static SharedPreferences prefs(Context contexto) {
        return contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public static List<String> listarEmpresas(Context contexto) {
        Set<String> conjunto = prefs(contexto).getStringSet(K_EMPRESAS, new HashSet<String>());
        List<String> lista = new ArrayList<>(conjunto);
        Collections.sort(lista, String.CASE_INSENSITIVE_ORDER);
        return lista;
    }

    public static boolean vazia(Context contexto) {
        return prefs(contexto).getStringSet(K_EMPRESAS, new HashSet<String>()).isEmpty();
    }

    /**
     * Devolve o codigo como esta gravado (comparando sem diferenciar
     * maiusculas/minusculas) para a empresa ter uma unica identidade.
     */
    private static String canonica(Set<String> empresas, String chave) {
        for (String cadastrada : empresas) {
            if (cadastrada.equalsIgnoreCase(chave)) {
                return cadastrada;
            }
        }
        return chave;
    }

    /** Devolve a configuracao da empresa, ou null quando nao ha nada gravado. */
    public static Configuracao carregar(Context contexto, String empresa) {
        String chave = normalizarEmpresa(empresa);
        if (chave.isEmpty()) {
            return null;
        }
        SharedPreferences p = prefs(contexto);
        String nome = canonica(p.getStringSet(K_EMPRESAS, new HashSet<String>()), chave);
        String url = p.getString(P_URL + nome, "");
        if (url.isEmpty()) {
            return null;
        }
        return new Configuracao(nome, url, p.getString(P_CODIGO + nome, ""));
    }

    public static Configuracao carregarAtual(Context contexto) {
        return carregar(contexto, empresaAtual(contexto));
    }

    public static String empresaAtual(Context contexto) {
        return prefs(contexto).getString(K_ATUAL, "");
    }

    public static void definirEmpresaAtual(Context contexto, String empresa) {
        String chave = normalizarEmpresa(empresa);
        if (chave.isEmpty()) {
            prefs(contexto).edit().remove(K_ATUAL).apply();
        } else {
            prefs(contexto).edit().putString(K_ATUAL, chave).apply();
        }
    }

    /** Grava (ou substitui) a configuracao. A primeira empresa vira a atual. */
    public static void salvar(Context contexto, Configuracao configuracao) {
        if (configuracao == null
                || configuracao.empresa.isEmpty()
                || configuracao.urlServidor.isEmpty()) {
            return;
        }
        SharedPreferences p = prefs(contexto);
        Set<String> empresas = new HashSet<>(p.getStringSet(K_EMPRESAS, new HashSet<String>()));
        String nome = canonica(empresas, configuracao.empresa);
        empresas.add(nome);
        p.edit()
                .putStringSet(K_EMPRESAS, empresas)
                .putString(P_URL + nome, configuracao.urlServidor)
                .putString(P_CODIGO + nome, configuracao.codigoUsuario)
                .apply();
        if (empresaAtual(contexto).isEmpty()) {
            definirEmpresaAtual(contexto, nome);
        }
    }

    /** Remove a empresa (e a URL/codigo dela). */
    public static void remover(Context contexto, String empresa) {
        String chave = normalizarEmpresa(empresa);
        if (chave.isEmpty()) {
            return;
        }
        SharedPreferences p = prefs(contexto);
        Set<String> empresas = new HashSet<>(p.getStringSet(K_EMPRESAS, new HashSet<String>()));
        String nome = canonica(empresas, chave);
        empresas.remove(nome);
        boolean eraAtual = nome.equalsIgnoreCase(empresaAtual(contexto));
        p.edit()
                .putStringSet(K_EMPRESAS, empresas)
                .remove(P_URL + nome)
                .remove(P_CODIGO + nome)
                .apply();
        if (eraAtual) {
            p.edit().remove(K_ATUAL).apply();
        }
    }

    /** Aponta o ApiClient para a empresa em uso (ou deixa a URL padrao). */
    public static void aplicarNoApi(Context contexto) {
        Configuracao atual = carregarAtual(contexto);
        ApiClient.setBaseUrl(atual == null ? URL_PADRAO : atual.urlServidor);
    }

    /** Texto curto para a tela de login/dashboard. */
    public String descricao() {
        if (codigoUsuario.isEmpty()) {
            return empresa + " · " + urlServidor;
        }
        return empresa + " · " + urlServidor + " · usuário " + codigoUsuario;
    }
}
