# ================================================
# DP-3 E-COMMERCE TERRAFORM OUTPUTS
# ================================================

# AWS Outputs
output "api_gateway_invoke_url" {
  description = "URL del API Gateway para llamadas desde el frontend"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
}

output "rds_public_endpoint" {
  description = "Endpoint público de la base de datos PostgreSQL RDS"
  value       = aws_db_instance.main_database.address
}

output "rds_port" {
  description = "Puerto de la base de datos PostgreSQL"
  value       = aws_db_instance.main_database.port
}

output "lambda_get_products_arn" {
  description = "ARN de la función Lambda GetProducts"
  value       = aws_lambda_function.get_products.arn
}

output "lambda_get_item_arn" {
  description = "ARN de la función Lambda GetItem"
  value       = aws_lambda_function.get_item.arn
}

output "lambda_add_product_arn" {
  description = "ARN de la función Lambda AddProduct"
  value       = aws_lambda_function.add_product.arn
}

# GCP Outputs
output "cloud_run_url" {
  description = "URL del servicio Cloud Run completo (aplicación principal)"
  value       = google_cloud_run_v2_service.flask_inline.uri
}

output "frontend_url" {
  description = "URL principal de la aplicación web"
  value       = google_cloud_run_v2_service.flask_inline.uri
}

output "artifact_registry_repository" {
  description = "URL del repositorio Artifact Registry"
  value       = google_artifact_registry_repository.repo.name
}

output "bigquery_dataset_id" {
  description = "ID del dataset BigQuery"
  value       = google_bigquery_dataset.ecommerce_dataset.dataset_id
}

output "bigquery_table_id" {
  description = "ID de la tabla BigQuery"
  value       = google_bigquery_table.products_table.table_id
}

# Database Connection Info
output "database_connection_info" {
  description = "Información de conexión a la base de datos"
  value = {
    host     = aws_db_instance.main_database.address
    port     = aws_db_instance.main_database.port
    database = aws_db_instance.main_database.db_name
    username = var.db_username
  }
  sensitive = true
}

# Project Information
output "project_name" {
  description = "Nombre del proyecto"
  value       = var.project_name
}

output "environment" {
  description = "Entorno de deployment"
  value       = var.environment
}

output "aws_region" {
  description = "Región AWS utilizada"
  value       = var.aws_region
}

output "gcp_region" {
  description = "Región GCP utilizada"  
  value       = var.gcp_region
}

output "deployment_summary" {
  description = "Resumen del deployment"
  value = {
    frontend_url      = google_cloud_run_v2_service.flask_inline.uri
    api_gateway_url   = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
    database_endpoint = aws_db_instance.main_database.address
    project_name      = var.project_name
    environment       = var.environment
    aws_region        = var.aws_region
    gcp_region        = var.gcp_region
  }
}