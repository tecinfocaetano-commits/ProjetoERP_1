package com.example.erp2026_mobile;

import android.os.Bundle;
import android.view.MenuItem;

import androidx.appcompat.app.ActionBar;
import androidx.appcompat.app.AppCompatActivity;

/**
 * Base de todas as telas do app.
 *
 * <p>Liga a seta de voltar na barra superior. Ao tocá-la a tela atual é
 * encerrada ({@link #finish()}), devolvendo o usuário à tela anterior da
 * pilha. A tela de login não usa esta base (não há para onde voltar).
 */
public abstract class BaseActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        habilitarVoltar();
    }

    /** Telas raiz podem desligar a seta; o padrão é exibi-la. */
    protected boolean temVoltar() {
        return true;
    }

    private void habilitarVoltar() {
        if (!temVoltar()) {
            return;
        }
        ActionBar barra = getSupportActionBar();
        if (barra != null) {
            barra.setDisplayHomeAsUpEnabled(true);
            barra.setDisplayShowHomeEnabled(true);
        }
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == android.R.id.home) {
            finish();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }
}
