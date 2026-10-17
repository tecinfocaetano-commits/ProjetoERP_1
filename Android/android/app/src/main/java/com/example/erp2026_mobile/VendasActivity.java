package com.example.erp2026_mobile;

import android.os.Bundle;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class VendasActivity extends AppCompatActivity {
    private ListView listViewVendas;
    private List<String> vendasList;
    private ArrayAdapter<String> adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_vendas);

        listViewVendas = findViewById(R.id.listViewVendas);
        vendasList = new ArrayList<>();
        vendasList.add("Carregando vendas da API...");

        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, vendasList);
        listViewVendas.setAdapter(adapter);

        listViewVendas.setOnItemClickListener((parent, view, position, id) ->
                Toast.makeText(VendasActivity.this,
                        vendasList.get(position), Toast.LENGTH_SHORT).show());

        carregarVendas();
    }

    private void carregarVendas() {
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ApiClient.Result r = ApiClient.get("/api/vendas");
                    if (r.ok()) {
                        JSONArray arr = new JSONArray(r.body);
                        final List<String> itens = new ArrayList<>();
                        for (int i = 0; i < arr.length(); i++) {
                            JSONObject o = arr.getJSONObject(i);
                            itens.add("Pedido " + o.optString("numero")
                                    + " - " + o.optString("cliente") + "\n"
                                    + "R$ " + String.format(Locale.US, "%.2f", o.optDouble("total", 0))
                                    + "  (" + o.optString("data_emissao").trim()
                                    + ")  " + o.optString("status").trim());
                        }
                        if (itens.isEmpty()) {
                            itens.add("Nenhuma venda registrada.");
                        }
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                vendasList.clear();
                                vendasList.addAll(itens);
                                adapter.notifyDataSetChanged();
                            }
                        });
                    } else {
                        mostrarErro(r.errorMessage());
                    }
                } catch (final Exception e) {
                    mostrarErro(e.getMessage());
                }
            }
        }).start();
    }

    private void mostrarErro(final String msg) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                vendasList.clear();
                vendasList.add("Erro: " + msg);
                adapter.notifyDataSetChanged();
            }
        });
    }
}
