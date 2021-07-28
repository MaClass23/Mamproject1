# creata vpc
# create an internet Gateway. this will be created within the vpc so that tarffic can be routed to/from the internet
# create a custom Route Table within the vpc
# create a subnet
# Associate subnet wuth Route Table
# create security group to allow ports 22, 80, 443
# create a network interface with an ip in the subnet that was created in step 4
# Assign an elastic ip to the network interface created in step 7
# create a key pair that will be attached to the ec2 instances
# create ubuntu server and install/enable apache2

# 1. Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  #access_key = "***********" not recommended to hardcode
  #secret_key = "************" cAlways configure credentials on the CLI
}

# 2. create a vpc
resource "aws_vpc" "mavpc1" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vpc1"
  }
}

# 3. create internet gateway mapped to the vpc
resource "aws_internet_gateway" "igw1" {
    vpc_id = aws_vpc.mavpc1.id
}

# 4. create a route table mapped to the vpc

resource "aws_route_table" "maroutetable" {
  vpc_id = aws_vpc.mavpc1.id

  route {
    cidr_block = "0.0.0.0/0" # Allows all traffic
    gateway_id = aws_internet_gateway.igw1.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.igw1.id
  }

  tags = {
    Name = "maRT"
  }
}

# 5. create a subnet

resource "aws_subnet" "masubnet" {
  vpc_id     = aws_vpc.mavpc1.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"  # specify an AZ-optional

  tags = {
    Name = "masubnet"
  }
}

# 6. Associate subnet with route table
resource "aws_route_table_association" "Rtassociation" {
  subnet_id      = aws_subnet.masubnet.id
  route_table_id = aws_route_table.maroutetable.id
}

# 7. create a security group (defining both inbound and outbound traffic - fireworld)
resource "aws_security_group" "maSG" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.mavpc1.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # allows inbound traffic from anywhere 
    # this can be restricted by specifying ip addresses from which traffic is allowed
  }

ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
}

ingress {
    description      = "SSH"
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
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "maSG"
  }
}

# 8. create a network interface with an ip in the subnet that was created above - stage 5

resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.masubnet.id
  private_ips     = ["10.0.1.50"] # we can add nore IPs
  security_groups = [aws_security_group.maSG.id]
}

# 9. assign an elastic IP to the network interface created in stage 8

resource "aws_eip" "eip1" {
  vpc                       = true
  network_interface         = aws_network_interface.test.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.igw1] # your add as many criteria as required
}

# 10. create ubuntu server and install/enable apache2

resource "aws_instance" "webServer" {
    ami = "ami-0747bdcabd34c712a"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a" # same AZ for subnet 
    key_name = "legacykey"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.test.id

    }
    
    user_data = <<-E0F
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first webserver > /var/www/html/index.html'
                E0F
     tags = {
         Name = "websever"
     }

    }
