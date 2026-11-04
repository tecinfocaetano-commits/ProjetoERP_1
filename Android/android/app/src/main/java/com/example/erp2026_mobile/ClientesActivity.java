package com.example.erp2026_mobile;

import android.content.Intent;
import android.widget.Button;
import android.widget.Toast;

import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton;

import java.util.ArrayList;
import java.util.List;

/**
 * Lista de clientes.
 *
 * <p>Funciona off-line: a lista vem do banco local (cache do servidor +
 * cadastros feitos no aparelho). Quando ha rede, uma sincronizacao em segundo
 * plano atualiza o cache e envia os cadastros pendentes.
 */
public class ClientesActivity extends BaseListaActivity {

    private boolean sincronizando;
    private boolean sincronizouNestaVisita;

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
        return "Nenhum cliente salvo no aparelho.\nToque em \"Incluir cliente\" para cadastrar.";
    }

    @Override
    protected int itemMenuAtual() {
        return R.id.navClientes;
    }

    @Override
    protected boolean temBusca() {
        return true;
    }

    @Override
    protected String dicaBusca() {
        return "Pesquisar clientes";
    }

    @Override
    protected void onResume() {
        sincronizouNestaVisita = false;
        super.onResume();
    }

    @Override
    protected void aoCriar() {
        ExtendedFloatingActionButton fab = findViewById(R.id.fabIncluirCliente);
        if (fab != null) {
            fab.setOnClickListener(v ->
                    startActivity(new Intent(this, InserirClienteActivity.class)));
        }
        Button botao = findViewById(R.id.buttonSincronizar);
        if (botao != null) {
            botao.setOnClickListener(v -> sincronizar(true));
        }
        atualizarBotaoSincronizar();
    }

    @Override
    protected void aoPublicar() {
        atualizarBotaoSincronizar();
        // Atualiza o cache sozinho na primeira exibicao da tela, sem travar a
        // lista (que ja apareceu com os dados locais).
        if (!sincronizouNestaVisita && Conectividade.temRede(this)) {
            sincronizouNestaVisita = true;
            sincronizar(false);
        }
    }

    @Override
    protected List<String> buscar() throws Exception {
        BancoLocal banco = BancoLocal.get(this);

        // Primeira carga (cache vazio): espera o download para nao abrir vazio.
        if (banco.contarClientes() == 0 && Conectividade.temRede(this)) {
            try {
                Sincronizacao.baixarClientes(this);
            } catch (Exception ignorado) {
                // segue com o que existe localmente
            }
        }

        List<ClienteLocal> locais = banco.listarClientes();

        List<String> linhas = new ArrayList<>();
        for (ClienteLocal c : locais) {
            String linha = c.resumo();
            if (!c.sincronizado) {
                linha += "\n(aguardando sincronização)";
            }
            linhas.add(linha);
        }
        return linhas;
    }

    private void sincronizar(final boolean mostrarResultado) {
        if (sincronizando || isFinishing()) {
            return;
        }
        if (!Conectividade.temRede(this)) {
            Toast.makeText(this,
                    "Sem conexão.\nOs dados continuam salvos no aparelho.",
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
                if (r.enviouAlgo() || r.clientesBaixados > 0) {
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
}
