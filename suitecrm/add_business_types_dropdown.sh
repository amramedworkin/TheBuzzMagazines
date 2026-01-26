#!/bin/bash

# 1. Define the path for the custom language override
TARGET_DIR="/var/www/html/suitecrm/public/legacy/custom/include/language"
TARGET_FILE="$TARGET_DIR/en_us.lang.php"

# 2. Create the directory if it doesn't exist
sudo mkdir -p $TARGET_DIR

# 3. Generate the file content
# Note: The trailing comma in the array is intentional for PHP best practices
sudo bash -c "cat << 'EOF' > $TARGET_FILE
<?php
// Custom Industry Dropdown for The Buzz Magazines Migration
\$app_list_strings['industry_dom'] = array (
    '' => '',
  'agencies' => 'Agencies',
  'arts_&_entertainment' => 'Arts & Entertainment',
  'automotive' => 'Automotive',
  'beauty_&_spas' => 'Beauty & Spas',
  'camp' => 'Camp',
  'education' => 'Education',
  'event_planning_&_services' => 'Event Planning & Services',
  'financial_services' => 'Financial Services',
  'food_&_drink' => 'Food & Drink',
  'health_&_medical' => 'Health & Medical',
  'home_services' => 'Home Services',
  'hotels_&_travel' => 'Hotels & Travel',
  'non-profit' => 'Non-Profit',
  'other' => 'Other',
  'personal_services' => 'Personal Services',
  'pets' => 'Pets',
  'professional_services' => 'Professional Services',
  'real_estate' => 'Real Estate',
  'recreation_&_fitness' => 'Recreation & Fitness',
  'religious_organizations' => 'Religious Organizations',
  'shopping' => 'Shopping',
);
EOF"

# 4. Set correct ownership and permissions for the web server
sudo chown -R www-data:www-data /var/www/html/suitecrm/public/legacy/custom
sudo chmod 664 $TARGET_FILE

echo "Dropdown override file created at $TARGET_FILE"
echo "Next step: Log into SuiteCRM and run a 'Quick Repair and Rebuild'."
