package com.example.erp2026_pdv;

import android.Manifest;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.TextView;
import android.net.Uri;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.core.content.FileProvider;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.journeyapps.barcodescanner.ScanContract;
import com.journeyapps.barcodescanner.ScanOptions;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.text.NumberFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Tela principal do PDV Mobile: busca produto (texto ou câmera),
 * monta o carrinho, finaliza a venda com forma de pagamento e troco,
 * e gerencia o caixa (suprimento, sangria, fechamento).
 *
 * Toda regra de negócio fica na API (/api/pdv/* → TPDVService);
 * aqui só coleta e exibe dados.
 */
public class PdvActivity extends AppCompatActivity {

    // ------------------------------------------------------------------
    // Modelo
    // ------------------------------------------------------------------
    private static class ItemCarrinho {
        long produtoId;
        String descricao;
        double precoUnitario;
        double quantidade = 1;

        double total() {
            return quantidade * precoUnitario;
        }

        @Override
        public String toString() {
            return String.format(Locale.getDefault(),
                    "%s  x%.2f  =  %s",
                    descricao, quantidade, moeda(total()));
        }
    }

    private static class Produto {
        long id;
        String descricao;
        double preco;

        @Override
        public String toString() {
            return String.format(Locale.getDefault(), "%s  —  %s",
                    descricao, moeda(preco));
        }
    }

    private static class FormaPagamento {
        long id;
        String descricao;
        String tipo;

        @Override
        public String toString() {
            return descricao;
        }
    }

    // ------------------------------------------------------------------
    // Views e estado
    // ------------------------------------------------------------------
    private TextView txtOperador, txtCaixa, txtTotal;
    private EditText editBusca, editDesconto;
    private ListView listaResultados, listaCarrinho;
    private Button btnBuscar, btnScan, btnMais, btnMenos, btnRemover,
            btnFinalizar, btnSuprimento, btnSangria, btnFecharCaixa, btnSair;

    private final ArrayList<Produto> resultados = new ArrayList<>();
    private final ArrayList<ItemCarrinho> carrinho = new ArrayList<>();
    private final ArrayList<FormaPagamento> formas = new ArrayList<>();
    private ArrayAdapter<Produto> adapterResultados;
    private ArrayAdapter<ItemCarrinho> adapterCarrinho;

    private long caixaId = 0;
    private String numeroCaixa = "";
    private double saldoCaixa = 0;
    private int itemSelecionado = -1;

    private final NumberFormat NF = NumberFormat.getCurrencyInstance(
            new Locale("pt", "BR"));

    // ------------------------------------------------------------------
    // Leitura de código pela câmera (ZXing)
    // ------------------------------------------------------------------
    private final ActivityResultLauncher<ScanOptions> scanLauncher =
            registerForActivityResult(new ScanContract(), resultado -> {
                if (resultado != null && resultado.getContents() != null) {
                    String codigo = resultado.getContents().trim();
                    if (!codigo.isEmpty()) {
                        adicionarPorCodigo(codigo);
                    }
                }
            });

    // ------------------------------------------------------------------

    @Override
    protected void onCreate(Bundle estado) {
        super.onCreate(estado);
        setContentView(R.layout.activity_pdv);

        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        txtOperador = findViewById(R.id.txtOperador);
        txtCaixa = findViewById(R.id.txtCaixa);
        txtTotal = findViewById(R.id.txtTotal);
        editBusca = findViewById(R.id.editBusca);
        editDesconto = findViewById(R.id.editDesconto);
        listaResultados = findViewById(R.id.listaResultados);
        listaCarrinho = findViewById(R.id.listaCarrinho);
        btnBuscar = findViewById(R.id.btnBuscar);
        btnScan = findViewById(R.id.btnScan);
        btnMais = findViewById(R.id.btnMais);
        btnMenos = findViewById(R.id.btnMenos);
        btnRemover = findViewById(R.id.btnRemover);
        btnFinalizar = findViewById(R.id.btnFinalizar);
        btnSuprimento = findViewById(R.id.btnSuprimento);
        btnSangria = findViewById(R.id.btnSangria);
        btnFecharCaixa = findViewById(R.id.btnFecharCaixa);
        btnSair = findViewById(R.id.btnSair);

        txtOperador.setText("Operador: " + Sessao.nome(this));

        adapterResultados = new ArrayAdapter<>(this,
                android.R.layout.simple_list_item_1, resultados);
        listaResultados.setAdapter(adapterResultados);
        adapterCarrinho = new ArrayAdapter<>(this,
                android.R.layout.simple_list_item_1, carrinho);
        listaCarrinho.setAdapter(adapterCarrinho);

        btnBuscar.setOnClickListener(v -> buscarProdutos());
        editBusca.setOnEditorActionListener((v, acao, ev) -> {
            if (acao == android.view.inputmethod.EditorInfo.IME_ACTION_SEARCH) {
                buscarProdutos();
                return true;
            }
            return false;
        });
        btnScan.setOnClickListener(v -> abrirCamera());
        listaResultados.setOnItemClickListener((parent, view, pos, id) -> {
            Produto p = resultados.get(pos);
            adicionarAoCarrinho(p.id, p.descricao, p.preco);
        });
        listaCarrinho.setOnItemClickListener((parent, view, pos, id) -> {
            itemSelecionado = pos;
            Toast.makeText(this,
                    "Item selecionado: use ＋ － Remover",
                    Toast.LENGTH_SHORT).show();
        });
        btnMais.setOnClickListener(v -> ajustarQuantidade(+0.5));
        btnMenos.setOnClickListener(v -> ajustarQuantidade(-0.5));
        btnRemover.setOnClickListener(v -> removerItem());
        editDesconto.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int a, int b, int c) { }
            @Override public void onTextChanged(CharSequence s, int a, int b, int c) { }
            @Override public void afterTextChanged(Editable s) { atualizarTotal(); }
        });
        btnFinalizar.setOnClickListener(v -> finalizarVenda());
        btnSuprimento.setOnClickListener(v -> movimentoCaixa("E"));
        btnSangria.setOnClickListener(v -> movimentoCaixa("S"));
        btnFecharCaixa.setOnClickListener(v -> {
            // sem caixa aberto o mesmo botão oferece a abertura
            if (caixaId <= 0) {
                dialogoAbrirCaixa();
            } else {
                fecharCaixa();
            }
        });
        btnSair.setOnClickListener(v -> finish());

        carregarStatus();
        carregarFormas();
    }

    @Override
    protected void onResume() {
        super.onResume();
        // volta da câmera ou de outra tela: atualiza caixa/saldo
        if (caixaId > 0) {
            carregarStatus();
        }
    }

    // ------------------------------------------------------------------
    // Utilidades
    // ------------------------------------------------------------------
    private static String moeda(double valor) {
        return NumberFormat.getCurrencyInstance(new Locale("pt", "BR"))
                .format(valor);
    }

    private static double lerValor(String texto) {
        if (texto == null) return 0;
        String t = texto.trim().replace("R$", "")
                .replace(".", "").replace(",", ".");
        try {
            return Double.parseDouble(t);
        } catch (Exception e) {
            return 0;
        }
    }

    private void erro(final String msg) {
        runOnUiThread(() -> Toast.makeText(this, msg, Toast.LENGTH_LONG).show());
    }

    private String mensagemErro(ApiClient.Result r, String padrao) {
        try {
            String e = new JSONObject(r.body).optString("error", "");
            if (!e.isEmpty()) return e;
        } catch (Exception ignorado) { }
        return padrao;
    }

    private boolean verificarSessao(ApiClient.Result r) {
        if (r.status == 401) {
            // chamado de thread de rede — a troca de tela vai para a UI
            runOnUiThread(() -> {
                Sessao.encerrar(this);
                Sessao.irParaLogin(this);
            });
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------------
    // Caixa
    // ------------------------------------------------------------------
    private void carregarStatus() {
        new Thread(() -> {
            try {
                ApiClient.Result r = ApiClient.get("/api/pdv/status");
                if (!verificarSessao(r)) return;
                if (!r.ok()) {
                    erro("Falha ao consultar o caixa: " + mensagemErro(r, "HTTP " + r.status));
                    return;
                }
                JSONObject j = new JSONObject(r.body);
                final boolean tem = j.optBoolean("tem_caixa", false);
                final long cx = j.optLong("caixa_id", 0);
                final String num = j.optString("numero", "");
                final double ab = j.optDouble("valor_abertura", 0);
                final double saldo = j.optDouble("saldo", 0);
                runOnUiThread(() -> {
                    caixaId = cx;
                    numeroCaixa = num;
                    saldoCaixa = saldo;
                    if (tem) {
                        txtCaixa.setText(String.format(Locale.getDefault(),
                                "Caixa %s — abertura %s — saldo %s",
                                numeroCaixa, moeda(ab), moeda(saldoCaixa)));
                        btnFinalizar.setEnabled(true);
                        btnFecharCaixa.setText("Fechar");
                    } else {
                        txtCaixa.setText("Nenhum caixa aberto — toque em Fechar para abrir.");
                        btnFecharCaixa.setText("Abrir");
                        btnFinalizar.setEnabled(false);
                    }
                });
            } catch (Exception e) {
                erro("Sem conexão com o servidor.");
            }
        }).start();
    }

    private void dialogoAbrirCaixa() {
        View v = LayoutInflater.from(this).inflate(R.layout.dialog_abrir_caixa, null);
        final EditText editValor = v.findViewById(R.id.editValorAbertura);
        editValor.setText("0,00");
        new AlertDialog.Builder(this)
                .setTitle("Abrir caixa")
                .setView(v)
                .setCancelable(false)
                .setPositiveButton("Abrir", (d, w) -> {
                    double valor = lerValor(editValor.getText().toString());
                    abrirCaixa(valor);
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void abrirCaixa(double valor) {
        new Thread(() -> {
            try {
                JSONObject corpo = new JSONObject();
                corpo.put("valor_abertura", valor);
                ApiClient.Result r = ApiClient.post("/api/pdv/caixa/abrir",
                        corpo.toString());
                if (!verificarSessao(r)) return;
                if (r.ok()) {
                    runOnUiThread(this::carregarStatus);
                } else {
                    erro(mensagemErro(r, "Falha ao abrir o caixa."));
                }
            } catch (Exception e) {
                erro("Sem conexão com o servidor.");
            }
        }).start();
    }

    private void fecharCaixa() {
        if (carrinho.size() > 0) {
            new AlertDialog.Builder(this)
                    .setMessage("Há itens na venda atual. Fechar o caixa mesmo assim?")
                    .setPositiveButton("Fechar", (d, w) -> confirmarFechar())
                    .setNegativeButton("Voltar", null)
                    .show();
            return;
        }
        confirmarFechar();
    }

    private void confirmarFechar() {
        new AlertDialog.Builder(this)
                .setTitle("Fechar caixa")
                .setMessage("Confirma o fechamento? O saldo atual será gravado.")
                .setPositiveButton("Fechar", (d, w) -> {
                    new Thread(() -> {
                        try {
                            ApiClient.Result r = ApiClient.post(
                                    "/api/pdv/caixa/fechar", "{}");
                            if (!verificarSessao(r)) return;
                            if (r.ok()) {
                                JSONObject j = new JSONObject(r.body);
                                double vf = j.optDouble("valor_fechamento", 0);
                                runOnUiThread(() -> {
                                    carrinho.clear();
                                    adapterCarrinho.notifyDataSetChanged();
                                    atualizarTotal();
                                    Toast.makeText(this,
                                            "Caixa fechado. Saldo: " + moeda(vf),
                                            Toast.LENGTH_LONG).show();
                                    carregarStatus();
                                });
                            } else {
                                erro(mensagemErro(r, "Falha ao fechar o caixa."));
                            }
                        } catch (Exception e) {
                            erro("Sem conexão com o servidor.");
                        }
                    }).start();
                })
                .setNegativeButton("Voltar", null)
                .show();
    }

    private void movimentoCaixa(String tipo) {
        if (caixaId <= 0) {
            Toast.makeText(this, "Abra o caixa primeiro.", Toast.LENGTH_SHORT).show();
            return;
        }
        String titulo = tipo.equals("E") ? "Suprimento" : "Sangria";
        View v = LayoutInflater.from(this).inflate(R.layout.dialog_movimento, null);
        final EditText editValor = v.findViewById(R.id.editValorMovimento);
        final EditText editDesc = v.findViewById(R.id.editDescricaoMovimento);
        editDesc.setText(titulo);
        new AlertDialog.Builder(this)
                .setTitle(titulo)
                .setView(v)
                .setPositiveButton("Confirmar", (d, w) -> {
                    double valor = lerValor(editValor.getText().toString());
                    String desc = editDesc.getText().toString().trim();
                    if (valor <= 0 || desc.isEmpty()) {
                        Toast.makeText(this, "Informe valor e descrição.",
                                Toast.LENGTH_SHORT).show();
                        return;
                    }
                    postarMovimento(tipo, valor, desc);
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void postarMovimento(String tipo, double valor, String desc) {
        new Thread(() -> {
            try {
                JSONObject corpo = new JSONObject();
                corpo.put("tipo", tipo);
                corpo.put("valor", valor);
                corpo.put("descricao", desc);
                ApiClient.Result r = ApiClient.post("/api/pdv/caixa/movimento",
                        corpo.toString());
                if (!verificarSessao(r)) return;
                if (r.ok()) {
                    runOnUiThread(() -> {
                        Toast.makeText(this, "Movimento registrado.",
                                Toast.LENGTH_SHORT).show();
                        carregarStatus();
                    });
                } else {
                    erro(mensagemErro(r, "Falha no movimento."));
                }
            } catch (Exception e) {
                erro("Sem conexão com o servidor.");
            }
        }).start();
    }

    // ------------------------------------------------------------------
    // Produtos
    // ------------------------------------------------------------------
    private void buscarProdutos() {
        String termo = editBusca.getText().toString().trim();
        if (termo.isEmpty()) {
            Toast.makeText(this, "Digite o código ou a descrição.",
                    Toast.LENGTH_SHORT).show();
            return;
        }
        new Thread(() -> {
            try {
                ApiClient.Result r = ApiClient.get("/api/pdv/produtos?"
                        + ApiClient.query("busca", termo));
                if (!verificarSessao(r)) return;
                if (!r.ok()) {
                    erro(mensagemErro(r, "Falha na busca."));
                    return;
                }
                JSONArray arr = new JSONArray(r.body);
                resultados.clear();
                for (int i = 0; i < arr.length(); i++) {
                    JSONObject j = arr.getJSONObject(i);
                    Produto p = new Produto();
                    p.id = j.optLong("id");
                    p.descricao = j.optString("descricao", "");
                    String dpdv = j.optString("descricao_pdv", "");
                    if (!dpdv.isEmpty()) {
                        p.descricao = dpdv;
                    }
                    p.preco = j.optDouble("preco_venda", 0);
                    resultados.add(p);
                }
                runOnUiThread(() -> {
                    adapterResultados.notifyDataSetChanged();
                    listaResultados.setVisibility(
                            resultados.isEmpty() ? View.GONE : View.VISIBLE);
                    if (resultados.isEmpty()) {
                        Toast.makeText(this, "Nenhum produto encontrado.",
                                Toast.LENGTH_SHORT).show();
                    }
                });
            } catch (Exception e) {
                erro("Sem conexão com o servidor.");
            }
        }).start();
    }

    private void adicionarPorCodigo(String codigo) {
        new Thread(() -> {
            try {
                ApiClient.Result r = ApiClient.get("/api/pdv/produtos/buscar?"
                        + ApiClient.query("codigo", codigo));
                if (!verificarSessao(r)) return;
                if (!r.ok()) {
                    runOnUiThread(() -> Toast.makeText(this,
                            mensagemErro(r, "Produto não encontrado."),
                            Toast.LENGTH_LONG).show());
                    return;
                }
                JSONObject j = new JSONObject(r.body);
                final long id = j.optLong("id");
                final String desc = j.optString("descricao", "");
                final double preco = j.optDouble("preco_venda", 0);
                runOnUiThread(() -> adicionarAoCarrinho(id, desc, preco));
            } catch (Exception e) {
                erro("Sem conexão com o servidor.");
            }
        }).start();
    }

    private void abrirCamera() {
        if (ContextCompat.checkSelfPermission(this,
                Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this,
                    new String[]{Manifest.permission.CAMERA}, 1001);
            return;
        }
        ScanOptions opcoes = new ScanOptions();
        opcoes.setDesiredBarcodeFormats(ScanOptions.PRODUCT_CODE_TYPES);
        opcoes.setPrompt("Aponte para o código de barras do produto");
        opcoes.setBeepEnabled(true);
        opcoes.setOrientationLocked(false);
        scanLauncher.launch(opcoes);
    }

    @Override
    public void onRequestPermissionsResult(int codigo, String[] permissoes,
                                           int[] resultadosPermissao) {
        super.onRequestPermissionsResult(codigo, permissoes, resultadosPermissao);
        if (codigo == 1001 && resultadosPermissao.length > 0
                && resultadosPermissao[0] == PackageManager.PERMISSION_GRANTED) {
            abrirCamera();
        }
    }

    // ------------------------------------------------------------------
    // Carrinho
    // ------------------------------------------------------------------
    private void adicionarAoCarrinho(long produtoId, String descricao,
                                     double preco) {
        for (ItemCarrinho item : carrinho) {
            if (item.produtoId == produtoId) {
                item.quantidade += 1;
                adapterCarrinho.notifyDataSetChanged();
                atualizarTotal();
                return;
            }
        }
        ItemCarrinho item = new ItemCarrinho();
        item.produtoId = produtoId;
        item.descricao = descricao;
        item.precoUnitario = preco;
        item.quantidade = 1;
        carrinho.add(item);
        itemSelecionado = carrinho.size() - 1;
        adapterCarrinho.notifyDataSetChanged();
        atualizarTotal();
    }

    private void ajustarQuantidade(double delta) {
        if (itemSelecionado < 0 || itemSelecionado >= carrinho.size()) {
            Toast.makeText(this, "Toque num item da lista primeiro.",
                    Toast.LENGTH_SHORT).show();
            return;
        }
        ItemCarrinho item = carrinho.get(itemSelecionado);
        item.quantidade += delta;
        if (item.quantidade <= 0) {
            carrinho.remove(itemSelecionado);
            itemSelecionado = -1;
        }
        adapterCarrinho.notifyDataSetChanged();
        atualizarTotal();
    }

    private void removerItem() {
        if (itemSelecionado < 0 || itemSelecionado >= carrinho.size()) {
            Toast.makeText(this, "Toque num item da lista primeiro.",
                    Toast.LENGTH_SHORT).show();
            return;
        }
        carrinho.remove(itemSelecionado);
        itemSelecionado = -1;
        adapterCarrinho.notifyDataSetChanged();
        atualizarTotal();
    }

    private double subtotal() {
        double s = 0;
        for (ItemCarrinho i : carrinho) {
            s += i.total();
        }
        return s;
    }

    private double desconto() {
        return lerValor(editDesconto.getText().toString());
    }

    private double total() {
        double t = subtotal() - desconto();
        return t < 0 ? 0 : t;
    }

    private void atualizarTotal() {
        txtTotal.setText("TOTAL " + moeda(total()));
    }

    // ------------------------------------------------------------------
    // Formas de pagamento
    // ------------------------------------------------------------------
    private void carregarFormas() {
        new Thread(() -> {
            try {
                ApiClient.Result r = ApiClient.get("/api/pdv/formas-pagamento");
                if (!r.ok()) return;
                JSONArray arr = new JSONArray(r.body);
                for (int i = 0; i < arr.length(); i++) {
                    JSONObject j = arr.getJSONObject(i);
                    FormaPagamento f = new FormaPagamento();
                    f.id = j.optLong("id");
                    f.descricao = j.optString("descricao", "");
                    f.tipo = j.optString("tipo", "").trim();
                    formas.add(f);
                }
            } catch (Exception ignorado) {
                // formas são carregadas de novo na hora da venda se falhar
            }
        }).start();
    }

    // ------------------------------------------------------------------
    // Venda
    // ------------------------------------------------------------------
    private void finalizarVenda() {
        if (carrinho.isEmpty()) {
            Toast.makeText(this, "Adicione itens à venda.",
                    Toast.LENGTH_SHORT).show();
            return;
        }
        if (caixaId <= 0) {
            Toast.makeText(this, "Nenhum caixa aberto.",
                    Toast.LENGTH_LONG).show();
            return;
        }
        if (formas.isEmpty()) {
            carregarFormas();
            Toast.makeText(this, "Formas de pagamento carregando — tente de novo.",
                    Toast.LENGTH_SHORT).show();
            return;
        }
        dialogoPagamento();
    }

    private void dialogoPagamento() {
        View v = LayoutInflater.from(this).inflate(R.layout.dialog_pagamento, null);
        RadioGroup grupo = new RadioGroup(this);
        grupo.setOrientation(RadioGroup.VERTICAL);
        final ArrayList<RadioButton> radios = new ArrayList<>();
        for (int i = 0; i < formas.size(); i++) {
            RadioButton rb = new RadioButton(this);
            rb.setText(formas.get(i).descricao);
            rb.setId(i);
            grupo.addView(rb);
            radios.add(rb);
        }
        if (!radios.isEmpty()) {
            radios.get(0).setChecked(true);
        }
        ((LinearLayout) v.findViewById(R.id.editValorPago)
                .getParent()).addView(grupo, 0);

        final EditText editPago = v.findViewById(R.id.editValorPago);
        final TextView txtTroco = v.findViewById(R.id.txtTroco);
        editPago.setText(String.format(Locale.getDefault(), "%.2f",
                total()).replace('.', ','));
        txtTroco.setText("Troco: " + moeda(0));

        editPago.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int a, int b, int c) { }
            @Override public void onTextChanged(CharSequence s, int a, int b, int c) { }
            @Override public void afterTextChanged(Editable s) {
                double pago = lerValor(s.toString());
                double troco = pago - total();
                txtTroco.setText("Troco: " + moeda(troco < 0 ? 0 : troco));
            }
        });

        new AlertDialog.Builder(this)
                .setTitle("Pagamento — total " + moeda(total()))
                .setView(v)
                .setPositiveButton("Confirmar venda", (d, w) -> {
                    int sel = grupo.getCheckedRadioButtonId();
                    if (sel < 0 || sel >= formas.size()) {
                        Toast.makeText(this, "Escolha a forma de pagamento.",
                                Toast.LENGTH_SHORT).show();
                        return;
                    }
                    FormaPagamento f = formas.get(sel);
                    double pago = lerValor(editPago.getText().toString());
                    postarVenda(f.id, pago);
                })
                .setNegativeButton("Voltar", null)
                .show();
    }

    private void postarVenda(long formaId, double valorPago) {
        btnFinalizar.setEnabled(false);
        new Thread(() -> {
            try {
                JSONObject corpo = new JSONObject();
                JSONArray itens = new JSONArray();
                for (ItemCarrinho i : carrinho) {
                    JSONObject it = new JSONObject();
                    it.put("produto_id", i.produtoId);
                    it.put("quantidade", i.quantidade);
                    it.put("preco_unitario", i.precoUnitario);
                    itens.put(it);
                }
                corpo.put("itens", itens);
                corpo.put("desconto", desconto());
                corpo.put("forma_pagamento_id", formaId);
                corpo.put("valor_pago", valorPago);
                corpo.put("observacoes", "PDV Mobile");

                ApiClient.Result r = ApiClient.post("/api/pdv/vendas",
                        corpo.toString());
                if (!verificarSessao(r)) return;
                if (r.ok()) {
                    JSONObject j = new JSONObject(r.body);
                    final String cupom = montarCupom(j);
                    // dados do cupom em PDF — montados antes de limpar o carrinho
                    final String numeroVenda = j.optString("numero", "-");
                    final List<String> linhasItens = new ArrayList<>();
                    for (ItemCarrinho i : carrinho) {
                        linhasItens.add(i.descricao + "  x"
                                + String.format(Locale.getDefault(), "%.2f",
                                        i.quantidade)
                                + "  =  " + moeda(i.total()));
                    }
                    final double sub = j.optDouble("subtotal", 0);
                    final double desc = j.optDouble("desconto", 0);
                    final double tot = j.optDouble("total", 0);
                    final double pago = j.optDouble("valor_pago", 0);
                    final double troco = j.optDouble("troco", 0);
                    runOnUiThread(() -> {
                        btnFinalizar.setEnabled(true);
                        carrinho.clear();
                        editDesconto.setText("");
                        adapterCarrinho.notifyDataSetChanged();
                        atualizarTotal();
                        carregarStatus();
                        new AlertDialog.Builder(this)
                                .setTitle("Venda registrada")
                                .setMessage(cupom)
                                .setPositiveButton("OK", null)
                                .setNeutralButton("Compartilhar", (d, w) -> {
                                    Intent send = new Intent(Intent.ACTION_SEND);
                                    send.setType("text/plain");
                                    send.putExtra(Intent.EXTRA_TEXT, cupom);
                                    startActivity(Intent.createChooser(send,
                                            "Enviar cupom"));
                                })
                                .setNegativeButton("PDF", (d, w) ->
                                        compartilharPdfCupom(numeroVenda,
                                                linhasItens, sub, desc, tot,
                                                pago, troco))
                                .show();
                    });
                } else {
                    runOnUiThread(() -> {
                        btnFinalizar.setEnabled(true);
                        Toast.makeText(this,
                                mensagemErro(r, "Falha ao registrar a venda."),
                                Toast.LENGTH_LONG).show();
                    });
                }
            } catch (Exception e) {
                runOnUiThread(() -> {
                    btnFinalizar.setEnabled(true);
                    Toast.makeText(this, "Sem conexão com o servidor.",
                            Toast.LENGTH_LONG).show();
                });
            }
        }).start();
    }

    /** Gera o cupom em PDF no cache e abre o compartilhamento. */
    private void compartilharPdfCupom(String numeroVenda,
                                      List<String> linhasItens,
                                      double sub, double desc, double tot,
                                      double pago, double troco) {
        new Thread(() -> {
            File pdf = CupomPdf.gerar(this, numeroVenda, linhasItens,
                    sub, desc, tot, pago, troco);
            runOnUiThread(() -> {
                if (pdf == null) {
                    Toast.makeText(this, "Falha ao gerar o PDF do cupom.",
                            Toast.LENGTH_LONG).show();
                    return;
                }
                try {
                    Uri uri = FileProvider.getUriForFile(this,
                            "com.example.erp2026_pdv.fileprovider", pdf);
                    Intent send = new Intent(Intent.ACTION_SEND);
                    send.setType("application/pdf");
                    send.putExtra(Intent.EXTRA_STREAM, uri);
                    send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    startActivity(Intent.createChooser(send, "Enviar cupom PDF"));
                } catch (Exception e) {
                    Toast.makeText(this,
                            "Não foi possível compartilhar o PDF.",
                            Toast.LENGTH_LONG).show();
                }
            });
        }).start();
    }

    private String montarCupom(JSONObject j) {
        StringBuilder sb = new StringBuilder();
        sb.append("ERP 2026 — PDV\n");
        sb.append("Venda nº ").append(j.optString("numero", "-")).append('\n');
        sb.append("------------------------------\n");
        for (ItemCarrinho i : new ArrayList<>(carrinho)) {
            sb.append(i.descricao).append(" x")
                    .append(String.format(Locale.getDefault(), "%.2f",
                            i.quantidade)).append('\n');
        }
        sb.append("------------------------------\n");
        sb.append("Subtotal: ").append(moeda(j.optDouble("subtotal", 0)))
                .append('\n');
        sb.append("Desconto: ").append(moeda(j.optDouble("desconto", 0)))
                .append('\n');
        sb.append("TOTAL: ").append(moeda(j.optDouble("total", 0)))
                .append('\n');
        sb.append("Pago: ").append(moeda(j.optDouble("valor_pago", 0)))
                .append('\n');
        sb.append("Troco: ").append(moeda(j.optDouble("troco", 0)))
                .append('\n');
        sb.append("Obrigado pela preferência!");
        return sb.toString();
    }
}
