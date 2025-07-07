# TODO: MEJORA CRÍTICA - Configurar backend remoto para Terraform state
# terraform {
#   backend "s3" {
#     bucket         = "dp3-terraform-state-bucket"
#     key            = "environments/${var.environment}/terraform.tfstate"
#     region         = var.aws_region
#     encrypt        = true
#     dynamodb_table = "dp3-terraform-state-lock"
#   }
# }

# --- Habilitar APIs de GCP ---
# TODO: MEJORA - Agregar timeouts y disable_on_destroy para control más granular
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "datastream.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbuild.googleapis.com"
  ])
  project                    = var.gcp_project_id
  service                    = each.key
  disable_dependent_services = false
  # TODO: MEJORA - Agregar disable_on_destroy = false para evitar problemas al destruir
}

# --- GCP: Artifact Registry para la imagen Docker de la App ---
resource "google_artifact_registry_repository" "repo" {
  project       = var.gcp_project_id
  location      = var.gcp_region
  repository_id = "${var.project_name}-repo"
  format        = "DOCKER"
  description   = "Repository for DP-3 e-commerce application"
  depends_on    = [google_project_service.apis]
}

# --- AWS: Red (VPC, Subred, etc.) ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets_cidr[0]
  availability_zone       = var.aws_availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet-1"
    Project = var.project_name
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets_cidr[1]
  availability_zone       = var.aws_availability_zones[1]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet-2"
    Project = var.project_name
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidr[0]
  availability_zone = var.aws_availability_zones[0]

  tags = {
    Name    = "${var.project_name}-private-subnet-1"
    Project = var.project_name
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidr[1]
  availability_zone = var.aws_availability_zones[1]

  tags = {
    Name    = "${var.project_name}-private-subnet-2"
    Project = var.project_name
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway para subnets privadas
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name    = "${var.project_name}-nat-gw"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-private-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# --- AWS: Security Groups ---

# TODO: PROBLEMA CRÍTICO DE SEGURIDAD - RDS público con acceso 0.0.0.0/0
# MEJORA URGENTE: Cambiar a subnets privadas y restringir acceso solo desde Lambda
# Security Group para RDS (público pero controlado)
resource "aws_security_group" "rds_sg" {
  name_prefix = "${var.project_name}-rds-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL from Lambda and external"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ❌ MUY PELIGROSO - Público como solicitaste
    # TODO: CAMBIAR POR: security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-rds-sg"
    Project = var.project_name
  }
}

# Security Group para Lambda (privado)
# TODO: MEJORA - Agregar regla de ingress específica para comunicación con RDS
resource "aws_security_group" "lambda_sg" {
  name_prefix = "${var.project_name}-lambda-sg"
  vpc_id      = aws_vpc.main.id

  # TODO: AGREGAR - Regla de ingress para permitir comunicación entre Lambdas si es necesario
  # ingress {
  #   from_port = 0
  #   to_port   = 65535
  #   protocol  = "tcp"
  #   self      = true
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-lambda-sg"
    Project = var.project_name
  }
}

# --- AWS: DB Subnet Group ---
# TODO: PROBLEMA DE SEGURIDAD - RDS debería estar en subnets privadas
resource "aws_db_subnet_group" "main_db_subnet_group" {
  name       = "${var.project_name}-dbsub-group-789"
  subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id] # ❌ RDS en subnets públicas
  # TODO: CAMBIAR POR: subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name    = "${var.project_name}-dbsub-group-789"
    Project = var.project_name
  }
}

# --- AWS: Base de Datos PostgreSQL en RDS (Público en VPC) ---
# TODO: MÚLTIPLES PROBLEMAS DE SEGURIDAD Y MEJORES PRÁCTICAS
resource "aws_db_instance" "main_database" {
  identifier             = "${var.project_name}-newdb-456"
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = 100
  storage_type           = "gp2" # TODO: MEJORA - Considerar gp3 para mejor performance/precio
  engine                 = "postgres"
  engine_version         = "15.7"
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password # TODO: SEGURIDAD - Usar AWS Secrets Manager
  publicly_accessible    = true  # ❌ CRÍTICO - Público como solicitaste
  # TODO: CAMBIAR A: publicly_accessible = false
  db_subnet_group_name   = aws_db_subnet_group.main_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true # TODO: PRODUCCIÓN - Cambiar a false
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # TODO: AGREGAR MEJORAS DE SEGURIDAD:
  # storage_encrypted               = true
  # kms_key_id                     = aws_kms_key.rds_key.arn
  # enabled_cloudwatch_logs_exports = ["postgresql"]
  # monitoring_interval            = 60
  # monitoring_role_arn           = aws_iam_role.rds_monitoring.arn
  # performance_insights_enabled   = true
  # deletion_protection           = var.environment == "production" ? true : false

  tags = {
    Name    = "${var.project_name}-public-db"
    Project = var.project_name
  }
}

# --- AWS: IAM Rol y Política para las Lambdas ---
# TODO: MEJORA - Aplicar principio de menor privilegio con políticas más específicas
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-lambda-execution-role"
    Project = var.project_name
  }
}

# TODO: MEJORA - Crear políticas IAM específicas para cada Lambda en lugar de usar managed policies genéricas
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# TODO: AGREGAR - Política específica para acceso a Secrets Manager
# resource "aws_iam_role_policy" "lambda_secrets_policy" {
#   name = "${var.project_name}-lambda-secrets-policy"
#   role = aws_iam_role.lambda_exec_role.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "secretsmanager:GetSecretValue"
#         ]
#         Resource = aws_secretsmanager_secret.db_credentials.arn
#       }
#     ]
#   })
# }

# --- AWS: Empaquetado y creación de las Funciones Lambda ---

# Lambda: GetProducts
# TODO: MEJORA - Considerar usar imágenes de contenedor para dependencias complejas
data "archive_file" "get_products" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/get_products"
  output_path = "${path.module}/get_products.zip"
}

resource "aws_lambda_function" "get_products" {
  filename         = data.archive_file.get_products.output_path
  function_name    = "${var.project_name}-getProducts"
  role            = aws_iam_role.lambda_exec_role.arn
  handler         = "main.lambda_handler"
  source_code_hash = data.archive_file.get_products.output_base64sha256
  runtime         = "python3.11"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # TODO: SEGURIDAD CRÍTICA - Credenciales expuestas como variables de entorno
  environment {
    variables = {
      DB_HOST     = aws_db_instance.main_database.address
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password # ❌ NUNCA exponer password en variables de entorno
      DB_NAME     = aws_db_instance.main_database.db_name
      # TODO: CAMBIAR POR: SECRET_ARN = aws_secretsmanager_secret.db_credentials.arn
    }
  }

  # TODO: AGREGAR - CloudWatch logs y dead letter queue
  # dead_letter_config {
  #   target_arn = aws_sqs_queue.lambda_dlq.arn
  # }

  tags = {
    Name    = "${var.project_name}-getProducts"
    Project = var.project_name
  }
}

# Lambda: GetItem
# TODO: MEJORA - Mismos problemas que GetProducts (seguridad, monitoreo, etc.)
data "archive_file" "get_item" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/get_item"
  output_path = "${path.module}/get_item.zip"
}

resource "aws_lambda_function" "get_item" {
  filename         = data.archive_file.get_item.output_path
  function_name    = "${var.project_name}-getItem"
  role            = aws_iam_role.lambda_exec_role.arn
  handler         = "main.lambda_handler"
  source_code_hash = data.archive_file.get_item.output_base64sha256
  runtime         = "python3.11"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # TODO: MISMO PROBLEMA - Credenciales expuestas
  environment {
    variables = {
      DB_HOST     = aws_db_instance.main_database.address
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password # ❌ MISMO PROBLEMA DE SEGURIDAD
      DB_NAME     = aws_db_instance.main_database.db_name
    }
  }

  tags = {
    Name    = "${var.project_name}-getItem"
    Project = var.project_name
  }
}

# Lambda: AddProduct
# TODO: OBSERVACIÓN - Comentario del alumno sobre usar Docker es correcto
data "archive_file" "add_product" {
  type        = "zip" # ✅ Aquí debería ser una docker image no un zip para manejar mejor dependencias
  source_dir  = "${path.module}/lambda_src/add_product"
  output_path = "${path.module}/add_product.zip"
}

resource "aws_lambda_function" "add_product" {
  filename         = data.archive_file.add_product.output_path
  function_name    = "${var.project_name}-addProduct"
  role            = aws_iam_role.lambda_exec_role.arn
  handler         = "main.lambda_handler"
  source_code_hash = data.archive_file.add_product.output_base64sha256
  runtime         = "python3.11"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # TODO: MISMO PROBLEMA - Credenciales expuestas
  environment {
    variables = {
      DB_HOST     = aws_db_instance.main_database.address
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password # ❌ MISMO PROBLEMA DE SEGURIDAD
      DB_NAME     = aws_db_instance.main_database.db_name
    }
  }

  tags = {
    Name    = "${var.project_name}-addProduct"
    Project = var.project_name
  }
}

# --- AWS: API Gateway ---
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-ecommerce-api"
  description = "API Gateway para el e-commerce DP-3"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name    = "${var.project_name}-ecommerce-api"
    Project = var.project_name
  }
}

# Recurso /products
resource "aws_api_gateway_resource" "products" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "products"
}

resource "aws_api_gateway_method" "products_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.products.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "products_get_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.products.id
  http_method             = aws_api_gateway_method.products_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_products.invoke_arn
}

# Recurso /add
resource "aws_api_gateway_resource" "add" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "add"
}

resource "aws_api_gateway_method" "add_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.add.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "add_post_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.add.id
  http_method             = aws_api_gateway_method.add_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.add_product.invoke_arn
}

# Recurso /item
resource "aws_api_gateway_resource" "item" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "item"
}

resource "aws_api_gateway_method" "item_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.item.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "item_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.item.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "item_get_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.item.id
  http_method             = aws_api_gateway_method.item_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_item.invoke_arn
}

resource "aws_api_gateway_integration" "item_post_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.item.id
  http_method             = aws_api_gateway_method.item_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_item.invoke_arn
}

# Habilitación CORS para todos los recursos
resource "aws_api_gateway_method" "products_options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.products.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "products_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.products.id
  http_method = aws_api_gateway_method.products_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "products_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.products.id
  http_method = aws_api_gateway_method.products_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "products_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.products.id
  http_method = aws_api_gateway_method.products_options.http_method
  status_code = aws_api_gateway_method_response.products_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Permisos para API Gateway llamar a Lambda
resource "aws_lambda_permission" "api_gateway_invoke_get_products" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_products.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_invoke_add_product" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.add_product.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_invoke_get_item" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Deployment del API
resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.products_get_lambda,
    aws_api_gateway_integration.add_post_lambda,
    aws_api_gateway_integration.item_get_lambda,
    aws_api_gateway_integration.item_post_lambda,
    aws_api_gateway_integration.products_options
  ]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.products.id,
      aws_api_gateway_method.products_get.id,
      aws_api_gateway_integration.products_get_lambda.id,
      aws_api_gateway_resource.add.id,
      aws_api_gateway_method.add_post.id,
      aws_api_gateway_integration.add_post_lambda.id,
      aws_api_gateway_resource.item.id,
      aws_api_gateway_method.item_get.id,
      aws_api_gateway_method.item_post.id,
      aws_api_gateway_integration.item_get_lambda.id,
      aws_api_gateway_integration.item_post_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage del API Gateway
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"

  tags = {
    Name    = "${var.project_name}-api-stage"
    Project = var.project_name
  }
}

# Los servicios personalizados de Docker han sido eliminados para evitar errores

# Permite acceso público a Cloud Run - Servicio completo inline
resource "google_cloud_run_service_iam_member" "noauth_inline" {
  location = google_cloud_run_v2_service.flask_inline.location
  project  = google_cloud_run_v2_service.flask_inline.project
  service  = google_cloud_run_v2_service.flask_inline.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# --- GCP: BigQuery Dataset y Table ---
resource "google_bigquery_dataset" "ecommerce_dataset" {
  dataset_id    = var.bigquery_dataset_id
  project       = var.gcp_project_id
  location      = var.bigquery_dataset_location
  friendly_name = "${var.project_name} E-commerce Products Dataset"
  description   = "Dataset para productos replicados desde PostgreSQL RDS"

  depends_on = [google_project_service.apis]
}

resource "google_bigquery_table" "products_table" {
  dataset_id          = google_bigquery_dataset.ecommerce_dataset.dataset_id
  table_id            = "productos"
  project             = var.gcp_project_id
  deletion_protection = false

  schema = jsonencode([
    {
      name = "id"
      type = "INTEGER"
      mode = "REQUIRED"
    },
    {
      name = "name"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "category"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "price"
      type = "NUMERIC"
      mode = "REQUIRED"
    },
    {
      name = "stock"
      type = "INTEGER"
      mode = "REQUIRED"
    },
    {
      name = "created_at"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    },
    {
      name = "updated_at"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    },
    {
      name = "sync_timestamp"
      type = "TIMESTAMP"
      mode = "REQUIRED"
    }
  ])
}

# --- Recursos Docker simplificados ---
# El cloudbuild.yaml se mantiene para uso futuro pero no es requerido para el deployment actual

# Solución completa: Usar imagen base de Python con código inline
resource "google_cloud_run_v2_service" "flask_inline" {
  name     = "${var.project_name}-complete-frontend"
  location = var.gcp_region
  project  = var.gcp_project_id

  template {
    containers {
      # Usar imagen Python base con aplicación Flask inline
      image = "python:3.11-slim"
      
      # Comando para instalar dependencias y ejecutar la app
      command = ["/bin/bash"]
      args = ["-c", <<-EOT
        pip install flask requests gunicorn &&
        cat > app.py << 'EOF'
import os
import requests
import json
from flask import Flask, render_template_string, request, jsonify, session
import logging
from datetime import datetime

app = Flask(__name__)
app.secret_key = "vitaminas-secret-key-2024"
logging.basicConfig(level=logging.INFO)

API_GATEWAY_URL = os.environ.get("API_GATEWAY_URL", "")

# Inicializar carrito en sesión
def init_cart():
    if "cart" not in session:
        session["cart"] = []

@app.route("/")
def index():
    return render_template_string('''
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>VitaShop - Tienda de Vitaminas y Suplementos</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f8f9fa; }
            
            .header { background: linear-gradient(135deg, #28a745, #20c997); color: white; padding: 1rem 0; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .nav { max-width: 1200px; margin: 0 auto; display: flex; justify-content: space-between; align-items: center; padding: 0 2rem; }
            .logo { font-size: 2rem; font-weight: bold; }
            .cart-icon { background: rgba(255,255,255,0.2); padding: 0.5rem 1rem; border-radius: 25px; cursor: pointer; transition: all 0.3s; }
            .cart-icon:hover { background: rgba(255,255,255,0.3); }
            .cart-count { background: #dc3545; color: white; border-radius: 50%; padding: 0.2rem 0.5rem; font-size: 0.8rem; margin-left: 0.5rem; }
            
            .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
            .hero { text-align: center; margin-bottom: 3rem; }
            .hero h1 { color: #2c3e50; margin-bottom: 1rem; font-size: 2.5rem; }
            .hero p { color: #6c757d; font-size: 1.2rem; }
            
            .products-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem; margin-bottom: 3rem; }
            .product-card { background: white; border-radius: 15px; padding: 1.5rem; box-shadow: 0 5px 15px rgba(0,0,0,0.1); transition: transform 0.3s; }
            .product-card:hover { transform: translateY(-5px); }
            .product-image { width: 100%; height: 200px; background: linear-gradient(45deg, #e3f2fd, #bbdefb); border-radius: 10px; display: flex; align-items: center; justify-content: center; margin-bottom: 1rem; }
            .product-icon { font-size: 4rem; }
            .product-name { font-size: 1.3rem; font-weight: bold; color: #2c3e50; margin-bottom: 0.5rem; }
            .product-category { color: #28a745; font-weight: 500; margin-bottom: 0.5rem; }
            .product-price { font-size: 1.5rem; font-weight: bold; color: #dc3545; margin-bottom: 1rem; }
            .product-stock { color: #6c757d; margin-bottom: 1rem; }
            .btn { padding: 0.75rem 1.5rem; border: none; border-radius: 25px; cursor: pointer; font-weight: 500; transition: all 0.3s; margin: 0 0.5rem; }
            .btn-primary { background: #28a745; color: white; }
            .btn-primary:hover { background: #218838; }
            .btn-secondary { background: #6c757d; color: white; }
            .btn-secondary:hover { background: #5a6268; }
            .btn-danger { background: #dc3545; color: white; }
            .btn-success { background: #20c997; color: white; }
            
            .cart-sidebar { position: fixed; right: -400px; top: 0; width: 400px; height: 100vh; background: white; box-shadow: -5px 0 15px rgba(0,0,0,0.1); transition: right 0.3s; z-index: 1000; overflow-y: auto; }
            .cart-sidebar.open { right: 0; }
            .cart-header { background: #28a745; color: white; padding: 1rem; }
            .cart-content { padding: 1rem; }
            .cart-item { display: flex; justify-content: space-between; align-items: center; padding: 1rem; border-bottom: 1px solid #eee; }
            .cart-total { background: #f8f9fa; padding: 1rem; margin-top: 1rem; border-radius: 10px; }
            .close-cart { float: right; cursor: pointer; font-size: 1.5rem; }
            
            .overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 999; display: none; }
            .overlay.show { display: block; }
            
            .checkout-form { background: white; padding: 2rem; border-radius: 15px; margin-top: 2rem; }
            .form-group { margin-bottom: 1rem; }
            .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; }
            .form-group input { width: 100%; padding: 0.75rem; border: 1px solid #ddd; border-radius: 5px; }
            
            .success-message { background: #d4edda; color: #155724; padding: 1rem; border-radius: 10px; margin: 1rem 0; }
            .error-message { background: #f8d7da; color: #721c24; padding: 1rem; border-radius: 10px; margin: 1rem 0; }
            .loading-message { background: #d4edda; color: #155724; padding: 2rem; border-radius: 10px; text-align: center; border: 1px solid #c3e6cb; }
            .loading-message h3 { margin: 0 0 0.5rem 0; }
            .loading-message p { margin: 0; opacity: 0.8; }
        </style>
    </head>
    <body>
        <div class="overlay" id="overlay" onclick="closeCart()"></div>
        
        <header class="header">
            <nav class="nav">
                <div class="logo">🌿 VitaShop</div>
                <div class="cart-icon" onclick="toggleCart()">
                    🛒 Carrito <span class="cart-count" id="cart-count">0</span>
                </div>
            </nav>
        </header>

        <div class="container">
            <div class="hero">
                <h1>Vitaminas y Suplementos Naturales</h1>
                <p>Cuida tu salud con los mejores productos naturales</p>
            </div>

            <div style="text-align: center; margin: 2rem 0;">
                <button onclick="testConnectivity()" class="btn btn-primary">🔄 Cargar Productos</button>
                <button onclick="showFallbackProducts()" class="btn btn-secondary">📦 Productos de Prueba</button>
            </div>
            
            <div id="products-grid" class="products-grid">
                <div class="loading-message">
                    <h3>🔄 Cargando productos...</h3>
                    <p>Conectando con la base de datos...</p>
                    <p><small>Si no cargan automáticamente, usa el botón "Cargar Productos"</small></p>
                </div>
            </div>
        </div>

        <!-- Carrito lateral -->
        <div class="cart-sidebar" id="cart-sidebar">
            <div class="cart-header">
                <h3>Tu Carrito <span class="close-cart" onclick="closeCart()">×</span></h3>
            </div>
            <div class="cart-content">
                <div id="cart-items"></div>
                <div class="cart-total">
                    <h4>Total: $<span id="cart-total">0.00</span></h4>
                    <button class="btn btn-success" style="width: 100%; margin-top: 1rem;" onclick="showCheckout()">
                        💳 Proceder al Pago
                    </button>
                </div>
            </div>
        </div>

        <!-- Formulario de checkout -->
        <div id="checkout-section" style="display: none;">
            <div class="checkout-form">
                <h3>Finalizar Compra</h3>
                <form id="checkout-form">
                    <div class="form-group">
                        <label>Nombre completo:</label>
                        <input type="text" id="customer-name" required>
                    </div>
                    <div class="form-group">
                        <label>Email:</label>
                        <input type="email" id="customer-email" required>
                    </div>
                    <div class="form-group">
                        <label>Teléfono:</label>
                        <input type="tel" id="customer-phone" required>
                    </div>
                    <button type="submit" class="btn btn-primary">Confirmar Pedido</button>
                </form>
            </div>
        </div>

        <script>
            let products = [];
            let cart = JSON.parse(localStorage.getItem("cart")) || [];

            // Íconos para categorías
            const categoryIcons = {
                "Vitaminas": "💊",
                "Minerales": "⚡",
                "Proteínas": "💪",
                "Omega": "🐟",
                "Antioxidantes": "🍇",
                "Probióticos": "🦠",
                "Energía": "⚡",
                "Inmunidad": "🛡️"
            };

            // Cargar productos
            async function loadProducts() {
                try {
                    const response = await fetch("/api/products");
                    const data = await response.json();
                    products = data;
                    displayProducts();
                    updateCartUI();
                } catch (error) {
                    document.getElementById("products-grid").innerHTML = 
                        "<div class=\"error-message\">Error cargando productos: " + error.message + "</div>";
                }
            }

            function displayProducts() {
                const grid = document.getElementById("products-grid");
                grid.innerHTML = products.map(product => `
                    <div class="product-card">
                        <div class="product-image">
                            <span class="product-icon">$${categoryIcons[product.category] || "💊"}</span>
                        </div>
                        <div class="product-name">$${product.name}</div>
                        <div class="product-category">$${product.category}</div>
                        <div class="product-price">$$${parseFloat(product.price).toFixed(2)}</div>
                        <div class="product-stock">Stock: $${product.stock} unidades</div>
                        <button class="btn btn-primary" onclick="addToCart($${product.id})" 
                                $${product.stock <= 0 ? "disabled" : ""}>
                            $${product.stock <= 0 ? "Sin Stock" : "🛒 Agregar al Carrito"}
                        </button>
                    </div>
                `).join("");
            }

            function addToCart(productId) {
                const product = products.find(p => p.id === productId);
                if (!product || product.stock <= 0) return;

                const existingItem = cart.find(item => item.id === productId);
                if (existingItem) {
                    if (existingItem.quantity < product.stock) {
                        existingItem.quantity++;
                    } else {
                        alert("No hay más stock disponible");
                        return;
                    }
                } else {
                    cart.push({
                        id: product.id,
                        name: product.name,
                        price: parseFloat(product.price),
                        quantity: 1,
                        category: product.category
                    });
                }
                
                saveCart();
                updateCartUI();
                
                // Animación de éxito
                event.target.style.background = "#20c997";
                event.target.textContent = "✓ Agregado";
                setTimeout(() => {
                    event.target.style.background = "#28a745";
                    event.target.textContent = "🛒 Agregar al Carrito";
                }, 1000);
            }

            function removeFromCart(productId) {
                cart = cart.filter(item => item.id !== productId);
                saveCart();
                updateCartUI();
            }

            function updateQuantity(productId, newQuantity) {
                const item = cart.find(item => item.id === productId);
                const product = products.find(p => p.id === productId);
                
                if (newQuantity <= 0) {
                    removeFromCart(productId);
                } else if (newQuantity <= product.stock) {
                    item.quantity = newQuantity;
                    saveCart();
                    updateCartUI();
                } else {
                    alert("No hay suficiente stock");
                }
            }

            function updateCartUI() {
                const cartCount = cart.reduce((total, item) => total + item.quantity, 0);
                const cartTotal = cart.reduce((total, item) => total + (item.price * item.quantity), 0);
                
                document.getElementById("cart-count").textContent = cartCount;
                document.getElementById("cart-total").textContent = cartTotal.toFixed(2);
                
                const cartItems = document.getElementById("cart-items");
                cartItems.innerHTML = cart.map(item => `
                    <div class="cart-item">
                        <div>
                            <strong>$${item.name}</strong><br>
                            <small>$${item.category}</small><br>
                            $$${item.price.toFixed(2)} x 
                            <input type="number" value="$${item.quantity}" min="1" max="10" 
                                   onchange="updateQuantity($${item.id}, this.value)"
                                   style="width: 60px; margin: 0 5px;">
                        </div>
                        <button class="btn btn-danger" onclick="removeFromCart($${item.id})">🗑️</button>
                    </div>
                `).join("");
            }

            function toggleCart() {
                const sidebar = document.getElementById("cart-sidebar");
                const overlay = document.getElementById("overlay");
                sidebar.classList.toggle("open");
                overlay.classList.toggle("show");
            }

            function closeCart() {
                document.getElementById("cart-sidebar").classList.remove("open");
                document.getElementById("overlay").classList.remove("show");
            }

            function showCheckout() {
                if (cart.length === 0) {
                    alert("Tu carrito está vacío");
                    return;
                }
                document.getElementById("checkout-section").style.display = "block";
                document.getElementById("checkout-section").scrollIntoView();
                closeCart();
            }

            function saveCart() {
                localStorage.setItem("cart", JSON.stringify(cart));
            }

            // Procesar compra
            document.getElementById("checkout-form").addEventListener("submit", async function(e) {
                e.preventDefault();
                
                if (cart.length === 0) {
                    alert("Tu carrito está vacío");
                    return;
                }

                const orderData = {
                    customer: {
                        name: document.getElementById("customer-name").value,
                        email: document.getElementById("customer-email").value,
                        phone: document.getElementById("customer-phone").value
                    },
                    items: cart,
                    total: cart.reduce((total, item) => total + (item.price * item.quantity), 0)
                };

                try {
                    // Procesar todo el carrito en una sola request
                    const response = await fetch("/api/purchase", {
                        method: "POST",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({
                            cart: cart,
                            customer_info: orderData.customer
                        })
                    });
                    
                    const result = await response.json();
                    
                    if (!response.ok || !result.success) {
                        throw new Error(result.error || "Error procesando la compra");
                    }

                    // Éxito
                    document.getElementById("checkout-section").innerHTML = `
                        <div class="success-message">
                            <h3>¡Pedido confirmado! 🎉</h3>
                            <p>Gracias $${result.customer.name}, tu pedido ha sido procesado exitosamente.</p>
                            <p>Total: $$${result.total.toFixed(2)}</p>
                            <p>Recibirás un email de confirmación en: $${result.customer.email}</p>
                            <p>Productos comprados: $${result.items.length} artículos</p>
                        </div>
                    `;
                    
                    // Limpiar carrito
                    cart = [];
                    saveCart();
                    updateCartUI();
                    
                    // Recargar productos para actualizar stock
                    loadProducts();

                } catch (error) {
                    document.getElementById("checkout-section").innerHTML += `
                        <div class="error-message">
                            Error procesando el pedido: $${error.message}
                        </div>
                    `;
                }
            });

            // Debug inicial
            console.log("🚀 VitaShop iniciando...");
            console.log("🔗 URL base para APIs:", window.location.origin);
            
            // Función para mostrar productos de fallback (sin conexión a BD)
            function showFallbackProducts() {
                console.log("📦 Mostrando productos de fallback...");
                products = [
                    {"id": 1, "name": "Vitamina C 1000mg", "category": "Vitaminas", "price": 15.99, "stock": 50},
                    {"id": 2, "name": "Omega-3 Fish Oil 1000mg", "category": "Omega", "price": 24.99, "stock": 30},
                    {"id": 3, "name": "Proteína Whey Chocolate", "category": "Proteínas", "price": 45.99, "stock": 25},
                    {"id": 4, "name": "Magnesio 400mg", "category": "Minerales", "price": 12.99, "stock": 40},
                    {"id": 5, "name": "Probióticos 50 Billones", "category": "Probióticos", "price": 29.99, "stock": 35},
                    {"id": 6, "name": "Antioxidantes Complexo", "category": "Antioxidantes", "price": 19.99, "stock": 45},
                    {"id": 7, "name": "CoQ10 100mg", "category": "Energía", "price": 31.99, "stock": 30},
                    {"id": 8, "name": "Vitamina C + Zinc", "category": "Inmunidad", "price": 17.99, "stock": 50}
                ];
                displayProducts();
                updateCartUI();
            }
            
            // Función de debug para probar conectividad
            async function testConnectivity() {
                try {
                    console.log("🧪 Probando conectividad...");
                    
                    // Probar endpoint debug
                    const debugResponse = await fetch("/debug");
                    const debugData = await debugResponse.json();
                    console.log("📊 Debug info:", debugData);
                    
                    // Probar endpoint de productos
                    const productsResponse = await fetch("/api/products");
                    console.log("📦 Products response status:", productsResponse.status);
                    
                    if (productsResponse.ok) {
                        const productsData = await productsResponse.json();
                        console.log("📦 Products data:", productsData);
                        products = productsData;
                        displayProducts();
                    } else {
                        console.error("❌ Error cargando productos:", productsResponse.status);
                        document.getElementById("products-grid").innerHTML = 
                            `<div class="error-message">Error: $${productsResponse.status} - $${productsResponse.statusText}</div>`;
                    }
                    
                } catch (error) {
                    console.error("❌ Error de conectividad:", error);
                    document.getElementById("products-grid").innerHTML = 
                        `<div class="error-message">Error de conexión: $${error.message}</div>`;
                }
            }
            
            // Cargar productos con debug al inicializar
            console.log("🔄 Cargando productos...");
            testConnectivity();
            
        </script>
    </body>
    </html>
    ''')

@app.route("/api/products")
def get_products():
    try:
        response = requests.get(f"{API_GATEWAY_URL}/products", timeout=10)
        if response.status_code == 200:
            lambda_response = response.json()
            # Las Lambda functions devuelven el resultado en el campo 'body' como string JSON
            if isinstance(lambda_response, dict) and 'body' in lambda_response:
                products_data = json.loads(lambda_response['body'])
                return jsonify(products_data)
            else:
                return jsonify(lambda_response)
        else:
            # Datos de prueba si las lambdas no están disponibles
            return jsonify([
                {"id": 1, "name": "Vitamina C 1000mg", "category": "Vitaminas", "price": 15.99, "stock": 50},
                {"id": 2, "name": "Omega-3 Fish Oil 1000mg", "category": "Omega", "price": 24.99, "stock": 30},
                {"id": 3, "name": "Proteína Whey Chocolate", "category": "Proteínas", "price": 45.99, "stock": 25},
                {"id": 4, "name": "Magnesio 400mg", "category": "Minerales", "price": 12.99, "stock": 40},
                {"id": 5, "name": "Probióticos 50 Billones", "category": "Probióticos", "price": 29.99, "stock": 35},
                {"id": 6, "name": "Antioxidantes Complexo", "category": "Antioxidantes", "price": 19.99, "stock": 45},
                {"id": 7, "name": "CoQ10 100mg", "category": "Energía", "price": 31.99, "stock": 30},
                {"id": 8, "name": "Vitamina C + Zinc", "category": "Inmunidad", "price": 17.99, "stock": 50}
            ])
    except Exception as e:
        # Datos de prueba si hay error de conexión
        return jsonify([
            {"id": 1, "name": "Vitamina C 1000mg", "category": "Vitaminas", "price": 15.99, "stock": 50},
            {"id": 2, "name": "Omega-3 Fish Oil 1000mg", "category": "Omega", "price": 24.99, "stock": 30},
            {"id": 3, "name": "Proteína Whey Chocolate", "category": "Proteínas", "price": 45.99, "stock": 25},
            {"id": 4, "name": "Magnesio 400mg", "category": "Minerales", "price": 12.99, "stock": 40},
            {"id": 5, "name": "Probióticos 50 Billones", "category": "Probióticos", "price": 29.99, "stock": 35},
            {"id": 6, "name": "Antioxidantes Complexo", "category": "Antioxidantes", "price": 19.99, "stock": 45},
            {"id": 7, "name": "CoQ10 100mg", "category": "Energía", "price": 31.99, "stock": 30},
            {"id": 8, "name": "Vitamina C + Zinc", "category": "Inmunidad", "price": 17.99, "stock": 50}
        ])

@app.route("/api/item/<int:item_id>")
def get_item(item_id):
    try:
        response = requests.get(f"{API_GATEWAY_URL}/item?id={item_id}", timeout=10)
        if response.status_code == 200:
            lambda_response = response.json()
            # Las Lambda functions devuelven el resultado en el campo 'body' como string JSON
            if isinstance(lambda_response, dict) and 'body' in lambda_response:
                item_data = json.loads(lambda_response['body'])
                return jsonify(item_data)
            else:
                return jsonify(lambda_response)
        else:
            return jsonify({"error": "Producto no encontrado"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/purchase", methods=["POST"])
def process_purchase():
    try:
        data = request.get_json()
        cart_items = data.get("cart", [])
        customer_info = data.get("customer_info", {})
        
        if not cart_items:
            return jsonify({"error": "Carrito vacío"}), 400
        
        # Procesar cada item del carrito
        results = []
        total_amount = 0
        
        for item in cart_items:
            # Actualizar stock usando la Lambda de item
            update_data = {
                "product_id": item["id"],
                "quantity": item["quantity"],
                "action": "purchase"
            }
            
            response = requests.post(f"{API_GATEWAY_URL}/item", json=update_data, timeout=10)
            
            if response.status_code == 200:
                lambda_response = response.json()
                # Verificar si la Lambda function devuelve success
                if isinstance(lambda_response, dict) and 'body' in lambda_response:
                    body_data = json.loads(lambda_response['body'])
                    if body_data.get('success', True):  # Asumir éxito si no se especifica
                        results.append({"id": item["id"], "status": "success"})
                        total_amount += item["price"] * item["quantity"]
                    else:
                        results.append({"id": item["id"], "status": "error", "message": body_data.get('message', 'Error desconocido')})
                else:
                    results.append({"id": item["id"], "status": "success"})
                    total_amount += item["price"] * item["quantity"]
            else:
                results.append({"id": item["id"], "status": "error", "message": "Stock insuficiente"})
        
        # Verificar si todas las compras fueron exitosas
        successful_purchases = [r for r in results if r["status"] == "success"]
        
        if len(successful_purchases) == len(cart_items):
            return jsonify({
                "success": True, 
                "message": "Compra procesada exitosamente",
                "total": total_amount,
                "customer": customer_info,
                "items": successful_purchases
            })
        else:
            return jsonify({
                "success": False,
                "error": "Algunos productos no pudieron procesarse",
                "results": results
            }), 400
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/health")
def health():
    return {"status": "healthy", "api_url": API_GATEWAY_URL, "store": "VitaShop"}

@app.route("/debug")
def debug():
    """Endpoint para debugging - muestra el estado de la configuración"""
    return {
        "api_gateway_url": API_GATEWAY_URL,
        "endpoints": {
            "products": f"{API_GATEWAY_URL}/products",
            "item": f"{API_GATEWAY_URL}/item"
        },
        "store": "VitaShop",
        "version": "2.0"
    }

@app.route("/init-db")
def init_database():
    """Endpoint para inicializar la base de datos con productos de vitaminas"""
    try:
        # Intentar añadir algunos productos básicos usando la Lambda addProduct
        sample_products = [
            {"name": "Vitamina C 1000mg", "category": "Vitaminas", "price": 15.99, "stock": 50},
            {"name": "Omega-3 Fish Oil 1000mg", "category": "Omega", "price": 24.99, "stock": 30},
            {"name": "Proteína Whey Chocolate", "category": "Proteínas", "price": 45.99, "stock": 25},
            {"name": "Magnesio 400mg", "category": "Minerales", "price": 12.99, "stock": 40}
        ]
        
        results = []
        for product in sample_products:
            try:
                response = requests.post(f"{API_GATEWAY_URL}/product", json=product, timeout=10)
                if response.status_code in [200, 201]:
                    results.append({"product": product["name"], "status": "success"})
                else:
                    results.append({"product": product["name"], "status": "error", "details": response.text})
            except Exception as e:
                results.append({"product": product["name"], "status": "error", "details": str(e)})
        
        return jsonify({
            "message": "Database initialization attempted",
            "results": results,
            "api_gateway_url": API_GATEWAY_URL
        })
        
    except Exception as e:
        return jsonify({"error": f"Error initializing database: {str(e)}"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF
        gunicorn --bind 0.0.0.0:8080 app:app
      EOT
      ]
      
      ports {
        container_port = var.flask_app_port
      }

      env {
        name  = "API_GATEWAY_URL"
        value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
      }

      env {
        name  = "FLASK_ENV"
        value = "production"
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_project_service.apis,
    aws_api_gateway_deployment.api
  ]
}

# Actualizar Cloud Run después de pushear nueva imagen
resource "null_resource" "update_cloud_run" {
  # Este recurso ya no es necesario porque el servicio se auto-actualiza
  count = 0
}

# Inicializar base de datos automáticamente
resource "null_resource" "init_database" {
  # Trigger para ejecutar solo una vez o cuando cambien las credenciales
  triggers = {
    db_endpoint = aws_db_instance.main_database.address
    db_name = var.db_name
    db_username = var.db_username
    # No incluir password en triggers por seguridad
  }

  provisioner "local-exec" {
    command = <<EOF
cd ${path.module}/../scripts
pip install -r requirements.txt
python setup_database.py \
  --host ${aws_db_instance.main_database.address} \
  --user ${var.db_username} \
  --password "${var.db_password}" \
  --database ${var.db_name}
EOF
  }

  depends_on = [
    aws_db_instance.main_database
  ]
}
