package com.example.erp2026_mobile;

import android.app.AlertDialog;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.appcompat.app.ActionBar;

import com.google.android.material.bottomnavigation.BottomNavigationView;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Base das telas de lista do app.
 *
 * Centraliza o comportamento esperado em qualquer listagem:
 *  - indicador de progresso enquanto busca os dados;
 *  - estado vazio com mensagem própria;
 *  - erro com mensagem amigável e botão "Tentar novamente";
 *  - recarrega sempre que a tela volta ao primeiro plano;
 *  - devolve ao login quando a sessão expira (HTTP 401);
 *  - barra de pesquisa opcional na barra superior (filtrando a lista).
 */
public abstract class BaseListaActivity extends BaseActivity {

    private ProgressBar progressBar;
    private TextView textViewMensagem;
    private Button buttonTentarNovamente;
    private ListView listView;
    private EditText editTextBusca;
    private final List<String> itens = new ArrayList<>();
    private final List<String> todos = new ArrayList<>();
    private String filtro = "";
    private ArrayAdapter<String> adapter;
    private boolean carregando;

    /** Layout da tela (deve ter os ids progressBar, textViewMensagem, buttonTentarNovamente e listViewItens). */
    protected abstract int layoutId();

    /** Título exibido na barra superior. */
    protected abstract String titulo();

    /** Mensagem exibida quando a consulta não retorna registros. */
    protected abstract String textoVazio();

    /** Executado em segundo plano: consulta a API e devolve as linhas da lista. */
    protected abstract List<String> buscar() throws Exception;

    /** Chamado na thread da interface imediatamente antes de exibir a lista. */
    protected void aoPublicar() { }

    /** Gancho opcional para as telas que têm conteúdo próprio (ex.: totais). */
    protected void aoCriar() { }

    /** Item do menu inferior que representa esta tela (0 = tela sem menu inferior). */
    protected int itemMenuAtual() {
        return 0;
    }

    /** Clique em uma linha da lista; o padrão abre o detalhe em um diálogo. */
    protected void aoSelecionarItem(int posicao, String texto) {
        mostrarDetalhe(texto);
    }

    /** Liga a barra de pesquisa na barra superior (ao lado da seta de voltar). */
    protected boolean temBusca() {
        return false;
    }

    /** Texto de dica da barra de pesquisa. */
    protected String dicaBusca() {
        return "Pesquisar";
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        setContentView(layoutId());
        setTitle(titulo());
        configurarBusca();

        progressBar = findViewById(R.id.progressBar);
        textViewMensagem = findViewById(R.id.textViewMensagem);
        buttonTentarNovamente = findViewById(R.id.buttonTentarNovamente);
        listView = findViewById(R.id.listViewItens);

        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, itens);
        listView.setAdapter(adapter);
        listView.setOnItemClickListener((parent, view, position, id) -> aoSelecionarItem(position, itens.get(position)));

        buttonTentarNovamente.setOnClickListener(v -> carregar());

        BottomNavigationView menuInferior = findViewById(R.id.bottomNavigation);
        if (menuInferior != null && itemMenuAtual() != 0) {
            Navegacao.configurar(menuInferior, this, itemMenuAtual());
        }

        aoCriar();
    }

    @Override
    protected void onResume() {
        super.onResume();
        // Mantém os dados atualizados ao voltar de outra tela
        if (progressBar != null) {
            carregar();
        }
    }

    /** Recarrega a lista após uma ação feita na própria tela (ex.: conversão). */
    protected void recarregar() {
        if (progressBar != null) {
            carregar();
        }
    }

    private void carregar() {
        if (carregando) {
            return;
        }
        carregando = true;
        progressBar.setVisibility(View.VISIBLE);
        textViewMensagem.setVisibility(View.GONE);
        buttonTentarNovamente.setVisibility(View.GONE);
        listView.setVisibility(View.GONE);

        new Thread(() -> {
            try {
                final List<String> novos = buscar();
                runOnUiThread(() -> publicar(novos));
            } catch (final Exception e) {
                runOnUiThread(() -> falhar(e));
            }
        }).start();
    }

    /** Coloca a barra de pesquisa no espaço da barra superior, à direita da seta. */
    private void configurarBusca() {
        if (!temBusca()) {
            return;
        }
        ActionBar barra = getSupportActionBar();
        if (barra == null) {
            return;
        }

        barra.setDisplayShowTitleEnabled(false);
        barra.setDisplayShowCustomEnabled(true);

        View campo = getLayoutInflater().inflate(R.layout.include_barra_busca, null);
        editTextBusca = campo.findViewById(R.id.editTextBusca);
        editTextBusca.setHint(dicaBusca());
        editTextBusca.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) { }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) { }

            @Override
            public void afterTextChanged(Editable s) {
                filtro = s.toString();
                aplicarFiltro();
            }
        });

        ActionBar.LayoutParams params = new ActionBar.LayoutParams(
                ActionBar.LayoutParams.MATCH_PARENT,
                ActionBar.LayoutParams.WRAP_CONTENT);
        params.gravity = Gravity.CENTER_VERTICAL;
        barra.setCustomView(campo, params);
    }

    private void publicar(List<String> novos) {
        carregando = false;
        progressBar.setVisibility(View.GONE);
        aoPublicar();

        todos.clear();
        if (novos != null) {
            todos.addAll(novos);
        }
        aplicarFiltro();
    }

    /** Aplica o texto digitado na pesquisa sobre a lista carregada. */
    private void aplicarFiltro() {
        if (adapter == null || textViewMensagem == null) {
            return;
        }

        String procurado = normalizar(filtro);
        itens.clear();
        for (String linha : todos) {
            if (procurado.isEmpty() || normalizar(linha).contains(procurado)) {
                itens.add(linha);
            }
        }
        adapter.notifyDataSetChanged();

        if (todos.isEmpty()) {
            textViewMensagem.setText(textoVazio());
            textViewMensagem.setVisibility(View.VISIBLE);
            listView.setVisibility(View.GONE);
        } else if (itens.isEmpty()) {
            textViewMensagem.setText("Nenhum item encontrado para \"" + filtro.trim() + "\".");
            textViewMensagem.setVisibility(View.VISIBLE);
            listView.setVisibility(View.GONE);
        } else {
            textViewMensagem.setVisibility(View.GONE);
            listView.setVisibility(View.VISIBLE);
        }
    }

    /** Minúsculas e sem acentos: a pesquisa ignora caixa e acentuação. */
    private static String normalizar(String texto) {
        if (texto == null) {
            return "";
        }
        String semAcento = Normalizer.normalize(texto, Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "");
        return semAcento.toLowerCase(Locale.ROOT).trim();
    }

    private void falhar(Exception e) {
        carregando = false;
        progressBar.setVisibility(View.GONE);

        if (e instanceof ApiException
                && Sessao.tratarSessaoExpirada(this, ((ApiException) e).resposta)) {
            return; // já voltou para o login
        }

        String mensagem = (e instanceof ApiException)
                ? ((ApiException) e).mensagemAmigavel()
                : "Não foi possível falar com o servidor.\nVerifique se a API está no ar.";

        textViewMensagem.setText(mensagem);
        textViewMensagem.setVisibility(View.VISIBLE);
        buttonTentarNovamente.setVisibility(View.VISIBLE);
        listView.setVisibility(View.GONE);
    }

    private void mostrarDetalhe(String texto) {
        new AlertDialog.Builder(this)
                .setTitle(titulo())
                .setMessage(texto)
                .setPositiveButton("Fechar", null)
                .show();
    }

    /** Erro de resposta da API, com mensagem pronta para o usuário. */
    protected static final class ApiException extends Exception {

        final ApiClient.Result resposta;

        ApiException(ApiClient.Result resposta) {
            super("HTTP " + resposta.status);
            this.resposta = resposta;
        }

        String mensagemAmigavel() {
            switch (resposta.status) {
                case 400:
                    return "Os dados enviados não foram aceitos pela API (HTTP 400).";
                case 401:
                    return "Sessão expirada. Entre novamente.";
                case 403:
                    return "Você não tem permissão para ver estes dados (HTTP 403).";
                case 404:
                    return "Endereço não encontrado na API (HTTP 404).";
                default:
                    if (resposta.status >= 500) {
                        return "Erro no servidor da API (HTTP " + resposta.status + ").";
                    }
                    return "A API respondeu com erro HTTP " + resposta.status + ".";
            }
        }
    }
}
