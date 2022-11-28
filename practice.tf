provider "aws" {
    secret_key = "${var.secret_key}"
    access_key  = "${var.access_key }"
    region = "${var.region}"
}


#VPC 
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/21"

  tags = {
      Name = "Main VPC"
  }
}


# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"
  depends_on = [aws_vpc.main_vpc]

  tags = {
    Name = "Public Subnet"
  }
}


# Private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone = "ap-south-1b"
  depends_on = [aws_vpc.main_vpc]

  tags = {
    Name = "Private Subnet"
  }
}

# Route Table
resource "aws_route_table" "public_route_table" {
  tags = {
    Name = "Public rt table"
  }

  vpc_id = aws_vpc.main_vpc.id
  
}

# Associate route table with public subnet
resource "aws_route_table_association" "public_subnect_associate" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_internet_gateway" "main_igw" {
  tags = {
    Name = "Main IGW"
  }
  vpc_id = aws_vpc.main_vpc.id
  depends_on = [aws_vpc.main_vpc]
}

# Add default route in routing table to point to IGW
resource "aws_route" "allow_public_route" {
  route_table_id            = aws_route_table.public_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main_igw.id
}

# Create SG for Web Server
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "https from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "http from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "ssh from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_sg"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "db_sg"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "db request from VPC"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    description      = "ssh from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db_sg"
  }
}

# AWS pem key 

resource "tls_private_key" "tls_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "pem_keys" {
  key_name   = "techschool"
  public_key = tls_private_key.tls_private_key.public_key_openssh
}

resource "local_file" "techschool_pem_key" {
    content  = tls_private_key.tls_private_key.private_key_pem
    filename = "techschool.pem"
}

resource "aws_instance" "my_web_instance" {
  ami                    = "${var.ami}"
  instance_type          = "t2.large"
  key_name               = aws_key_pair.pem_keys.key_name
  //vpc_security_group_ids = ["${aws_security_group.web_security_group.id}"]
  subnet_id              = aws_subnet.public_subnet.id
  user_data = "${file("init.sh")}"
  tags = {
    Name = "my_web_instance"
  }
  volume_tags = {
    Name = "my_web_instance_volume"
  }
  # provisioner "remote-exec" { #install apache, mysql client, php
  #   inline = [
  #     "sudo mkdir -p /var/www/html/",
  #     "sudo yum update -y",
  #     "sudo yum install -y httpd",
  #     "sudo service httpd start",
  #     "sudo usermod -a -G apache centos",
  #     "sudo chown -R centos:apache /var/www",
  #     "sudo yum install -y mysql php php-mysql",
  #     ]
  # }
  provisioner "file" { #copy the index file form local to remote
   source      = "index.php"
    destination = "/tmp/index.php"
  }
  provisioner "remote-exec" {
   inline = [
    "sudo mv /tmp/index.php /var/www/html/index.php"
   ]
}
  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = ""
    host     = self.public_ip
    #copy <private.pem> to your local instance to the home directory
    #chmod 600 id_rsa.pem
    //private_key = "${file("d:\\terraform\\private\\myprivate.pem")}"
    private_key = "${file("techschool.pem")}"
    }
}



resource "aws_db_instance" "my_database_instance" {
    allocated_storage = 20
    storage_type = "gp2"
    engine = "mysql"
    engine_version = "5.7"
    instance_class = "db.t2.micro"
    port = 3306
    //vpc_security_group_ids = ["${aws_security_group.db_security_group.id}"]
    db_subnet_group_name = aws_subnet.private_subnet.id
    //name = "mydb"
    identifier = "mysqldb"
    username = "myuser"
    password = "mypassword"
    parameter_group_name = "default.mysql5.7"
    skip_final_snapshot = true
    tags = {
        Name = "my_database_instance"
    }
}
