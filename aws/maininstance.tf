variable "instance_name_maininstance" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "MainInstance"
}



data "aws_ami" "latestamazon2" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-*-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["amazon"]
}


resource "aws_instance" "maininstance" {
  #ami                         = "ami-00a4e06732205ac29"
  ami                         = data.aws_ami.latestamazon2.id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.main_sg.id]
  subnet_id                   = aws_subnet.subnet_main.id
  associate_public_ip_address = true
  key_name                    = var.main_key_name
  tags = {
    Name    = var.instance_name_maininstance
    Purpose = "LAB"
    Role    = "OAM"
  }

  provisioner "remote-exec" {
    inline = ["sudo hostnamectl set-hostname ${var.instance_name_maininstance}"]
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key)
    host        = self.public_ip
  }
}

