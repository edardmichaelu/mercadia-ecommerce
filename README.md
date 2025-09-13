# **Marketmerce - Plataforma E-commerce de Código Abierto**

**Marketmerce** es una plataforma de e-commerce de nivel empresarial, diseñada desde cero con una filosofía de **seguridad primero, escalabilidad por diseño y una experiencia de desarrollo excepcional**. Nuestro objetivo es proporcionar una base sólida y de código abierto para construir tiendas en línea robustas, modernas y personalizables, utilizando un stack tecnológico gratuito y de vanguardia.

![Diagrama de la Base de Datos de Marketmerce](https://via.placeholder.com/800x400.png?text=Diagrama+BD+Marketmerce+Completo)

## **🧭 Filosofía y Principios de Diseño**

Marketmerce no es solo un conjunto de funcionalidades; es una arquitectura guiada por principios claros:

1.  **Seguridad Primero (Security-First):** La seguridad no es una característica, es el fundamento. Desde el almacenamiento de contraseñas con hashes robustos (bcrypt) hasta la gestión segura de sesiones y llaves API (almacenando solo hashes), cada decisión de diseño prioriza la protección de los datos del usuario y la integridad de la plataforma.
2.  **Escalabilidad por Diseño (Scalability by Design):** Construido sobre **PostgreSQL**, el esquema utiliza técnicas avanzadas como **particionamiento de tablas** (auditorias, notificaciones) para manejar grandes volúmenes de datos sin degradar el rendimiento. El uso de UUIDs como claves primarias facilita la distribución y federación de la base de datos en el futuro.
3.  **Experiencia de Desarrollador (DX) Superior:** Un equipo feliz construye mejores productos. Utilizamos herramientas como **Next.js** para un desarrollo unificado de frontend y backend, **Prisma** para un acceso a datos tipado y seguro, y un plan de sprints claro para mantener el desarrollo enfocado y predecible.
4.  **Código Abierto y Gratuito:** Creemos en el poder de la comunidad. Todo el stack tecnológico se basa en herramientas de código abierto y servicios con generosas capas gratuitas, permitiendo a desarrolladores y pequeñas empresas lanzar su proyecto con una inversión inicial mínima.

## **📜 Principios de Desarrollo y Calidad de Código**

Para garantizar la calidad, mantenibilidad y escalabilidad del software, todo el desarrollo se regirá por los siguientes principios:

1.  **Modularidad y Cohesión:** El código se organizará en módulos funcionales (usuarios, productos, inventario, etc.) que se correspondan con los sprints. Cada módulo será lo más autocontenido posible para reducir acoplamientos.
2.  **Principio DRY (Don't Repeat Yourself):** Se evitará la duplicación de código a toda costa.
    *   **Frontend:** Se crearán componentes React genéricos y reutilizables (ej. botones, tarjetas, modales) en un directorio `components/ui`.
    *   **Backend:** La lógica de negocio compartida se abstraerá en servicios o utilidades reutilizables.
    *   **Full-stack:** Los tipos de datos y esquemas de validación (Zod) se definirán en un lugar centralizado para ser utilizados tanto por el frontend como por el backend.
3.  **Implementaciones Completas y Robustas:** No se tomarán atajos. Cada funcionalidad desarrollada debe ser completa, incluyendo:
    *   **Validación Estricta:** Toda entrada de datos (API, formularios) será validada rigurosamente con Zod.
    *   **Manejo de Errores:** Se implementará un sistema consistente de manejo y reporte de errores.
    *   **Casos de Borde:** Se considerarán y gestionarán los casos de borde y estados vacíos desde el inicio.
4.  **Uso Adecuado del Stack Tecnológico:** Cada herramienta se usará para el propósito para el que fue diseñada.
    *   **Next.js:** Se priorizará el uso de Server Components para el rendimiento. Las APIs se construirán con Route Handlers. La optimización de imágenes se hará con `next/image`.
    *   **Prisma:** Será la única capa de acceso a la base de datos. Se utilizarán transacciones para operaciones atómicas complejas (ej. crear un pedido y reducir stock).
    *   **React Query / Zustand:** Se usará React Query para gestionar el estado del servidor (fetching, caching, mutaciones) y Zustand para el estado global y efímero del cliente (ej. estado de un modal, contenido del carrito).
5.  **Enfoque en la Experiencia de Usuario (UI/UX) y Rendimiento:**
    *   **Sistema de Diseño:** Se seguirá un sistema de diseño consistente basado en **Tailwind CSS** y los componentes predefinidos de **shadcn/ui**.
    *   **Rendimiento:** El rendimiento es una característica fundamental. Se optimizarán las consultas a la base de datos, se minimizará el tamaño de los bundles de JavaScript y se analizará el rendimiento de la aplicación de forma continua.

## **🛠️ Stack Tecnológico Detallado**
| Categoría | Tecnología/Herramienta | Versión Sugerida | Propósito Principal |
|---|---|---|---|
| Framework Principal | Next.js | 14+ | Desarrollo full-stack con App Router para renderizado híbrido (SSR, SSG, ISR). |
| Lenguaje | TypeScript | 5+ | Tipado estático para robustez y mantenibilidad del código. |
| Base de Datos | PostgreSQL | 15+ | Sistema de gestión de bases de datos relacional, potente y de código abierto. |
| ORM | Prisma | 5+ | ORM de próxima generación para un acceso a datos seguro, intuitivo y tipado. |
| UI Framework | React | 18+ | Biblioteca para construir interfaces de usuario interactivas. |
| Estilos CSS | Tailwind CSS | 3+ | Framework CSS utility-first para un diseño rápido y personalizable. |
| Componentes UI | shadcn/ui | Última | Colección de componentes UI reutilizables, accesibles y personalizables. |
| Animaciones | Framer Motion | 10+ | Biblioteca de animación para React, para crear interfaces fluidas. |
| Autenticación | NextAuth.js | 5+ (Auth.js) | Solución completa para la autenticación en aplicaciones Next.js. |
| Gestión de Estado | Zustand / React Query | 4+ / 5+ | Manejo de estado de cliente y servidor, caching, y sincronización de datos. |
| Despliegue | Docker | 20+ | Contenerización para consistencia entre entornos de desarrollo y producción. |
| Infraestructura Cloud | AWS (RDS, S3, EC2) | N/A | Servicios para base de datos gestionada, almacenamiento de objetos y cómputo. |
| CI/CD | GitHub Actions | N/A | Automatización de flujos de trabajo de integración y despliegue continuo. |
| Reportes | pdfme / SheetJS | Última | Generación de documentos PDF y hojas de cálculo Excel del lado del cliente/servidor. |

## **📁 Estructura del Proyecto (Actualizada)**

La estructura del proyecto se ha adaptado para reflejar un enfoque "schema-first" para la base de datos.

```bash
merketmerce/
├── database/                        # Directorio central para la BD
│   ├── marketmerce.sql              # Script de creación del esquema completo
│   └── insert_and_checks.sql        # Script para poblar datos de prueba y verificar
# ... (resto de la estructura del proyecto se mantiene)
```

## **🗺️ Hoja de Ruta Detallada del Proyecto (Roadmap Granular)**

**Principio de Ejecución:** El desarrollo se llevará a cabo siguiendo un modelo de sprints estrictamente secuencial. **No se comenzará un nuevo sprint hasta que el anterior haya sido completado, probado y aprobado en su totalidad.** Los sprints a continuación representan entregables pequeños y atómicos para garantizar la calidad y el control del progreso.

### **Sprint 0: Fundamentos e Infraestructura**
*   **Objetivo:** Preparar todo el entorno, herramientas y la infraestructura base del proyecto.
*   **Entregables:** Repositorio, CI/CD, Base de Datos PostgreSQL configurada con el esquema de `marketmerce.sql`, Bucket S3, Proyecto Next.js inicializado, Prisma configurado con `prisma db pull`.

### **Sprint 1: Autenticación y Roles de Usuario**
*   **Objetivo:** Construir el núcleo del sistema de registro y login.
*   **Tablas Involucradas:** `usuarios`, `roles`, `sesiones_usuarios`.
*   **Entregables:** API para registro y login, middleware para proteger rutas, UI para formularios de login/registro.

### **Sprint 2: Gestión de Perfiles y Permisos**
*   **Objetivo:** Permitir a los usuarios gestionar su perfil y definir un sistema de permisos.
*   **Tablas Involucradas:** `permisos`, `roles_permisos`, `direcciones_usuarios`, `media` (para avatares), `llaves_api`.
*   **Entregables:** UI para que el usuario edite su perfil y direcciones, flujo para subir avatares, UI de admin para gestionar permisos y llaves API.

### **Sprint 3: Gestión de Catálogo (Base)**
*   **Objetivo:** Crear la base para la gestión de productos.
*   **Tablas Involucradas:** `categorias`, `marcas`, `productos`.
*   **Entregables:** UI de admin para el CRUD (Crear, Leer, Actualizar, Borrar) de categorías y marcas. CRUD básico para productos.

### **Sprint 4: Variantes y Dimensiones de Productos**
*   **Objetivo:** Añadir la capacidad de gestionar variantes complejas y sus propiedades físicas.
*   **Tablas Involucradas:** `variantes_producto`, `unidades_medida`, `historial_precios_variante`.
*   **Entregables:** UI para añadir/editar variantes a un producto (SKU, atributos, precio), gestionar dimensiones (peso, tamaño) y ver el historial de precios.

### **Sprint 5: Contenido Enriquecido del Catálogo**
*   **Objetivo:** Implementar la gestión de imágenes, tags y relaciones entre productos.
*   **Tablas Involucradas:** `media` (para productos), `tags`, `productos_tags`, `productos_categorias`, `productos_relacionados`.
*   **Entregables:** UI para subir múltiples imágenes a un producto (carrusel), sistema para crear y asignar tags, y UI para definir productos relacionados.

### **Sprint 6: Inventario (Ubicaciones y Proveedores)**
*   **Objetivo:** Establecer las bases de la gestión de inventario y abastecimiento.
*   **Tablas Involucradas:** `ubicaciones`, `proveedores`, `ordenes_compra`, `items_orden_compra`.
*   **Entregables:** UI de admin para gestionar almacenes/tiendas, proveedores y crear/administrar órdenes de compra.

### **Sprint 7: Gestión de Stock y Movimientos**
*   **Objetivo:** Implementar el control de stock y su trazabilidad.
*   **Tablas Involucradas:** `stock_ubicacion`, `movimientos_inventario`, `stock_historial`.
*   **Entregables:** Lógica para actualizar el stock al recibir una orden de compra. UI para visualizar el stock por ubicación, realizar ajustes manuales y transferencias. Vista del historial de movimientos.

### **Sprint 8: Carrito de Compras**
*   **Objetivo:** Implementar la funcionalidad de carrito de compras.
*   **Tablas Involucradas:** `carritos`, `items_carrito`.
*   **Entregables:** API y lógica de UI para añadir, actualizar, eliminar y ver ítems en el carrito.

### **Sprint 9: Proceso de Checkout y Creación de Pedidos**
*   **Objetivo:** Permitir a los usuarios convertir su carrito en un pedido real.
*   **Tablas Involucradas:** `pedidos`, `items_pedido`, `historial_estado_pedido`.
*   **Entregables:** UI de checkout con selección de dirección, lógica transaccional para crear el pedido y reservar el stock, y página de historial de pedidos del usuario.

### **Sprint 10: Integración de Pagos**
*   **Objetivo:** Integrar una pasarela de pagos para procesar las compras.
*   **Tablas Involucradas:** `pagos`.
*   **Entregables:** Integración con un SDK de pago (ej. Stripe), y un webhook para recibir la confirmación del pago y actualizar el estado del pedido.

### **Sprint 11: Gestión de Envíos**
*   **Objetivo:** Implementar la logística de envío de los pedidos.
*   **Tablas Involucradas:** `envios`, `historial_envio`.
*   **Entregables:** UI de admin para crear envíos y añadir números de seguimiento. UI para que el cliente vea el estado de su envío.

### **Sprint 12: Reseñas y Devoluciones**
*   **Objetivo:** Implementar funcionalidades post-venta.
*   **Tablas Involucradas:** `resenas_productos`, `devoluciones`, `reembolsos`.
*   **Entregables:** Sistema para que los usuarios dejen reseñas en productos comprados. Flujo completo para solicitar y gestionar devoluciones y reembolsos.

### **Sprint 13: Marketing (Cupones y Promociones)**
*   **Objetivo:** Desarrollar herramientas de marketing para impulsar las ventas.
*   **Tablas Involucradas:** `cupones`, `promociones`.
*   **Entregables:** UI de admin para crear y gestionar cupones y promociones. Lógica para aplicar los descuentos en el carrito.

### **Sprint 14: Operaciones y Configuración del Sitio**
*   **Objetivo:** Implementar funcionalidades administrativas finales.
*   **Tablas Involucradas:** `auditorias`, `notificaciones`, `configuracion_sitio`, `tienda`.
*   **Entregables:** Panel de admin para la configuración general de la tienda. Sistema de notificaciones transaccionales (ej. "Pedido enviado").

### **Sprint 15: Lanzamiento**
*   **Objetivo:** Realizar las pruebas finales y preparar para producción.
*   **Entregables:** Pruebas de carga, optimización de consultas, revisión final de seguridad y despliegue a producción.

## **🚀 Guía de Instalación y Ejecución (Actualizada)**

(La guía de instalación se mantiene sin cambios)

### **Prerrequisitos**

*   **Node.js**: v18.17.0 o superior.
*   **pnpm**: v8.6.0 o superior (instalado con `npm install -g pnpm`).
*   **Docker**: v20.10 o superior.

### **1. Clonar el Repositorio**

```bash
git clone https://github.com/TU_USUARIO/TU_REPO.git
cd TU_REPO
```

### **2. Configurar Variables de Entorno**

Copia el archivo `.env.example` a `.env` y rellena las variables, especialmente las de la base de datos (`DATABASE_URL`).

```bash
cp .env.example .env
```

### **3. Levantar la Base de Datos con Docker**

```bash
docker-compose up -d
```

### **4. Aplicar Esquema y Datos de Prueba**

Usa `psql` u otra herramienta para ejecutar los scripts SQL en la base de datos creada por Docker.

```bash
# Ejecutar el esquema principal
psql -U user -d marketmerce_db -h localhost -f database/marketmerce.sql

# Insertar datos de prueba
psql -U user -d marketmerce_db -h localhost -f database/insert_and_checks.sql
```

### **5. Sincronizar Prisma con la Base de Datos**

En lugar de crear migraciones, Prisma introspeccionará el esquema que ya creaste.

```bash
# Instalar dependencias del proyecto
pnpm install

# Introspeccionar la base de datos
pnpm prisma db pull

# Generar el cliente de Prisma
pnpm prisma generate
```

### **6. Ejecutar la Aplicación**

```bash
pnpm dev
```

## **🤝 Contribuciones**

¡Las contribuciones son bienvenidas! Si quieres ayudar, por favor sigue el flujo de trabajo estándar de Fork & Pull Request.

## **📜 Licencia**

Este proyecto está bajo la **Licencia MIT**. Consulta el archivo LICENSE para más detalles.
