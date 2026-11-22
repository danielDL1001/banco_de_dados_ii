/*-------------------------------------------------------------------------------------------------------------------------
Disciplina: Banco de Dados I
Autor....: Prof. Rodrigo Gonçalves Pinto
Objetivo..: Exercícios da Aula 08 - Views, Triggers, Procedures e Functions
Objeto....: Aula08_exercicios.sql

Banco de dados: db_biblioteca
--------------------------------------------------------------------------------------------------------------------------
COMO FAZER:
 1) rode o script Aula08_views_triggers_procedures.sql inteiro antes de começar.
 2) escreva a sua resposta LOGO ABAIXO de cada enunciado.
 3) rode a sua resposta e confira o resultado.
 4) não apague o enunciado.

LEMBRE DAS DUAS REGRAS QUE MAIS DERRUBAM GENTE NESTA AULA:
 - o corpo de toda rotina vai entre $$ e $$. Não existe DELIMITER no PostgreSQL.
 - é ELSIF, e não ELSEIF.

TRAVOU? Todo exercício tem um exemplo parecido no 09_Aula08_views_triggers_procedures.sql.
O jeito mais fácil: COPIE o exemplo da aula, cole aqui e vá trocando os nomes.
--------------------------------------------------------------------------------------------------------------------------
*/

-- >>> TROQUE PARA O BANCO db_biblioteca no seletor do topo da janela <<<
-- a linha abaixo só funciona no psql. No DBeaver e no pgAdmin, deixe comentada.
-- \c db_biblioteca

SELECT current_database();
-- tem que responder: db_biblioteca. Se não respondeu, PARE e troque de banco.


/*------------------------------------------------------
BLOCO 1 - VIEWS
--------------------------------------------------------*/

-- [1.1] Crie uma view chamada vw_autores com id_autor, primeiro_nome e ultimo_nome,
--       trazendo também uma coluna nome_completo, com os dois nomes juntos.
-- DICA: seção VIEWS, a vw_idiomas. Para juntar os nomes, lembre do CONCAT da Aula 07
--       (e não esqueça o espaço no meio: ' ').
-- RESPOSTA:



-- [1.2] Consulte a view que você acabou de criar, trazendo só os autores cujo sobrenome
--       comece com a letra "S".
-- RESPOSTA:



-- [1.3] Crie uma view chamada vw_emprestimos_por_leitor com id_leitor, nome completo do leitor,
--       a quantidade de empréstimos e o valor total. Envolve JOIN e GROUP BY dentro da view.
-- RESPOSTA:



-- [1.4] Crie uma MATERIALIZED VIEW chamada mvw_obras_por_idioma com o nome do idioma e a
--       quantidade de obras. Depois consulte-a e dê um REFRESH nela.
-- RESPOSTA:



-- [1.5] CONCEITO. Em um comentário, responda: qual a diferença entre a view do item 1.3 e a
--       materialized view do item 1.4? Em que situação cada uma é a escolha certa?
-- RESPOSTA:




/*------------------------------------------------------
BLOCO 2 - TRIGGERS
--------------------------------------------------------*/

-- [2.1] Crie a FUNÇÃO fn_valida_custo_obra, que impede gravar obra com custo_reposicao
--       negativo. A mensagem de erro deve ser: 'custo de reposição não pode ser negativo'.
-- DICA: copie a fn_valida_idioma da aula. Troque o nome e troque o teste do IF:
--       em vez de NEW.nome = '', o teste agora é sobre NEW.custo_reposicao.
-- RESPOSTA:



-- [2.2] Crie a TRIGGER trg_valida_custo_obra, que chama a função acima ANTES de todo
--       INSERT e de todo UPDATE na tabela obra.
-- DICA: igual à trg_before_idioma_insert da aula. Para valer nos dois eventos, escreva:
--       BEFORE INSERT OR UPDATE ON obra
-- RESPOSTA:



-- [2.3] Teste a sua trigger de duas formas: um INSERT com custo negativo (tem que dar erro)
--       e um INSERT com custo válido (tem que passar). Apague depois a obra de teste.
-- DICA: a tabela obra só exige o titulo. Basta:  INSERT INTO obra (titulo, custo_reposicao) VALUES (...);
-- RESPOSTA:



-- [2.4] DESAFIO. Crie uma tabela de auditoria chamada tb_log_idioma com as colunas
--       id_log, id_idioma, nome_gravado e data_hora. Depois crie uma trigger AFTER INSERT
--       na tabela idioma que grave uma linha nessa tabela a cada idioma novo cadastrado.
--       Teste cadastrando um idioma e conferindo o log.
-- DICA: dentro da função, grave com  INSERT INTO tb_log_idioma (...) VALUES (NEW.id_idioma, NEW.nome, now());
--       e para data_hora use o tipo TIMESTAMP.
-- RESPOSTA:



-- [2.5] CONCEITO. Por que a trigger do item 2.4 é AFTER e não BEFORE?
--       Responda em uma linha, dentro de um comentário.
-- RESPOSTA:




/*------------------------------------------------------
BLOCO 3 - PROCEDURES
--------------------------------------------------------*/

-- [3.1] Crie a procedure stp_cadastra_area, que recebe o nome de uma área e a cadastra
--       na tabela area. Se a área já existir, apenas avise com RAISE NOTICE e não cadastre.
-- DICA: é a segunda versão da stp_adiciona_novo_idioma da aula, a "melhorada", com IF EXISTS.
-- RESPOSTA:



-- [3.2] Chame a sua procedure duas vezes com o mesmo nome e mostre que na segunda vez
--       ela avisa em vez de duplicar.
-- RESPOSTA:



-- [3.3] Crie a procedure stp_reajusta_custo, que recebe o id de uma área e um percentual,
--       e aplica esse percentual ao custo_reposicao de todas as obras daquela área.
--       Ao final, avise com RAISE NOTICE quantas obras foram alteradas.
--       DICA: dentro do plpgsql existe a variável especial ROW_COUNT, lida com GET DIAGNOSTICS.
--       Fica assim, logo depois do UPDATE:   GET DIAGNOSTICS v_quantidade = ROW_COUNT;
--       (declare antes a variável v_quantidade INT no DECLARE)
--       DICA 2: um aumento de 10% é multiplicar por 1.10. Com o percentual num parâmetro p_percentual:
--               custo_reposicao * (1 + p_percentual / 100.0)
--       DICA 3: a tabela obra não tem id_area. Para achar as obras da área, use
--               WHERE id_obra IN (SELECT id_obra FROM obra_area WHERE id_area = p_id_area)
-- RESPOSTA:



-- [3.4] Liste todas as procedures e functions que existem hoje no schema public.
-- RESPOSTA:




/*------------------------------------------------------
BLOCO 4 - FUNCTIONS
--------------------------------------------------------*/

-- [4.1] Crie a função fn_conta_obras_da_area, que recebe o id de uma área e devolve
--       a quantidade de obras dela.
-- DICA: copie a fn_pega_total_emprestimos_por_leitor da aula. Troque o SUM por COUNT,
--       a tabela emprestimo por obra_area, e o tipo de retorno para INT.
-- RESPOSTA:



-- [4.2] Use a função acima dentro de um SELECT sobre a tabela area, mostrando o nome da
--       área e a quantidade de obras, ordenado da que tem mais para a que tem menos.
-- RESPOSTA:



-- [4.3] Crie a função fn_classifica_duracao, que recebe uma duração em minutos e devolve
--       o texto 'curta' (menos de 90), 'média' (de 90 a 140) ou 'longa' (acima de 140).
--       Trate o nulo devolvendo 'não informada'.
-- DICA: é a fn_faixa_de_custo da aula, com outros cortes. Cuidado: 90 e 140 são 'média'.
-- RESPOSTA:



-- [4.4] Use a função do item 4.3 para agrupar: quantas obras existem em cada faixa de duração?
-- RESPOSTA:



-- [4.5] Crie a função fn_obras_da_area que recebe o id de uma área e devolve uma TABELA
--       com id_obra e titulo. Chame-a com SELECT * FROM.
-- DICA: é a fn_primeiras_obras da aula. Lembre do O. na frente das colunas, para não dar "ambiguous".
-- RESPOSTA:



-- [4.6] CONCEITO. Em um comentário, explique quando você usaria PROCEDURE e quando usaria
--       FUNCTION. Cite as duas diferenças que vimos em aula.
-- RESPOSTA:




/*------------------------------------------------------
BLOCO 5 - FLUXO: IF, CASE e LOOP
--------------------------------------------------------*/

-- [5.1] Escreva um bloco DO que conte de 1 a 5 e escreva na tela, com RAISE NOTICE,
--       se o número é par ou ímpar.
--       DICA: use MOD ou o operador %.
-- RESPOSTA:



-- [5.2] Escreva um bloco DO que percorra as 5 primeiras áreas e escreva na tela
--       o nome de cada uma. Use FOR ... IN SELECT.
-- RESPOSTA:



-- [5.3] Sem usar function nenhuma, escreva um SELECT com CASE WHEN que classifique as
--       obras em 'barata', 'média' e 'cara' pelo custo_reposicao, usando os mesmos cortes
--       da função fn_faixa_de_custo da aula.
-- RESPOSTA:



-- [5.4] Conte, em UMA única consulta e em UMA única passada pela tabela obra, quantas obras
--       são de classificação 'L' e quantas são '18'. Faça das duas formas: com FILTER
--       e com SUM(CASE WHEN ...).
-- RESPOSTA:



-- [5.5] DESAFIO. Escreva uma procedure stp_relatorio_areas que percorra todas as áreas com
--       um FOR e escreva na tela, para cada uma, o nome e a quantidade de obras, pulando
--       as áreas que não têm obra nenhuma.
--       (o Acervo Raro, criado na Aula 07, é a área sem obra: ele NÃO pode aparecer.)
-- DICA: dentro do FOR, use a sua fn_conta_obras_da_area do item 4.1 e um IF.
-- RESPOSTA:


/*
FIM DOS EXERCÍCIOS DA AULA 8
*/
