-- Simulação de inserção pelo App Android
-- Cliente: João Santos Android

INSERT INTO CLIENTE (ID, EMPRESA_ID, NOME, CPF_CNPJ, ENDERECO, CIDADE, UF, CEP, TELEFONE, EMAIL, ATIVO)
VALUES (1234, 1, 'João Santos Android', '987.654.321-00', 'Av. Brasil, 500', 'Rio de Janeiro', 'RJ', '20000-000', '(21) 98888-8888', 'joao.android@teste.com', 'A');

COMMIT;

-- Verificar inserção
SELECT ID, NOME, CPF_CNPJ, ENDERECO, CIDADE, UF, CEP, TELEFONE, EMAIL, ATIVO
FROM CLIENTE
WHERE ID = 1234;
