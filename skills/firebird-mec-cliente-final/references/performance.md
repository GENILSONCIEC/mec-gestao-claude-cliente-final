# Consultas rápidas em bancos grandes (até 100 GB / 100+ milhões de linhas, Firebird 2.5)

Em bases grandes, uma consulta mal escrita lê a tabela inteira e pode levar horas, prejudicando todos os usuários
do sistema. Siga estas regras sempre.

## Antes de rodar
1. **Sempre filtre por período** numa coluna de data com índice e por filial. Se o usuário não informou o período, pergunte.
   Colunas de data **com** índice:
   - `ME1_EMISSAO`, `ME1_MOVIMENTO`;
   - `ME2_DATA`, também nos compostos `(ME2_FILIAL, ME2_DATA, ME2_OPERACAO)`, `(ME2_PRODUTO, ME2_DATA)` e `(ME2_PRODUTOD, ME2_DATA, ME2_OPERACAO)`;
   - `NF1_EMISSAO`, `RC1_EMISSAO`, `PRA_EMISSAO`;
   - `MCX_DATA` (composto `MCX_DATA, MCX_NUMERO`);
   - `RC2_DATABAIXA` (composto).

   Colunas **sem** índice:
   - `RC2_VENCIMENTO`, `RC2_DATABANCO`;
   - `PAG_VENCIMENTO`, `PAG_DATAPAGO`, `PAG_EMISSAO`;
   - `ME1_DATACAN`, `OS2_DATTERMIN`.

   Filtrar por uma coluna sem índice lê a tabela toda. Avise o usuário e prefira combinar com um filtro indexado.
2. **Veja o plano antes** com `-Plan`, rodando com `FIRST 1`. Se aparecer `NATURAL` numa tabela grande de movimento
   (MVESTOQUE1/2, RECEBER2, PAGAR, MOVCAIXA, NFISCAL1/2, PRAZO), reescreva a consulta antes de rodar de verdade.
3. **Limite o retorno**: `SELECT FIRST 100 ...` em listagens; para totais, agregue no banco (`SUM`/`COUNT` com `GROUP BY`)
   em vez de trazer linhas.

## Escrita do WHERE (o que impede o uso do índice no FB 2.5)
| Evite | Use |
|---|---|
| `EXTRACT(YEAR FROM ME1_EMISSAO) = 2025` | `ME1_EMISSAO BETWEEN '2025-01-01' AND '2025-12-31'` |
| `CAST(ME1_EMISSAO AS VARCHAR(10)) LIKE '2025%'` | intervalo de datas |
| `COALESCE(M1.ME1_FILIAL, 0) = 1` | `M1.ME1_FILIAL = 1` |
| `TRIM(ME1_DOCTO) = '123'` | `ME1_DOCTO = '123'` (CHAR compara ignorando espaços à direita) |
| `UPPER(CLI_RAZAO) LIKE '%JOSE%'` | `CLI_RAZAO STARTING WITH 'JOSE'` (usa índice) ou `CONTAINING` só em tabela pequena |
| `(FILIAL = :F OR :F = 999)` | gerar a consulta com ou sem o filtro, ou `FILIAL BETWEEN :FIL_INI AND :FIL_FIN` |
| subselect correlacionado na lista `(SELECT SUM(...) WHERE x = t.x)` | `JOIN` com tabela derivada agregada |

- `IN (5, 3)` é aceitável. `OR` entre colunas diferentes geralmente força leitura completa.
- `ME1_OPERACAO`, `PRA_TIPO`, `*_ATIVO` e `*_REPLICPDV` têm poucos valores distintos. Não conte com eles como filtro principal.
- **Truque do Firebird para descartar um índice ruim**: se o plano mostrar o otimizador combinando um índice bom com um ruim,
  por exemplo `INDEX (IDX_MVESTOQUE2_ABCD_01, MV2_OPERACAO_QTDE)`, escreva `M2.ME2_OPERACAO + 0 = 5`. O `+ 0` impede o uso do
  índice de operação, e o filtro passa a ser aplicado só sobre as linhas já selecionadas pela data/filial. Compare os dois planos e tempos com `-Plan -Stats`.
- Junte MVESTOQUE2 → MVESTOQUE1 sempre pelas **duas** colunas da chave (`DOCTO` + `OPERACAO`).

## Modelos

Vendas líquidas por dia (filial 1, mês de setembro):
```sql
SELECT M2.ME2_DATA,
       SUM(CASE WHEN M2.ME2_OPERACAO = 5 THEN 1 ELSE -1 END
           * (M2.ME2_VLRUNIT - COALESCE(M2.ME2_DESCONTO,0)) * M2.ME2_QUATIDADE) AS VENDA_LIQUIDA
FROM MVESTOQUE2 M2
WHERE M2.ME2_FILIAL = 1
  AND M2.ME2_DATA BETWEEN '2026-09-01' AND '2026-09-30'
  AND M2.ME2_OPERACAO IN (5, 3)
GROUP BY M2.ME2_DATA
ORDER BY M2.ME2_DATA
```
(Confirme com o usuário se itens cancelados devem ser excluídos via `MVESTOQUE1.ME1_CANCEL`.)

Top 20 produtos vendidos no período:
```sql
SELECT FIRST 20 M2.ME2_PRODUTO, TRIM(P.PRO_NOMECOMPLETO) AS PRODUTO,
       SUM(M2.ME2_QUATIDADE) AS QTDE,
       SUM((M2.ME2_VLRUNIT - COALESCE(M2.ME2_DESCONTO,0)) * M2.ME2_QUATIDADE) AS VALOR
FROM MVESTOQUE2 M2
JOIN PRODUTO P ON P.PRO_CODIGO = M2.ME2_PRODUTO
WHERE M2.ME2_FILIAL = 1
  AND M2.ME2_DATA BETWEEN '2026-09-01' AND '2026-09-30'
  AND M2.ME2_OPERACAO = 5
GROUP BY M2.ME2_PRODUTO, P.PRO_NOMECOMPLETO
ORDER BY 4 DESC
```

## Bases muito grandes
- Para relatórios de longos períodos, sugira ao usuário **tabelas de resumo** (como `CURVA_ABCD_P`). A criação delas
  é tarefa do desenvolvedor/DBA; este skill não cria nada.
- Consultas pesadas devem rodar fora do horário de pico.
- A transação usada pelo `fbquery.ps1` é READ ONLY READ COMMITTED. Ela não segura a coleta de lixo do banco, então é
  segura para leituras longas.
