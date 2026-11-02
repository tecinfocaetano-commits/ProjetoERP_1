package com.example.erp2026_mobile;

import android.app.Activity;
import android.content.Intent;

import com.google.android.material.bottomnavigation.BottomNavigationView;

/**
 * Navegação inferior comum às telas principais.
 *
 * <p>Cada tela inclui o layout {@code include_bottom_nav} (id
 * {@code bottomNavigation}) e informa qual item a representa. O item da
 * própria tela fica selecionado e não reabre a Activity; os demais abrem a
 * tela correspondente, reutilizando a instância que já estiver na pilha.
 */
public final class Navegacao {

    private Navegacao() { }

    /** Liga o menu inferior à tela atual. {@code itemAtual} deve ser um R.id.navXxx. */
    public static void configurar(BottomNavigationView menu, Activity atividade, int itemAtual) {
        menu.setSelectedItemId(itemAtual);

        menu.setOnItemSelectedListener(item -> {
            int id = item.getItemId();
            if (id == itemAtual) {
                return true; // já estamos nesta tela
            }
            Class<?> destino = destino(id);
            if (destino == null) {
                return false;
            }
            Intent i = new Intent(atividade, destino);
            // Reaproveita a tela se ela já estiver na pilha (não empilha infinito)
            i.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
            atividade.startActivity(i);
            return false;
        });
    }

    private static Class<?> destino(int id) {
        if (id == R.id.navInicio) {
            return DashboardActivity.class;
        }
        if (id == R.id.navClientes) {
            return ClientesActivity.class;
        }
        if (id == R.id.navEstoque) {
            return EstoqueActivity.class;
        }
        if (id == R.id.navVendas) {
            return VendasActivity.class;
        }
        if (id == R.id.navFinanceiro) {
            return FinanceiroActivity.class;
        }
        return null;
    }

    /** Atalho usado pelo menu e pela tela de vendas. */
    public static void abrirOrcamentos(Activity atividade) {
        atividade.startActivity(new Intent(atividade, OrcamentosActivity.class));
    }
}
