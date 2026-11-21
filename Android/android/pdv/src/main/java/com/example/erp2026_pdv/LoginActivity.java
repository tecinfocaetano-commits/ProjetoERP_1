package com.example.erp2026_pdv;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import org.json.JSONObject;

/**
 * Login do operador do PDV — mesmas credenciais do ERP
 * (POST /api/login). A URL do servidor é configurada aqui.
 */
public class LoginActivity extends Activity {

    private EditText editUrl, editUsuario, editEmpresa, editSenha;
    private TextView txtErro;
    private Button btnEntrar;

    @Override
    protected void onCreate(Bundle estado) {
        super.onCreate(estado);
        setContentView(R.layout.activity_login);

        editUrl = findViewById(R.id.editUrlServidor);
        editUsuario = findViewById(R.id.editUsuario);
        editEmpresa = findViewById(R.id.editEmpresa);
        editSenha = findViewById(R.id.editSenha);
        txtErro = findViewById(R.id.txtErro);
        btnEntrar = findViewById(R.id.btnEntrar);

        String urlSalva = Sessao.urlServidor(this);
        if (urlSalva != null && !urlSalva.isEmpty()) {
            editUrl.setText(urlSalva);
        }

        btnEntrar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                autenticar();
            }
        });

        if (Sessao.ativa(this)) {
            abrirPdv();
        }
    }

    private void autenticar() {
        final String url = editUrl.getText().toString().trim();
        final String usuario = editUsuario.getText().toString().trim();
        final String empresa = editEmpresa.getText().toString().trim();
        final String senha = editSenha.getText().toString();

        if (url.isEmpty()) {
            txtErro.setText("Informe o endereço do servidor (ex.: http://192.168.0.10:9000)");
            return;
        }
        if (usuario.isEmpty()) {
            txtErro.setText("Informe o usuário.");
            editUsuario.requestFocus();
            return;
        }
        if (senha.isEmpty()) {
            txtErro.setText("Informe a senha.");
            editSenha.requestFocus();
            return;
        }

        txtErro.setText("");
        btnEntrar.setEnabled(false);
        btnEntrar.setText("Entrando...");

        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    Sessao.configurar(LoginActivity.this, url);
                    ApiClient.configurar(url);

                    JSONObject corpo = new JSONObject();
                    corpo.put("login", usuario);
                    corpo.put("senha", senha);
                    String empresaDigitos = empresa.replaceAll("\\D", "");
                    if (!empresaDigitos.isEmpty()) {
                        corpo.put("empresa_id", Long.parseLong(empresaDigitos));
                    }

                    final ApiClient.Result r = ApiClient.postSemToken("/api/login",
                            corpo.toString());

                    if (r.ok()) {
                        JSONObject json = new JSONObject(r.body);
                        final String token = json.optString("token", "");
                        final String nome = json.optString("nome", usuario);
                        if (token.isEmpty()) {
                            falhar("Resposta do servidor sem token.");
                            return;
                        }
                        final long empresaId =
                                json.optLong("empresa_id",
                                        Sessao.empresaIdSalvo(LoginActivity.this));
                        Sessao.guardar(LoginActivity.this, token, usuario,
                                nome, empresaId);
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                abrirPdv();
                            }
                        });
                    } else {
                        String msg = "Falha no login (HTTP " + r.status + ").";
                        try {
                            String erro = new JSONObject(r.body).optString("error", "");
                            if (!erro.isEmpty()) {
                                msg = erro;
                            }
                        } catch (Exception ignorado) {
                            // mantém a mensagem genérica
                        }
                        falhar(msg);
                    }
                } catch (final Exception e) {
                    falhar("Sem conexão com o servidor.\nVerifique a URL e a rede.");
                }
            }
        }).start();
    }

    private void falhar(final String mensagem) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                btnEntrar.setEnabled(true);
                btnEntrar.setText("Entrar");
                txtErro.setText(mensagem);
            }
        });
    }

    private void abrirPdv() {
        startActivity(new Intent(this, PdvActivity.class));
        finish();
    }
}
