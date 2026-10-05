# Histórico de versões

## 1.0.0 — 05/10/2026
- Primeira versão.
- Consultas somente leitura no Firebird 2.5 (`fbquery.ps1`): aceita só SELECT/WITH e roda em transação READ ONLY.
- Relatórios em PDF no padrão Mec Gestão (`gerar_relatorio.ps1`) com gráficos de barras, colunas, linha e pizza.
- Modelo de dados com os códigos de operação 1–10 e a ligação da operação 10 com a OS.
- Regras de performance para bancos de até 100 GB.
- Catálogo das 259 procedures de relatório, com as 60 que gravam dados marcadas como proibidas.
- Instalador para as máquinas dos clientes, com atualização automática.
