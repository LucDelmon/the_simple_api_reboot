#!/bin/bash
exec > /var/log/user-data.log 2>&1

SCRIPT_RUBY_VERSION="3.3.0"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
IMAGE_ID=$(curl -s http://169.254.169.254/latest/meta-data/ami-id)
export NO_PROXY="169.254.169.254"
export http_proxy="http://10.0.1.252:3128"
export https_proxy="http://10.0.1.252:3128"

# Set the CloudWatch Logs Group Name (can be set dynamically or hardcoded)
LOG_GROUP_NAME="/aws/ec2/$INSTANCE_ID"

## Adding github action public key to authorized_keys
echo "${SSH_PUBLIC_KEY}" >> /home/ubuntu/.ssh/authorized_keys

# Wait for network to be up
echo "Checking network connectivity..."
for i in {1..5}; do
    if curl -I http://example.com &> /dev/null; then
        echo "Network is up."
        break
    else
        echo "Network is down, attempt $i/5..."
        sleep 10
    fi
done

if [ $i -gt 5 ]; then
    echo "Failed to establish network connectivity."
    exit 1
fi

# Set up the APT proxy configuration
echo "Configuring APT to use the proxy..."

cat <<EOF | sudo tee /etc/apt/apt.conf.d/01proxy
Acquire::http::Proxy "http://10.0.1.252:3128/";
Acquire::https::Proxy "http://10.0.1.252:3128/";
EOF

# Install the necessary packages
sudo apt-get update
sudo apt-get install -y awscli jq libpq-dev unzip rpm

# Function to retrieve the Rails master key and set up the Rails environment variables
function setup_rails_env() {
    cat << 'EOL' | sudo tee /etc/profile.d/rails_env.sh > /dev/null
#!/bin/bash
export NO_PROXY="169.254.169.254"
export http_proxy="http://10.0.1.252:3128"
export https_proxy="http://10.0.1.252:3128"
# Retrieve the secret from AWS Secrets Manager
RAILS_MASTER_KEY=$(
    aws secretsmanager get-secret-value \
    --secret-id credential_encryption_key \
    --region ${REGION} \
    --query SecretString \
    --output text | jq -r '.credential_encryption_key'
)

# Export the RAILS_MASTER_KEY environment variable
export RAILS_MASTER_KEY
export DB_HOST='${DB_HOST}'
export DB_USERNAME='${DB_USERNAME}'
export WEB_CONCURRENCY=${WEB_CONCURRENCY}
export RAILS_ENV=production

EOL
}
setup_rails_env

wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Install the CloudWatch agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start

# Create the CloudWatch Agent configuration file
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null <<EOT
{
  "agent": {
    "run_as_user": "ubuntu"
  },
  "metrics": {
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "resources": [
          "*"
        ]
      }
    },
    "append_dimensions": {
      "ImageId": "$IMAGE_ID",
      "InstanceId": "$INSTANCE_ID",
      "InstanceType": "$INSTANCE_TYPE"
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/home/ubuntu/simple-api/current/log/puma.stdout.log",
            "log_group_name": "$LOG_GROUP_NAME",
            "log_stream_name": "$INSTANCE_ID/puma-stdout",
            "retention_in_days": 7,
            "filters": [
              {
                "type": "exclude",
                "expression": "Started GET \"/up\""
              },
              {
                "type": "exclude",
                "expression": "Processing by Rails::HealthController#show"
              },
              {
                "type": "exclude",
                "expression": "Completed 200 OK"
              }
            ]
          },
          {
            "file_path": "/home/ubuntu/simple-api/current/log/puma.stderr.log",
            "log_group_name": "$LOG_GROUP_NAME",
            "log_stream_name": "$INSTANCE_ID/puma-stderr",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
EOT


echo "[proxy]" >> /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml
echo "  http_proxy = \"$http_proxy\" " >> /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml
echo "  https_proxy = \"$https_proxy\" " >> /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml
echo "  no_proxy = \"$NO_PROXY\" " >> /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml

sudo rm /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/default # Remove the default configuration file that will conflict with the custom configuration

sudo systemctl restart amazon-cloudwatch-agent

# see https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html to add more metrics

sudo chmod +x /etc/profile.d/rails_env.sh # Make the script executable, so it runs on every login

sudo mkdir -p /etc/gnupg
cat <<EOF | sudo tee /etc/gnupg/dirmngr.conf
http-proxy http://10.0.1.252:3128/
EOF

# Ensure the proxy settings are reloaded
sudo pkill dirmngr || true

# Install RVM and Ruby
sudo apt install gnupg2
gpg2 --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable
source /etc/profile.d/rvm.sh
rvm install "$SCRIPT_RUBY_VERSION"
rvm use "$SCRIPT_RUBY_VERSION" --default
sudo usermod -aG rvm ubuntu

# Add a service for puma but does not start it (code is not deployed yet)

# Create the Puma service file
cat <<EOF > /etc/systemd/system/puma.service
[Unit]
Description=Puma HTTP Server
After=network.target

[Service]
Type=notify

WatchdogSec=10

User=ubuntu
WorkingDirectory=/home/ubuntu/simple-api/current
Environment="PATH=/usr/local/rvm/gems/$SCRIPT_RUBY_VERSION/bin:/usr/local/rvm/gems/$SCRIPT_RUBY_VERSION@global/bin:/usr/local/rvm/rubies/$SCRIPT_RUBY_VERSION/bin:/usr/local/rvm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
# load master key in the environment of the service then start puma
ExecStart=/bin/bash -c 'source /etc/profile.d/rails_env.sh && exec /usr/local/rvm/wrappers/default/bundle exec puma -C /home/ubuntu/simple-api/current/config/puma.rb'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new service
systemctl daemon-reload
systemctl enable puma
