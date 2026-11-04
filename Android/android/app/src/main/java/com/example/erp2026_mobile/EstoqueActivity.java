package com.example.erp2026_mobile;

import java.util.ArrayList;
import java.util.List;

/**
 * Posicao de estoque dos produtos.
 *
 * <p>A lista vem do cache local, preenchido pela sincronizacao. Quando ha
 * rede, a tela atualiza o cache sozinha na primeira exibicao.
 */
public class EstoqueActivity extends BaseListaActivity {

    private boolean sincronizando;
    private boolean sincronizouNestaVisita;

    @Override
    protected int layoutId() {
        return R.layout.activity_estoque;
    }

    @Override
    protected String titulo() {
        return "Estoque";
    }

    @Override
    protected String textoVazio() {
        return "Nenhum produto com estoque salvo no aparelho.\n"
                + "Use ⋮ › Sincronizar dados para baixar.";
    }

    @Override
    protected int itemMenuAtual() {
        return R.id.navEstoque;
    }

    @Override
    protected void onResume() {
        sincronizouNestaVisita = false;
        super.onResume();
    }

    @Override
    protected void aoPublicar() {
        if (!sincronizouNestaVisita && Conectividade.temRede(this)) {
            sincronizouNestaVisita = true;
            sincronizar();
        }
    }

    @Override
    protected List<String> buscar() throws Exception {
        BancoLocal banco = BancoLocal.get(this);

        // Primeira carga (cache vazio): espera o download para nao abrir vazio.
        if (banco.contarEstoque() == 0 && Conectividade.temRede(this)) {
            try {
                Sincronizacao.baixarEstoque(this);
            } catch (Exception ignorado) {
                // segue com o que existe localmente
            }
        }

        List<String> itens = new ArrayList<>();
        for (EstoqueLocal item : banco.listarEstoque()) {
            itens.add(item.resumo());
        }
        return itens;
    }

    private void sincronizar() {
        if (sincronizando || isFinishing()) {
            return;
        }
        sincronizando = true;

        new Thread(() -> {
            try {
                Sincronizacao.baixarEstoque(this);
            } catch (Sincronizacao.ErroApi e) {
                if (e.resposta.status == 401) {
                    runOnUiThread(() -> Sessao.tratarSessaoExpirada(this, e.resposta));
                    sincronizando = false;
                    return;
                }
            } catch (Exception ignorado) {
                // mantem o cache anterior
            }
            sincronizando = false;
            runOnUiThread(() -> {
                if (!isFinishing()) {
                    recarregar();
                }
            });
        }).start();
    }
}
