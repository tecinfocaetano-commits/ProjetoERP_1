package com.example.erp2026_mobile;

import android.os.Bundle;
import android.util.Patterns;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONObject;

/**
 * Cadastro de cliente.
 *
 * <p>Fluxo off-line: grava sempre no banco local e enfileira o envio na
 * {@code outbox}. Se houver conexao, tenta sincronizar na hora; caso contrario
 * o cadastro fica salvo no aparelho e sobe na proxima sincronizacao.
 */
public class InserirClienteActivity extends BaseActivity {
    private EditText editTextNome;
    private EditText editTextCpf;
    private EditText editTextEndereco;
    private EditText editTextCidade;
    private EditText editTextUf;
    private EditText editTextCep;
    private EditText editTextTelefone;
    private EditText editTextEmail;
    private Button buttonSalvar;
    private TextView textViewStatus;
    private boolean salvando;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        setContentView(R.layout.activity_inserir_cliente);
        setTitle("Inserir Cliente");

        editTextNome = findViewById(R.id.editTextNome);
        editTextCpf = findViewById(R.id.editTextCpf);
        editTextEndereco = findViewById(R.id.editTextEndereco);
        editTextCidade = findViewById(R.id.editTextCidade);
        editTextUf = findViewById(R.id.editTextUf);
        editTextCep = findViewById(R.id.editTextCep);
        editTextTelefone = findViewById(R.id.editTextTelefone);
        editTextEmail = findViewById(R.id.editTextEmail);
        buttonSalvar = findViewById(R.id.buttonSalvar);
        textViewStatus = findViewById(R.id.textViewStatus);

        buttonSalvar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                salvar();
            }
        });
    }

    /** Valida os campos obrigatórios destacando o primeiro problema. */
    private boolean validar(String nome, String cpf, String uf, String email) {
        if (nome.length() < 3) {
            editTextNome.setError("Informe o nome completo");
            editTextNome.requestFocus();
            return false;
        }

        String digitos = cpf.replaceAll("\\D", "");
        if (digitos.length() != 11 && digitos.length() != 14) {
            editTextCpf.setError("CPF (11 dígitos) ou CNPJ (14 dígitos)");
            editTextCpf.requestFocus();
            return false;
        }

        if (!uf.isEmpty() && uf.length() != 2) {
            editTextUf.setError("Use a sigla com 2 letras (ex.: SP)");
            editTextUf.requestFocus();
            return false;
        }

        if (!email.isEmpty() && !Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            editTextEmail.setError("E-mail inválido");
            editTextEmail.requestFocus();
            return false;
        }

        return true;
    }

    private void salvar() {
        // Evita cadastro duplicado por toque repetido no botão
        if (salvando) {
            return;
        }

        final String nome = editTextNome.getText().toString().trim();
        final String cpf = editTextCpf.getText().toString().trim();
        final String uf = editTextUf.getText().toString().trim().toUpperCase();
        final String email = editTextEmail.getText().toString().trim();

        textViewStatus.setText("");

        if (!validar(nome, cpf, uf, email)) {
            return;
        }

        editTextUf.setText(uf);

        final ClienteLocal cliente = new ClienteLocal(nome, cpf);
        cliente.endereco = editTextEndereco.getText().toString().trim();
        cliente.cidade = editTextCidade.getText().toString().trim();
        cliente.uf = uf;
        cliente.cep = editTextCep.getText().toString().trim();
        cliente.telefone = editTextTelefone.getText().toString().trim();
        cliente.email = email;

        salvando = true;
        buttonSalvar.setEnabled(false);
        buttonSalvar.setText("Salvando...");
        textViewStatus.setText("Salvando no aparelho...");

        new Thread(new Runnable() {
            @Override
            public void run() {
                boolean salvou = false;
                Sincronizacao.Resultado resultado = null;

                try {
                    BancoLocal banco = BancoLocal.get(InserirClienteActivity.this);
                    long idLocal = banco.inserirCliente(cliente, false);

                    // Payload para diagnostico; o envio real usa os dados do banco.
                    JSONObject corpo = new JSONObject();
                    corpo.put("nome", cliente.nome);
                    corpo.put("cpf_cnpj", cliente.cpfCnpj);
                    corpo.put("endereco", cliente.endereco);
                    corpo.put("cidade", cliente.cidade);
                    corpo.put("uf", cliente.uf);
                    corpo.put("cep", cliente.cep);
                    corpo.put("telefone", cliente.telefone);
                    corpo.put("email", cliente.email);
                    banco.enfileirar(ItemOutbox.TIPO_CLIENTE,
                            ItemOutbox.ACAO_INSERIR, idLocal, corpo.toString());

                    salvou = true;

                    if (Conectividade.temRede(InserirClienteActivity.this)) {
                        resultado = Sincronizacao.sincronizar(InserirClienteActivity.this);
                    }
                } catch (Exception e) {
                    salvou = false;
                }

                final boolean salvouFinal = salvou;
                final Sincronizacao.Resultado resultadoFinal = resultado;

                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        salvando = false;
                        buttonSalvar.setEnabled(true);
                        buttonSalvar.setText("Salvar Cliente");

                        if (!salvouFinal) {
                            textViewStatus.setText("Não foi possível salvar o cliente no aparelho.");
                            Toast.makeText(InserirClienteActivity.this,
                                    "Não foi possível salvar o cliente.",
                                    Toast.LENGTH_LONG).show();
                            return;
                        }

                        if (resultadoFinal != null && resultadoFinal.sessaoExpirada != null) {
                            Sessao.tratarSessaoExpirada(InserirClienteActivity.this,
                                    resultadoFinal.sessaoExpirada);
                            return;
                        }

                        boolean enviado = resultadoFinal != null
                                && resultadoFinal.clientesEnviados > 0;

                        if (enviado) {
                            Toast.makeText(InserirClienteActivity.this,
                                    "Cliente " + nome + " cadastrado e sincronizado.",
                                    Toast.LENGTH_LONG).show();
                        } else {
                            Toast.makeText(InserirClienteActivity.this,
                                    "Cliente " + nome + " salvo no aparelho.\n"
                                            + "Será enviado ao servidor na próxima sincronização.",
                                    Toast.LENGTH_LONG).show();
                        }
                        // Volta para a lista; ela recarrega sozinha
                        setResult(RESULT_OK);
                        finish();
                    }
                });
            }
        }).start();
    }
}
