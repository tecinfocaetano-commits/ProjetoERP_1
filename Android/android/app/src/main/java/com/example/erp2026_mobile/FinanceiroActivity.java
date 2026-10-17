package com.example.erp2026_mobile;

import android.os.Bundle;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class FinanceiroActivity extends AppCompatActivity {
    private ListView listViewContas;
    private TextView textViewTotalReceber;
    private TextView textViewTotalPagar;
    private List<String> contasList;
    private ArrayAdapter<String> adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_financeiro);

        listViewContas = findViewById(R.id.listViewContas);
        textViewTotalReceber = findViewById(R.id.textViewTotalReceber);
        textViewTotalPagar = findViewById(R.id.textViewTotalPagar);

        contasList = new ArrayList<>();
        contasList.add("Carregando financeiro da API...");

        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, contasList);
        listViewContas.setAdapter(adapter);

        listViewContas.setOnItemClickListener((parent, view, position, id) ->
                Toast.makeText(FinanceiroActivity.this,
                        contasList.get(position), Toast.LENGTH_SHORT).show());

        carregarFinanceiro();
    }

    private void carregarFinanceiro() {
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    final List<String> itens = new ArrayList<>();
                    String resumoReceber = "Total a Receber: -";
                    String resumoPagar = "Total a Pagar: -";

                    ApiClient.Result resumo = ApiClient.get("/api/financeiro");
                    if (resumo.ok()) {
                        JSONObject o = new JSONObject(resumo.body);
                        resumoReceber = "Total a Receber: R$ "
                                + String.format(Locale.US, "%.2f", o.optDouble("a_receber", 0));
                        resumoPagar = "Total a Pagar: R$ "
                                + String.format(Locale.US, "%.2f", o.optDouble("a_pagar", 0));
                    }

                    ApiClient.Result receber = ApiClient.get("/api/financeiro/receber");
                    if (receber.ok()) {
                        JSONArray arr = new JSONArray(receber.body);
                        for (int i = 0; i < arr.length(); i++) {
                            JSONObject o = arr.getJSONObject(i);
                            itens.add("A RECEBER - " + o.optString("cliente") + "\n"
                                    + o.optString("descricao") + " - R$ "
                                    + String.format(Locale.US, "%.2f", o.optDouble("valor", 0))
                                    + "  venc. " + o.optString("vencimento").trim());
                        }
                    }

                    ApiClient.Result pagar = ApiClient.get("/api/financeiro/pagar");
                    if (pagar.ok()) {
                        JSONArray arr = new JSONArray(pagar.body);
                        for (int i = 0; i < arr.length(); i++) {
                            JSONObject o = arr.getJSONObject(i);
                            itens.add("A PAGAR - " + o.optString("fornecedor") + "\n"
                                    + o.optString("descricao") + " - R$ "
                                    + String.format(Locale.US, "%.2f", o.optDouble("valor", 0))
                                    + "  venc. " + o.optString("vencimento").trim());
                        }
                    }

                    if (itens.isEmpty()) {
                        itens.add("Nenhuma conta em aberto.");
                    }

                    final String fr = resumoReceber;
                    final String fp = resumoPagar;
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            textViewTotalReceber.setText(fr);
                            textViewTotalPagar.setText(fp);
                            contasList.clear();
                            contasList.addAll(itens);
                            adapter.notifyDataSetChanged();
                        }
                    });
                } catch (final Exception e) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            contasList.clear();
                            contasList.add("Erro: " + e.getMessage());
                            adapter.notifyDataSetChanged();
                        }
                    });
                }
            }
        }).start();
    }
}
