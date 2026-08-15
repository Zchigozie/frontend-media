
# Fetch the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security Group
resource "aws_security_group" "web_sg" {
  name        = "front-app-sg"
  description = "Allow HTTP and SSH"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}

# EC2 Instance
resource "aws_instance" "vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
            #!/bin/bash
# Update packages and install Nginx + Git + Curl
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install nginx git curl -y

# Install Node.js 20 and npm
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Start and enable Nginx service
sudo systemctl start nginx
sudo systemctl enable nginx

# Clone the frontend repository
git pull https://github.com/Zchigozie/frontend-mediahub.git /home/ubuntu/frontend-mediahub

# Move into project directory
cd /home/ubuntu/frontend-mediahub/mediahub

# Install dependencies and build the app
npm install
npm run build

# Clear Nginx's default splash page
sudo rm -rf /var/www/html/*

# Copy built files into Nginx web root
sudo cp -r dist/* /var/www/html/

# Ensure correct permissions
sudo chown -R www-data:www-data /var/www/html/

# Configure Nginx for SPA routing
sudo tee /etc/nginx/sites-available/default > /dev/null << 'EON'
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri /index.html;
    }
}
EON

# Test and restart Nginx
sudo nginx -t
sudo systemctl restart nginx
EOF

  tags = {
    Name = "front Site"
  }
}

output "site_url" {
  value       = "http://${aws_instance.vm.public_ip}"
  description = "Click this link to access your hosted Media-hub frontend project."
}
