"""
Driver auxiliar do marco02_transacoes_concorrencia.sql
-------------------------------------------------------
Abre conexões PostgreSQL INDEPENDENTES (processos/PIDs distintos) e executa, na ordem,
exatamente os comandos numerados do .sql, para gerar as evidências reais.
Uso:  pip install psycopg2-binary
      (executar antes as seções 1-9 do marco01 e as seções 3-4 do marco02 no banco)
      ajuste DSN abaixo;  python3 driver_concorrencia.py [anom dup lock ser dl stress]
Observação: o driver só apaga matrículas das turmas CONC-* que não sejam f1/f2.
"""
# Comandos SQL compartilhados: o MESMO texto vai para o .sql e é executado pelo driver.
EM = lambda k: f"conc_{k}@conc.invalid"
TURMA = lambda c: f"(SELECT id_turma FROM turma WHERE codigo = '{c}')"
ALUNO = lambda k: f"(SELECT id_aluno FROM aluno WHERE email = '{EM(k)}')"

def vagas(c):
    return (f"SELECT c.capacidade, count(m.id_matricula) AS matriculados,\n"
            f"       c.capacidade - count(m.id_matricula) AS vagas\n"
            f"  FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma\n"
            f"  LEFT JOIN matricula m ON m.id_turma = c.id_turma\n"
            f" WHERE t.codigo = '{c}' GROUP BY c.capacidade")

def lock(c):
    return (f"SELECT c.id_turma FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma\n"
            f" WHERE t.codigo = '{c}' FOR UPDATE OF c")

def ins(c,k):
    return (f"INSERT INTO matricula (id_aluno, id_turma, data_matricula, status)\n"
            f"SELECT a.id_aluno, t.id_turma, CURRENT_DATE, 'CONFIRMADA'\n"
            f"  FROM aluno a, turma t WHERE a.email = '{EM(k)}' AND t.codigo = '{c}'")

def reset(c):
    return (f"DELETE FROM matricula WHERE id_turma = {TURMA(c)}\n"
            f"   AND id_aluno NOT IN (SELECT id_aluno FROM aluno WHERE email LIKE 'conc\\_f%@conc.invalid')")

def estado(c):
    return (f"SELECT t.codigo, c.capacidade, count(m.id_matricula) AS matriculados,\n"
            f"       count(m.id_matricula) > c.capacidade AS excedeu\n"
            f"  FROM turma t JOIN turma_capacidade c ON c.id_turma = t.id_turma\n"
            f"  LEFT JOIN matricula m ON m.id_turma = t.id_turma\n"
            f" WHERE t.codigo = '{c}' GROUP BY t.codigo, c.capacidade")

BEGIN_RC  = "BEGIN"
BEGIN_SER = "BEGIN ISOLATION LEVEL SERIALIZABLE"

import psycopg2, threading, time, random, sys, json
DSN=dict(dbname='bd_ii_concorrencia', user='postgres', host='/var/run/postgresql')
T0=time.time()
OUT=[]
def log(s):
    line=f"[{time.time()-T0:7.3f}s] {s}"; OUT.append(line); print(line, flush=True)
def one(sql): return ' '.join(sql.split())
class S:
    def __init__(s,name):
        s.name=name; s.c=psycopg2.connect(**DSN); s.c.autocommit=True
        s.cur=s.c.cursor(); s.cur.execute("select pg_backend_pid()"); s.pid=s.cur.fetchone()[0]
        s.cur.execute("SET application_name = %s",('sessao_'+name,))
    def x(s,sql,quiet=False):
        try:
            s.cur.execute(sql)
            rows=s.cur.fetchall() if s.cur.description else None
            res=('ok',rows,None)
        except psycopg2.Error as e:
            res=('erro',None,(e.pgcode,str(e).strip().split('\n')[0]))
        if not quiet:
            r = res[1] if res[0]=='ok' else f"ERRO SQLSTATE {res[2][0]}: {res[2][2 -1]}"
            log(f"Sessão {s.name} (pid {s.pid}): {one(sql)}  ->  {r if r is not None else 'OK'}")
        return res
    def bg(s,sql):
        """executa em thread (comando que pode bloquear); retorna objeto com .join()"""
        box={}
        def run():
            t=time.time(); box['res']=s.x(sql); box['dur']=time.time()-t
        th=threading.Thread(target=run); th.start(); box['th']=th; return box
def waiting(obs,sess,timeout=3):
    """consulta (sessão observadora) se o backend está esperando por lock"""
    t=time.time()
    while time.time()-t<timeout:
        r=obs.x("select wait_event_type, wait_event, state from pg_stat_activity where pid=%d"%sess.pid,quiet=True)[1][0]
        if r[0]=='Lock': return r
        time.sleep(0.05)
    return r
def blockers(obs,sess):
    return obs.x("select pg_blocking_pids(%d)"%sess.pid,quiet=True)[1][0][0]

_rs=reset
def do_reset(obs,c): obs.x(_rs(c),quiet=True)

# ---------------------------------------------------------------- Exp 1: anomalia
def exp_anomalia(obs):
    c='CONC-ANOM'; do_reset(obs,c)
    log("=== EXP 1: ANOMALIA (READ COMMITTED, sem controle) ===")
    obs.x(estado(c))
    A,B=S('A'),S('B')
    A.x(BEGIN_RC); B.x(BEGIN_RC)
    A.x(vagas(c)); B.x(vagas(c))
    A.x(ins(c,'a'))
    b=B.bg(ins(c,'b')); b['th'].join(2)
    log(f"Sessão B: INSERT bloqueou? {'SIM' if b['th'].is_alive() else 'NAO (concluiu em %.3fs sem esperar)'%b['dur']}")
    A.x("COMMIT"); b['th'].join(); B.x("COMMIT")
    obs.x(estado(c)); r=obs.x(estado(c),quiet=True)[1][0]
    A.c.close(); B.c.close(); return r

def exp_dup(obs):
    c='CONC-ANOM'; do_reset(obs,c)
    log("=== EXP 1b: MESMO ALUNO nas duas sessões (papel do UNIQUE) ===")
    A,B=S('A'),S('B')
    A.x(BEGIN_RC); B.x(BEGIN_RC)
    A.x(ins(c,'a'))
    b=B.bg(ins(c,'a'))
    w=waiting(obs,B); log(f"Observadora: Sessão B -> wait_event_type={w[0]}, wait_event={w[1]}")
    A.x("COMMIT"); b['th'].join(); B.x("ROLLBACK")
    obs.x(estado(c)); A.c.close(); B.c.close(); do_reset(obs,c)

# ---------------------------------------------------------------- Exp 2: FOR UPDATE
def exp_lock(obs):
    c='CONC-LOCK'; do_reset(obs,c)
    log("=== EXP 2: BLOQUEIO EXPLICITO (SELECT ... FOR UPDATE OF turma_capacidade) ===")
    obs.x(estado(c))
    A,B=S('A'),S('B')
    A.x(BEGIN_RC); A.x(lock(c)); A.x(vagas(c))
    B.x(BEGIN_RC)
    b=B.bg(lock(c))
    w=waiting(obs,B); log(f"Observadora: Sessão B -> wait_event_type={w[0]}, wait_event={w[1]}; bloqueada por pid {blockers(obs,B)} (Sessão A pid {A.pid})")
    log('Sessão A: segura o lock por 1,5 s (simula processamento) antes de inserir e confirmar'); time.sleep(1.5)
    A.x(ins(c,'a')); A.x("COMMIT")
    b['th'].join(); log(f"Sessão B ficou bloqueada ~{b['dur']:.2f}s no FOR UPDATE e só obteve o lock após o COMMIT de A")
    r=B.x(vagas(c))[1][0]
    if r[2]<=0: log("Sessão B (aplicação): vagas = 0 -> turma cheia; não insere"); B.x("ROLLBACK")
    else: B.x(ins(c,'b')); B.x("COMMIT")
    obs.x(estado(c)); res=obs.x(estado(c),quiet=True)[1][0]
    A.c.close(); B.c.close(); return res

# ---------------------------------------------------------------- Exp 3: SERIALIZABLE
def exp_ser(obs):
    c='CONC-SER'; do_reset(obs,c)
    log("=== EXP 3: SERIALIZABLE ===")
    obs.x(estado(c))
    A,B=S('A'),S('B')
    A.x(BEGIN_SER); B.x(BEGIN_SER)
    A.x(vagas(c)); B.x(vagas(c))
    A.x(ins(c,'a'))
    rb=B.x(ins(c,'b'))
    ra=A.x("COMMIT")
    rb2=None
    if rb[0]=='ok': rb2=B.x("COMMIT")
    else: B.x("ROLLBACK")
    obs.x(estado(c)); res=obs.x(estado(c),quiet=True)[1][0]
    perdedora=None
    if rb[0]=='erro' or (rb2 and rb2[0]=='erro'): perdedora='B'
    elif ra[0]=='erro': perdedora='A'
    log(f"Perdedora (40001): {perdedora}")
    if perdedora:
        S_=B if perdedora=='B' else A; k='b' if perdedora=='B' else 'a'
        log(f"--- RETENTATIVA da Sessão {perdedora}: NOVA transação, repetindo leitura + decisão ---")
        S_.x(BEGIN_SER); r=S_.x(vagas(c))[1][0]
        if r[2]<=0: log(f"Sessão {perdedora} (aplicação): vagas = 0 -> turma cheia; não insere"); S_.x("ROLLBACK")
        else: S_.x(ins(c,k)); S_.x("COMMIT")
        obs.x(estado(c))
    A.c.close(); B.c.close(); return res

# ---------------------------------------------------------------- Exp 4: deadlock
def exp_deadlock(obs):
    log("=== EXP 4: DEADLOCK (40P01) com FOR UPDATE em ordem inconsistente ===")
    A,B=S('A'),S('B')
    A.x(BEGIN_RC); B.x(BEGIN_RC)
    A.x(lock('CONC-DL1')); B.x(lock('CONC-DL2'))
    a=A.bg(lock('CONC-DL2')); time.sleep(0.3)
    b=B.bg(lock('CONC-DL1'))
    a['th'].join(); b['th'].join()
    ra,rb=a['res'],b['res']
    log(f"Resultados: A={ra[0]} {ra[2]}; B={rb[0]} {rb[2]}")
    for s,r in ((A,ra),(B,rb)):
        s.x("ROLLBACK" if r[0]=='erro' else "COMMIT")
    A.c.close(); B.c.close()
    log("--- MITIGAÇÃO: ordem canônica (menor codigo/id primeiro) em ambas ---")
    A,B=S('A'),S('B')
    A.x(BEGIN_RC); B.x(BEGIN_RC)
    A.x(lock('CONC-DL1')); b=B.bg(lock('CONC-DL1')); w=waiting(obs,B)
    log(f"Observadora: Sessão B -> wait_event_type={w[0]}")
    A.x(lock('CONC-DL2')); A.x("COMMIT"); b['th'].join(); B.x(lock('CONC-DL2')); B.x("COMMIT")
    A.c.close(); B.c.close()

# ---------------------------------------------------------------- Exp 5: retentativa e contenção
STATS={}
def worker(strategy,c,k,barrier,out,max_tries=6):
    conn=psycopg2.connect(**DSN); conn.autocommit=True; cur=conn.cursor()
    def q(sql):
        cur.execute(sql); return cur.fetchall() if cur.description else None
    barrier.wait(); tent=0; err40001=0; err40p01=0; resultado=None
    while tent<max_tries:
        tent+=1
        try:
            if strategy=='lock':
                q("BEGIN"); q(lock(c))
            elif strategy=='ser':
                q(BEGIN_SER)
            else:
                q("BEGIN")
            v=q(vagas(c))[0][2]
            if v<=0:
                q("ROLLBACK"); resultado='TURMA_CHEIA'; break
            q(ins(c,k)); q("COMMIT"); resultado='MATRICULADO'; break
        except psycopg2.Error as e:
            try: q("ROLLBACK")
            except Exception: pass
            if e.pgcode=='40001': err40001+=1
            elif e.pgcode=='40P01': err40p01+=1
            else: resultado='ERRO_'+str(e.pgcode); break
            time.sleep(min(0.05*(2**(tent-1)),0.8)*(0.5+random.random()))   # backoff exponencial + jitter
    else:
        resultado='DESISTIU_APOS_%d_TENTATIVAS'%max_tries
    out.append((k,resultado,tent,err40001,err40p01)); conn.close()

def stress(obs,strategy,c,rounds=10,n=8):
    ks=[f"s{i:02d}" for i in range(1,n+1)]
    final=[]; agg=dict(matric=0,cheia=0,desist=0,e40001=0,e40p01=0,tent=0)
    for r in range(rounds):
        do_reset(obs,c)
        bar=threading.Barrier(n); out=[]
        ths=[threading.Thread(target=worker,args=(strategy,c,k,bar,out)) for k in ks]
        [t.start() for t in ths]; [t.join() for t in ths]
        res=obs.x(estado(c),quiet=True)[1][0]
        final.append(res[2])
        for k,rs,t,e1,e2 in out:
            agg['matric']+= rs=='MATRICULADO'; agg['cheia']+= rs=='TURMA_CHEIA'; agg['desist']+= rs.startswith('DESIST'); agg['e40001']+=e1; agg['e40p01']+=e2; agg['tent']+=t
    do_reset(obs,c)
    return dict(strategy=strategy,rounds=rounds,contenders=n,final_counts=final,
                rounds_overbooked=sum(1 for f in final if f>3),**agg)

if __name__=='__main__':
    obs=S('OBS')
    which=sys.argv[1:] or ['anom','dup','lock','ser','dl','stress']
    R={}
    if 'anom' in which: R['anom']=exp_anomalia(obs)
    if 'dup' in which: exp_dup(obs)
    if 'lock' in which: R['lock']=exp_lock(obs)
    if 'ser' in which: R['ser']=exp_ser(obs)
    if 'dl' in which: exp_deadlock(obs)
    if 'stress' in which:
        log("=== EXP 5: 8 sessões disputando 1 vaga (10 rodadas por estratégia; barreira de largada) ===")
        for st,c in (('anom','CONC-ANOM'),('lock','CONC-LOCK'),('ser','CONC-SER')):
            r=stress(obs,st,c); log("RESULTADO "+json.dumps(r)); R['stress_'+st]=r
    json.dump(R,open('driver_result.json','w'),default=str)
    open('driver_out_%s.log'%('_'.join(which)),'w').write('\n'.join(OUT))
