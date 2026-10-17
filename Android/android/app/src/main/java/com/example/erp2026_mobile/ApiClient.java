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
 */
public final class ApiClient {

    /** 10.0.2.2 e o alias do "localhost" da maquina host, visto de dentro do emulador. */
    public static final String BASE_URL = "http://10.0.2.2:9000";

    private static String token = null;

    private ApiClient() { }

    public static void setToken(String valor) { token = valor; }
    public static String getToken() { return token; }

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
        return request("GET", path, null);
    }

    public static Result post(String path, String json) throws Exception {
        return request("POST", path, json);
    }

    public static Result request(String method, String path, String jsonBody) throws Exception {
        HttpURLConnection conn = null;
        try {
            URL url = new URL(BASE_URL + path);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod(method);
            conn.setConnectTimeout(8000);
            conn.setReadTimeout(8000);
            conn.setRequestProperty("Accept", "application/json");

            if (token != null && !token.isEmpty()) {
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
