provider "aws" {
    region ="ap-south-1"
    profile = "vishal"
}

resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "mynewvpc"
  }
}

resource "aws_subnet" "sub1" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "mysubnet1"
  }
}

resource "aws_subnet" "sub2" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "mysubnet2"
  }
}

resource "aws_security_group" "sg" {
  name        = "sgvpc"
  description = "Security group for VPC"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "TLS from VPC"
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
    Name = "mysg"
  }
}

resource "aws_instance" "wordpress_inst" {
    ami = "ami-052c08d70def0ac62"
    instance_type = "t2.micro"
    associate_public_ip_address = true
    subnet_id = "${aws_subnet.sub1.id}"
    key_name = "myNewkey2"
    vpc_security_group_ids = [ "${aws_security_group.sg.id}" ]
    tags = {
        Name = "Wordpress_LinuxWorld"
    }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
  tags = {
    Name = "igwmy"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "rtable"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.sub1.id}"
  route_table_id = "${aws_route_table.rt.id}"
}

resource "aws_security_group" "mysqlsg" {
  name        = "mysqlsgvpc"
  description = "Security group for MySql"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "SSH"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [ "${aws_security_group.sg.id}" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysqlmysg"
  }
}

resource "aws_instance" "mysql_inst" {
    ami = "ami-07a8c73a650069cf3"
    instance_type = "t2.micro"
    associate_public_ip_address = true
    subnet_id = "${aws_subnet.sub2.id}"
    key_name = "myNewkey2"
    vpc_security_group_ids = [ "${aws_security_group.mysqlsg.id}", "${aws_security_group.mysqlbatsonsg.id}" ]
    depends_on = [
        aws_security_group.mysqlbatsonsg
    ]
    tags = {
        Name = "Mysql_LinuxWorld"
    }
}

resource "null_resource" "cluster" {
  depends_on = [
      aws_instance.wordpress_inst,
      aws_instance.mysql_inst
  ]
}

# Security group created for Batson :
resource "aws_security_group" "batsonsg" {
  name        = "batson"
  description = "Security group for VPC"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "SSH"
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
    Name = "batsonmysg"
  }
}

#Instance for batson on public subnet
resource "aws_instance" "batson_inst" {
    ami = "ami-07a8c73a650069cf3"
    instance_type = "t2.micro"
    associate_public_ip_address = true
    subnet_id = "${aws_subnet.sub1.id}"
    key_name = "myNewkey2"
    vpc_security_group_ids = [ "${aws_security_group.batsonsg.id}" ]
    tags = {
        Name = "Batson_LinuxWorld"
    }
}

#Security group for MYSQL
resource "aws_security_group" "mysqlbatsonsg" {
  name        = "mysqlbatson"
  description = "Security group for VPC"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "SSH"
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
    Name = "mysqlbatson"
  }
}

#NAT Gateway
resource "aws_nat_gateway" "gw" {
  allocation_id = "eipalloc-04d08bd8eb697f41c"
  subnet_id     = "${aws_subnet.sub1.id}"

  tags = {
    Name = "NATgw"
  }
  depends_on = [
      aws_subnet.sub1
  ]
}

#Create route table for making path to NAT
resource "aws_route_table" "natrt" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.gw.id}"
  }
  
  depends_on  =[aws_nat_gateway.gw]
  tags = {
    Name = "natrtable"
  }
}

#Assosiate that route to private subnet
resource "aws_route_table_association" "natasso" {
  subnet_id      = "${aws_subnet.sub2.id}"
  route_table_id = "${aws_route_table.natrt.id}"
  depends_on = [aws_route_table.natrt]
}