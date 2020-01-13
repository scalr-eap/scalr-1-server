## Default SG

data "aws_security_group" "default_sg" {
  name = "default"
  vpc_id = var.vpc
}


###############################
#
# Scalr Security Group

resource "aws_security_group" "scalr_sg" {
  name        = "scalr_sg-${random_string.random.result}"
  description = "General rules for Scalr Servers"
  vpc_id      = var.vpc

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 6275
    to_port     = 6275
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 6276
    to_port     = 6276
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 6291
    to_port     = 6291
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 15671
    to_port     = 15671
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 11211
    to_port     = 11211
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
