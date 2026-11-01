package com.example.erp2026_mobile;

import android.app.Application;

import com.google.android.material.color.DynamicColors;

/**
 * Aplicacao do ERP 2026 mobile.
 *
 * Aplica o Material You (cores dinamicas) em todo o app quando o aparelho
 * suporta (Android 12+). Abaixo do 12 o tema estatico de res/values
 * permanece - nenhuma logica de tela e afetada, so a paleta.
 */
public class App extends Application {

    @Override
    public void onCreate() {
        super.onCreate();
        DynamicColors.applyToActivitiesIfAvailable(this);
        // Empresa configurada (D9): deixa o ApiClient apontado para o
        // servidor certo antes de qualquer tela chamar a API.
        Configuracao.aplicarNoApi(this);
    }
}
