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
        setContentView(R.layout.activity_main);

        editTextLogin = findViewById(R.id.editTextLogin);
        editTextSenha = findViewById(R.id.editTextSenha);
        buttonLogin = findViewById(R.id.buttonLogin);

        // Valores de conveniencia para teste
        editTextLogin.setText("admin");
        editTextSenha.setText("admin123");

        buttonLogin.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                autenticar();
            }
        });
    }

    private void autenticar() {
        final String login = editTextLogin.getText().toString().trim();
        final String senha = editTextSenha.getText().toString().trim();

        if (login.isEmpty() || senha.isEmpty()) {
            Toast.makeText(this, "Informe login e senha", Toast.LENGTH_SHORT).show();
            return;
        }

        buttonLogin.setEnabled(false);
        Toast.makeText(this, "Autenticando na API...", Toast.LENGTH_SHORT).show();

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
                        ApiClient.setToken(json.optString("token", ""));
                        final String nome = json.optString("nome", login);
                        getSharedPreferences("erp2026", MODE_PRIVATE)
                                .edit()
                                .putString("nome", nome)
                                .apply();

                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                startActivity(new Intent(MainActivity.this, DashboardActivity.class));
                                finish();
                            }
                        });
                    } else {
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                buttonLogin.setEnabled(true);
                                Toast.makeText(MainActivity.this,
                                        "Login ou senha invalidos", Toast.LENGTH_SHORT).show();
                            }
                        });
                    }
                } catch (final Exception e) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            buttonLogin.setEnabled(true);
                            Toast.makeText(MainActivity.this,
                                    "Falha ao conectar na API: " + e.getMessage(),
                                    Toast.LENGTH_LONG).show();
                        }
                    });
                }
            }
        }).start();
    }
}
