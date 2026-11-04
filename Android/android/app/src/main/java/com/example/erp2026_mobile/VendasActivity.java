package com.example.erp2026_mobile;

import java.util.ArrayList;
import java.util.List;

/**
 * Pedidos de venda registrados.
 *
 * <p>A lista vem do cache local, preenchido pela sincronizacao. Quando ha
 * rede, a tela atualiza o cache sozinha na primeira exibicao, sem travar a
 * lista que ja apareceu com os dados do aparelho.
 */
public class VendasActivity extends BaseListaActivity {

    private boolean sincronizando;
    private boolean sincronizouNestaVisita;

    @Override
    protected int layoutId() {
        return R.layout.activity_vendas;
    }

    @Override
    protected String titulo() {
        return "Vendas";
    }

    @Override
    protected String textoVazio() {
        return "Nenhuma venda salva no aparelho.\nUse ⋮ › Sincronizar dados para baixar.";
    }

    @Override
    protected int itemMenuAtual() {
        return R.id.navVendas;
    }

    @Override
    protected boolean temBusca() {
        return true;
    }

    @Override
    protected String dicaBusca() {
        return "Pesquisar vendas";
    }

    @Override
    protected void onResume() {
        sincronizouNestaVisita = false;
        super.onResume();
    }

    @Override
    protected void aoCriar() {
        findViewById(R.id.buttonOrcamentos).setOnClickListener(v -> Navegacao.abrirOrcamentos(this));
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
        if (banco.contarVendas() == 0 && Conectividade.temRede(this)) {
            try {
                Sincronizacao.baixarVendas(this);
            } catch (Exception ignorado) {
                // segue com o que existe localmente
            }
        }

        List<String> itens = new ArrayList<>();
        for (VendaLocal venda : banco.listarVendas()) {
            itens.add(venda.resumo());
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
                Sincronizacao.baixarVendas(this);
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
