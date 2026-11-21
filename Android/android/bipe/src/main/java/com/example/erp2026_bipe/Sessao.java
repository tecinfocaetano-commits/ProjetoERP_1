package com.example.erp2026_bipe;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

/**
 * Sessão do operador: URL do servidor, token JWT e nome — gravados em
 * SharedPreferences para sobreviver ao app ser fechado pelo Android.
 */
public final class Sessao {

    private static final String PREFS = "erp2026_bipe";
    private static final String K_URL = "urlServidor";
    private static final String K_TOKEN = "token";
    private static final String K_NOME = "nome";
    private static final String K_USUARIO = "usuario";
    private static final String K_EMPRESA = "empresa_id";

    private Sessao() { }

    private static SharedPreferences prefs(Context contexto) {
        return contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public static void configurar(Context contexto, String url) {
        prefs(contexto).edit().putString(K_URL, url).apply();
    }

    public static String urlServidor(Context contexto) {
        return prefs(contexto).getString(K_URL, "");
    }

    /** Recarrega o token salvo para a memória do ApiClient. */
    public static void restaurar(Context contexto) {
        ApiClient.configurar(urlServidor(contexto));
        String t = prefs(contexto).getString(K_TOKEN, "");
        if (t != null && !t.isEmpty()) {
            ApiClient.setToken(t);
        }
    }

    public static void guardar(Context contexto, String token,
                               String usuario, String nome, long empresaId) {
        ApiClient.setToken(token);
        prefs(contexto).edit()
                .putString(K_TOKEN, token)
                .putString(K_USUARIO, usuario)
                .putString(K_NOME, nome)
                .putLong(K_EMPRESA, empresaId)
                .apply();
    }

    /** Empresa do último login (0 = nunca logado). Usado para zerar
        o histórico local quando o aparelho troca de empresa. */
    public static long empresaIdSalvo(Context contexto) {
        return prefs(contexto).getLong(K_EMPRESA, 0);
    }

    public static void encerrar(Context contexto) {
        ApiClient.setToken(null);
        prefs(contexto).edit()
                .remove(K_TOKEN)
                .remove(K_NOME)
                .remove(K_USUARIO)
                .apply();
    }

    public static boolean ativa(Context contexto) {
        restaurar(contexto);
        String token = ApiClient.getToken();
        return token != null && !token.isEmpty();
    }

    public static String nome(Context contexto) {
        return prefs(contexto).getString(K_NOME, "Operador");
    }

    /** Volta ao login limpando a pilha de telas. */
    public static void irParaLogin(Activity atividade) {
        Intent i = new Intent(atividade, LoginActivity.class);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        atividade.startActivity(i);
        atividade.finish();
    }
}
