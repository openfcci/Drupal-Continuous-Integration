#!/bin/bash

# Author: Dustin Rue <dustin.rue@fccinteractive.com,ruedu@dustinrue.com>
#
#   This script generates an apache config that can be included by
#   the main vhost config file on the server
#


if [ "$SERVER_ENV" == "" ]; then
  # assume this is a dev environment
  SERVER_ENV="dev"
fi

# function quit the script if an error is detected

function stop_if_error {
  if [ ! "$1" -eq 0 ]; then
    echo "FAIL with $1"
    exit $1
  fi
}

# TODO: properly parse our current location so that the 
# resulting config files are a bit cleaner (no ..)
if [ "$INSTALL_LOCATION" == "" ]; then
  INSTALL_LOCATION="$PWD/.."
fi


siteurl=$1

if [ "${siteurl}" == "" ]; then
  # "prefix" is really the subdomain that this site will run under
  echo -n "What is your site's prefix? <${USER}>: "
  read siteurl
fi

# this section generates the web config file for Apache
# A file called "sites" must exist in utilities/support
# and should contain one line for each file with:
#
#     hostname.com:Site Name
#
# We'll now loop over the info stored there and create
# a ServerAlias for each one as well as tell Drupal
# to add the domain.  
#
# During the first part of the script, one of the questions is
# the site "prefix." For those who understand, a prefix is 
# really just a subdomain.  That subdomain is used here to 
# define if this is testing, staging, production or dev.
#
# A dev site would simply be username.hostname.com and production
# would be www.hostname.com.  Testing and staging would be
# testing.hostname.com and staging.hostname.com.  These are simply
# a suggested protocol and not actually enforced by this script.
#
> ../wwwconfig/${siteurl}.serveraliases
> ../wwwconfig/redirects.conf

echo "#This is a generated config file, please edit build_web_config.sh to change this file!" >> ../wwwconfig/${siteurl}.serveraliases
echo "#This is a generated config file, please edit build_web_config.sh to change this file!" >> ../wwwconfig/redirects.conf

while read I
do
  URL=`echo $I | cut -d ':' -f 1`
  SITENAME=`echo $I | cut -d ':' -f 2`

  # only add the domain if it doesn't already exist
  EXISTS=0
  EXISTS=`drush -r ${INSTALL_LOCATION}/public_html sql-query "SELECT * FROM domain" | grep -c $URL`
  if [ "$EXISTS" -eq 0 ]; then
    drush -r ${INSTALL_LOCATION}/public_html domain-add ${siteurl}.${URL} "${SITENAME}"
    stop_if_error $?
  else
    # it exists but it is probably wrong for this env
    URLUNDERSCORED=`echo $URL |  tr '.' '_'`
    drush -r ${INSTALL_LOCATION}/public_html sql-query "UPDATE domain SET subdomain = '${siteurl}.${URL}', machine_name = '${siteurl}_${URLUNDERSCORED}' WHERE machine_name LIKE '%_${URLUNDERSCORED}'"
    drush -r ${INSTALL_LOCATION}/public_html sql-query "UPDATE domain_export SET machine_name = '${siteurl}_${URLUNDERSCORED}' WHERE machine_name LIKE '%_${URLUNDERSCORED}'"
    stop_if_error $?
    echo "Updated ${siteurl}.${URL}"
  fi
  echo "ServerAlias ${siteurl}.${URL}" >> ../wwwconfig/${siteurl}.serveraliases

  echo "<VirtualHost *:80>
  ServerName ${URL}
  Redirect / http://${siteurl}.${URL}
</VirtualHost>
" >> ../wwwconfig/redirects.conf

  echo "<VirtualHost *:80>
  ServerName mobile.${URL}
  Redirect / http://${siteurl}.${URL}
</VirtualHost>
" >> ../wwwconfig/redirects.conf

done < $INSTALL_LOCATION/utilities/support/role/$SERVER_ENV/sites


# we have a slightly different config for live
# because we use the itk mpm (giving us different
# users per vhost) on live
if [ ${SERVER_ENV} == "production" ]; then
echo "
# this is the template for production sites
#
#
# setup for 
<VirtualHost *:80>
  ServerName ${siteurl}.fccnn.com
  Include ${INSTALL_LOCATION}/wwwconfig/${siteurl}.serveraliases
  Include ${INSTALL_LOCATION}/wwwconfig/rewrites.conf
  DocumentRoot ${INSTALL_LOCATION}/public_html
  <Directory ${INSTALL_LOCATION}/public_html>
    Order allow,deny
    Allow from all
    AllowOverride All
  </Directory>
#AssignUserId drupalcms drupalcms

  ErrorLog logs/fccnn.com-error.log
  CustomLog logs/fccnn.com-access.log combined

  # set the newrelic appname for tracking
  php_value newrelic.appname 'Drupal 7'
</VirtualHost>

Include ${INSTALL_LOCATION}/wwwconfig/redirects.conf

" > $INSTALL_LOCATION/wwwconfig/web.${siteurl}.fccnn.com.conf
else

echo "
# this is the template for dev sites
#
#
# setup for 
<VirtualHost *:80>
  ServerName ${siteurl}.fccnn.com
  Include ${INSTALL_LOCATION}/wwwconfig/${siteurl}.serveraliases
  Include ${INSTALL_LOCATION}/wwwconfig/rewrites.conf
  DocumentRoot ${INSTALL_LOCATION}/public_html
  <Directory ${INSTALL_LOCATION}/public_html>
    Order allow,deny
    Allow from all
    AllowOverride All
  </Directory>

  # set the newrelic appname for tracking
  php_value newrelic.appname 'Drupal 7 Dev'
</VirtualHost>
" > $INSTALL_LOCATION/wwwconfig/web.${siteurl}.fccnn.com.conf
fi
