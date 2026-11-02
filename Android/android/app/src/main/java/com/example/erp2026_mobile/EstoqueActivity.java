package com.example.erp2026_mobile;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/** Posição de estoque dos produtos. */
public class EstoqueActivity extends BaseListaActivity {

    @Override
    protected int layoutId() {
        return R.layout.activity_estoque;
    }

    @Override
    protected String titulo() {
        return "Estoque";
    }

    @Override
    protected String textoVazio() {
        return "Nenhum produto com controle de estoque.";
    }

    @Override
    protected int itemMenuAtual() {
        return R.id.navEstoque;
    }

    @Override
    protected List<String> buscar() throws Exception {
        ApiClient.Result r = ApiClient.get("/api/estoque");
        if (!r.ok()) {
            throw new ApiException(r);
        }

        JSONArray arr = new JSONArray(r.body);
        List<String> itens = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            double quantidade = o.optDouble("quantidade", 0);
            double minimo = o.optDouble("estoque_minimo", 0);

            StringBuilder linha = new StringBuilder(Fmt.limpar(o.optString("descricao")));
            linha.append("\nCód: ").append(Fmt.limpar(o.optString("codigo")));
            linha.append("   Qtd: ").append(Fmt.quantidade(quantidade));
            if (minimo > 0 && quantidade <= minimo) {
                linha.append("\nEstoque baixo (mínimo ").append(Fmt.quantidade(minimo)).append(")");
            }
            itens.add(linha.toString());
        }
        return itens;
    }
}
