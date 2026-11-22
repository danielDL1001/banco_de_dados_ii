# Banco de Dados II — Marco 1

## Arquivos
- `01_ddl.sql`: tipos, domínios, tabelas, chaves, FKs, UNIQUEs e restrições de integridade.
- `02_carga_dados.sql`: carga mínima de 100 alunos, 8 turmas e 300 matrículas.
- `03_consultas_marco1.sql`: 10 consultas comentadas de complexidade crescente.
- `AUTORES.md`: divisão de responsabilidades do trio.

## Execução

No PostgreSQL, em uma sessão limpa:

```sql
\i 01_ddl.sql
\i 02_carga_dados.sql
\i 03_consultas_marco1.sql
```

Ou, pelo terminal `psql`, execute os três arquivos nesta ordem.

## Conferência do Marco 1
- DDL completo: incluído.
- Carga: 100 alunos, 8 turmas e 300 matrículas.
- 10 consultas: incluídas.
- LEFT JOIN + agregação: Q02.
- Recursiva — árvore de pré-requisitos: Q06.
- Recursiva — disciplinas que o aluno pode cursar: Q07.
- Ranking + percentil: Q08.
- LAG para evolução: Q09.
- `04_verificacao.sql`: contagens para comprovar os mínimos do Marco 1.

## Observação
O arquivo original do projeto continha scripts de outras etapas e um DDL diferente do modelo de referência. Esta pasta do Marco 1 foi organizada para usar o modelo de referência fornecido no próprio projeto, evitando incompatibilidade entre nomes de colunas, esquema e consultas.
