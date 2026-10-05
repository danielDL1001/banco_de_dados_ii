# Ambiente da disciplina — Banco de Dados II (CCO072)

**IESB · 2026/2 · Prof. Rodrigo Gonçalves**

Este pacote sobe um **PostgreSQL 16** já com o banco `matricula` carregado e populado, pronto para as aulas práticas. A versão 16 foi escolhida para funcionar com o DBeaver dos laboratórios.

---

## Pré-requisito

Ter o **Docker Desktop** instalado (Windows, macOS ou Linux). Nada mais — o PostgreSQL e o pgAdmin vêm dentro dos contêineres.

---

## Subindo o ambiente

Dentro desta pasta, no terminal:

```bash
docker compose up -d
```

Na primeira vez, o Docker baixa as imagens e **carrega o banco automaticamente** (leva alguns minutos). Quando terminar:

| Serviço | Endereço | Credenciais |
|---|---|---|
| **PostgreSQL 16** | `localhost:5432` | usuário `bd2` · senha `bd2` · base `matricula` |
| **pgAdmin** | `http://localhost:8080` | login `admin@iesb.br` · senha `admin` |

Você pode usar o **DBeaver** (com os mesmos dados de conexão) ou o pgAdmin no navegador.

---

## Importante: as tabelas estão no schema `academico`

O banco não usa o schema padrão (`public`). Todas as tabelas estão em **`academico`**. Ao abrir o editor de SQL, comece sempre com:

```sql
SET search_path TO academico;
```

Depois disso, escreva os nomes normalmente:

```sql
SELECT * FROM aluno;
SELECT * FROM turma;
```

Sem essa linha, o banco procura no `public` (vazio) e diz que a tabela "não existe".

---

## Comandos do dia a dia

| Comando | O que faz |
|---|---|
| `docker compose up -d` | liga o ambiente |
| `docker compose down` | desliga, **mantendo** os dados |
| `docker compose down -v` | desliga e **apaga tudo** (recarrega o banco do zero) |
| `docker compose ps` | mostra se os serviços estão no ar |
| `docker compose logs -f` | acompanha a inicialização |

---

## Conectando pelo DBeaver

1. Nova conexão → PostgreSQL.
2. Host `localhost`, Port `5432`, Database `matricula`, Username `bd2`, Password `bd2`.
3. Em Test Connection, se pedir para baixar o driver, aceite.
4. Para não digitar o `SET search_path` toda vez, defina o schema padrão da conexão como `academico` (nas propriedades da conexão).

---

## Se algo der errado

| Sintoma | O que verificar |
|---|---|
| `port is already allocated` | outra coisa usa a porta 5432 ou 8080; feche-a ou ajuste a porta no `docker-compose.yml` |
| `relation "aluno" does not exist` | faltou `SET search_path TO academico;` no início |
| o banco parece vazio | espere a carga inicial terminar (`docker compose logs -f`); na 1ª subida demora |
| quero recomeçar limpo | `docker compose down -v` apaga e recarrega o banco do zero |
