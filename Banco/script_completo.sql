/* ============================================================
   ERP 2026 - SCRIPT COMPLETO (banco novo)
   ------------------------------------------------------------
   Fonte única da estrutura: schema_canonico.sql (gerado do banco
   real por Scripts\gerar_schema.bat). As sementes ficam em
   007_initial_data.sql.

   O caminho antigo (002_domains -> 003_generators -> 004_tables ->
   005_triggers -> 006_indexes -> 007_initial_data ->
   008_tabelas_adicionais) ficou defasado: criava só parte das
   tabelas e precisava dos remendos 009..021. Não é mais usado.

   Como executar (a partir desta pasta Banco):
     isql -user SYSDBA -password masterkey -ch UTF8 -i script_completo.sql

   Os INPUTs são RELATIVOS a esta pasta para não prender o
   repositório a um diretório de usuário específico. Para escolher
   outro caminho de .fdb, use Scripts\executar_banco.bat (ou
   GerarSchema.exe), que gera o CREATE DATABASE com o destino desejado.
   ============================================================ */

INPUT 'schema_canonico.sql';
INPUT '007_initial_data.sql';

COMMIT;
QUIT;
