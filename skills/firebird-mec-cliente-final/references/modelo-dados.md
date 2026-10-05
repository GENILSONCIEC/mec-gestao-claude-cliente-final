# Modelo de dados — sistema MEC (Firebird 2.5)

Convenção: cada tabela tem um prefixo de 3 letras nas colunas (`ME1_`, `ME2_`, `RC1_`, `PAG_`...).
Não existem comentários (`RDB$DESCRIPTION`) nas tabelas. Para ver as colunas de uma tabela, consulte o catálogo:

```sql
SELECT TRIM(RDB$FIELD_NAME) FROM RDB$RELATION_FIELDS
WHERE RDB$RELATION_NAME = 'MVESTOQUE1' ORDER BY RDB$FIELD_POSITION
```

Valores monetários são `NUMERIC(15,2)` ou `NUMERIC(15,4)`. Colunas de texto são `CHAR`, então use `TRIM()` para exibir.
**Datas `1899-12-30`** são a "data zero" do Delphi (equivalem a vazio) e devem ser excluídas ou tratadas nos relatórios.

## 1. Movimento de estoque (vendas, compras, transferências)

| Tabela | Papel | Chave |
|---|---|---|
| `MVESTOQUE1` | Cabeçalho do documento | PK `ME1_DOCTO CHAR(12)` + `ME1_OPERACAO` |
| `MVESTOQUE2` | Itens do documento | PK `ME2_ID`; liga por `ME2_DOCTO` + `ME2_OPERACAO` |
| `PRAZO` | Formas de pagamento/parcelas do documento | PK `PRA_ID`; liga por `PRA_DOCTO` + `PRA_TIPO` |

### Códigos de operação (`ME1_OPERACAO` / `ME2_OPERACAO`)

| Op | Significado | Efeito no estoque | Participante |
|---|---|---|---|
| 1 | Entrada / compra | **+** aumenta | `ME1_FORNECEDOR` |
| 2 | Transferência — entrada | **+** aumenta | `ME1_FORNECEDOR` |
| 3 | Devolução de venda | **+** aumenta | `ME1_CLIENTE` |
| 4 | Outras entradas de estoque | **+** aumenta | — |
| 5 | Venda | **−** diminui | `ME1_CLIENTE` |
| 6 | Transferência — saída | **−** diminui | `ME1_FORNECEDOR` |
| 9 | Outras saídas de estoque | **−** diminui | — |
| 10 | Produtos lançados pela Ordem de Serviço | **−** diminui | cliente da OS |

Sinal para saldo de estoque: `CASE WHEN ME2_OPERACAO IN (1,2,3,4) THEN 1 WHEN ME2_OPERACAO IN (5,6,9,10) THEN -1 END`.

**Venda líquida** = operação 5 − operação 3. Itens de OS (operação 10) também são faturamento; pergunte ao usuário se devem entrar no relatório.
**Cancelados**: `ME1_CANCEL` (verifique os valores com `SELECT DISTINCT`) e a data em `ME1_DATACAN`.

### Ligações — ATENÇÃO à operação 10
```sql
-- Operações 1,2,3,4,5,6,9: o cabeçalho está em MVESTOQUE1
FROM MVESTOQUE2 M2
JOIN MVESTOQUE1 M1 ON M1.ME1_DOCTO = M2.ME2_DOCTO AND M1.ME1_OPERACAO = M2.ME2_OPERACAO

-- Operação 10: NÃO existe cabeçalho em MVESTOQUE1; o cabeçalho é a Ordem de Serviço
FROM MVESTOQUE2 M2
JOIN OSERVICO1 OS1 ON OS1.OS1_DOCTOS = M2.ME2_DOCTO AND M2.ME2_OPERACAO = 10
```
Podem existir itens da operação 10 sem OS correspondente (OS excluída). Se o relatório precisa de todos, use LEFT JOIN.

### Colunas mais usadas
- **MVESTOQUE1**:
  - identificação: `ME1_DOCTO`, `ME1_OPERACAO`, `ME1_FILIAL`;
  - datas: `ME1_EMISSAO`, `ME1_MOVIMENTO` (data contábil do movimento), `ME1_HORA`;
  - participantes: `ME1_CLIENTE`, `ME1_FORNECEDOR`, `ME1_VENDEDOR` → FUNCIONARIO;
  - valores: `ME1_VLRNOTA`, `ME1_VLPRODUTOS`, `ME1_DESCONTO`;
  - outros: `ME1_CANCEL`, `ME1_NOTAFISCAL`, `ME1_TIPOVENDA`, `ME1_PDV`, `ME1_CHAVENFE`;
  - cópia do cliente no documento: `ME1_NOMCLI`, `ME1_CNPJCP`, `ME1_CIDCLI`, `ME1_ESTCLI`.
- **MVESTOQUE2**:
  - identificação: `ME2_DOCTO`, `ME2_OPERACAO`, `ME2_FILIAL`, `ME2_DATA`;
  - produto: `ME2_PRODUTO` → PRODUTO.PRO_CODIGO, `ME2_PRODUTOD` → PRODUTOD.PRD_ID;
  - valores: `ME2_QUATIDADE` (sic, com "QUA"), `ME2_VLRUNIT`, `ME2_DESCONTO` (unitário: total = `(ME2_VLRUNIT - ME2_DESCONTO) * ME2_QUATIDADE`).

### Tabelas com estrutura igual a MVESTOQUE1/2
Estas tabelas têm a mesma estrutura de MVESTOQUE1/2, mas guardam outros tipos de documento:
- `MAESTOQUE*`, `MCESTOQUE*`, `MDESTOQUE*`, `MEESTOQUE*`, `MPESTOQUE*`;
- `MVBSTOQUE*`, `MVCSTOQUE*`, `MVFSTOQUE*`, `MVOSTOQUE*`;
- `MVESTOQUE3..10`.

O significado de cada uma **não está documentado**: pergunte ao usuário antes de usá-las.
Orçamentos ficam em `ORCAMENTO1/2` e pedidos de compra em `PEDIDO1/2/3`.

## 2. Ordem de serviço
- `OSERVICO1` (cabeçalho, documento em `OS1_DOCTOS`)
- `OSERVICO2` (serviços/itens da OS, datas `OS2_DATTERMIN`, `OS2_DATAENTREGA`)
- Os produtos da OS estão em `MVESTOQUE2` com operação 10.

## 3. Notas fiscais
- `NFISCAL1`: cabeçalho, PK `NF1_DOCTO`. Colunas: `NF1_EMISSAO`, `NF1_FILIAL`, `NF1_CLIENTE`, `NF1_CANCELADA`, `NF1_STATUSNFE`, `NF1_CHAVE`, `NF1_NFNUMERO`.
- `NFISCAL2`: itens, PK `NF2_ID`; liga por `NF2_DOCTO` = `NF1_DOCTO`; produto em `NF2_PRODUTO`.
- Complementos: `NFISCALVENC` (vencimentos), `NFISCALPAGTO`, `NFISCALPEDIDO`, `NFISCALXML`, `NFISCALEVENTO`. O sufixo `C` indica notas de compra.
- SPED: `SPED*`.

## 4. Financeiro
| Tabela | Papel | Chave / ligação | Datas |
|---|---|---|---|
| `RECEBER1` | Título a receber | PK `RC1_DOCREC + RC1_CONTROLE`; `RC1_CLIENTE`, `RC1_FILIAL`, `RC1_VENDEDOR`, `RC1_MVESTOQUE1` | `RC1_EMISSAO` (índice) |
| `RECEBER2` | Parcelas | PK `RC2_ID`; liga `RC2_DOCREC + RC2_CONTROLE` | `RC2_VENCIMENTO` (**sem índice**), `RC2_DATABAIXA` (índice composto), `RC2_DATABANCO` |
| `RECEBER3`, `RECEBER4`, `HAVER` | Baixas e créditos do cliente | — | — |
| `PAGAR` | Contas a pagar (título + parcela) | PK `PAG_DOCPAG + PAG_CONTROLE`; `PAG_FORNECEDOR`, `PAG_FILIAL` | `PAG_EMISSAO`, `PAG_VENCIMENTO`, `PAG_DATAPAGO` (**sem índice**) |
| `MOVCAIXA` | Lançamentos de caixa | PK `MCX_ID`; contas `MCX_COPCAIXAC/D` → `COPCAIXA` | `MCX_DATA` (índice) |

Em aberto: `RC2_DATABAIXA IS NULL` / `RC2_SALDO > 0`; `PAG_DATAPAGO IS NULL` / `PAG_SALDO > 0` (confirme com dados).

## 5. Cadastros
- `CLIENTE`: PK `CLI_CODIGO`; `CLI_RAZAO`, `CLI_FANTA`, `CLI_CNPJ`, `CLI_REGIAO` → REGIAO, `CLI_ATIVO`.
- `PRODUTO`: PK `PRO_CODIGO`; `PRO_NOMECOMPLETO`, `PRO_REFERENCIA`, `PRO_CODBARRA`, `PRO_GRUPO`, `PRO_SUBGRUPO`, `PRO_SECCAO`, `PRO_DEPROD`, `PRO_FABRICANTE`, `PRO_ATIVO`.
- `PRODUTOD`: dados do produto por filial (estoque, preço); PK `PRD_ID`, `PRD_PRODUTO`, `PRD_FILIAL`.
- `FORNECEDOR`, `FUNCIONARIO` (vendedores, `FUN_NOME`), `FILIAL`.
- `GRUPO`, `SUBGRUPO`, `SECCAO`, `DEPROD`, `FABRICANTE`, `REGIAO`, `TIPODOCUMENTO`, `BANCO`.

## 6. Views existentes
- Caixa: `SALDOSCAIXA`, `SALDOSCAIXAC/D`, `EVOLUCOES`, `EVOLUCOESC/D/CP/DP`.
- Estoque: `ESTOQUE_MINIMO`, `ESTOQUE_MINIMO_MENOR`.
- Outras: `COTACAO_PRODUTOS`, `MALA_DIRETA`, `REQUISICAO_SEM_EFETIVAR`, `REQUISICAO_SEM_VALOR`, `ETIQUETA_BARRA/NORMAL`, `CONVERT_DOCINTEIRO`.

## 7. Resumos prontos
- `CURVA_ABCD_P`: já é uma tabela de resumo (curva ABC por período e filial). Use-a em vez de recalcular a partir de MVESTOQUE2 quando o período coincidir.
