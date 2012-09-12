<?php
  include("../public_html/sites/settings_override/settings.php");

  $databases = array_pop(array_pop($databases));

  echo $databases[$argv[1]];
