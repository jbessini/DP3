import json
import os
import pg8000.dbapi
from decimal import Decimal

def get_db_connection():
    """Establece conexión con PostgreSQL RDS"""
    return pg8000.dbapi.connect(
        host=os.environ.get('DB_HOST'),
        user=os.environ.get('DB_USER'),
        password=os.environ.get('DB_PASSWORD'),
        database=os.environ.get('DB_NAME'),
        port=5432
    )

def lambda_handler(event, context):
    """
    Lambda function: addProduct
    Inserta un nuevo producto en la tabla productos
    """
    try:
        # Parsear el body de la petición
        body = json.loads(event.get('body', '{}'))
        
        # Validar campos requeridos
        required_fields = ['name', 'category', 'price', 'stock']
        missing_fields = [field for field in required_fields if field not in body]
        
        if missing_fields:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': f'Campos requeridos faltantes: {", ".join(missing_fields)}'
                })
            }
        
        # Validar tipos de datos
        try:
            name = str(body['name']).strip()
            category = str(body['category']).strip()
            price = float(body['price'])
            stock = int(body['stock'])
            
            # Validaciones adicionales
            if not name or len(name) > 255:
                raise ValueError("El nombre debe tener entre 1 y 255 caracteres")
            
            if not category or len(category) > 100:
                raise ValueError("La categoría debe tener entre 1 y 100 caracteres")
            
            if price <= 0:
                raise ValueError("El precio debe ser mayor que 0")
            
            if stock < 0:
                raise ValueError("El stock no puede ser negativo")
                
        except (ValueError, TypeError) as validation_error:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': f'Datos inválidos: {str(validation_error)}'
                })
            }
        
        # Conectar a la base de datos
        conn = get_db_connection()
        cursor = conn.cursor()
        
        try:
            # Insertar el producto
            insert_query = """
                INSERT INTO productos (name, category, price, stock, created_at, updated_at) 
                VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                RETURNING id, name, category, price, stock, created_at, updated_at
            """
            
            cursor.execute(insert_query, (name, category, price, stock))
            new_product = cursor.fetchone()
            conn.commit()
            
            # Formatear respuesta
            product_data = {
                'id': new_product[0],
                'name': new_product[1],
                'category': new_product[2],
                'price': float(new_product[3]),
                'stock': new_product[4],
                'created_at': new_product[5].isoformat() if new_product[5] else None,
                'updated_at': new_product[6].isoformat() if new_product[6] else None
            }
            
            cursor.close()
            conn.close()
            
            return {
                'statusCode': 201,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type'
                },
                'body': json.dumps({
                    'message': f'Producto "{name}" creado exitosamente',
                    'product': product_data
                })
            }
            
        except Exception as db_error:
            conn.rollback()
            cursor.close()
            conn.close()
            
            # Verificar si es un error de duplicado (si hay índice único en name)
            if 'duplicate key' in str(db_error).lower():
                return {
                    'statusCode': 409,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'error': 'Ya existe un producto con ese nombre'
                    })
                }
            
            raise db_error
            
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'JSON inválido en el body de la petición'
            })
        }
        
    except Exception as e:
        print(f"ERROR in addProduct: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Error interno del servidor',
                'message': str(e)
            })
        }