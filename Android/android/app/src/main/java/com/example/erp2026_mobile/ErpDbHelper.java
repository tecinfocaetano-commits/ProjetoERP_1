package com.example.erp2026_mobile;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

/**
 * Banco local (SQLite) do app - base do modo off-line.
 *
 * <p>Guarda o cache de clientes e produtos, os orcamentos (rascunhos e
 * enviados), a fila de sincronizacao ({@code outbox}) e metadados (ultima
 * sincronizacao). Todas as tabelas de negocio tem a coluna {@code empresa},
 * porque a configuracao do app e por empresa (D9) e os dados nao podem se
 * misturar.
 *
 * <p>Sem Room/DDL externa: usa apenas {@link SQLiteOpenHelper} do Android,
 * entao nenhuma dependencia nova entra no Gradle.
 *
 * <p><b>Migracoes:</b> a versao atual e {@link #VERSAO}. Ao mudar o schema,
 * incremente a versao e adicione o passo em {@link #onUpgrade}; nunca edite
 * um {@code CREATE TABLE} ja publicado sem migrar quem ja tem o banco.
 */
public class ErpDbHelper extends SQLiteOpenHelper {

    public static final String NOME_BANCO = "erp2026.db";

    /** v2: produto_local, desconto do item e quantidade de itens no orcamento. */
    public static final int VERSAO = 2;

    // ---- clientes -------------------------------------------------
    public static final String T_CLIENTE = "cliente_local";
    public static final String C_ID = "id";
    public static final String C_ID_SERVIDOR = "id_servidor";
    public static final String C_EMPRESA = "empresa";
    public static final String C_NOME = "nome";
    public static final String C_CPF_CNPJ = "cpf_cnpj";
    public static final String C_ENDERECO = "endereco";
    public static final String C_CIDADE = "cidade";
    public static final String C_UF = "uf";
    public static final String C_CEP = "cep";
    public static final String C_TELEFONE = "telefone";
    public static final String C_EMAIL = "email";
    public static final String C_ATIVO = "ativo";
    public static final String C_SINCRONIZADO = "sincronizado";
    public static final String C_ATUALIZADO_EM = "atualizado_em";

    // ---- produtos (cache para montar orcamentos off-line) ---------
    public static final String T_PRODUTO = "produto_local";
    public static final String P_ID = "id";
    public static final String P_EMPRESA = "empresa";
    public static final String P_ID_SERVIDOR = "id_servidor";
    public static final String P_DESCRICAO = "descricao";
    public static final String P_PRECO_VENDA = "preco_venda";

    // ---- orcamentos ----------------------------------------------
    public static final String T_ORCAMENTO = "orcamento_local";
    public static final String O_ID = "id";
    public static final String O_ID_SERVIDOR = "id_servidor";
    public static final String O_EMPRESA = "empresa";
    public static final String O_NUMERO = "numero";
    public static final String O_CLIENTE_LOCAL_ID = "cliente_local_id";
    public static final String O_CLIENTE_NOME = "cliente_nome";
    public static final String O_DATA = "data";
    public static final String O_VALIDADE = "validade";
    public static final String O_DESCONTO = "desconto";
    public static final String O_TOTAL = "total";
    public static final String O_OBSERVACAO = "observacao";
    public static final String O_STATUS = "status";
    public static final String O_QTD_ITENS = "qtd_itens";
    public static final String O_SINCRONIZADO = "sincronizado";
    public static final String O_CRIADO_EM = "criado_em";
    public static final String O_ATUALIZADO_EM = "atualizado_em";

    public static final String T_ORCAMENTO_ITEM = "orcamento_item_local";
    public static final String I_ID = "id";
    public static final String I_ORCAMENTO_LOCAL_ID = "orcamento_local_id";
    public static final String I_PRODUTO_ID = "produto_id";
    public static final String I_DESCRICAO = "descricao";
    public static final String I_QUANTIDADE = "quantidade";
    public static final String I_VALOR_UNITARIO = "valor_unitario";
    public static final String I_DESCONTO = "desconto";
    public static final String I_TOTAL = "total";

    // ---- fila de sincronizacao -----------------------------------
    public static final String T_OUTBOX = "outbox";
    public static final String B_ID = "id";
    public static final String B_EMPRESA = "empresa";
    public static final String B_TIPO = "tipo";
    public static final String B_ACAO = "acao";
    public static final String B_REFERENCIA_LOCAL = "referencia_local";
    public static final String B_PAYLOAD = "payload";
    public static final String B_CRIADO_EM = "criado_em";
    public static final String B_TENTATIVAS = "tentativas";
    public static final String B_ULTIMO_ERRO = "ultimo_erro";

    // ---- metadados -----------------------------------------------
    public static final String T_META = "meta";
    public static final String M_CHAVE = "chave";
    public static final String M_VALOR = "valor";

    public ErpDbHelper(Context contexto) {
        super(contexto, NOME_BANCO, null, VERSAO);
    }

    @Override
    public void onConfigure(SQLiteDatabase db) {
        super.onConfigure(db);
        // Integridade dos itens do orcamento (ON DELETE CASCADE).
        db.setForeignKeyConstraintsEnabled(true);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE " + T_CLIENTE + " ("
                + C_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, "
                + C_EMPRESA + " TEXT NOT NULL DEFAULT '', "
                + C_ID_SERVIDOR + " INTEGER, "
                + C_NOME + " TEXT NOT NULL, "
                + C_CPF_CNPJ + " TEXT, "
                + C_ENDERECO + " TEXT, "
                + C_CIDADE + " TEXT, "
                + C_UF + " TEXT, "
                + C_CEP + " TEXT, "
                + C_TELEFONE + " TEXT, "
                + C_EMAIL + " TEXT, "
                + C_ATIVO + " TEXT NOT NULL DEFAULT 'A', "
                + C_SINCRONIZADO + " INTEGER NOT NULL DEFAULT 0, "
                + C_ATUALIZADO_EM + " INTEGER NOT NULL DEFAULT 0"
                + ")");
        db.execSQL("CREATE UNIQUE INDEX ux_cliente_servidor ON " + T_CLIENTE
                + " (" + C_EMPRESA + ", " + C_ID_SERVIDOR + ")");
        db.execSQL("CREATE INDEX ix_cliente_nome ON " + T_CLIENTE
                + " (" + C_EMPRESA + ", " + C_NOME + ")");

        criarTabelaProdutos(db);

        db.execSQL("CREATE TABLE " + T_ORCAMENTO + " ("
                + O_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, "
                + O_EMPRESA + " TEXT NOT NULL DEFAULT '', "
                + O_ID_SERVIDOR + " INTEGER, "
                + O_NUMERO + " TEXT, "
                + O_CLIENTE_LOCAL_ID + " INTEGER, "
                + O_CLIENTE_NOME + " TEXT, "
                + O_DATA + " TEXT, "
                + O_VALIDADE + " TEXT, "
                + O_DESCONTO + " REAL NOT NULL DEFAULT 0, "
                + O_TOTAL + " REAL NOT NULL DEFAULT 0, "
                + O_OBSERVACAO + " TEXT, "
                + O_STATUS + " TEXT NOT NULL DEFAULT 'RASCUNHO', "
                + O_QTD_ITENS + " INTEGER NOT NULL DEFAULT 0, "
                + O_SINCRONIZADO + " INTEGER NOT NULL DEFAULT 0, "
                + O_CRIADO_EM + " INTEGER NOT NULL DEFAULT 0, "
                + O_ATUALIZADO_EM + " INTEGER NOT NULL DEFAULT 0, "
                + "FOREIGN KEY (" + O_CLIENTE_LOCAL_ID + ") REFERENCES "
                + T_CLIENTE + "(" + C_ID + ") ON DELETE SET NULL"
                + ")");
        db.execSQL("CREATE INDEX ix_orcamento_status ON " + T_ORCAMENTO
                + " (" + O_EMPRESA + ", " + O_STATUS + ")");
        db.execSQL("CREATE INDEX ix_orcamento_sinc ON " + T_ORCAMENTO
                + " (" + O_EMPRESA + ", " + O_SINCRONIZADO + ")");
        db.execSQL("CREATE UNIQUE INDEX ux_orcamento_servidor ON " + T_ORCAMENTO
                + " (" + O_EMPRESA + ", " + O_ID_SERVIDOR + ")");

        db.execSQL("CREATE TABLE " + T_ORCAMENTO_ITEM + " ("
                + I_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, "
                + I_ORCAMENTO_LOCAL_ID + " INTEGER NOT NULL, "
                + I_PRODUTO_ID + " INTEGER, "
                + I_DESCRICAO + " TEXT NOT NULL, "
                + I_QUANTIDADE + " REAL NOT NULL DEFAULT 1, "
                + I_VALOR_UNITARIO + " REAL NOT NULL DEFAULT 0, "
                + I_DESCONTO + " REAL NOT NULL DEFAULT 0, "
                + I_TOTAL + " REAL NOT NULL DEFAULT 0, "
                + "FOREIGN KEY (" + I_ORCAMENTO_LOCAL_ID + ") REFERENCES "
                + T_ORCAMENTO + "(" + O_ID + ") ON DELETE CASCADE"
                + ")");
        db.execSQL("CREATE INDEX ix_orcamento_item ON " + T_ORCAMENTO_ITEM
                + " (" + I_ORCAMENTO_LOCAL_ID + ")");

        db.execSQL("CREATE TABLE " + T_OUTBOX + " ("
                + B_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, "
                + B_EMPRESA + " TEXT NOT NULL DEFAULT '', "
                + B_TIPO + " TEXT NOT NULL, "
                + B_ACAO + " TEXT NOT NULL, "
                + B_REFERENCIA_LOCAL + " INTEGER, "
                + B_PAYLOAD + " TEXT NOT NULL, "
                + B_CRIADO_EM + " INTEGER NOT NULL DEFAULT 0, "
                + B_TENTATIVAS + " INTEGER NOT NULL DEFAULT 0, "
                + B_ULTIMO_ERRO + " TEXT"
                + ")");
        db.execSQL("CREATE INDEX ix_outbox_pendente ON " + T_OUTBOX
                + " (" + B_EMPRESA + ", " + B_TIPO + ", " + B_ID + ")");

        db.execSQL("CREATE TABLE " + T_META + " ("
                + B_EMPRESA + " TEXT NOT NULL DEFAULT '', "
                + M_CHAVE + " TEXT NOT NULL, "
                + M_VALOR + " TEXT, "
                + "PRIMARY KEY (" + B_EMPRESA + ", " + M_CHAVE + ")"
                + ")");
    }

    private void criarTabelaProdutos(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE IF NOT EXISTS " + T_PRODUTO + " ("
                + P_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, "
                + P_EMPRESA + " TEXT NOT NULL DEFAULT '', "
                + P_ID_SERVIDOR + " INTEGER NOT NULL, "
                + P_DESCRICAO + " TEXT NOT NULL DEFAULT '', "
                + P_PRECO_VENDA + " REAL NOT NULL DEFAULT 0"
                + ")");
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS ux_produto_servidor ON " + T_PRODUTO
                + " (" + P_EMPRESA + ", " + P_ID_SERVIDOR + ")");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int versaoAntiga, int versaoNova) {
        if (versaoAntiga < 1) {
            onCreate(db);
            return;
        }
        if (versaoAntiga < 2) {
            // v1 -> v2: cache de produtos e campos novos do orcamento.
            db.execSQL("ALTER TABLE " + T_ORCAMENTO_ITEM + " ADD COLUMN "
                    + I_DESCONTO + " REAL NOT NULL DEFAULT 0");
            db.execSQL("ALTER TABLE " + T_ORCAMENTO + " ADD COLUMN "
                    + O_QTD_ITENS + " INTEGER NOT NULL DEFAULT 0");
            criarTabelaProdutos(db);
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS ux_orcamento_servidor ON "
                    + T_ORCAMENTO + " (" + O_EMPRESA + ", " + O_ID_SERVIDOR + ")");
        }
    }
}
