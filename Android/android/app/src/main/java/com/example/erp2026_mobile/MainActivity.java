package com.example.erp2026_mobile;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONObject;

public class MainActivity extends AppCompatActivity {
    private EditText editTextLogin;
    private EditText editTextSenha;
    private Button buttonLogin;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Sessão anterior ainda válida: vai direto para o menu
        if (Sessao.ativa(this)) {
            abrirMenu();
            return;
        }

        setContentView(R.layout.activity_main);

        editTextLogin = findViewById(R.id.editTextLogin);
        editTextSenha = findViewById(R.id.editTextSenha);
        buttonLogin = findViewById(R.id.buttonLogin);

        // Valores de conveniência para teste
        editTextLogin.setText("admin");
        editTextSenha.setText("admin123");

        buttonLogin.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                autenticar();
            }
        });
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
