provider "aws" {
  region = "us-east-1"  # Cambia a tu región AWS deseada
}

resource "aws_security_group" "lb_sg" {
  name        = "lb-sg"
  description = "Security group for load balancer"
  
  vpc_id = var.vpc_id

  # Permitir tráfico entrante desde Internet en el puerto del load balancer
  # Ajusta el puerto y el protocolo según tu configuración
  ingress {
    from_port   = 80  # Puerto del load balancer
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir tráfico saliente hacia el puerto del contenedor ECS
  # Ajusta el puerto y el protocolo según tu configuración
  egress {
    from_port   = 0  # Puerto de la aplicación en el contenedor
    to_port     = 65535  # Puerto de la aplicación en el contenedor
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg-web" {
  name        = "web-sg"
  description = "Security group for ECS container"
  
  vpc_id = var.vpc_id

  # Permitir tráfico saliente hacia el puerto de la aplicación en el contenedor
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir tráfico entrante desde el security group del load balancer
  # Ajusta el puerto y el protocolo según tu configuración
  ingress {
    from_port        = 0  # Puerto de la aplicación en el contenedor
    to_port          = 65535  # Puerto de la aplicación en el contenedor
    protocol         = "tcp"
    security_groups  = [aws_security_group.lb_sg.id]
  }
}

resource "aws_lb" "app_lb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["subnet-01337e6e80b2f251b", "subnet-064881b5071a96304"]
  security_groups    = [aws_security_group.lb_sg.id]
}

resource "aws_lb_target_group" "app_target_group" {
  name     = "my-webcv-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id 
  target_type = "ip"
  health_check {
      path                  = "/"
      protocol              = "HTTP"
      matcher               = "200"
      port                  = "traffic-port"
      healthy_threshold     = 2
      unhealthy_threshold   = 2
      timeout               = 20
      interval              = 30
  }

}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

/*resource "aws_lb_listener_rule" "root_listener_rule" {
  listener_arn = aws_lb_listener.web_listener.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}*/



resource "aws_iam_role" "ecs_execution_role" {
  name               = "ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_attachment_v2" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}



resource "aws_ecs_cluster" "web-cluster" {
  name = "web-cluster"  
}

resource "aws_ecs_task_definition" "web-cv-task" {
  family                   = "web-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu             = 256  # Asigna 0.25 unidades de CPU
  memory          = 512  # Asigna 512 MB de memoria

  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "cv-nginx"
    image = "snakierboss/cv-nginx:v10"
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "nginx-cv-container",
            "awslogs-region": "us-east-1",
            "awslogs-create-group": "true",
            "awslogs-stream-prefix": "nginx-cv"
        }
    }
  }])
}

resource "aws_ecs_service" "web-service-cv" {
  name            = "web-service-cv"
  cluster         = aws_ecs_cluster.web-cluster.id
  task_definition = aws_ecs_task_definition.web-cv-task.arn
  launch_type     = "FARGATE"
  desired_count = 1

  network_configuration {
    subnets = ["subnet-01337e6e80b2f251b", "subnet-064881b5071a96304"]
    assign_public_ip = true 
    security_groups = [aws_security_group.sg-web.id] 
  }

load_balancer {
    target_group_arn = aws_lb_target_group.app_target_group.arn
    container_name   = "cv-nginx"
    container_port   = 80
  }
}