#!/bin/bash
exec > /var/log/user-data.log 2>&1

SCRIPT_RUBY_VERSION="3.3.0"
SCRIPT_BUNDLER_VERSION="2.5.6"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
IMAGE_ID=$(curl -s http://169.254.169.254/latest/meta-data/ami-id)

# Set the CloudWatch Logs Group Name (can be set dynamically or hardcoded)
LOG_GROUP_NAME="/aws/ec2/$INSTANCE_ID"

# Wait for network to be up
echo "Checking network connectivity..."
for i in {1..5}; do
    if ping -c 1 8.8.8.8 &> /dev/null; then
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

# Install the necessary packages
sudo apt-get update
sudo apt-get install -y awscli jq libpq-dev unzip rpm

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
            "file_path": "/home/ubuntu/current/log/puma.stdout.log",
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
            "file_path": "/home/ubuntu/current/log/puma.stderr.log",
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

sudo rm /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/default # Remove the default configuration file that will conflict with the custom configuration

sudo systemctl restart amazon-cloudwatch-agent

# see https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html to add more metrics

# Function to retrieve the Rails master key and set up the Rails environment variables
function setup_rails_env() {
    cat << 'EOL' | sudo tee /etc/profile.d/rails_env.sh > /dev/null
#!/bin/bash

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

sudo chmod +x /etc/profile.d/rails_env.sh # Make the script executable, so it runs on every login

# Install RVM and Ruby
sudo apt install gnupg2
gpg2 --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable
source /etc/profile.d/rvm.sh
rvm install "$SCRIPT_RUBY_VERSION"
rvm use "$SCRIPT_RUBY_VERSION" --default
gem install bundler -v "$SCRIPT_BUNDLER_VERSION"
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
WorkingDirectory=/home/ubuntu/current
Environment="PATH=/usr/local/rvm/gems/$SCRIPT_RUBY_VERSION/bin:/usr/local/rvm/gems/$SCRIPT_RUBY_VERSION@global/bin:/usr/local/rvm/rubies/$SCRIPT_RUBY_VERSION/bin:/usr/local/rvm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
# load master key in the environment of the service then start puma
ExecStart=/bin/bash -c 'source /etc/profile.d/rails_env.sh && exec /usr/local/rvm/wrappers/default/bundle exec puma -C /home/ubuntu/current/config/puma.rb'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new service
systemctl daemon-reload
systemctl enable puma

# Prepare deployment
mkdir -p /home/ubuntu/older_releases
mkdir -p /home/ubuntu/tmp_release
mkdir -p /home/ubuntu/deploy_logs
sudo chown -R ubuntu:ubuntu /home/ubuntu/tmp_release
sudo chown -R ubuntu:ubuntu /home/ubuntu/older_releases
sudo chown -R ubuntu:ubuntu /home/ubuntu/deploy_logs

cat << 'EOF' > /home/ubuntu/deploy.sh
#!/bin/bash

# Variables
S3_BUCKET_URL="{{S3_BUCKET_URL}}"
RELEASE_VERSION=$1
CURRENT_DIR="/home/ubuntu/current_release"
OLD_DIR="/home/ubuntu/older_releases"
TMP_DIR="/home/ubuntu/tmp_release"
TIMESTAMP=$(date +%Y%m%d%H%M%S)  # Store the timestamp in a variable
LOG_FILE="/home/ubuntu/deploy_logs/deploy_$(printf '%s' "$TIMESTAMP").log"
MAX_OLD_RELEASES=5 # Maximum number of old releases to keep
source /usr/local/rvm/scripts/rvm
source /etc/profile.d/rails_env.sh


# Redirect all output to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting deployment of version $RELEASE_VERSION"

# Download the latest release from S3
aws s3 cp "$S3_BUCKET_URL/$RELEASE_VERSION.zip" "$TMP_DIR/$RELEASE_VERSION.zip"

# Move the current release to the old releases directory
if [ -d "$CURRENT_DIR" ]; then
  mv "$CURRENT_DIR" "$OLD_DIR/$(printf '%s_release' "$TIMESTAMP")"
fi

# Unzip the new release
unzip "$TMP_DIR/$RELEASE_VERSION" -d "$TMP_DIR"
VERSION_NUMBER=$(echo "$RELEASE_VERSION" | sed 's/^v//')

# Rename the unzipped folder to match the version number
mv "$TMP_DIR/the_simple_api_reboot-$VERSION_NUMBER" "$TMP_DIR/$RELEASE_VERSION"

# Move the renamed folder to the current release directory
mv "$TMP_DIR/$RELEASE_VERSION" "$CURRENT_DIR"
sudo chown -R ubuntu:ubuntu "$CURRENT_DIR"

cd "$CURRENT_DIR"
bundle install --deployment --without development test

# Run database migrations
RAILS_ENV=production bundle exec rails db:migrate

# Create a symlink ti-08001d7d9956f77c0o the new release as the current one
ln -sfn "$CURRENT_DIR" "/home/ubuntu/current"

# Clean up old releases
cd $OLD_DIR
ls -1t | tail -n +$((MAX_OLD_RELEASES + 1)) | xargs -d '\n' rm -rf

# Start or restart the Puma service
sudo systemctl restart puma
EOF

sed -i "s|{{S3_BUCKET_URL}}|${S3_BUCKET_URL}|g" /home/ubuntu/deploy.sh


chmod +x /home/ubuntu/deploy.sh
sudo chown -R ubuntu:ubuntu /home/ubuntu/deploy.sh
