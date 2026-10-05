# Mec Gestão — Relatórios para o Claude

Plugin do Claude Code / aplicativo Claude que permite aos clientes do sistema **MEC** consultar o banco Firebird 2.5
em linguagem natural e receber **relatórios em PDF no padrão Mec Gestão**, com gráficos.

- **Somente leitura:** o plugin nunca altera dados nem estrutura. Ele só aceita `SELECT`/`WITH`, roda tudo em transação
  `READ ONLY` e recusa pedidos de alteração.
- **PDF padrão:** cabeçalho com os dados da filial, faixa de título, tabela com totais, gráficos e paginação.
- **Atualização automática:** as máquinas dos clientes recebem cada nova versão publicada aqui.

## Instalação no cliente (uma vez por máquina)

Pré-requisitos:
- aplicativo Claude ou Claude Code;
- [Git para Windows](https://git-scm.com/download/win);
- cliente do Firebird 2.5;
- Microsoft Edge (já vem no Windows).

1. Baixe este repositório (**Code → Download ZIP**) e extraia.
2. Execute `instalar\instalar-cliente.bat` e informe:
   - o banco (`servidor/porta:caminho.fdb`);
   - o usuário e a senha do Firebird.

   O instalador testa a conexão e registra o plugin com atualização automática.
3. Feche e abra o Claude. Na primeira sessão, o plugin é baixado sozinho.

**Recomendado:** use um usuário do Firebird com permissão **somente de SELECT**, não o SYSDBA.
O script para criá-lo está em [`configuracao.md`](skills/firebird-mec-cliente-final/references/configuracao.md).

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
instalar/
  instalar-cliente.bat/.ps1 instalador para as máquinas dos clientes
```
