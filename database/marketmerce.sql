-- ===================================================================
-- Esquema Unificado y Mejorado para Marketmerce
-- Versión: 2.0
-- Autor: Gemini
-- Descripción: Este script contiene la definición completa y consolidada
-- de la base de datos, integrando el esquema original con todas las
-- mejoras de inventario, seguridad, y flexibilidad. Se ha refactorizado
-- para tener una única fuente de verdad, eliminando duplicados y
-- aplicando las mejores prácticas discutidas.
-- ===================================================================

-- ===========================
-- EXTENSIONES
-- ===========================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===========================
-- TIPOS ENUM
-- ===========================
CREATE TYPE rol_usuario_enum AS ENUM ('cliente','empleado','admin','proveedor');
CREATE TYPE estado_pedido_enum AS ENUM ('pendiente','confirmado','procesando','enviado','entregado','cancelado','devuelto');
CREATE TYPE estado_envio_enum AS ENUM ('pendiente','enviado','en_transito','entregado','cancelado','devuelto');
CREATE TYPE estado_devolucion_enum AS ENUM ('solicitado','aprobado','rechazado','procesado','completado');
CREATE TYPE estado_pago_enum AS ENUM ('pendiente','completado','fallido','reembolsado');
CREATE TYPE estado_cupon_enum AS ENUM ('activo','expirado','deshabilitado');

-- ===========================
-- FUNCIONES
-- ===========================

-- Función para actualizar el campo 'actualizado_en'
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.actualizado_en = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Función para registrar cambios en el stock de una ubicación
CREATE OR REPLACE FUNCTION fn_log_stock_ubicacion_changes() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO stock_historial(stock_ubicacion_id, variante_id, ubicacion_id, cantidad_anterior, cantidad_nueva, reservado_anterior, reservado_nuevo, tipo, creado_en)
    VALUES (NEW.id, NEW.variante_id, NEW.ubicacion_id, NULL, NEW.cantidad, NULL, NEW.reservado, 'insert', now());
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO stock_historial(stock_ubicacion_id, variante_id, ubicacion_id, cantidad_anterior, cantidad_nueva, reservado_anterior, reservado_nuevo, tipo, creado_en)
    VALUES (NEW.id, NEW.variante_id, NEW.ubicacion_id, OLD.cantidad, NEW.cantidad, OLD.reservado, NEW.reservado, 'update', now());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO stock_historial(stock_ubicacion_id, variante_id, ubicacion_id, cantidad_anterior, cantidad_nueva, reservado_anterior, reservado_nuevo, tipo, creado_en)
    VALUES (OLD.id, OLD.variante_id, OLD.ubicacion_id, OLD.cantidad, NULL, OLD.reservado, NULL, 'delete', now());
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Función para transferir stock entre dos ubicaciones
CREATE OR REPLACE FUNCTION fn_transferir_stock(p_variante_id UUID, p_origen_id UUID, p_destino_id UUID, p_cantidad INTEGER, p_referencia TEXT DEFAULT NULL, p_creado_por UUID DEFAULT NULL) RETURNS VOID AS $$
DECLARE
  s_origen stock_ubicacion%ROWTYPE;
  s_destino stock_ubicacion%ROWTYPE;
BEGIN
  IF p_cantidad <= 0 THEN
    RAISE EXCEPTION 'La cantidad a transferir debe ser mayor que cero.';
  END IF;

  SELECT * INTO s_origen FROM stock_ubicacion WHERE variante_id = p_variante_id AND ubicacion_id = p_origen_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No hay registro de stock en la ubicación de origen (variante: %, ubicación: %)', p_variante_id, p_origen_id;
  END IF;

  IF s_origen.cantidad < p_cantidad THEN
    RAISE EXCEPTION 'Stock insuficiente en origen. Disponible: %, Solicitado: %', s_origen.cantidad, p_cantidad;
  END IF;

  SELECT * INTO s_destino FROM stock_ubicacion WHERE variante_id = p_variante_id AND ubicacion_id = p_destino_id FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO stock_ubicacion(variante_id, ubicacion_id, cantidad, reservado, creado_en, actualizado_en)
      VALUES (p_variante_id, p_destino_id, 0, 0, now(), now())
      RETURNING * INTO s_destino;
  END IF;

  UPDATE stock_ubicacion SET cantidad = cantidad - p_cantidad, actualizado_en = now() WHERE id = s_origen.id;
  UPDATE stock_ubicacion SET cantidad = cantidad + p_cantidad, actualizado_en = now() WHERE id = s_destino.id;

  INSERT INTO movimientos_inventario(referencia, tipo, variante_id, ubicacion_origen_id, ubicacion_destino_id, cantidad, creado_por, motivo, creado_en)
    VALUES (p_referencia, 'transferencia', p_variante_id, p_origen_id, p_destino_id, p_cantidad, p_creado_por, 'Transferencia interna de stock', now());
END;
$$ LANGUAGE plpgsql;

-- ===========================
-- TABLAS
-- ===========================

-- ROLES Y PERMISOS
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre rol_usuario_enum NOT NULL UNIQUE,
    descripcion TEXT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE permisos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clave TEXT NOT NULL UNIQUE, -- Ej: 'productos:crear', 'pedidos:ver_todos'
    descripcion TEXT
);

CREATE TABLE roles_permisos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rol_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permiso_id UUID NOT NULL REFERENCES permisos(id) ON DELETE CASCADE,
    UNIQUE (rol_id, permiso_id)
);

-- USUARIOS Y PERFILES
CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rol_id UUID NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    correo VARCHAR(320) NOT NULL UNIQUE,
    hash_password TEXT NOT NULL,
    nombre_completo TEXT NOT NULL,
    display_name VARCHAR(255),
    telefono VARCHAR(50),
    fecha_nacimiento DATE,
    genero VARCHAR(50),
    perfil_bio TEXT,
    perfil_completo BOOLEAN DEFAULT FALSE,
    ultimo_login TIMESTAMPTZ,
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Soft Delete
    eliminado BOOLEAN NOT NULL DEFAULT FALSE,
    eliminado_en TIMESTAMPTZ,
    eliminado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL
);

CREATE TABLE direcciones_usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    etiqueta VARCHAR(50), -- Ej: 'Casa', 'Trabajo'
    linea1 VARCHAR(255) NOT NULL,
    linea2 VARCHAR(255),
    ciudad VARCHAR(100) NOT NULL,
    estado VARCHAR(100) NOT NULL,
    codigo_postal VARCHAR(20) NOT NULL,
    pais VARCHAR(100) NOT NULL,
    es_principal BOOLEAN NOT NULL DEFAULT FALSE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unica_direccion_principal UNIQUE (usuario_id, es_principal) WHERE es_principal = TRUE
);

-- SEGURIDAD: SESIONES Y LLAVES API
CREATE TABLE sesiones_usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    tipo_token VARCHAR(50) NOT NULL DEFAULT 'refresh',
    ip_origen INET,
    agente_usuario TEXT,
    emitido_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_en TIMESTAMPTZ NOT NULL,
    revocado BOOLEAN NOT NULL DEFAULT FALSE,
    revocado_en TIMESTAMPTZ
);

CREATE TABLE llaves_api (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    nombre TEXT NOT NULL,
    clave_hash TEXT NOT NULL,
    permisos JSONB DEFAULT '[]'::JSONB,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    rotado_en TIMESTAMPTZ,
    expira_en TIMESTAMPTZ
);

-- TIENDA Y CONFIGURACIÓN
CREATE TABLE tienda (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE,
    ruc VARCHAR(50),
    correo_contacto VARCHAR(320),
    telefono VARCHAR(50),
    direccion JSONB,
    redes_sociales JSONB,
    horario_atencion JSONB,
    moneda VARCHAR(10) DEFAULT 'PEN',
    pais VARCHAR(100) DEFAULT 'Peru',
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE configuracion_sitio (
    clave TEXT PRIMARY KEY,
    valor JSONB NOT NULL,
    descripcion TEXT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CATÁLOGO: MARCAS, CATEGORÍAS, TAGS
CREATE TABLE marcas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Soft Delete
    eliminado BOOLEAN NOT NULL DEFAULT FALSE,
    eliminado_en TIMESTAMPTZ,
    eliminado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL
);

CREATE TABLE categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID REFERENCES categorias(id) ON DELETE SET NULL,
    nombre TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    orden INTEGER DEFAULT 0,
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Soft Delete
    eliminado BOOLEAN NOT NULL DEFAULT FALSE,
    eliminado_en TIMESTAMPTZ,
    eliminado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL
);

CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR(150) NOT NULL UNIQUE,
  slug VARCHAR(150) NOT NULL UNIQUE,
  metadatos JSONB DEFAULT '{}'::JSONB,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- PRODUCTOS Y VARIANTES
CREATE TABLE unidades_medida (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    simbolo TEXT,
    descripcion TEXT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    categoria_id UUID REFERENCES categorias(id) ON DELETE RESTRICT,
    marca_id UUID REFERENCES marcas(id) ON DELETE SET NULL,
    unidad_default_id UUID REFERENCES unidades_medida(id) ON DELETE SET NULL,
    nombre TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    descripcion_larga TEXT,
    meta_title VARCHAR(255),
    meta_description VARCHAR(512),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Soft Delete
    eliminado BOOLEAN NOT NULL DEFAULT FALSE,
    eliminado_en TIMESTAMPTZ,
    eliminado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL
);

CREATE TABLE variantes_producto (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
    sku VARCHAR(100) NOT NULL UNIQUE,
    codigo_barra VARCHAR(255),
    atributos JSONB NOT NULL, -- Ej: {'color': 'Rojo', 'talla': 'M'}
    precio_compra NUMERIC(12,2) DEFAULT 0 CHECK (precio_compra >= 0),
    precio_venta NUMERIC(12,2) NOT NULL CHECK (precio_venta >= 0),
    stock INTEGER NOT NULL CHECK (stock >= 0), -- Stock total (obsoleto si se usa stock_ubicacion)
    stock_minimo INTEGER DEFAULT 0 CHECK (stock_minimo >= 0),
    stock_maximo INTEGER DEFAULT 0 CHECK (stock_maximo >= 0),
    peso_kg NUMERIC(10,3),
    largo_cm NUMERIC(10,3),
    ancho_cm NUMERIC(10,3),
    alto_cm NUMERIC(10,3),
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Soft Delete
    eliminado BOOLEAN NOT NULL DEFAULT FALSE,
    eliminado_en TIMESTAMPTZ,
    eliminado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    CONSTRAINT atributos_no_vacios CHECK (jsonb_array_length(jsonb_object_keys(atributos)) > 0)
);

CREATE TABLE productos_categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
    categoria_id UUID NOT NULL REFERENCES categorias(id) ON DELETE CASCADE,
    UNIQUE(producto_id, categoria_id)
);

CREATE TABLE productos_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  UNIQUE(producto_id, tag_id)
);

CREATE TABLE productos_relacionados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
    relacionado_id UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
    tipo_relacion VARCHAR(50) DEFAULT 'recomendado', -- 'accesorio', 'similar'
    prioridad INTEGER DEFAULT 0,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(producto_id, relacionado_id),
    CONSTRAINT chk_no_self_relation CHECK (producto_id <> relacionado_id)
);

CREATE TABLE resenas_productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
    usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    calificacion SMALLINT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    titulo VARCHAR(255),
    cuerpo TEXT,
    aprobado BOOLEAN NOT NULL DEFAULT FALSE,
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- MEDIA (Imágenes y Archivos Polimórficos)
CREATE TABLE media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_type VARCHAR(50) NOT NULL, -- Ej: 'producto', 'variante', 'categoria', 'usuario'
    owner_id UUID NOT NULL,
    tipo VARCHAR(50) DEFAULT 'imagen',
    url TEXT NOT NULL,
    es_principal BOOLEAN NOT NULL DEFAULT FALSE,
    orden INTEGER NOT NULL DEFAULT 0, -- Para carruseles, 0 es la primera imagen.
    alt_text TEXT,
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- PROVEEDORES Y COMPRAS
CREATE TABLE proveedores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa TEXT NOT NULL UNIQUE,
    contacto TEXT,
    correo VARCHAR(320),
    telefono VARCHAR(30),
    direccion JSONB,
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Soft Delete
    eliminado BOOLEAN NOT NULL DEFAULT FALSE,
    eliminado_en TIMESTAMPTZ,
    eliminado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL
);

CREATE TABLE ordenes_compra (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proveedor_id UUID NOT NULL REFERENCES proveedores(id) ON DELETE RESTRICT,
    numero_orden VARCHAR(50) UNIQUE NOT NULL,
    fecha_orden TIMESTAMPTZ NOT NULL DEFAULT now(),
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente', -- 'pendiente', 'completada', 'cancelada'
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE items_orden_compra (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    orden_compra_id UUID NOT NULL REFERENCES ordenes_compra(id) ON DELETE CASCADE,
    variante_producto_id UUID NOT NULL REFERENCES variantes_producto(id) ON DELETE RESTRICT,
    cantidad_ordenada INTEGER NOT NULL CHECK (cantidad_ordenada > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(orden_compra_id, variante_producto_id)
);

-- INVENTARIO: UBICACIONES, STOCK, MOVIMIENTOS
CREATE TABLE ubicaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(150) NOT NULL,
    codigo VARCHAR(50) UNIQUE,
    direccion JSONB,
    tipo VARCHAR(50) DEFAULT 'almacen', -- 'almacen', 'tienda_fisica', 'transito'
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE stock_ubicacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variante_id UUID NOT NULL REFERENCES variantes_producto(id) ON DELETE CASCADE,
    ubicacion_id UUID NOT NULL REFERENCES ubicaciones(id) ON DELETE CASCADE,
    cantidad INTEGER NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    reservado INTEGER NOT NULL DEFAULT 0 CHECK (reservado >= 0),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (variante_id, ubicacion_id)
);

CREATE TABLE movimientos_inventario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referencia VARCHAR(200), -- ID de pedido, orden de compra, etc.
    tipo VARCHAR(50) NOT NULL, -- 'venta', 'compra', 'transferencia', 'ajuste_manual'
    variante_id UUID NOT NULL REFERENCES variantes_producto(id) ON DELETE CASCADE,
    ubicacion_origen_id UUID REFERENCES ubicaciones(id) ON DELETE SET NULL,
    ubicacion_destino_id UUID REFERENCES ubicaciones(id) ON DELETE SET NULL,
    cantidad INTEGER NOT NULL,
    creado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    motivo TEXT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE stock_historial (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_ubicacion_id UUID REFERENCES stock_ubicacion(id) ON DELETE CASCADE,
    variante_id UUID NOT NULL REFERENCES variantes_producto(id) ON DELETE CASCADE,
    ubicacion_id UUID NOT NULL REFERENCES ubicaciones(id) ON DELETE CASCADE,
    cantidad_anterior INTEGER,
    cantidad_nueva INTEGER,
    reservado_anterior INTEGER,
    reservado_nuevo INTEGER,
    tipo VARCHAR(50), -- 'insert', 'update', 'delete'
    motivo TEXT,
    creado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE historial_precios_variante (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variante_id UUID NOT NULL REFERENCES variantes_producto(id) ON DELETE CASCADE,
    precio_compra NUMERIC(12,2),
    precio_venta NUMERIC(12,2),
    motivo TEXT,
    valido_desde TIMESTAMPTZ NOT NULL DEFAULT now(),
    creado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CARRITOS DE COMPRA
CREATE TABLE carritos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE items_carrito (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    carrito_id UUID NOT NULL REFERENCES carritos(id) ON DELETE CASCADE,
    variante_id UUID NOT NULL REFERENCES variantes_producto(id) ON DELETE RESTRICT,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (carrito_id, variante_id)
);

-- PEDIDOS Y CICLO DE VIDA
CREATE TABLE pedidos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    direccion_envio_id UUID NOT NULL REFERENCES direcciones_usuarios(id) ON DELETE RESTRICT,
    direccion_factura_id UUID NOT NULL REFERENCES direcciones_usuarios(id) ON DELETE RESTRICT,
    numero_pedido VARCHAR(50) UNIQUE NOT NULL,
    estado estado_pedido_enum NOT NULL DEFAULT 'pendiente',
    total NUMERIC(14,2) NOT NULL CHECK (total >= 0),
    metodo_envio JSONB,
    metadatos JSONB DEFAULT '{}'::JSONB,
    realizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Soft Delete
    eliminado BOOLEAN NOT NULL DEFAULT FALSE,
    eliminado_en TIMESTAMPTZ,
    eliminado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL
);

CREATE TABLE items_pedido (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
    variante_id UUID NOT NULL REFERENCES variantes_producto(id) ON DELETE RESTRICT,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
    descuento NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (descuento >= 0),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(pedido_id, variante_id)
);

CREATE TABLE historial_estado_pedido (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
    estado estado_pedido_enum NOT NULL,
    cambiado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    cambiado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    notas TEXT
);

-- PAGOS Y REEMBOLSOS
CREATE TABLE pagos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID UNIQUE REFERENCES pedidos(id) ON DELETE SET NULL,
    proveedor_pago VARCHAR(100), -- Ej: 'Stripe', 'MercadoPago'
    metodo_pago VARCHAR(50), -- Ej: 'credit_card', 'paypal'
    estado estado_pago_enum NOT NULL DEFAULT 'pendiente',
    monto NUMERIC(14,2) NOT NULL CHECK (monto >= 0),
    transaction_id TEXT UNIQUE,
    pagado_en TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadatos JSONB DEFAULT '{}'::JSONB
);

CREATE TABLE devoluciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_pedido_id UUID NOT NULL REFERENCES items_pedido(id) ON DELETE RESTRICT,
    numero_devolucion VARCHAR(50) UNIQUE NOT NULL,
    estado estado_devolucion_enum NOT NULL DEFAULT 'solicitado',
    razon TEXT,
    solicitado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    procesado_en TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE reembolsos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    devolucion_id UUID REFERENCES devoluciones(id) ON DELETE CASCADE,
    pago_id UUID REFERENCES pagos(id) ON DELETE CASCADE,
    monto NUMERIC(14,2) NOT NULL CHECK (monto > 0),
    reembolsado_en TIMESTAMPTZ DEFAULT now(),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadatos JSONB DEFAULT '{}'::JSONB
);

-- ENVÍOS
CREATE TABLE envios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
    numero_seguimiento TEXT UNIQUE,
    transportista TEXT,
    estado estado_envio_enum NOT NULL DEFAULT 'pendiente',
    enviado_en TIMESTAMPTZ,
    entrega_estimada TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadatos JSONB DEFAULT '{}'::JSONB
);

CREATE TABLE historial_envio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    envio_id UUID NOT NULL REFERENCES envios(id) ON DELETE CASCADE,
    estado estado_envio_enum NOT NULL,
    cambiado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    notas TEXT
);

-- MARKETING: CUPONES Y PROMOCIONES
CREATE TABLE cupones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo VARCHAR(50) UNIQUE NOT NULL,
    descripcion TEXT,
    tipo_descuento VARCHAR(30) NOT NULL, -- 'porcentaje', 'fijo'
    valor_descuento NUMERIC(10,2) CHECK (valor_descuento >= 0),
    usos_max INTEGER CHECK (usos_max >= 0),
    usados INTEGER NOT NULL DEFAULT 0 CHECK (usados >= 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    valido_desde TIMESTAMPTZ,
    valido_hasta TIMESTAMPTZ,
    estado estado_cupon_enum NOT NULL DEFAULT 'activo',
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_cupon_validez CHECK (valido_desde IS NULL OR valido_hasta IS NULL OR valido_desde <= valido_hasta)
);

CREATE TABLE promociones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    codigo VARCHAR(100) UNIQUE,
    tipo VARCHAR(30) NOT NULL, -- 'descuento_producto', '2x1', 'envio_gratis'
    valor NUMERIC(12,2),
    aplica_a JSONB DEFAULT '[]'::JSONB, -- {'tipo': 'categoria', 'ids': [uuid1, uuid2]}
    fecha_inicio TIMESTAMPTZ,
    fecha_fin TIMESTAMPTZ,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    prioridad INTEGER DEFAULT 0,
    metadatos JSONB DEFAULT '{}'::JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- SISTEMA: NOTIFICACIONES Y AUDITORÍA (Particionadas)
CREATE TABLE notificaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo VARCHAR(50),
    contenido JSONB NOT NULL,
    leido BOOLEAN NOT NULL DEFAULT FALSE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (creado_en);

CREATE TABLE auditorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    evento VARCHAR(100) NOT NULL,
    usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    entidad TEXT NOT NULL,
    entidad_id UUID,
    datos_cambiados JSONB,
    ip inet,
    agente_usuario TEXT,
    trace_id TEXT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (creado_en);

-- ===========================
-- PARTICIONES (Ejemplos)
-- ===========================
-- NOTA: Se deben crear particiones futuras de forma proactiva.
CREATE TABLE IF NOT EXISTS notificaciones_2025 PARTITION OF notificaciones FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS auditorias_2025 PARTITION OF auditorias FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- ===========================
-- VISTAS
-- ===========================
CREATE OR REPLACE VIEW vista_inventario_actual AS
SELECT
  v.id AS variante_id,
  v.sku,
  p.nombre AS producto_nombre,
  v.atributos,
  COALESCE(SUM(su.cantidad), 0) AS stock_total,
  COALESCE(SUM(su.reservado), 0) AS reservado_total,
  (COALESCE(SUM(su.cantidad), 0) - COALESCE(SUM(su.reservado), 0)) AS disponible_para_venta
FROM variantes_producto v
JOIN productos p ON p.id = v.producto_id
LEFT JOIN stock_ubicacion su ON su.variante_id = v.id
WHERE v.eliminado = FALSE AND p.eliminado = FALSE
GROUP BY v.id, p.nombre;

CREATE OR REPLACE VIEW vista_productos_activos AS
SELECT p.*,
       m.url AS imagen_principal,
       COALESCE(json_agg(DISTINCT jsonb_build_object('id', t.id, 'nombre', t.nombre)) FILTER (WHERE t.id IS NOT NULL), '[]') AS tags
FROM productos p
LEFT JOIN media m ON m.owner_type='producto' AND m.owner_id = p.id AND m.es_principal = TRUE
LEFT JOIN productos_tags pt ON pt.producto_id = p.id
LEFT JOIN tags t ON t.id = pt.tag_id
WHERE p.activo = TRUE AND p.eliminado = FALSE
GROUP BY p.id, m.url;

-- ===========================
-- ÍNDICES
-- ===========================
-- Índices para tablas de usuario y seguridad
CREATE INDEX IF NOT EXISTS idx_usuarios_rol ON usuarios(rol_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_correo ON usuarios(correo);
CREATE INDEX IF NOT EXISTS idx_sesiones_usuarios_expira ON sesiones_usuarios(expira_en);

-- Índices para catálogo (productos, categorías, etc.)
CREATE INDEX IF NOT EXISTS idx_productos_slug ON productos(slug);
CREATE INDEX IF NOT EXISTS idx_productos_categoria_activo ON productos(categoria_id, activo, creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_categorias_slug ON categorias(slug);
CREATE INDEX IF NOT EXISTS idx_categorias_parent ON categorias(parent_id);
CREATE INDEX IF NOT EXISTS idx_variantes_producto_sku ON variantes_producto(sku);
CREATE INDEX IF NOT EXISTS idx_variantes_producto_producto ON variantes_producto(producto_id);
CREATE INDEX IF NOT EXISTS idx_resenas_producto ON resenas_productos(producto_id);
CREATE INDEX IF NOT EXISTS idx_media_owner ON media(owner_type, owner_id);

-- Índices para inventario y proveedores
CREATE INDEX IF NOT EXISTS idx_stock_ubicacion_variante ON stock_ubicacion(variante_id);
CREATE INDEX IF NOT EXISTS idx_stock_ubicacion_ubicacion ON stock_ubicacion(ubicacion_id);
CREATE INDEX IF NOT EXISTS idx_mov_inv_variante_fecha ON movimientos_inventario(variante_id, creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_ordenes_compra_proveedor_estado ON ordenes_compra(proveedor_id, estado);

-- Índices para ciclo de venta (pedidos, pagos, envíos)
CREATE INDEX IF NOT EXISTS idx_pedidos_usuario_fecha ON pedidos(usuario_id, realizado_en DESC);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado_fecha ON pedidos(estado, realizado_en DESC);
CREATE INDEX IF NOT EXISTS idx_items_pedido_pedido ON items_pedido(pedido_id);
CREATE INDEX IF NOT EXISTS idx_pagos_estado_fecha ON pagos(estado, pagado_en DESC);
CREATE INDEX IF NOT EXISTS idx_envios_pedido_estado ON envios(pedido_id, estado);

-- Índices para tablas particionadas
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario_leido ON notificaciones(usuario_id, leido);
CREATE INDEX IF NOT EXISTS idx_auditorias_evento_fecha ON auditorias(evento, creado_en DESC);

-- ===========================
-- DISPARADORES (TRIGGERS)
-- ===========================
DO $$
DECLARE
  tbl TEXT;
  trg_name TEXT;
BEGIN
  FOR tbl IN SELECT UNNEST(ARRAY[
    'roles','usuarios','direcciones_usuarios','proveedores','ordenes_compra','items_orden_compra',
    'categorias','productos','variantes_producto','resenas_productos','media','carritos','items_carrito',
    'pedidos','items_pedido','historial_estado_pedido','pagos','envios','historial_envio',
    'devoluciones','reembolsos','cupones','promociones','notificaciones','configuracion_sitio',
    'marcas','unidades_medida','ubicaciones','stock_ubicacion','tienda','tags'
  ]) LOOP
    trg_name := 'trg_' || tbl || '_set_updated_at';
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = trg_name) THEN
      EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();', trg_name, tbl);
    END IF;
  END LOOP;
END
$$ LANGUAGE plpgsql;

-- Trigger para registrar historial de stock
DROP TRIGGER IF EXISTS trg_stock_ubicacion_changes ON stock_ubicacion;
CREATE TRIGGER trg_stock_ubicacion_changes
AFTER INSERT OR UPDATE OR DELETE ON stock_ubicacion
FOR EACH ROW EXECUTE FUNCTION fn_log_stock_ubicacion_changes();

-- ===========================
-- SUGERENCIAS DE SEGURIDAD Y MANTENIMIENTO
-- ===========================
-- 1) RLS (Row Level Security): Considera habilitar RLS en tablas sensibles como 'usuarios', 'pedidos', y 'direcciones_usuarios'
--    para restringir el acceso a los datos solo a sus propietarios o a roles autorizados.
--    Ejemplo:
--    ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
--    CREATE POLICY usuarios_self_access ON usuarios
--    FOR ALL USING (id = current_setting('app.current_user_id')::uuid OR (SELECT rol FROM roles WHERE id = rol_id) = 'admin');

-- 2) Gestión de Secretos: Usa un servicio como AWS Secrets Manager o HashiCorp Vault para gestionar las
--    credenciales de la base de datos y otras claves maestras, en lugar de tenerlas en archivos de configuración.

-- 3) Backups: Asegúrate de tener una estrategia de backups automáticos y recuperación de punto en el tiempo (PITR),
--    especialmente si usas servicios como AWS RDS.

-- 4) Mantenimiento de Particiones: Crea un script o trabajo cron para añadir nuevas particiones a las tablas
--    'notificaciones' y 'auditorias' antes de que comience cada nuevo período (ej. cada año).

-- FIN DEL ESQUEMA
