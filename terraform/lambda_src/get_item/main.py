import json
import os
import pg8000.dbapi

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
    Lambda function: getItem
    Devuelve un producto por ID o procesa una compra
    """
    try:
        # Obtener parámetros dependiendo del método HTTP
        if event.get('httpMethod') == 'GET':
            # Obtener producto por ID desde query parameters
            product_id = event.get('queryStringParameters', {}).get('id')
            if not product_id:
                return {
                    'statusCode': 400,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'error': 'Parámetro id requerido'
                    })
                }
            
            # Conectar y obtener producto
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT id, name, category, price, stock, created_at, updated_at 
                FROM productos 
                WHERE id = %s
            """, (int(product_id),))
            
            row = cursor.fetchone()
            cursor.close()
            conn.close()
            
            if not row:
                return {
                    'statusCode': 404,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'error': 'Producto no encontrado'
                    })
                }
            
            product = {
                'id': row[0],
                'name': row[1],
                'category': row[2],
                'price': float(row[3]),
                'stock': row[4],
                'created_at': row[5].isoformat() if row[5] else None,
                'updated_at': row[6].isoformat() if row[6] else None
            }
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps(product)
            }
        
        elif event.get('httpMethod') == 'POST':
            # Procesar compra
            body = json.loads(event.get('body', '{}'))
            product_id = body.get('product_id')
            quantity = int(body.get('quantity', 1))
            
            if not product_id:
                return {
                    'statusCode': 400,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'error': 'product_id requerido'
                    })
                }
            
            # Conectar y procesar transacción
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Iniciar transacción explícita
            cursor.execute("BEGIN")
            
            try:
                # Verificar stock actual con lock
                cursor.execute("""
                    SELECT id, name, stock 
                    FROM productos 
                    WHERE id = %s 
                    FOR UPDATE
                """, (int(product_id),))
                
                product_data = cursor.fetchone()
                
                if not product_data:
                    cursor.execute("ROLLBACK")
                    return {
                        'statusCode': 404,
                        'headers': {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*'
                        },
                        'body': json.dumps({
                            'error': 'Producto no encontrado'
                        })
                    }
                
                current_stock = product_data[2]
                product_name = product_data[1]
                
                if current_stock < quantity:
                    cursor.execute("ROLLBACK")
                    return {
                        'statusCode': 409,
                        'headers': {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*'
                        },
                        'body': json.dumps({
                            'error': f'Stock insuficiente. Disponible: {current_stock}'
                        })
                    }
                
                # Actualizar stock
                new_stock = current_stock - quantity
                cursor.execute("""
                    UPDATE productos 
                    SET stock = %s, updated_at = CURRENT_TIMESTAMP 
                    WHERE id = %s
                """, (new_stock, int(product_id)))
                
                # Confirmar transacción
                cursor.execute("COMMIT")
                cursor.close()
                conn.close()
                
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'message': f'Compra exitosa de {quantity} unidad(es) de {product_name}',
                        'product_id': int(product_id),
                        'quantity_purchased': quantity,
                        'new_stock': new_stock
                    })
                }
                
            except Exception as transaction_error:
                cursor.execute("ROLLBACK")
                cursor.close()
                conn.close()
                raise transaction_error
        
        else:
            return {
                'statusCode': 405,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Método no permitido'
                })
            }
            
    except Exception as e:
        print(f"ERROR in getItem: {str(e)}")
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