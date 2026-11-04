package com.example.erp2026_mobile;

import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

/**
 * Resumo financeiro e contas em aberto.
 *
 * <p>Os totais e as contas vem do cache local, preenchido pela sincronizacao.
 * Quando ha rede, a tela atualiza o cache sozinha na primeira exibicao.
 */
public class FinanceiroActivity extends BaseListaActivity {

    private TextView textViewTotalReceber;
    private TextView textViewTotalPagar;

    private String resumoReceber = "A Receber: -";
    private String resumoPagar = "A Pagar: -";

    private boolean sincronizando;
    private boolean sincronizouNestaVisita;

    @Override
    protected int layoutId() {
        return R.layout.activity_financeiro;
    }

    @Override
    protected String titulo() {
        return "Financeiro";
    }

    @Override
    protected String textoVazio() {
        return "Nenhuma conta em aberto salva no aparelho.\n"
                + "Use ⋮ › Sincronizar dados para baixar.";
    }

    @Override
    protected int itemMenuAtual() {
        return R.id.navFinanceiro;
    }

    @Override
    protected void onResume() {
        sincronizouNestaVisita = false;
        super.onResume();
    }

    @Override
    protected void aoCriar() {
        textViewTotalReceber = findViewById(R.id.textViewTotalReceber);
        textViewTotalPagar = findViewById(R.id.textViewTotalPagar);
    }

    @Override
    protected void aoPublicar() {
        textViewTotalReceber.setText(resumoReceber);
        textViewTotalPagar.setText(resumoPagar);

        if (!sincronizouNestaVisita && Conectividade.temRede(this)) {
            sincronizouNestaVisita = true;
            sincronizar();
        }
    }

    @Override
    protected List<String> buscar() throws Exception {
        BancoLocal banco = BancoLocal.get(this);

        // Primeira carga (cache vazio): espera o download para nao abrir vazio.
        if (banco.lerResumoFinanceiro() == null && Conectividade.temRede(this)) {
            try {
                Sincronizacao.baixarResumoFinanceiro(this);
                Sincronizacao.baixarContasReceber(this);
                Sincronizacao.baixarContasPagar(this);
            } catch (Exception ignorado) {
                // segue com o que existe localmente
            }
        }

        BancoLocal.ResumoFinanceiro resumo = banco.lerResumoFinanceiro();
        if (resumo != null) {
            resumoReceber = "A Receber: " + Fmt.moeda(resumo.aReceber);
            resumoPagar = "A Pagar: " + Fmt.moeda(resumo.aPagar);
        } else {
            resumoReceber = "A Receber: -";
            resumoPagar = "A Pagar: -";
        }

        List<String> itens = new ArrayList<>();
        for (ContaLocal conta : banco.listarContasReceber()) {
            itens.add(conta.resumo(true));
        }
        for (ContaLocal conta : banco.listarContasPagar()) {
            itens.add(conta.resumo(false));
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
                Sincronizacao.baixarResumoFinanceiro(this);
                Sincronizacao.baixarContasReceber(this);
                Sincronizacao.baixarContasPagar(this);
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
