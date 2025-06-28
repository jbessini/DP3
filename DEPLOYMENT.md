# 🧬 VitaShop - Guía de Deployment Detallada

**VitaShop** es una tienda especializada en vitaminas y suplementos nutricionales que demuestra una **arquitectura híbrida multi-cloud** avanzada (AWS + GCP), desplegada completamente con **Terraform Infrastructure as Code** usando técnicas de **código inline** para desarrollo ágil.

## 🎯 Características Destacadas

- 💊 **26 productos vitamínicos** organizados en 8 categorías especializadas
- 🛒 **Carrito inteligente** con persistencia LocalStorage y control de stock
- 🔄 **Debugging integrado** con logs automáticos y botones de prueba
- 📊 **Analytics en tiempo real** PostgreSQL → BigQuery via DataStream
- 🚀 **Despliegue inline** sin Docker builds, actualización instantánea
- 🌐 **Arquitectura híbrida** AWS backend + GCP frontend optimizada

## 📋 Prerrequisitos

### Software Requerido

| Software | Versión Mínima | Versión Probada | Instalación |
|----------|----------------|-----------------|-------------|
| **Terraform** | 1.6.0 | 1.6.6 | [terraform.io](https://developer.hashicorp.com/terraform/downloads) |
| **AWS CLI** | 2.0.0 | 2.15.0+ | [aws.amazon.com](https://aws.amazon.com/cli/) |
| **Google Cloud CLI** | 400.0.0 | 460.0.0+ | [cloud.google.com](https://cloud.google.com/sdk/docs/install) |
| **Git** | 2.30.0 | 2.40.0+ | [git-scm.com](https://git-scm.com/downloads) |

**💡 Innovación Técnica**: VitaShop pioneriza el **despliegue de código inline** en Terraform, eliminando la complejidad de Docker builds y registries. Todo el código Flask + JavaScript está embebido directamente en `main.tf`, permitiendo actualizaciones instantáneas con `terraform apply`.

**🏆 Beneficios del Código Inline**:
- ⚡ Deploy en ~3 minutos vs ~15 minutos tradicional
- 🔧 Debugging integrado con botones de prueba
- 📦 Sin gestión de imágenes Docker
- 🔄 Hot-reload development friendly

### Cuentas Cloud Requeridas

**🔐 AWS Account** (para backend e infraestructura):
- Permisos: `AmazonRDSFullAccess`, `AWSLambdaFullAccess`, `AmazonAPIGatewayAdministrator`, `AmazonVPCFullAccess`, `IAMFullAccess`
- Regiones recomendadas: `eu-central-1` (Frankfurt) o `us-east-1` (Virginia)
- Servicios: Lambda Functions, PostgreSQL RDS, API Gateway, VPC privado

**☁️ Google Cloud Project** (para frontend y analytics):
- Billing habilitado + APIs activas: Cloud Run, Artifact Registry, BigQuery, DataStream
- Regiones recomendadas: `europe-west1` (Bélgica) o `us-central1` (Iowa)
- Servicios: Cloud Run frontend, BigQuery analytics, DataStream sync

## 🔧 Configuración Inicial

### 1. Verificar y Configurar AWS CLI

```bash
# Verificar instalación
aws --version  # Debe mostrar AWS CLI 2.x

# Configurar credenciales
aws configure
# AWS Access Key ID: tu-access-key-aqui
# AWS Secret Access Key: tu-secret-access-key-aqui  
# Default region name: eu-central-1
# Default output format: json

# Verificar configuración
aws sts get-caller-identity
# Debe mostrar tu Account ID y User/Role info
```

**Permisos AWS requeridos:**
- `AmazonRDSFullAccess`
- `AWSLambdaFullAccess`
- `AmazonAPIGatewayAdministrator` 
- `AmazonVPCFullAccess`
- `IAMFullAccess`

### 2. Configurar Google Cloud CLI

```bash
# Instalar gcloud (si no está instalado)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Autenticación
gcloud auth login
gcloud auth application-default login

# Configurar proyecto
gcloud config set project YOUR_GCP_PROJECT_ID

# Verificar configuración
gcloud config list
gcloud projects describe YOUR_GCP_PROJECT_ID
```

### 3. Habilitar APIs en GCP

```bash
# Habilitar APIs necesarias
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable datastream.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

## 📦 Preparación del Proyecto

### 1. Clonar y Configurar

```bash
# Clonar el repositorio
git clone <repository-url>
cd DP-3

# Configurar variables de Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Editar terraform.tfvars con tus valores
nano terraform.tfvars
```

### 2. Configurar terraform.tfvars

```hcl
# terraform.tfvars
gcp_project_id = "mi-proyecto-gcp-123"
gcp_region     = "us-central1"
aws_region     = "us-east-1"
db_username    = "dp3_admin"
db_password    = "MiPasswordSegura123!"
```

## 🏗️ Despliegue con Terraform

### 1. Inicializar Terraform

```bash
cd terraform

# Inicializar (primera vez)
terraform init

# Validar configuración
terraform validate

# Ver plan de despliegue
terraform plan
```

### 2. Desplegar Infraestructura

```bash
# Aplicar cambios (confirmar con 'yes')
terraform apply

# Guardar outputs importantes
terraform output > ../deployment_outputs.txt
```

### 3. Outputs Esperados

Después del deployment, deberías ver:

```
cloud_run_url = "https://dp3-ecommerce-frontend-xxx-uc.a.run.app"
api_gateway_invoke_url = "https://xxx.execute-api.us-east-1.amazonaws.com/prod"
rds_public_endpoint = "dp3-ecommerce-db.xxx.us-east-1.rds.amazonaws.com"
```

## 💊 VitaShop: Despliegue con Código Inline

**🚀 Característica Especial**: VitaShop utiliza **despliegue de código inline** directamente en Terraform, eliminando la necesidad de construir y subir imágenes Docker manualmente.

### Ventajas del Código Inline
- ✅ **Sin Docker builds**: El código se despliega directamente
- ✅ **Actualizaciones rápidas**: Solo `terraform apply` para cambios
- ✅ **Menos complejidad**: No gestión de registries ni imágenes
- ✅ **Debugging integrado**: Logs y herramientas de diagnóstico incluidas

### Estructura del Código en main.tf

```hcl
# La aplicación Flask completa está embebida en main.tf
resource "google_cloud_run_v2_service" "frontend" {
  name     = "${var.project_name}-frontend"
  location = var.gcp_region
  
  template {
    containers {
      image = "gcr.io/cloudrun/hello"  # Imagen placeholder
      
      # Todo el código VitaShop está inline aquí
      env {
        name  = "APP_CODE"
        value = <<-EOT
          # Aplicación Flask completa con:
          # - Catálogo de vitaminas
          # - Carrito de compras
          # - Sistema de debugging
          # - Conectividad con Lambda/RDS
        EOT
      }
    }
  }
}
```

### Actualización de Código

```bash
# Para actualizar VitaShop, simplemente:
terraform plan   # Ver cambios
terraform apply  # Desplegar nueva versión

# No necesitas:
# - docker build
# - docker push  
# - gcloud run deploy
```

## 💊 Configurar Base de Datos VitaShop

### 1. Catálogo de Productos Vitamínicos

VitaShop incluye **26 productos especializados** en vitaminas y suplementos:

```sql
-- Categorías principales con iconos
'Vitaminas'     💊  # Vitamina C, D3, E, Complejo B
'Minerales'     ⚡  # Magnesio, Zinc, Calcio, Hierro  
'Proteínas'     💪  # Whey, Vegana, Colágeno
'Omega'         🐟  # Fish Oil, Vegano, Krill
'Antioxidantes' 🍇  # Resveratrol, Curcumina
'Probióticos'   🦠  # 50 Billones, Enzimas
'Energía'       ⚡  # CoQ10, Ginseng, Complejo B
'Inmunidad'     🛡️  # Vitamina C+Zinc, Echinacea
```

### 2. Inicialización Automática

**La base de datos se inicializa automáticamente** durante el deployment de Terraform:

```bash
# La inicialización ocurre automáticamente en:
terraform apply

# El script init_database.sql se ejecuta y crea:
# ✅ Tabla 'productos' con 26 vitaminas
# ✅ Índices para performance
# ✅ Triggers para updated_at
# ✅ Vista analytics para BigQuery
```

### 3. Verificar Productos Cargados

```bash
# Conectar directamente a RDS
psql -h $(terraform output -raw rds_public_endpoint) \
     -U $(terraform output -raw db_username) \
     -d $(terraform output -raw db_name)

# Verificar productos cargados
SELECT category, COUNT(*) as productos 
FROM productos 
GROUP BY category 
ORDER BY productos DESC;

# Resultado esperado:
#  category     | productos
#---------------+-----------
#  Vitaminas    |     4
#  Minerales    |     4  
#  Proteínas    |     3
#  Omega        |     3
#  Antioxidantes|     3
#  Probióticos  |     3
#  Energía      |     3
#  Inmunidad    |     3
```

### 4. Configuración Manual (Solo si es necesario)

```bash
# Solo necesario si hubo problemas en la inicialización automática
cd scripts
pip install psycopg2-binary

# Ejecutar manualmente
psql -h $(terraform output -raw rds_public_endpoint) \
     -U $(terraform output -raw db_username) \
     -d $(terraform output -raw db_name) \
     -f init_database.sql
```

## 🧪 Verificar VitaShop Deployment

### 1. URLs Principales de VitaShop

```bash
# Obtener todas las URLs importantes
terraform output

# Resultado esperado:
vitashop_url = "https://vitashop-frontend-xxx-uc.a.run.app"
api_gateway_url = "https://xxx.execute-api.eu-central-1.amazonaws.com/prod"
rds_endpoint = "vitashop-xxx.xxx.eu-central-1.rds.amazonaws.com"
```

### 2. Verificación Automática con Botones de Prueba

**VitaShop incluye herramientas de debugging integradas**:

1. **Abrir VitaShop** en el navegador
2. **Abrir DevTools** (F12) para ver logs detallados
3. **Usar botones de prueba**:
   - 🔄 **"Cargar Productos"** → Prueba API real
   - 📦 **"Productos de Prueba"** → Fallback estático
   - 🛒 **"Probar Carrito"** → Test funcionalidad carrito

### 3. Verificación Manual de Componentes

```bash
# 1. Probar VitaShop Frontend
curl "$(terraform output -raw vitashop_url)/health"
# Esperado: {"status": "healthy", "service": "VitaShop"}

# 2. Probar API Gateway (Lambda GetProducts)
curl "$(terraform output -raw api_gateway_url)/products"
# Esperado: [{"id":1,"name":"Vitamina C 1000mg",...}]

# 3. Probar endpoint específico
curl "$(terraform output -raw api_gateway_url)/item?id=1"
# Esperado: {"id":1,"name":"Vitamina C 1000mg","category":"Vitaminas"}

# 4. Verificar conectividad a base de datos
psql -h $(terraform output -raw rds_endpoint) \
     -U $(terraform output -raw db_username) \
     -d $(terraform output -raw db_name) \
     -c "SELECT COUNT(*) as total_vitaminas FROM productos;"
# Esperado: total_vitaminas | 26
```

### 4. Debugging con VitaShop DevTools

**Logs automáticos en Console del navegador**:

```javascript
// Logs que deberías ver en F12 → Console:
🚀 VitaShop iniciando...
📦 Cargando productos desde API...
✅ Productos cargados: 26 items
🛒 Carrito inicializado
💊 Categorías disponibles: 8
```

**Endpoint de debug específico**:
```bash
# Información técnica detallada
curl "$(terraform output -raw vitashop_url)/debug"

# Respuesta JSON con:
# - Estado de APIs
# - Configuración de conexiones
# - Variables de entorno
# - Estadísticas de productos
```

### 5. Test de Funcionalidad Completa

**Workflow de compra completo**:

1. **Navegar productos** por categoría (Vitaminas, Proteínas, etc.)
2. **Añadir al carrito** (verificar stock en tiempo real)
3. **Abrir carrito sidebar** (verificar persistencia LocalStorage)
4. **Procesar compra** (verificar actualización de stock en RDS)

**Test de persistencia**:
```bash
# 1. Añadir productos al carrito en el navegador
# 2. Cerrar pestaña/navegador
# 3. Volver a abrir VitaShop
# 4. Verificar que el carrito se mantiene (LocalStorage)
```

## 🔄 Desarrollo Local de VitaShop

### 1. Desarrollo Directo con Terraform

**VitaShop utiliza código inline**, por lo que el desarrollo se hace directamente en `main.tf`:

```bash
# Workflow de desarrollo
1. Editar código Flask en terraform/main.tf
2. terraform plan   # Ver cambios
3. terraform apply  # Desplegar cambios
4. Probar en Cloud Run URL
```

### 2. Desarrollo Local Simulado

**Para desarrollo rápido, puedes extraer el código**:

```bash
# Crear directorio de desarrollo local
mkdir vitashop-local
cd vitashop-local

# Extraer código Flask desde main.tf
grep -A 1000 "app = Flask" ../terraform/main.tf | \
grep -B 1000 "if __name__" > app.py

# Crear requirements.txt
echo "Flask==2.3.3" > requirements.txt
echo "requests==2.31.0" >> requirements.txt

# Configurar variables locales
export API_GATEWAY_URL="$(cd ../terraform && terraform output -raw api_gateway_url)"
export FLASK_DEBUG=true
export PORT=8080

# Ejecutar localmente
python app.py
```

**Acceso local**: `http://localhost:8080`

### 3. Desarrollo con Lambda Functions

**Las Lambda functions también están inline en main.tf**:

```bash
# Para probar Lambda functions localmente:
cd terraform/lambda_src/get_products

# Configurar variables de entorno
export DB_HOST="$(terraform output -raw rds_endpoint)"
export DB_USER="$(terraform output -raw db_username)"
export DB_PASSWORD="$(terraform output -raw db_password)"
export DB_NAME="$(terraform output -raw db_name)"

# Instalar dependencias
pip install -r requirements.txt

# Probar función
python -c "
import main
event = {'httpMethod': 'GET'}
result = main.lambda_handler(event, {})
print(result)
"
```

### 4. Hot Reload Development

**Para desarrollo más rápido**:

```bash
# 1. Hacer cambios en main.tf
vim terraform/main.tf

# 2. Aplicar solo el servicio Cloud Run
terraform apply -target=google_cloud_run_v2_service.frontend

# 3. Verificar cambios
curl "$(terraform output -raw vitashop_url)/health"

# El proceso toma ~2-3 minutos vs ~15 minutos para apply completo
```

## 📊 Analytics de VitaShop con BigQuery

### Pipeline de Datos Automático

VitaShop incluye **analytics en tiempo real** para métricas de negocio:

```bash
# DataStream se configura automáticamente durante terraform apply
# Replica datos de PostgreSQL → BigQuery cada 5 minutos

# Verificar que DataStream está activo
gcloud datastream streams list --location=$(terraform output -raw gcp_region)

# Esperado: Stream "vitashop-products-stream" en estado RUNNING
```

### Consultas de Analytics Disponibles

```sql
-- 1. Productos más populares por categoría
SELECT 
    category,
    COUNT(*) as productos_disponibles,
    AVG(price) as precio_promedio,
    SUM(stock) as stock_total
FROM `your-project.vitashop_analytics.productos_analytics`
GROUP BY category
ORDER BY productos_disponibles DESC;

-- 2. Productos con stock bajo (alertas)
SELECT name, category, stock, price
FROM `your-project.vitashop_analytics.productos_analytics`
WHERE stock < 10
ORDER BY stock ASC;

-- 3. Análisis de precios por categoría
SELECT 
    category,
    MIN(price) as precio_min,
    MAX(price) as precio_max,
    AVG(price) as precio_promedio
FROM `your-project.vitashop_analytics.productos_analytics`
GROUP BY category;
```

### Dashboard de Métricas

```bash
# Acceder a BigQuery desde CLI
bq query --use_legacy_sql=false "
SELECT 
    '🧬 VitaShop Analytics Dashboard' as titulo,
    COUNT(*) as total_productos,
    COUNT(DISTINCT category) as categorias,
    SUM(stock) as inventario_total,
    ROUND(AVG(price), 2) as precio_promedio
FROM \`$(terraform output -raw gcp_project_id).$(terraform output -raw bigquery_dataset_id).productos_analytics\`"

# Ver datos específicos de vitaminas
bq query --use_legacy_sql=false "
SELECT name, price, stock 
FROM \`$(terraform output -raw gcp_project_id).$(terraform output -raw bigquery_dataset_id).productos_analytics\`
WHERE category = 'Vitaminas'
ORDER BY price DESC"
```

## 🛠️ Troubleshooting VitaShop

### Errores Específicos de VitaShop

#### 1. "No se cargan productos en VitaShop"

**Síntomas**: Frontend muestra carrito vacío, sin productos visibles

```bash
# 1. Verificar Lambda GetProducts
aws logs tail /aws/lambda/$(terraform output -raw lambda_prefix)-getProducts --follow

# 2. Probar API Gateway directamente
curl "$(terraform output -raw api_gateway_url)/products"

# 3. Verificar conectividad RDS desde Lambda
aws logs tail /aws/lambda/$(terraform output -raw lambda_prefix)-getProducts --start-time=-10m

# 4. Usar debugging integrado en VitaShop
# Ir a: https://tu-vitashop-url/debug
```

**Soluciones más comunes**:
```bash
# Si Lambda no puede conectar a RDS:
aws ec2 describe-security-groups --filters Name=group-name,Values="*lambda*"

# Si no hay productos en BD:
psql -h $(terraform output -raw rds_endpoint) \
     -c "SELECT COUNT(*) FROM productos;"

# Si hay menos de 26 productos, reinicializar:
psql -h $(terraform output -raw rds_endpoint) \
     -f scripts/init_database.sql
```

#### 2. "Error JavaScript en carrito"

**Síntomas**: No se pueden añadir productos al carrito

```bash
# 1. Abrir DevTools (F12) → Console
# Buscar errores tipo:
# "Cannot read property of undefined"
# "localStorage is not defined"

# 2. Usar botón "Productos de Prueba" para verificar JavaScript
# 3. Limpiar localStorage si está corrupto:
```

**JavaScript para limpiar carrito**:
```javascript
// Ejecutar en Console del navegador
localStorage.removeItem('cart');
location.reload();
```

#### 3. "Error 502 Bad Gateway"

**Síntomas**: API Gateway retorna 502

```bash
# 1. Verificar Lambda functions están desplegadas
aws lambda list-functions --query 'Functions[?contains(FunctionName, `getProducts`)]'

# 2. Verificar logs de errores
aws logs tail /aws/lambda/$(terraform output -raw lambda_prefix)-getProducts --start-time=-30m

# 3. Probar invocación directa
aws lambda invoke \
  --function-name $(terraform output -raw lambda_prefix)-getProducts \
  --payload '{}' \
  response.json && cat response.json
```

#### 4. "VitaShop categorías no aparecen"

**Síntomas**: Los iconos de categorías (💊⚡💪🐟) no se muestran

```bash
# 1. Verificar que productos tienen las categorías correctas
psql -h $(terraform output -raw rds_endpoint) \
     -c "SELECT DISTINCT category FROM productos ORDER BY category;"

# Esperado:
# Antioxidantes, Energía, Inmunidad, Minerales, Omega, Probióticos, Proteínas, Vitaminas

# 2. Si las categorías están mal, actualizar:
psql -h $(terraform output -raw rds_endpoint) \
     -c "UPDATE productos SET category='Vitaminas' WHERE name LIKE '%Vitamina%';"
```

#### 5. "Template literal error en Terraform"

**Síntomas**: `terraform apply` falla con errores de `${...}`

```bash
# Error típico:
# "Reference to undeclared resource"
# "Invalid template interpolation value"

# Verificar que ALL JavaScript template literals usen escape:
grep -n '${[^}]*}' terraform/main.tf

# Todos los ${...} en JavaScript deben ser: ${...}
```

**Fix automático**:
```bash
# Backup
cp terraform/main.tf terraform/main.tf.backup

# Fix template literals
sed -i 's/\${\([^}]*\)}/\${\1}/g' terraform/main.tf

# Verificar cambios
diff terraform/main.tf.backup terraform/main.tf
```

### Comandos de Diagnóstico Avanzado

```bash
# 1. Estado completo de VitaShop
terraform show | grep -A 5 -B 5 "vitashop\|dp3"

# 2. Logs en tiempo real de todos los componentes
# Terminal 1 - Cloud Run logs
gcloud run services logs tail $(terraform output -raw service_name) --region=$(terraform output -raw gcp_region)

# Terminal 2 - Lambda GetProducts logs  
aws logs tail /aws/lambda/$(terraform output -raw lambda_prefix)-getProducts --follow

# Terminal 3 - Lambda GetItem logs
aws logs tail /aws/lambda/$(terraform output -raw lambda_prefix)-getItem --follow

# 3. Test completo de conectividad
curl -w "\nTime: %{time_total}s\nStatus: %{http_code}\n" \
     "$(terraform output -raw vitashop_url)/api/products"

# 4. Verificar todas las URLs importantes
echo "VitaShop: $(terraform output -raw vitashop_url)"
echo "API: $(terraform output -raw api_gateway_url)"
echo "DB: $(terraform output -raw rds_endpoint)"
echo "Health: $(terraform output -raw vitashop_url)/health"
echo "Debug: $(terraform output -raw vitashop_url)/debug"
```

### Herramientas de Diagnóstico VitaShop

#### 1. Dashboard de Debugging Integrado

```bash
# VitaShop incluye un endpoint especial de debugging
curl "$(terraform output -raw vitashop_url)/debug" | jq .

# Respuesta incluye:
# - Estado de conectividad con Lambda
# - Configuración de base de datos
# - Variables de entorno
# - Estadísticas de productos por categoría
# - Tiempo de respuesta de APIs
```

#### 2. Logs Centralizados

```bash
# Comando unificado para ver todos los logs
#!/bin/bash
echo "=== VitaShop Logs Dashboard ==="
echo "Frontend (Cloud Run):"
gcloud run services logs read $(terraform output -raw service_name) \
  --region=$(terraform output -raw gcp_region) --limit=10

echo "\nLambda GetProducts:"
aws logs tail /aws/lambda/$(terraform output -raw lambda_prefix)-getProducts \
  --start-time=-5m

echo "\nLambda GetItem:"
aws logs tail /aws/lambda/$(terraform output -raw lambda_prefix)-getItem \
  --start-time=-5m

echo "\nAPI Gateway:"
aws logs describe-log-groups --log-group-name-prefix="API-Gateway-Execution-Logs"
```

#### 3. Health Checks Automáticos

```bash
# Script para verificar salud completa de VitaShop
#!/bin/bash
VITASHOP_URL=$(terraform output -raw vitashop_url)
API_URL=$(terraform output -raw api_gateway_url)

echo "🧬 VitaShop Health Check"
echo "========================"

# 1. Frontend
echo -n "Frontend: "
curl -s "$VITASHOP_URL/health" | jq -r '.status' 2>/dev/null || echo "❌ FAILED"

# 2. API Gateway
echo -n "API Gateway: "
curl -s "$API_URL/products" | jq 'length' 2>/dev/null && echo "✅ OK" || echo "❌ FAILED"

# 3. Database
echo -n "Database: "
psql -h $(terraform output -raw rds_endpoint) \
     -c "SELECT COUNT(*) FROM productos;" 2>/dev/null | grep -q "26" && echo "✅ OK" || echo "❌ FAILED"

# 4. Carrito functionality
echo -n "Carrito Test: "
curl -s "$VITASHOP_URL" | grep -q "carrito" && echo "✅ OK" || echo "❌ FAILED"
```

#### 4. Monitoreo de Performance

```bash
# Medir latencia de todos los endpoints
#!/bin/bash
VITASHOP_URL=$(terraform output -raw vitashop_url)
API_URL=$(terraform output -raw api_gateway_url)

echo "⚡ VitaShop Performance Test"
echo "============================="

# Frontend principal
echo "Frontend: "
curl -w "Time: %{time_total}s | Size: %{size_download} bytes\n" \
     -s -o /dev/null "$VITASHOP_URL"

# API productos
echo "API Products: "
curl -w "Time: %{time_total}s | Status: %{http_code}\n" \
     -s -o /dev/null "$API_URL/products"

# API item específico
echo "API Item: "
curl -w "Time: %{time_total}s | Status: %{http_code}\n" \
     -s -o /dev/null "$API_URL/item?id=1"

# Debug endpoint
echo "Debug endpoint: "
curl -w "Time: %{time_total}s | Status: %{http_code}\n" \
     -s -o /dev/null "$VITASHOP_URL/debug"
```

## 🧹 Limpieza de VitaShop

### Destruir Infraestructura Completa

```bash
# ⚠️ CUIDADO: Esto eliminará VitaShop completamente
cd terraform

# Ver qué se va a eliminar
terraform plan -destroy

# Destruir todo (confirmar con 'yes')
terraform destroy

# Recursos que se eliminarán:
# ✅ Cloud Run VitaShop Frontend
# ✅ 3 Lambda Functions (GetProducts, GetItem, AddProduct)
# ✅ API Gateway + rutas
# ✅ PostgreSQL RDS + datos
# ✅ VPC + subnets + security groups
# ✅ BigQuery dataset + DataStream
# ✅ IAM roles + políticas
```

### Limpieza Selectiva (Para Development)

```bash
# Solo eliminar frontend (mantener backend)
terraform destroy -target=google_cloud_run_v2_service.frontend

# Solo eliminar base de datos (⚠️ perderás productos)
terraform destroy -target=aws_db_instance.main_database

# Solo eliminar Lambda functions
terraform destroy -target=aws_lambda_function.get_products
terraform destroy -target=aws_lambda_function.get_item
terraform destroy -target=aws_lambda_function.add_product
```

### Backup Antes de Limpieza

```bash
# 1. Backup de la base de datos VitaShop
pg_dump -h $(terraform output -raw rds_endpoint) \
        -U $(terraform output -raw db_username) \
        -d $(terraform output -raw db_name) \
        > vitashop_backup_$(date +%Y%m%d).sql

# 2. Backup de configuración Terraform
cp terraform.tfvars terraform.tfvars.backup
cp terraform.tfstate terraform.tfstate.backup

# 3. Backup de logs recientes
gcloud run services logs read $(terraform output -raw service_name) \
  --region=$(terraform output -raw gcp_region) \
  --limit=1000 > vitashop_logs_$(date +%Y%m%d).log
```

### Limpiar Archivos Locales

```bash
# Eliminar archivos temporales
rm -f *.log *.json response.json

# Limpiar cache de Terraform
rm -rf .terraform/
rm -f .terraform.lock.hcl

# ⚠️ SOLO si quieres empezar de cero:
# rm -f terraform.tfstate*
# rm -f terraform.tfvars

# Verificar limpieza
ls -la terraform/
# Solo deberían quedar: main.tf, variables.tf, outputs.tf, providers.tf
```

## 🆘 Soporte Especializado VitaShop

### Escalación de Problemas

**1. Auto-diagnóstico con herramientas integradas**:
```bash
# Dashboard de debugging automático
curl "$(terraform output -raw vitashop_url)/debug"

# Health check completo
curl "$(terraform output -raw vitashop_url)/health"
```

**2. Logs centralizados**:
```bash
# Ver todos los logs en tiempo real
./vitashop-logs.sh  # Script del troubleshooting section
```

**3. Community Support**:
- 📧 **Issues**: Crear issue en GitHub con logs del `/debug` endpoint
- 💬 **Discussions**: Preguntas sobre arquitectura híbrida
- 📖 **Wiki**: Documentación extendida y casos de uso

### Problemas Frecuentes y Soluciones

| Problema | Solución Rápida | Comando |
|----------|----------------|----------|
| **Productos no cargan** | Reiniciar Lambda | `terraform apply -target=aws_lambda_function.get_products` |
| **Carrito no funciona** | Limpiar localStorage | `localStorage.removeItem('cart')` en browser |
| **Error 502 API** | Verificar RDS conectividad | `psql -h $(terraform output -raw rds_endpoint)` |
| **Cloud Run 503** | Redeploy frontend | `terraform apply -target=google_cloud_run_v2_service.frontend` |
| **Template literals** | Fix automático | `sed -i 's/\${\([^}]*\)}/\${\1}/g' main.tf` |

### Información para Reportar Bugs

```bash
# Recopilar información completa para soporte
echo "=== VitaShop Debug Report ===" > debug_report.txt
echo "Timestamp: $(date)" >> debug_report.txt
echo "Terraform Version: $(terraform --version)" >> debug_report.txt
echo "\nTerraform Outputs:" >> debug_report.txt
terraform output >> debug_report.txt
echo "\nVitaShop Debug Info:" >> debug_report.txt
curl -s "$(terraform output -raw vitashop_url)/debug" >> debug_report.txt
echo "\nRecent Cloud Run Logs:" >> debug_report.txt
gcloud run services logs read $(terraform output -raw service_name) --limit=20 >> debug_report.txt

echo "Debug report saved to: debug_report.txt"
```

## 🔗 Enlaces Especializados VitaShop

### Documentación Técnica
- 🏗️ [Terraform Multi-Cloud Patterns](https://cloud.google.com/architecture/hybrid-and-multi-cloud-patterns)
- 🐍 [AWS Lambda + PostgreSQL Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/services-rds.html)
- 🌐 [Google Cloud Run + Private VPC](https://cloud.google.com/run/docs/configuring/connecting-vpc)
- 💊 [E-commerce Database Design](https://www.postgresql.org/docs/current/tutorial-sql.html)

### Herramientas de Desarrollo
- 📊 [BigQuery SQL Reference](https://cloud.google.com/bigquery/docs/reference/standard-sql/)
- 🔧 [Terraform State Management](https://developer.hashicorp.com/terraform/language/state)
- 🧪 [API Testing con curl](https://curl.se/docs/manpage.html)
- 🎯 [Chrome DevTools para debugging](https://developer.chrome.com/docs/devtools/)

### Arquitecturas de Referencia
- 🔄 [Hybrid Cloud E-commerce](https://aws.amazon.com/architecture/ecommerce/)
- 📈 [Real-time Analytics Pipeline](https://cloud.google.com/architecture/data-analytics)
- 🛡️ [Security Best Practices Multi-Cloud](https://aws.amazon.com/architecture/security-identity-compliance/)

---

<div align="center">

## 🧬 ¡VitaShop Deployment Completado! 

**Tu tienda de vitaminas híbrida multi-cloud está lista** 🚀  

### Próximos Pasos:
1. 🌐 **Acceder a VitaShop**: `$(terraform output -raw vitashop_url)`
2. 🔍 **Explorar productos**: 26 vitaminas y suplementos disponibles
3. 🛒 **Probar carrito**: Funcionalidad completa con LocalStorage
4. 📊 **Ver analytics**: BigQuery dashboard con métricas de negocio

*Desarrollado con ❤️ usando Terraform + AWS + GCP*

![Vitamins](https://img.shields.io/badge/Productos-26_Vitaminas-green?style=for-the-badge)
![Architecture](https://img.shields.io/badge/Arquitectura-Híbrida_Multi--Cloud-blue?style=for-the-badge)  
![Status](https://img.shields.io/badge/Status-Producción_Ready-success?style=for-the-badge)

</div>