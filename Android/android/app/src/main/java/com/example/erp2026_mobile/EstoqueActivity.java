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

public class EstoqueActivity extends AppCompatActivity {
    private ListView listViewProdutos;
    private List<String> produtosList;
    private ArrayAdapter<String> adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_estoque);

        listViewProdutos = findViewById(R.id.listViewProdutos);
        produtosList = new ArrayList<>();
        produtosList.add("Carregando estoque da API...");

        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, produtosList);
        listViewProdutos.setAdapter(adapter);

        listViewProdutos.setOnItemClickListener((parent, view, position, id) ->
                Toast.makeText(EstoqueActivity.this,
                        produtosList.get(position), Toast.LENGTH_SHORT).show());

        carregarEstoque();
    }

    private void carregarEstoque() {
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ApiClient.Result r = ApiClient.get("/api/estoque");
                    if (r.ok()) {
                        JSONArray arr = new JSONArray(r.body);
                        final List<String> itens = new ArrayList<>();
                        for (int i = 0; i < arr.length(); i++) {
                            JSONObject o = arr.getJSONObject(i);
                            itens.add(o.optString("descricao") + "\n"
                                    + "Cod: " + o.optString("codigo")
                                    + "  Qtd: " + String.format(Locale.US, "%.2f", o.optDouble("quantidade", 0)));
                        }
                        if (itens.isEmpty()) {
                            itens.add("Nenhum produto com controle de estoque.");
                        }
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                produtosList.clear();
                                produtosList.addAll(itens);
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
                produtosList.clear();
                produtosList.add("Erro: " + msg);
                adapter.notifyDataSetChanged();
            }
        });
    }
}
