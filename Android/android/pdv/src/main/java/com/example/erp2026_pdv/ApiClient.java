package com.example.erp2026_pdv;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * Cliente HTTP mínimo para a API do ERP (GET/POST JSON + Bearer token).
 * Sem dependências externas — mesmo padrão do app Bipe.
 */
public final class ApiClient {

    public static class Result {
        public final int status;
        public final String body;

        public Result(int status, String body) {
            this.status = status;
            this.body = body == null ? "" : body;
        }

        public boolean ok() {
            return status >= 200 && status < 300;
        }
    }

    private static String urlBase = "";
    private static String token = null;

    private ApiClient() { }

    public static void configurar(String base) {
        urlBase = base == null ? "" : base.trim();
        while (urlBase.endsWith("/")) {
            urlBase = urlBase.substring(0, urlBase.length() - 1);
        }
    }

    public static String getUrlBase() {
        return urlBase;
    }

    public static void setToken(String valor) {
        token = valor;
    }

    public static String getToken() {
        return token;
    }

    /** GET com token. Lança Exception em falha de rede/timeout. */
    public static Result get(String caminho) throws Exception {
        HttpURLConnection conn = null;
        try {
            URL url = new URL(urlBase + caminho);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(15000);
            conn.setRequestProperty("Accept", "application/json");
            if (token != null && !token.isEmpty()) {
                conn.setRequestProperty("Authorization", "Bearer " + token);
            }
            int status = conn.getResponseCode();
            InputStream is = status >= 400 ? conn.getErrorStream() : conn.getInputStream();
            return new Result(status, ler(is));
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }

    /** POST JSON. Lança Exception em falha de rede/timeout. */
    public static Result post(String caminho, String corpoJson) throws Exception {
        return post(caminho, corpoJson, true);
    }

    /** POST JSON sem token (usado pelo login). */
    public static Result postSemToken(String caminho, String corpoJson) throws Exception {
        return post(caminho, corpoJson, false);
    }

    /** Monta query string encodada (para GET /api/pdv/produtos?busca=). */
    public static String query(String chave, String valor) {
        try {
            return chave + "=" + URLEncoder.encode(valor, "UTF-8");
        } catch (Exception e) {
            return chave + "=" + valor;
        }
    }

    private static Result post(String caminho, String corpoJson,
                               boolean comToken) throws Exception {
        String endereco = urlBase + caminho;
        HttpURLConnection conn = null;
        try {
            URL url = new URL(endereco);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(15000);
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            conn.setRequestProperty("Accept", "application/json");
            conn.setDoOutput(true);

            if (comToken && token != null && !token.isEmpty()) {
                conn.setRequestProperty("Authorization", "Bearer " + token);
            }

            byte[] dados = corpoJson.getBytes(StandardCharsets.UTF_8);
            conn.setFixedLengthStreamingMode(dados.length);
            try (OutputStream os = conn.getOutputStream()) {
                os.write(dados);
            }

            int status = conn.getResponseCode();
            InputStream is = status >= 400 ? conn.getErrorStream() : conn.getInputStream();
            return new Result(status, ler(is));
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }

    private static String ler(InputStream is) throws Exception {
        if (is == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(
                new InputStreamReader(is, StandardCharsets.UTF_8))) {
            String linha;
            while ((linha = br.readLine()) != null) {
                sb.append(linha);
            }
        }
        return sb.toString();
    }
}
