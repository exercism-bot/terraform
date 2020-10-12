# ###
# Set up an iam role that allows servers to write
# to any services required.
# ###

resource "aws_iam_role" "ecs_webserver" {
  name               = "ecs_webserver"
  assume_role_policy = var.aws_iam_policy_document_assume_ecs_role.json
}
resource "aws_iam_role_policy_attachment" "webservers_write_to_cloudwatch" {
  role       = aws_iam_role.ecs_webserver.name
  policy_arn = var.aws_iam_policy_write_to_cloudwatch.arn
}
resource "aws_iam_role_policy_attachment" "webservers_access_dynamodb" {
  role       = aws_iam_role.ecs_webserver.name
  policy_arn = var.aws_iam_policy_access_dynamodb.arn
}

# ###
# Set up the cluster
# ###
resource "aws_ecs_cluster" "webservers" {
  name = "webservers"
}
data "template_file" "webservers" {
  template = file("./templates/ecs_webservers.json.tpl")

  vars = {
    nginx_image        = "${aws_ecr_repository.webserver_nginx.repository_url}:latest"
    rails_image        = "${aws_ecr_repository.webserver_rails.repository_url}:latest"
    anycable_go_image  = "${aws_ecr_repository.webserver_anycable_go.repository_url}:latest"
    anycable_redis_url = local.anycable_redis_url
    http_port          = var.http_port
    websockets_port    = var.websockets_port
    region             = var.region
    log_group_name     = aws_cloudwatch_log_group.webservers.name
  }
}
resource "aws_ecs_task_definition" "webservers" {
  family                   = "webservers"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  container_definitions    = data.template_file.webservers.rendered
  execution_role_arn       = var.aws_iam_role_ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_webserver.arn
  tags                     = {}
}
resource "aws_ecs_service" "webservers" {
  name            = "webservers"
  cluster         = aws_ecs_cluster.webservers.id
  task_definition = aws_ecs_task_definition.webservers.arn
  desired_count   = var.container_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_webservers.id]
    subnets          = var.aws_subnet_publics.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.webservers_http.id
    container_name   = "nginx"
    container_port   = var.http_port
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.webservers_websockets.id
    container_name   = "anycable_go"
    container_port   = var.websockets_port
  }

  depends_on = [
    aws_alb_listener.webservers_http,
    aws_alb_listener.webservers_websockets,
    var.aws_iam_role_policy_attachment_ecs_task_execution_role,
    aws_security_group.ecs_webservers
  ]
}
