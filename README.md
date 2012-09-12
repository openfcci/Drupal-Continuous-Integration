Purpose
-------
Example scripts and information on continuous integration with Drupal and how FCC is using them to help solve the dev->staging->production lifecycle problem.  They are shared with the community in the hopes that they spark additional interest.

Scripts
-------
This directory contains scripts FCC uses to manage the state of our Drupal based CMS throughout the staging to production process.  Many are works in progress and are actively maintained to suit our needs.  They are shared here in the hopes that the inspire other Drupal users.

The majority of the scripts are written in bash so that some tasks could be performed outside of Drupal itself.  Common practice is to use drush for a lot of tasks but there are cases where drush isn't appropriate or simply work won't, depending on the current state of the setup.  Still, in some places we are knowingly breaking from tradition because it gives us more flexibility or because it made sense at the time.  
