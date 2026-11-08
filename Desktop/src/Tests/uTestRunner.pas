program TestRunner;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Test Runner Principal
  Descrição: Executa todos os testes unitários do sistema
  ============================================================ }

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils,
  uAssert,
  uFrmLoginTest,
  uPessoaTest,
  uFrmProdutosTest,
  uFrmCategoriasTest,
  uFrmUsuariosTest,
  uProducaoTest,
  uTelasAdmTest,
  uGeograficoTest,
  uCadastrosFase1Test,
  uNotasFiscaisTest,
  uCaixaTest,
  uContasTest,
  uEstoqueTest,
  uPedidoVendaTest,
  uPedidoCompraTest,
  uOrcamentoTest,
  uPDVTest,
  uMovimentoFinanceiroTest,
  uConexao,
  uSessao;

var
  LSuite: TTestSuite;
  LConexao: TConexao;

begin
  // Mesma codepage do app: sem isto, textos acentuados gravados pelos testes
  // iriam como CP1252 e voltariam corrompidos (ver ERP2026.lpr).
  SetMultiByteConversionCodePage(CP_UTF8);
  WriteLn('');
  WriteLn('╔════════════════════════════════════════════════════════════╗');
  WriteLn('║     ERP 2026 - SUITE DE TESTES UNITÁRIOS                   ║');
  WriteLn('║     Framework de Testes Simples com Asserts                 ║');
  WriteLn('╚════════════════════════════════════════════════════════════╝');
  WriteLn('');

  // Inicializar a suite de testes
  LSuite := TTestSuite.Create;

  try
    // Inicializar conexão com o banco
    LConexao := TConexao.GetInstance;
    LConexao.Conectar;

    // Inicializar sessão (usar empresa padrão)
    TSessao.GetInstance.Logar(1, 1, 1, 'Usuario Teste', 'testuser', True);

    WriteLn('Sessão de teste inicializada.');
    WriteLn('Empresa ID: ', TSessao.GetInstance.EmpresaId);
    WriteLn('Usuário ID: ', TSessao.GetInstance.UsuarioId);
    WriteLn('');

    // Executar testes de Login
    TLoginTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes de Pessoas (D3)
    TPessoaTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes de Produtos
    TProdutosTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes de Categorias
    TCategoriasTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes de Usuários
    TUsuariosTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes de Produção (Fase 7)
    TProducaoTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes das telas de administração (30/10/2026)
    TTelasAdmTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes dos cadastros geográficos (04/11/2026)
    TGeograficoTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes dos cadastros da Fase 1 (04/11/2026)
    TCadastrosFase1Test.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes das notas fiscais de entrada e saída (04/11/2026)
    TNotasFiscaisTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes do caixa (financeiro) (07/11/2026)
    TCaixaTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes de contas a pagar/receber (07/11/2026)
    TContasTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes de movimentação de estoque (07/11/2026)
    TEstoqueTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes de pedido de venda (08/11/2026)
    TPedidoVendaTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes de pedido de compra (08/11/2026)
    TPedidoCompraTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes de orçamento (08/11/2026)
    TOrcamentoTest.RunAllTests(LSuite);
    WriteLn('');

    // Executar testes do PDV (08/11/2026)
    TPDVTest.RunAllTests(LSuite);
    WriteLn('');

    // Imprimir resultados finais
    LSuite.PrintResults;

    // Pausa para visualização
    WriteLn('');
    WriteLn('Pressione ENTER para sair...');
    ReadLn;

  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('========================================');
      WriteLn('ERRO CRÍTICO NA EXECUÇÃO DOS TESTES');
      WriteLn('========================================');
      WriteLn('Mensagem: ', E.Message);
      WriteLn('========================================');
      WriteLn('');
      WriteLn('Pressione ENTER para sair...');
      ReadLn;
    end;
  end;

  LSuite.Free;
end.
