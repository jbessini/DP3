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
    Lambda function: getProducts
    Devuelve todos los productos de la base de datos PostgreSQL
    """
    try:
        # Conectar a la base de datos
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Ejecutar consulta
        cursor.execute("""
            SELECT id, name, category, price, stock, created_at, updated_at 
            FROM productos 
            ORDER BY id ASC
        """)
        rows = cursor.fetchall()
        
        # Convertir a formato JSON
        products = []
        for row in rows:
            products.append({
                'id': row[0],
                'name': row[1],
                'category': row[2],
                'price': float(row[3]),
                'stock': row[4],
                'created_at': row[5].isoformat() if row[5] else None,
                'updated_at': row[6].isoformat() if row[6] else None
            })
        
        # Cerrar conexión
        cursor.close()
        conn.close()
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps(products)
        }
        
    except Exception as e:
        print(f"ERROR in getProducts: {str(e)}")
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