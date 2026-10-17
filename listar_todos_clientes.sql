-- Listar todos os clientes para verificar sincronização
SELECT ID, NOME, CPF_CNPJ, CIDADE, UF, ATIVO
FROM CLIENTE
ORDER BY ID DESC;
