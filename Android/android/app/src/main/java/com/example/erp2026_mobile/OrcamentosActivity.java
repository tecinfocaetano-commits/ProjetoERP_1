package com.example.erp2026_mobile;

import android.app.AlertDialog;
import android.content.Intent;
import android.widget.Button;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

/**
 * Orçamentos em aberto.
 *
 * <p>Funciona off-line: a lista vem do banco local (orçamentos criados no
 * aparelho aparecem como "aguardando sincronização"). Com rede, a tela
 * sincroniza sozinha e o botão "Sincronizar" mostra quantos registros faltam
 * enviar. A conversão em pedido continua sendo feita pela API e só está
 * disponível para orçamentos já sincronizados.
 */
public class OrcamentosActivity extends BaseListaActivity {

    private final List<Long> ids = new ArrayList<>();
    private boolean convertendo;
    private boolean sincronizando;
    private boolean sincronizouNestaVisita;

    @Override
    protected int layoutId() {
        return R.layout.activity_orcamentos;
    }

    @Override
    protected String titulo() {
        return "Orçamentos";
    }

    @Override
    protected String textoVazio() {
        return "Nenhum orçamento salvo no aparelho.\nUse \"Novo orçamento\" para criar o primeiro.";
    }

    @Override
    protected int itemMenuAtual() {
        return R.id.navVendas;
    }

    @Override
    protected void onResume() {
        sincronizouNestaVisita = false;
        super.onResume();
    }

    @Override
    protected void aoCriar() {
        findViewById(R.id.buttonNovoOrcamento).setOnClickListener(
                v -> startActivity(new Intent(this, InserirOrcamentoActivity.class)));

        Button botao = findViewById(R.id.buttonSincronizar);
        if (botao != null) {
            botao.setOnClickListener(v -> sincronizar(true));
        }
        atualizarBotaoSincronizar();
    }

    @Override
    protected void aoPublicar() {
        atualizarBotaoSincronizar();
        if (!sincronizouNestaVisita && Conectividade.temRede(this)) {
            sincronizouNestaVisita = true;
            sincronizar(false);
        }
    }

    @Override
    protected List<String> buscar() throws Exception {
        BancoLocal banco = BancoLocal.get(this);

        // Primeira carga (cache vazio): espera o download para nao abrir vazio.
        if (banco.contarOrcamentos() == 0 && Conectividade.temRede(this)) {
            try {
                Sincronizacao.baixarOrcamentos(this);
            } catch (Exception ignorado) {
                // segue com o que existe localmente
            }
        }

        List<OrcamentoLocal> locais = banco.listarOrcamentos();

        ids.clear();
        List<String> linhas = new ArrayList<>();
        for (OrcamentoLocal o : locais) {
            ids.add(o.id);

            StringBuilder linha = new StringBuilder("Orçamento ");
            linha.append(o.numero == null || o.numero.isEmpty() ? "#" + o.id : o.numero);
            if (!o.clienteNome.isEmpty()) {
                linha.append(" - ").append(o.clienteNome);
            }
            linha.append("\n").append(Fmt.moeda(o.total));
            if (!o.data.isEmpty()) {
                linha.append("   Emissão: ").append(o.data);
            }
            linha.append("\n").append(o.qtdItens).append(" item(ns)");
            if (!o.sincronizado) {
                linha.append("   (aguardando sincronização)");
            }
            linhas.add(linha.toString());
        }
        return linhas;
    }

    @Override
    protected void aoSelecionarItem(int posicao, String texto) {
        if (posicao < 0 || posicao >= ids.size()) {
            return;
        }
        OrcamentoLocal orcamento = BancoLocal.get(this).buscarOrcamento(ids.get(posicao));
        if (orcamento == null) {
            return;
        }

        String detalhes = texto + detalhesItens(orcamento);

        if (orcamento.idServidor == null || !orcamento.sincronizado) {
            new AlertDialog.Builder(this)
                    .setTitle("Orçamento")
                    .setMessage(detalhes + "\n\nEste orçamento ainda não foi enviado ao servidor."
                            + "\nSincronize para poder converter em pedido.")
                    .setNegativeButton("Fechar", null)
                    .setPositiveButton("Sincronizar", (dialog, which) -> sincronizar(true))
                    .show();
            return;
        }

        final long idServidor = orcamento.idServidor;
        new AlertDialog.Builder(this)
                .setTitle("Orçamento")
                .setMessage(detalhes + "\n\nDeseja converter este orçamento em pedido?")
                .setNegativeButton("Fechar", null)
                .setPositiveButton("Converter", (dialog, which) -> converter(idServidor))
                .show();
    }

    /** Lista os itens do orçamento para o diálogo de detalhes. */
    private String detalhesItens(OrcamentoLocal orcamento) {
        List<OrcamentoItemLocal> itens;
        try {
            itens = BancoLocal.get(this).listarItens(orcamento.id);
        } catch (Exception e) {
            return "";
        }
        if (itens == null || itens.isEmpty()) {
            return "";
        }
        StringBuilder sb = new StringBuilder("\n\nItens:");
        for (OrcamentoItemLocal item : itens) {
            String nome = item.descricao == null || item.descricao.isEmpty()
                    ? "Produto " + item.produtoId : item.descricao;
            sb.append("\n- ").append(nome)
                    .append("  x").append(Fmt.quantidade(item.quantidade))
                    .append("  ").append(Fmt.moeda(item.total));
        }
        return sb.toString();
    }

    private void sincronizar(final boolean mostrarResultado) {
        if (sincronizando || isFinishing()) {
            return;
        }
        if (!Conectividade.temRede(this)) {
            Toast.makeText(this,
                    "Sem conexão.\nOs orçamentos continuam salvos no aparelho.",
                    Toast.LENGTH_LONG).show();
            return;
        }

        sincronizando = true;
        atualizarBotaoSincronizar();

        new Thread(() -> {
            final Sincronizacao.Resultado r = Sincronizacao.sincronizar(this);
            runOnUiThread(() -> {
                if (isFinishing()) {
                    return;
                }
                sincronizando = false;
                atualizarBotaoSincronizar();

                if (r.sessaoExpirada != null) {
                    Sessao.tratarSessaoExpirada(this, r.sessaoExpirada);
                    return;
                }
                if (mostrarResultado || r.enviouAlgo() || r.falhas > 0) {
                    Toast.makeText(this, r.resumo(), Toast.LENGTH_LONG).show();
                }
                if (r.enviouAlgo() || r.orcamentosBaixados > 0) {
                    recarregar();
                }
            });
        }).start();
    }

    private void atualizarBotaoSincronizar() {
        Button botao = findViewById(R.id.buttonSincronizar);
        if (botao == null) {
            return;
        }
        if (sincronizando) {
            botao.setText("Sincronizando...");
        } else {
            int pendentes = Sincronizacao.pendentes(this);
            if (pendentes == 0) {
                botao.setText("Sincronizar");
            } else if (pendentes == 1) {
                botao.setText("Sincronizar (1 pendente)");
            } else {
                botao.setText("Sincronizar (" + pendentes + " pendentes)");
            }
        }
        botao.setEnabled(!sincronizando);
    }

    private void converter(final long idServidor) {
        if (convertendo) {
            return;
        }
        convertendo = true;

        new Thread(() -> {
            try {
                final ApiClient.Result r = ApiClient.post(
                        "/api/orcamentos/" + idServidor + "/converter", null);

                runOnUiThread(() -> {
                    convertendo = false;

                    if (Sessao.tratarSessaoExpirada(OrcamentosActivity.this, r)) {
                        return;
                    }
                    if (r.ok()) {
                        Toast.makeText(OrcamentosActivity.this,
                                "Orçamento convertido em pedido.",
                                Toast.LENGTH_LONG).show();
                        recarregar();
                    } else if (r.status == 409) {
                        Toast.makeText(OrcamentosActivity.this,
                                "Este orçamento já foi convertido.",
                                Toast.LENGTH_LONG).show();
                        recarregar();
                    } else {
                        Toast.makeText(OrcamentosActivity.this,
                                "Não foi possível converter (HTTP " + r.status + ").",
                                Toast.LENGTH_LONG).show();
                    }
                });
            } catch (final Exception e) {
                runOnUiThread(() -> {
                    convertendo = false;
                    Toast.makeText(OrcamentosActivity.this,
                            "Falha de conexão.\nVerifique se a API está no ar.",
                            Toast.LENGTH_LONG).show();
                });
            }
        }).start();
    }
}
