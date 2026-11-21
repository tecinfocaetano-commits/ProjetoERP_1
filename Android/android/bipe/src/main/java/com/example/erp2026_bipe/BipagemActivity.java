package com.example.erp2026_bipe;

import androidx.appcompat.app.AppCompatActivity;
import android.content.Intent;
import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.KeyEvent;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import com.journeyapps.barcodescanner.ScanContract;
import com.journeyapps.barcodescanner.ScanOptions;

import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Tela de bipagem — o coração do app.
 *
 * <p>Três formas de bipar o mesmo código:
 *  - leitor USB/Bluetooth: funciona como teclado; o Enter dispara;
 *  - digitação manual no campo;
 *  - câmera (botão "Ler pela câmera", via ZXing).
 *
 * <p>Cada bipagem chama POST /api/producao/bipar e toca um bipe
 * diferente para OK / DUPLICADO / INVÁLIDO. O histórico das últimas
 * 50 bipagens fica no SQLite local (BipeDb) e sobrevive a queda do app.
 */
public class BipagemActivity extends AppCompatActivity {

    private EditText editCodigo;
    private TextView txtResultado, txtOperador, txtContadores;
    private Button btnBipar, btnCamera, btnZerar, btnSair;
    private ListView listaHistorico;
    private ArrayAdapter<String> adaptador;

    private int totalOk = 0;
    private int totalDuplicado = 0;
    private int totalInvalido = 0;
    private boolean bipando = false;

    private final ActivityResultLauncher<ScanOptions> scanner =
            registerForActivityResult(
                    new ScanContract(), resultado -> {
                        if (resultado != null && resultado.getContents() != null) {
                    bipar(resultado.getContents());
                }
            });

    @Override
    protected void onCreate(Bundle estado) {
        super.onCreate(estado);
        setContentView(R.layout.activity_bipagem);

        Sessao.restaurar(this);
        if (!Sessao.ativa(this)) {
            Sessao.irParaLogin(this);
            return;
        }

        editCodigo = findViewById(R.id.editCodigoBarras);
        txtResultado = findViewById(R.id.txtResultado);
        txtOperador = findViewById(R.id.txtOperador);
        txtContadores = findViewById(R.id.txtContadores);
        btnBipar = findViewById(R.id.btnBipar);
        btnCamera = findViewById(R.id.btnCamera);
        btnZerar = findViewById(R.id.btnZerar);
        btnSair = findViewById(R.id.btnSair);
        listaHistorico = findViewById(R.id.listaHistorico);

        txtOperador.setText("Operador: " + Sessao.nome(this));
        adaptador = new ArrayAdapter<>(this,
                android.R.layout.simple_list_item_1);
        listaHistorico.setAdapter(adaptador);
        recarregarHistorico();
        atualizarContadores();

        // Enter no campo = bipar (o leitor hardware envia Enter no fim)
        editCodigo.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == android.view.inputmethod.EditorInfo.IME_ACTION_DONE
                    || (event != null && event.getKeyCode() == KeyEvent.KEYCODE_ENTER)) {
                bipar(editCodigo.getText().toString());
                return true;
            }
            return false;
        });
        // alguns leitores usam Tab como sufixo em vez de Enter
        editCodigo.setOnKeyListener((v, keyCode, event) -> {
            if (event.getAction() == KeyEvent.ACTION_DOWN
                    && (keyCode == KeyEvent.KEYCODE_ENTER
                        || keyCode == KeyEvent.KEYCODE_TAB
                        || keyCode == KeyEvent.KEYCODE_DPAD_CENTER)) {
                bipar(editCodigo.getText().toString());
                return true;
            }
            return false;
        });

        btnBipar.setOnClickListener(v -> bipar(editCodigo.getText().toString()));
        btnCamera.setOnClickListener(v -> {
            ScanOptions opcoes = new ScanOptions();
            opcoes.setDesiredBarcodeFormats(ScanOptions.PRODUCT_CODE_TYPES);
            opcoes.setPrompt("Aponte para o código de barras do talão");
            opcoes.setBeepEnabled(false); // o bipe é nosso (resultado da API)
            opcoes.setOrientationLocked(false);
            scanner.launch(opcoes);
        });
        btnZerar.setOnClickListener(v -> {
            totalOk = totalDuplicado = totalInvalido = 0;
            BipeDb.get(this).limpar();
            adaptador.clear();
            adaptador.notifyDataSetChanged();
            atualizarContadores();
        });
        btnSair.setOnClickListener(v -> {
            Sessao.encerrar(this);
            Sessao.irParaLogin(this);
        });

        editCodigo.requestFocus();
    }

    @Override
    protected void onResume() {
        super.onResume();
        // se a sessão expirou (401), volta ao login
        Sessao.restaurar(this);
    }

    private void bipar(String codigoDigitado) {
        final String codigo = codigoDigitado == null ? "" : codigoDigitado.trim();
        if (codigo.isEmpty() || bipando) {
            return;
        }
        bipando = true;
        btnBipar.setEnabled(false);
        txtResultado.setText("Enviando...");

        new Thread(() -> {
            ApiClient.Result r;
            try {
                JSONObject corpo = new JSONObject();
                corpo.put("codigo", codigo);
                corpo.put("origem", "APP_BIPE");
                r = ApiClient.post("/api/producao/bipar", corpo.toString());
            } catch (Exception e) {
                r = new ApiClient.Result(-1, "");
            }

            final ApiClient.Result resposta = r;
            runOnUiThread(() -> processar(codigo, resposta));
        }).start();
    }

    private void processar(String codigo, ApiClient.Result r) {
        bipando = false;
        btnBipar.setEnabled(true);
        editCodigo.setText("");
        editCodigo.requestFocus();

        if (r.status == 401) {
            Sessao.encerrar(this);
            Sessao.irParaLogin(this);
            return;
        }
        if (r.status < 0) {
            tocar(ToneGenerator.TONE_CDMA_ABBR_ALERT);
            txtResultado.setText("✗ Sem conexão com o servidor.\n"
                    + "Verifique a rede e tente novamente.");
            totalInvalido++;
            atualizarContadores();
            return;
        }

        try {
            JSONObject json = new JSONObject(r.body);

            // erros HTTP (400/500) voltam como {"error": "..."} — sem
            // campo "resultado"; exibe a mensagem real da API
            if (!json.has("resultado") && json.has("error")) {
                String erroApi = json.optString("error", "Erro na requisição.");
                tocar(ToneGenerator.TONE_CDMA_ABBR_ALERT);
                txtResultado.setText("✗ " + erroApi);
                totalInvalido++;
                atualizarContadores();
                return;
            }

            String resultado = json.optString("resultado", "INVALIDO");
            String mensagem = json.optString("mensagem", "");
            String etapa = json.optString("etapa", "");
            int numero = json.optInt("numero_talao", 0);
            String produto = json.optString("produto", "");
            int mapa = json.optInt("mapa_numero", 0);
            boolean mapaConcluido = json.optBoolean("mapa_concluido", false);

            String hora = new SimpleDateFormat("HH:mm:ss", Locale.getDefault())
                    .format(new Date());
            BipeDb.get(this).registrar(codigo, resultado, mensagem,
                    numero, produto, mapa, mapaConcluido, etapa, hora);
            recarregarHistorico();

            switch (resultado) {
                case "OK":
                    totalOk++;
                    tocar(ToneGenerator.TONE_PROP_ACK);
                    txtResultado.setText("✓ " + mensagem);
                    break;
                case "DUPLICADO":
                    totalDuplicado++;
                    tocar(ToneGenerator.TONE_PROP_NACK);
                    txtResultado.setText("⚠ " + mensagem);
                    break;
                default:
                    totalInvalido++;
                    tocar(ToneGenerator.TONE_CDMA_ABBR_ALERT);
                    txtResultado.setText("✗ " + mensagem);
                    break;
            }
            atualizarContadores();
        } catch (Exception e) {
            tocar(ToneGenerator.TONE_CDMA_ABBR_ALERT);
            txtResultado.setText("✗ Resposta inesperada do servidor.");
            totalInvalido++;
            atualizarContadores();
        }
    }

    private void tocar(int tom) {
        ToneGenerator tg = null;
        try {
            tg = new ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100);
            tg.startTone(tom, 400);
        } catch (Exception ignorado) {
            // aparelho sem controle de volume não pode impedir a bipagem
        } finally {
            if (tg != null) {
                tg.release();
            }
        }
    }

    private void atualizarContadores() {
        txtContadores.setText("Turno — OK: " + totalOk
                + "   |   Duplicados: " + totalDuplicado
                + "   |   Inválidos: " + totalInvalido);
    }

    private void recarregarHistorico() {
        adaptador.clear();
        for (String linha : BipeDb.get(this).ultimas(50)) {
            adaptador.add(linha);
        }
        adaptador.notifyDataSetChanged();
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent evento) {
        // leitor pode mandar sufixo próprio; Enter já tratado no campo
        return super.onKeyDown(keyCode, evento);
    }
}
