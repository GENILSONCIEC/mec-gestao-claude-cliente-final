# Configuração (feita pelo administrador / suporte, uma vez por máquina)

## 1. Criar um usuário do Firebird somente leitura (RECOMENDADO)
O script já bloqueia alterações, mas a proteção definitiva é o próprio banco: um usuário que **só tem SELECT**.
Execute como SYSDBA, numa ferramenta de administração (fora deste assistente):

```sql
-- Firebird 2.5: criar o usuário (no security2.fdb do servidor)
CREATE USER CONSULTA PASSWORD 'defina_uma_senha';
COMMIT;

-- Conceder SELECT em todas as tabelas e views do banco
SET TERM ^ ;
EXECUTE BLOCK AS
DECLARE VARIABLE T VARCHAR(63);
BEGIN
  FOR SELECT TRIM(RDB$RELATION_NAME) FROM RDB$RELATIONS WHERE COALESCE(RDB$SYSTEM_FLAG,0) = 0 INTO :T DO
    EXECUTE STATEMENT 'GRANT SELECT ON "' || T || '" TO CONSULTA';
END^
SET TERM ; ^
COMMIT;
```

Para que o usuário possa usar as procedures de relatório, conceda `EXECUTE` somente às procedures **sem "Grava? = sim"**
listadas em `procedures.md`:

```sql
GRANT EXECUTE ON PROCEDURE CONTAS_RECEBER TO CONSULTA;
```

As procedures acessam as tabelas com os direitos do usuário. Como ele só tem SELECT, qualquer tentativa de gravação é negada pelo banco.

## 2. Variáveis de ambiente do usuário Windows
No Prompt de Comando da máquina do usuário:

```bat
setx ISC_USER "CONSULTA"
setx ISC_PASSWORD "a_senha_definida"
setx MEC_FB_DATABASE "localhost/3050:C:\MEC\DBS\EMPRESA\DBCIECF.FDB"
```

Opcional, se o Firebird 2.5 estiver instalado em outro caminho:
```bat
setx MEC_FB_ISQL "C:\Program Files\Firebird\Firebird_2_5\bin\isql.exe"
```
Depois, feche e abra o aplicativo do Claude.

- Banco em outro computador: use `servidor/3050:C:\caminho\banco.fdb` (o caminho é o do servidor).
- Se houver Firebird 3/4/5 na mesma máquina, confirme a porta do 2.5. Por padrão é 3050; veja `RemoteServicePort` no `firebird.conf`.

Opcional, pasta onde os PDFs são salvos (padrão: `Documentos\Relatorios MEC`):
```bat
setx MEC_RELATORIOS_DIR "C:\Relatorios MEC"
```

## 3. Instalação e atualização
Este skill é distribuído como plugin do Claude Code pelo repositório GitHub da Mec Gestão.
Use o instalador `instalar\instalar-cliente.bat` do repositório: ele configura as variáveis acima, registra o
marketplace com atualização automática e ativa o plugin. É preciso ter o Git, o cliente do Firebird 2.5 (`isql.exe`) e o
Microsoft Edge (já vem no Windows 10/11, usado para gerar os PDFs).
