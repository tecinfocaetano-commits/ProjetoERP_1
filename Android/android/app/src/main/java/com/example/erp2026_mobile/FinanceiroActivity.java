package com.example.erp2026_mobile;

import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/** Resumo financeiro e contas em aberto. */
public class FinanceiroActivity extends BaseListaActivity {

    private TextView textViewTotalReceber;
    private TextView textViewTotalPagar;

    private String resumoReceber = "A Receber: -";
    private String resumoPagar = "A Pagar: -";

    @Override
    protected int layoutId() {
        return R.layout.activity_financeiro;
    }

    @Override
    protected String titulo() {
        return "Financeiro";
    }

    @Override
    protected String textoVazio() {
        return "Nenhuma conta em aberto.";
    }

    @Override
    protected int itemMenuAtual() {
        return R.id.navFinanceiro;
    }

    @Override
    protected void aoCriar() {
        textViewTotalReceber = findViewById(R.id.textViewTotalReceber);
        textViewTotalPagar = findViewById(R.id.textViewTotalPagar);
    }

    @Override
    protected void aoPublicar() {
        textViewTotalReceber.setText(resumoReceber);
        textViewTotalPagar.setText(resumoPagar);
    }

    @Override
    protected List<String> buscar() throws Exception {
        List<String> itens = new ArrayList<>();

        ApiClient.Result resumo = ApiClient.get("/api/financeiro");
        if (!resumo.ok()) {
            throw new ApiException(resumo);
        }
        JSONObject totais = new JSONObject(resumo.body);
        resumoReceber = "A Receber: " + Fmt.moeda(totais.optDouble("a_receber", 0));
        resumoPagar = "A Pagar: " + Fmt.moeda(totais.optDouble("a_pagar", 0));

        ApiClient.Result receber = ApiClient.get("/api/financeiro/receber");
        if (!receber.ok()) {
            throw new ApiException(receber);
        }
        JSONArray arrReceber = new JSONArray(receber.body);
        for (int i = 0; i < arrReceber.length(); i++) {
            JSONObject o = arrReceber.getJSONObject(i);
            itens.add("A RECEBER  -  " + Fmt.limpar(o.optString("cliente"))
                    + "\n" + Fmt.limpar(o.optString("descricao"))
                    + "\n" + Fmt.moeda(o.optDouble("valor", 0))
                    + "   Venc.: " + Fmt.limpar(o.optString("vencimento")));
        }

        ApiClient.Result pagar = ApiClient.get("/api/financeiro/pagar");
        if (!pagar.ok()) {
            throw new ApiException(pagar);
        }
        JSONArray arrPagar = new JSONArray(pagar.body);
        for (int i = 0; i < arrPagar.length(); i++) {
            JSONObject o = arrPagar.getJSONObject(i);
            itens.add("A PAGAR  -  " + Fmt.limpar(o.optString("fornecedor"))
                    + "\n" + Fmt.limpar(o.optString("descricao"))
                    + "\n" + Fmt.moeda(o.optDouble("valor", 0))
                    + "   Venc.: " + Fmt.limpar(o.optString("vencimento")));
        }

        return itens;
    }
}
