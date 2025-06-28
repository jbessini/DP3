-- ================================================
-- DP-3 E-COMMERCE DATABASE INITIALIZATION SCRIPT
-- ================================================
-- Script para inicializar la base de datos PostgreSQL
-- con la estructura de tablas y datos de prueba

-- Crear la tabla productos
CREATE TABLE IF NOT EXISTS productos (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para actualizar updated_at en cada UPDATE
DROP TRIGGER IF EXISTS update_productos_updated_at ON productos;
CREATE TRIGGER update_productos_updated_at
    BEFORE UPDATE ON productos
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Crear índices para mejorar performance
CREATE INDEX IF NOT EXISTS idx_productos_category ON productos(category);
CREATE INDEX IF NOT EXISTS idx_productos_name ON productos(name);
CREATE INDEX IF NOT EXISTS idx_productos_stock ON productos(stock);

-- Insertar datos de prueba si la tabla está vacía
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM productos LIMIT 1) THEN
        INSERT INTO productos (name, category, price, stock) VALUES
        ('Vitamina C 1000mg', 'Vitaminas', 15.99, 50),
        ('Vitamina D3 5000 IU', 'Vitaminas', 18.99, 45),
        ('Complejo B-100', 'Vitaminas', 22.99, 35),
        ('Vitamina E 400 IU', 'Vitaminas', 16.99, 40),
        ('Omega-3 Fish Oil 1000mg', 'Omega', 24.99, 30),
        ('Omega-3 Vegano (Algas)', 'Omega', 32.99, 25),
        ('Krill Oil Premium', 'Omega', 38.99, 20),
        ('Proteína Whey Chocolate', 'Proteínas', 45.99, 25),
        ('Proteína Vegana Vainilla', 'Proteínas', 42.99, 30),
        ('Colágeno Hidrolizado', 'Proteínas', 28.99, 35),
        ('Magnesio 400mg', 'Minerales', 12.99, 40),
        ('Zinc 50mg', 'Minerales', 14.99, 45),
        ('Calcio + Vitamina D', 'Minerales', 19.99, 38),
        ('Hierro Quelado 28mg', 'Minerales', 16.99, 42),
        ('Antioxidantes Complexo', 'Antioxidantes', 19.99, 45),
        ('Resveratrol 500mg', 'Antioxidantes', 26.99, 28),
        ('Curcumina + Pimienta', 'Antioxidantes', 21.99, 32),
        ('Probióticos 50 Billones', 'Probióticos', 29.99, 35),
        ('Prebióticos + Probióticos', 'Probióticos', 34.99, 25),
        ('Enzimas Digestivas', 'Probióticos', 23.99, 40),
        ('CoQ10 100mg', 'Energía', 31.99, 30),
        ('Ginseng Rojo Coreano', 'Energía', 27.99, 33),
        ('Vitaminas del Complejo B', 'Energía', 18.99, 38),
        ('Vitamina C + Zinc', 'Inmunidad', 17.99, 50),
        ('Echinacea 1000mg', 'Inmunidad', 15.99, 45),
        ('Própolis + Miel', 'Inmunidad', 22.99, 35);

        RAISE NOTICE 'Datos de prueba insertados exitosamente';
    ELSE
        RAISE NOTICE 'La tabla productos ya contiene datos, omitiendo inserción';
    END IF;
END $$;

-- Crear vista para analytics (para BigQuery)
CREATE OR REPLACE VIEW productos_analytics AS
SELECT 
    id,
    name,
    category,
    price,
    stock,
    CASE 
        WHEN stock = 0 THEN 'Agotado'
        WHEN stock < 10 THEN 'Stock Bajo'
        WHEN stock < 30 THEN 'Stock Normal'
        ELSE 'Stock Alto'
    END as stock_status,
    CASE 
        WHEN price < 50 THEN 'Económico'
        WHEN price < 200 THEN 'Medio'
        WHEN price < 500 THEN 'Premium'
        ELSE 'Lujo'
    END as price_category,
    created_at,
    updated_at,
    CURRENT_TIMESTAMP as sync_timestamp
FROM productos;

-- Mostrar estadísticas finales
DO $$
DECLARE
    total_products INTEGER;
    total_categories INTEGER;
    avg_price DECIMAL(10,2);
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT category), AVG(price)
    INTO total_products, total_categories, avg_price
    FROM productos;
    
    RAISE NOTICE '=== ESTADÍSTICAS DE LA BASE DE DATOS ===';
    RAISE NOTICE 'Total de productos: %', total_products;
    RAISE NOTICE 'Total de categorías: %', total_categories;
    RAISE NOTICE 'Precio promedio: $%', avg_price;
    RAISE NOTICE '========================================';
END $$;

-- Verificar que todo está correcto
SELECT 
    'productos' as tabla,
    COUNT(*) as total_registros,
    COUNT(DISTINCT category) as categorias_unicas,
    MIN(price) as precio_minimo,
    MAX(price) as precio_maximo,
    AVG(price)::DECIMAL(10,2) as precio_promedio
FROM productos;