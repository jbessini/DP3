#!/usr/bin/env python3
"""
DP-3 E-commerce System Test Script
==================================
Script para probar todos los componentes del sistema:
- Conectividad de base de datos
- Funciones Lambda (vía API Gateway)
- Frontend Flask
- Integración completa

Uso:
    python test_system.py [--api-url API_GATEWAY_URL] [--frontend-url FRONTEND_URL]
"""

import os
import sys
import argparse
import requests
import psycopg2
import json
import time
import logging
from pathlib import Path

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SystemTester:
    def __init__(self, api_gateway_url=None, frontend_url=None):
        self.api_gateway_url = api_gateway_url
        self.frontend_url = frontend_url
        self.test_results = {}
        
    def test_database_connectivity(self):
        """Probar conectividad con PostgreSQL"""
        logger.info("🗃️  Probando conectividad con PostgreSQL...")
        
        try:
            conn = psycopg2.connect(
                host=os.getenv('DB_HOST'),
                port=os.getenv('DB_PORT', '5432'),
                database=os.getenv('DB_NAME', 'ecommercedb'),
                user=os.getenv('DB_USER'),
                password=os.getenv('DB_PASSWORD')
            )
            
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM productos;")
            count = cursor.fetchone()[0]
            
            cursor.close()
            conn.close()
            
            logger.info(f"✅ PostgreSQL: Conectividad exitosa ({count} productos)")
            self.test_results['database'] = True
            return True
            
        except Exception as e:
            logger.error(f"❌ PostgreSQL: Error de conectividad - {e}")
            self.test_results['database'] = False
            return False
    
    def test_lambda_functions(self):
        """Probar todas las funciones Lambda vía API Gateway"""
        if not self.api_gateway_url:
            logger.warning("⚠️  API Gateway URL no proporcionada, omitiendo pruebas Lambda")
            return False
        
        logger.info("🔧 Probando funciones Lambda...")
        
        # Test 1: GetProducts
        success_count = 0
        total_tests = 3
        
        try:
            logger.info("📋 Probando GetProducts...")
            response = requests.get(f"{self.api_gateway_url}/products", timeout=30)
            response.raise_for_status()
            products = response.json()
            
            if isinstance(products, list) and len(products) > 0:
                logger.info(f"✅ GetProducts: {len(products)} productos obtenidos")
                success_count += 1
            else:
                logger.warning("⚠️  GetProducts: Respuesta vacía o inválida")
                
        except Exception as e:
            logger.error(f"❌ GetProducts: Error - {e}")
        
        # Test 2: AddProduct
        try:
            logger.info("➕ Probando AddProduct...")
            test_product = {
                "name": f"Producto Test {int(time.time())}",
                "category": "Test",
                "price": 99.99,
                "stock": 10
            }
            
            response = requests.post(
                f"{self.api_gateway_url}/add",
                json=test_product,
                timeout=30
            )
            response.raise_for_status()
            result = response.json()
            
            if response.status_code == 201:
                logger.info("✅ AddProduct: Producto creado exitosamente")
                success_count += 1
                # Guardar ID para próximo test
                self.test_product_id = result.get('product', {}).get('id')
            else:
                logger.warning("⚠️  AddProduct: Respuesta inesperada")
                
        except Exception as e:
            logger.error(f"❌ AddProduct: Error - {e}")
        
        # Test 3: GetItem (si tenemos un ID de producto)
        try:
            if hasattr(self, 'test_product_id') and self.test_product_id:
                logger.info("🔍 Probando GetItem...")
                response = requests.get(
                    f"{self.api_gateway_url}/item?id={self.test_product_id}",
                    timeout=30
                )
                response.raise_for_status()
                product = response.json()
                
                if product.get('id') == self.test_product_id:
                    logger.info("✅ GetItem: Producto obtenido exitosamente")
                    success_count += 1
                else:
                    logger.warning("⚠️  GetItem: Producto no encontrado")
            else:
                logger.info("🔍 Probando GetItem con ID=1...")
                response = requests.get(f"{self.api_gateway_url}/item?id=1", timeout=30)
                response.raise_for_status()
                product = response.json()
                
                if product.get('id'):
                    logger.info("✅ GetItem: Producto obtenido exitosamente")
                    success_count += 1
                    
        except Exception as e:
            logger.error(f"❌ GetItem: Error - {e}")
        
        logger.info(f"🔧 Lambda Functions: {success_count}/{total_tests} pruebas exitosas")
        self.test_results['lambda'] = success_count == total_tests
        return success_count == total_tests
    
    def test_frontend_flask(self):
        """Probar frontend Flask"""
        if not self.frontend_url:
            logger.warning("⚠️  Frontend URL no proporcionada, omitiendo pruebas Frontend")
            return False
        
        logger.info("🌐 Probando Frontend Flask...")
        
        try:
            # Test health endpoint
            response = requests.get(f"{self.frontend_url}/health", timeout=30)
            response.raise_for_status()
            health = response.json()
            
            if health.get('status') == 'healthy':
                logger.info("✅ Frontend Health: Saludable")
                
                # Test página principal
                response = requests.get(self.frontend_url, timeout=30)
                response.raise_for_status()
                
                if response.status_code == 200:
                    logger.info("✅ Frontend Main Page: Accesible")
                    self.test_results['frontend'] = True
                    return True
                    
        except Exception as e:
            logger.error(f"❌ Frontend: Error - {e}")
        
        self.test_results['frontend'] = False
        return False
    
    def test_integration(self):
        """Probar integración completa del sistema"""
        logger.info("🔗 Probando integración completa...")
        
        if not all([self.api_gateway_url, self.frontend_url]):
            logger.warning("⚠️  URLs incompletas para prueba de integración")
            return False
        
        try:
            # Probar que el frontend puede obtener productos desde API
            response = requests.get(f"{self.frontend_url}/api/products", timeout=30)
            response.raise_for_status()
            products = response.json()
            
            if isinstance(products, list):
                logger.info(f"✅ Integración: Frontend puede acceder a {len(products)} productos vía API")
                self.test_results['integration'] = True
                return True
                
        except Exception as e:
            logger.error(f"❌ Integración: Error - {e}")
        
        self.test_results['integration'] = False
        return False
    
    def run_all_tests(self):
        """Ejecutar todas las pruebas del sistema"""
        logger.info("=" * 60)
        logger.info("🚀 INICIANDO PRUEBAS COMPLETAS DEL SISTEMA DP-3")
        logger.info("=" * 60)
        
        start_time = time.time()
        
        # Ejecutar todas las pruebas
        self.test_database_connectivity()
        self.test_lambda_functions()
        self.test_frontend_flask()
        self.test_integration()
        
        # Resumen de resultados
        end_time = time.time()
        duration = end_time - start_time
        
        logger.info("=" * 60)
        logger.info("📊 RESUMEN DE PRUEBAS")
        logger.info("=" * 60)
        
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results.values() if result)
        
        for test_name, result in self.test_results.items():
            status = "✅ PASS" if result else "❌ FAIL"
            logger.info(f"{test_name.upper()}: {status}")
        
        logger.info("-" * 60)
        logger.info(f"📈 Total: {passed_tests}/{total_tests} pruebas exitosas")
        logger.info(f"⏱️  Duración: {duration:.2f} segundos")
        
        if passed_tests == total_tests:
            logger.info("🎉 ¡TODAS LAS PRUEBAS EXITOSAS! Sistema funcionando correctamente")
            return True
        else:
            logger.warning("⚠️  ALGUNAS PRUEBAS FALLARON. Revisar logs para detalles")
            return False

def get_config():
    """Obtener configuración desde argumentos o variables de entorno"""
    parser = argparse.ArgumentParser(description='Test DP-3 E-commerce System')
    
    parser.add_argument('--api-url', 
                       default=os.getenv('API_GATEWAY_URL'),
                       help='API Gateway URL (default: API_GATEWAY_URL env var)')
    
    parser.add_argument('--frontend-url', 
                       default=os.getenv('FRONTEND_URL'),
                       help='Frontend URL (default: FRONTEND_URL env var)')
    
    parser.add_argument('--verbose', '-v', 
                       action='store_true',
                       help='Verbose output')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    return args

def main():
    """Función principal"""
    try:
        config = get_config()
        
        logger.info("🔧 Configuración de pruebas:")
        logger.info(f"  API Gateway: {config.api_url or 'No configurado'}")
        logger.info(f"  Frontend: {config.frontend_url or 'No configurado'}")
        logger.info("")
        
        tester = SystemTester(
            api_gateway_url=config.api_url,
            frontend_url=config.frontend_url
        )
        
        success = tester.run_all_tests()
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        logger.info("\n⚠️  Pruebas canceladas por el usuario")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Error inesperado: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()