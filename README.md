# Mec Gestão — Relatórios para o Claude

Plugin do Claude Code / aplicativo Claude que permite aos clientes do sistema **MEC** consultar o banco Firebird 2.5
em linguagem natural e receber **relatórios em PDF no padrão Mec Gestão**, com gráficos.

- **Somente leitura:** o plugin nunca altera dados nem estrutura. Ele só aceita `SELECT`/`WITH`, roda tudo em transação
  `READ ONLY` e recusa pedidos de alteração.
- **PDF padrão:** cabeçalho com os dados da filial, faixa de título, tabela com totais, gráficos e paginação.
- **Atualização automática:** as máquinas dos clientes recebem cada nova versão publicada aqui.

## Instalação no cliente (uma vez por máquina)

**Envie ao cliente só o arquivo [`INSTALAR-MEC-CLAUDE.bat`](INSTALAR-MEC-CLAUDE.bat)** (por WhatsApp, e-mail ou pendrive).
O cliente dá dois cliques no arquivo, com o usuário do Windows que usa o Claude. O instalador baixa a versão mais
recente do GitHub e faz tudo sozinho:

1. verifica o aplicativo Claude e o Microsoft Edge (usado para gerar os PDFs);
2. instala o **Git**, se faltar;
3. providencia o `isql` do **Firebird 2.5**. Se faltar, baixa o pacote oficial e extrai em
   `%LOCALAPPDATA%\MecGestao\Firebird25`, sem instalar serviço nem alterar o Firebird existente;
4. lista os bancos do MEC encontrados no computador, pede o usuário e a senha do Firebird e testa a conexão;
5. registra o plugin no Claude com **atualização automática**;
6. cria a tarefa agendada **"MecGestao - Atualizar plugin Claude"**, que ao entrar no Windows e a cada 4 horas busca a versão
   mais nova no GitHub, em segundo plano. Assim os clientes se atualizam mesmo sem reabrir o Claude; a versão nova entra
   em uso na próxima vez que o Claude for aberto.

Depois, basta fechar e abrir o Claude. Na primeira sessão, o plugin é baixado sozinho.

Ninguém precisa de conta no GitHub; só a Mec Gestão, para publicar atualizações.
Se o Windows avisar que o arquivo veio da internet, clique em **Mais informações → Executar assim mesmo**.

**Recomendado:** use um usuário do Firebird com permissão **somente de SELECT**, não o SYSDBA.
O script para criá-lo está em [`configuracao.md`](skills/firebird-mec-cliente-final/references/configuracao.md).

Alternativa: baixe o ZIP do repositório, extraia e execute `instalar\instalar-cliente.bat`.
Instalação manual, sem o instalador: no Claude, digite
```
/plugin marketplace add GENILSONCIEC/mec-gestao-claude-cliente-final
/plugin install mec-gestao@mec-gestao-plugins
```
Depois, em `/plugin` → **Marketplaces**, ative **Enable auto-update**. Configure as variáveis `MEC_FB_DATABASE`, `ISC_USER` e
`ISC_PASSWORD` conforme `configuracao.md`.

## Como publicar uma atualização (Mec Gestão)

1. Altere os arquivos em `skills/firebird-mec-cliente-final/`.
2. **Aumente a versão** em `.claude-plugin/plugin.json` (`1.0.0` → `1.0.1`; nova função → `1.1.0`).
   Sem mudar a versão, os clientes **não** recebem a alteração. Isso permite enviar trabalho em andamento sem afetar ninguém.
3. Registre a mudança no `CHANGELOG.md`.
4. `git commit` e `git push`. Os clientes recebem a nova versão ao abrir a próxima sessão do Claude.

**Segurança:** este repositório é público e o código dele roda nas máquinas dos clientes, com acesso ao banco.
- Mantenha 2FA ativo na conta GitHub.
- Proteja a branch `main`.
- Nunca coloque aqui senhas, caminhos de banco ou dados de clientes.

## Estrutura
```
.claude-plugin/
  marketplace.json          catálogo (marketplace "mec-gestao-plugins")
  plugin.json               plugin "mec-gestao" e sua versão
skills/firebird-mec-cliente-final/
  SKILL.md                  regras e fluxo de trabalho do Claude
  scripts/fbquery.ps1       consultas somente leitura (bloqueio + transação READ ONLY)
  scripts/gerar_relatorio.ps1  PDF no padrão Mec Gestão (Edge headless)
  references/               modelo de dados, performance, procedures, layout do PDF, exemplos
INSTALAR-MEC-CLAUDE.bat    instalador de um arquivo só (baixa o instalar-cliente.ps1 do GitHub)
instalar/
  instalar-cliente.bat/.ps1 instalador completo
```
