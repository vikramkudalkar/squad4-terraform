
provider "aws" {
  region = "us-west-2"  
}


resource "aws_vpc" "squad4_vpc" {
  cidr_block = "10.0.0.0/16"  

  tags = {
    Name = "squad4-VPC"
  }
}


resource "aws_subnet" "squad4_public_subnet" {
  vpc_id    = aws_vpc.squad4_vpc.id
  cidr_block = "10.0.1.0/24"  
  availability_zone = "us-west-2a"  
  map_public_ip_on_launch = true  

  tags = {
    Name = "squad4-Public-Subnet"
  }
}

resource "aws_subnet" "squad4_private_subnet" {
  vpc_id    = aws_vpc.squad4_vpc.id
  cidr_block = "10.0.2.0/24"  
  availability_zone = "us-west-2b"  
  map_public_ip_on_launch = true  

  tags = {
    Name = "squad4-Public-Subnet"
  }
}


resource "aws_internet_gateway" "squad4_internet_gateway" {
  vpc_id = aws_vpc.squad4_vpc.id

  tags = {
    Name = "squad4-Internet-Gateway"
  }
}


resource "aws_route_table" "squad4_route_table" {
  vpc_id = aws_vpc.squad4_vpc.id

 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.squad4_internet_gateway.id
  }

  tags = {
    Name = "squad4-Route-Table"
  }
}


resource "aws_route_table_association" "squad4_route_table_association" {
  subnet_id = aws_subnet.squad4_public_subnet.id
  route_table_id = aws_route_table.squad4_route_table.id
}


resource "aws_security_group" "squad4_security_group" {
  vpc_id       = aws_vpc.squad4_vpc.id
  name         = "squad4-Security-Group"
  description  = "Allow SSH and HTTP access"


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open to all (be cautious with this setting)
  }


  ingress {
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
    Name = "squad4-Security-Group"
  }
}

resource "aws_s3_bucket" "terraform-squad4-s3" {
  bucket = "terraform-squad4-s3"

}

resource "aws_dynamodb_table" "squad4-ddb" {
  name = "quad4-ddb"
  hash_key = "LockID"
  read_capacity = 20
  write_capacity = 20
 
  attribute {
    name = "LockID"
    type = "S"
  }
}


# Create IAM role for EKS cluster (cluster's control plane)
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

# Attach EKS Cluster policy to the IAM role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Create IAM role for EKS worker nodes
resource "aws_iam_role" "eks_worker_role" {
  name = "eks-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

# Attach necessary policies to the worker node role
resource "aws_iam_role_policy_attachment" "eks_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_worker_role.name
}

resource "aws_iam_role_policy_attachment" "eks_CNI_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_worker_role.name
}

# Create EKS Cluster
resource "aws_eks_cluster" "my_cluster" {
  name     = "-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# Create Instance Profile for worker nodes
resource "aws_iam_instance_profile" "eks_worker_profile" {
  name = "eks-worker-instance-profile"
  role = aws_iam_role.eks_worker_role.name
}
