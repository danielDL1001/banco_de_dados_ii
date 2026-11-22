# Banco de Dados I — PostgreSQL 16

Prof. Rodrigo Gonçalves Pinto · IESB

## Antes de tudo

1. Instale o **Docker Desktop** e deixe ele **aberto** (o ícone da baleia tem que estar verde).
2. Descompacte esta pasta num lugar fácil, por exemplo `C:\bd1`.

## Subir o banco

Abra o terminal **dentro desta pasta** (no Windows: clique com o botão direito na pasta → *Abrir no Terminal*) e rode:

```
docker compose up -d
```

Na primeira vez ele baixa o PostgreSQL e demora um pouco. Nas próximas, sobe em segundos.

Para conferir se está rodando:

```
docker ps
```

Tem que aparecer uma linha com `bd1_postgres` e o status `Up`.

## Conectar (DBeaver, pgAdmin, o que preferir)

| Campo | Valor |
|---|---|
| Host | `localhost` |
| Porta | `5433` |
| Usuário | `postgres` |
| Senha | `iesb2026` |
| Banco | `postgres` |

Repare: a porta é **5433**, e não a 5432 que aparece por padrão. Foi escolhida assim para não brigar com um PostgreSQL que você já tenha instalado no computador.

No DBeaver, marque **Show all databases** em Edit Connection → aba PostgreSQL.
Depois de criar um banco, use **Invalidate/Reconnect** para ele aparecer na árvore.

## Rodar os scripts

Estão na pasta `aulas/`, numerados na ordem em que são usados.

| Script | Conectado ao banco |
|---|---|
| `01_cria_bancos.sql` | `postgres`, e depois `db_biblioteca` |
| `02_carga_db_biblioteca.sql` | `db_biblioteca` |
| `03_Aula06_CRUD.sql` | `db_universidade` |
| `04_Aula06_exercicios.sql` | `db_universidade` |
| `06_Aula07_consultas.sql` | passa pelos três (`db_universidade`, `db_iesb`, `db_biblioteca`) |
| `07_Aula07_exercicios.sql` | `db_biblioteca` |
| `09_Aula08_views_triggers_procedures.sql` | `db_biblioteca` |
| `10_Aula08_exercicios.sql` | `db_biblioteca` |

A numeração pula o 05, o 08 e o 11: são os gabaritos, que ficam com o professor.

## Três avisos

**1. Trocar de banco.** Não existe `USE` no PostgreSQL. No DBeaver e no pgAdmin, troque o banco
no seletor do topo da janela. Todo script começa com:

```sql
SELECT current_database();
```

Rode essa linha primeiro. Se a resposta não for o banco escrito no cabeçalho do script, **pare e troque**.
As linhas `-- \c nome_do_banco` dos scripts estão comentadas de propósito: elas só funcionam no psql.

**2. `CREATE DATABASE cannot run inside a transaction block`** quer dizer que o DBeaver está
em **Manual**. Troque para **Auto** no alto da janela.

**3. Algumas linhas dão erro DE PROPÓSITO.** Elas estão marcadas no script com o aviso
`DÁ ERRO DE PROPÓSITO`. Leia a mensagem, ela faz parte da aula. Rode o resto normalmente.

## Deu problema?

| O que aparece | O que fazer |
|---|---|
| `docker: command not found` ou `cannot connect to the Docker daemon` | O Docker Desktop está fechado. Abra e espere a baleia ficar verde. |
| `port is already allocated` | Já tem algo usando a porta 5433. Rode `docker ps -a` e pare o outro container. |
| `password authentication failed` | A senha é `iesb2026`, tudo minúsculo. |
| `relation "obra" does not exist` | Você está no banco errado, ou não rodou o script 02. Rode `SELECT current_database();`. |
| `database "db_biblioteca" does not exist` | Você ainda não rodou o script 01. |

## Parar e zerar

Parar (os dados **ficam guardados**):

```
docker compose down
```

Zerar tudo (os dados **são apagados**):

```
docker compose down -v
docker compose up -d
```

Volta a ter só o banco `postgres`. Recomeça pelo script 01.
