-- Script de teste de conexão com o banco ERP2026
-- Execute no DBeaver ou FlameRobin

CONNECT 'localhost:C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb' USER 'SYSDBA' PASSWORD 'masterkey';

-- Testar conexão listando usuários
SELECT * FROM USUARIO;

-- Testar conexão listando clientes
SELECT * FROM CLIENTE;

-- Testar conexão listando produtos
SELECT * FROM PRODUTO;

-- Verificar versão do banco
SELECT MON$SERVER_VERSION FROM MON$DATABASE;

QUIT;
