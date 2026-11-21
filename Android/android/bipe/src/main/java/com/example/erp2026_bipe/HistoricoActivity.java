package com.example.erp2026_bipe;

import android.os.Bundle;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Histórico de bipagens DO SERVIDOR (GET /api/producao/bipagens) —
 * mostra o que a empresa toda bipou, não só o que este aparelho fez.
 * Complementa o histórico local do turno (BipeDb).
 */
public class HistoricoActivity extends AppCompatActivity {

    private TextView txtStatus;
    private ListView lista;
    private ArrayAdapter<String> adaptador;

    @Override
    protected void onCreate(Bundle estado) {
        super.onCreate(estado);
        setContentView(R.layout.activity_historico);

        Sessao.restaurar(this);
        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        txtStatus = findViewById(R.id.txtStatusHistorico);
        lista = findViewById(R.id.listaHistoricoServidor);
        adaptador = new ArrayAdapter<>(this,
                android.R.layout.simple_list_item_1);
        lista.setAdapter(adaptador);

        txtStatus.setText("Carregando bipagens do servidor...");
        new Thread(() -> {
            ApiClient.Result r;
            String erro = "";
            try {
                r = ApiClient.get("/api/producao/bipagens?limite=100");
            } catch (Exception e) {
                erro = e.getClass().getSimpleName() + ": " + e.getMessage();
                r = new ApiClient.Result(-1, "");
            }
            final ApiClient.Result resposta = r;
            final String erroFinal = erro;
            runOnUiThread(() -> {
                carregar(resposta);
                if (!erroFinal.isEmpty()) {
                    txtStatus.setText("Erro de conexão: " + erroFinal);
                }
            });
        }).start();
    }

    private void carregar(final ApiClient.Result r) {
        if (r.status == 401) {
            Sessao.encerrar(this);
            Sessao.irParaLogin(this);
            return;
        }
        if (r.status < 0) {
            txtStatus.setText("Sem conexão com o servidor.");
            return;
        }
        try {
            JSONArray arr = new JSONArray(r.body);
            List<String> linhas = new ArrayList<>();
            for (int i = 0; i < arr.length(); i++) {
                JSONObject j = arr.getJSONObject(i);
                linhas.add(formatar(j));
            }
            adaptador.clear();
            for (String l : linhas) {
                adaptador.add(l);
            }
            adaptador.notifyDataSetChanged();
            txtStatus.setText(linhas.isEmpty()
                    ? "Nenhuma bipagem registrada ainda."
                    : linhas.size() + " bipagem(ns) — mais recente primeiro.");
        } catch (Exception e) {
            txtStatus.setText("Resposta inesperada do servidor.");
        }
    }

    private String formatar(JSONObject j) {
        StringBuilder sb = new StringBuilder();
        String hora = j.optString("data_hora", "");
        // data_hora vem dd/mm/aaaa hh:mm:ss do Firebird — encurta a data
        if (hora.length() > 11) {
            hora = hora.substring(0, 5) + " " + hora.substring(11);
        }
        sb.append(hora).append("  ");
        String resultado = j.optString("resultado", "");
        if ("OK".equals(resultado)) {
            sb.append("✓");
        } else if ("DUPLICADO".equals(resultado)) {
            sb.append("⚠");
        } else {
            sb.append("✗");
        }
        sb.append(" ").append(j.optString("operador", "?"));
        int numero = j.optInt("numero_talao", 0);
        if (numero > 0) {
            sb.append("  Talão ").append(numero);
            String cod = j.optString("codigo_barras", "");
            if (!cod.isEmpty()) {
                sb.append(" (").append(cod).append(")");
            }
        } else {
            sb.append("  código não encontrado");
        }
        String obs = j.optString("observacao", "");
        if (!obs.isEmpty()) {
            sb.append("  — ").append(obs);
        }
        return sb.toString();
    }
}
