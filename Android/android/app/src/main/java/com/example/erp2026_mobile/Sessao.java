package com.example.erp2026_mobile;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

/**
 * Sessão do usuário no app.
 *
 * O token fica gravado em SharedPreferences para sobreviver ao app ser encerrado
 * pelo Android em segundo plano (o usuário volta direto para o menu, sem relogar).
 */
public final class Sessao {

    private static final String PREFS = "erp2026";
    private static final String K_TOKEN = "token";
    private static final String K_NOME = "nome";

    private Sessao() { }

    private static SharedPreferences prefs(Context contexto) {
        return contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    /** Recarrega o token salvo para a memória. */
    public static void restaurar(Context contexto) {
        if (ApiClient.getToken() == null || ApiClient.getToken().isEmpty()) {
            ApiClient.setToken(prefs(contexto).getString(K_TOKEN, ""));
        }
    }

    public static void guardar(Context contexto, String token, String nome) {
        ApiClient.setToken(token);
        prefs(contexto).edit()
                .putString(K_TOKEN, token)
                .putString(K_NOME, nome)
                .apply();
    }

    public static void encerrar(Context contexto) {
        ApiClient.setToken(null);
        prefs(contexto).edit().remove(K_TOKEN).apply();
    }

    public static boolean ativa(Context contexto) {
        restaurar(contexto);
        String token = ApiClient.getToken();
        return token != null && !token.isEmpty();
    }

    public static String nome(Context contexto) {
        return prefs(contexto).getString(K_NOME, "Usuário");
    }

    /** Leva de volta ao login limpando a pilha de telas. */
    public static void irParaLogin(Activity atividade) {
        Intent i = new Intent(atividade, MainActivity.class);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        atividade.startActivity(i);
        atividade.finish();
    }

    /**
     * Se a resposta for 401 (token inválido/expirado) encerra a sessão e volta ao
     * login. Retorna true quando tratou, para o chamador não exibir erro técnico.
     */
    public static boolean tratarSessaoExpirada(Activity atividade, ApiClient.Result resposta) {
        if (resposta != null && resposta.status == 401) {
            encerrar(atividade);
            irParaLogin(atividade);
            return true;
        }
        return false;
    }
}
