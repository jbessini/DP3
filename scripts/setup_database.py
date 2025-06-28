#!/usr/bin/env python3
"""
DP-3 E-commerce Database Setup Script
=====================================
Script para configurar automáticamente la base de datos PostgreSQL
con la estructura de tablas y datos de prueba.

Uso:
    python setup_database.py [--host HOST] [--port PORT] [--database DB] [--user USER] [--password PASS]
    
    O usando variables de entorno:
    DB_HOST=your-host DB_USER=your-user DB_PASSWORD=your-pass python setup_database.py
"""

import os
import sys
import argparse
import psycopg2
from psycopg2 import sql
import logging
from pathlib import Path

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DatabaseSetup:
    def __init__(self, host, port, database, user, password):
        self.host = host
        self.port = port
        self.database = database
        self.user = user
        self.password = password
        self.connection = None
        
    def connect(self):
        """Conectar a la base de datos PostgreSQL"""
        try:
            self.connection = psycopg2.connect(
                host=self.host,
                port=self.port,
                database=self.database,
                user=self.user,
                password=self.password
            )
            self.connection.autocommit = True
            logger.info(f"✅ Conexión exitosa a PostgreSQL: {self.host}:{self.port}/{self.database}")
            return True
            
        except psycopg2.Error as e:
            logger.error(f"❌ Error conectando a PostgreSQL: {e}")
            return False
    
    def disconnect(self):
        """Cerrar conexión a la base de datos"""
        if self.connection:
            self.connection.close()
            logger.info("🔌 Conexión cerrada")
    
    def test_connection(self):
        """Probar la conexión y mostrar información de la BD"""
        try:
            cursor = self.connection.cursor()
            
            # Obtener versión de PostgreSQL
            cursor.execute("SELECT version();")
            version = cursor.fetchone()[0]
            logger.info(f"📊 Versión PostgreSQL: {version.split(',')[0]}")
            
            # Obtener nombre de la base de datos actual
            cursor.execute("SELECT current_database();")
            current_db = cursor.fetchone()[0]
            logger.info(f"🗃️  Base de datos actual: {current_db}")
            
            # Listar tablas existentes
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                ORDER BY table_name;
            """)
            tables = cursor.fetchall()
            
            if tables:
                logger.info(f"📋 Tablas existentes: {', '.join([t[0] for t in tables])}")
            else:
                logger.info("📋 No hay tablas en el esquema public")
            
            cursor.close()
            return True
            
        except psycopg2.Error as e:
            logger.error(f"❌ Error probando conexión: {e}")
            return False
    
    def execute_sql_file(self, sql_file_path):
        """Ejecutar un archivo SQL"""
        try:
            if not os.path.exists(sql_file_path):
                logger.error(f"❌ Archivo SQL no encontrado: {sql_file_path}")
                return False
            
            with open(sql_file_path, 'r', encoding='utf-8') as file:
                sql_content = file.read()
            
            cursor = self.connection.cursor()
            cursor.execute(sql_content)
            cursor.close()
            
            logger.info(f"✅ Archivo SQL ejecutado exitosamente: {sql_file_path}")
            return True
            
        except psycopg2.Error as e:
            logger.error(f"❌ Error ejecutando SQL: {e}")
            return False
        except Exception as e:
            logger.error(f"❌ Error leyendo archivo: {e}")
            return False
    
    def verify_setup(self):
        """Verificar que la configuración fue exitosa"""
        try:
            cursor = self.connection.cursor()
            
            # Verificar que la tabla productos existe
            cursor.execute("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_schema = 'public' 
                    AND table_name = 'productos'
                );
            """)
            
            table_exists = cursor.fetchone()[0]
            
            if not table_exists:
                logger.error("❌ La tabla 'productos' no fue creada")
                return False
            
            # Contar productos
            cursor.execute("SELECT COUNT(*) FROM productos;")
            product_count = cursor.fetchone()[0]
            
            # Obtener estadísticas
            cursor.execute("""
                SELECT 
                    COUNT(*) as total,
                    COUNT(DISTINCT category) as categories,
                    AVG(price)::DECIMAL(10,2) as avg_price,
                    MIN(price) as min_price,
                    MAX(price) as max_price
                FROM productos;
            """)
            
            stats = cursor.fetchone()
            
            logger.info("=" * 50)
            logger.info("📊 RESUMEN DE CONFIGURACIÓN")
            logger.info("=" * 50)
            logger.info(f"✅ Tabla 'productos' creada correctamente")
            logger.info(f"📦 Total de productos: {stats[0]}")
            logger.info(f"🏷️  Categorías únicas: {stats[1]}")
            logger.info(f"💰 Precio promedio: ${stats[2]}")
            logger.info(f"💸 Rango de precios: ${stats[3]} - ${stats[4]}")
            logger.info("=" * 50)
            
            cursor.close()
            return True
            
        except psycopg2.Error as e:
            logger.error(f"❌ Error verificando configuración: {e}")
            return False
    
    def setup_database(self):
        """Ejecutar setup completo de la base de datos"""
        logger.info("🚀 Iniciando configuración de base de datos DP-3...")
        
        if not self.connect():
            return False
        
        if not self.test_connection():
            return False
        
        # Buscar archivo SQL de inicialización
        script_dir = Path(__file__).parent
        sql_file = script_dir / "init_database.sql"
        
        logger.info(f"📄 Ejecutando script SQL: {sql_file}")
        
        if not self.execute_sql_file(sql_file):
            return False
        
        if not self.verify_setup():
            return False
        
        logger.info("🎉 ¡Configuración de base de datos completada exitosamente!")
        self.disconnect()
        return True

def get_db_config():
    """Obtener configuración de base de datos desde argumentos o variables de entorno"""
    parser = argparse.ArgumentParser(description='Setup DP-3 E-commerce Database')
    
    parser.add_argument('--host', default=os.getenv('DB_HOST'), 
                       help='PostgreSQL host (default: DB_HOST env var)')
    parser.add_argument('--port', default=os.getenv('DB_PORT', '5432'), 
                       help='PostgreSQL port (default: 5432)')
    parser.add_argument('--database', default=os.getenv('DB_NAME', 'ecommercedb'), 
                       help='Database name (default: ecommercedb)')
    parser.add_argument('--user', default=os.getenv('DB_USER'), 
                       help='PostgreSQL user (default: DB_USER env var)')
    parser.add_argument('--password', default=os.getenv('DB_PASSWORD'), 
                       help='PostgreSQL password (default: DB_PASSWORD env var)')
    
    args = parser.parse_args()
    
    # Validar parámetros requeridos
    if not args.host:
        logger.error("❌ Host de PostgreSQL requerido (--host o DB_HOST)")
        sys.exit(1)
    
    if not args.user:
        logger.error("❌ Usuario de PostgreSQL requerido (--user o DB_USER)")
        sys.exit(1)
    
    if not args.password:
        logger.error("❌ Contraseña de PostgreSQL requerida (--password o DB_PASSWORD)")
        sys.exit(1)
    
    return args

def main():
    """Función principal"""
    try:
        config = get_db_config()
        
        setup = DatabaseSetup(
            host=config.host,
            port=config.port,
            database=config.database,
            user=config.user,
            password=config.password
        )
        
        success = setup.setup_database()
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        logger.info("\n⚠️  Operación cancelada por el usuario")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Error inesperado: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()