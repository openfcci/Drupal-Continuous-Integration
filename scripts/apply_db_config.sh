#!/bin/bash

# Author: Dustin Rue <dustin.rue@fccinteractive.com,ruedu@dustinrue.com>
#
#   This script creates the settings_override.php file
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


# Run interactively if parameters weren't passed
if [ "$5" == "" ]; then
  useOldFile="y"
  if [ -f "${INSTALL_LOCATION}/public_html/sites/settings_override/settings.php" ]; then
    echo -n "Existing settings file found, do you want to overwrite it? <y> or <n>: "
    read useOldFile

    if [ "$useOldFile" == "" ]; then
      useOldFile="n"
    fi

    if [ $useOldFile == "n" ]; then
      hostname=`php lib/get_db_setting.php host`
      dbname=`php lib/get_db_setting.php database`
      username=`php lib/get_db_setting.php username`
      password=`php lib/get_db_setting.php password`
      siteurl=`php lib/get_other_setting.php prefix`
    fi
  fi

  if [ $useOldFile == "y" ]; then
    echo -n "Where is your drupal database hosted? <127.0.0.1>: "
    read hostname

    echo -n "What is the name of your drupal database? <${USER}_drupal>: "
    read dbname

    echo -n "What is the username for your drupal database? <${USER}_drupal>: "
    read username

    echo -n "What is the password for your drupal database? <${USER}_drupal2k12>: "
    read password

    # "prefix" is really the subdomain that this site will run under
    echo -n "What is your site's prefix? <${USER}>: "
    read siteurl
  fi
else
  useOldFile="y"
  hostname="$1"
  dbname="$2"
  username="$3"
  password="$4"
  siteurl="$5"
fi




DRUSH=`which drush`

if [ "$DRUSH" == "" ]; then
  echo "You don't seem to have drush installed, I can't continue"
  stop_if_error 255
fi

MYSQL=`which mysql`

if [ "$MYSQL" == "" ]; then
  echo "You don't seem to have mysql CLI tools installed, I can't continue"
  stop_if_error 255
fi


if [ "$useOldFile" == "y" ]; then
  echo -n "Generating local settings override file..."

  if [ "$hostname" == "" ]; then
    hostname='127.0.0.1'
  fi

  if [ "$dbname" == "" ]; then
    dbname=${USER}_drupal
  fi
  
  if [ "$username" == "" ]; then
    username=${USER}_drupal
  fi

  if [ "$password" == "" ]; then
    password=${USER}_drupal2k12
  fi

  if [ "$siteurl" == "" ]; then
    siteurl=${USER}
  fi

  echo "<?php
\$databases = array (
  'default' =>
  array (
    'default' =>
    array (
      'database' => '${dbname}',
      'username' => '${username}',
      'password' => '${password}',
      'host' => '${hostname}',
      'port' => '3306',
      'driver' => 'mysql',
      'prefix' => '',
    ),
  ),
 
);
\$fcc_settings = array (
  'default' => array(
    'default' => array (
      'prefix' => '${siteurl}',
    ),
  ),
);
" > $INSTALL_LOCATION/public_html/sites/settings_override/settings.php

  echo "Done"
fi
