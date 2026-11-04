package com.example.erp2026_mobile;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;

/**
 * Verificacao rapida de conectividade.
 *
 * <p>As telas usam isto antes de chamar a API para nao esperar os timeouts do
 * HTTP quando o aparelho esta sem rede (modo aviao, sem Wi-Fi/dados). Quando o
 * aparelho esta sem rede, o app trabalha direto com o banco local.
 */
public final class Conectividade {

    private Conectividade() { }

    /** true quando existe rede ativa com capacidade de internet. */
    public static boolean temRede(Context contexto) {
        ConnectivityManager cm = (ConnectivityManager) contexto
                .getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) {
            return true;
        }
        Network rede = cm.getActiveNetwork();
        if (rede == null) {
            return false;
        }
        NetworkCapabilities recursos = cm.getNetworkCapabilities(rede);
        return recursos != null
                && recursos.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
    }
}
