data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_region" "current" {}


module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-1a", "us-west-1c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}


resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  vpc_security_group_ids = [ module.blog_sg.security_group_id ] 

  subnet_id = module.blog_vpc.public_subnets[0]

  tags = {
    Name = "HelloWorld"
  }
}


module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name    = "blog"
  vpc_id  = module.blog_vpc.vpc_id

  ingress_rules = [ "http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules = [ "all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

}

module "nlb" {
  source = "terraform-aws-modules/alb/aws"

  name               = "my-nlb"
  load_balancer_type = "network"
  vpc_id             = "vpc-abcde012"
  subnets            = ["subnet-abcde012", "subnet-bcde012a"]

  # Security Group
  enforce_security_group_inbound_rules_on_private_link_traffic = "on"

  security_group_ingress_rules = module.blog_sg.ingress_rules ["http-80-tcp"]
  security_group_egress_rules  = module.blog_vpc.egress_rules ["all-all"]

  access_logs = {
    bucket = "blog-logs"
  }


  target_groups = {
    ex-target = {
      name_prefix = "blog-"
      protocol    = "TCP"
      port        = 80
      target_type = "ip"
    }
  }

  tags = {
    Environment = "Development"
    Project     = "Example"
  }
}


