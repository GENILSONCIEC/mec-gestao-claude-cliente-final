# Histórico de versões

## Instalador — 05/10/2026 (atualização garantida)
- Nova tarefa agendada "MecGestao - Atualizar plugin Claude" (ao entrar no Windows e a cada 4 h), que atualiza o plugin
  pelo GitHub em segundo plano (`instalar/atualizar-plugin.ps1`, sempre baixado na versão mais nova). Registro em
  `%LOCALAPPDATA%\MecGestao\atualizacao.log`.
- Rodar o instalador de novo também atualiza o plugin para a versão mais nova.
- O diagnóstico mostra a versão no GitHub, a tarefa agendada e as últimas atualizações.

## 1.0.2 — 05/10/2026
- Correção: em alguns computadores o PDF falhava ("Falha ao gerar o PDF") porque o processo inicial do Edge encerrava antes
  de gravar o arquivo. O gerador agora espera o PDF aparecer, mesmo depois que o Edge encerra.
- Cada geração usa uma pasta de perfil própria do Edge: um Edge preso de uma execução anterior não atrapalha mais.
- Em caso de falha, a mensagem mostra o código e o erro do Edge.

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
