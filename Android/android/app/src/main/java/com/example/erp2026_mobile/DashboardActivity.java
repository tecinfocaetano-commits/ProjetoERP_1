package com.example.erp2026_mobile;

import android.app.AlertDialog;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import com.google.android.material.bottomnavigation.BottomNavigationView;

public class DashboardActivity extends BaseActivity {
    private TextView textViewWelcome;
    private Button buttonClientes;
    private Button buttonInserirCliente;
    private Button buttonConsultarClientes;
    private Button buttonEstoque;
    private Button buttonVendas;
    private Button buttonOrcamentos;
    private Button buttonFinanceiro;
    private Button buttonConfiguracao;
    private Button buttonSair;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        setContentView(R.layout.activity_dashboard);
        setTitle("ERP 2026 - Menu");

        textViewWelcome = findViewById(R.id.textViewWelcome);
        buttonClientes = findViewById(R.id.buttonClientes);
        buttonInserirCliente = findViewById(R.id.buttonInserirCliente);
        buttonConsultarClientes = findViewById(R.id.buttonConsultarClientes);
        buttonEstoque = findViewById(R.id.buttonEstoque);
        buttonVendas = findViewById(R.id.buttonVendas);
        buttonOrcamentos = findViewById(R.id.buttonOrcamentos);
        buttonFinanceiro = findViewById(R.id.buttonFinanceiro);
        buttonConfiguracao = findViewById(R.id.buttonConfiguracao);
        buttonSair = findViewById(R.id.buttonSair);

        buttonClientes.setOnClickListener(v -> abrir(ClientesActivity.class));
        buttonInserirCliente.setOnClickListener(v -> abrir(InserirClienteActivity.class));
        buttonConsultarClientes.setOnClickListener(v -> abrir(ConsultarClientesActivity.class));
        buttonEstoque.setOnClickListener(v -> abrir(EstoqueActivity.class));
        buttonVendas.setOnClickListener(v -> abrir(VendasActivity.class));
        buttonOrcamentos.setOnClickListener(v -> abrir(OrcamentosActivity.class));
        buttonFinanceiro.setOnClickListener(v -> abrir(FinanceiroActivity.class));
        buttonConfiguracao.setOnClickListener(v -> abrir(ConfiguracaoActivity.class));

        BottomNavigationView menuInferior = findViewById(R.id.bottomNavigation);
        if (menuInferior != null) {
            Navegacao.configurar(menuInferior, this, R.id.navInicio);
        }

        buttonSair.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                confirmarSaida();
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        textViewWelcome.setText("Bem-vindo, " + Sessao.nome(this) + "!");

        Configuracao atual = Configuracao.carregarAtual(this);
        if (atual == null) {
            setTitle("ERP 2026 - Menu");
        } else {
            setTitle("ERP 2026 - " + atual.getEmpresa());
        }
    }

    private void abrir(Class<?> tela) {
        startActivity(new Intent(this, tela));
    }

    private void confirmarSaida() {
        new AlertDialog.Builder(this)
                .setTitle("Sair")
                .setMessage("Deseja encerrar a sessão?")
                .setNegativeButton("Cancelar", null)
                .setPositiveButton("Sair", (dialog, which) -> {
                    Sessao.encerrar(this);
                    Sessao.irParaLogin(this);
                })
                .show();
    }
}
