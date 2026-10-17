package com.example.erp2026_mobile;

import android.os.Bundle;
import android.util.Patterns;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONObject;

public class InserirClienteActivity extends AppCompatActivity {
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

        salvando = true;
        buttonSalvar.setEnabled(false);
        buttonSalvar.setText("Salvando...");
        textViewStatus.setText("Enviando para a API...");

        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    JSONObject corpo = new JSONObject();
                    corpo.put("nome", nome);
                    corpo.put("cpf_cnpj", cpf);
                    corpo.put("endereco", editTextEndereco.getText().toString().trim());
                    corpo.put("cidade", editTextCidade.getText().toString().trim());
                    corpo.put("uf", uf);
                    corpo.put("cep", editTextCep.getText().toString().trim());
                    corpo.put("telefone", editTextTelefone.getText().toString().trim());
                    corpo.put("email", email);

                    final ApiClient.Result r = ApiClient.post("/api/clientes", corpo.toString());

                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            salvando = false;
                            buttonSalvar.setEnabled(true);
                            buttonSalvar.setText("Salvar Cliente");

                            if (r.ok()) {
                                Toast.makeText(InserirClienteActivity.this,
                                        "Cliente " + nome + " cadastrado com sucesso.",
                                        Toast.LENGTH_LONG).show();
                                // Volta para o menu principal; as listas se atualizam sozinhas
                                setResult(RESULT_OK);
                                finish();
                            } else if (r.status == 401) {
                                Sessao.tratarSessaoExpirada(InserirClienteActivity.this, r);
                            } else {
                                textViewStatus.setText(mensagemDeErro(r));
                                Toast.makeText(InserirClienteActivity.this,
                                        "Não foi possível salvar o cliente.",
                                        Toast.LENGTH_LONG).show();
                            }
                        }
                    });
                } catch (final Exception e) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            salvando = false;
                            buttonSalvar.setEnabled(true);
                            buttonSalvar.setText("Salvar Cliente");
                            textViewStatus.setText("Falha de conexão.\n"
                                    + "Verifique se a API está no ar.");
                        }
                    });
                }
            }
        }).start();
    }

    private String mensagemDeErro(ApiClient.Result r) {
        if (r.status == 400) {
            return "A API recusou os dados enviados (HTTP 400).";
        }
        if (r.status >= 500) {
            return "Erro no servidor da API (HTTP " + r.status + ").";
        }
        return "A API respondeu com erro HTTP " + r.status + ".";
    }
}
