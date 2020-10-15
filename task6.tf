provider "aws" {
  region     = "ap-south-1"
  profile    = "sahil123"
}

//creating IAM role for cluster
resource "aws_iam_role" "sahil-iam-role" {
  name = "sahil-eks-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "sahil-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.sahil-iam-role.name
}
resource "aws_iam_role_policy_attachment" "sahil-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.sahil-iam-role.name
}


//Creating the eks cluster



resource "aws_eks_cluster" "sahil-eks-cluster" {
  name     = "sahil-eks-cluster"
  role_arn = aws_iam_role.sahil-iam-role.arn

  vpc_config {
    subnet_ids = ["subnet-beaa17c5", "subnet-54a1ca18"]
  }
  depends_on = [
    aws_iam_role_policy_attachment.sahil-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.sahil-AmazonEKSVPCResourceController,
  ]
}



//Creating IAM role for node group



resource "aws_iam_role" "worker-nodes" {
  name = "eks-node-group"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.example.name
}


//Creating node groups




resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.sahil-eks-cluster.name
  node_group_name = "sahil-node-group"
  node_role_arn   = aws_iam_role.worker-nodes.arn
  subnet_ids      = ["subnet-beaa17c5", "subnet-54a1ca18"]
  instance_types  = ["t2.micro"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}

//Creating security group


resource "aws_security_group" "rds-sg" {
  name        = "rds-sg"
  description = "Allow port 3306"

  ingress {
    description = "port 3306"
    from_port   =  3306
    to_port     =  3306
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
    Name = "RDS-SG"
  }
}

//Creating the database


resource "aws_db_instance" "sahil-db" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "my-db"
  username             = "sahil-db"
  password             = "123"
  parameter_group_name = "default.mysql5.7"
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.rds-sg.id]
  skip_final_snapshot  = true
}

resource "null_resource" "null-1"
{
depends_on=[
            aws_eks_cluster.sahil_eks_cluster,
            aws_eks_node_group.example,
]
provisioner "local-exec"{
command= "aws eks update-kubeconfig --name sahil-eks-cluster"
}
  }

//Launching the wordpress pod

provider "kubernetes"{
}
resource "kubernetes_deployment" "wordpress-instance" {
 metadata {
    name = "terraform-example"
    labels = {
      test = "MyExampleApp"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        test = "MyExampleApp"
      }
    }

    template {
      metadata {
        labels = {
          test = "MyExampleApp"
        }
      }
  spec {
   container {
    image = "wordpress:4.8-apache"
    name = "wordpress-instance" 
    }
   }
  }
}



resource "kubernetes_service" "sahil_lb" {
depends_on=[
kubernetes_deployment.wordpress-instance
]
 metadata {
  name = "sahil_lb"
  }
  spec {
   selector = {
    app = "${kubernetes_deployment.wordpress-instance.metadata.0.labels.test}"
   }
   port {
    port = 80
   }
   type = "LoadBalancer"
  }
}





















