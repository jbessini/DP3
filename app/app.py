import os
import requests
import logging
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', os.urandom(24))

# La URL del API Gateway se inyecta como variable de entorno desde Terraform
API_GATEWAY_URL = os.environ.get('API_GATEWAY_URL', '')

def make_api_request(method, endpoint, data=None, timeout=30):
    """
    Helper function para hacer peticiones al API Gateway
    """
    if not API_GATEWAY_URL:
        raise Exception("API_GATEWAY_URL no configurada")
    
    url = f"{API_GATEWAY_URL.rstrip('/')}/{endpoint.lstrip('/')}"
    
    try:
        if method.upper() == 'GET':
            response = requests.get(url, timeout=timeout)
        elif method.upper() == 'POST':
            response = requests.post(url, json=data, timeout=timeout)
        else:
            raise Exception(f"Método HTTP no soportado: {method}")
        
        response.raise_for_status()
        return response.json()
        
    except requests.exceptions.Timeout:
        raise Exception("Timeout al conectar con el API")
    except requests.exceptions.ConnectionError:
        raise Exception("Error de conexión con el API")
    except requests.exceptions.HTTPError as e:
        try:
            error_data = e.response.json()
            raise Exception(error_data.get('error', f'Error HTTP {e.response.status_code}'))
        except:
            raise Exception(f'Error HTTP {e.response.status_code}')
    except Exception as e:
        raise Exception(f"Error inesperado: {str(e)}")

@app.route('/')
def index():
    """Página principal del e-commerce"""
    products = []
    try:
        if API_GATEWAY_URL:
            products = make_api_request('GET', '/products')
            logger.info(f"Cargados {len(products)} productos exitosamente")
        else:
            flash("API Gateway no configurado", "warning")
            
    except Exception as e:
        error_msg = f"Error al cargar productos: {str(e)}"
        logger.error(error_msg)
        flash(error_msg, "danger")
    
    return render_template('index.html', products=products)

@app.route('/add', methods=['POST'])
def add_product():
    """Añadir un nuevo producto"""
    try:
        # Validar datos del formulario
        name = request.form.get('name', '').strip()
        category = request.form.get('category', '').strip()
        price = request.form.get('price', '')
        stock = request.form.get('stock', '')
        
        if not all([name, category, price, stock]):
            flash("Todos los campos son requeridos", "danger")
            return redirect(url_for('index'))
        
        # Preparar datos para el API
        product_data = {
            "name": name,
            "category": category,
            "price": float(price),
            "stock": int(stock)
        }
        
        # Llamar al API
        result = make_api_request('POST', '/add', product_data)
        
        success_msg = result.get('message', 'Producto añadido exitosamente')
        flash(success_msg, "success")
        logger.info(f"Producto añadido: {name}")
        
    except ValueError as e:
        flash("Precio y stock deben ser números válidos", "danger")
    except Exception as e:
        error_msg = f"Error al añadir producto: {str(e)}"
        logger.error(error_msg)
        flash(error_msg, "danger")
    
    return redirect(url_for('index'))

@app.route('/buy', methods=['POST'])
def buy_product():
    """Procesar compra de un producto"""
    try:
        product_id = request.form.get('product_id')
        quantity = int(request.form.get('quantity', 1))
        
        if not product_id:
            flash("ID de producto inválido", "danger")
            return redirect(url_for('index'))
        
        # Preparar datos para el API
        buy_data = {
            "product_id": int(product_id),
            "quantity": quantity
        }
        
        # Llamar al API (endpoint /item con POST para compras)
        result = make_api_request('POST', '/item', buy_data)
        
        success_msg = result.get('message', 'Compra exitosa')
        flash(success_msg, "success")
        logger.info(f"Compra procesada: Producto {product_id}, Cantidad {quantity}")
        
    except ValueError as e:
        flash("Datos de compra inválidos", "danger")
    except Exception as e:
        error_msg = f"Error en la compra: {str(e)}"
        logger.error(error_msg)
        flash(error_msg, "danger")
    
    return redirect(url_for('index'))

@app.route('/health')
def health_check():
    """Health check endpoint para Cloud Run"""
    try:
        # Verificar conectividad con API Gateway
        api_status = "unknown"
        if API_GATEWAY_URL:
            try:
                make_api_request('GET', '/products')
                api_status = "healthy"
            except:
                api_status = "unhealthy"
        
        return jsonify({
            'status': 'healthy',
            'service': 'DP-3 E-commerce Frontend',
            'api_gateway_status': api_status,
            'api_gateway_url': API_GATEWAY_URL if API_GATEWAY_URL else 'not_configured'
        }), 200
        
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500

@app.route('/api/products')
def api_products():
    """API endpoint para obtener productos (para uso programático)"""
    try:
        products = make_api_request('GET', '/products')
        return jsonify(products)
    except Exception as e:
        logger.error(f"API products error: {str(e)}")
        return jsonify({
            'error': str(e)
        }), 500

@app.route('/api/product/<int:product_id>')
def api_product_detail(product_id):
    """API endpoint para obtener un producto específico"""
    try:
        # Hacer petición GET al endpoint /item con query parameter
        url = f"/item?id={product_id}"
        product = make_api_request('GET', url)
        return jsonify(product)
    except Exception as e:
        logger.error(f"API product detail error: {str(e)}")
        return jsonify({
            'error': str(e)
        }), 500

@app.errorhandler(404)
def not_found_error(error):
    """Manejador de errores 404"""
    flash("Página no encontrada", "warning")
    return redirect(url_for('index'))

@app.errorhandler(500)
def internal_error(error):
    """Manejador de errores 500"""
    logger.error(f"Error interno: {str(error)}")
    flash("Error interno del servidor", "danger")
    return redirect(url_for('index'))

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Iniciando aplicación en puerto {port}")
    logger.info(f"API Gateway URL: {API_GATEWAY_URL}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)