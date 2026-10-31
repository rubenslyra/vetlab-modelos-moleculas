-- =============================================================================
-- 📐 Modelos e Moléculas 🔬
-- Vídeo 2: Regra e Esquema — Da Regulamentação e do Negócio à Álgebra Relacional
-- Estudo de Caso: VET-Lab (Infraestrutura de Diagnóstico e Genômica)
-- =============================================================================
-- Autor: Rubens Lyra, Analista de Sistemas e estudante de Biotecnologia
-- Banco Alvo: vetlab_db (PostgreSQL 18)
-- Execução: Rodar com Auto-Commit DESLIGADO no pgAdmin ou via psql
-- =============================================================================

BEGIN;

-- Garantindo que estamos operando nos schemas corretos criados no Vídeo 1
SET search_path TO clinica, genoma, auditoria, public;

-- -----------------------------------------------------------------------------
-- 1. RESPONSÁVEIS TÉCNICOS (Conformidade CFMV / CRMV)
-- Regra de Negócio: Nenhum laudo ou coleta biológica é válida sem a vinculação
-- intransferível de um Médico Veterinário com inscrição ativa na UF.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clinica.veterinarios (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    nome_completo VARCHAR(150) NOT NULL,
    crmv_uf CHAR(2) NOT NULL,
    crmv_numero VARCHAR(20) NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Restrição de Domínio (Teoria dos Conjuntos): UF deve ter exatamente 2 letras maiúsculas
    CONSTRAINT ck_veterinario_uf_formato CHECK (crmv_uf ~ '^[A-Z]{2}$'),
    -- Restrição de Unicidade Composta (Chave Candidata): CRMV é único dentro de cada Estado
    CONSTRAINT uq_veterinario_crmv UNIQUE (crmv_uf, crmv_numero)
);

COMMENT ON TABLE clinica.veterinarios IS 'Cadastro de Responsáveis Técnicos habilitados pelo CFMV/CRMV.';

-- -----------------------------------------------------------------------------
-- 2. PACIENTES / MATRIZES BIOLÓGICAS (Rastreabilidade MAPA & LGPD)
-- Regra de Negócio: Identificação inequívoca do organismo fonte (microchip/brinco).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clinica.pacientes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    identificador_oficial VARCHAR(50) NOT NULL,
    especie VARCHAR(80) NOT NULL,
    raca VARCHAR(80),
    sexo CHAR(1) NOT NULL,
    data_nascimento DATE,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Unicidade do identificador físico animal (Microchip ISO 11784/11785 ou Brinco Oficial)
    CONSTRAINT uq_paciente_identificador UNIQUE (identificador_oficial),
    -- Domínio fechado para sexo biológico: Macho (M), Fêmea (F), Indeterminado (I)
    CONSTRAINT ck_paciente_sexo_dominio CHECK (sexo IN ('M', 'F', 'I')),
    -- Coerência temporal: data de nascimento não pode estar no futuro
    CONSTRAINT ck_paciente_nascimento_valido CHECK (data_nascimento IS NULL OR data_nascimento <= CURRENT_DATE)
);

COMMENT ON TABLE clinica.pacientes IS 'Matrizes biológicas e animais sob custódia diagnóstica.';

-- -----------------------------------------------------------------------------
-- 3. AMOSTRAS LABORATORIAIS (Cadeia de Custódia ISO/IEC 17025 - Item 7.11)
-- Regra de Negócio: Conecta a matriz biológica ao responsável técnico pela coleta,
-- garantindo integridade referencial e linha do tempo inviolável.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clinica.amostras (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    codigo_barras VARCHAR(40) NOT NULL,
    paciente_id UUID NOT NULL,
    veterinario_coletor_id UUID NOT NULL,
    tipo_material VARCHAR(50) NOT NULL,
    status_amostra VARCHAR(30) NOT NULL DEFAULT 'RECEBIDA',
    coletada_em TIMESTAMPTZ NOT NULL,
    recebida_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_amostra_codigo_barras UNIQUE (codigo_barras),

    -- Domínio controlado de matrizes de coleta
    CONSTRAINT ck_amostra_tipo_material CHECK (
        tipo_material IN ('SANGUE_TOTAL', 'SWAB_NASAL', 'BIOPSIA_TECIDO', 'PLASMA', 'OUTRO')
    ),

    -- Máquina de estados finitos do ciclo de vida da amostra
    CONSTRAINT ck_amostra_status CHECK (
        status_amostra IN ('RECEBIDA', 'EM_PROCESSAMENTO', 'SEQUENCIADA', 'DESCARTADA', 'REJEITADA')
    ),

    -- Regra cronológica: é fisicamente impossível receber a amostra antes da coleta
    CONSTRAINT ck_amostra_cronologia_coleta CHECK (recebida_em >= coletada_em),

    -- Chaves Estrangeiras Estritas (ON DELETE RESTRICT impede apagamento acidental de histórico)
    CONSTRAINT fk_amostra_paciente FOREIGN KEY (paciente_id)
        REFERENCES clinica.pacientes(id) ON DELETE RESTRICT,
    CONSTRAINT fk_amostra_veterinario FOREIGN KEY (veterinario_coletor_id)
        REFERENCES clinica.veterinarios(id) ON DELETE RESTRICT
);

COMMENT ON TABLE clinica.amostras IS 'Registro de custódia física e temporal das amostras biológicas (ISO 17025).';

-- -----------------------------------------------------------------------------
-- 4. SEQUÊNCIAS GENÉTICAS (Intersecção com a Biologia Computacional)
-- Regra de Negócio: Armazenamento estruturado de leituras (DNA/RNA) vinculadas
-- a uma amostra válida, aplicando validação algébrica sobre o alfabeto IUPAC.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS genoma.sequencias (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    amostra_id UUID NOT NULL,
    marcador_alvo VARCHAR(100) NOT NULL, -- Ex: BRCA1, COI, 16S rRNA
    tipo_molecula VARCHAR(10) NOT NULL,
    cadeia_nucleotideos TEXT NOT NULL,
    comprimento_pb INTEGER GENERATED ALWAYS AS (length(cadeia_nucleotideos)) STORED,
    phred_score_medio NUMERIC(4,2) NOT NULL,
    processado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Domínio molecular
    CONSTRAINT ck_sequencia_tipo_molecula CHECK (tipo_molecula IN ('DNA', 'RNA')),

    -- Teoria dos Conjuntos aplicada: apenas bases canônicas IUPAC (A, C, G, T, U, N) sem espaços
    CONSTRAINT ck_sequencia_alfabeto_biologico CHECK (cadeia_nucleotideos ~ '^[ACGTUN]+$'),

    -- Coerência bioquímica: DNA não contém Uracila (U); RNA não contém Timina (T)
    CONSTRAINT ck_sequencia_coerencia_bases CHECK (
        (tipo_molecula = 'DNA' AND cadeia_nucleotideos !~ 'U') OR
        (tipo_molecula = 'RNA' AND cadeia_nucleotideos !~ 'T')
    ),

    -- Escala de qualidade Phred (Q-score entre 0 e 60)
    CONSTRAINT ck_sequencia_phred_score CHECK (phred_score_medio BETWEEN 0 AND 60),

    -- Integridade Referencial: nenhuma sequência genética existe sem uma amostra física auditável
    CONSTRAINT fk_sequencia_amostra FOREIGN KEY (amostra_id)
        REFERENCES clinica.amostras(id) ON DELETE RESTRICT
);

COMMENT ON TABLE genoma.sequencias IS 'Leituras genômicas validadas por regras de domínio biológico e qualidade Phred.';

-- =============================================================================
-- Consolidação da Transação
-- =============================================================================
COMMIT;

-- =============================================================================
-- Consultas Rápidas de Verificação Pós-Execução (Auditoria do Esquema)
-- =============================================================================
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('clinica', 'genoma')
ORDER BY table_schema, table_name;

SELECT conname AS nome_regra,
       contype AS tipo_regra,
       pg_get_constraintdef(oid) AS definicao_matematica
FROM pg_constraint
WHERE connamespace IN ('clinica'::regnamespace, 'genoma'::regnamespace)
ORDER BY conname;
