package com.example.erp2026_bipe;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import java.util.ArrayList;
import java.util.List;

/**
 * Histórico local das bipagens do turno (SQLite).
 *
 * <p>A regra de negócio fica no servidor (POST /api/producao/bipar);
 * aqui só guardamos o que já foi bipado para o operador conferir —
 * funciona mesmo se a lista da API estiver indisponível depois.
 */
public class BipeDb extends SQLiteOpenHelper {

    private static final String DB_NOME = "erp2026_bipe.db";
    private static final int DB_VERSAO = 2;

    private static final String T_BIPE = "bipe";
    private static final String B_ID = "id";
    private static final String B_CODIGO = "codigo";
    private static final String B_RESULTADO = "resultado";
    private static final String B_MENSAGEM = "mensagem";
    private static final String B_NUMERO = "numero_talao";
    private static final String B_PRODUTO = "produto";
    private static final String B_MAPA = "mapa_numero";
    private static final String B_CONCLUIDO = "mapa_concluido";
    private static final String B_ETAPA = "etapa";
    private static final String B_HORA = "hora";

    // fila offline: códigos bipados sem rede, enviados quando voltar
    private static final String T_PEND = "pendente";
    private static final String P_ID = "id";
    private static final String P_CODIGO = "codigo";
    private static final String P_HORA = "hora";

    /** Item da fila offline. */
    public static class Pendente {
        public final long id;
        public final String codigo;
        public final String hora;

        Pendente(long id, String codigo, String hora) {
            this.id = id;
            this.codigo = codigo;
            this.hora = hora;
        }
    }

    private static BipeDb instancia;

    public static synchronized BipeDb get(Context contexto) {
        if (instancia == null) {
            instancia = new BipeDb(contexto.getApplicationContext());
        }
        return instancia;
    }

    private BipeDb(Context contexto) {
        super(contexto, DB_NOME, null, DB_VERSAO);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE " + T_BIPE + " ("
                + B_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, "
                + B_CODIGO + " TEXT NOT NULL, "
                + B_RESULTADO + " TEXT NOT NULL, "
                + B_MENSAGEM + " TEXT, "
                + B_NUMERO + " INTEGER, "
                + B_PRODUTO + " TEXT, "
                + B_MAPA + " INTEGER, "
                + B_CONCLUIDO + " INTEGER, "
                + B_ETAPA + " TEXT, "
                + B_HORA + " TEXT NOT NULL)");
        criarFila(db);
    }

    private void criarFila(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE IF NOT EXISTS " + T_PEND + " ("
                + P_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, "
                + P_CODIGO + " TEXT NOT NULL, "
                + P_HORA + " TEXT NOT NULL)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int antiga, int nova) {
        if (antiga < 2) {
            criarFila(db);
        }
    }

    public void registrar(String codigo, String resultado, String mensagem,
                          int numeroTalao, String produto, int mapaNumero,
                          boolean mapaConcluido, String etapa, String hora) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues v = new ContentValues();
        v.put(B_CODIGO, codigo);
        v.put(B_RESULTADO, resultado);
        v.put(B_MENSAGEM, mensagem);
        v.put(B_NUMERO, numeroTalao);
        v.put(B_PRODUTO, produto);
        v.put(B_MAPA, mapaNumero);
        v.put(B_CONCLUIDO, mapaConcluido ? 1 : 0);
        v.put(B_ETAPA, etapa);
        v.put(B_HORA, hora);
        db.insert(T_BIPE, null, v);
    }

    /** Últimas N bipagens, da mais recente para a mais antiga. */
    public List<String> ultimas(int limite) {
        List<String> linhas = new ArrayList<>();
        SQLiteDatabase db = getReadableDatabase();
        Cursor c = db.rawQuery(
                "SELECT * FROM " + T_BIPE + " ORDER BY " + B_ID + " DESC LIMIT ?",
                new String[]{String.valueOf(limite)});
        try {
            while (c.moveToNext()) {
                linhas.add(formatar(c));
            }
        } finally {
            c.close();
        }
        return linhas;
    }

    private String formatar(Cursor c) {
        StringBuilder sb = new StringBuilder();
        sb.append(c.getString(c.getColumnIndexOrThrow(B_HORA))).append("  ");
        sb.append(c.getString(c.getColumnIndexOrThrow(B_CODIGO)));
        String resultado = c.getString(c.getColumnIndexOrThrow(B_RESULTADO));
        if ("OK".equals(resultado)) {
            int numero = c.getInt(c.getColumnIndexOrThrow(B_NUMERO));
            String produto = c.getString(c.getColumnIndexOrThrow(B_PRODUTO));
            sb.append("  →  Talão ").append(numero);
            if (produto != null && !produto.isEmpty()) {
                sb.append(" (").append(produto).append(")");
            }
            String etapa = c.getString(c.getColumnIndexOrThrow(B_ETAPA));
            if ("CONCLUSAO".equals(etapa)) {
                sb.append("  ✓ CONCLUÍDO");
            } else {
                sb.append("  ▶ EM PRODUÇÃO");
            }
            if (c.getInt(c.getColumnIndexOrThrow(B_CONCLUIDO)) == 1) {
                sb.append("  |  MAPA ").append(c.getInt(c.getColumnIndexOrThrow(B_MAPA)))
                        .append(" CONCLUÍDO!");
            }
        } else if ("DUPLICADO".equals(resultado)) {
            sb.append("  ⚠ DUPLICADO");
        } else {
            sb.append("  ✗ INVÁLIDO");
        }
        return sb.toString();
    }

    public void limpar() {
        getWritableDatabase().delete(T_BIPE, null, null);
    }

    // ---- fila offline -------------------------------------------------

    public void enfileirar(String codigo, String hora) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues v = new ContentValues();
        v.put(P_CODIGO, codigo);
        v.put(P_HORA, hora);
        db.insert(T_PEND, null, v);
    }

    /** Fila na ordem em que foi bipada (FIFO — a ordem importa:
        o servidor processa INICIO antes de CONCLUSAO). */
    public List<Pendente> pendentes() {
        List<Pendente> itens = new ArrayList<>();
        SQLiteDatabase db = getReadableDatabase();
        Cursor c = db.rawQuery(
                "SELECT " + P_ID + ", " + P_CODIGO + ", " + P_HORA
                        + " FROM " + T_PEND + " ORDER BY " + P_ID,
                null);
        try {
            while (c.moveToNext()) {
                itens.add(new Pendente(
                        c.getLong(c.getColumnIndexOrThrow(P_ID)),
                        c.getString(c.getColumnIndexOrThrow(P_CODIGO)),
                        c.getString(c.getColumnIndexOrThrow(P_HORA))));
            }
        } finally {
            c.close();
        }
        return itens;
    }

    public void removerPendente(long id) {
        getWritableDatabase().delete(T_PEND, P_ID + " = ?",
                new String[]{String.valueOf(id)});
    }

    public int totalPendentes() {
        SQLiteDatabase db = getReadableDatabase();
        Cursor c = db.rawQuery("SELECT COUNT(*) FROM " + T_PEND, null);
        try {
            return c.moveToFirst() ? c.getInt(0) : 0;
        } finally {
            c.close();
        }
    }
}
