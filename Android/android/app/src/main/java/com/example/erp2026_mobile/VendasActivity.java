package com.example.erp2026_mobile;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/** Pedidos de venda registrados. */
public class VendasActivity extends BaseListaActivity {

    @Override
    protected int layoutId() {
        return R.layout.activity_vendas;
    }

    @Override
    protected String titulo() {
        return "Vendas";
    }

    @Override
    protected String textoVazio() {
        return "Nenhuma venda registrada.";
    }

    @Override
    protected int itemMenuAtual() {
        return R.id.navVendas;
    }

    @Override
    protected boolean temBusca() {
        return true;
    }

    @Override
    protected String dicaBusca() {
        return "Pesquisar vendas";
    }

    @Override
    protected void aoCriar() {
        findViewById(R.id.buttonOrcamentos).setOnClickListener(v -> Navegacao.abrirOrcamentos(this));
    }

    @Override
    protected List<String> buscar() throws Exception {
        ApiClient.Result r = ApiClient.get("/api/vendas");
        if (!r.ok()) {
            throw new ApiException(r);
        }

        JSONArray arr = new JSONArray(r.body);
        List<String> itens = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            String data = Fmt.limpar(o.optString("data_emissao"));
            String status = Fmt.limpar(o.optString("status"));

            StringBuilder linha = new StringBuilder("Pedido ");
            linha.append(Fmt.limpar(o.optString("numero")));
            linha.append(" - ").append(Fmt.limpar(o.optString("cliente")));
            linha.append("\n").append(Fmt.moeda(o.optDouble("total", 0)));
            if (!data.isEmpty()) {
                linha.append("   Emissão: ").append(data);
            }
            if (!status.isEmpty()) {
                linha.append("\n").append(status);
            }
            itens.add(linha.toString());
        }
        return itens;
    }
}
