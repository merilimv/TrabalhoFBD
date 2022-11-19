-- adicionar aluno
CREATE OR REPLACE FUNCTION add_aluno() RETURNS TRIGGER 
AS
$BODY$
BEGIN
    IF ((NEW.id_disc, NEW.id_turma) not in (select disciplina_id, id from turma)) 
    THEN RAISE EXCEPTION 'Turma Não Existe';
    ELSE
      UPDATE turma t
      SET qnt_alunos = (t.qnt_alunos + 1)
      FROM aluno_turma_disc a WHERE (t.id = NEW.id_turma);
      RETURN NEW;
    END IF;
END;
$BODY$
LANGUAGE plpgsql;

CREATE TRIGGER T_ADDALUNO
AFTER INSERT ON aluno_turma_disc
FOR EACH ROW
EXECUTE PROCEDURE add_aluno();

-- quando a turma eh atualizada
CREATE OR REPLACE FUNCTION update_turma() RETURNS TRIGGER 
AS
$BODY$
BEGIN
    IF NEW.vagas < NEW.qnt_alunos OR NEW.qnt_alunos < 0
    THEN RAISE EXCEPTION 'limite da turma atingido.';
    ELSE
        RETURN NEW;
    END IF;
END;
$BODY$
LANGUAGE plpgsql;

CREATE TRIGGER T_update_turma
AFTER UPDATE ON turma
FOR EACH ROW
EXECUTE PROCEDURE update_turma();

-- remover aluno
CREATE OR REPLACE FUNCTION rem_aluno() RETURNS TRIGGER 
AS
$BODY$
BEGIN
	UPDATE turma t
	SET qnt_alunos = qnt_alunos - 1 where t.id = OLD.id_turma;
	RETURN NEW;
END;
$BODY$
LANGUAGE plpgsql;

CREATE TRIGGER T_REMALUNO
AFTER DELETE ON aluno_turma_disc
FOR EACH ROW
EXECUTE PROCEDURE rem_aluno();

-- checar o cargo do professor
CREATE OR REPLACE FUNCTION checa_cargo_professor() RETURNS TRIGGER
AS
$BODY$
BEGIN
	IF (NEW.coord_curso_id IS NOT NULL) AND (NEW.diretor_centro_id IS NOT NULL)
	THEN RAISE EXCEPTION 'Professor não pode ser coordenador de um curso e diretor de um centro ao mesmo tempo.';
	ELSE RETURN NEW;
	END IF;
END;
$BODY$
LANGUAGE plpgsql;

CREATE TRIGGER T_CHECACARGOPROFESSOR
AFTER INSERT OR UPDATE ON professor
FOR EACH ROW
EXECUTE PROCEDURE checa_cargo_professor();

-- checar formatacao do semestre e horario alem da lotacao
CREATE OR REPLACE FUNCTION add_turma() RETURNS TRIGGER 
AS
$BODY$
DECLARE
    numero_lotacao integer;
BEGIN
    IF (NEW.semestre NOT LIKE '{%.%}') THEN RAISE EXCEPTION 'Erro, Semestre não está corretamente formatado';
    END IF;
    IF (NEW.horaini >= NEW.horafim) THEN RAISE EXCEPTION 'Horario final é antes do horario final';
    END IF;
    SELECT lotacao FROM local WHERE (codigo = NEW.local_id) INTO numero_lotacao;
    IF (NEW.vagas > numero_lotacao) THEN RAISE EXCEPTION 'O numero de vagas não pode exceder a lotação';
    END IF;
    RETURN NEW;
END;
$BODY$
LANGUAGE plpgsql;

CREATE TRIGGER T_ADDTURMA
AFTER INSERT OR UPDATE ON turma
FOR EACH ROW
EXECUTE PROCEDURE add_turma();
 
-- checar se local tem bloco nulo e
-- chechar se a soma da lotacao das salas de um bloco eh menor que a lotacao total do bloco
CREATE OR REPLACE FUNCTION add_local() RETURNS TRIGGER 
AS
$BODY$
DECLARE 
	lotacao_total integer;
	lotacao_soma integer;
BEGIN
	-- caso em que o local nao possui bloco
	IF upper(NEW.tipo) != 'B' AND (NEW.bloco IS NULL) THEN RAISE EXCEPTION 'Necessário Possuir um BLOCO';
	-- caso em que alteramos ou adicionamos um bloco
	ELSEIF upper(NEW.tipo) = 'B' THEN 
		SELECT SUM(lotacao) FROM local WHERE bloco = NEW.codigo INTO lotacao_soma;
		SELECT lotacao FROM local WHERE codigo = NEW.codigo INTO lotacao_total;
		IF lotacao_soma > lotacao_total
		THEN RAISE EXCEPTION 'Soma da lotação das salas ultrapassa a lotação total do bloco';
		END IF;
	-- caso em que adicionamos um local que o campo bloco nao esta nulo
	ELSEIF NEW.tipo != 'B' THEN 
		SELECT SUM(lotacao) FROM local WHERE bloco = NEW.bloco INTO lotacao_soma;
		SELECT lotacao FROM local WHERE codigo = NEW.bloco INTO lotacao_total;
		IF lotacao_soma > lotacao_total 
		THEN RAISE EXCEPTION 'Soma da lotação das salas ultrapassa a lotação total do bloco';
		END IF;
	END IF;
	
	RETURN NEW;
END;
$BODY$
LANGUAGE plpgsql;

CREATE TRIGGER T_ADDLOCAL
AFTER INSERT OR UPDATE ON local
FOR EACH ROW
EXECUTE PROCEDURE add_local();

-- checar quantidade de disciplinas que o professor leciona
CREATE OR REPLACE FUNCTION add_disciplina() RETURNS TRIGGER 
AS
$BODY$
DECLARE 
    numero integer;
BEGIN
    Select count(professor_id) from disciplina where professor_id = NEW.professor_id into numero;
    IF (numero > 4) THEN RAISE EXCEPTION 'Um Professor não pode lecionar mais do que 4 disciplinas';
    ELSE
        RETURN NEW
    END IF;
END;
$BODY$
LANGUAGE plpgsql;

CREATE TRIGGER T_ADDDISCIPLINA
AFTER INSERT OR UPDATE ON disciplina
FOR EACH ROW
EXECUTE PROCEDURE add_disciplina();

--  turma existe e se um aluno não pode ser matriculado 2 vezes
CREATE OR REPLACE FUNCTION add_atd() RETURNS TRIGGER 
AS
$BODY$
BEGIN
	IF ((NEW.id_disc, NEW.id_turma) not in (select disciplina_id, id from turma))
	THEN RAISE EXCEPTION 'A TURMA NÃO É DA RESPECTIVA DISCIPLINA';
	ELSEIF((NEW.matr_aluno, NEW.id_disc) in (select matr_aluno, id_disc from aluno_turma_disc where id != NEW.id))
	THEN RAISE EXCEPTION 'UM MESMO ALUNO NÃO PODE SER MATRICULADO NA MESMA DISCIPLINA 2 VEZES';
	ELSE
	RETURN NEW;
	END IF;
END;
$BODY$
LANGUAGE plpgsql;

CREATE TRIGGER T_ADDATD
AFTER INSERT OR UPDATE ON aluno_turma_disc
FOR EACH ROW
EXECUTE PROCEDURE add_atd();

-- checar se aluno ta matriculado na disciplina q a nota ta sendo inserida
CREATE OR REPLACE FUNCTION add_nota() RETURNS TRIGGER
AS
$BODY$
BEGIN
	IF (NEW.id_disc NOT IN (SELECT id FROM disciplina))
	THEN RAISE EXCEPTION 'A DISCIPLINA NÃO EXISTE';
	ELSEIF (NEW.id_disc NOT IN (SELECT id_disc FROM aluno_turma_disc atd WHERE NEW.matr_aluno = atd.matr_aluno))
	THEN RAISE EXCEPTION 'O ALUNO NÃO ESTÁ MATRICULADO NA DISCIPLINA QUE A NOTA PERTENCE';
	ELSE RETURN NEW;
	END IF;
END;
$BODY$
LANGUAGE plpgsql;

CREATE TRIGGER T_ADDNOTA
AFTER INSERT OR UPDATE ON notas
FOR EACH ROW
EXECUTE PROCEDURE add_nota()