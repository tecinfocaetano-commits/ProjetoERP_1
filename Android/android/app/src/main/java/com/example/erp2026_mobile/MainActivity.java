package com.example.erp2026_mobile;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONObject;

public class MainActivity extends AppCompatActivity {
    private EditText editTextLogin;
    private EditText editTextSenha;
    private Button buttonLogin;
    private Button buttonConfiguracao;
    private TextView textViewEmpresa;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Aponta o ApiClient para a empresa configurada antes de qualquer chamada
        Configuracao.aplicarNoApi(this);

        // Sessão anterior ainda válida: vai direto para o menu
        if (Sessao.ativa(this)) {
            abrirMenu();
            return;
        }

        setContentView(R.layout.activity_main);

        editTextLogin = findViewById(R.id.editTextLogin);
        editTextSenha = findViewById(R.id.editTextSenha);
        buttonLogin = findViewById(R.id.buttonLogin);
        buttonConfiguracao = findViewById(R.id.buttonConfiguracao);
        textViewEmpresa = findViewById(R.id.textViewEmpresa);

        atualizarEmpresa();

        // Valores de conveniência para teste
        editTextLogin.setText("admin");
        editTextSenha.setText("admin123");

        buttonLogin.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                autenticar();
            }
        });

        buttonConfiguracao.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startActivity(new Intent(MainActivity.this, ConfiguracaoActivity.class));
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (textViewEmpresa != null) {
            atualizarEmpresa();
        }
    }

    /** Mostra a empresa em uso (ou avisa que ainda não há configuração). */
    private void atualizarEmpresa() {
        Configuracao atual = Configuracao.carregarAtual(this);
        if (atual == null) {
            textViewEmpresa.setText("Nenhuma empresa configurada — toque em \"Servidor e empresa\"");
        } else {
            textViewEmpresa.setText("Empresa " + atual.getEmpresa()
                    + " · " + atual.getUrlServidor());
        }
    }

    private void abrirMenu() {
        startActivity(new Intent(MainActivity.this, DashboardActivity.class));
        finish();
    }

    private void autenticar() {
        final String login = editTextLogin.getText().toString().trim();
        final String senha = editTextSenha.getText().toString().trim();

        if (login.isEmpty()) {
            editTextLogin.setError("Informe o usuário");
            editTextLogin.requestFocus();
            return;
        }
        if (senha.isEmpty()) {
            editTextSenha.setError("Informe a senha");
            editTextSenha.requestFocus();
            return;
        }

        buttonLogin.setEnabled(false);
        buttonLogin.setText("Entrando...");

        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    JSONObject corpo = new JSONObject();
                    corpo.put("login", login);
                    corpo.put("senha", senha);

                    // Código do usuário da empresa configurada (D9). A API
                    // ignora campos que não conhece, então a rota atual
                    // continua funcionando sem configuração.
                    Configuracao atual = Configuracao.carregarAtual(MainActivity.this);
                    if (atual != null && !atual.getCodigoUsuario().isEmpty()) {
                        corpo.put("codigoUsuario", atual.getCodigoUsuario());
                    }

                    final ApiClient.Result r = ApiClient.post("/api/login", corpo.toString());

                    if (r.ok()) {
                        JSONObject json = new JSONObject(r.body);
                        Sessao.guardar(MainActivity.this,
                                json.optString("token", ""),
                                json.optString("nome", login));

                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                abrirMenu();
                            }
                        });
                    } else {
                        final String mensagem = (r.status == 401)
                                ? "Usuário ou senha inválidos."
                                : "Não foi possível entrar (HTTP " + r.status + ").";
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                buttonLogin.setEnabled(true);
                                buttonLogin.setText("ENTRAR");
                                Toast.makeText(MainActivity.this, mensagem, Toast.LENGTH_LONG).show();
                            }
                        });
                    }
                } catch (final Exception e) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            buttonLogin.setEnabled(true);
                            buttonLogin.setText("ENTRAR");
                            Toast.makeText(MainActivity.this,
                                    "Falha ao conectar na API.\nVerifique se ela está no ar.",
                                    Toast.LENGTH_LONG).show();
                        }
                    });
                }
            }
        }).start();
    }
}
