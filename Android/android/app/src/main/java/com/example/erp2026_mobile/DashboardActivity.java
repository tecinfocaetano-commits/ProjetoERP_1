package com.example.erp2026_mobile;

import android.app.AlertDialog;
import android.content.Intent;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.TextView;

import com.google.android.material.bottomnavigation.BottomNavigationView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Tela inicial do app: dashboard com o resumo de vendas do mês.
 *
 * <p>No lugar dos antigos botões, mostra os números da empresa (faturamento,
 * contas em aberto, orçamentos, clientes e as últimas vendas). A configuração
 * do servidor/empresa e a saída ficam no menu de três pontinhos da barra
 * superior. O menu inferior continua sendo a navegação principal.
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

    private boolean carregando;

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
     * Busca os números do dashboard em segundo plano.
     *
     * <p>As chamadas são independentes: se uma falhar, as demais ainda são
     * exibidas e a falha aparece no rodapé, sem apagar o que já carregou.
     */
    private void carregarResumo() {
        if (carregando) {
            return;
        }
        carregando = true;

        new Thread(() -> {
            final Resumo resumo = new Resumo();

            try {
                ApiClient.Result financeiro = ApiClient.get("/api/financeiro");
                resumo.verificar(financeiro);
                if (financeiro.ok()) {
                    JSONObject totais = new JSONObject(financeiro.body);
                    resumo.faturamentoMes = totais.optDouble("faturamento_mes", 0);
                    resumo.vendasMes = totais.optInt("vendas_mes", 0);
                    resumo.aReceber = totais.optDouble("a_receber", 0);
                    resumo.aPagar = totais.optDouble("a_pagar", 0);
                } else {
                    resumo.falhou("resumo financeiro");
                }
            } catch (Exception e) {
                resumo.falhou("resumo financeiro");
            }

            try {
                ApiClient.Result orcamentos = ApiClient.get("/api/orcamentos");
                resumo.verificar(orcamentos);
                if (orcamentos.ok()) {
                    resumo.orcamentosAbertos = new JSONArray(orcamentos.body).length();
                } else {
                    resumo.falhou("orçamentos");
                }
            } catch (Exception e) {
                resumo.falhou("orçamentos");
            }

            try {
                ApiClient.Result clientes = ApiClient.get("/api/clientes");
                resumo.verificar(clientes);
                if (clientes.ok()) {
                    resumo.clientes = new JSONArray(clientes.body).length();
                } else {
                    resumo.falhou("clientes");
                }
            } catch (Exception e) {
                resumo.falhou("clientes");
            }

            try {
                ApiClient.Result vendas = ApiClient.get("/api/vendas");
                resumo.verificar(vendas);
                if (vendas.ok()) {
                    JSONArray arr = new JSONArray(vendas.body);
                    int limite = Math.min(ULTIMAS_VENDAS, arr.length());
                    for (int i = 0; i < limite; i++) {
                        resumo.ultimasVendas.add(linhaVenda(arr.getJSONObject(i)));
                    }
                } else {
                    resumo.falhou("vendas");
                }
            } catch (Exception e) {
                resumo.falhou("vendas");
            }

            runOnUiThread(() -> {
                carregando = false;
                if (resumo.naoAutorizado != null
                        && Sessao.tratarSessaoExpirada(this, resumo.naoAutorizado)) {
                    return;
                }
                publicar(resumo);
            });
        }).start();
    }

    /** Monta as duas linhas de uma venda recente. */
    private static String linhaVenda(JSONObject venda) {
        String numero = Fmt.limpar(venda.optString("numero"));
        String cliente = Fmt.limpar(venda.optString("cliente"));
        String data = Fmt.limpar(venda.optString("data_emissao"));
        String status = Fmt.limpar(venda.optString("status"));

        StringBuilder linha = new StringBuilder();
        linha.append(numero.isEmpty() ? "Pedido" : numero);
        if (!cliente.isEmpty()) {
            linha.append(" - ").append(cliente);
        }
        linha.append("\n").append(Fmt.moeda(venda.optDouble("total", 0)));
        if (!data.isEmpty()) {
            linha.append("   Emissão: ").append(data);
        }
        if (!status.isEmpty()) {
            linha.append("   ").append(status);
        }
        return linha.toString();
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

        if (resumo.falhas.isEmpty()) {
            textViewStatusResumo.setVisibility(View.GONE);
        } else {
            textViewStatusResumo.setText("Não foi possível carregar: "
                    + junta(resumo.falhas) + ".\nToque em ⋮ › Atualizar resumo para tentar de novo.");
            textViewStatusResumo.setVisibility(View.VISIBLE);
        }
    }

    private static String junta(List<String> partes) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < partes.size(); i++) {
            if (i > 0) {
                sb.append(", ");
            }
            sb.append(partes.get(i));
        }
        return sb.toString();
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

    /** Números exibidos no dashboard (preenchidos em segundo plano). */
    private static final class Resumo {
        double faturamentoMes;
        int vendasMes;
        double aReceber;
        double aPagar;
        int orcamentosAbertos;
        int clientes;
        final List<String> ultimasVendas = new ArrayList<>();
        final List<String> falhas = new ArrayList<>();
        ApiClient.Result naoAutorizado;

        void verificar(ApiClient.Result resultado) {
            if (resultado.status == 401 && naoAutorizado == null) {
                naoAutorizado = resultado;
            }
        }

        void falhou(String parte) {
            falhas.add(parte);
        }
    }
}
