# Getting setup & installing some utilities
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wget vim curl git

######################
# Setup package keys #
######################

# Rabbit
echo "deb http://www.rabbitmq.com/debian/ testing main" > /etc/apt/sources.list.d/rabbitmq.list
curl -L -o ~/rabbitmq-signing-key-public.asc http://www.rabbitmq.com/rabbitmq-signing-key-public.asc
apt-key add ~/rabbitmq-signing-key-public.asc

# Sensu
wget -q http://repos.sensuapp.org/apt/pubkey.gpg -O- | sudo apt-key add -
echo "    deb     http://repos.sensuapp.org/apt sensu main" >> /etc/apt/sources.list

########################
# Install Dependancies #
########################
# erlang & rabbit
apt-get update
apt-get -y install erlang-nox
apt-get -y --allow-unauthenticated --force-yes install rabbitmq-server

####################
# Configure Rabbit #
####################

# Generate SSL Certs
git clone git://github.com/joemiller/joemiller.me-intro-to-sensu.git
cd joemiller.me-intro-to-sensu/
~/ssl_certs.sh clean
~/ssl_certs.sh generate

mkdir -p /etc/rabbitmq/ssl
cp ./server_key.pem /etc/rabbitmq/ssl/
cp ./server_cert.pem /etc/rabbitmq/ssl/
cp ./testca/cacert.pem /etc/rabbitmq/ssl/

sudo cat > /etc/rabbitmq/rabbitmq.config <<EOF
[
    {rabbit, [
    {ssl_listeners, [5671]},
    {ssl_options, [{cacertfile,"/etc/rabbitmq/ssl/cacert.pem"},
                   {certfile,"/etc/rabbitmq/ssl/server_cert.pem"},
                   {keyfile,"/etc/rabbitmq/ssl/server_key.pem"},
                   {verify,verify_peer},
                   {fail_if_no_peer_cert,true}]}
  ]}
].
EOF

# Install the mgmt console
rabbitmq-plugins enable rabbitmq_management

# Restart rabbit
update-rc.d rabbitmq-server defaults
/etc/init.d/rabbitmq-server start

# Configure rabbit for sensu
rabbitmqctl add_vhost /sensu
rabbitmqctl add_user sensu mypass
rabbitmqctl set_permissions -p /sensu sensu ".*" ".*" ".*"

#################
# Install Sensu #
#################

apt-get install -y redis-server sensu

# Enable Sensu services
update-rc.d sensu-server defaults
update-rc.d sensu-api defaults
update-rc.d sensu-client defaults
update-rc.d sensu-dashboard defaults

# Configure Sensu

# SSL
mkdir -p /etc/sensu/ssl/
cp client_key.pem client_cert.pem  /etc/sensu/ssl/

# Create just enough sensu to start /etc/sensu/config.json
sudo cat > /etc/sensu/config.json <<EOF
   {
      "rabbitmq": {
        "ssl": {
          "private_key_file": "/etc/sensu/ssl/client_key.pem",
          "cert_chain_file": "/etc/sensu/ssl/client_cert.pem"
        },
        "port": 5671,
        "host": "localhost",
        "user": "sensu",
        "password": "mypass",
        "vhost": "/sensu"
      },
      "redis": {
        "host": "localhost",
        "port": 6379
      },
      "api": {
        "host": "localhost",
        "port": 4567
      },
      "dashboard": {
        "host": "localhost",
        "port": 8080,
        "user": "admin",
        "password": "secret"
      },
      "handlers": {
        "default": {
          "type": "pipe",
          "command": "true"
        }
      }
    }
EOF

# /etc/sensu/conf.d/client.json
export MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
sudo cat > /etc/sensu/conf.d/client.json <<EOF
    {
      "client": {
        "name": "sensu-server.dom.tld",
        "address": "${MY_IP}",
        "subscriptions": [ "test" ]
      }
    }
EOF

# start / restart services
sudo /etc/init.d/sensu-server start
sudo /etc/init.d/sensu-api start
sudo /etc/init.d/sensu-client start    
sudo /etc/init.d/sensu-dashboard start 
