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
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
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
    private Button btnBipar, btnCamera, btnZerar, btnSair, btnSync;
    private ListView listaHistorico;
    private ArrayAdapter<String> adaptador;

    private int totalOk = 0;
    private int totalDuplicado = 0;
    private int totalInvalido = 0;
    private boolean bipando = false;
    private boolean sincronizando = false;

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
        btnSync = findViewById(R.id.btnSync);
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
        // envio manual da fila offline (além do automático no onResume)
        btnSync.setOnClickListener(v -> sincronizar());
        findViewById(R.id.btnHistoricoServidor).setOnClickListener(v ->
                startActivity(new Intent(this, HistoricoActivity.class)));

        editCodigo.requestFocus();
    }

    @Override
    protected void onResume() {
        super.onResume();
        // se a sessão expirou (401), volta ao login
        Sessao.restaurar(this);
        // voltou a ter rede? envia a fila offline acumulada
        sincronizar();
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
            // sem rede: entra na fila offline e será enviado depois —
            // o servidor é quem decide o resultado real da bipagem
            tocar(ToneGenerator.TONE_CDMA_ABBR_ALERT);
            String hora = horaAgora();
            BipeDb.get(this).enfileirar(codigo, hora);
            txtResultado.setText("⚡ Sem conexão — bipagem na fila.\n"
                    + "Será enviada quando a rede voltar.");
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
        // rede OK agora? aproveita para esvaziar a fila offline
        sincronizar();
    }

    private static String horaAgora() {
        return new SimpleDateFormat("HH:mm:ss", Locale.getDefault())
                .format(new Date());
    }

    /**
     * Envia à API os códigos bipados sem rede (fila FIFO do BipeDb).
     * O servidor processa na ordem — INICIO antes de CONCLUSAO — e o
     * resultado real (OK/DUPLICADO/INVALIDO) entra no histórico local.
     * Para no primeiro erro de rede: o resto continua na fila.
     */
    private void sincronizar() {
        if (sincronizando) {
            return;
        }
        final List<BipeDb.Pendente> fila;
        try {
            fila = BipeDb.get(this).pendentes();
        } catch (Exception e) {
            return;
        }
        if (fila.isEmpty()) {
            atualizarContadores();
            return;
        }
        sincronizando = true;
        btnSync.setEnabled(false);

        new Thread(() -> {
            List<BipeDb.Pendente> enviadas = new ArrayList<>();
            List<JSONObject> respostas = new ArrayList<>();
            boolean offline = false;
            for (BipeDb.Pendente p : fila) {
                ApiClient.Result r;
                try {
                    JSONObject corpo = new JSONObject();
                    corpo.put("codigo", p.codigo);
                    corpo.put("origem", "APP_BIPE_OFFLINE");
                    r = ApiClient.post("/api/producao/bipar", corpo.toString());
                } catch (Exception e) {
                    r = new ApiClient.Result(-1, "");
                }
                if (r.status < 0) {
                    offline = true;
                    break; // rede caiu de novo — para e tenta depois
                }
                enviadas.add(p);
                try {
                    respostas.add(new JSONObject(r.body));
                } catch (Exception e) {
                    respostas.add(null);
                }
            }

            final boolean parouOffline = offline;
            final List<BipeDb.Pendente> enviadasFinal = enviadas;
            final List<JSONObject> respostasFinal = respostas;
            runOnUiThread(() -> {
                sincronizando = false;
                btnSync.setEnabled(true);
                BipeDb db = BipeDb.get(BipagemActivity.this);
                for (int i = 0; i < enviadasFinal.size(); i++) {
                    BipeDb.Pendente p = enviadasFinal.get(i);
                    JSONObject json = respostasFinal.get(i);
                    db.removerPendente(p.id);
                    if (json == null) {
                        continue; // resposta ilegível: já saiu da fila
                    }
                    String resultado = json.optString("resultado", "INVALIDO");
                    String mensagem = json.optString("mensagem", "");
                    String etapa = json.optString("etapa", "");
                    db.registrar(p.codigo, resultado, mensagem,
                            json.optInt("numero_talao", 0),
                            json.optString("produto", ""),
                            json.optInt("mapa_numero", 0),
                            json.optBoolean("mapa_concluido", false),
                            etapa, p.hora);
                    switch (resultado) {
                        case "OK": totalOk++; break;
                        case "DUPLICADO": totalDuplicado++; break;
                        default: totalInvalido++; break;
                    }
                }
                if (!enviadasFinal.isEmpty()) {
                    tocar(ToneGenerator.TONE_PROP_ACK);
                    recarregarHistorico();
                }
                atualizarContadores();
                if (parouOffline && !fila.isEmpty()) {
                    txtResultado.setText("⚡ Rede caiu — "
                            + db.totalPendentes() + " bipagem(ns) ainda na fila.");
                }
            });
        }).start();
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
        int fila = BipeDb.get(this).totalPendentes();
        txtContadores.setText("Turno — OK: " + totalOk
                + "   |   Duplicados: " + totalDuplicado
                + "   |   Inválidos: " + totalInvalido
                + (fila > 0 ? "   |   ⚡ Fila: " + fila : ""));
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
