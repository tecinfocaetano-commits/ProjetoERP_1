package com.example.erp2026_mobile;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

/**
 * Cliente HTTP da API REST do ERP 2026.
 * Sem dependencias externas: usa HttpURLConnection e org.json (nativos do Android).
 *
 * <p>A URL base e configuravel por empresa ({@link Configuracao}): a tela de
 * configuracao chama {@link #setBaseUrl(String)} e todas as chamadas passam a
 * usar aquele servidor. Sem configuracao, vale {@link #BASE_URL}.
 */
public final class ApiClient {

    /** 10.0.2.2 e o alias do "localhost" da maquina host, visto de dentro do emulador. */
    public static final String BASE_URL = "http://10.0.2.2:9000";

    private static String baseUrl = BASE_URL;
    private static String token = null;

    private ApiClient() { }

    public static void setToken(String valor) { token = valor; }
    public static String getToken() { return token; }

    /** Define a URL base (ex.: "http://192.168.0.10:9000"); vazio volta ao padrao. */
    public static void setBaseUrl(String valor) {
        String normalizada = Configuracao.normalizarUrl(valor);
        baseUrl = normalizada.isEmpty() ? BASE_URL : normalizada;
    }

    public static String getBaseUrl() { return baseUrl; }

    public static final class Result {
        public final int status;
        public final String body;

        Result(int status, String body) {
            this.status = status;
            this.body = body;
        }

        public boolean ok() {
            return status >= 200 && status < 300;
        }

        public String errorMessage() {
            if (body == null || body.isEmpty()) {
                return "HTTP " + status;
            }
            return "HTTP " + status + " - " + body;
        }
    }

    public static Result get(String path) throws Exception {
        // O servidor eventualmente encerra a resposta um byte antes do
        // Content-Length (perda do último fechamento de chave). Como GET é
        // idempotente, tenta de novo antes de entregar o erro para a tela.
        Exception ultimo = null;
        for (int tentativa = 1; tentativa <= 3; tentativa++) {
            try {
                return request("GET", path, null);
            } catch (java.io.IOException e) {
                ultimo = e;
                if (tentativa < 3) {
                    Thread.sleep(120L * tentativa);
                }
            }
        }
        if (ultimo != null) {
            throw ultimo;
        }
        throw new IllegalStateException("Falha ao consultar a API.");
    }

    public static Result post(String path, String json) throws Exception {
        return request("POST", path, json);
    }

    public static Result request(String method, String path, String jsonBody) throws Exception {
        return enviar(method, getBaseUrl() + path, jsonBody, true);
    }

    /**
     * Testa se o servidor informado responde. Qualquer resposta HTTP (inclusive
     * 401/404) prova que existe um servidor atendendo no endereco; excecao fica
     * reservada a falha de rede/timeout. Nao envia o token da sessao.
     */
    public static Result ping(String urlServidor) throws Exception {
        String base = Configuracao.normalizarUrl(urlServidor);
        if (base.isEmpty()) {
            throw new IllegalArgumentException("Informe a URL do servidor.");
        }
        return enviar("GET", base + "/", null, false);
    }

    private static Result enviar(String method, String endereco, String jsonBody,
                                 boolean comToken) throws Exception {
        HttpURLConnection conn = null;
        try {
            URL url = new URL(endereco);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod(method);
            conn.setConnectTimeout(8000);
            conn.setReadTimeout(8000);
            conn.setRequestProperty("Accept", "application/json");
            // Cada chamada abre e fecha a conexão: evita reaproveitar sockets que o
            // servidor já encerrou (respostas truncadas com "unexpected end of stream").
            conn.setRequestProperty("Connection", "close");

            if (comToken && token != null && !token.isEmpty()) {
                conn.setRequestProperty("Authorization", "Bearer " + token);
            }

            if (jsonBody != null) {
                conn.setDoOutput(true);
                conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
                byte[] dados = jsonBody.getBytes(StandardCharsets.UTF_8);
                conn.setFixedLengthStreamingMode(dados.length);
                OutputStream os = conn.getOutputStream();
                try {
                    os.write(dados);
                } finally {
                    os.close();
                }
            }

            int status = conn.getResponseCode();
            InputStream is = (status >= 200 && status < 300)
                    ? conn.getInputStream()
                    : conn.getErrorStream();

            StringBuilder sb = new StringBuilder();
            if (is != null) {
                BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8));
                try {
                    String linha;
                    while ((linha = br.readLine()) != null) {
                        sb.append(linha);
                    }
                } finally {
                    br.close();
                }
            }

            return new Result(status, sb.toString());
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }
}
