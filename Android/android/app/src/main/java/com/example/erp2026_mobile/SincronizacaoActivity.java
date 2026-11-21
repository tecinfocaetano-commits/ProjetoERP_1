package com.example.erp2026_mobile;

import android.os.Bundle;
import androidx.core.content.ContextCompat;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

/**
 * Tela "Sincronizar dados" (menu do Dashboard).
 *
 * <p>Mostra a empresa e o usuario do token, o que sera baixado, a ultima
 * sincronizacao de cada conjunto e as alteracoes pendentes de envio. O botao
 * "Baixar tudo" roda a rodada completa: envia a fila e baixa clientes,
 * produtos, orcamentos, vendas, estoque e financeiro da empresa do usuario.
 *
 * <p>F9: o painel "Fila de envio" mostra tentativas, proxima tentativa e falhas
 * definitivas. "Tentar novamente" libera itens em backoff (nao apaga o
 * historico); "Limpar falhas" remove so a dead-letter.
 */
public class SincronizacaoActivity extends BaseActivity {

    private TextView textViewEmpresa;
    private TextView textViewUsuario;
    private TextView textViewClientes;
    private TextView textViewProdutos;
    private TextView textViewOrcamentos;
    private TextView textViewVendas;
    private TextView textViewEstoque;
    private TextView textViewFinanceiro;
    private TextView textViewPendencias;
    private TextView textViewResultado;
    private TextView textViewFilaResumo;
    private LinearLayout containerFila;
    private Button buttonBaixarTudo;
    private Button buttonTentarFila;
    private Button buttonLimparFalhas;
    private ProgressBar progressBarSincronizacao;

    private boolean sincronizando;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        setContentView(R.layout.activity_sincronizacao);
        setTitle("Sincronizar dados");

        textViewEmpresa = findViewById(R.id.textViewEmpresa);
        textViewUsuario = findViewById(R.id.textViewUsuario);
        textViewClientes = findViewById(R.id.textViewClientes);
        textViewProdutos = findViewById(R.id.textViewProdutos);
        textViewOrcamentos = findViewById(R.id.textViewOrcamentos);
        textViewVendas = findViewById(R.id.textViewVendas);
        textViewEstoque = findViewById(R.id.textViewEstoque);
        textViewFinanceiro = findViewById(R.id.textViewFinanceiro);
        textViewPendencias = findViewById(R.id.textViewPendencias);
        textViewResultado = findViewById(R.id.textViewResultado);
        textViewFilaResumo = findViewById(R.id.textViewFilaResumo);
        containerFila = findViewById(R.id.containerFila);
        buttonBaixarTudo = findViewById(R.id.buttonBaixarTudo);
        buttonTentarFila = findViewById(R.id.buttonTentarFila);
        buttonLimparFalhas = findViewById(R.id.buttonLimparFalhas);
        progressBarSincronizacao = findViewById(R.id.progressBarSincronizacao);

        buttonBaixarTudo.setOnClickListener(v -> sincronizar());
        buttonTentarFila.setOnClickListener(v -> tentarNovamente());
        buttonLimparFalhas.setOnClickListener(v -> limparFalhas());
    }

    @Override
    protected void onResume() {
        super.onResume();
        preencher();
    }

    /** Atualiza os textos da tela com o que ja existe no aparelho. */
    private void preencher() {
        Configuracao configuracao = Configuracao.carregarAtual(this);
        textViewEmpresa.setText("Empresa: "
                + (configuracao == null ? "-" : configuracao.getEmpresa()));
        textViewUsuario.setText("Usuário: " + Sessao.nome(this));

        BancoLocal banco = BancoLocal.get(this);
        textViewClientes.setText(linha("Clientes", banco.contarClientes(),
                Sincronizacao.CONJUNTO_CLIENTES));
        textViewProdutos.setText(linha("Produtos", banco.contarProdutos(),
                Sincronizacao.CONJUNTO_PRODUTOS));
        textViewOrcamentos.setText(linha("Orçamentos em aberto",
                banco.contarOrcamentos(), Sincronizacao.CONJUNTO_ORCAMENTOS));
        textViewVendas.setText(linha("Vendas", banco.contarVendas(),
                Sincronizacao.CONJUNTO_VENDAS));
        textViewEstoque.setText(linha("Estoque", banco.contarEstoque(),
                Sincronizacao.CONJUNTO_ESTOQUE));
        textViewFinanceiro.setText(linha("Financeiro",
                banco.contarContasReceber() + banco.contarContasPagar(),
                Sincronizacao.CONJUNTO_FINANCEIRO));

        int pendentes = Sincronizacao.pendentes(this);
        if (pendentes == 0) {
            textViewPendencias.setText("Nenhuma alteração pendente de envio.");
        } else if (pendentes == 1) {
            textViewPendencias.setText("1 alteração pendente de envio ao servidor.");
        } else {
            textViewPendencias.setText(pendentes
                    + " alterações pendentes de envio ao servidor.");
        }
        preencherFila(banco);
    }

    private void preencherFila(BancoLocal banco) {
        BancoLocal.ResumoFila fila = banco.resumoFila();
        if (fila.total() == 0) {
            textViewFilaResumo.setText("Nenhum item na fila.");
        } else {
            textViewFilaResumo.setText(fila.total() + " item(ns): "
                    + fila.naFila + " pronto(s), "
                    + fila.aguardando + " aguardando retry, "
                    + fila.deadLetter + " falha(s) definitiva(s).");
        }

        containerFila.removeAllViews();
        List<ItemOutbox> itens = banco.fila(20);
        if (itens.isEmpty()) {
            containerFila.addView(linhaFila("Nada aguardando envio."));
        } else {
            for (ItemOutbox item : itens) {
                containerFila.addView(linhaFila(item.descricao()));
            }
            if (fila.total() > itens.size()) {
                containerFila.addView(linhaFila("... e mais "
                        + (fila.total() - itens.size()) + " item(ns)."));
            }
        }
        buttonTentarFila.setEnabled(fila.total() > 0 && !sincronizando);
        buttonLimparFalhas.setEnabled(fila.deadLetter > 0 && !sincronizando);
    }

    private TextView linhaFila(String texto) {
        TextView tv = new TextView(this);
        tv.setText(texto);
        tv.setTextSize(13f);
        tv.setTextColor(ContextCompat.getColor(this, R.color.erp_on_surface_variant));
        tv.setPadding(0, 6, 0, 6);
        return tv;
    }

    private String linha(String nome, int quantidade, String conjunto) {
        return nome + ": " + quantidade + " salvo(s)  ·  última: "
                + Sincronizacao.ultimaSincronizacaoTexto(this, conjunto);
    }

    private void sincronizar() {
        if (sincronizando || !temRedeOuAvisa()) {
            return;
        }
        iniciar();
        new Thread(() -> finalizar(Sincronizacao.sincronizar(this))).start();
    }

    /** Libera itens em backoff e roda uma rodada completa. */
    private void tentarNovamente() {
        if (sincronizando || !temRedeOuAvisa()) {
            return;
        }
        iniciar();
        new Thread(() -> {
            BancoLocal banco = BancoLocal.get(this);
            for (ItemOutbox item : banco.fila(500)) {
                if (!ItemOutbox.STATUS_DEAD.equals(item.status)) {
                    banco.requererTentativa(item.id);
                }
            }
            finalizar(Sincronizacao.sincronizar(this));
        }).start();
    }

    private void limparFalhas() {
        int removidas = BancoLocal.get(this).limparDeadLetter();
        Toast.makeText(this,
                removidas + " falha(s) definitiva(s) removida(s) do aparelho.",
                Toast.LENGTH_SHORT).show();
        preencher();
    }

    private boolean temRedeOuAvisa() {
        if (Conectividade.temRede(this)) {
            return true;
        }
        Toast.makeText(this,
                "Sem conexão.\nOs dados continuam salvos no aparelho.",
                Toast.LENGTH_LONG).show();
        return false;
    }

    private void iniciar() {
        sincronizando = true;
        buttonBaixarTudo.setEnabled(false);
        buttonTentarFila.setEnabled(false);
        buttonLimparFalhas.setEnabled(false);
        buttonBaixarTudo.setText("Sincronizando...");
        progressBarSincronizacao.setVisibility(View.VISIBLE);
        textViewResultado.setVisibility(View.GONE);
    }

    private void finalizar(Sincronizacao.Resultado resultado) {
        runOnUiThread(() -> {
            if (isFinishing()) {
                return;
            }
            sincronizando = false;
            buttonBaixarTudo.setEnabled(true);
            buttonBaixarTudo.setText("Baixar tudo");
            progressBarSincronizacao.setVisibility(View.GONE);

            if (resultado.sessaoExpirada != null) {
                Sessao.tratarSessaoExpirada(this, resultado.sessaoExpirada);
                return;
            }

            textViewResultado.setText(resultado.resumo());
            textViewResultado.setVisibility(View.VISIBLE);
            preencher();
        });
    }
}
