# Relatório técnico — Transações e concorrência: disputa pela última vaga (PostgreSQL)

**Entrega:** `marco02_transacoes_concorrencia.sql` (principal) · `driver_concorrencia.py` (auxiliar, gera as evidências) · este relatório.
**Referência:** `marco01.sql` = `modelo_fisico_postgresql.sql` (etapa anterior; não foi modificado).
**Ambiente das evidências:** PostgreSQL 16.15 (Ubuntu), 1 vCPU, 4 GB RAM, `read committed` (padrão), `deadlock_timeout` = 1 s, tabelas pequenas. Todas as sessões foram conexões independentes (PIDs distintos) conduzidas na ordem do roteiro numerado.

> **Legenda de honestidade:** **[T]** = comportamento teórico/documentado; **[O]** = observado nos experimentos; **[A]** = depende do ambiente/carga e **não foi medido**. Não há medição de throughput ou latência neste trabalho.

---

## 1. Resumo do cenário

Uma turma tem capacidade N = 3 e 2 matrículas confirmadas (N−1): resta **1 vaga**. A transação da Sessão A matricula o aluno `a`; a da Sessão B, o aluno `b`. Ambas seguem o padrão leitura-modificação-escrita: lê as vagas → a aplicação decide (`vagas > 0`) → `INSERT` em `matricula`.

### Limitação do modelo (identificada antes do SQL)
O `marco01` **não tem capacidade nem contador de vagas** em `turma`; `sala.capacidade` existe, mas não há relacionamento turma↔sala, então a capacidade não é derivável. Foi criada **uma única estrutura auxiliar, isolada**:

```sql
turma_capacidade (id_turma PK/FK -> turma, capacidade smallint NOT NULL CHECK (capacidade > 0))
```

A ocupação **não** é armazenada: é calculada com `count(*)` em `matricula` (evita contador redundante que poderia divergir). Nenhuma tabela, FK, UNIQUE ou índice do modelo foi alterado ou removido.

### Decisões assumidas
* **D1.** "Matrículas confirmadas" = todas as linhas de `matricula` da turma, porque o modelo não define os valores de `status`.
* **D2.** Dados de teste marcados (`CONC-…`, `conc_…@conc.invalid`); preparação e limpeza só tocam esses marcadores (validado: linhas preexistentes inseridas antes permaneceram intactas após a limpeza).
* **D3.** A regra de capacidade é imposta pelo **protocolo transacional**, não por constraint. Uma garantia estrutural exigiria um `TRIGGER` em `matricula` (alteração do modelo), **não criado sem sua autorização**.

---

## 2. Explicação da anomalia

Em `READ COMMITTED`, cada comando vê apenas dados já confirmados. A leitura de B não enxerga o `INSERT` ainda não confirmado de A: **ambas leem `vagas = 1`**. Como `a` e `b` são alunos **diferentes**, o `UNIQUE (id_aluno, id_turma)` não entra em ação, e nenhuma PK/FK limita quantas linhas uma turma pode ter. O `INSERT` de B **não espera nem falha**.

* **Execução sequencial** (A termina, depois B): B lê `vagas = 0` e não insere — correto.
* **Execução concorrente** (ambas leem antes do primeiro COMMIT): as duas decidem inserir.
* **O que o PostgreSQL garante** em `READ COMMITTED`: sem leitura suja e snapshot consistente *por comando*. **Não** garante que uma decisão baseada numa leitura continue válida na hora da escrita.

**Papel do UNIQUE (não removido):** na variante com o *mesmo* aluno nas duas sessões, o `INSERT` de B espera A e, após o COMMIT de A, falha com `23505`. O UNIQUE evita *duplicidade*, não *excesso de capacidade*.

### Evidência observada — Experimento 1 (anomalia)
```
t= 0.005s  === EXP 1: ANOMALIA (READ COMMITTED, sem controle) ===
t= 0.006s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-ANOM', 3, 2, False)]
t= 0.010s  Sessão A (pid 1728)  BEGIN  =>  OK
t= 0.010s  Sessão B (pid 1729)  BEGIN  =>  OK
t= 0.012s  Sessão A (pid 1728)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 2, 1)]
t= 0.013s  Sessão B (pid 1729)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 2, 1)]
t= 0.014s  Sessão A (pid 1728)  INSERT matricula [aluno a, CONC-ANOM]  =>  OK
t= 0.015s  Sessão B (pid 1729)  INSERT matricula [aluno b, CONC-ANOM]  =>  OK
t= 0.015s  Sessão B: INSERT bloqueou? NAO (concluiu em 0.001s sem esperar)
t= 0.016s  Sessão A (pid 1728)  COMMIT  =>  OK
t= 0.016s  Sessão B (pid 1729)  COMMIT  =>  OK
t= 0.016s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-ANOM', 3, 4, True)]
```

Resultado: **4 matrículas numa turma de capacidade 3** (`excedeu = True`); o `INSERT` de B concluiu em ~1 ms, sem esperar.

### Evidência observada — Experimento 1b (mesmo aluno; UNIQUE)
```
t= 0.020s  === EXP 1b: MESMO ALUNO nas duas sessões (papel do UNIQUE) ===
t= 0.024s  Sessão A (pid 1731)  BEGIN  =>  OK
t= 0.024s  Sessão B (pid 1732)  BEGIN  =>  OK
t= 0.025s  Sessão A (pid 1731)  INSERT matricula [aluno a, CONC-ANOM]  =>  OK
t= 0.078s  Observadora: Sessão B -> wait_event_type=Lock, wait_event=transactionid
t= 0.079s  Sessão A (pid 1731)  COMMIT  =>  OK
t= 0.079s  Sessão B (pid 1732)  INSERT matricula [aluno a, CONC-ANOM]  =>  ERRO SQLSTATE 23505: duplicate key value violates unique constraint "uq_matricula_aluno_turma"
t= 0.079s  Sessão B (pid 1732)  ROLLBACK  =>  OK
t= 0.079s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-ANOM', 3, 3, False)]
```


---

## 3. Correção 1 — Bloqueio explícito (`SELECT … FOR UPDATE`)

```sql
BEGIN;
SELECT c.id_turma FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
 WHERE t.codigo = 'CONC-LOCK' FOR UPDATE OF c;     -- 1) trava a linha da capacidade
-- 2) SÓ DEPOIS do lock: ler vagas (comando novo = snapshot novo)
-- 3) se vagas > 0: INSERT em matricula;  4) COMMIT   (senão ROLLBACK)
```

| Pergunta | Resposta |
|---|---|
| **Qual registro é bloqueado?** | A linha de `turma_capacidade` da turma disputada (`FOR UPDATE OF c`). Outras turmas não são afetadas. |
| **Por que não a linha de `turma`?** | O `INSERT` em `matricula` adquire `FOR KEY SHARE` na linha de `turma` (checagem da FK); um `FOR UPDATE` em `turma` conflitaria com matrículas legítimas e outros usos da turma. [T] Alternativa: `FOR NO KEY UPDATE` em `turma`. |
| **Por que não bloquear linhas de `matricula`?** | O conflito envolve linha que **ainda não existe**; `FOR UPDATE` não bloqueia "fantasmas". |
| **Quando o lock é adquirido?** | Quando o `SELECT … FOR UPDATE` retorna (passo 2). |
| **Quando é liberado?** | No COMMIT/ROLLBACK; locks de linha só caem no fim da transação. [T] |
| **O que B faz?** | Fica em espera (`wait_event_type = Lock`) até A terminar; depois obtém o lock, **relê** a disponibilidade (comando novo, enxerga a matrícula confirmada de A) e vê `vagas = 0`. |
| **Por que impede o excesso?** | "Ler vagas + inserir" vira seção crítica por turma. |

**Limitações:** (1) só protege quem segue o protocolo (inserção direta em `matricula` não é barrada); (2) cria fila — o tempo de espera de B é o tempo que A segura o lock; (3) locks em ordem inconsistente entre turmas geram deadlock (seção 6).

### Evidência observada — Experimento 2
```
t= 0.084s  === EXP 2: BLOQUEIO EXPLICITO (SELECT ... FOR UPDATE OF turma_capacidade) ===
t= 0.085s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-LOCK', 3, 2, False)]
t= 0.089s  Sessão A (pid 1734)  BEGIN  =>  OK
t= 0.090s  Sessão A (pid 1734)  SELECT ... FOR UPDATE OF c  [CONC-LOCK]  =>  [(2,)]
t= 0.090s  Sessão A (pid 1734)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 2, 1)]
t= 0.090s  Sessão B (pid 1735)  BEGIN  =>  OK
t= 0.092s  Observadora: Sessão B -> wait_event_type=Lock, wait_event=transactionid; bloqueada por pid [1734] (Sessão A pid 1734)
t= 0.092s  Sessão A: segura o lock por 1,5 s (simula processamento) antes de inserir e confirmar
t= 1.593s  Sessão A (pid 1734)  INSERT matricula [aluno a, CONC-LOCK]  =>  OK
t= 1.594s  Sessão A (pid 1734)  COMMIT  =>  OK
t= 1.594s  Sessão B (pid 1735)  SELECT ... FOR UPDATE OF c  [CONC-LOCK]  =>  [(2,)]
t= 1.594s  Sessão B ficou bloqueada ~1.50s no FOR UPDATE e só obteve o lock após o COMMIT de A
t= 1.595s  Sessão B (pid 1735)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 3, 0)]
t= 1.595s  Sessão B (aplicação): vagas = 0 -> turma cheia; não insere
t= 1.595s  Sessão B (pid 1735)  ROLLBACK  =>  OK
t= 1.595s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-LOCK', 3, 3, False)]
```

B ficou bloqueada (por Lock, pelo PID de A) ~1,5 s — exatamente o tempo em que A segurou o lock —, obteve o lock após o COMMIT de A, viu `vagas = 0` e fez ROLLBACK. Estado final: 3 matrículas.

---

## 4. Correção 2 — `SERIALIZABLE` (SSI)

Mesma lógica, sem lock explícito, em `BEGIN ISOLATION LEVEL SERIALIZABLE`.

**Como o PostgreSQL detecta o problema [T]:** cada transação trabalha sobre um snapshot e registra o que leu em *predicate locks* (SIREAD), que **não bloqueiam ninguém**. Quando uma escreve o que a outra leu, forma-se uma dependência rw. Duas transações que leram `vagas = 1` e depois escreveram formam um ciclo (*write skew*): o PostgreSQL **aborta uma** com `SQLSTATE 40001`, no `INSERT` ou no `COMMIT`. A abortada deve ser **reexecutada inteira** (nova transação, relendo as vagas).

Diferenças que o enunciado pede:

| Conceito | O que é |
|---|---|
| Bloqueio explícito | **Espera** por lock de linha |
| Detecção de conflito (SSI) | Rastreamento de dependências rw, sem esperar |
| Aborto | `ROLLBACK` forçado pelo servidor (`40001`) |
| Retentativa | Responsabilidade da **aplicação** |

> SERIALIZABLE **não** garante sucesso de todas as transações, **não** bloqueia todas e pode produzir **falsos positivos** (abortos desnecessários, p.ex. por granularidade de predicate lock) [T].

### Evidência observada — Experimento 3
```
t= 1.599s  === EXP 3: SERIALIZABLE ===
t= 1.600s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-SER', 3, 2, False)]
t= 1.604s  Sessão A (pid 1737)  BEGIN ISOLATION LEVEL SERIALIZABLE  =>  OK
t= 1.604s  Sessão B (pid 1738)  BEGIN ISOLATION LEVEL SERIALIZABLE  =>  OK
t= 1.605s  Sessão A (pid 1737)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 2, 1)]
t= 1.607s  Sessão B (pid 1738)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 2, 1)]
t= 1.607s  Sessão A (pid 1737)  INSERT matricula [aluno a, CONC-SER]  =>  OK
t= 1.608s  Sessão B (pid 1738)  INSERT matricula [aluno b, CONC-SER]  =>  OK
t= 1.608s  Sessão A (pid 1737)  COMMIT  =>  OK
t= 1.608s  Sessão B (pid 1738)  COMMIT  =>  ERRO SQLSTATE 40001: could not serialize access due to read/write dependencies among transactions
t= 1.609s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-SER', 3, 3, False)]
t= 1.609s  Perdedora (40001): B
t= 1.609s  --- RETENTATIVA da Sessão B: NOVA transação, repetindo leitura + decisão ---
t= 1.609s  Sessão B (pid 1738)  BEGIN ISOLATION LEVEL SERIALIZABLE  =>  OK
t= 1.609s  Sessão B (pid 1738)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 3, 0)]
t= 1.609s  Sessão B (aplicação): vagas = 0 -> turma cheia; não insere
t= 1.609s  Sessão B (pid 1738)  ROLLBACK  =>  OK
t= 1.610s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-SER', 3, 3, False)]
```

Os dois `INSERT` ocorreram em paralelo sem espera; A confirmou; **o COMMIT de B foi abortado com 40001**. Na retentativa (nova transação), B leu `vagas = 0` e recusou. Em 3 execuções adicionais a perdedora foi sempre B, no COMMIT — [O] neste ambiente; **qual** transação perde não é garantido.

---

## 5. Contenção e retentativa — 8 sessões disputando 1 vaga (10 rodadas por estratégia)

Cada rodada: turma com 2/3 ocupadas; 8 sessões largam juntas (barreira). A estratégia com retentativa usa **máx. 6 tentativas**, backoff exponencial `min(0,05·2ⁿ⁻¹; 0,8) s × (0,5 + aleatório)`.

```
anom  sobrelotadas=10/10  contagem_final=[10]  matriculados=80  turma_cheia=0  desistencias=0  erros_40001=0  erros_40P01=0  tentativas_totais=80
lock  sobrelotadas=0/10  contagem_final=[3]  matriculados=10  turma_cheia=70  desistencias=0  erros_40001=0  erros_40P01=0  tentativas_totais=80
ser   sobrelotadas=0/10  contagem_final=[3]  matriculados=10  turma_cheia=70  desistencias=0  erros_40001=70  erros_40P01=0  tentativas_totais=150
```

| Estratégia | Observado |
|---|---|
| **Sem controle** | Turma sobrelotada em **todas** as rodadas (ex.: 10 matrículas em capacidade 3). Em outra execução, uma sessão chegou tarde e viu "turma cheia": a quantidade varia, a violação não. |
| **FOR UPDATE** | Contagem final **sempre 3**; **0** erros; 70 sessões viram "turma cheia" (a espera individual não foi medida). |
| **SERIALIZABLE** | Contagem final **sempre 3**; **70** erros `40001` (7 de 8 sessões por rodada falharam na 1ª tentativa), todos resolvidos por retentativa (nenhuma desistiu); 150 tentativas totais para 80 operações. |

Estabilidade: o teste de estresse foi executado 4 vezes; as contagens finais 3 (lock/ser) e os 70 `40001` se repetiram; o sem-controle ficou sempre acima de 3.
**[A]** Essas contagens valem para este ambiente (1 vCPU, 8 sessões, tabela mínima). **Não são medida de desempenho** e não se extrapolam.

---

## 6. Tratamento de erros e retentativas

| SQLSTATE | Significado | Ação |
|---|---|---|
| `40001` | `serialization_failure` | ROLLBACK + **reexecutar a operação completa** em nova transação |
| `40P01` | `deadlock_detected` | ROLLBACK + reexecutar a operação completa |
| `23505` | `unique_violation` | Erro de **negócio** (já matriculado): não retentar |

* Retentativa = nova transação **repetindo todas as leituras e decisões**; repetir só o comando que falhou é incorreto.
* Limite de tentativas e backoff com jitter; nunca laço infinito. A retentativa deve estar no **cliente**: um bloco `EXCEPTION` em PL/pgSQL usa subtransação e manteria o mesmo snapshot SERIALIZABLE.
* Com bloqueio explícito a concorrência normalmente se resolve por **espera**, mas ainda há `40P01`, timeouts (`lock_timeout`) e falhas de conexão.
* SERIALIZABLE **exige** tratamento de `40001` sempre.

### Deadlock com a Correção 1 — Experimento 4
Duas transações travando as linhas de duas turmas em ordem inversa:
```
t= 1.610s  === EXP 4: DEADLOCK (40P01) com FOR UPDATE em ordem inconsistente ===
t= 1.616s  Sessão A (pid 1739)  BEGIN  =>  OK
t= 1.616s  Sessão B (pid 1740)  BEGIN  =>  OK
t= 1.617s  Sessão A (pid 1739)  SELECT ... FOR UPDATE OF c  [CONC-DL1]  =>  [(1,)]
t= 1.618s  Sessão B (pid 1740)  SELECT ... FOR UPDATE OF c  [CONC-DL2]  =>  [(4,)]
t= 2.618s  Sessão A (pid 1739)  SELECT ... FOR UPDATE OF c  [CONC-DL2]  =>  ERRO SQLSTATE 40P01: deadlock detected
t= 2.619s  Sessão B (pid 1740)  SELECT ... FOR UPDATE OF c  [CONC-DL1]  =>  [(1,)]
t= 2.619s  Resultados: A=erro ('40P01', 'deadlock detected'); B=ok None
t= 2.619s  Sessão A (pid 1739)  ROLLBACK  =>  OK
t= 2.620s  Sessão B (pid 1740)  COMMIT  =>  OK
t= 2.620s  --- MITIGAÇÃO: ordem canônica (menor codigo/id primeiro) em ambas ---
t= 2.627s  Sessão A (pid 1743)  BEGIN  =>  OK
t= 2.627s  Sessão B (pid 1744)  BEGIN  =>  OK
t= 2.629s  Sessão A (pid 1743)  SELECT ... FOR UPDATE OF c  [CONC-DL1]  =>  [(1,)]
t= 2.682s  Observadora: Sessão B -> wait_event_type=Lock
t= 2.682s  Sessão A (pid 1743)  SELECT ... FOR UPDATE OF c  [CONC-DL2]  =>  [(4,)]
t= 2.683s  Sessão B (pid 1744)  SELECT ... FOR UPDATE OF c  [CONC-DL1]  =>  [(1,)]
t= 2.683s  Sessão A (pid 1743)  COMMIT  =>  OK
t= 2.683s  Sessão B (pid 1744)  SELECT ... FOR UPDATE OF c  [CONC-DL2]  =>  [(4,)]
t= 2.683s  Sessão B (pid 1744)  COMMIT  =>  OK
```

Após ~1 s (`deadlock_timeout`) uma sessão recebeu `40P01`; a outra prosseguiu. **Mitigação observada:** ordem canônica de lock nas duas sessões → B apenas esperou, sem deadlock.

---

## 7. Comparação entre as abordagens

[T] teórico · [O] observado · [A] depende do ambiente (não medido).

| Critério | Bloqueio explícito (`FOR UPDATE`) | SERIALIZABLE (SSI) |
|---|---|---|
| Mecanismo de proteção | [T] Lock de linha em `turma_capacidade` cria seção crítica | [T] Snapshot + predicate locks (SIREAD) + detecção de ciclos rw |
| Controle da concorrência | [T] Pessimista: serializa quem disputa o recurso | [T] Otimista: executa em paralelo e aborta conflito |
| Garantia de integridade | [T] Só para quem segue o protocolo | [T] Para toda transação SERIALIZABLE, sem escolher o recurso |
| Contenção | [T] Fila por turma; só a turma disputada é afetada | [T] Sem filas por leitura; contenção vira abortos/retrabalho |
| Possibilidade de bloqueio | [O] Sim (B esperou ~1,5 s) | [O] Não houve espera por lock neste cenário |
| Possibilidade de abortar | [T] Baixa; [O] `40P01` com ordem inconsistente | [T] Inerente (`40001`), inclusive falso positivo; [O] 70 em 80 operações no estresse |
| Necessidade de retentativa | [T] Só `40P01`/timeouts; [O] nenhuma no estresse | [T] Obrigatória; [O] 70 retentativas no estresse |
| Custo operacional | [T] Lock de linha barato; risco ao segurar lock durante processamento longo [A] | [T] Memória/CPU de predicate locks e do grafo de conflitos; retrabalho das abortadas [A] |
| Escalabilidade | [T] Boa se o lock for por recurso e curto; ruim em linha muito disputada [A] | [T] Boa com pouco conflito; piora com muito conflito e com limites de predicate locks [A] |
| Complexidade de implementação | [T] Média: lock antes de ler, ordem canônica, `lock_timeout` | [T] Baixa na SQL, mas laço de retentativa obrigatório e lógica reexecutável |
| Adequação ao cenário | Recurso disputado bem identificável (a turma); operações curtas | Invariantes sobre várias linhas/predicados difíceis de travar; contenção baixa/média |

**Custo.** *Bloqueio:* sobrecarga pequena por lock de linha; o custo real é a **espera** (latência de B ≈ tempo de A com o lock) e o limite de concorrência naquela turma. *SERIALIZABLE:* custo de manter predicate locks/dependências e de **refazer** transações abortadas; efeito em throughput/latência **[A]**, não medido.
**Contenção.** Bloqueio: transações esperam quando disputam o mesmo lock. SSI: não esperam por leitura; conflitos viram `40001`; granularidade (página/relação) pode ampliar falsos positivos.
**Retentativa.** Esperar um lock **não** exige reexecução; receber `40001` **exige**, e a responsabilidade é da aplicação.

**Não há abordagem universalmente superior:** o bloqueio troca *aborts* por *espera* e exige conhecer o recurso correto; SERIALIZABLE troca *espera* por *aborts* e exige retentativa, mas protege sem identificar o recurso. Ambas exigem transações curtas e bem delimitadas.

---

## 8. Integridade final

Verificações do arquivo (seção 11): matrículas por turma × capacidade; excedentes; duplicidade; órfãs; transações abertas. **Observado** ao final: nenhuma turma acima da capacidade, nenhuma duplicidade (UNIQUE), nenhuma matrícula órfã (FKs) e nenhuma transação aberta. Estado logo após cada experimento: **ANOM = 4 (violação)**, LOCK = 3, SER = 3. Rollback de transações incompletas é demonstrado nos experimentos 1b, 2, 3 e 4.

---

## 9. Validação final (checklist)

| Item | Status |
|---|---|
| Usa estruturas reais do `marco01` | Sim (`turma`, `matricula`, `uq_matricula_aluno_turma`, FKs); limitação da capacidade documentada |
| Anomalia com duas sessões independentes | Sim — [O], PIDs distintos, sem execução sequencial disfarçada |
| Duas soluções distintas, bloco por bloco, sem misturar transações | Sim (turmas separadas por experimento) |
| Lock no recurso correto | Sim — `turma_capacidade` da turma (`FOR UPDATE OF c`), justificado |
| SERIALIZABLE com tratamento de `40001` e retentativa | Sim (experimento 3 e estresse) |
| Capacidade preservada | Sim — [O] 3/3 nas duas correções |
| Restrições do `marco01` preservadas | Sim; nada removido |
| Dados preexistentes preservados | Sim — testado: linhas reais permaneceram após preparação + limpeza |
| Arquivo executável | Seções 3, 4, 11 e 14 executaram sem erros via `psql -f`; roteiros usam o mesmo texto SQL executado pelo driver |
| Sem resultados inventados | Sim — [O] vêm de execução real; [T]/[A] marcados |

## 10. Limitações e pendências

* **Capacidade** só existe na tabela auxiliar; **pendência de decisão:** se o modelo ganhar capacidade em `turma` (ou relação turma↔sala), a tabela auxiliar pode ser removida.
* **Garantia estrutural:** sem `TRIGGER`/constraint, a regra depende do protocolo. Um trigger `BEFORE INSERT` em `matricula` que tome o lock de `turma_capacidade` tornaria a regra inevitável — **não implementado sem autorização**.
* `status` de matrícula sem domínio: a contagem considera todas as linhas.
* Ambiente pequeno (1 vCPU, tabelas mínimas): falsos positivos de SSI, uso de memória de predicate locks, throughput e latência **não foram medidos**; repetir em ambiente representativo.
* O vencedor do conflito SERIALIZABLE (quem recebe `40001`) e o ponto do erro (INSERT ou COMMIT) **não são garantidos**; só o invariante (≤ capacidade) é.
