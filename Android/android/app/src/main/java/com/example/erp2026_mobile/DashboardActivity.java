package com.example.erp2026_mobile;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

public class DashboardActivity extends AppCompatActivity {
    private TextView textViewWelcome;
    private Button buttonClientes;
    private Button buttonInserirCliente;
    private Button buttonConsultarClientes;
    private Button buttonEstoque;
    private Button buttonVendas;
    private Button buttonFinanceiro;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_dashboard);

        textViewWelcome = findViewById(R.id.textViewWelcome);
        buttonClientes = findViewById(R.id.buttonClientes);
        buttonInserirCliente = findViewById(R.id.buttonInserirCliente);
        buttonConsultarClientes = findViewById(R.id.buttonConsultarClientes);
        buttonEstoque = findViewById(R.id.buttonEstoque);
        buttonVendas = findViewById(R.id.buttonVendas);
        buttonFinanceiro = findViewById(R.id.buttonFinanceiro);

        String nome = getSharedPreferences("erp2026", MODE_PRIVATE).getString("nome", "Usuario");
        textViewWelcome.setText("Bem-vindo, " + nome + "!");

        buttonClientes.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                startActivity(new Intent(DashboardActivity.this, ClientesActivity.class));
            }
        });
        buttonInserirCliente.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                startActivity(new Intent(DashboardActivity.this, InserirClienteActivity.class));
            }
        });
        buttonConsultarClientes.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                startActivity(new Intent(DashboardActivity.this, ConsultarClientesActivity.class));
            }
        });
        buttonEstoque.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                startActivity(new Intent(DashboardActivity.this, EstoqueActivity.class));
            }
        });
        buttonVendas.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                startActivity(new Intent(DashboardActivity.this, VendasActivity.class));
            }
        });
        buttonFinanceiro.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                startActivity(new Intent(DashboardActivity.this, FinanceiroActivity.class));
            }
        });
    }
}
