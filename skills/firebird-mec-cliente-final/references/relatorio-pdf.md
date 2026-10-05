# Relatório em PDF — padrão Mec Gestão

**Todo resultado de consulta é entregue ao usuário como PDF neste padrão.** Ele é gerado pelo script
`scripts/gerar_relatorio.ps1` a partir de uma especificação JSON. O script consulta o banco somente pelo
`fbquery.ps1` (somente leitura) e converte o HTML em PDF com o Microsoft Edge, que já vem no Windows.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\scripts\gerar_relatorio.ps1" -Spec relatorio.json
```
Grave o JSON em **UTF-8**. A saída informa o caminho do PDF gerado.

## Layout (fixo, não altere)
Baseado no "Demonstrativo de Resultado" do Mec Gestão, com as cores da marca:
- **Cabeçalho**, repetido em todas as páginas e montado a partir da tabela `FILIAL` (`filial` na spec):
  - **RAZÃO SOCIAL | CNPJ**;
  - Telefone e E-mail;
  - Endereço completo (rua, número, bairro, cidade/UF, CEP).

  Uma linha laranja fecha o cabeçalho. O script lê **só** essas colunas públicas da FILIAL; nunca inclua outras,
  porque a tabela guarda senhas e chaves.
- **Faixa de título** azul-petróleo com o título em maiúsculas. **O título é o assunto/tabela consultada**:
  "PRODUTOS", "CLIENTES", "VENDAS POR DIA", "CONTAS A RECEBER" etc.
- **Linha de filtro**: à esquerda, os critérios usados (período, filial, operações); à direita, "Emitido em".
- **Cartões de resumo** (opcional), gráficos (opcional) e a **tabela** com cabeçalho azul, bordas finas e linha de TOTAL
  em destaque laranja-claro.
- **Rodapé**: data/hora de emissão à esquerda, "Mec Gestão" ao centro e "Pág. X / Y" à direita.

Cores da marca: azul-petróleo `#10869F` (títulos/cabeçalhos), azul escuro `#0B6D82` (textos de destaque),
laranja `#F09A2C` (linhas de destaque e totais).

## Quando incluir gráfico
**Se os dados forem analíticos** (totais por período, por grupo, por vendedor, ranking, comparação, evolução), inclua
pelo menos um gráfico. Uma listagem cadastral simples (lista de clientes, de produtos) não precisa de gráfico.

| Situação | `tipo` |
|---|---|
| Ranking / comparação entre itens (top produtos, vendedores, clientes) | `barras` (horizontais), `limite` 10–15 |
| Valores ao longo do tempo com poucos pontos (meses, dias de um mês) | `colunas` |
| Evolução / tendência com muitos pontos, ou 2–3 séries ao longo do tempo | `linha` |
| Participação de partes num total (no máximo 5 fatias; o resto vira "Outros") | `pizza` |

Regras:
- **Uma medida por gráfico.** Nunca misture valor (R$) e quantidade no mesmo eixo; faça dois gráficos.
- **No máximo 3 séries** por gráfico (`valores` com até 3 campos, com nomes em `series`).
- **Ordene** os dados de ranking do maior para o menor no SQL (`ORDER BY ... DESC`).
- **Datas** no eixo saem como dd/mm. Ordene por data crescente.
- As cores dos gráficos são fixas e foram validadas para daltonismo: azul `#0087AD`, laranja `#F09A2C`, roxo `#4A3AA7`,
  vermelho `#E34948`, verde `#008300`, rosa `#E87BA4`. Não troque.

## Especificação (JSON)

| Campo | Obrigatório | Descrição |
|---|---|---|
| `titulo` | sim | Assunto do relatório (vai em maiúsculas na faixa) |
| `filial` | recomendado | `FIL_CODIGO` usado no cabeçalho. Use a filial filtrada; se for "todas", use a principal (1) |
| `filtro` | sim | Critérios: "Filtrado por Data: 01/09/2026 até o dia 30/09/2026 \| Filial: 1 \| ..." |
| `sql` | um dos três | Consulta SELECT executada em modo somente leitura |
| `dados` | um dos três | Caminho de um JSON gerado por `fbquery.ps1 -Json` |
| `linhas` | um dos três | Array de objetos já pronto |
| `colunas` | recomendado | Lista de `{campo, titulo, tipo, decimais?, total?, largura?}` |
| `totais` | não | `true` → linha TOTAL somando as colunas com `"total": true` |
| `resumo` | não | Cartões: `[{rotulo, valor, tipo}]` (ex.: total vendido, nº de documentos, ticket médio) |
| `graficos` | não | `[{tipo, titulo, rotulo, valores:[...], series?:[...], limite?, formato?}]` |
| `orientacao` | não | `retrato` (padrão) ou `paisagem` para tabelas com muitas colunas |
| `grafico_depois` | não | `true` → tabela antes dos gráficos |
| `tabela` | não | `false` → só cartões e gráficos |
| `saida` | não | Caminho do PDF. Padrão: `Documentos\Relatorios MEC\<titulo>_<data>.pdf` (ou `MEC_RELATORIOS_DIR`) |

Tipos de coluna:
- `texto`;
- `inteiro`;
- `numero` (com `decimais`);
- `moeda` (2 casas, sem "R$" na tabela; o título da coluna leva "(R$)");
- `percentual`;
- `data` (sai como dd/mm/aaaa; `1899-12-30` vira vazio).

Linhas especiais na tabela: inclua o campo `_estilo` com `grupo` (faixa azul-clara, negrito), `subgrupo` (negrito) ou
`total`. Linhas com `_estilo` não entram nos gráficos nem na soma.

`formato` do gráfico: `moeda`, `numero`, `inteiro` ou `percentual`.

No SQL, use **apelidos simples sem espaços** (`AS VALOR`, `AS PRODUTO`) e `TRIM()` em colunas CHAR.

## Exemplo
```json
{
  "titulo": "Produtos mais vendidos",
  "filial": 1,
  "filtro": "Filtrado por Data: 01/09/2026 até o dia 30/09/2026 | Filial: 1 | Operação: Venda",
  "sql": "SELECT FIRST 15 TRIM(P.PRO_NOMECOMPLETO) AS PRODUTO, SUM(M2.ME2_QUATIDADE) AS QTDE, SUM((M2.ME2_VLRUNIT - COALESCE(M2.ME2_DESCONTO,0)) * M2.ME2_QUATIDADE) AS VALOR FROM MVESTOQUE2 M2 JOIN PRODUTO P ON P.PRO_CODIGO = M2.ME2_PRODUTO WHERE M2.ME2_FILIAL = 1 AND M2.ME2_DATA BETWEEN '2026-09-01' AND '2026-09-30' AND M2.ME2_OPERACAO = 5 GROUP BY P.PRO_NOMECOMPLETO ORDER BY 3 DESC",
  "colunas": [
    {"campo":"PRODUTO","titulo":"Produto","tipo":"texto"},
    {"campo":"QTDE","titulo":"Qtde","tipo":"numero","decimais":3,"total":true,"largura":"12%"},
    {"campo":"VALOR","titulo":"Valor (R$)","tipo":"moeda","total":true,"largura":"16%"}
  ],
  "totais": true,
  "graficos": [ {"tipo":"barras","titulo":"Top 10 produtos por valor vendido","rotulo":"PRODUTO","valores":["VALOR"],"limite":10,"formato":"moeda"} ]
}
```
Mais exemplos (vendas por dia com colunas e linha, participação por grupo em pizza) estão em `references/exemplos/`.

## Depois de gerar
1. Confira o **resumo impresso pelo gerador**: quantidade de linhas, primeira linha, totais das colunas e cabeçalho.
   Só abra o PDF se o resumo indicar problema, porque abrir o PDF deixa a resposta bem mais lenta.
2. Entregue o PDF ao usuário: se houver ferramenta de envio de arquivo, use-a; senão, informe o caminho.
3. No texto da resposta, resuma em 2–4 linhas o que o relatório mostra (total, destaque principal, critérios).
