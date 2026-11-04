package com.example.erp2026_mobile;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.database.sqlite.SQLiteOpenHelper;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Field;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Testes da sincronizacao (envio da outbox + download dos caches locais).
 *
 * <p>Roda na JVM com Robolectric: usa o SQLite real do Android e um servidor
 * HTTP falso em {@code 127.0.0.1} no lugar da API. Nenhum dado e gravado no
 * banco do aparelho nem no banco do ERP.
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class SincronizacaoTest {

    /** Endpoints GET baixados pela rodada completa. */
    private static final String[] CAMINHOS_GET = {
            "/api/clientes",
            "/api/produtos",
            "/api/orcamentos",
            "/api/vendas",
            "/api/estoque",
            "/api/financeiro",
            "/api/financeiro/receber",
            "/api/financeiro/pagar"
    };

    private Context contexto;
    private ServerSocket servidor;
    private Thread threadServidor;

    private final List<String> chamadas = Collections.synchronizedList(new ArrayList<String>());
    private final Map<String, Integer> status = Collections.synchronizedMap(new HashMap<String, Integer>());
    private final Map<String, String> corpos = Collections.synchronizedMap(new HashMap<String, String>());
    private final AtomicInteger postsClientes = new AtomicInteger();

    /** Lista de clientes que o servidor falso devolve em GET /api/clientes. */
    private volatile String clientesDoServidor = "[]";

    @Before
    public void preparar() throws Exception {
        contexto = RuntimeEnvironment.getApplication();

        fecharBanco();
        contexto.deleteDatabase(ErpDbHelper.NOME_BANCO);
        contexto.getSharedPreferences("erp2026", Context.MODE_PRIVATE).edit().clear().commit();
        contexto.getSharedPreferences("erp2026_config", Context.MODE_PRIVATE).edit().clear().commit();

        Configuracao.definirEmpresaAtual(contexto, "1");
        ApiClient.setToken("token-teste");

        chamadas.clear();
        status.clear();
        corpos.clear();
        postsClientes.set(0);
        clientesDoServidor = "[]";

        // Respostas vazias por padrao: cada teste troca so o que interessa.
        for (String caminho : CAMINHOS_GET) {
            json("GET", caminho, "/api/financeiro".equals(caminho) ? "{}" : "[]");
        }

        servidor = new ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"));
        threadServidor = new Thread(this::lacoServidor, "servidor-falso");
        threadServidor.setDaemon(true);
        threadServidor.start();
        ApiClient.setBaseUrl("http://127.0.0.1:" + servidor.getLocalPort());
    }

    @After
    public void encerrar() throws Exception {
        if (servidor != null) {
            servidor.close();
            servidor = null;
        }
        if (threadServidor != null) {
            threadServidor.join(2000);
            threadServidor = null;
        }
        fecharBanco();
        contexto.deleteDatabase(ErpDbHelper.NOME_BANCO);
        ApiClient.setBaseUrl("");
        ApiClient.setToken("");
    }

    // ------------------------------------------------------------------
    // Casos
    // ------------------------------------------------------------------

    @Test
    public void sincronizarBaixaTodosOsConjuntos() {
        json("GET", "/api/clientes", "[{\"id\":10,\"nome\":\"Cliente A\",\"cpf_cnpj\":\"111\","
                + "\"email\":\"a@exemplo.com\",\"telefone\":\"1199999\","
                + "\"cidade\":\"Sao Paulo\",\"uf\":\"SP\",\"status\":\"A\"}]");
        json("GET", "/api/produtos",
                "[{\"id\":5,\"descricao\":\"Produto A\",\"preco_venda\":10.5}]");
        json("GET", "/api/orcamentos",
                "[{\"id\":3,\"numero\":\"ORC-3\",\"cliente\":\"Cliente A\","
                        + "\"data_emissao\":\"01/11/2026\",\"total\":100.0,\"itens\":2}]");
        json("GET", "/api/vendas",
                "[{\"id\":8,\"numero\":\"VEN-8\",\"cliente\":\"Cliente A\",\"total\":50.0,"
                        + "\"data_emissao\":\"02/11/2026\",\"status\":\"FATURADO\"},"
                        + "{\"id\":9,\"numero\":\"VEN-9\",\"cliente\":\"Cliente B\",\"total\":70.0,"
                        + "\"data_emissao\":\"03/11/2026\",\"status\":\"ABERTO\"}]");
        json("GET", "/api/estoque",
                "[{\"id\":1,\"codigo\":\"P1\",\"descricao\":\"Produto A\",\"quantidade\":7.0,"
                        + "\"estoque_minimo\":2.0,\"estoque_maximo\":20.0,\"valor_estoque\":70.0}]");
        json("GET", "/api/financeiro",
                "{\"a_receber\":500.0,\"recebido\":100.0,\"a_pagar\":200.0,\"pago\":50.0,"
                        + "\"faturamento_mes\":1000.0,\"vendas_mes\":4}");
        json("GET", "/api/financeiro/receber",
                "[{\"id\":1,\"cliente\":\"Cliente A\",\"descricao\":\"Parcela 1\","
                        + "\"valor\":500.0,\"vencimento\":\"10/11/2026\"}]");
        json("GET", "/api/financeiro/pagar",
                "[{\"id\":1,\"fornecedor\":\"Fornecedor A\",\"descricao\":\"Compra\","
                        + "\"valor\":200.0,\"vencimento\":\"15/11/2026\"}]");

        Sincronizacao.Resultado r = Sincronizacao.sincronizar(contexto);

        assertNull(r.sessaoExpirada);
        assertEquals(0, r.falhas);
        assertEquals(1, r.clientesBaixados);
        assertEquals(1, r.produtosBaixados);
        assertEquals(1, r.orcamentosBaixados);
        assertEquals(2, r.vendasBaixadas);
        assertEquals(1, r.estoqueBaixados);
        assertEquals(1, r.contasReceberBaixadas);
        assertEquals(1, r.contasPagarBaixadas);

        BancoLocal banco = BancoLocal.get(contexto);
        assertEquals(1, banco.contarClientes());
        assertEquals(1, banco.contarProdutos());
        assertEquals(1, banco.contarOrcamentos());
        assertEquals(2, banco.contarVendas());
        assertEquals(1, banco.contarEstoque());
        assertEquals(1, banco.contarContasReceber());
        assertEquals(1, banco.contarContasPagar());

        BancoLocal.ResumoFinanceiro resumo = banco.lerResumoFinanceiro();
        assertNotNull(resumo);
        assertEquals(1000.0, resumo.faturamentoMes, 0.001);
        assertEquals(4, resumo.vendasMes);
        assertEquals(500.0, resumo.aReceber, 0.001);
        assertEquals(200.0, resumo.aPagar, 0.001);

        for (String conjunto : new String[]{
                Sincronizacao.CONJUNTO_CLIENTES,
                Sincronizacao.CONJUNTO_PRODUTOS,
                Sincronizacao.CONJUNTO_ORCAMENTOS,
                Sincronizacao.CONJUNTO_VENDAS,
                Sincronizacao.CONJUNTO_ESTOQUE,
                Sincronizacao.CONJUNTO_FINANCEIRO}) {
            assertTrue(conjunto, Sincronizacao.ultimaSincronizacao(contexto, conjunto) > 0);
        }
        assertFalse(banco.getMeta("ultima_sincronizacao", "").isEmpty());
        assertEquals(0, postsClientes.get());
    }

    @Test
    public void sincronizarEnviaClientePendenteEBaixaIdDoServidor() {
        BancoLocal banco = BancoLocal.get(contexto);
        ClienteLocal novo = new ClienteLocal("Cliente Novo", "12345678900");
        long idLocal = banco.inserirCliente(novo, false);
        banco.enfileirar(ItemOutbox.TIPO_CLIENTE, ItemOutbox.ACAO_INSERIR,
                idLocal, "{\"nome\":\"Cliente Novo\"}");
        assertEquals(1, banco.contarPendentes());

        Sincronizacao.Resultado r = Sincronizacao.sincronizar(contexto);

        assertEquals(1, r.clientesEnviados);
        assertEquals(0, r.falhas);
        assertEquals(1, postsClientes.get());
        assertTrue(chamadas.contains("POST /api/clientes"));
        assertEquals(0, banco.contarPendentes());

        ClienteLocal salvo = banco.buscarCliente(idLocal);
        assertNotNull(salvo);
        assertEquals(Long.valueOf(77L), salvo.idServidor);
        assertTrue(salvo.sincronizado);
        assertEquals(1, banco.contarClientes());
    }

    @Test
    public void snapshotsSubstituemDadosEIsolamPorEmpresa() {
        BancoLocal banco = BancoLocal.get(contexto);

        json("GET", "/api/vendas", vendas(1, 2));
        Sincronizacao.sincronizar(contexto);
        assertEquals(2, banco.contarVendas());

        // Outra empresa recebe outro snapshot: os dados da empresa 1 ficam intactos.
        Configuracao.definirEmpresaAtual(contexto, "2");
        json("GET", "/api/vendas", vendas(9));
        Sincronizacao.sincronizar(contexto);
        assertEquals(1, banco.contarVendas());
        assertEquals(9L, banco.listarVendas().get(0).idServidor.longValue());

        Configuracao.definirEmpresaAtual(contexto, "1");
        assertEquals(2, banco.contarVendas());

        // Novo snapshot da mesma empresa substitui (nao acumula).
        json("GET", "/api/vendas", vendas(3));
        Sincronizacao.sincronizar(contexto);
        assertEquals(1, banco.contarVendas());
        assertEquals(3L, banco.listarVendas().get(0).idServidor.longValue());
    }

    @Test
    public void resposta401MarcaSessaoExpiradaEInterrompeDownloads() {
        for (String caminho : CAMINHOS_GET) {
            json("GET", caminho, 401, "{\"error\":\"Token expirado\"}");
        }

        Sincronizacao.Resultado r = Sincronizacao.sincronizar(contexto);

        assertNotNull(r.sessaoExpirada);
        assertEquals(401, r.sessaoExpirada.status);
        assertEquals("Sessão expirada. Entre novamente.", r.resumo());
        assertFalse(chamadas.contains("GET /api/produtos"));
        assertFalse(chamadas.contains("GET /api/vendas"));
        assertEquals(0, Sincronizacao.ultimaSincronizacao(
                contexto, Sincronizacao.CONJUNTO_CLIENTES));
        assertNull(BancoLocal.get(contexto).lerResumoFinanceiro());
        assertEquals("", BancoLocal.get(contexto).getMeta("ultima_sincronizacao", ""));
    }

    @Test
    public void resposta401NoEnvioInterrompeAntesDosDownloads() {
        BancoLocal banco = BancoLocal.get(contexto);
        ClienteLocal pendente = new ClienteLocal("Cliente Pendente", "999");
        long idLocal = banco.inserirCliente(pendente, false);
        banco.enfileirar(ItemOutbox.TIPO_CLIENTE, ItemOutbox.ACAO_INSERIR, idLocal, "{}");

        json("GET", "/api/clientes", 401, "{\"error\":\"Token expirado\"}");
        json("POST", "/api/clientes", 401, "{\"error\":\"Token expirado\"}");

        Sincronizacao.Resultado r = Sincronizacao.sincronizar(contexto);

        assertNotNull(r.sessaoExpirada);
        assertEquals(1, postsClientes.get());
        assertFalse(chamadas.contains("GET /api/produtos"));
        // A operacao continua na fila para a proxima tentativa.
        assertEquals(1, banco.contarPendentes());
        assertNull(banco.buscarCliente(idLocal).idServidor);
    }

    // ------------------------------------------------------------------
    // Servidor falso (HTTP/1.1 minimo sobre ServerSocket)
    // ------------------------------------------------------------------

    private void lacoServidor() {
        while (!servidor.isClosed()) {
            try (Socket conexao = servidor.accept()) {
                conexao.setSoTimeout(5000);
                atender(conexao);
            } catch (IOException e) {
                if (servidor.isClosed()) {
                    return;
                }
                // Erro em uma conexao nao derruba o servidor falso.
            }
        }
    }

    private void atender(Socket conexao) throws IOException {
        InputStream entrada = conexao.getInputStream();

        String linhaRequisicao = lerLinha(entrada);
        if (linhaRequisicao == null || linhaRequisicao.isEmpty()) {
            return;
        }
        String[] partes = linhaRequisicao.split(" ");
        if (partes.length < 2) {
            responder(conexao, 400, "{\"error\":\"Requisicao invalida\"}");
            return;
        }
        String metodo = partes[0];
        String caminho = partes[1];

        Map<String, String> cabecalhos = new HashMap<>();
        String cabecalho;
        while ((cabecalho = lerLinha(entrada)) != null && !cabecalho.isEmpty()) {
            int separador = cabecalho.indexOf(':');
            if (separador > 0) {
                cabecalhos.put(cabecalho.substring(0, separador).trim().toLowerCase(Locale.ROOT),
                        cabecalho.substring(separador + 1).trim());
            }
        }

        // Consome o corpo (Content-Length) antes de responder.
        int tamanho = 0;
        String comprimento = cabecalhos.get("content-length");
        if (comprimento != null) {
            try {
                tamanho = Integer.parseInt(comprimento);
            } catch (NumberFormatException ignorado) {
                tamanho = 0;
            }
        }
        byte[] corpoRecebido = new byte[tamanho];
        int lidos = 0;
        while (lidos < tamanho) {
            int n = entrada.read(corpoRecebido, lidos, tamanho - lidos);
            if (n < 0) {
                break;
            }
            lidos += n;
        }

        String chave = metodo + " " + caminho;
        chamadas.add(chave);

        if ("POST".equals(metodo) && "/api/clientes".equals(caminho)) {
            postsClientes.incrementAndGet();
            Integer codigo = status.get(chave);
            if (codigo != null && codigo >= 300) {
                responder(conexao, codigo, corpos.get(chave));
                return;
            }
            // O servidor "cria" o cliente e passa a devolve-lo na lista.
            clientesDoServidor = "[{\"id\":77,\"nome\":\"Cliente Novo\","
                    + "\"cpf_cnpj\":\"12345678900\",\"status\":\"A\"}]";
            responder(conexao, 201, "{\"ok\":true}");
            return;
        }

        if ("GET".equals(metodo) && "/api/clientes".equals(caminho)) {
            Integer codigo = status.get(chave);
            if (codigo != null && codigo != 200) {
                responder(conexao, codigo, corpos.get(chave));
            } else {
                responder(conexao, 200, clientesDoServidor);
            }
            return;
        }

        Integer codigo = status.get(chave);
        if (codigo == null) {
            responder(conexao, 404, "{\"error\":\"Rota nao configurada: " + chave + "\"}");
            return;
        }
        responder(conexao, codigo, corpos.get(chave));
    }

    private void json(String metodo, String caminho, String corpo) {
        json(metodo, caminho, 200, corpo);
    }

    private void json(String metodo, String caminho, int codigo, String corpo) {
        status.put(metodo + " " + caminho, codigo);
        corpos.put(metodo + " " + caminho, corpo);
        if (codigo == 200 && "GET".equals(metodo) && "/api/clientes".equals(caminho)) {
            // GET /api/clientes e dinamico (o POST altera a lista), mas um
            // corpo configurado no teste vale como estado inicial do servidor.
            clientesDoServidor = corpo;
        }
    }

    private static void responder(Socket conexao, int codigo, String corpo) throws IOException {
        byte[] bytes = (corpo == null ? "" : corpo).getBytes(StandardCharsets.UTF_8);
        String cabecalho = "HTTP/1.1 " + codigo + " " + motivo(codigo) + "\r\n"
                + "Content-Type: application/json; charset=UTF-8\r\n"
                + "Content-Length: " + bytes.length + "\r\n"
                + "Connection: close\r\n\r\n";
        OutputStream saida = conexao.getOutputStream();
        saida.write(cabecalho.getBytes(StandardCharsets.US_ASCII));
        saida.write(bytes);
        saida.flush();
    }

    private static String motivo(int codigo) {
        switch (codigo) {
            case 200:
                return "OK";
            case 201:
                return "Created";
            case 400:
                return "Bad Request";
            case 401:
                return "Unauthorized";
            case 404:
                return "Not Found";
            default:
                return "OK";
        }
    }

    /** Le uma linha CRLF/LF do socket; null no fim do stream. */
    private static String lerLinha(InputStream entrada) throws IOException {
        ByteArrayOutputStream linha = new ByteArrayOutputStream();
        int b;
        while ((b = entrada.read()) >= 0) {
            if (b == '\n') {
                break;
            }
            if (b != '\r') {
                linha.write(b);
            }
        }
        if (b < 0 && linha.size() == 0) {
            return null;
        }
        return new String(linha.toByteArray(), StandardCharsets.US_ASCII);
    }

    private static String vendas(long... ids) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < ids.length; i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append("{\"id\":").append(ids[i])
                    .append(",\"numero\":\"VEN-").append(ids[i])
                    .append("\",\"cliente\":\"Cliente\",\"total\":10.0,")
                    .append("\"data_emissao\":\"01/11/2026\",\"status\":\"ABERTO\"}");
        }
        return sb.append(']').toString();
    }

    // ------------------------------------------------------------------
    // Isolamento do banco entre testes
    // ------------------------------------------------------------------

    /** Fecha o helper e zera o singleton para o proximo teste abrir um banco limpo. */
    private void fecharBanco() throws Exception {
        Field campoInstancia = BancoLocal.class.getDeclaredField("instancia");
        campoInstancia.setAccessible(true);
        BancoLocal banco = (BancoLocal) campoInstancia.get(null);
        if (banco == null) {
            return;
        }
        Field campoHelper = BancoLocal.class.getDeclaredField("helper");
        campoHelper.setAccessible(true);
        Object helper = campoHelper.get(banco);
        if (helper instanceof SQLiteOpenHelper) {
            ((SQLiteOpenHelper) helper).close();
        }
        campoInstancia.set(null, null);
    }
}
