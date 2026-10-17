package com.example.erp2026_mobile;

import android.os.Bundle;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONObject;

public class ConsultarClientesActivity extends AppCompatActivity {
    private TextView textViewResult;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_test_database);

        textViewResult = findViewById(R.id.textViewResult);
        textViewResult.setText("=== CONSULTA DE CLIENTES (API REST) ===\n\nCarregando...\n");

        new Thread(new Runnable() {
            @Override
            public void run() {
                final StringBuilder sb = new StringBuilder();
                sb.append("=== CONSULTA DE CLIENTES (API REST) ===\n\n");
                try {
                    ApiClient.Result r = ApiClient.get("/api/clientes");
                    if (r.ok()) {
                        JSONArray arr = new JSONArray(r.body);
                        sb.append("Total: ").append(arr.length()).append(" cliente(s)\n\n");
                        for (int i = 0; i < arr.length(); i++) {
                            JSONObject o = arr.getJSONObject(i);
                            sb.append(o.optString("nome")).append("\n");
                            sb.append("  CPF/CNPJ: ").append(o.optString("cpf_cnpj")).append("\n");
                            sb.append("  Cidade:   ").append(o.optString("cidade"))
                              .append("/").append(o.optString("uf")).append("\n");
                            sb.append("  Telefone: ").append(o.optString("telefone")).append("\n");
                            sb.append("  E-mail:   ").append(o.optString("email")).append("\n\n");
                        }
                    } else {
                        sb.append("Erro: ").append(r.errorMessage());
                    }
                } catch (Exception e) {
                    sb.append("Falha de conexao: ").append(e.getMessage());
                }

                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        textViewResult.setText(sb.toString());
                    }
                });
            }
        }).start();
    }
}
