package com.example.erp2026_mobile;

import android.app.AlertDialog;
import android.content.Intent;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.TextView;

import com.google.android.material.bottomnavigation.BottomNavigationView;

import java.util.ArrayList;
import java.util.List;

/**
 * Tela inicial do app: dashboard com o resumo de vendas do mes.
 *
 * <p>Os numeros vem do cache local (preenchido por "Sincronizar dados" ou pela
 * sincronizacao automatica em segundo plano). A configuracao do servidor e a
 * sincronizacao ficam no menu de tres pontinhos da barra superior. O menu
 * inferior continua sendo a navegacao principal.
 */
public class DashboardActivity extends BaseActivity {

    /** Quantas vendas recentes aparecem no card "Últimas vendas". */
    private static final int ULTIMAS_VENDAS = 3;

    private TextView textViewWelcome;
    private TextView textViewFaturamento;
    private TextView textViewVendasMes;
    private TextView textViewAReceber;
    private TextView textViewAPagar;
    private TextView textViewOrcamentosAbertos;
    private TextView textViewClientes;
    private TextView textViewUltimasVendas;
    private TextView textViewStatusResumo;

    private boolean sincronizando;

    /** Mensagem da ultima sincronizacao (vazia quando deu tudo certo). */
    private String avisoSincronizacao = "";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        setContentView(R.layout.activity_dashboard);
        setTitle("ERP 2026 - Dashboard");

        textViewWelcome = findViewById(R.id.textViewWelcome);
        textViewFaturamento = findViewById(R.id.textViewFaturamento);
        textViewVendasMes = findViewById(R.id.textViewVendasMes);
        textViewAReceber = findViewById(R.id.textViewAReceber);
        textViewAPagar = findViewById(R.id.textViewAPagar);
        textViewOrcamentosAbertos = findViewById(R.id.textViewOrcamentosAbertos);
        textViewClientes = findViewById(R.id.textViewClientes);
        textViewUltimasVendas = findViewById(R.id.textViewUltimasVendas);
        textViewStatusResumo = findViewById(R.id.textViewStatusResumo);

        findViewById(R.id.cardOrcamentos).setOnClickListener(
                v -> abrir(OrcamentosActivity.class));
        findViewById(R.id.cardClientes).setOnClickListener(
                v -> abrir(ClientesActivity.class));
        findViewById(R.id.cardUltimasVendas).setOnClickListener(
                v -> abrir(VendasActivity.class));

        BottomNavigationView menuInferior = findViewById(R.id.bottomNavigation);
        if (menuInferior != null) {
            Navegacao.configurar(menuInferior, this, R.id.navInicio);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();

        textViewWelcome.setText("Bem-vindo, " + Sessao.nome(this) + "!");

        Configuracao atual = Configuracao.carregarAtual(this);
        if (atual == null) {
            setTitle("ERP 2026 - Dashboard");
        } else {
            setTitle("ERP 2026 - " + atual.getEmpresa());
        }

        carregarResumo();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_dashboard, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        if (id == R.id.action_atualizar) {
            carregarResumo();
            return true;
        }
        if (id == R.id.action_sincronizar) {
            abrir(SincronizacaoActivity.class);
            return true;
        }
        if (id == R.id.action_configuracao) {
            abrir(ConfiguracaoActivity.class);
            return true;
        }
        if (id == R.id.action_sair) {
            confirmarSaida();
            return true;
        }
        // Seta de voltar (e demais itens padrão) tratada pela BaseActivity.
        return super.onOptionsItemSelected(item);
    }

    private void abrir(Class<?> tela) {
        startActivity(new Intent(this, tela));
    }

    /**
     * Mostra o que esta salvo no aparelho e, havendo rede, atualiza o cache em
     * segundo plano. A tela nunca fica vazia esperando o servidor.
     */
    private void carregarResumo() {
        publicarLocal();
        sincronizarEmSegundoPlano();
    }

    /** Monta os numeros a partir do banco local. */
    private void publicarLocal() {
        BancoLocal banco = BancoLocal.get(this);
        Resumo resumo = new Resumo();

        BancoLocal.ResumoFinanceiro financeiro = banco.lerResumoFinanceiro();
        if (financeiro != null) {
            resumo.faturamentoMes = financeiro.faturamentoMes;
            resumo.vendasMes = financeiro.vendasMes;
            resumo.aReceber = financeiro.aReceber;
            resumo.aPagar = financeiro.aPagar;
            resumo.temDados = true;
        }

        resumo.orcamentosAbertos = banco.contarOrcamentos();
        resumo.clientes = banco.contarClientes();

        List<VendaLocal> vendas = banco.listarVendas();
        int limite = Math.min(ULTIMAS_VENDAS, vendas.size());
        for (int i = 0; i < limite; i++) {
            resumo.ultimasVendas.add(vendas.get(i).resumo());
            resumo.temDados = true;
        }
        if (resumo.clientes > 0 || resumo.orcamentosAbertos > 0) {
            resumo.temDados = true;
        }

        publicar(resumo);
    }

    /** Atualiza o cache completo sem travar a tela. */
    private void sincronizarEmSegundoPlano() {
        if (sincronizando || isFinishing() || !Conectividade.temRede(this)) {
            return;
        }
        sincronizando = true;

        new Thread(() -> {
            final Sincronizacao.Resultado resultado = Sincronizacao.sincronizar(this);
            runOnUiThread(() -> {
                sincronizando = false;
                if (isFinishing()) {
                    return;
                }
                if (resultado.sessaoExpirada != null
                        && Sessao.tratarSessaoExpirada(this, resultado.sessaoExpirada)) {
                    return;
                }
                avisoSincronizacao = resultado.falhas == 0
                        ? ""
                        : "Não foi possível atualizar: " + resultado.primeiraFalha
                        + ".\nUse ⋮ › Sincronizar dados para tentar de novo.";
                publicarLocal();
            });
        }).start();
    }

    private void publicar(Resumo resumo) {
        textViewFaturamento.setText(Fmt.moeda(resumo.faturamentoMes));
        textViewVendasMes.setText(resumo.vendasMes == 1
                ? "1 venda no mês"
                : resumo.vendasMes + " vendas no mês");
        textViewAReceber.setText(Fmt.moeda(resumo.aReceber));
        textViewAPagar.setText(Fmt.moeda(resumo.aPagar));
        textViewOrcamentosAbertos.setText(String.valueOf(resumo.orcamentosAbertos));
        textViewClientes.setText(String.valueOf(resumo.clientes));

        if (resumo.ultimasVendas.isEmpty()) {
            textViewUltimasVendas.setText("Nenhuma venda registrada ainda.");
        } else {
            StringBuilder texto = new StringBuilder();
            for (int i = 0; i < resumo.ultimasVendas.size(); i++) {
                if (i > 0) {
                    texto.append("\n\n");
                }
                texto.append(resumo.ultimasVendas.get(i));
            }
            textViewUltimasVendas.setText(texto.toString());
        }

        if (!resumo.temDados) {
            textViewStatusResumo.setText("Ainda não há dados salvos no aparelho.\n"
                    + "Use ⋮ › Sincronizar dados para baixar.");
            textViewStatusResumo.setVisibility(View.VISIBLE);
        } else if (!avisoSincronizacao.isEmpty()) {
            textViewStatusResumo.setText(avisoSincronizacao);
            textViewStatusResumo.setVisibility(View.VISIBLE);
        } else {
            textViewStatusResumo.setVisibility(View.GONE);
        }
    }

    private void confirmarSaida() {
        new AlertDialog.Builder(this)
                .setTitle("Sair")
                .setMessage("Deseja encerrar a sessão?")
                .setNegativeButton("Cancelar", null)
                .setPositiveButton("Sair", (dialog, which) -> {
                    Sessao.encerrar(this);
                    Sessao.irParaLogin(this);
                })
                .show();
    }

    /** Números exibidos no dashboard (preenchidos a partir do cache local). */
    private static final class Resumo {
        double faturamentoMes;
        int vendasMes;
        double aReceber;
        double aPagar;
        int orcamentosAbertos;
        int clientes;
        boolean temDados;
        final List<String> ultimasVendas = new ArrayList<>();
    }
}
