package com.example.erp2026_mobile;

import android.os.Bundle;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

public class TestDatabaseActivity extends AppCompatActivity {
    private TextView textViewResult;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_test_database);

        textViewResult = findViewById(R.id.textViewResult);
        textViewResult.setText("=== DIAGNOSTICO DA API REST ===\n\nExecutando...\n");

        new Thread(new Runnable() {
            @Override
            public void run() {
                final StringBuilder sb = new StringBuilder();
                sb.append("=== DIAGNOSTICO DA API REST ===\n");
                sb.append("Servidor: ").append(ApiClient.BASE_URL).append("\n");
                sb.append("Token: ").append(ApiClient.getToken() == null ? "ausente" : "presente").append("\n\n");

                testar(sb, "GET /api/clientes", "/api/clientes");
                testar(sb, "GET /api/produtos", "/api/produtos");
                testar(sb, "GET /api/estoque", "/api/estoque");
                testar(sb, "GET /api/vendas", "/api/vendas");
                testar(sb, "GET /api/financeiro", "/api/financeiro");
                testar(sb, "GET /api/financeiro/receber", "/api/financeiro/receber");
                testar(sb, "GET /api/financeiro/pagar", "/api/financeiro/pagar");

                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        textViewResult.setText(sb.toString());
                    }
                });
            }
        }).start();
    }

    private void testar(StringBuilder sb, String rotulo, String caminho) {
        try {
            ApiClient.Result r = ApiClient.get(caminho);
            sb.append(r.ok() ? "[OK]   " : "[FALHA] ");
            sb.append(rotulo);
            sb.append("  -> HTTP ").append(r.status);
            if (r.body != null) {
                sb.append("  (").append(r.body.length()).append(" bytes)");
            }
            sb.append("\n");
        } catch (Exception e) {
            sb.append("[ERRO] ").append(rotulo).append(" -> ").append(e.getMessage()).append("\n");
        }
    }
}
