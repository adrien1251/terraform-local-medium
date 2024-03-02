# 1. Initialisation des providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 2. Initialisation de l'api gateway, du deploiement et du stage
resource "aws_api_gateway_rest_api" "medium_test_apgw" {
  name = "medium_test"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "medium_test_deployment" {
  rest_api_id = aws_api_gateway_rest_api.medium_test_apgw.id

  triggers = {
    redeployment = sha1(timestamp())
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.medium_agw_resource_get_integrations,
    aws_api_gateway_integration.medium_agw_resource_options_integrations
  ]
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.medium_test_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.medium_test_apgw.id
  stage_name    = "api"
}

# 3. Création des methods d'integrations de l'api gateway

resource "aws_api_gateway_resource" "medium_agw_resource" {
  rest_api_id = aws_api_gateway_rest_api.medium_test_apgw.id
  parent_id   = aws_api_gateway_rest_api.medium_test_apgw.root_resource_id
  path_part   = "hello_world"
}

resource "aws_api_gateway_method" "medium_agw_resource_method" {
  rest_api_id   = aws_api_gateway_rest_api.medium_test_apgw.id
  resource_id   = aws_api_gateway_resource.medium_agw_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "medium_agw_resource_options_response_200" {
  rest_api_id = aws_api_gateway_rest_api.medium_test_apgw.id
  resource_id = aws_api_gateway_resource.medium_agw_resource.id
  http_method = aws_api_gateway_method.medium_agw_resource_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "medium_agw_resource_options_integrations" {
  rest_api_id = aws_api_gateway_rest_api.medium_test_apgw.id
  resource_id = aws_api_gateway_resource.medium_agw_resource.id
  http_method = aws_api_gateway_method.medium_agw_resource_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_integration_response" "medium_agw_resource_options_integrations_response" {
  rest_api_id = aws_api_gateway_rest_api.medium_test_apgw.id
  resource_id = aws_api_gateway_resource.medium_agw_resource.id
  http_method = aws_api_gateway_method.medium_agw_resource_method.http_method
  status_code = aws_api_gateway_method_response.medium_agw_resource_options_response_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'*'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.medium_agw_resource_options_integrations]
}

resource "aws_api_gateway_method" "medium_agw_resource_method_get" {
  rest_api_id   = aws_api_gateway_rest_api.medium_test_apgw.id
  resource_id   = aws_api_gateway_resource.medium_agw_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "medium_agw_resource_get_response_200" {
  rest_api_id = aws_api_gateway_rest_api.medium_test_apgw.id
  resource_id = aws_api_gateway_resource.medium_agw_resource.id
  http_method = aws_api_gateway_method.medium_agw_resource_method_get.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "medium_agw_resource_get_integrations" {
  rest_api_id             = aws_api_gateway_rest_api.medium_test_apgw.id
  resource_id             = aws_api_gateway_resource.medium_agw_resource.id
  http_method             = aws_api_gateway_method.medium_agw_resource_method_get.http_method
  integration_http_method = "GET"
  type                    = "AWS"
  uri                     = module.lambda_medium.lambda_function_invoke_arn
  timeout_milliseconds    = 12000
}

resource "aws_api_gateway_integration_response" "medium_agw_resource_get_integrations_response" {
  rest_api_id = aws_api_gateway_rest_api.medium_test_apgw.id
  resource_id = aws_api_gateway_resource.medium_agw_resource.id
  http_method = aws_api_gateway_method.medium_agw_resource_method_get.http_method
  status_code = aws_api_gateway_method_response.medium_agw_resource_get_response_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'*'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.medium_agw_resource_get_integrations]
}

# 4. Création du rôle pour la lambda
resource "aws_iam_role" "medium_lambda_role" {
  name = "medium_lambda_role"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Sid       = ""
          Principal = { Service = "lambda.amazonaws.com" }
        }
      ]
    }
  )
}

# 5. Création de la lambda 
# Sur la localstack, nous somme obligé de créer la lambda avec un zip car
# la fonction pour la dpéloyer avec une image docker est payante
module "lambda_medium" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "lambda_medium"
  description   = "Lambda pour tester la localstack"
  handler       = "lambda-medium.apiHandler"
  runtime       = "nodejs18.x"

  publish        = true
  create_package = false
  s3_existing_package = {
    bucket = aws_s3_bucket.lambda_s3_build.id
    key    = aws_s3_object.lambda_s3_function.id
  }

  memory_size                       = 128
  timeout                           = 10
  cloudwatch_logs_retention_in_days = 1

  environment_variables = {}

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${aws_api_gateway_stage.stage.execution_arn}/*/*"
    }
  }

  create_role = false
  lambda_role = aws_iam_role.medium_lambda_role.arn

  depends_on = [aws_s3_bucket.lambda_s3_build]
}

resource "aws_s3_bucket" "lambda_s3_build" {
  bucket = "lambda-medium-build"
}

data "archive_file" "zip_lambda" {
  type        = "zip"
  source_file = "../lambda-medium.js"
  output_path = "lambda-medium.zip"
}

resource "aws_s3_object" "lambda_s3_function" {
  bucket = aws_s3_bucket.lambda_s3_build.id
  key    = data.archive_file.zip_lambda.output_path
  source = data.archive_file.zip_lambda.output_path
}
