# Histórico de versões

## 1.0.1 — 05/10/2026
- PDF gerado em cerca de metade do tempo (aprox. 3,5 s em vez de 7 s): as consultas rodam no mesmo processo e o gerador
  não espera mais à toa pelo Edge.
- O gerador imprime um resumo (linhas, primeira linha, totais, cabeçalho). O Claude confere por ele em vez de abrir o PDF.
- Fluxo do skill mais rápido: o PDF é gerado direto, sem rodar a consulta antes para testar.

## Instalador — 05/10/2026 (correção)
- O instalador agora baixa e instala o plugin na hora, usando o Claude Code que acompanha o aplicativo Claude.
  Antes, só declarar no settings.json não fazia o Claude baixar o plugin.

## Instalador — 05/10/2026
- `INSTALAR-MEC-CLAUDE.bat`: instalador de um arquivo só, que baixa sempre a versão mais recente do instalador.
- O instalador agora instala o Git se faltar, baixa o isql do Firebird 2.5 (pacote ZIP oficial, sem instalar serviço),
  lista os bancos do MEC encontrados e testa a conexão, com até 3 tentativas de senha.

## 1.0.0 — 05/10/2026
- Primeira versão.
- Consultas somente leitura no Firebird 2.5 (`fbquery.ps1`): aceita só SELECT/WITH e roda em transação READ ONLY.
- Relatórios em PDF no padrão Mec Gestão (`gerar_relatorio.ps1`) com gráficos de barras, colunas, linha e pizza.
- Modelo de dados com os códigos de operação 1–10 e a ligação da operação 10 com a OS.
- Regras de performance para bancos de até 100 GB.
- Catálogo das 259 procedures de relatório, com as 60 que gravam dados marcadas como proibidas.
- Instalador para as máquinas dos clientes, com atualização automática.
