#!/bin/bash

# take the template file and substitute the IPs

exec 1>/var/tmp/$(basename $0).log

exec 2>&1

abort () {
  echo "ERROR: Failed with $1 executing '$2' @ line $3"
  exit $1
}

trap 'abort $? "$STEP" $LINENO' ERR


LB_NAME=$1

STEP="Create config with cat"

cat << ! > /etc/scalr-server/scalr-server.rb
########################################################################################
# IMPORTANT: This is NOT a substitute for documentation. Make sure that you understand #
# the configuration parameters you use in your configuration file.                     #
########################################################################################

##########################
# Topology Configuration #
##########################
# You can use IPs for the below as well, but hostnames are preferable.
ENDPOINT = '$LB_NAME'

# Enable all components (single server install)
enable_all true

# Scalr web UI URL
routing[:endpoint_host] = ENDPOINT

# Uncomment to enable SSL
#proxy[:ssl_enable] = true
#proxy[:ssl_redirect] = true
#proxy[:ssl_cert_path] = "/path/to/the/cert"
#proxy[:ssl_key_path] = "/path/to/the/key"
#routing[:endpoint_scheme] = 'https'

repos[:enable] = true

# Default local agent repo configuration
app[:configuration] = {
  :scalr => {
      :ui => {
         :login_warning => "WELCOME TO SCALR - INSTALLED by Terraform  <p>This is a single server Scalr installation entirely built by Terraform using Scalr as a remote Backend</p>"
      },
      :system => {
        :server_terminate_timeout => 'auto',
        :api => {
                :enabled => true,
                :allowed_origins => '*,https://api-explorer.scalr.com'
       }
    },
    :scalarizr_update => {
      :mode => "solo",
      :default_repo => "latest",
      :repos => {
        "latest" => {
          :rpm_repo_url => "http://"+ENDPOINT+"/repos/rpm/latest/rhel/\$releasever/\$basearch",
          :suse_repo_url => "http://"+ENDPOINT+"/repos/rpm/latest/suse/\$releasever/\$basearch",
          :deb_repo_url => "http://"+ENDPOINT+"/repos/apt-plain/latest /",
          :win_repo_url => "http://"+ENDPOINT+"/repos/win/latest",
        },
      },
    },
  },
}

!

STEP="Reconfigure"
scalr-server-ctl reconfigure
