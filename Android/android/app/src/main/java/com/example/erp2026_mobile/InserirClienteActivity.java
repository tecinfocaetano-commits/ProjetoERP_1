package com.example.erp2026_mobile;

import android.os.Bundle;
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

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_inserir_cliente);

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

    private void salvar() {
        final String nome = editTextNome.getText().toString().trim();
        final String cpf = editTextCpf.getText().toString().trim();

        if (nome.isEmpty() || cpf.isEmpty()) {
            Toast.makeText(this, "Nome e CPF sao obrigatorios", Toast.LENGTH_SHORT).show();
            return;
        }

        buttonSalvar.setEnabled(false);
        textViewStatus.setText("Enviando para a API...\n");

        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    JSONObject corpo = new JSONObject();
                    corpo.put("nome", nome);
                    corpo.put("cpf_cnpj", cpf);
                    corpo.put("endereco", editTextEndereco.getText().toString().trim());
                    corpo.put("cidade", editTextCidade.getText().toString().trim());
                    corpo.put("uf", editTextUf.getText().toString().trim());
                    corpo.put("cep", editTextCep.getText().toString().trim());
                    corpo.put("telefone", editTextTelefone.getText().toString().trim());
                    corpo.put("email", editTextEmail.getText().toString().trim());

                    final ApiClient.Result r = ApiClient.post("/api/clientes", corpo.toString());

                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            buttonSalvar.setEnabled(true);
                            if (r.ok()) {
                                textViewStatus.setText("Cliente cadastrado com sucesso na API!\n\n");
                                textViewStatus.append("Nome: " + nome + "\n");
                                textViewStatus.append("CPF: " + cpf + "\n");
                                Toast.makeText(InserirClienteActivity.this,
                                        "Cliente salvo no banco via API", Toast.LENGTH_LONG).show();
                            } else {
                                textViewStatus.setText("Falha ao salvar.\n" + r.errorMessage());
                                Toast.makeText(InserirClienteActivity.this,
                                        "Erro ao salvar cliente", Toast.LENGTH_LONG).show();
                            }
                        }
                    });
                } catch (final Exception e) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            buttonSalvar.setEnabled(true);
                            textViewStatus.setText("Falha de conexao.\n" + e.getMessage());
                        }
                    });
                }
            }
        }).start();
    }
}
