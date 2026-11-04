package com.example.erp2026_mobile;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.util.Log;

import java.util.ArrayList;
import java.util.List;

/**
 * Fachada do banco local (SQLite) usada pelas telas e pela sincronizacao.
 *
 * <p>Todos os metodos de negocio filtram pela {@code empresa} atual
 * ({@link Configuracao#empresaAtual(Context)}), entao trocar de empresa na
 * configuracao troca o conjunto de dados visivel sem misturar cache/fila.
 *
 * <p>Chame os metodos em thread de fundo (as telas ja usam {@code new Thread}
 * para falar com a API); sao operacoes sincronas de disco.
 */
public final class BancoLocal {

    public static final String TAG = "ErpDb";

    private static BancoLocal instancia;

    private final Context contexto;
    private final ErpDbHelper helper;

    private BancoLocal(Context contexto) {
        this.contexto = contexto.getApplicationContext();
        this.helper = new ErpDbHelper(this.contexto);
    }

    public static synchronized BancoLocal get(Context contexto) {
        if (instancia == null) {
            instancia = new BancoLocal(contexto);
        }
        return instancia;
    }

    public String empresaAtual() {
        return Configuracao.empresaAtual(contexto);
    }

    /**
     * Abre (criando na primeira vez) o banco e registra no log as tabelas e os
     * totais da empresa atual. Serve de diagnostico e garante o arquivo antes
     * das telas precisarem dele.
     */
    public void aquecer() {
        SQLiteDatabase db = helper.getWritableDatabase();
        Log.i(TAG, "banco " + ErpDbHelper.NOME_BANCO + " v" + ErpDbHelper.VERSAO
                + " empresa='" + empresaAtual() + "'");
        Cursor c = db.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' ORDER BY name",
                null);
        try {
            while (c.moveToNext()) {
                Log.i(TAG, "tabela: " + c.getString(0));
            }
        } finally {
            c.close();
        }
        Log.i(TAG, "clientes=" + contarClientes()
                + " pendentes=" + contarClientesPendentes()
                + " produtos=" + contarProdutos()
                + " orcamentos=" + contarOrcamentos()
                + " outbox=" + contarPendentes());
    }

    // ==================================================================
    // Clientes
    // ==================================================================

    /** Grava um cliente novo e devolve o id local. */
    public long inserirCliente(ClienteLocal cliente, boolean sincronizado) {
        ContentValues v = valoresCliente(cliente);
        v.put(ErpDbHelper.C_SINCRONIZADO, sincronizado ? 1 : 0);
        v.put(ErpDbHelper.C_ATUALIZADO_EM,
                cliente.atualizadoEm > 0 ? cliente.atualizadoEm : System.currentTimeMillis());
        long id = helper.getWritableDatabase().insertOrThrow(ErpDbHelper.T_CLIENTE, null, v);
        cliente.id = id;
        return id;
    }

    /** Atualiza o cliente pelo id local. Devolve false se nao existia. */
    public boolean atualizarCliente(ClienteLocal cliente) {
        ContentValues v = valoresCliente(cliente);
        v.put(ErpDbHelper.C_SINCRONIZADO, cliente.sincronizado ? 1 : 0);
        v.put(ErpDbHelper.C_ATUALIZADO_EM,
                cliente.atualizadoEm > 0 ? cliente.atualizadoEm : System.currentTimeMillis());
        int linhas = helper.getWritableDatabase().update(ErpDbHelper.T_CLIENTE, v,
                ErpDbHelper.C_ID + " = ? AND " + ErpDbHelper.C_EMPRESA + " = ?",
                new String[]{String.valueOf(cliente.id), empresaAtual()});
        return linhas > 0;
    }

    public List<ClienteLocal> listarClientes() {
        return listarClientes(null, false);
    }

    /** Clientes ainda nao confirmados no servidor (fila de envio). */
    public List<ClienteLocal> listarClientesPendentes() {
        return listarClientes(null, true);
    }

    private List<ClienteLocal> listarClientes(String filtro, boolean somentePendentes) {
        StringBuilder sql = new StringBuilder("SELECT * FROM ").append(ErpDbHelper.T_CLIENTE)
                .append(" WHERE ").append(ErpDbHelper.C_EMPRESA).append(" = ?");
        List<String> args = new ArrayList<>();
        args.add(empresaAtual());
        if (somentePendentes) {
            sql.append(" AND ").append(ErpDbHelper.C_SINCRONIZADO).append(" = 0");
        }
        if (filtro != null && !filtro.trim().isEmpty()) {
            sql.append(" AND (UPPER(").append(ErpDbHelper.C_NOME).append(") LIKE ?")
                    .append(" OR ").append(ErpDbHelper.C_CPF_CNPJ).append(" LIKE ?")
                    .append(" OR UPPER(").append(ErpDbHelper.C_CIDADE).append(") LIKE ?)");
            String termo = "%" + filtro.trim().toUpperCase() + "%";
            args.add(termo);
            args.add("%" + filtro.trim() + "%");
            args.add(termo);
        }
        sql.append(" ORDER BY ").append(ErpDbHelper.C_NOME).append(" COLLATE NOCASE");
        return consultarClientes(sql.toString(), args.toArray(new String[0]));
    }

    public ClienteLocal buscarCliente(long idLocal) {
        List<ClienteLocal> lista = consultarClientes(
                "SELECT * FROM " + ErpDbHelper.T_CLIENTE
                        + " WHERE " + ErpDbHelper.C_ID + " = ? AND " + ErpDbHelper.C_EMPRESA + " = ?",
                new String[]{String.valueOf(idLocal), empresaAtual()});
        return lista.isEmpty() ? null : lista.get(0);
    }

    public int contarClientes() {
        return contar(ErpDbHelper.T_CLIENTE, null);
    }

    public int contarClientesPendentes() {
        return contar(ErpDbHelper.T_CLIENTE, ErpDbHelper.C_SINCRONIZADO + " = 0");
    }

    /** Depois do POST: guarda o id do servidor e marca como sincronizado. */
    public void marcarClienteSincronizado(long idLocal, long idServidor) {
        ContentValues v = new ContentValues();
        v.put(ErpDbHelper.C_ID_SERVIDOR, idServidor);
        v.put(ErpDbHelper.C_SINCRONIZADO, 1);
        v.put(ErpDbHelper.C_ATUALIZADO_EM, System.currentTimeMillis());
        helper.getWritableDatabase().update(ErpDbHelper.T_CLIENTE, v,
                ErpDbHelper.C_ID + " = ? AND " + ErpDbHelper.C_EMPRESA + " = ?",
                new String[]{String.valueOf(idLocal), empresaAtual()});
    }

    /**
     * Atualiza o cache de clientes com a lista vinda do servidor.
     *
     * <p>Faz upsert por {@code id_servidor} (preserva o id local, que os
     * orcamentos pendentes usam como referencia) e remove apenas os clientes
     * sincronizados que deixaram de existir no servidor. Cadastros locais ainda
     * nao enviados ({@code sincronizado = 0}) nunca sao apagados.
     */
    public void substituirClientesServidor(List<ClienteLocal> clientes) {
        SQLiteDatabase db = helper.getWritableDatabase();
        String empresa = empresaAtual();
        long agora = System.currentTimeMillis();
        db.beginTransaction();
        try {
            List<String> idsServidor = new ArrayList<>();
            for (ClienteLocal c : clientes) {
                if (c.idServidor == null) {
                    continue;
                }
                idsServidor.add(String.valueOf(c.idServidor));
                ContentValues v = valoresCliente(c);
                v.put(ErpDbHelper.C_SINCRONIZADO, 1);
                v.put(ErpDbHelper.C_ATUALIZADO_EM, agora);
                int linhas = db.update(ErpDbHelper.T_CLIENTE, v,
                        ErpDbHelper.C_EMPRESA + " = ? AND " + ErpDbHelper.C_ID_SERVIDOR + " = ?",
                        new String[]{empresa, String.valueOf(c.idServidor)});
                if (linhas == 0) {
                    db.insertOrThrow(ErpDbHelper.T_CLIENTE, null, v);
                }
            }

            StringBuilder where = new StringBuilder(ErpDbHelper.C_EMPRESA + " = ? AND ")
                    .append(ErpDbHelper.C_SINCRONIZADO).append(" = 1");
            List<String> args = new ArrayList<>();
            args.add(empresa);
            if (!idsServidor.isEmpty()) {
                where.append(" AND ").append(ErpDbHelper.C_ID_SERVIDOR).append(" NOT IN (");
                for (int i = 0; i < idsServidor.size(); i++) {
                    if (i > 0) {
                        where.append(",");
                    }
                    where.append("?");
                    args.add(idsServidor.get(i));
                }
                where.append(")");
            }
            db.delete(ErpDbHelper.T_CLIENTE, where.toString(), args.toArray(new String[0]));
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    private ContentValues valoresCliente(ClienteLocal c) {
        ContentValues v = new ContentValues();
        v.put(ErpDbHelper.C_EMPRESA, empresaAtual());
        if (c.idServidor != null) {
            v.put(ErpDbHelper.C_ID_SERVIDOR, c.idServidor);
        } else {
            v.putNull(ErpDbHelper.C_ID_SERVIDOR);
        }
        v.put(ErpDbHelper.C_NOME, texto(c.nome));
        v.put(ErpDbHelper.C_CPF_CNPJ, texto(c.cpfCnpj));
        v.put(ErpDbHelper.C_ENDERECO, texto(c.endereco));
        v.put(ErpDbHelper.C_CIDADE, texto(c.cidade));
        v.put(ErpDbHelper.C_UF, texto(c.uf));
        v.put(ErpDbHelper.C_CEP, texto(c.cep));
        v.put(ErpDbHelper.C_TELEFONE, texto(c.telefone));
        v.put(ErpDbHelper.C_EMAIL, texto(c.email));
        v.put(ErpDbHelper.C_ATIVO, c.ativo == null || c.ativo.isEmpty() ? "A" : c.ativo);
        return v;
    }

    private List<ClienteLocal> consultarClientes(String sql, String[] args) {
        List<ClienteLocal> lista = new ArrayList<>();
        Cursor c = helper.getReadableDatabase().rawQuery(sql, args);
        try {
            while (c.moveToNext()) {
                ClienteLocal cli = new ClienteLocal();
                cli.id = c.getLong(c.getColumnIndexOrThrow(ErpDbHelper.C_ID));
                int iServidor = c.getColumnIndexOrThrow(ErpDbHelper.C_ID_SERVIDOR);
                cli.idServidor = c.isNull(iServidor) ? null : c.getLong(iServidor);
                cli.nome = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.C_NOME)));
                cli.cpfCnpj = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.C_CPF_CNPJ)));
                cli.endereco = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.C_ENDERECO)));
                cli.cidade = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.C_CIDADE)));
                cli.uf = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.C_UF)));
                cli.cep = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.C_CEP)));
                cli.telefone = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.C_TELEFONE)));
                cli.email = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.C_EMAIL)));
                cli.ativo = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.C_ATIVO)));
                cli.sincronizado = c.getInt(c.getColumnIndexOrThrow(ErpDbHelper.C_SINCRONIZADO)) == 1;
                cli.atualizadoEm = c.getLong(c.getColumnIndexOrThrow(ErpDbHelper.C_ATUALIZADO_EM));
                lista.add(cli);
            }
        } finally {
            c.close();
        }
        return lista;
    }

    // ==================================================================
    // Produtos (cache do servidor, usado nos orcamentos off-line)
    // ==================================================================

    public List<ProdutoLocal> listarProdutos() {
        List<ProdutoLocal> lista = new ArrayList<>();
        Cursor c = helper.getReadableDatabase().rawQuery(
                "SELECT * FROM " + ErpDbHelper.T_PRODUTO
                        + " WHERE " + ErpDbHelper.P_EMPRESA + " = ?"
                        + " ORDER BY " + ErpDbHelper.P_DESCRICAO + " COLLATE NOCASE",
                new String[]{empresaAtual()});
        try {
            while (c.moveToNext()) {
                ProdutoLocal p = new ProdutoLocal();
                p.id = c.getLong(c.getColumnIndexOrThrow(ErpDbHelper.P_ID));
                p.idServidor = c.getLong(c.getColumnIndexOrThrow(ErpDbHelper.P_ID_SERVIDOR));
                p.descricao = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.P_DESCRICAO)));
                p.precoVenda = c.getDouble(c.getColumnIndexOrThrow(ErpDbHelper.P_PRECO_VENDA));
                lista.add(p);
            }
        } finally {
            c.close();
        }
        return lista;
    }

    /** Troca o cache de produtos pelo snapshot atual do servidor. */
    public void substituirProdutosServidor(List<ProdutoLocal> produtos) {
        SQLiteDatabase db = helper.getWritableDatabase();
        db.beginTransaction();
        try {
            db.delete(ErpDbHelper.T_PRODUTO,
                    ErpDbHelper.P_EMPRESA + " = ?", new String[]{empresaAtual()});
            for (ProdutoLocal p : produtos) {
                if (p.idServidor == null) {
                    continue;
                }
                ContentValues v = new ContentValues();
                v.put(ErpDbHelper.P_EMPRESA, empresaAtual());
                v.put(ErpDbHelper.P_ID_SERVIDOR, p.idServidor);
                v.put(ErpDbHelper.P_DESCRICAO, texto(p.descricao));
                v.put(ErpDbHelper.P_PRECO_VENDA, p.precoVenda);
                db.insertOrThrow(ErpDbHelper.T_PRODUTO, null, v);
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    public int contarProdutos() {
        return contar(ErpDbHelper.T_PRODUTO, null);
    }

    // ==================================================================
    // Orcamentos
    // ==================================================================

    /**
     * Grava (ou regrava) o orcamento e seus itens numa unica transacao.
     * Devolve o id local.
     */
    public long salvarOrcamento(OrcamentoLocal orcamento, List<OrcamentoItemLocal> itens) {
        SQLiteDatabase db = helper.getWritableDatabase();
        long agora = System.currentTimeMillis();
        db.beginTransaction();
        try {
            ContentValues v = new ContentValues();
            v.put(ErpDbHelper.O_EMPRESA, empresaAtual());
            if (orcamento.idServidor != null) {
                v.put(ErpDbHelper.O_ID_SERVIDOR, orcamento.idServidor);
            } else {
                v.putNull(ErpDbHelper.O_ID_SERVIDOR);
            }
            v.put(ErpDbHelper.O_NUMERO, texto(orcamento.numero));
            if (orcamento.clienteLocalId != null) {
                v.put(ErpDbHelper.O_CLIENTE_LOCAL_ID, orcamento.clienteLocalId);
            } else {
                v.putNull(ErpDbHelper.O_CLIENTE_LOCAL_ID);
            }
            v.put(ErpDbHelper.O_CLIENTE_NOME, texto(orcamento.clienteNome));
            v.put(ErpDbHelper.O_DATA, texto(orcamento.data));
            v.put(ErpDbHelper.O_VALIDADE, texto(orcamento.validade));
            v.put(ErpDbHelper.O_DESCONTO, orcamento.desconto);
            v.put(ErpDbHelper.O_TOTAL, orcamento.total);
            v.put(ErpDbHelper.O_OBSERVACAO, texto(orcamento.observacao));
            v.put(ErpDbHelper.O_STATUS,
                    orcamento.status == null || orcamento.status.isEmpty()
                            ? OrcamentoLocal.STATUS_RASCUNHO : orcamento.status);
            v.put(ErpDbHelper.O_QTD_ITENS, itens == null ? 0 : itens.size());
            v.put(ErpDbHelper.O_SINCRONIZADO, orcamento.sincronizado ? 1 : 0);
            v.put(ErpDbHelper.O_ATUALIZADO_EM, agora);

            if (orcamento.id > 0) {
                db.update(ErpDbHelper.T_ORCAMENTO, v,
                        ErpDbHelper.O_ID + " = ? AND " + ErpDbHelper.O_EMPRESA + " = ?",
                        new String[]{String.valueOf(orcamento.id), empresaAtual()});
            } else {
                v.put(ErpDbHelper.O_CRIADO_EM,
                        orcamento.criadoEm > 0 ? orcamento.criadoEm : agora);
                orcamento.id = db.insertOrThrow(ErpDbHelper.T_ORCAMENTO, null, v);
            }

            db.delete(ErpDbHelper.T_ORCAMENTO_ITEM,
                    ErpDbHelper.I_ORCAMENTO_LOCAL_ID + " = ?",
                    new String[]{String.valueOf(orcamento.id)});
            if (itens != null) {
                for (OrcamentoItemLocal item : itens) {
                    item.recalcular();
                    ContentValues iv = new ContentValues();
                    iv.put(ErpDbHelper.I_ORCAMENTO_LOCAL_ID, orcamento.id);
                    if (item.produtoId != null) {
                        iv.put(ErpDbHelper.I_PRODUTO_ID, item.produtoId);
                    } else {
                        iv.putNull(ErpDbHelper.I_PRODUTO_ID);
                    }
                    iv.put(ErpDbHelper.I_DESCRICAO, texto(item.descricao));
                    iv.put(ErpDbHelper.I_QUANTIDADE, item.quantidade);
                    iv.put(ErpDbHelper.I_VALOR_UNITARIO, item.valorUnitario);
                    iv.put(ErpDbHelper.I_DESCONTO, item.desconto);
                    iv.put(ErpDbHelper.I_TOTAL, item.total);
                    db.insertOrThrow(ErpDbHelper.T_ORCAMENTO_ITEM, null, iv);
                }
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
        orcamento.atualizadoEm = agora;
        orcamento.qtdItens = itens == null ? 0 : itens.size();
        return orcamento.id;
    }

    public List<OrcamentoLocal> listarOrcamentos() {
        List<OrcamentoLocal> lista = new ArrayList<>();
        Cursor c = helper.getReadableDatabase().rawQuery(
                "SELECT * FROM " + ErpDbHelper.T_ORCAMENTO
                        + " WHERE " + ErpDbHelper.O_EMPRESA + " = ?"
                        + " ORDER BY " + ErpDbHelper.O_ID + " DESC",
                new String[]{empresaAtual()});
        try {
            while (c.moveToNext()) {
                lista.add(lerOrcamento(c));
            }
        } finally {
            c.close();
        }
        return lista;
    }

    public OrcamentoLocal buscarOrcamento(long idLocal) {
        Cursor c = helper.getReadableDatabase().rawQuery(
                "SELECT * FROM " + ErpDbHelper.T_ORCAMENTO
                        + " WHERE " + ErpDbHelper.O_ID + " = ? AND " + ErpDbHelper.O_EMPRESA + " = ?",
                new String[]{String.valueOf(idLocal), empresaAtual()});
        try {
            return c.moveToFirst() ? lerOrcamento(c) : null;
        } finally {
            c.close();
        }
    }

    public List<OrcamentoItemLocal> listarItens(long idOrcamentoLocal) {
        List<OrcamentoItemLocal> lista = new ArrayList<>();
        Cursor c = helper.getReadableDatabase().rawQuery(
                "SELECT * FROM " + ErpDbHelper.T_ORCAMENTO_ITEM
                        + " WHERE " + ErpDbHelper.I_ORCAMENTO_LOCAL_ID + " = ? ORDER BY " + ErpDbHelper.I_ID,
                new String[]{String.valueOf(idOrcamentoLocal)});
        try {
            while (c.moveToNext()) {
                OrcamentoItemLocal item = new OrcamentoItemLocal();
                item.id = c.getLong(c.getColumnIndexOrThrow(ErpDbHelper.I_ID));
                item.orcamentoLocalId = c.getLong(
                        c.getColumnIndexOrThrow(ErpDbHelper.I_ORCAMENTO_LOCAL_ID));
                int iProduto = c.getColumnIndexOrThrow(ErpDbHelper.I_PRODUTO_ID);
                item.produtoId = c.isNull(iProduto) ? null : c.getLong(iProduto);
                item.descricao = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.I_DESCRICAO)));
                item.quantidade = c.getDouble(c.getColumnIndexOrThrow(ErpDbHelper.I_QUANTIDADE));
                item.valorUnitario = c.getDouble(
                        c.getColumnIndexOrThrow(ErpDbHelper.I_VALOR_UNITARIO));
                item.desconto = c.getDouble(c.getColumnIndexOrThrow(ErpDbHelper.I_DESCONTO));
                item.total = c.getDouble(c.getColumnIndexOrThrow(ErpDbHelper.I_TOTAL));
                lista.add(item);
            }
        } finally {
            c.close();
        }
        return lista;
    }

    public int contarOrcamentos() {
        return contar(ErpDbHelper.T_ORCAMENTO, null);
    }

    public int contarOrcamentosPendentes() {
        return contar(ErpDbHelper.T_ORCAMENTO, ErpDbHelper.O_SINCRONIZADO + " = 0");
    }

    /** Depois do POST: guarda id/numero/status devolvidos pela API. */
    public void marcarOrcamentoSincronizado(long idLocal, long idServidor,
                                            String numero, String status) {
        ContentValues v = new ContentValues();
        v.put(ErpDbHelper.O_ID_SERVIDOR, idServidor);
        if (numero != null && !numero.isEmpty()) {
            v.put(ErpDbHelper.O_NUMERO, numero);
        }
        if (status != null && !status.isEmpty()) {
            v.put(ErpDbHelper.O_STATUS, status);
        }
        v.put(ErpDbHelper.O_SINCRONIZADO, 1);
        v.put(ErpDbHelper.O_ATUALIZADO_EM, System.currentTimeMillis());
        helper.getWritableDatabase().update(ErpDbHelper.T_ORCAMENTO, v,
                ErpDbHelper.O_ID + " = ? AND " + ErpDbHelper.O_EMPRESA + " = ?",
                new String[]{String.valueOf(idLocal), empresaAtual()});
    }

    /**
     * Atualiza o cache de orcamentos em aberto com a lista do servidor.
     *
     * <p>Upsert por {@code id_servidor}: preserva os itens ja gravados e nunca
     * toca nos orcamentos locais ainda pendentes. Remove apenas os
     * sincronizados que sumiram do servidor (ex.: convertidos em pedido).
     */
    public void substituirOrcamentosServidor(List<OrcamentoLocal> orcamentos) {
        SQLiteDatabase db = helper.getWritableDatabase();
        String empresa = empresaAtual();
        long agora = System.currentTimeMillis();
        db.beginTransaction();
        try {
            List<String> idsServidor = new ArrayList<>();
            for (OrcamentoLocal o : orcamentos) {
                if (o.idServidor == null) {
                    continue;
                }
                idsServidor.add(String.valueOf(o.idServidor));

                ContentValues v = new ContentValues();
                v.put(ErpDbHelper.O_NUMERO, texto(o.numero));
                v.put(ErpDbHelper.O_CLIENTE_NOME, texto(o.clienteNome));
                v.put(ErpDbHelper.O_DATA, texto(o.data));
                v.put(ErpDbHelper.O_TOTAL, o.total);
                v.put(ErpDbHelper.O_STATUS,
                        o.status == null || o.status.isEmpty() ? "ABERTO" : o.status);
                v.put(ErpDbHelper.O_QTD_ITENS, o.qtdItens);
                v.put(ErpDbHelper.O_SINCRONIZADO, 1);
                v.put(ErpDbHelper.O_ATUALIZADO_EM, agora);

                int linhas = db.update(ErpDbHelper.T_ORCAMENTO, v,
                        ErpDbHelper.O_EMPRESA + " = ? AND " + ErpDbHelper.O_ID_SERVIDOR + " = ?",
                        new String[]{empresa, String.valueOf(o.idServidor)});
                if (linhas == 0) {
                    v.put(ErpDbHelper.O_EMPRESA, empresa);
                    v.put(ErpDbHelper.O_ID_SERVIDOR, o.idServidor);
                    v.put(ErpDbHelper.O_CRIADO_EM, agora);
                    db.insertOrThrow(ErpDbHelper.T_ORCAMENTO, null, v);
                }
            }

            StringBuilder where = new StringBuilder(ErpDbHelper.O_EMPRESA + " = ? AND ")
                    .append(ErpDbHelper.O_SINCRONIZADO).append(" = 1");
            List<String> args = new ArrayList<>();
            args.add(empresa);
            if (!idsServidor.isEmpty()) {
                where.append(" AND ").append(ErpDbHelper.O_ID_SERVIDOR).append(" NOT IN (");
                for (int i = 0; i < idsServidor.size(); i++) {
                    if (i > 0) {
                        where.append(",");
                    }
                    where.append("?");
                    args.add(idsServidor.get(i));
                }
                where.append(")");
            }
            db.delete(ErpDbHelper.T_ORCAMENTO, where.toString(), args.toArray(new String[0]));
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    /** Remove o orcamento local (itens caem pelo ON DELETE CASCADE). */
    public void excluirOrcamento(long idLocal) {
        helper.getWritableDatabase().delete(ErpDbHelper.T_ORCAMENTO,
                ErpDbHelper.O_ID + " = ? AND " + ErpDbHelper.O_EMPRESA + " = ?",
                new String[]{String.valueOf(idLocal), empresaAtual()});
    }

    private OrcamentoLocal lerOrcamento(Cursor c) {
        OrcamentoLocal o = new OrcamentoLocal();
        o.id = c.getLong(c.getColumnIndexOrThrow(ErpDbHelper.O_ID));
        int iServidor = c.getColumnIndexOrThrow(ErpDbHelper.O_ID_SERVIDOR);
        o.idServidor = c.isNull(iServidor) ? null : c.getLong(iServidor);
        o.numero = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.O_NUMERO)));
        int iCliente = c.getColumnIndexOrThrow(ErpDbHelper.O_CLIENTE_LOCAL_ID);
        o.clienteLocalId = c.isNull(iCliente) ? null : c.getLong(iCliente);
        o.clienteNome = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.O_CLIENTE_NOME)));
        o.data = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.O_DATA)));
        o.validade = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.O_VALIDADE)));
        o.desconto = c.getDouble(c.getColumnIndexOrThrow(ErpDbHelper.O_DESCONTO));
        o.total = c.getDouble(c.getColumnIndexOrThrow(ErpDbHelper.O_TOTAL));
        o.observacao = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.O_OBSERVACAO)));
        o.status = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.O_STATUS)));
        o.qtdItens = c.getInt(c.getColumnIndexOrThrow(ErpDbHelper.O_QTD_ITENS));
        o.sincronizado = c.getInt(c.getColumnIndexOrThrow(ErpDbHelper.O_SINCRONIZADO)) == 1;
        o.criadoEm = c.getLong(c.getColumnIndexOrThrow(ErpDbHelper.O_CRIADO_EM));
        o.atualizadoEm = c.getLong(c.getColumnIndexOrThrow(ErpDbHelper.O_ATUALIZADO_EM));
        return o;
    }

    // ==================================================================
    // Fila de sincronizacao (outbox)
    // ==================================================================

    /**
     * Enfileira uma operacao. Se ja existe um INSERT pendente do mesmo
     * registro local, apenas atualiza o payload (evita duplicar o cadastro).
     */
    public long enfileirar(String tipo, String acao, Long referenciaLocal, String payload) {
        SQLiteDatabase db = helper.getWritableDatabase();
        if (ItemOutbox.ACAO_INSERIR.equals(acao) && referenciaLocal != null) {
            Cursor c = db.rawQuery(
                    "SELECT " + ErpDbHelper.B_ID + " FROM " + ErpDbHelper.T_OUTBOX
                            + " WHERE " + ErpDbHelper.B_EMPRESA + " = ? AND "
                            + ErpDbHelper.B_TIPO + " = ? AND " + ErpDbHelper.B_REFERENCIA_LOCAL + " = ?"
                            + " AND " + ErpDbHelper.B_ACAO + " = ? LIMIT 1",
                    new String[]{empresaAtual(), tipo, String.valueOf(referenciaLocal), acao});
            try {
                if (c.moveToFirst()) {
                    long id = c.getLong(0);
                    ContentValues v = new ContentValues();
                    v.put(ErpDbHelper.B_PAYLOAD, payload);
                    v.put(ErpDbHelper.B_TENTATIVAS, 0);
                    v.putNull(ErpDbHelper.B_ULTIMO_ERRO);
                    db.update(ErpDbHelper.T_OUTBOX, v,
                            ErpDbHelper.B_ID + " = ?", new String[]{String.valueOf(id)});
                    return id;
                }
            } finally {
                c.close();
            }
        }
        ContentValues v = new ContentValues();
        v.put(ErpDbHelper.B_EMPRESA, empresaAtual());
        v.put(ErpDbHelper.B_TIPO, tipo);
        v.put(ErpDbHelper.B_ACAO, acao);
        if (referenciaLocal != null) {
            v.put(ErpDbHelper.B_REFERENCIA_LOCAL, referenciaLocal);
        } else {
            v.putNull(ErpDbHelper.B_REFERENCIA_LOCAL);
        }
        v.put(ErpDbHelper.B_PAYLOAD, payload);
        v.put(ErpDbHelper.B_CRIADO_EM, System.currentTimeMillis());
        return db.insertOrThrow(ErpDbHelper.T_OUTBOX, null, v);
    }

    public List<ItemOutbox> pendentes(int limite) {
        List<ItemOutbox> lista = new ArrayList<>();
        Cursor c = helper.getReadableDatabase().rawQuery(
                "SELECT * FROM " + ErpDbHelper.T_OUTBOX
                        + " WHERE " + ErpDbHelper.B_EMPRESA + " = ?"
                        + " ORDER BY " + ErpDbHelper.B_ID
                        + " LIMIT " + Math.max(1, limite),
                new String[]{empresaAtual()});
        try {
            while (c.moveToNext()) {
                ItemOutbox item = new ItemOutbox();
                item.id = c.getLong(c.getColumnIndexOrThrow(ErpDbHelper.B_ID));
                item.tipo = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.B_TIPO)));
                item.acao = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.B_ACAO)));
                int iRef = c.getColumnIndexOrThrow(ErpDbHelper.B_REFERENCIA_LOCAL);
                item.referenciaLocal = c.isNull(iRef) ? null : c.getLong(iRef);
                item.payload = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.B_PAYLOAD)));
                item.criadoEm = c.getLong(c.getColumnIndexOrThrow(ErpDbHelper.B_CRIADO_EM));
                item.tentativas = c.getInt(c.getColumnIndexOrThrow(ErpDbHelper.B_TENTATIVAS));
                item.ultimoErro = nulo(c.getString(c.getColumnIndexOrThrow(ErpDbHelper.B_ULTIMO_ERRO)));
                lista.add(item);
            }
        } finally {
            c.close();
        }
        return lista;
    }

    public int contarPendentes() {
        return contar(ErpDbHelper.T_OUTBOX, null);
    }

    /** Registra a falha de uma tentativa (mantem a linha para a proxima). */
    public void marcarErro(long id, String erro) {
        helper.getWritableDatabase().execSQL(
                "UPDATE " + ErpDbHelper.T_OUTBOX + " SET "
                        + ErpDbHelper.B_TENTATIVAS + " = " + ErpDbHelper.B_TENTATIVAS + " + 1, "
                        + ErpDbHelper.B_ULTIMO_ERRO + " = ? WHERE " + ErpDbHelper.B_ID + " = ?",
                new Object[]{erro == null ? "" : erro, id});
    }

    /** Remove da fila depois do envio confirmado. */
    public void removerDaFila(long id) {
        helper.getWritableDatabase().delete(ErpDbHelper.T_OUTBOX,
                ErpDbHelper.B_ID + " = ? AND " + ErpDbHelper.B_EMPRESA + " = ?",
                new String[]{String.valueOf(id), empresaAtual()});
    }

    public void limparFila() {
        helper.getWritableDatabase().delete(ErpDbHelper.T_OUTBOX,
                ErpDbHelper.B_EMPRESA + " = ?", new String[]{empresaAtual()});
    }

    // ==================================================================
    // Metadados
    // ==================================================================

    public String getMeta(String chave, String padrao) {
        Cursor c = helper.getReadableDatabase().rawQuery(
                "SELECT " + ErpDbHelper.M_VALOR + " FROM " + ErpDbHelper.T_META
                        + " WHERE " + ErpDbHelper.B_EMPRESA + " = ? AND " + ErpDbHelper.M_CHAVE + " = ?",
                new String[]{empresaAtual(), chave});
        try {
            return c.moveToFirst() ? nulo(c.getString(0)) : padrao;
        } finally {
            c.close();
        }
    }

    public void setMeta(String chave, String valor) {
        ContentValues v = new ContentValues();
        v.put(ErpDbHelper.B_EMPRESA, empresaAtual());
        v.put(ErpDbHelper.M_CHAVE, chave);
        v.put(ErpDbHelper.M_VALOR, valor);
        helper.getWritableDatabase().insertWithOnConflict(ErpDbHelper.T_META, null, v,
                SQLiteDatabase.CONFLICT_REPLACE);
    }

    // ==================================================================
    // Utilitarios
    // ==================================================================

    private int contar(String tabela, String condicaoExtra) {
        String sql = "SELECT COUNT(*) FROM " + tabela + " WHERE " + ErpDbHelper.C_EMPRESA + " = ?";
        List<String> args = new ArrayList<>();
        args.add(empresaAtual());
        if (condicaoExtra != null && !condicaoExtra.isEmpty()) {
            sql += " AND " + condicaoExtra;
        }
        Cursor c = helper.getReadableDatabase().rawQuery(sql, args.toArray(new String[0]));
        try {
            return c.moveToFirst() ? c.getInt(0) : 0;
        } finally {
            c.close();
        }
    }

    private static String texto(String valor) {
        return valor == null ? "" : valor.trim();
    }

    private static String nulo(String valor) {
        return valor == null ? "" : valor;
    }
}
