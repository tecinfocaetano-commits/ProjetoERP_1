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

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Cadastro de orçamento no app.
 *
 * <p>Off-line: clientes e produtos vem do banco local (cache do servidor). O
 * orçamento é gravado no aparelho e entra na fila de sincronização; quando há
 * conexão, é enviado na hora para a API. O servidor recalcula os totais e grava
 * como PEDIDO_VENDA com STATUS 'O'.
 */
public class InserirOrcamentoActivity extends BaseActivity {

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

    private final List<ClienteLocal> clientes = new ArrayList<>();
    private final List<ProdutoLocal> produtos = new ArrayList<>();
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
    // Carga de clientes e produtos (banco local + atualizacao on-line)
    // ------------------------------------------------------------------

    private void carregarDados() {
        buttonAdicionarItem.setEnabled(false);
        buttonSalvar.setEnabled(false);
        textViewStatus.setText("Carregando clientes e produtos...");

        new Thread(() -> {
            BancoLocal banco = BancoLocal.get(this);
            boolean temRede = Conectividade.temRede(this);

            if (temRede) {
                // Atualiza os caches sem impedir o uso off-line se falhar.
                try {
                    Sincronizacao.baixarClientes(this);
                } catch (Exception ignorado) {
                    // usa o cache atual
                }
                try {
                    Sincronizacao.baixarProdutos(this);
                } catch (Exception ignorado) {
                    // usa o cache atual
                }
            }

            final List<ClienteLocal> novosClientes = new ArrayList<>();
            novosClientes.add(new ClienteLocal("Selecione o cliente...", ""));
            novosClientes.addAll(banco.listarClientes());

            final List<ProdutoLocal> novosProdutos = new ArrayList<>();
            novosProdutos.add(new ProdutoLocal(null, "Selecione o produto...", 0));
            novosProdutos.addAll(banco.listarProdutos());

            final boolean comRede = temRede;
            runOnUiThread(() -> preencher(novosClientes, novosProdutos, comRede));
        }).start();
    }

    /** Roda na thread da interface: monta os spinners já com os dados. */
    private void preencher(List<ClienteLocal> novosClientes,
                           List<ProdutoLocal> novosProdutos,
                           boolean comRede) {
        clientes.clear();
        clientes.addAll(novosClientes);
        produtos.clear();
        produtos.addAll(novosProdutos);

        List<String> nomesClientes = new ArrayList<>();
        for (ClienteLocal c : clientes) {
            if (c.id == 0) {
                nomesClientes.add(c.nome);
            } else {
                nomesClientes.add(c.nome + (c.idServidor == null ? " (novo)" : ""));
            }
        }
        ArrayAdapter<String> adClientes = new ArrayAdapter<>(
                this, android.R.layout.simple_spinner_item, nomesClientes);
        adClientes.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spinnerCliente.setAdapter(adClientes);
        spinnerCliente.setSelection(0);

        List<String> nomesProdutos = new ArrayList<>();
        for (ProdutoLocal p : produtos) {
            if (p.id == 0) {
                nomesProdutos.add(p.descricao);
            } else {
                nomesProdutos.add(p.descricao + " — " + Fmt.moeda(p.precoVenda));
            }
        }
        ArrayAdapter<String> adProdutos = new ArrayAdapter<>(
                this, android.R.layout.simple_spinner_item, nomesProdutos);
        adProdutos.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spinnerProduto.setAdapter(adProdutos);
        spinnerProduto.setSelection(0);

        boolean temClientes = clientes.size() > 1;
        boolean temProdutos = produtos.size() > 1;

        if (!temClientes || !temProdutos) {
            StringBuilder msg = new StringBuilder();
            if (!temClientes) {
                msg.append("Nenhum cliente salvo. Cadastre em Clientes");
            }
            if (!temProdutos) {
                if (msg.length() > 0) {
                    msg.append(" e ");
                }
                msg.append("nenhum produto salvo. Conecte-se uma vez para baixar o catálogo");
            }
            msg.append(".");
            textViewStatus.setText(msg.toString());
        } else if (!comRede) {
            textViewStatus.setText("Modo off-line: usando os dados salvos no aparelho.");
        } else {
            textViewStatus.setText("");
        }

        buttonAdicionarItem.setEnabled(temProdutos);
        buttonSalvar.setEnabled(temClientes);
    }

    // ------------------------------------------------------------------
    // Itens
    // ------------------------------------------------------------------

    private void selecionarProduto(int position) {
        if (position < 0 || position >= produtos.size()) {
            return;
        }
        ProdutoLocal p = produtos.get(position);
        if (p.id == 0) {
            editTextValorUnitario.setText("");
            return;
        }
        editTextValorUnitario.setText(String.format(BR, "%.2f", p.precoVenda));
    }

    private void adicionarItem() {
        int posicao = spinnerProduto.getSelectedItemPosition();
        if (posicao <= 0 || posicao >= produtos.size()) {
            Toast.makeText(this, "Selecione um produto.", Toast.LENGTH_SHORT).show();
            return;
        }

        ProdutoLocal produto = produtos.get(posicao);
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

        itens.add(new Item(produto.idServidor, produto.descricao, quantidade, valor, desconto));
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
    // Gravação (local + fila de sincronização)
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

        final ClienteLocal cliente = clientes.get(posicaoCliente);
        final String observacoes = editTextObservacoes.getText().toString().trim();
        double desconto = numero(editTextDesconto.getText().toString());

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

        final double descontoFinal = desconto;

        salvando = true;
        buttonSalvar.setEnabled(false);
        buttonSalvar.setText("Salvando...");
        textViewStatus.setText("Salvando no aparelho...");

        new Thread(() -> {
            boolean salvou = false;
            Sincronizacao.Resultado resultado = null;
            String numero = "";

            try {
                BancoLocal banco = BancoLocal.get(this);

                OrcamentoLocal orcamento = new OrcamentoLocal();
                orcamento.clienteLocalId = cliente.id;
                orcamento.clienteNome = cliente.nome;
                orcamento.data = new SimpleDateFormat("dd/MM/yyyy", BR).format(new Date());
                orcamento.desconto = descontoFinal;
                orcamento.total = subtotalAtual - descontoFinal;
                orcamento.observacao = observacoes;
                orcamento.status = OrcamentoLocal.STATUS_RASCUNHO;
                orcamento.sincronizado = false;

                List<OrcamentoItemLocal> locais = new ArrayList<>();
                for (Item item : itens) {
                    OrcamentoItemLocal li = new OrcamentoItemLocal(
                            item.descricao, item.quantidade, item.valorUnitario);
                    li.produtoId = item.produtoId;
                    li.desconto = item.desconto;
                    li.recalcular();
                    locais.add(li);
                }

                long idLocal = banco.salvarOrcamento(orcamento, locais);

                // O envio real e montado a partir do banco; o payload fica so
                // como referencia/diagnostico da fila.
                banco.enfileirar(ItemOutbox.TIPO_ORCAMENTO,
                        ItemOutbox.ACAO_INSERIR, idLocal, "{}");

                salvou = true;

                if (Conectividade.temRede(InserirOrcamentoActivity.this)) {
                    resultado = Sincronizacao.sincronizar(InserirOrcamentoActivity.this);
                    if (resultado.orcamentosEnviados > 0) {
                        OrcamentoLocal salvo = banco.buscarOrcamento(idLocal);
                        if (salvo != null) {
                            numero = salvo.numero;
                        }
                    }
                }
            } catch (Exception e) {
                salvou = false;
            }

            final boolean salvouFinal = salvou;
            final Sincronizacao.Resultado resultadoFinal = resultado;
            final String numeroFinal = numero;

            runOnUiThread(() -> {
                salvando = false;
                buttonSalvar.setEnabled(true);
                buttonSalvar.setText("Salvar orçamento");

                if (!salvouFinal) {
                    textViewStatus.setText("Não foi possível salvar o orçamento no aparelho.");
                    Toast.makeText(InserirOrcamentoActivity.this,
                            "Não foi possível salvar o orçamento.",
                            Toast.LENGTH_LONG).show();
                    return;
                }

                if (resultadoFinal != null && resultadoFinal.sessaoExpirada != null) {
                    Sessao.tratarSessaoExpirada(InserirOrcamentoActivity.this,
                            resultadoFinal.sessaoExpirada);
                    return;
                }

                boolean enviado = resultadoFinal != null
                        && resultadoFinal.orcamentosEnviados > 0;

                if (enviado) {
                    String texto = numeroFinal.isEmpty()
                            ? "Orçamento salvo e sincronizado com o servidor."
                            : "Orçamento " + numeroFinal + " salvo e sincronizado.";
                    Toast.makeText(InserirOrcamentoActivity.this, texto,
                            Toast.LENGTH_LONG).show();
                } else {
                    Toast.makeText(InserirOrcamentoActivity.this,
                            "Orçamento salvo no aparelho.\n"
                                    + "Será enviado ao servidor na próxima sincronização.",
                            Toast.LENGTH_LONG).show();
                }
                setResult(RESULT_OK);
                finish();
            });
        }).start();
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
    // Modelo simples dos itens da tela
    // ------------------------------------------------------------------

    private static final class Item {
        final Long produtoId;
        final String descricao;
        final double quantidade;
        final double valorUnitario;
        final double desconto;

        Item(Long produtoId, String descricao, double quantidade,
             double valorUnitario, double desconto) {
            this.produtoId = produtoId;
            this.descricao = descricao;
            this.quantidade = quantidade;
            this.valorUnitario = valorUnitario;
            this.desconto = desconto;
        }

        double total() {
            return (quantidade * valorUnitario) - desconto;
        }
    }
}
