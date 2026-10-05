---
name: firebird-mec-cliente-final
description: Consultas e relatórios SOMENTE LEITURA no banco Firebird 2.5 do sistema MEC (ERP comercial/agro, arquivo DBCIECF.FDB), entregues em PDF no padrão visual Mec Gestão com gráficos. Use quando o usuário pedir relatórios, consultas, totais, análises, gráficos ou dúvidas sobre dados de vendas, estoque, notas fiscais, contas a receber/pagar, caixa, clientes, produtos ou ordens de serviço do MEC. Nunca altera dados nem estrutura.
---

# Firebird MEC — consultas somente leitura

Você ajuda usuários do sistema MEC a obter informações do banco Firebird 2.5 por meio de consultas.
Os bancos dos clientes podem ter **até 100 GB e mais de 100 milhões de registros**, então cada consulta precisa ser eficiente.

## Regra absoluta: SOMENTE LEITURA

**Este skill nunca altera dados nem estrutura do banco, mesmo que o usuário peça.**

- Rode SQL **apenas** pelos scripts deste skill: `scripts/fbquery.ps1` e `scripts/gerar_relatorio.ps1`, que usa o primeiro.
  O `fbquery.ps1` aceita só `SELECT`/`WITH`, bloqueia comandos de alteração e executa tudo numa transação `READ ONLY`.
- **Nunca** chame o `isql.exe` diretamente, nem outra ferramenta (gfix, gbak, gsec, ODBC, Python, FlameRobin etc.)
  para acessar o banco.
- **Nunca** tente contornar o bloqueio do script: não edite o script, não use outro caminho, não divida o comando.
- **Não use** procedures marcadas com **Grava? = sim** em `references/procedures.md`.
- Se o usuário pedir para inserir, alterar, excluir, corrigir dados, criar ou alterar índices, tabelas, procedures, triggers,
  usuários ou permissões, ou rodar manutenção (sweep, backup, restore): **recuse com educação**. Explique que este
  assistente só faz consultas e que a alteração deve ser feita pelo sistema MEC ou pelo suporte técnico. Você pode
  descrever o que precisaria ser feito, mas não execute.
- Nunca peça, mostre ou digite a senha do banco. As credenciais vêm de variáveis de ambiente configuradas pelo administrador
  (veja `references/configuracao.md`).

## Como executar consultas

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\scripts\fbquery.ps1" -Sql "SELECT FIRST 10 CLI_CODIGO, CLI_RAZAO FROM CLIENTE"
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\scripts\fbquery.ps1" -File consulta.sql -Plan -Stats
```
- `-Plan` mostra o plano de execução (use antes de consultas pesadas). `-Stats` mostra o tempo e as leituras.
- `-Database` sobrepõe o banco configurado em `MEC_FB_DATABASE` (formato `servidor/porta:caminho.fdb`).
- Consultas longas: grave num arquivo `.sql` (codificação Windows-1252) e use `-File`.
- `-Json arquivo.json` grava o resultado em JSON (UTF-8). Use para alimentar o relatório PDF (`"dados"`).
- Se o script disser que falta configuração, mostre ao usuário a mensagem e as instruções de `references/configuracao.md`.
  Não tente adivinhar senha nem caminho.

## Como gerar o PDF

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\scripts\gerar_relatorio.ps1" -Spec relatorio.json
```
A especificação, o layout, os tipos de gráfico e os exemplos estão em `references/relatorio-pdf.md` e
`references/exemplos/`. Não altere cores nem layout: eles seguem o padrão oficial Mec Gestão.

## Fluxo de trabalho

1. **Entenda o pedido.** Pergunte o que faltar: período, filial, se inclui devoluções, cancelados ou itens de OS.
2. **Consulte o modelo** em `references/modelo-dados.md`: tabelas, ligações e **códigos de operação**.
   Para descobrir colunas, consulte `RDB$RELATION_FIELDS`. Não invente nomes de colunas.
3. **Verifique se já existe uma procedure** de relatório em `references/procedures.md` (somente as sem "Grava?").
   Use-a com `SELECT * FROM PROCEDURE(param1, param2, ...)`.
4. **Escreva a consulta seguindo `references/performance.md`.** Isso é obrigatório para bases grandes: filtro por data
   indexada + filial, sem funções sobre colunas no WHERE, com `FIRST n` em listagens. Use `-Plan` só quando houver
   dúvida se a consulta usa índice numa tabela de movimento grande.
5. **Gere SEMPRE o PDF no padrão Mec Gestão** com `scripts/gerar_relatorio.ps1`, seguindo `references/relatorio-pdf.md`:
   - cabeçalho com os dados da FILIAL;
   - título = assunto/tabela consultada (PRODUTOS, CLIENTES, VENDAS POR DIA...);
   - linha de filtro com os critérios;
   - tabela com totais;
   - **gráfico sempre que os dados forem analíticos**.

   **Seja rápido:** coloque o SQL direto no campo `"sql"` da spec e gere o PDF numa única execução, sem testar a
   consulta antes. Se der erro, o gerador mostra a mensagem: corrija e rode de novo. Para conferir, use o **resumo que o
   gerador imprime** (linhas, primeira linha, totais, cabeçalho). **Não abra o PDF**, salvo se o resumo indicar problema:
   0 linhas inesperadas, totais estranhos ou cabeçalho vazio.
6. **Entregue o PDF** ao usuário: use a ferramenta de envio de arquivo, se houver; senão, informe o caminho. Resuma o
   resultado em poucas linhas, em português, com valores em R$ de 2 casas.
7. Se a consulta ficar lenta por falta de índice ou se um relatório depender de uma melhoria no banco, **apenas recomende**
   ao usuário que acione o suporte/DBA.

## Pontos de atenção do modelo (resumo)
- Operações: **1** compra/entrada (+), **2** transferência entrada (+), **3** devolução de venda (+), **4** outras entradas (+),
  **5** venda (−), **6** transferência saída (−), **9** outras saídas (−), **10** produtos da OS (−).
- MVESTOQUE2 → MVESTOQUE1 pela chave `DOCTO + OPERACAO`. **Exceção: a operação 10 não tem MVESTOQUE1.** O cabeçalho é
  `OSERVICO1` (`OS1.OS1_DOCTOS = M2.ME2_DOCTO AND M2.ME2_OPERACAO = 10`).
- Quantidade do item: `ME2_QUATIDADE` (grafia do sistema). Valor do item: `(ME2_VLRUNIT - ME2_DESCONTO) * ME2_QUATIDADE`.
- Datas `1899-12-30` significam "vazio".
- Colunas CHAR: use `TRIM()` ao exibir.
