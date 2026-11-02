package com.example.erp2026_mobile;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/** Lista de clientes cadastrados. */
public class ClientesActivity extends BaseListaActivity {

    @Override
    protected int layoutId() {
        return R.layout.activity_clientes;
    }

    @Override
    protected String titulo() {
        return "Clientes";
    }

    @Override
    protected String textoVazio() {
        return "Nenhum cliente cadastrado.\nUse \"Inserir Cliente\" para cadastrar o primeiro.";
    }

    @Override
    protected int itemMenuAtual() {
        return R.id.navClientes;
    }

    @Override
    protected List<String> buscar() throws Exception {
        ApiClient.Result r = ApiClient.get("/api/clientes");
        if (!r.ok()) {
            throw new ApiException(r);
        }

        JSONArray arr = new JSONArray(r.body);
        List<String> itens = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            String nome = Fmt.limpar(o.optString("nome"));
            String cidade = Fmt.cidadeUf(o.optString("cidade"), o.optString("uf"));
            String telefone = Fmt.limpar(o.optString("telefone"));
            String email = Fmt.limpar(o.optString("email"));
            String cpf = Fmt.limpar(o.optString("cpf_cnpj"));

            StringBuilder linha = new StringBuilder(nome);
            if (!cidade.isEmpty()) {
                linha.append("\n").append(cidade);
            }
            if (!telefone.isEmpty()) {
                linha.append("  -  ").append(telefone);
            }
            if (!cpf.isEmpty() || !email.isEmpty()) {
                linha.append("\n").append(cpf);
                if (!email.isEmpty()) {
                    linha.append("  -  ").append(email);
                }
            }
            itens.add(linha.toString());
        }
        return itens;
    }
}
