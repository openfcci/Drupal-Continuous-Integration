#!/bin/bash

# Author: Dustin Rue <dustin.rue@fccinteractive.com,ruedu@dustinrue.com>
#
#   This script is used to perform a test upgrade against production data.
#
#   You are required within the Jenkin's job to delete the code and get
#   into a state the represents the environment you want to upgrade.
#
#   This script will then drop the existing database and then restore the
#   database from the source system.
#
#   Environment variables must also be set in order for this script to work:
#
#     DBHOST      = Hostname of where the database lives
#     DBDB        = Database name
#     DBUSER      = Database user
#     DBPASS      = Database password
#     DESTINATION = This is the "prefix" or subdomain that the site uses
#                   in the case of staging.fccnn.com it would be staging
#     PROXYHOST   = This is the host where images should be proxied from using
#                   the stage_file_proxy module
#     SOURCE      = Name of the source branch.  Might be staging, production, etc 
#     SOURCEDBURL = HTTP location of where database backup files are hosted.
#                   This location should simply contain a list of files using
#                   Apache's autoindex option
#
#   These variables should be set and exported in the Jenkin's script that calls
#   this script
#

# lets do a sanity check to ensure all ENV vars are set, quit if they aren't

if [ "${DBHOST}"      == "" ] || 
   [ "${DBDB}"        == "" ] || 
   [ "${DBUSER}"      == "" ] ||
   [ "${DBPASS}"      == "" ] ||
   [ "${DESTINATION}" == "" ] ||
   [ "${PROXYHOST}"   == "" ] ||
   [ "${SOURCE}"      == "" ] ||
   [ "${SOURCEDBURL}" == "" ]; then
   
  echo "ENV vars not set"
  exit 1
fi

if [ "$INSTALL_LOCATION" == "" ]; then
  INSTALL_LOCATION="$PWD/.."
fi

function stop_if_error {
  if [ ! "$1" -eq 0 ]; then
    echo "FAIL with $1"
    exit $1
  fi
}

./apply_db_config.sh ${DBHOST} ${DBDB} ${DBUSER} ${DBPASS} ${DESTINATION}
stop_if_error $?


# need to disable memcache if it exists already because it 
# will cause failures still

echo
echo -n "Removing memcache.settings.php if it exists..."
rm -f ../public_html/sites/default/memcache.settings.php
echo "done"

echo 
echo -n "Applying database upgrades if needed..."
drush -r ../public_html updb -y
echo "done"

# very important that we clear the cache right here module
# upgrades/installs can fail.  For example, cached menu entries
# will prevent a person from properly updating them via APIs
#drush -r ../public_html cc all
#stop_if_error $?


./build_web_config.sh ${DESTINATION}
stop_if_error $?

# we don't use a file proxy on live, just staging (currently doesn't work anyway)
if [ ${DESTINATION} != "www" ]; then
  echo "\$conf['stage_file_proxy_origin'] = '${PROXYHOST}';" >> ../public_html/sites/settings_override/settings.php
fi


# enable these now as there might be failures later on
# it is ok to ignore warnings and failures from these modules.
# They may fail if the database refers to a file that doesn't
# exist on the file system
drush -r ../public_html en -y file_entity entity
#stop_if_error $?


drush -r ../public_html updb -y
stop_if_error $?

./apply_modules.sh
stop_if_error $?

# deal with the files directory
cd ../public_html

if [ "${DESTINATION}" == "www" ]; then 
  if [ ! -h files ]; then
    cd ${INSTALL_LOCATION}/public_html/sites/default
    ln -s /opt/drupal-cms-production files
    cd -
  fi
else
  mkdir sites/default/files
  chmod 777 sites/default/files
fi

# ensure that we're we think we are
cd ${INSTALL_LOCATION}/utilities

cd ../public_html
drush cc all
cd -

./import_menu_categories.sh
stop_if_error $?

cd ../public_html
drush features-revert fcc_main_navigation -y
drush features-revert fcc_homepage_blocks -y
drush features-revert fcc_obituary_content -y
drush features-revert fcc_workflow -y
drush features-revert fcc_wizzywig -y
drush features-revert fcc_article_content -y
drush features-revert fcc_ldap_integration -y
drush features-revert fcc_classified_content_type -y
drush features-revert fcc_article_content -y
drush features-revert fcc_field_bundle_settings -y
drush features-revert fcc_users -y
drush features-revert fcc_image_caption -y
drush features-revert fcc_google_analytics -y
drush features-revert fcc_featured -y
drush features-revert fcc_homepage -y
drush features-revert fcc_category_field -y
drush features-revert fcc_brightcove_integration -y
drush features-revert fcc_cache_settings -y
drush features-revert fcc_masthead_footer -y
drush features-revert fcc_admin_finder_context -y
drush features-revert fcc_cache_settings -y
drush features-revert fcc_varnish_settings -y
drush features-revert fcc_search -y
drush features-revert fcc_search_facets -y

# this should no longer be needed
#drush migrate-import FCCUsersCSV --update

cd ../public_html
drush cc all

# don't do this, an outside script should after the upgrade is done
#/etc/init.d/apache2 reload
#stop_if_error $?

cd ../utilities
./apply_memcache_config.sh
stop_if_error $?

#start feeds import
pwd
echo
echo "starting feeds importers"
drush -r ../public_html php-eval 'fcc_feeds_start_imports(all)'
stop_if_error $?

echo
echo -n "Import apache solr settings..."
if [ "${DESTINATION}" == "www" ]; then
  `drush -r ../public_html sql-connect` < support/role/production/apachesolr_settings.sql
else
  `drush -r ../public_html sql-connect` < support/role/${DESTINATION}/apachesolr_settings.sql
fi
echo "done"

echo
echo -n "Clearing caches..."
drush -r ../public_html cc all
echo "done"
