package com.example.erp2026_mobile;

import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Cadastro de orçamento no app.
 *
 * <p>Cliente e produtos vêm da API. Os itens são montados na tela e enviados
 * para {@code POST /api/orcamentos}; o servidor recalcula os totais e grava
 * como PEDIDO_VENDA com STATUS 'O'.
 */
public class InserirOrcamentoActivity extends AppCompatActivity {

    private static final Locale BR = new Locale("pt", "BR");

    private Spinner spinnerCliente;
    private Spinner spinnerProduto;
    private EditText editTextQuantidade;
    private EditText editTextValorUnitario;
    private EditText editTextDescontoItem;
    private EditText editTextDesconto;
    private EditText editTextObservacoes;
    private TextView textViewItens;
    private TextView textViewTotais;
    private TextView textViewStatus;
    private Button buttonAdicionarItem;
    private Button buttonLimparItens;
    private Button buttonSalvar;

    private final List<Cliente> clientes = new ArrayList<>();
    private final List<Produto> produtos = new ArrayList<>();
    private final List<Item> itens = new ArrayList<>();

    private double subtotalAtual;
    private boolean salvando;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        setContentView(R.layout.activity_inserir_orcamento);
        setTitle("Novo orçamento");

        spinnerCliente = findViewById(R.id.spinnerCliente);
        spinnerProduto = findViewById(R.id.spinnerProduto);
        editTextQuantidade = findViewById(R.id.editTextQuantidade);
        editTextValorUnitario = findViewById(R.id.editTextValorUnitario);
        editTextDescontoItem = findViewById(R.id.editTextDescontoItem);
        editTextDesconto = findViewById(R.id.editTextDesconto);
        editTextObservacoes = findViewById(R.id.editTextObservacoes);
        textViewItens = findViewById(R.id.textViewItens);
        textViewTotais = findViewById(R.id.textViewTotais);
        textViewStatus = findViewById(R.id.textViewStatus);
        buttonAdicionarItem = findViewById(R.id.buttonAdicionarItem);
        buttonLimparItens = findViewById(R.id.buttonLimparItens);
        buttonSalvar = findViewById(R.id.buttonSalvar);

        buttonAdicionarItem.setOnClickListener(v -> adicionarItem());
        buttonLimparItens.setOnClickListener(v -> limparItens());
        buttonSalvar.setOnClickListener(v -> salvar());

        editTextDesconto.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) { }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) { }

            @Override
            public void afterTextChanged(Editable s) {
                atualizarTotais();
            }
        });

        spinnerProduto.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                selecionarProduto(position);
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) { }
        });

        atualizarItens();
        carregarDados();
    }

    // ------------------------------------------------------------------
    // Carga de clientes e produtos
    // ------------------------------------------------------------------

    private void carregarDados() {
        buttonAdicionarItem.setEnabled(false);
        buttonSalvar.setEnabled(false);
        textViewStatus.setText("Carregando clientes e produtos...");

        new Thread(() -> {
            try {
                final ApiClient.Result rc = ApiClient.get("/api/clientes");
                if (!rc.ok()) {
                    falhaCarregamento(rc);
                    return;
                }
                final ApiClient.Result rp = ApiClient.get("/api/produtos");
                if (!rp.ok()) {
                    falhaCarregamento(rp);
                    return;
                }

                JSONArray ac = new JSONArray(rc.body);
                JSONArray ap = new JSONArray(rp.body);

                final List<Cliente> novosClientes = new ArrayList<>();
                novosClientes.add(new Cliente(0, "Selecione o cliente..."));
                for (int i = 0; i < ac.length(); i++) {
                    JSONObject o = ac.getJSONObject(i);
                    novosClientes.add(new Cliente(o.optLong("id"), Fmt.limpar(o.optString("nome"))));
                }

                final List<Produto> novosProdutos = new ArrayList<>();
                novosProdutos.add(new Produto(0, "Selecione o produto...", 0));
                for (int i = 0; i < ap.length(); i++) {
                    JSONObject o = ap.getJSONObject(i);
                    novosProdutos.add(new Produto(
                            o.optLong("id"),
                            Fmt.limpar(o.optString("descricao")),
                            o.optDouble("preco_venda", 0)));
                }

                runOnUiThread(() -> preencher(novosClientes, novosProdutos));
            } catch (final Exception e) {
                runOnUiThread(() -> {
                    textViewStatus.setText("Falha de conexão.\nVerifique se a API está no ar.");
                });
            }
        }).start();
    }

    private void falhaCarregamento(final ApiClient.Result r) {
        runOnUiThread(() -> {
            if (Sessao.tratarSessaoExpirada(this, r)) {
                return;
            }
            textViewStatus.setText("Não foi possível carregar os dados (HTTP " + r.status + ").");
        });
    }

    /** Roda na thread da interface: monta os spinners já com os dados. */
    private void preencher(List<Cliente> novosClientes, List<Produto> novosProdutos) {
        clientes.clear();
        clientes.addAll(novosClientes);
        produtos.clear();
        produtos.addAll(novosProdutos);

        List<String> nomesClientes = new ArrayList<>();
        for (Cliente c : clientes) {
            nomesClientes.add(c.nome);
        }
        ArrayAdapter<String> adClientes = new ArrayAdapter<>(
                this, android.R.layout.simple_spinner_item, nomesClientes);
        adClientes.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spinnerCliente.setAdapter(adClientes);
        spinnerCliente.setSelection(0);

        List<String> nomesProdutos = new ArrayList<>();
        for (Produto p : produtos) {
            if (p.id == 0) {
                nomesProdutos.add(p.nome);
            } else {
                nomesProdutos.add(p.nome + " — " + Fmt.moeda(p.preco));
            }
        }
        ArrayAdapter<String> adProdutos = new ArrayAdapter<>(
                this, android.R.layout.simple_spinner_item, nomesProdutos);
        adProdutos.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spinnerProduto.setAdapter(adProdutos);
        spinnerProduto.setSelection(0);

        if (clientes.size() <= 1 || produtos.size() <= 1) {
            textViewStatus.setText("Cadastre clientes e produtos no desktop para usar orçamentos.");
        } else {
            textViewStatus.setText("");
        }

        buttonAdicionarItem.setEnabled(produtos.size() > 1);
        buttonSalvar.setEnabled(clientes.size() > 1);
    }

    // ------------------------------------------------------------------
    // Itens
    // ------------------------------------------------------------------

    private void selecionarProduto(int position) {
        if (position < 0 || position >= produtos.size()) {
            return;
        }
        Produto p = produtos.get(position);
        if (p.id == 0) {
            editTextValorUnitario.setText("");
            return;
        }
        editTextValorUnitario.setText(String.format(BR, "%.2f", p.preco));
    }

    private void adicionarItem() {
        int posicao = spinnerProduto.getSelectedItemPosition();
        if (posicao <= 0 || posicao >= produtos.size()) {
            Toast.makeText(this, "Selecione um produto.", Toast.LENGTH_SHORT).show();
            return;
        }

        Produto produto = produtos.get(posicao);
        double quantidade = numero(editTextQuantidade.getText().toString());
        double valor = numero(editTextValorUnitario.getText().toString());
        double desconto = numero(editTextDescontoItem.getText().toString());

        if (Double.isNaN(quantidade) || quantidade <= 0) {
            editTextQuantidade.setError("Informe uma quantidade maior que zero");
            editTextQuantidade.requestFocus();
            return;
        }
        if (Double.isNaN(valor) || valor < 0) {
            editTextValorUnitario.setError("Informe um valor válido");
            editTextValorUnitario.requestFocus();
            return;
        }
        if (Double.isNaN(desconto) || desconto < 0) {
            editTextDescontoItem.setError("Desconto inválido");
            editTextDescontoItem.requestFocus();
            return;
        }
        if (desconto > quantidade * valor) {
            editTextDescontoItem.setError("Desconto maior que o valor do item");
            editTextDescontoItem.requestFocus();
            return;
        }

        itens.add(new Item(produto.id, produto.nome, quantidade, valor, desconto));
        atualizarItens();

        // Prepara o próximo item
        spinnerProduto.setSelection(0);
        editTextQuantidade.setText("1");
        editTextDescontoItem.setText("0,00");
        Toast.makeText(this, "Item adicionado.", Toast.LENGTH_SHORT).show();
    }

    private void limparItens() {
        itens.clear();
        atualizarItens();
    }

    private void atualizarItens() {
        StringBuilder sb = new StringBuilder();
        subtotalAtual = 0;

        for (Item item : itens) {
            subtotalAtual += item.total();
            sb.append(Fmt.quantidade(item.quantidade))
              .append(" x ").append(item.descricao)
              .append(" — ").append(Fmt.moeda(item.total()))
              .append("\n");
        }

        if (itens.isEmpty()) {
            textViewItens.setText("Nenhum item adicionado.");
        } else {
            textViewItens.setText(sb.toString().trim());
        }
        atualizarTotais();
    }

    private void atualizarTotais() {
        double desconto = numero(editTextDesconto.getText().toString());
        if (Double.isNaN(desconto) || desconto < 0) {
            desconto = 0;
        }
        double total = subtotalAtual - desconto;
        if (total < 0) {
            total = 0;
        }
        textViewTotais.setText("Subtotal: " + Fmt.moeda(subtotalAtual)
                + "\nDesconto: " + Fmt.moeda(desconto)
                + "\nTotal: " + Fmt.moeda(total));
    }

    // ------------------------------------------------------------------
    // Gravação
    // ------------------------------------------------------------------

    private void salvar() {
        if (salvando) {
            return;
        }

        int posicaoCliente = spinnerCliente.getSelectedItemPosition();
        if (posicaoCliente <= 0 || posicaoCliente >= clientes.size()) {
            Toast.makeText(this, "Selecione o cliente.", Toast.LENGTH_SHORT).show();
            return;
        }
        if (itens.isEmpty()) {
            Toast.makeText(this, "Adicione pelo menos um item.", Toast.LENGTH_SHORT).show();
            return;
        }

        final long clienteId = clientes.get(posicaoCliente).id;
        final String observacoes = editTextObservacoes.getText().toString().trim();
        final double desconto = numero(editTextDesconto.getText().toString());

        if (Double.isNaN(desconto) || desconto < 0) {
            editTextDesconto.setError("Informe um desconto válido");
            editTextDesconto.requestFocus();
            return;
        }
        if (desconto > subtotalAtual) {
            editTextDesconto.setError("Desconto maior que o subtotal");
            editTextDesconto.requestFocus();
            return;
        }

        salvando = true;
        buttonSalvar.setEnabled(false);
        buttonSalvar.setText("Salvando...");
        textViewStatus.setText("Enviando para a API...");

        new Thread(() -> {
            try {
                JSONObject corpo = new JSONObject();
                corpo.put("cliente_id", clienteId);
                corpo.put("desconto", desconto);
                corpo.put("observacoes", observacoes);

                JSONArray lista = new JSONArray();
                for (Item item : itens) {
                    JSONObject o = new JSONObject();
                    o.put("produto_id", item.produtoId);
                    o.put("quantidade", item.quantidade);
                    o.put("valor_unitario", item.valorUnitario);
                    o.put("desconto", item.desconto);
                    lista.put(o);
                }
                corpo.put("itens", lista);

                final ApiClient.Result r = ApiClient.post("/api/orcamentos", corpo.toString());

                runOnUiThread(() -> {
                    salvando = false;
                    buttonSalvar.setEnabled(true);
                    buttonSalvar.setText("Salvar orçamento");

                    if (Sessao.tratarSessaoExpirada(InserirOrcamentoActivity.this, r)) {
                        return;
                    }
                    if (r.ok()) {
                        String numero = "";
                        try {
                            numero = new JSONObject(r.body).optString("numero", "");
                        } catch (Exception ignored) {
                        }
                        Toast.makeText(InserirOrcamentoActivity.this,
                                "Orçamento " + numero + " salvo com sucesso.",
                                Toast.LENGTH_LONG).show();
                        setResult(RESULT_OK);
                        finish();
                    } else {
                        textViewStatus.setText(mensagemDeErro(r));
                        Toast.makeText(InserirOrcamentoActivity.this,
                                "Não foi possível salvar o orçamento.",
                                Toast.LENGTH_LONG).show();
                    }
                });
            } catch (final Exception e) {
                runOnUiThread(() -> {
                    salvando = false;
                    buttonSalvar.setEnabled(true);
                    buttonSalvar.setText("Salvar orçamento");
                    textViewStatus.setText("Falha de conexão.\nVerifique se a API está no ar.");
                });
            }
        }).start();
    }

    private String mensagemDeErro(ApiClient.Result r) {
        String detalhe = "";
        try {
            detalhe = new JSONObject(r.body).optString("error", "");
        } catch (Exception ignored) {
        }
        if (!detalhe.isEmpty()) {
            return detalhe;
        }
        if (r.status == 400) {
            return "A API recusou os dados enviados (HTTP 400).";
        }
        if (r.status >= 500) {
            return "Erro no servidor da API (HTTP " + r.status + ").";
        }
        return "A API respondeu com erro HTTP " + r.status + ".";
    }

    /** Aceita "35,50", "35.50" e "1.234,56"; devolve NaN quando inválido. */
    private static double numero(String texto) {
        if (texto == null) {
            return Double.NaN;
        }
        String t = texto.trim().replace(" ", "");
        if (t.isEmpty()) {
            return Double.NaN;
        }
        if (t.contains(",")) {
            t = t.replace(".", "").replace(",", ".");
        }
        try {
            return Double.parseDouble(t);
        } catch (NumberFormatException e) {
            return Double.NaN;
        }
    }

    // ------------------------------------------------------------------
    // Modelos simples da tela
    // ------------------------------------------------------------------

    private static final class Cliente {
        final long id;
        final String nome;

        Cliente(long id, String nome) {
            this.id = id;
            this.nome = nome;
        }
    }

    private static final class Produto {
        final long id;
        final String nome;
        final double preco;

        Produto(long id, String nome, double preco) {
            this.id = id;
            this.nome = nome;
            this.preco = preco;
        }
    }

    private static final class Item {
        final long produtoId;
        final String descricao;
        final double quantidade;
        final double valorUnitario;
        final double desconto;

        Item(long produtoId, String descricao, double quantidade,
             double valorUnitario, double desconto) {
            this.produtoId = produtoId;
            this.descricao = descricao;
            this.quantidade = quantidade;
            this.valorUnitario = valorUnitario;
            this.desconto = desconto;
        }

        double total() {
            return quantidade * valorUnitario - desconto;
        }
    }
}
