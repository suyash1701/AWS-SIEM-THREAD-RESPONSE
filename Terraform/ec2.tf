# Use the default network that every AWS account already has
data "aws_vpc" "default" {
  default = true
}

# Find the latest Amazon Linux 2023 image automatically
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Firewall for the test server: no inbound traffic allowed
resource "aws_security_group" "test_server_sg" {
  name        = "siem-test-server-sg"
  description = "Test server firewall, no inbound"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# The test server
resource "aws_instance" "test_server" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.test_server_sg.id]

  tags = {
    Name    = "siem-test-server"
    Project = "siem-lab"
  }
}

output "test_server_id" {
  value = aws_instance.test_server.id
}