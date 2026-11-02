package com.example.erp2026_mobile;

import android.os.Bundle;
import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONObject;

/** Relação detalhada dos clientes (nome, documento, contato). */
public class ConsultarClientesActivity extends BaseActivity {

    private TextView textViewResult;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        setContentView(R.layout.activity_consultar_clientes);
        setTitle("Consulta de Clientes");

        textViewResult = findViewById(R.id.textViewResult);
    }

    @Override
    protected void onResume() {
        super.onResume();
        carregar();
    }

    private void carregar() {
        textViewResult.setText("Carregando clientes...");

        new Thread(() -> {
            String texto;
            try {
                final ApiClient.Result r = ApiClient.get("/api/clientes");
                if (!r.ok()) {
                    if (r.status == 401) {
                        runOnUiThread(() -> Sessao.tratarSessaoExpirada(ConsultarClientesActivity.this, r));
                        return;
                    }
                    texto = "Não foi possível carregar os clientes.\n"
                            + "A API respondeu HTTP " + r.status + ".";
                } else {
                    texto = montar(new JSONArray(r.body));
                }
            } catch (Exception e) {
                texto = "Não foi possível falar com a API.\nVerifique se ela está no ar.";
            }

            final String conteudo = texto;
            runOnUiThread(() -> textViewResult.setText(conteudo));
        }).start();
    }

    private String montar(JSONArray arr) throws Exception {
        StringBuilder sb = new StringBuilder();
        sb.append("Total: ").append(arr.length()).append(" cliente(s)\n");

        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            sb.append("\n").append(Fmt.limpar(o.optString("nome"))).append("\n");
            sb.append("  CPF/CNPJ: ").append(Fmt.limpar(o.optString("cpf_cnpj"))).append("\n");
            sb.append("  Cidade:   ")
              .append(Fmt.cidadeUf(o.optString("cidade"), o.optString("uf"))).append("\n");
            sb.append("  Telefone: ").append(Fmt.limpar(o.optString("telefone"))).append("\n");
            sb.append("  E-mail:   ").append(Fmt.limpar(o.optString("email"))).append("\n");
        }
        return sb.toString();
    }
}
