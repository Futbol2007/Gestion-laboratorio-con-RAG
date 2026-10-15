-- ============================================================================
-- UNIVERSIDAD DE CALDAS - BASES DE DATOS RELACIONALES
-- ENTREGA 1: SISTEMA HÍBRIDO RELACIONAL-VECTORIAL LIMS + RAG
-- Autores: Estupiñán, Noreña, Puerta
-- Archivo: sql/schema.sql
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- 1. MÓDULO DE ORGANIZACIÓN, PERSONAL Y NÚCLEO RAG (USUARIOS)
-- ============================================================================
CREATE TABLE departamento (
    id_departamento SERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL UNIQUE
);

CREATE TABLE investigador (
    id_investigador SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    rol VARCHAR(30) NOT NULL DEFAULT 'investigador'
        CHECK (rol IN ('admin', 'investigador', 'analista', 'tecnico')),
    id_departamento INT NOT NULL
        REFERENCES departamento(id_departamento) ON DELETE RESTRICT
);

CREATE TABLE proyecto_investigacion (
    id_proyecto_investigacion SERIAL PRIMARY KEY,
    titulo VARCHAR(250) NOT NULL,
    fecha_inicio DATE NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'activo'
        CHECK (estado IN ('activo', 'pausado', 'finalizado')),
    id_investigador_principal INT NOT NULL
        REFERENCES investigador(id_investigador) ON DELETE RESTRICT
);

-- ============================================================================
-- 2. MÓDULO DOCUMENTAL (PROTOCOLOS / DOCUMENTOS) Y EJECUCIÓN EXPERIMENTAL
-- ============================================================================
CREATE TABLE protocolo_estandar (
    id_protocolo SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    version VARCHAR(20) NOT NULL DEFAULT '1.0',
    idioma VARCHAR(5) NOT NULL DEFAULT 'es'
        CHECK (idioma IN ('es', 'en')),
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    fuente VARCHAR(150) NOT NULL DEFAULT 'Laboratorio Interno',
    texto TEXT NOT NULL,
    UNIQUE (nombre, version)
);

CREATE TABLE experimento (
    id_experimento SERIAL PRIMARY KEY,
    fecha_ejecucion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_proyecto INT NOT NULL
        REFERENCES proyecto_investigacion(id_proyecto_investigacion) ON DELETE RESTRICT,
    id_investigador INT NOT NULL
        REFERENCES investigador(id_investigador) ON DELETE RESTRICT,
    id_protocolo INT NOT NULL
        REFERENCES protocolo_estandar(id_protocolo) ON DELETE RESTRICT
);

CREATE TABLE condicion_ambiental (
    id_condicion_ambiental SERIAL PRIMARY KEY,
    temperatura NUMERIC(5,2) NOT NULL,
    humedad NUMERIC(5,2) NOT NULL CHECK (humedad BETWEEN 0 AND 100),
    presion NUMERIC(7,2) NOT NULL CHECK (presion > 0),
    id_experimento INT NOT NULL UNIQUE
        REFERENCES experimento(id_experimento) ON DELETE CASCADE
);

CREATE TABLE desecho (
    id_desecho SERIAL PRIMARY KEY,
    tipo_residuo VARCHAR(100) NOT NULL,
    cantidad_residuo NUMERIC(10,3) NOT NULL CHECK (cantidad_residuo > 0),
    id_experimento INT NOT NULL
        REFERENCES experimento(id_experimento) ON DELETE CASCADE
);

-- ============================================================================
-- 3. MÓDULO DE MUESTRAS Y RESULTADOS ESTRUCTURADOS DE LABORATORIO
-- ============================================================================
CREATE TABLE muestra (
    id_muestra SERIAL PRIMARY KEY,
    tipo_muestra VARCHAR(100) NOT NULL,
    id_experimento INT NOT NULL
        REFERENCES experimento(id_experimento) ON DELETE CASCADE
);

CREATE TABLE resultado_estructurado (
    id_resultado SERIAL PRIMARY KEY,
    metrica VARCHAR(100) NOT NULL,
    valor_numerico NUMERIC(14,4) NOT NULL,
    unidad VARCHAR(30) NOT NULL,
    id_muestra INT NOT NULL
        REFERENCES muestra(id_muestra) ON DELETE CASCADE
);

-- ============================================================================
-- 4. MÓDULO DE INVENTARIO QUÍMICO Y TRAZABILIDAD DE LOTES
-- ============================================================================
CREATE TABLE reactivo (
    id_reactivo SERIAL PRIMARY KEY,
    nombre_cientifico VARCHAR(180) NOT NULL,
    cas_numero VARCHAR(30) NOT NULL UNIQUE,
    nivel_peligro INT NOT NULL CHECK (nivel_peligro BETWEEN 1 AND 5)
);

CREATE TABLE lote_reactivo (
    id_lote_reactivo SERIAL PRIMARY KEY,
    cantidad NUMERIC(12,3) NOT NULL CHECK (cantidad >= 0),
    caducidad DATE NOT NULL,
    ubicacion VARCHAR(120) NOT NULL,
    reactivo_id INT NOT NULL
        REFERENCES reactivo(id_reactivo) ON DELETE RESTRICT
);

CREATE TABLE consumo_lote_reactivo (
    id_consumo_lote_reactivo SERIAL PRIMARY KEY,
    id_lote_reactivo INT NOT NULL
        REFERENCES lote_reactivo(id_lote_reactivo) ON DELETE RESTRICT,
    id_experimento INT NOT NULL
        REFERENCES experimento(id_experimento) ON DELETE CASCADE,
    cantidad_usada NUMERIC(12,3) NOT NULL CHECK (cantidad_usada > 0),
    UNIQUE (id_lote_reactivo, id_experimento)
);

-- ============================================================================
-- 5. MÓDULO DE EQUIPAMIENTO Y MANTENIMIENTO
-- ============================================================================
CREATE TABLE equipo_laboratorio (
    id_equipo SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    modelo VARCHAR(100) NOT NULL
);

CREATE TABLE registro_uso_equipo (
    id_registro SERIAL PRIMARY KEY,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    hora_de_uso TIME NOT NULL,
    id_equipo INT NOT NULL
        REFERENCES equipo_laboratorio(id_equipo) ON DELETE RESTRICT,
    id_investigador INT NOT NULL
        REFERENCES investigador(id_investigador) ON DELETE RESTRICT
);

CREATE TABLE mantenimiento_equipo (
    id_mantenimiento SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    id_equipo INT NOT NULL
        REFERENCES equipo_laboratorio(id_equipo) ON DELETE CASCADE
);

-- ============================================================================
-- 6. MÓDULO MULTIMODAL DE IMÁGENES
-- ============================================================================
CREATE TABLE imagenes (
    id_img SERIAL PRIMARY KEY,
    id_protocolo INT NOT NULL
        REFERENCES protocolo_estandar(id_protocolo) ON DELETE CASCADE,
    id_muestra INT
        REFERENCES muestra(id_muestra) ON DELETE SET NULL,
    ruta_archivo VARCHAR(500) NOT NULL UNIQUE,
    descripcion TEXT NOT NULL
);

-- ============================================================================
-- 7. MÓDULO DE CONSULTAS RAG, RESULTADOS Y EVALUACIÓN DE CALIDAD
-- ============================================================================
CREATE TABLE consultas (
    id_consulta SERIAL PRIMARY KEY,
    id_investigador INT NOT NULL
        REFERENCES investigador(id_investigador) ON DELETE CASCADE,
    texto_pregunta TEXT NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE resultados (
    id_resultado_rag SERIAL PRIMARY KEY,
    id_consulta INT NOT NULL
        REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    id_protocolo INT
        REFERENCES protocolo_estandar(id_protocolo) ON DELETE CASCADE,
    id_img INT
        REFERENCES imagenes(id_img) ON DELETE CASCADE,
    score_similitud NUMERIC(6,5) NOT NULL
        CHECK (score_similitud BETWEEN -1 AND 1),
    CHECK (
        (id_protocolo IS NOT NULL AND id_img IS NULL) OR
        (id_protocolo IS NULL AND id_img IS NOT NULL)
    )
);

CREATE TABLE evaluaciones (
    id_eval SERIAL PRIMARY KEY,
    id_consulta INT NOT NULL UNIQUE
        REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    faithfulness NUMERIC(4,3) NOT NULL CHECK (faithfulness BETWEEN 0 AND 1),
    answer_relevancy NUMERIC(4,3) NOT NULL CHECK (answer_relevancy BETWEEN 0 AND 1),
    context_recall NUMERIC(4,3) NOT NULL CHECK (context_recall BETWEEN 0 AND 1),
    modelo_eval VARCHAR(100) NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 8. TABLAS VECTORIALES E ÍNDICES HNSW (PGVECTOR)
-- ============================================================================
CREATE TABLE embeddings_texto (
    id_embedding SERIAL PRIMARY KEY,
    id_protocolo INT NOT NULL
        REFERENCES protocolo_estandar(id_protocolo) ON DELETE CASCADE,
    chunk_id INT NOT NULL,
    estrategia_chunking VARCHAR(20) NOT NULL
        CHECK (estrategia_chunking IN ('fixed-size', 'sentence-aware', 'semantic')),
    chunk_texto TEXT NOT NULL,
    vector_embedding VECTOR(384) NOT NULL,
    modelo VARCHAR(100) NOT NULL DEFAULT 'all-MiniLM-L6-v2',
    UNIQUE (id_protocolo, estrategia_chunking, chunk_id)
);

CREATE TABLE embeddings_imagen (
    id_embedding SERIAL PRIMARY KEY,
    id_img INT NOT NULL
        REFERENCES imagenes(id_img) ON DELETE CASCADE,
    vector_embedding VECTOR(512) NOT NULL,
    modelo VARCHAR(100) NOT NULL DEFAULT 'clip-vit-base-patch32'
);

CREATE TABLE query_embeddings (
    id_query_embedding SERIAL PRIMARY KEY,
    id_consulta INT NOT NULL
        REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    vector_texto VECTOR(384),
    vector_clip_texto VECTOR(512),
    modelo VARCHAR(100) NOT NULL
);

-- Índices vectoriales HNSW para búsqueda rápida por similitud de coseno
CREATE INDEX idx_hnsw_embeddings_texto
    ON embeddings_texto USING hnsw (vector_embedding vector_cosine_ops);

CREATE INDEX idx_hnsw_embeddings_imagen
    ON embeddings_imagen USING hnsw (vector_embedding vector_cosine_ops);