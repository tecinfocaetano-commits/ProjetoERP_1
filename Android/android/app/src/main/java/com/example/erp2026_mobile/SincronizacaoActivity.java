package com.example.erp2026_mobile;

import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

/**
 * Tela "Sincronizar dados" (menu do Dashboard).
 *
 * <p>Mostra a empresa e o usuario do token, o que sera baixado, a ultima
 * sincronizacao de cada conjunto e as alteracoes pendentes de envio. O botao
 * "Baixar tudo" roda a rodada completa: envia a fila e baixa clientes,
 * produtos, orcamentos, vendas, estoque e financeiro da empresa do usuario.
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
    private Button buttonBaixarTudo;
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
        buttonBaixarTudo = findViewById(R.id.buttonBaixarTudo);
        progressBarSincronizacao = findViewById(R.id.progressBarSincronizacao);

        buttonBaixarTudo.setOnClickListener(v -> sincronizar());
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
    }

    private String linha(String nome, int quantidade, String conjunto) {
        return nome + ": " + quantidade + " salvo(s)  ·  última: "
                + Sincronizacao.ultimaSincronizacaoTexto(this, conjunto);
    }

    private void sincronizar() {
        if (sincronizando) {
            return;
        }
        if (!Conectividade.temRede(this)) {
            Toast.makeText(this,
                    "Sem conexão.\nOs dados continuam salvos no aparelho.",
                    Toast.LENGTH_LONG).show();
            return;
        }

        sincronizando = true;
        buttonBaixarTudo.setEnabled(false);
        buttonBaixarTudo.setText("Sincronizando...");
        progressBarSincronizacao.setVisibility(View.VISIBLE);
        textViewResultado.setVisibility(View.GONE);

        new Thread(() -> {
            final Sincronizacao.Resultado resultado = Sincronizacao.sincronizar(this);
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
        }).start();
    }
}
