# main terraform script

# provider block
provider "aws" {
  profile = "personal"
  region  = "ca-central-1"
}

# VPC block
resource "aws_vpc" "main" {
  cidr_block                       = "10.2.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = false # Ensuring IPv6 CIDR block is not assigned

  tags = {
    Name = "Project VPC"
  }
}

# public subnet block
resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ca-central-1a"
  cidr_block        = "10.2.0.0/24"

  tags = {
    Name = "Public Subnet A"
  }
}

# application subnet block
resource "aws_subnet" "application_subnet_a" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ca-central-1a"
  cidr_block        = "10.2.2.0/24"

  tags = {
    Name = "Application Subnet A"
  }
}

# data subnet block
resource "aws_subnet" "data_subnet_a" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ca-central-1a"
  cidr_block        = "10.2.4.0/24"

  tags = {
    Name = "Data Subnet A"
  }
}

# public subnet block
resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ca-central-1b"
  cidr_block        = "10.2.1.0/24"

  tags = {
    Name = "Public Subnet B"
  }
}

# application subnet block
resource "aws_subnet" "application_subnet_b" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ca-central-1b"
  cidr_block        = "10.2.3.0/24"

  tags = {
    Name = "Application Subnet B"
  }
}

# data subnet block
resource "aws_subnet" "data_subnet_b" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ca-central-1b"
  cidr_block        = "10.2.5.0/24"

  tags = {
    Name = "Data Subnet B"
  }
}

# create IGW
#         type                  name
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "igw_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "igw_route_table"
  }
}

resource "aws_route_table_association" "rta_public_subnet_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.igw_route_table.id
}

resource "aws_route_table_association" "rta_public_subnet_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.igw_route_table.id
}

# create 2 elastic ips for a and b
resource "aws_eip" "eip_a" {
  domain = "vpc"
  tags = {
    Name = "eip_A"
  }
}

resource "aws_eip" "eip_b" {
  domain = "vpc"
  tags = {
    Name = "eip_B"
  }
}

resource "aws_nat_gateway" "ngw_a" {
  allocation_id     = aws_eip.eip_a.id
  subnet_id         = aws_subnet.public_subnet_a.id
  connectivity_type = "public"

  tags = {
    Name = "gw_NAT_A"
  }
}

resource "aws_nat_gateway" "ngw_b" {
  allocation_id     = aws_eip.eip_b.id
  subnet_id         = aws_subnet.public_subnet_b.id
  connectivity_type = "public"

  tags = {
    Name = "gw_NAT_B"
  }

}

resource "aws_route_table" "ngw_route_table_A" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw_a.id
  }

  tags = {
    Name = "ngw_route_table_A"
  }
}

resource "aws_route_table" "ngw_route_table_B" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw_b.id
  }

  tags = {
    Name = "ngw_route_table_B"
  }
}

resource "aws_route_table_association" "rta_application_subnet_a" {
  subnet_id      = aws_subnet.application_subnet_a.id
  route_table_id = aws_route_table.ngw_route_table_A.id
}

resource "aws_route_table_association" "rta_application_subnet_b" {
  subnet_id      = aws_subnet.application_subnet_b.id
  route_table_id = aws_route_table.ngw_route_table_B.id
}

# set up RDS database 

resource "aws_security_group" "wp_db_clients" {
  name        = "WP Database Clients"
  description = "Security group for Wordpress Database clients"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "WP_Database_Clients"
  }
}

resource "aws_security_group" "wp_db" {
  name        = "WP Database"
  description = "Database instance security group"
  vpc_id      = aws_vpc.main.id

  # MySQL/Aurora
  ingress {
    from_port       = 3306
    protocol        = "tcp"
    to_port         = 3306
    security_groups = [aws_security_group.wp_db_clients.id]
    description     = " MySQL/Aurora which allows traffic on port 3306 from Custom source WP Database Clients security group."
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "WP_Database"
  }
}

# Create an RDS subnet group

resource "aws_db_subnet_group" "aurora-wordpress" {
  name        = "aurora-wordpress"
  subnet_ids  = [aws_subnet.data_subnet_a.id, aws_subnet.data_subnet_b.id]
  description = "RDS subnet group used by Wordpress"
  tags = {
    Name = "Aurora-Wordpress"
  }
}

# Create the RDS cluster configuration
resource "aws_rds_cluster" "wordpress-workshop" {
  cluster_identifier     = "wordpress-workshop"
  availability_zones     = ["ca-central-1a", "ca-central-1b"]
  engine                 = "aurora-mysql"
  engine_mode            = "provisioned" # Aurora MySQL requires provisioned engine mode
  master_username        = "wpadmin"
  master_password        = "wpadmin123"
  vpc_security_group_ids = [aws_security_group.wp_db.id, aws_security_group.wp_db_clients.id]
  db_subnet_group_name   = aws_db_subnet_group.aurora-wordpress.name
  database_name          = "wordpress"
  #final_snapshot_identifier = "final-snap-shot"
  skip_final_snapshot     = true
  backup_retention_period = 0
}

# Add instance to RDS cluster configuration
resource "aws_rds_cluster_instance" "cluster_instances" {
  cluster_identifier           = aws_rds_cluster.wordpress-workshop.id
  identifier                   = "wordpress-workshop-${count.index}"
  instance_class               = "db.r5.large"
  count                        = 2
  engine                       = aws_rds_cluster.wordpress-workshop.engine
  db_subnet_group_name         = aws_rds_cluster.wordpress-workshop.db_subnet_group_name
  performance_insights_enabled = true
}


# Create EFS security groups

resource "aws_security_group" "wp_efs_clients" {
  name        = "WP EFS Clients"
  description = "Security group for WP EFS Clients"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "WP_EFS_Clients"
  }
}

resource "aws_security_group" "wp_efs" {
  name        = "WP EFS"
  description = "WP EFS security group"
  vpc_id      = aws_vpc.main.id

  # NFS
  ingress {
    from_port       = 2049
    protocol        = "tcp"
    to_port         = 2049
    security_groups = [aws_security_group.wp_efs_clients.id]
    description     = "NFS TCP port 2049 for EFS share"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "WP EFS security group"
  }
}

resource "aws_efs_file_system" "wordpress-efs" {
  creation_token = "wordpress-EFS"
  encrypted      = true
  tags = {
    Name = "Wordpress-EFS"
  }
}

resource "aws_efs_mount_target" "efs_a" {
  file_system_id  = aws_efs_file_system.wordpress-efs.id
  subnet_id       = aws_subnet.data_subnet_a.id
  security_groups = [aws_security_group.wp_efs.id]
}

resource "aws_efs_mount_target" "efs_b" {
  file_system_id  = aws_efs_file_system.wordpress-efs.id
  subnet_id       = aws_subnet.data_subnet_b.id
  security_groups = [aws_security_group.wp_efs.id]
}

# LOAD BALANCER CONFIGURATION 
resource "aws_security_group" "wp_load_balancer" {
  name        = "WP Load Balancer"
  description = "WP Load Balancer"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "WP load balancer"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.wp_load_balancer.id
  cidr_ipv4         = "99.251.238.23/32"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_security_group" "wp_web_servers" {
  name        = "WP web server"
  description = "WP web server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    protocol        = "tcp"
    to_port         = 80
    security_groups = [aws_security_group.wp_load_balancer.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "WP web server"
  }
}

resource "aws_lb" "wordpress-alb" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.wp_load_balancer.id]
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]

  enable_deletion_protection = true

  tags = {
    Name = "wordpress-alb"
  }
}

resource "aws_lb_target_group" "wordpress-targetgroup" {
  name     = "Wordpress-TargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled = true
    path    = "/phpinfo.php"
  }
}

resource "aws_lb_listener" "wordpress-listener" {
  load_balancer_arn = aws_lb.wordpress-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress-targetgroup.arn
  }
}


# Create a launch template 

resource "aws_launch_template" "wp-web-servers-lt" {
  name          = "WP-WebServers-LT"
  description   = "WP WebServers Launch Template"
  image_id      = "ami-07117708253546063"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.wp_db_clients.id,
    aws_security_group.wp_web_servers.id,
  aws_security_group.wp_efs_clients.id]
  user_data = filebase64("${path.module}/user-data.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "wp-web-servers-lt"
    }
  }

}

# create autoscaling group

resource "aws_autoscaling_group" "wp-asg" {
  name = "Wordpress-ASG"
  vpc_zone_identifier = [aws_subnet.application_subnet_a.id,
  aws_subnet.application_subnet_b.id]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  desired_capacity          = 2
  max_size                  = 4
  min_size                  = 2
  default_instance_warmup   = 300

  launch_template {
    id = aws_launch_template.wp-web-servers-lt.id
  }
}

# Create a new load balancer attachment
resource "aws_autoscaling_attachment" "example" {
  autoscaling_group_name = aws_autoscaling_group.wp-asg.id
  lb_target_group_arn    = aws_lb_target_group.wordpress-targetgroup.arn
}

resource "aws_autoscaling_policy" "wp-tracking-policy-cpuutil" {
  autoscaling_group_name = aws_autoscaling_group.wp-asg.name
  name                   = "wp-tracking-policy-cpuutil"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"

    }
    target_value = 80
  }
}
