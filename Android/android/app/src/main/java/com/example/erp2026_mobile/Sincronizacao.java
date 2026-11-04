package com.example.erp2026_mobile;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Sincronizacao entre o banco local (SQLite) e a API do ERP.
 *
 * <p><b>Envio:</b> percorre a fila {@code outbox} e manda primeiro os clientes
 * (a API nao devolve o id no POST, entao o id e localizado pela lista do
 * servidor) e depois os orcamentos, que precisam do id do cliente ja
 * cadastrado. Uma falha nao descarta a operacao: a linha continua na fila com
 * o erro anotado para a proxima tentativa.
 *
 * <p><b>Download:</b> atualiza os caches de clientes, produtos e orcamentos em
 * aberto e, na sincronizacao total, tambem vendas, estoque e financeiro. Os
 * caches de clientes/produtos/orcamentos nunca apagam registros locais
 * pendentes; vendas/estoque/contas sao snapshots (substituidos por inteiro).
 *
 * <p>Chame sempre em thread de fundo. Nao mexe em telas.
 */
public final class Sincronizacao {

    private static final int LIMITE_FILA = 500;

    /** Conjuntos com data de ultima sincronizacao guardada em {@code meta}. */
    public static final String CONJUNTO_CLIENTES = "clientes";
    public static final String CONJUNTO_PRODUTOS = "produtos";
    public static final String CONJUNTO_ORCAMENTOS = "orcamentos";
    public static final String CONJUNTO_VENDAS = "vendas";
    public static final String CONJUNTO_ESTOQUE = "estoque";
    public static final String CONJUNTO_FINANCEIRO = "financeiro";

    private Sincronizacao() { }

    /** Resultado de uma rodada, usado para montar a mensagem na tela. */
    public static final class Resultado {

        public int clientesEnviados;
        public int orcamentosEnviados;
        public int clientesBaixados;
        public int produtosBaixados;
        public int orcamentosBaixados;
        public int vendasBaixadas;
        public int estoqueBaixados;
        public int contasReceberBaixadas;
        public int contasPagarBaixadas;
        public int falhas;
        public String primeiraFalha = "";

        /** Preenchido quando a API respondeu 401 (token invalido/expirado). */
        public ApiClient.Result sessaoExpirada;

        public boolean enviouAlgo() {
            return clientesEnviados + orcamentosEnviados > 0;
        }

        public String resumo() {
            if (sessaoExpirada != null) {
                return "Sessão expirada. Entre novamente.";
            }
            StringBuilder sb = new StringBuilder();
            if (enviouAlgo()) {
                sb.append("Enviado ao servidor: ")
                        .append(clientesEnviados).append(" cliente(s), ")
                        .append(orcamentosEnviados).append(" orçamento(s).");
            } else {
                sb.append("Nenhuma pendência para enviar.");
            }
            sb.append("\nSalvo no aparelho: ")
                    .append(clientesBaixados).append(" cliente(s), ")
                    .append(produtosBaixados).append(" produto(s), ")
                    .append(orcamentosBaixados).append(" orçamento(s) em aberto.");
            sb.append("\n").append(vendasBaixadas).append(" venda(s), ")
                    .append(estoqueBaixados).append(" item(ns) de estoque, ")
                    .append(contasReceberBaixadas).append(" conta(s) a receber e ")
                    .append(contasPagarBaixadas).append(" a pagar.");
            if (falhas > 0) {
                sb.append("\n").append(falhas).append(" falha(s)");
                if (primeiraFalha != null && !primeiraFalha.isEmpty()) {
                    sb.append(": ").append(primeiraFalha);
                }
            }
            return sb.toString();
        }
    }

    /** Erro de resposta da API durante o download. */
    public static final class ErroApi extends Exception {

        public final ApiClient.Result resposta;

        ErroApi(ApiClient.Result resposta) {
            super(resposta.errorMessage());
            this.resposta = resposta;
        }
    }

    /** Quantidade de registros aguardando envio (clientes + orcamentos). */
    public static int pendentes(Context contexto) {
        BancoLocal banco = BancoLocal.get(contexto);
        return banco.contarClientesPendentes() + banco.contarOrcamentosPendentes();
    }

    /**
     * Roda a rodada completa: envia a fila e atualiza os caches.
     * Nunca lanca excecao de rede - o problema fica registrado no resultado.
     */
    public static Resultado sincronizar(Context contexto) {
        Sessao.restaurar(contexto);
        BancoLocal banco = BancoLocal.get(contexto);
        Resultado r = new Resultado();

        enviarClientes(banco, r);
        if (r.sessaoExpirada == null) {
            enviarOrcamentos(banco, r);
        }
        if (r.sessaoExpirada == null) {
            try {
                r.clientesBaixados = baixarClientes(contexto);
                marcarSincronizado(banco, CONJUNTO_CLIENTES);
            } catch (ErroApi e) {
                registrar(r, e.resposta);
            } catch (Exception e) {
                falha(r, "clientes: " + e.getMessage());
            }
            try {
                r.produtosBaixados = baixarProdutos(contexto);
                marcarSincronizado(banco, CONJUNTO_PRODUTOS);
            } catch (ErroApi e) {
                registrar(r, e.resposta);
            } catch (Exception e) {
                falha(r, "produtos: " + e.getMessage());
            }
            try {
                r.orcamentosBaixados = baixarOrcamentos(contexto);
                marcarSincronizado(banco, CONJUNTO_ORCAMENTOS);
            } catch (ErroApi e) {
                registrar(r, e.resposta);
            } catch (Exception e) {
                falha(r, "orçamentos: " + e.getMessage());
            }
            try {
                r.vendasBaixadas = baixarVendas(contexto);
                marcarSincronizado(banco, CONJUNTO_VENDAS);
            } catch (ErroApi e) {
                registrar(r, e.resposta);
            } catch (Exception e) {
                falha(r, "vendas: " + e.getMessage());
            }
            try {
                r.estoqueBaixados = baixarEstoque(contexto);
                marcarSincronizado(banco, CONJUNTO_ESTOQUE);
            } catch (ErroApi e) {
                registrar(r, e.resposta);
            } catch (Exception e) {
                falha(r, "estoque: " + e.getMessage());
            }
            try {
                baixarResumoFinanceiro(contexto);
                r.contasReceberBaixadas = baixarContasReceber(contexto);
                r.contasPagarBaixadas = baixarContasPagar(contexto);
                marcarSincronizado(banco, CONJUNTO_FINANCEIRO);
            } catch (ErroApi e) {
                registrar(r, e.resposta);
            } catch (Exception e) {
                falha(r, "financeiro: " + e.getMessage());
            }
        }
        if (r.sessaoExpirada == null) {
            banco.setMeta("ultima_sincronizacao", String.valueOf(System.currentTimeMillis()));
        }
        return r;
    }

    // ------------------------------------------------------------------
    // Envio
    // ------------------------------------------------------------------

    private static void enviarClientes(BancoLocal banco, Resultado r) {
        Map<String, Long> idsServidor = new HashMap<>();
        try {
            for (ClienteLocal c : lerClientes(ApiClient.get("/api/clientes"))) {
                if (c.idServidor != null) {
                    idsServidor.put(chaveCliente(c.nome, c.cpfCnpj), c.idServidor);
                }
            }
        } catch (Exception ignorado) {
            // Sem a lista inicial ainda vale tentar o POST; se o envio der certo
            // a lista e recarregada logo abaixo.
        }

        for (ItemOutbox item : banco.pendentes(LIMITE_FILA)) {
            if (!ItemOutbox.TIPO_CLIENTE.equals(item.tipo)) {
                continue;
            }
            ClienteLocal cliente = item.referenciaLocal == null
                    ? null : banco.buscarCliente(item.referenciaLocal);
            if (cliente == null) {
                banco.removerDaFila(item.id);
                continue;
            }
            if (cliente.idServidor != null) {
                banco.marcarClienteSincronizado(cliente.id, cliente.idServidor);
                banco.removerDaFila(item.id);
                continue;
            }

            String chave = chaveCliente(cliente.nome, cliente.cpfCnpj);
            Long idServidor = idsServidor.get(chave);
            if (idServidor != null) {
                // Ja existe no servidor (envio anterior confirmado sem baixar a fila).
                banco.marcarClienteSincronizado(cliente.id, idServidor);
                banco.removerDaFila(item.id);
                r.clientesEnviados++;
                continue;
            }

            try {
                ApiClient.Result res = ApiClient.post("/api/clientes", jsonCliente(cliente));
                if (res.status == 401) {
                    r.sessaoExpirada = res;
                    return;
                }
                if (!res.ok()) {
                    banco.marcarErro(item.id, mensagem(res));
                    falha(r, mensagem(res));
                    continue;
                }

                r.clientesEnviados++;

                // A API nao devolve o id criado: recarrega a lista e localiza
                // pelo nome + documento (o cadastro recem-criado tem o maior id).
                try {
                    for (ClienteLocal c : lerClientes(ApiClient.get("/api/clientes"))) {
                        if (c.idServidor == null) {
                            continue;
                        }
                        String k = chaveCliente(c.nome, c.cpfCnpj);
                        Long atual = idsServidor.get(k);
                        if (atual == null || c.idServidor > atual) {
                            idsServidor.put(k, c.idServidor);
                        }
                    }
                } catch (Exception ignorado) {
                    // Mantem o mapa anterior; a proxima sincronizacao resolve.
                }

                idServidor = idsServidor.get(chave);
                if (idServidor != null) {
                    banco.marcarClienteSincronizado(cliente.id, idServidor);
                    banco.removerDaFila(item.id);
                } else {
                    banco.marcarErro(item.id,
                            "Cliente enviado, mas o id do servidor ainda não foi localizado.");
                    falha(r, "cliente " + cliente.nome + " enviado, id não localizado");
                }
            } catch (Exception e) {
                banco.marcarErro(item.id, e.getMessage());
                falha(r, "cliente " + cliente.nome + ": " + e.getMessage());
            }
        }
    }

    private static void enviarOrcamentos(BancoLocal banco, Resultado r) {
        for (ItemOutbox item : banco.pendentes(LIMITE_FILA)) {
            if (!ItemOutbox.TIPO_ORCAMENTO.equals(item.tipo)) {
                continue;
            }
            OrcamentoLocal orcamento = item.referenciaLocal == null
                    ? null : banco.buscarOrcamento(item.referenciaLocal);
            if (orcamento == null) {
                banco.removerDaFila(item.id);
                continue;
            }
            if (orcamento.idServidor != null) {
                banco.removerDaFila(item.id);
                continue;
            }

            Long clienteId = null;
            if (orcamento.clienteLocalId != null) {
                ClienteLocal cliente = banco.buscarCliente(orcamento.clienteLocalId);
                if (cliente != null) {
                    clienteId = cliente.idServidor;
                }
            }
            if (clienteId == null) {
                banco.marcarErro(item.id, "Cliente do orçamento ainda não foi sincronizado.");
                falha(r, "orçamento com cliente pendente");
                continue;
            }

            List<OrcamentoItemLocal> itens = banco.listarItens(orcamento.id);
            if (itens.isEmpty()) {
                banco.marcarErro(item.id, "Orçamento sem itens.");
                falha(r, "orçamento sem itens");
                continue;
            }
            boolean semProduto = false;
            for (OrcamentoItemLocal i : itens) {
                if (i.produtoId == null) {
                    semProduto = true;
                    break;
                }
            }
            if (semProduto) {
                banco.marcarErro(item.id, "Item sem produto do servidor.");
                falha(r, "item de orçamento sem produto");
                continue;
            }

            try {
                ApiClient.Result res = ApiClient.post("/api/orcamentos",
                        jsonOrcamento(orcamento, clienteId, itens));
                if (res.status == 401) {
                    r.sessaoExpirada = res;
                    return;
                }
                if (!res.ok()) {
                    banco.marcarErro(item.id, mensagem(res));
                    falha(r, mensagem(res));
                    continue;
                }

                long idServidor = 0;
                String numero = "";
                try {
                    JSONObject o = new JSONObject(res.body);
                    idServidor = o.optLong("id", 0);
                    numero = o.optString("numero", "");
                } catch (Exception ignorado) {
                    // resposta sem corpo JSON: segue com o que veio
                }
                banco.marcarOrcamentoSincronizado(orcamento.id, idServidor, numero, "ABERTO");
                banco.removerDaFila(item.id);
                r.orcamentosEnviados++;
            } catch (Exception e) {
                banco.marcarErro(item.id, e.getMessage());
                falha(r, "orçamento " + orcamento.id + ": " + e.getMessage());
            }
        }
    }

    // ------------------------------------------------------------------
    // Download (cache local)
    // ------------------------------------------------------------------

    /** Baixa a lista de clientes e atualiza o cache. Devolve quantos vieram. */
    public static int baixarClientes(Context contexto) throws Exception {
        List<ClienteLocal> clientes = lerClientes(ApiClient.get("/api/clientes"));
        BancoLocal.get(contexto).substituirClientesServidor(clientes);
        return clientes.size();
    }

    /** Baixa os produtos ativos e atualiza o cache. Devolve quantos vieram. */
    public static int baixarProdutos(Context contexto) throws Exception {
        ApiClient.Result res = ApiClient.get("/api/produtos");
        if (!res.ok()) {
            throw new ErroApi(res);
        }
        JSONArray arr = new JSONArray(res.body);
        List<ProdutoLocal> produtos = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            produtos.add(new ProdutoLocal(
                    o.optLong("id"),
                    Fmt.limpar(o.optString("descricao")),
                    o.optDouble("preco_venda", 0)));
        }
        BancoLocal.get(contexto).substituirProdutosServidor(produtos);
        return produtos.size();
    }

    /** Baixa os orcamentos em aberto e atualiza o cache. Devolve quantos vieram. */
    public static int baixarOrcamentos(Context contexto) throws Exception {
        ApiClient.Result res = ApiClient.get("/api/orcamentos");
        if (!res.ok()) {
            throw new ErroApi(res);
        }
        JSONArray arr = new JSONArray(res.body);
        List<OrcamentoLocal> orcamentos = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            OrcamentoLocal orcamento = new OrcamentoLocal();
            orcamento.idServidor = o.optLong("id");
            orcamento.numero = Fmt.limpar(o.optString("numero"));
            orcamento.clienteNome = Fmt.limpar(o.optString("cliente"));
            orcamento.data = Fmt.limpar(o.optString("data_emissao"));
            orcamento.total = o.optDouble("total", 0);
            orcamento.qtdItens = o.optInt("itens", 0);
            orcamento.status = "ABERTO";
            orcamento.sincronizado = true;
            orcamentos.add(orcamento);
        }
        BancoLocal.get(contexto).substituirOrcamentosServidor(orcamentos);
        return orcamentos.size();
    }

    /** Baixa as vendas mais recentes e troca o cache local. */
    public static int baixarVendas(Context contexto) throws Exception {
        ApiClient.Result res = ApiClient.get("/api/vendas");
        if (!res.ok()) {
            throw new ErroApi(res);
        }
        JSONArray arr = new JSONArray(res.body);
        List<VendaLocal> vendas = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            VendaLocal venda = new VendaLocal();
            venda.idServidor = o.optLong("id");
            venda.numero = Fmt.limpar(o.optString("numero"));
            venda.clienteNome = Fmt.limpar(o.optString("cliente"));
            venda.total = o.optDouble("total", 0);
            venda.data = Fmt.limpar(o.optString("data_emissao"));
            venda.status = Fmt.limpar(o.optString("status"));
            vendas.add(venda);
        }
        BancoLocal.get(contexto).substituirVendasServidor(vendas);
        return vendas.size();
    }

    /** Baixa a posicao de estoque e troca o cache local. */
    public static int baixarEstoque(Context contexto) throws Exception {
        ApiClient.Result res = ApiClient.get("/api/estoque");
        if (!res.ok()) {
            throw new ErroApi(res);
        }
        JSONArray arr = new JSONArray(res.body);
        List<EstoqueLocal> itens = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            EstoqueLocal item = new EstoqueLocal();
            item.idServidor = o.optLong("id");
            item.codigo = Fmt.limpar(o.optString("codigo"));
            item.descricao = Fmt.limpar(o.optString("descricao"));
            item.quantidade = o.optDouble("quantidade", 0);
            item.estoqueMinimo = o.optDouble("estoque_minimo", 0);
            item.valorEstoque = o.optDouble("valor_estoque", 0);
            itens.add(item);
        }
        BancoLocal.get(contexto).substituirEstoqueServidor(itens);
        return itens.size();
    }

    /** Baixa o resumo financeiro do mes e guarda em {@code meta}. */
    public static void baixarResumoFinanceiro(Context contexto) throws Exception {
        ApiClient.Result res = ApiClient.get("/api/financeiro");
        if (!res.ok()) {
            throw new ErroApi(res);
        }
        JSONObject totais = new JSONObject(res.body);
        BancoLocal.get(contexto).salvarResumoFinanceiro(
                totais.optDouble("faturamento_mes", 0),
                totais.optInt("vendas_mes", 0),
                totais.optDouble("a_receber", 0),
                totais.optDouble("a_pagar", 0));
    }

    /** Baixa as contas a receber em aberto e troca o cache local. */
    public static int baixarContasReceber(Context contexto) throws Exception {
        ApiClient.Result res = ApiClient.get("/api/financeiro/receber");
        if (!res.ok()) {
            throw new ErroApi(res);
        }
        JSONArray arr = new JSONArray(res.body);
        List<ContaLocal> contas = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            ContaLocal conta = new ContaLocal();
            conta.idServidor = o.optLong("id");
            conta.pessoaNome = Fmt.limpar(o.optString("cliente"));
            conta.descricao = Fmt.limpar(o.optString("descricao"));
            conta.valor = o.optDouble("valor", 0);
            conta.vencimento = Fmt.limpar(o.optString("vencimento"));
            contas.add(conta);
        }
        BancoLocal.get(contexto).substituirContasReceberServidor(contas);
        return contas.size();
    }

    /** Baixa as contas a pagar em aberto e troca o cache local. */
    public static int baixarContasPagar(Context contexto) throws Exception {
        ApiClient.Result res = ApiClient.get("/api/financeiro/pagar");
        if (!res.ok()) {
            throw new ErroApi(res);
        }
        JSONArray arr = new JSONArray(res.body);
        List<ContaLocal> contas = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            ContaLocal conta = new ContaLocal();
            conta.idServidor = o.optLong("id");
            conta.pessoaNome = Fmt.limpar(o.optString("fornecedor"));
            conta.descricao = Fmt.limpar(o.optString("descricao"));
            conta.valor = o.optDouble("valor", 0);
            conta.vencimento = Fmt.limpar(o.optString("vencimento"));
            contas.add(conta);
        }
        BancoLocal.get(contexto).substituirContasPagarServidor(contas);
        return contas.size();
    }

    // ------------------------------------------------------------------
    // Datas de sincronizacao (usadas pela tela "Sincronizar dados")
    // ------------------------------------------------------------------

    private static void marcarSincronizado(BancoLocal banco, String conjunto) {
        banco.setMeta("sync_" + conjunto, String.valueOf(System.currentTimeMillis()));
    }

    /** Momento da ultima sincronizacao do conjunto, ou 0 se nunca baixou. */
    public static long ultimaSincronizacao(Context contexto, String conjunto) {
        String valor = BancoLocal.get(contexto).getMeta("sync_" + conjunto, "");
        if (valor.isEmpty()) {
            return 0;
        }
        try {
            return Long.parseLong(valor);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** Data/hora da ultima sincronizacao do conjunto, pronta para a tela. */
    public static String ultimaSincronizacaoTexto(Context contexto, String conjunto) {
        long quando = ultimaSincronizacao(contexto, conjunto);
        if (quando <= 0) {
            return "nunca";
        }
        java.text.SimpleDateFormat formato =
                new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault());
        return formato.format(new java.util.Date(quando));
    }

    // ------------------------------------------------------------------
    // Conversao JSON
    // ------------------------------------------------------------------

    private static List<ClienteLocal> lerClientes(ApiClient.Result res) throws Exception {
        if (!res.ok()) {
            throw new ErroApi(res);
        }
        JSONArray arr = new JSONArray(res.body);
        List<ClienteLocal> clientes = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.getJSONObject(i);
            ClienteLocal c = new ClienteLocal();
            c.idServidor = o.optLong("id");
            c.nome = Fmt.limpar(o.optString("nome"));
            c.cpfCnpj = Fmt.limpar(o.optString("cpf_cnpj"));
            c.email = Fmt.limpar(o.optString("email"));
            c.telefone = Fmt.limpar(o.optString("telefone"));
            c.cidade = Fmt.limpar(o.optString("cidade"));
            c.uf = Fmt.limpar(o.optString("uf"));
            c.ativo = Fmt.limpar(o.optString("status"));
            if (c.ativo.isEmpty()) {
                c.ativo = "A";
            }
            c.sincronizado = true;
            clientes.add(c);
        }
        return clientes;
    }

    private static String jsonCliente(ClienteLocal c) throws Exception {
        JSONObject o = new JSONObject();
        o.put("nome", c.nome);
        o.put("cpf_cnpj", c.cpfCnpj);
        o.put("endereco", c.endereco);
        o.put("cidade", c.cidade);
        o.put("uf", c.uf);
        o.put("cep", c.cep);
        o.put("telefone", c.telefone);
        o.put("email", c.email);
        return o.toString();
    }

    private static String jsonOrcamento(OrcamentoLocal o, long clienteId,
                                        List<OrcamentoItemLocal> itens) throws Exception {
        JSONObject corpo = new JSONObject();
        corpo.put("cliente_id", clienteId);
        corpo.put("desconto", o.desconto);
        corpo.put("observacoes", o.observacao);

        JSONArray lista = new JSONArray();
        for (OrcamentoItemLocal item : itens) {
            JSONObject i = new JSONObject();
            i.put("produto_id", item.produtoId);
            i.put("quantidade", item.quantidade);
            i.put("valor_unitario", item.valorUnitario);
            i.put("desconto", item.desconto);
            lista.put(i);
        }
        corpo.put("itens", lista);
        return corpo.toString();
    }

    // ------------------------------------------------------------------
    // Utilitarios
    // ------------------------------------------------------------------

    /** Nome normalizado + digitos do documento: identifica o cliente no servidor. */
    private static String chaveCliente(String nome, String documento) {
        String n = nome == null ? "" : nome.trim().toUpperCase(Locale.ROOT);
        String d = documento == null ? "" : documento.replaceAll("\\D", "");
        return n + "|" + d;
    }

    private static void registrar(Resultado r, ApiClient.Result res) {
        if (res.status == 401) {
            r.sessaoExpirada = res;
        } else {
            falha(r, mensagem(res));
        }
    }

    private static void falha(Resultado r, String texto) {
        r.falhas++;
        if (r.primeiraFalha == null || r.primeiraFalha.isEmpty()) {
            r.primeiraFalha = texto == null ? "" : texto;
        }
    }

    private static String mensagem(ApiClient.Result res) {
        try {
            String detalhe = new JSONObject(res.body).optString("error", "");
            if (!detalhe.isEmpty()) {
                return detalhe;
            }
        } catch (Exception ignorado) {
            // corpo sem JSON
        }
        return "HTTP " + res.status;
    }
}
