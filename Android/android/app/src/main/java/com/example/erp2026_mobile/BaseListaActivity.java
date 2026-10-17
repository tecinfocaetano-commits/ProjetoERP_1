package com.example.erp2026_mobile;

import android.app.AlertDialog;
import android.os.Bundle;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

import java.util.ArrayList;
import java.util.List;

/**
 * Base das telas de lista do app.
 *
 * Centraliza o comportamento esperado em qualquer listagem:
 *  - indicador de progresso enquanto busca os dados;
 *  - estado vazio com mensagem própria;
 *  - erro com mensagem amigável e botão "Tentar novamente";
 *  - recarrega sempre que a tela volta ao primeiro plano;
 *  - devolve ao login quando a sessão expira (HTTP 401).
 */
public abstract class BaseListaActivity extends AppCompatActivity {

    private ProgressBar progressBar;
    private TextView textViewMensagem;
    private Button buttonTentarNovamente;
    private ListView listView;
    private final List<String> itens = new ArrayList<>();
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

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        setContentView(layoutId());
        setTitle(titulo());

        progressBar = findViewById(R.id.progressBar);
        textViewMensagem = findViewById(R.id.textViewMensagem);
        buttonTentarNovamente = findViewById(R.id.buttonTentarNovamente);
        listView = findViewById(R.id.listViewItens);

        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, itens);
        listView.setAdapter(adapter);
        listView.setOnItemClickListener((parent, view, position, id) -> mostrarDetalhe(itens.get(position)));

        buttonTentarNovamente.setOnClickListener(v -> carregar());

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

    private void publicar(List<String> novos) {
        carregando = false;
        progressBar.setVisibility(View.GONE);
        aoPublicar();

        itens.clear();
        if (novos == null || novos.isEmpty()) {
            textViewMensagem.setText(textoVazio());
            textViewMensagem.setVisibility(View.VISIBLE);
            listView.setVisibility(View.GONE);
            return;
        }
        itens.addAll(novos);
        adapter.notifyDataSetChanged();
        listView.setVisibility(View.VISIBLE);
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
