-- ===================================================================
-- Script de Inserción de Datos y Comprobaciones para Marketmerce
-- Versión: 1.0
-- Autor: Gemini
-- Descripción: Este script puebla la base de datos con datos iniciales
-- para realizar pruebas funcionales de la tienda virtual. Incluye la
-- creación de roles, usuarios, productos de ejemplo, inventario y
-- consultas de verificación.
-- ===================================================================

-- Limpiar datos anteriores (opcional, usar con precaución en desarrollo)
-- DELETE FROM stock_historial; 
-- DELETE FROM movimientos_inventario;
-- DELETE FROM stock_ubicacion;
-- DELETE FROM media;
-- DELETE FROM items_pedido;
-- DELETE FROM pedidos;
-- DELETE FROM carritos;
-- DELETE FROM variantes_producto;
-- DELETE FROM productos;
-- DELETE FROM categorias;
-- DELETE FROM marcas;
-- DELETE FROM usuarios;
-- DELETE FROM roles;
-- DELETE FROM ubicaciones;
-- DELETE FROM tienda;

-- ===========================
-- INSERCIÓN DE DATOS INICIALES
-- ===========================

BEGIN;

-- 1. Roles de Usuario
INSERT INTO roles (id, nombre, descripcion) VALUES
('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'admin', 'Administrador con todos los permisos'),
('c47ac10b-58cc-4372-a567-0e02b2c3d479', 'cliente', 'Cliente final que realiza compras'),
('e47ac10b-58cc-4372-a567-0e02b2c3d479', 'empleado', 'Empleado de la tienda con permisos restringidos'),
('p47ac10b-58cc-4372-a567-0e02b2c3d479', 'proveedor', 'Proveedor de productos')
ON CONFLICT (nombre) DO NOTHING;

-- 2. Usuarios (Contraseña para todos: 'marketmerce123')
-- La contraseña debe ser hasheada por la aplicación antes de insertarla.
-- Este es un HASH DE EJEMPLO (bcrypt de 'marketmerce123'). NO USAR EN PRODUCCIÓN.
INSERT INTO usuarios (id, rol_id, correo, hash_password, nombre_completo, display_name)
VALUES
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'admin@marketmerce.com', '$2a$12$8.IdmMPS.3b3p1i/3d22A.xTj.l1Qc.ECsm2a3s5/PIt2.2N.Qz.K', 'Admin General', 'Admin'),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'c47ac10b-58cc-4372-a567-0e02b2c3d479', 'cliente@marketmerce.com', '$2a$12$8.IdmMPS.3b3p1i/3d22A.xTj.l1Qc.ECsm2a3s5/PIt2.2N.Qz.K', 'Cliente de Prueba', 'ClientePrueba')
ON CONFLICT (correo) DO NOTHING;

-- 3. Tienda
INSERT INTO tienda (id, nombre, slug, correo_contacto, telefono, moneda, pais)
VALUES
('1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed', 'Marketmerce', 'marketmerce', 'contacto@marketmerce.com', '+51 999 888 777', 'PEN', 'Perú')
ON CONFLICT (slug) DO NOTHING;

-- 4. Categorías (con jerarquía)
INSERT INTO categorias (id, parent_id, nombre, slug, descripcion) VALUES
('c001', NULL, 'Electrónica', 'electronica', 'Dispositivos electrónicos y accesorios.'),
('c002', 'c001', 'Smartphones', 'smartphones', 'Teléfonos inteligentes de última generación.'),
('c003', 'c001', 'Laptops', 'laptops', 'Computadoras portátiles para trabajo y entretenimiento.'),
('c004', NULL, 'Hogar', 'hogar', 'Artículos para el hogar y decoración.')
ON CONFLICT (slug) DO NOTHING;

-- 5. Marcas
INSERT INTO marcas (id, nombre, slug) VALUES
('m001', 'Genérica', 'generica'),
('m002', 'TechPro', 'techpro'),
('m003', 'HomeStyle', 'homestyle')
ON CONFLICT (slug) DO NOTHING;

-- 6. Productos
INSERT INTO productos (id, categoria_id, marca_id, nombre, slug, descripcion, activo)
VALUES
('p001', 'c002', 'm002', 'Smartphone Z10', 'smartphone-z10', 'El nuevo Smartphone Z10 con IA integrada.', TRUE),
('p002', 'c003', 'm002', 'Laptop ProBook X', 'laptop-probook-x', 'Potencia y diseño en un solo equipo.', TRUE),
('p003', 'c004', 'm003', 'Lámpara de Escritorio LED', 'lampara-escritorio-led', 'Iluminación moderna para tu espacio.', TRUE)
ON CONFLICT (slug) DO NOTHING;

-- 7. Variantes de Producto
INSERT INTO variantes_producto (id, producto_id, sku, atributos, precio_venta, stock)
VALUES
('v001', 'p001', 'SPZ10-BLK', '{"color": "Negro", "almacenamiento": "128GB"}', 1899.90, 100),
('v002', 'p001', 'SPZ10-WHT', '{"color": "Blanco", "almacenamiento": "128GB"}', 1899.90, 80),
('v003', 'p002', 'LPX-15-GRY', '{"tamaño": "15 pulgadas", "ram": "16GB"}', 4500.00, 50),
('v004', 'p003', 'LEDLAMP-SLV', '{"color": "Plata"}', 120.50, 200)
ON CONFLICT (sku) DO NOTHING;

-- 8. Medios (Imágenes para productos y avatares)
-- Se asume que las URLs apuntan a un bucket de S3 o similar.
INSERT INTO media (owner_type, owner_id, url, es_principal, orden, alt_text) VALUES
-- Imágenes para Smartphone Z10 (p001)
('producto', 'p001', 'https://example.com/images/spz10-black-main.jpg', TRUE, 0, 'Smartphone Z10 color negro vista frontal'),
('producto', 'p001', 'https://example.com/images/spz10-black-side.jpg', FALSE, 1, 'Smartphone Z10 color negro vista lateral'),
('producto', 'p001', 'https://example.com/images/spz10-white-main.jpg', FALSE, 2, 'Smartphone Z10 color blanco'),
-- Imágenes para Laptop ProBook X (p002)
('producto', 'p002', 'https://example.com/images/lpx-main.jpg', TRUE, 0, 'Laptop ProBook X abierta'),
-- Avatar para usuario Admin
('usuario', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'https://example.com/avatars/admin.png', TRUE, 0, 'Avatar de Admin')
ON CONFLICT DO NOTHING;

-- 9. Ubicaciones (Almacenes)
INSERT INTO ubicaciones (id, nombre, codigo, tipo)
VALUES
('u001', 'Almacén Principal', 'ALM-PRI', 'almacen'),
('u002', 'Tienda Sur', 'TIEN-SUR', 'tienda_fisica')
ON CONFLICT (codigo) DO NOTHING;

-- 10. Stock por Ubicación
-- Distribuimos el stock de las variantes en el almacén principal.
INSERT INTO stock_ubicacion (variante_id, ubicacion_id, cantidad)
VALUES
('v001', 'u001', 100),
('v002', 'u001', 80),
('v003', 'u001', 50),
('v004', 'u001', 200)
ON CONFLICT (variante_id, ubicacion_id) DO NOTHING;

COMMIT;


-- ===========================
-- COMPROBACIONES (CHECKS)
-- ===========================

-- 1. Verificar el inventario actual usando la vista
PROMPT '\n[CHECK 1] Mostrando inventario actual desde la vista vista_inventario_actual:'
SELECT * FROM vista_inventario_actual;

-- 2. Verificar los productos activos con su imagen principal
PROMPT '\n[CHECK 2] Mostrando productos activos desde la vista vista_productos_activos:'
SELECT id, nombre, slug, imagen_principal FROM vista_productos_activos;

-- 3. Simular una transferencia de stock y verificar el resultado
PROMPT '\n[CHECK 3] Transfiriendo 10 unidades del Smartphone Z10 (SKU: SPZ10-BLK) del Almacén Principal a la Tienda Sur...'
-- Antes de la transferencia
SELECT 'Antes' as momento, u.nombre, su.cantidad, su.reservado
FROM stock_ubicacion su
JOIN ubicaciones u ON u.id = su.ubicacion_id
WHERE su.variante_id = 'v001';

-- Ejecutar la función de transferencia
SELECT fn_transferir_stock('v001', 'u001', 'u002', 10, 'Transferencia inicial para tienda');

-- Después de la transferencia
SELECT 'Después' as momento, u.nombre, su.cantidad, su.reservado
FROM stock_ubicacion su
JOIN ubicaciones u ON u.id = su.ubicacion_id
WHERE su.variante_id = 'v001';

-- 4. Verificar el historial de movimientos de inventario para la transferencia
PROMPT '\n[CHECK 4] Verificando el registro en la tabla movimientos_inventario:'
SELECT tipo, variante_id, ubicacion_origen_id, ubicacion_destino_id, cantidad, motivo
FROM movimientos_inventario
WHERE variante_id = 'v001' AND tipo = 'transferencia';

-- 5. Verificar el historial de cambios en la tabla de stock
PROMPT '\n[CHECK 5] Verificando los logs en la tabla stock_historial (generados por el trigger):'
SELECT sh.tipo, v.sku, u.nombre as ubicacion, sh.cantidad_anterior, sh.cantidad_nueva
FROM stock_historial sh
JOIN variantes_producto v ON v.id = sh.variante_id
JOIN ubicaciones u ON u.id = sh.ubicacion_id
WHERE sh.variante_id = 'v001' ORDER BY sh.creado_en DESC LIMIT 2;

-- FIN DEL SCRIPT
