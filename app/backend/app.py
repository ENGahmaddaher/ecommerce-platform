import os
import json
import logging
import boto3
import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, jsonify, request
from functools import wraps
import time

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_NAME = os.environ.get('DB_NAME', 'ecommerce')
DB_USER = os.environ.get('DB_USER', 'postgres')
DB_SECRET_NAME = os.environ.get('DB_SECRET_NAME', f'{ENVIRONMENT}-db-password')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')

def get_db_password():
    try:
        session = boto3.session.Session()
        client = session.client(service_name='secretsmanager', region_name=AWS_REGION)
        response = client.get_secret_value(SecretId=DB_SECRET_NAME)
        return response['SecretString']
    except Exception as e:
        logger.error(f"Error getting secret: {e}")
        return None

def get_db_connection():
    password = get_db_password()
    if not password:
        raise Exception("Could not get database password")
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=password,
        connect_timeout=5
    )

def init_database():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS products (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                price DECIMAL(10,2) NOT NULL,
                stock INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS orders (
                id SERIAL PRIMARY KEY,
                customer_name VARCHAR(255) NOT NULL,
                customer_email VARCHAR(255) NOT NULL,
                total DECIMAL(10,2) NOT NULL,
                status VARCHAR(50) DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS order_items (
                id SERIAL PRIMARY KEY,
                order_id INTEGER REFERENCES orders(id),
                product_id INTEGER REFERENCES products(id),
                quantity INTEGER NOT NULL,
                price DECIMAL(10,2) NOT NULL
            )
        """)
        cur.execute("SELECT COUNT(*) FROM products")
        if cur.fetchone()[0] == 0:
            sample_products = [
                ("Laptop Pro", "High performance laptop", 1299.99, 10),
                ("Smartphone X", "6.5 inch screen", 699.99, 25),
                ("Wireless Headphones", "Noise cancelling", 89.99, 50),
                ("Smart Watch", "Heart rate monitor", 199.99, 15),
                ("Fast Charger", "65W fast charging", 29.99, 100),
            ]
            for p in sample_products:
                cur.execute("INSERT INTO products (name, description, price, stock) VALUES (%s,%s,%s,%s)", p)
        conn.commit()
        cur.close()
        conn.close()
        logger.info("Database initialized")
    except Exception as e:
        logger.error(f"Database init error: {e}")

def timing(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        start = time.time()
        result = f(*args, **kwargs)
        end = time.time()
        logger.info(f"{f.__name__} took {end-start:.4f}s")
        return result
    return decorated

@app.route('/')
def home():
    return jsonify({"name": "E-Commerce API", "version": "1.0.0", "environment": ENVIRONMENT})

@app.route('/health')
def health():
    status = {"status": "healthy", "services": {}}
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        status["services"]["database"] = "healthy"
    except Exception as e:
        status["services"]["database"] = f"unhealthy: {str(e)}"
        status["status"] = "degraded"
    return jsonify(status)

@app.route('/api/products', methods=['GET'])
@timing
def get_products():
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT id, name, description, price, stock FROM products WHERE stock > 0 ORDER BY id")
        products = cur.fetchall()
        cur.close()
        conn.close()
        for p in products:
            p['price'] = float(p['price'])
        return jsonify(products)
    except Exception as e:
        logger.error(f"Error fetching products: {e}")
        return jsonify({"error": "Internal server error"}), 500

@app.route('/api/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT id, name, description, price, stock FROM products WHERE id = %s", (product_id,))
        product = cur.fetchone()
        cur.close()
        conn.close()
        if not product:
            return jsonify({"error": "Product not found"}), 404
        product['price'] = float(product['price'])
        return jsonify(product)
    except Exception as e:
        logger.error(f"Error fetching product {product_id}: {e}")
        return jsonify({"error": "Internal server error"}), 500

@app.route('/api/orders', methods=['POST'])
def create_order():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400
        customer_name = data.get('customer_name')
        customer_email = data.get('customer_email')
        items = data.get('items', [])
        if not customer_name or not customer_email or not items:
            return jsonify({"error": "Missing required fields"}), 400

        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        total = 0
        for item in items:
            product_id = item.get('product_id')
            quantity = item.get('quantity', 1)
            cur.execute("SELECT price, stock FROM products WHERE id = %s", (product_id,))
            product = cur.fetchone()
            if not product:
                conn.close()
                return jsonify({"error": f"Product {product_id} not found"}), 404
            if product['stock'] < quantity:
                conn.close()
                return jsonify({"error": f"Insufficient stock for product {product_id}"}), 400
            total += float(product['price']) * quantity

        cur.execute("INSERT INTO orders (customer_name, customer_email, total) VALUES (%s,%s,%s) RETURNING id",
                    (customer_name, customer_email, total))
        order_id = cur.fetchone()['id']

        for item in items:
            product_id = item['product_id']
            quantity = item['quantity']
            cur.execute("SELECT price FROM products WHERE id = %s", (product_id,))
            price = cur.fetchone()['price']
            cur.execute("INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (%s,%s,%s,%s)",
                        (order_id, product_id, quantity, float(price)))
            cur.execute("UPDATE products SET stock = stock - %s, updated_at = CURRENT_TIMESTAMP WHERE id = %s",
                        (quantity, product_id))

        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"order_id": order_id, "total": total, "message": "Order created"}), 201
    except Exception as e:
        logger.error(f"Error creating order: {e}")
        return jsonify({"error": "Internal server error"}), 500

@app.route('/api/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT id, customer_name, customer_email, total, status, created_at FROM orders WHERE id = %s", (order_id,))
        order = cur.fetchone()
        if not order:
            conn.close()
            return jsonify({"error": "Order not found"}), 404
        cur.execute("SELECT oi.id, oi.product_id, p.name, oi.quantity, oi.price FROM order_items oi JOIN products p ON oi.product_id = p.id WHERE oi.order_id = %s", (order_id,))
        items = cur.fetchall()
        cur.close()
        conn.close()
        order['total'] = float(order['total'])
        order['items'] = items
        return jsonify(order)
    except Exception as e:
        logger.error(f"Error fetching order {order_id}: {e}")
        return jsonify({"error": "Internal server error"}), 500

@app.route('/api/metrics', methods=['GET'])
def get_metrics():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM products")
        product_count = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM orders")
        order_count = cur.fetchone()[0]
        cur.execute("SELECT COALESCE(SUM(total),0) FROM orders")
        total_sales = cur.fetchone()[0]
        cur.close()
        conn.close()
        return jsonify({
            "products": product_count,
            "orders": order_count,
            "total_sales": float(total_sales)
        })
    except Exception as e:
        logger.error(f"Error fetching metrics: {e}")
        return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    init_database()
    app.run(host='0.0.0.0', port=5000, debug=(ENVIRONMENT == 'dev'))
