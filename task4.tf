provider "aws" {
  region = "ap-south-1"
  profile = "usertf"
}

# Creating VPC
resource "aws_vpc" "task4-vpc" {
  cidr_block = "192.168.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    "Name" = "task4-vpc" 
  }
}

# Creating Public Subnet for Wordpress
resource "aws_subnet" "task4-public-wp" {
  depends_on = [
    aws_vpc.task4-vpc,
  ]
  
  vpc_id = aws_vpc.task4-vpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "public-wp"
  }
}

# Creating Private Subnet for MySQL Database
resource "aws_subnet" "task4-private-db" {
  depends_on = [
    aws_vpc.task4-vpc,
  ]
  
  vpc_id = aws_vpc.task4-vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = false
  tags = {
    "Name" = "private-db"
  }
}

# Creating Internet Gateway for Public Subnet
resource "aws_internet_gateway" "task4-wp-ig" {
  depends_on = [
    aws_vpc.task4-vpc,
  ]
  
  vpc_id = aws_vpc.task4-vpc.id
  tags = {
    "Name" = "task4-wp-ig"
  }
}

# route table for Internet Gateway
resource "aws_route_table" "task4-rt-public" {
  depends_on = [
    aws_internet_gateway.task4-wp-ig,
  ]

  vpc_id = aws_vpc.task4-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task4-wp-ig.id
  }

  tags = {
    Name = "my-routing-table"
  }
}

# route table associate to Public Subnet
resource "aws_route_table_association" "task4-rt-public-ascn" {
  depends_on = [
    aws_route_table.task4-rt-public,
    aws_subnet.task4-public-wp,
  ]

  subnet_id = aws_subnet.task4-public-wp.id
  route_table_id = aws_route_table.task4-rt-public.id
}

# allocate EIP
resource "aws_eip" "task4-eip" {
  vpc = true
  depends_on = [
    aws_internet_gateway.task4-wp-ig,
  ]

  tags = {
    Name = "task4-eip"
  }
}

# create NAT Gateway for Private Subnet
resource "aws_nat_gateway" "task4-nat-gw" {
  depends_on = [
    aws_eip.task4-eip,
    aws_subnet.task4-private-db,
  ]

  allocation_id = aws_eip.task4-eip.id
  subnet_id = aws_subnet.task4-private-db.id

  tags = {
    Name = "task4-nat-gw"
  }
}

# route table for NAT Gateway
resource "aws_route_table" "task4-rt-private" {
  depends_on = [
    aws_nat_gateway.task4-nat-gw,
  ]

  vpc_id = aws_vpc.task4-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.task4-nat-gw.id
  }

  tags = {
    Name = "my-routing-table"
  }
}

# route table associate to Private Subnet
resource "aws_route_table_association" "task4-rt-private-ascn" {
  depends_on = [
    aws_route_table.task4-rt-private,
    aws_subnet.task4-private-db,
  ]

  subnet_id = aws_subnet.task4-private-db.id
  route_table_id = aws_route_table.task4-rt-private.id
}

# security group for Wordpress
resource "aws_security_group" "task4-sg-wp" {
  depends_on = [
    aws_vpc.task4-vpc,
  ]

  name        = "SG-Wordpress"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.task4-vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wp-sg"
  }
}

# security group for MySQL DB
resource "aws_security_group" "task4-sg-db" {
  depends_on = [
    aws_vpc.task4-vpc,
    aws_security_group.task4-sg-wp,
    aws_security_group.task4-sg-bastion,
  ]

  name        = "SG-Database"
  description = "Allow SG-Wordpress inbound traffic"
  vpc_id      = aws_vpc.task4-vpc.id

  ingress {
    description = "MySQL"
    security_groups = [
      aws_security_group.task4-sg-wp.id,
    ]
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
  }

  ingress {
    description = "SSH"
    security_groups = [
      aws_security_group.task4-sg-bastion.id,
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}

# security group for Bastion Host
resource "aws_security_group" "task4-sg-bastion" {
  depends_on = [
    aws_vpc.task4-vpc,
    aws_security_group.task4-sg-wp,
  ]

  name        = "SG-Bastion"
  description = "SG for Bastion Host"
  vpc_id      = aws_vpc.task4-vpc.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# MySQL instance
resource "aws_instance" "task4-mysql" {
  depends_on = [
    aws_security_group.task4-sg-db,
    aws_subnet.task4-private-db,
  ]

  ami = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  associate_public_ip_address = false
  subnet_id = aws_subnet.task4-private-db.id
  vpc_security_group_ids = [
    aws_security_group.task4-sg-db.id,
  ]
  key_name = "keyos1"

  tags ={
    Name = "task4-mysql"
  }
}

# WordPress instance
resource "aws_instance" "task4-wordpress" {
  depends_on = [
    aws_subnet.task4-public-wp,
    aws_security_group.task4-sg-wp,
  ]

  // ami = "ami-0447a12f28fddb066"
  ami = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id = aws_subnet.task4-public-wp.id
  vpc_security_group_ids = [
    aws_security_group.task4-sg-wp.id,
  ]
  key_name = "keyos1"

  tags ={
    Name = "task4-wordpress"
  }
}

# Bastion Host instance
resource "aws_instance" "task4-bastion" {
  ami = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  key_name = "keyos1"
  availability_zone = "ap-south-1a"
  subnet_id = aws_subnet.task4-public-wp.id
  security_groups = [
    aws_security_group.task4-sg-bastion.id,
  ]

  tags = {
  Name = "task4-bastion"
  }
}

