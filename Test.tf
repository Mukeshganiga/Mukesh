provider "aws" {
  region     = "us-east-2"
  access_key = "AKIASG57RLGYJNRZYGQG"
  secret_key = "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"
}
resource "aws_instance" "demo" {
  ami           = "ami-06013f13f176912f5"
  instance_type = "t2.micro"

  tags = {
    Name = "Practical"
  }
}
resource "aws_eip" "elasticip"{
    instance = aws_instance.demo.id
}
output "EIP"{
    value = aws_eip.elasticip.public_ip
}