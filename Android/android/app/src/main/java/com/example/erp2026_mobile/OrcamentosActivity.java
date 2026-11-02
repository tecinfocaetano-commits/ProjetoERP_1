package com.example.erp2026_mobile;

import android.app.AlertDialog;
import android.content.Intent;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Orçamentos em aberto (PEDIDO_VENDA com STATUS 'O').
 *
 * <p>Lista os orçamentos e permite abrir um novo ou converter o selecionado
 * em pedido. A conversão é feita pela API, que também valida se o orçamento
 * ainda está em aberto.
 */
public class OrcamentosActivity extends BaseListaActivity {

    private final List<Long> ids = new ArrayList<>();
    private boolean convertendo;

    @Override
    protected int layoutId() {
        return R.layout.activity_orcamentos;
    }

    @Override
    protected String titulo() {
        return "Orçamentos";
    }

    @Override
    protected String textoVazio() {
        return "Nenhum orçamento em aberto.\nUse \"Novo orçamento\" para criar o primeiro.";
    }

    @Override
    protected int itemMenuAtual() {
        return R.id.navVendas;
    }

    @Override
    protected void aoCriar() {
        findViewById(R.id.buttonNovoOrcamento).setOnClickListener(
                v -> startActivity(new Intent(this, InserirOrcamentoActivity.class)));
    }

    @Override
    protected List<String> buscar() throws Exception {
        ApiClient.Result r = ApiClient.get("/api/orcamentos");
        if (!r.ok()) {
            throw new ApiException(r);
        }

        JSONArray arr = new JSONArray(r.body);
        List<String> linhas = new ArrayList<>();
        ids.clear();

        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            ids.add(o.optLong("id"));

            String data = Fmt.limpar(o.optString("data_emissao"));
            int quantidadeItens = o.optInt("itens", 0);

            StringBuilder linha = new StringBuilder("Orçamento ");
            linha.append(Fmt.limpar(o.optString("numero")));
            linha.append(" - ").append(Fmt.limpar(o.optString("cliente")));
            linha.append("\n").append(Fmt.moeda(o.optDouble("total", 0)));
            if (!data.isEmpty()) {
                linha.append("   Emissão: ").append(data);
            }
            linha.append("\n").append(quantidadeItens).append(" item(ns)");
            linhas.add(linha.toString());
        }
        return linhas;
    }

    @Override
    protected void aoSelecionarItem(int posicao, String texto) {
        if (posicao < 0 || posicao >= ids.size()) {
            return;
        }
        final long id = ids.get(posicao);

        new AlertDialog.Builder(this)
                .setTitle("Orçamento")
                .setMessage(texto + "\n\nDeseja converter este orçamento em pedido?")
                .setNegativeButton("Fechar", null)
                .setPositiveButton("Converter", (dialog, which) -> converter(id))
                .show();
    }

    private void converter(final long id) {
        if (convertendo) {
            return;
        }
        convertendo = true;

        new Thread(() -> {
            try {
                final ApiClient.Result r = ApiClient.post("/api/orcamentos/" + id + "/converter", null);

                runOnUiThread(() -> {
                    convertendo = false;

                    if (Sessao.tratarSessaoExpirada(OrcamentosActivity.this, r)) {
                        return;
                    }
                    if (r.ok()) {
                        Toast.makeText(OrcamentosActivity.this,
                                "Orçamento convertido em pedido.",
                                Toast.LENGTH_LONG).show();
                        recarregar();
                    } else if (r.status == 409) {
                        Toast.makeText(OrcamentosActivity.this,
                                "Este orçamento já foi convertido.",
                                Toast.LENGTH_LONG).show();
                        recarregar();
                    } else {
                        Toast.makeText(OrcamentosActivity.this,
                                "Não foi possível converter (HTTP " + r.status + ").",
                                Toast.LENGTH_LONG).show();
                    }
                });
            } catch (final Exception e) {
                runOnUiThread(() -> {
                    convertendo = false;
                    Toast.makeText(OrcamentosActivity.this,
                            "Falha de conexão.\nVerifique se a API está no ar.",
                            Toast.LENGTH_LONG).show();
                });
            }
        }).start();
    }
}
