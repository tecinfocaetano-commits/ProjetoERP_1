package com.example.erp2026_mobile;

import android.app.AlertDialog;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

/**
 * Configuracao por empresa (D9).
 *
 * <p>Cadastra, para cada empresa, a URL da API e o codigo do usuario. A empresa
 * usada no momento e a que abastece o {@link ApiClient} (aplicada em
 * {@link Configuracao#aplicarNoApi(android.content.Context)}). Trocar de empresa
 * encerra a sessao, porque o token pertence ao servidor anterior.
 */
public class ConfiguracaoActivity extends BaseActivity {

    private static final String NOVA_EMPRESA = "Nova empresa...";

    private Spinner spinnerEmpresas;
    private EditText editTextEmpresa;
    private EditText editTextUrl;
    private EditText editTextCodigo;
    private Button buttonTestar;
    private Button buttonSalvar;
    private Button buttonExcluir;
    private Button buttonUsar;
    private TextView textViewStatus;

    /** Codigos ja gravados (sem a opcao "Nova empresa"). */
    private final List<String> empresas = new ArrayList<String>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_configuracao);
        setTitle("Configuração do servidor");

        spinnerEmpresas = findViewById(R.id.spinnerEmpresas);
        editTextEmpresa = findViewById(R.id.editTextEmpresa);
        editTextUrl = findViewById(R.id.editTextUrl);
        editTextCodigo = findViewById(R.id.editTextCodigo);
        buttonTestar = findViewById(R.id.buttonTestar);
        buttonSalvar = findViewById(R.id.buttonSalvar);
        buttonExcluir = findViewById(R.id.buttonExcluir);
        buttonUsar = findViewById(R.id.buttonUsar);
        textViewStatus = findViewById(R.id.textViewStatus);

        buttonTestar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                testar();
            }
        });
        buttonSalvar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                gravar(false);
            }
        });
        buttonUsar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                gravar(true);
            }
        });
        buttonExcluir.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                confirmarExclusao();
            }
        });

        recarregar(null);
    }

    // ------------------------------------------------------------------
    // Spinner / preenchimento
    // ------------------------------------------------------------------

    /**
     * Reconstroi a lista de empresas. {@code selecionar} escolhe qual fica
     * selecionada; null usa a empresa atual do app.
     */
    private void recarregar(String selecionar) {
        empresas.clear();
        empresas.addAll(Configuracao.listarEmpresas(this));

        List<String> opcoes = new ArrayList<String>();
        opcoes.add(NOVA_EMPRESA);
        opcoes.addAll(empresas);

        ArrayAdapter<String> adapter = new ArrayAdapter<String>(
                this, android.R.layout.simple_spinner_item, opcoes);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);

        // A selecao e feita ANTES de ligar o listener: assim o preenchimento
        // inicial fica a cargo de preencher()/preencherNova() e o listener so
        // reage a escolha do usuario (evita apagar o campo ao recarregar).
        spinnerEmpresas.setAdapter(adapter);

        int indice = 0;
        String alvo = selecionar == null ? Configuracao.empresaAtual(this) : selecionar;
        if (!alvo.isEmpty()) {
            for (int i = 0; i < empresas.size(); i++) {
                if (empresas.get(i).equalsIgnoreCase(alvo)) {
                    indice = i + 1;
                    break;
                }
            }
        }
        spinnerEmpresas.setSelection(indice);

        spinnerEmpresas.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                if (position <= 0) {
                    preencherNova();
                } else {
                    preencher(empresas.get(position - 1));
                }
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // nada a fazer
            }
        });

        if (indice > 0) {
            preencher(empresas.get(indice - 1));
        } else {
            preencherNova();
        }
    }

    private void preencher(String empresa) {
        Configuracao configuracao = Configuracao.carregar(this, empresa);
        if (configuracao == null) {
            limpar();
            return;
        }
        editTextEmpresa.setText(configuracao.getEmpresa());
        editTextUrl.setText(configuracao.getUrlServidor());
        editTextCodigo.setText(configuracao.getCodigoUsuario());

        if (configuracao.getEmpresa().equalsIgnoreCase(Configuracao.empresaAtual(this))) {
            status("Empresa em uso: " + configuracao.getEmpresa());
        } else {
            status("Empresa selecionada: " + configuracao.getEmpresa());
        }
    }

    private void preencherNova() {
        limpar();
        editTextUrl.setText(Configuracao.URL_PADRAO);
        if (Configuracao.vazia(this)) {
            status("Nenhuma empresa cadastrada. Informe o servidor e o código do usuário.");
        }
    }

    private void limpar() {
        editTextEmpresa.setText("");
        editTextUrl.setText("");
        editTextCodigo.setText("");
    }

    private void status(String texto) {
        textViewStatus.setText(texto);
    }

    // ------------------------------------------------------------------
    // Acoes
    // ------------------------------------------------------------------

    private void testar() {
        final String url = Configuracao.normalizarUrl(editTextUrl.getText().toString());
        if (!Configuracao.urlValida(url)) {
            editTextUrl.setError("Informe uma URL válida, ex.: http://192.168.0.10:9000");
            editTextUrl.requestFocus();
            status("URL inválida.");
            return;
        }
        editTextUrl.setText(url);
        status("Testando " + url + " ...");
        buttonTestar.setEnabled(false);

        new Thread(new Runnable() {
            @Override
            public void run() {
                String resultado;
                try {
                    final ApiClient.Result resposta = ApiClient.ping(url);
                    if (resposta.status >= 200 && resposta.status < 300) {
                        resultado = "Servidor respondeu (HTTP " + resposta.status + ").";
                    } else {
                        resultado = "Servidor alcançável (HTTP " + resposta.status
                                + "). A conexão está funcionando.";
                    }
                } catch (Exception e) {
                    resultado = "Sem resposta de " + url + ".\n"
                            + "Verifique o endereço, a rede e se a API está no ar.";
                }

                final String mensagem = resultado;
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        buttonTestar.setEnabled(true);
                        status(mensagem);
                    }
                });
            }
        }).start();
    }

    /**
     * Valida e grava. Com {@code usar = true}, define a empresa como atual e
     * volta ao login (o token anterior era do outro servidor).
     */
    private void gravar(final boolean usar) {
        final String empresa = Configuracao.normalizarEmpresa(editTextEmpresa.getText().toString());
        final String url = Configuracao.normalizarUrl(editTextUrl.getText().toString());
        final String codigo = editTextCodigo.getText().toString().trim();

        if (empresa.isEmpty()) {
            editTextEmpresa.setError("Informe o código da empresa");
            editTextEmpresa.requestFocus();
            status("O código da empresa é obrigatório.");
            return;
        }
        if (!Configuracao.urlValida(url)) {
            editTextUrl.setError("Informe uma URL válida, ex.: http://192.168.0.10:9000");
            editTextUrl.requestFocus();
            status("O caminho do servidor é obrigatório.");
            return;
        }
        if (codigo.isEmpty()) {
            editTextCodigo.setError("Informe o código do usuário");
            editTextCodigo.requestFocus();
            status("O código do usuário é obrigatório.");
            return;
        }

        editTextUrl.setText(url);
        Configuracao.salvar(this, new Configuracao(empresa, url, codigo));

        if (usar) {
            Configuracao.definirEmpresaAtual(this, empresa);
            Configuracao.aplicarNoApi(this);
            Sessao.encerrar(this);
            Toast.makeText(this, "Empresa " + empresa + " definida. Entre novamente.",
                    Toast.LENGTH_LONG).show();
            Sessao.irParaLogin(this);
            return;
        }

        Configuracao.aplicarNoApi(this);
        recarregar(empresa);
        status("Configuração salva para " + empresa + ".");
        Toast.makeText(this, "Configuração salva.", Toast.LENGTH_SHORT).show();
    }

    private void confirmarExclusao() {
        final String empresa = Configuracao.normalizarEmpresa(editTextEmpresa.getText().toString());
        if (empresa.isEmpty() || Configuracao.carregar(this, empresa) == null) {
            status("Selecione uma empresa salva para excluir.");
            return;
        }

        boolean eraAtual = empresa.equalsIgnoreCase(Configuracao.empresaAtual(this));
        String mensagem = "Remover a configuração de \"" + empresa + "\"?";
        if (eraAtual) {
            mensagem += "\n\nEsta é a empresa em uso: você voltará para o login.";
        }

        new AlertDialog.Builder(this)
                .setTitle("Excluir empresa")
                .setMessage(mensagem)
                .setNegativeButton("Cancelar", null)
                .setPositiveButton("Excluir", (dialog, which) -> {
                    Configuracao.remover(ConfiguracaoActivity.this, empresa);
                    if (eraAtual) {
                        Configuracao.aplicarNoApi(ConfiguracaoActivity.this);
                        Sessao.encerrar(ConfiguracaoActivity.this);
                        Sessao.irParaLogin(ConfiguracaoActivity.this);
                    } else {
                        recarregar(null);
                        status("Configuração de " + empresa + " removida.");
                    }
                })
                .show();
    }
}
