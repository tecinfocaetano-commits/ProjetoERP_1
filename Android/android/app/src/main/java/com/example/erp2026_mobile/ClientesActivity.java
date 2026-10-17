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

public class ClientesActivity extends AppCompatActivity {
    private ListView listViewClientes;
    private List<String> clientesList;
    private ArrayAdapter<String> adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_clientes);

        listViewClientes = findViewById(R.id.listViewClientes);

        clientesList = new ArrayList<>();
        clientesList.add("Carregando clientes da API...");

        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, clientesList);
        listViewClientes.setAdapter(adapter);

        listViewClientes.setOnItemClickListener((parent, view, position, id) ->
                Toast.makeText(ClientesActivity.this,
                        clientesList.get(position), Toast.LENGTH_SHORT).show());

        carregarClientes();
    }

    private void carregarClientes() {
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ApiClient.Result r = ApiClient.get("/api/clientes");
                    if (r.ok()) {
                        JSONArray arr = new JSONArray(r.body);
                        final List<String> itens = new ArrayList<>();
                        for (int i = 0; i < arr.length(); i++) {
                            JSONObject o = arr.getJSONObject(i);
                            itens.add(o.optString("nome") + "\n"
                                    + o.optString("cidade") + "/" + o.optString("uf")
                                    + " - " + o.optString("telefone"));
                        }
                        if (itens.isEmpty()) {
                            itens.add("Nenhum cliente cadastrado.");
                        }
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                clientesList.clear();
                                clientesList.addAll(itens);
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
                clientesList.clear();
                clientesList.add("Erro: " + msg);
                adapter.notifyDataSetChanged();
            }
        });
    }
}
