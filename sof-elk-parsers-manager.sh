#!/bin/bash

parsers_directory="Parsers"
templates_directory="/usr/local/sof-elk"

# Define color codes
RED='\033[0;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Function to print colored output with prefixes
print_error() {
  local message=$1
  echo -e "${RED}[!] ${message}${RESET}"
}

print_success() {
  local message=$1
  echo -e "${GREEN}[+] ${message}${RESET}"
}

print_verbose() {
  local message=$1
  echo -e "${WHITE}[*] ${message}${RESET}"
}

print_verbose_list() {
  local message=$1
  echo -e "    [-] ${message}"
}

# Function to list available parsers
list_parsers() {
  print_verbose "Available parsers:"
  # for parser in `ls -1 "$parsers_directory"`; do echo -e "    - $parser"; done
  for parser in `ls -1 "$parsers_directory"`; do print_verbose_list "$parser"; done
}

# Function to create a new parser
create_new_parser() {
  # Prompt the user for the name of the new parser or use the argument if provided
  if [ -z "$1" ]; then
    read -p "Enter the name of the new parser: " parser_name
  else
    parser_name="$1"
  fi

  # Create the directory for the new parser
  print_verbose "Creating the directory for the new parser ..."

  new_parser_directory="$parsers_directory/$parser_name"
  sudo mkdir -vp "$new_parser_directory"

  # Copy the template files to the new parser directory
  print_verbose "Copying the template files to the new parser directory ..."
  sudo cp -v "$templates_directory/configfiles-templates/6xxx-parsing_template.conf.sample" "$new_parser_directory/6xxx-parsing-$parser_name.conf"
  # sudo cp -v "$templates_directory/configfiles-templates/9xxx-output-template.conf.sample" "$new_parser_directory/9xxx-output-$parser_name.conf"  ---> REMOVING AFTER LAST UPDATE
  sudo cp -v "$templates_directory/lib/filebeat_inputs/filebeat_template.yml.sample" "$new_parser_directory/$parser_name.yml"
  sudo cp -v "$templates_directory/lib/elasticsearch_templates/index_templates/000_index-example.json.sample" "$new_parser_directory/index-$parser_name.json"

  print_success "New parser created successfully."
  print_verbose "Parser name: $parser_name"
  print_verbose "Parser directory: $new_parser_directory"
}

# Function to uninstall a specific parser from SOF-ELK
uninstall_parser() {
  parser_name=$1

  # Check if parser name is provided
  print_verbose "Checking if parser name is provided ..."
  if [ -z "$parser_name" ]; then
    print_error "Parser name not provided."
    return 1
  fi

  # Check if parser directory exists
  print_verbose "Checking if parser directory exists ..."
  parser_directory="$parsers_directory/$parser_name"
  if [ ! -d "$parser_directory" ]; then
    print_error "Parser does not exist."
    return 1
  fi

  # Remove parser from 'usr/local/sof-elk/configfiles/1000-preprocess-all.conf'
  print_verbose "Removing '$parser_name' configuration from '1000-preprocess-all.conf' ..."
  sudo sed -i '/else if \[type\] == "$parser_name" {/,+2d' "/usr/local/sof-elk/configfiles/1000-preprocess-all.conf"

  # Remove the parser directory from /logstash/
  print_verbose "Removing parser directory from /logstash/ ..."
  filebeat_inputs_directory="/usr/local/sof-elk/lib/filebeat_inputs"
  parser_data_folder=$(sudo grep -o '/logstash/.*/*' $filebeat_inputs_directory/$parser_name.yml | cut -d* -f 1 | sort -u )
  sudo rm -rvf "$parser_data_folder"

  # Remove <parsername>.yml from filebeat_inputs directory
  print_verbose "Removing $parser_name.yml from filebeat_inputs directory ..."
  sudo rm -vf "$filebeat_inputs_directory/$parser_name.yml"

  # Remove the parser configuration files from configfiles directory
  print_verbose "Removing parser configuration files from configfiles directory ..."
  configfiles_directory="/usr/local/sof-elk/configfiles"
  
  processing_parser=$(find $parser_directory -iname "*-parsing-$parser_name.conf" | xargs -I {} basename {})
  # output_parser=$(find $parser_directory -iname "*-output-$parser_name.conf" | xargs -I {} basename {})  ---> REMOVING AFTER LAST UPDATE
  
  sudo rm -vf "$configfiles_directory/$processing_parser"
  # sudo rm -vf "$configfiles_directory/$output_parser"  ---> REMOVING AFTER LAST UPDATE

  # Remove the symbolic links from /etc/logstash/conf.d
  print_verbose "Removing symbolic links from /etc/logstash/conf.d ..."
  logstash_conf_directory="/etc/logstash/conf.d"
  sudo rm -vf "$logstash_conf_directory/$processing_parser"
  # sudo rm -vf "$logstash_conf_directory/$output_parser"  ---> REMOVING AFTER LAST UPDATE

  # Remove index-<parser_name>.json from elasticsearch index template directory
  print_verbose "Removing index-$parser_name.json from elasticsearch index template directory ..."
  index_template_directory="/usr/local/sof-elk/lib/elasticsearch_templates/index_templates"
  sudo rm -vf "$index_template_directory/index-$parser_name.json"

  # Restart logstash service
  print_verbose "Restarting logstash service ..."
  sudo systemctl restart logstash
  sudo systemctl status logstash
  
  # Restart Filebeat service
  print_verbose "Restarting filebeat service ..."
  sudo systemctl restart filebeat
  sudo systemctl status filebeat

  # Reload custom elasticsearch templates
  load_all_dashboards.sh

  print_success "Parser '$parser_name' uninstalled successfully."
}


# Function to install a specific parser into SOF-ELK
install_parser() {
  parser_name=$1

  # Check if parser name is provided
  print_verbose "Checking if parser name is provided ..."
  if [ -z "$parser_name" ]; then
    print_error "Parser name not provided."
    return 1
  fi

  # Check if parser directory exists
  print_verbose "Checking if parser directory exists ..."
  parser_directory="$parsers_directory/$parser_name"
  if [ ! -d "$parser_directory" ]; then
    print_error "Parser does not exist."
    return 1
  fi

  # Check if parser configurations already exist
  print_verbose "Checking if parser configurations already exist ..."
  if [ -f "/usr/local/sof-elk/lib/filebeat_inputs/$parser_name.yml" ] || [ -d "$parser_data_folder" ] || [ -f "/usr/local/sof-elk/configfiles/$processing_parser" ]; then
    print_verbose "Parser configurations already exist."
    
    # Ask the user if they want to clean up and reinstall
    read -p "Do you want to clean up and reinstall the parser? (y/n): " cleanup_choice
    if [ "$cleanup_choice" == "y" ]; then
      print_verbose "Cleaning up existing parser configurations..."
      uninstall_parser "$parser_name"
    else
      print_verbose "Skipping parser installation."
      return
    fi
  fi

  # Copy <parsername>.yml to filebeat_inputs directory
  print_verbose "Copying $parser_name.yml to filebeat_inputs directory ..."
  filebeat_inputs_directory="/usr/local/sof-elk/lib/filebeat_inputs"
  sudo cp -v "$parser_directory/$parser_name.yml" "$filebeat_inputs_directory/"

  # Extract parser_data_folder from <parsername>.yml
  print_verbose "Extracting parser_data_folder from $parser_name.yml"
  parser_data_folder=$(sudo grep -o '/logstash/.*/*' $filebeat_inputs_directory/$parser_name.yml | cut -d* -f 1 | sort -u )
  print_verbose "Parsed Folder = $parser_data_folder"

  # Create directory for parser in /logstash/
  print_verbose "Creating directory for parser in /logstash/ ..."
  sudo mkdir -vp "$parser_data_folder"

  # Set permissions and ownership for the parser directory
  print_verbose "Setting permissions and ownership for the parser directory ..."
  sudo chown root:root "$parser_data_folder"
  sudo chmod 1777 "$parser_data_folder"

  # ===========================================================================================================
  # Add the custom parser to the pre-processor. TO BE TESTED.
  # Your new block to be inserted
  new_block="    else if [type] == \"$parser_name\" {
    mutate { add_field => { \"[@metadata][index_base]\" => \"$parser_name\" } }
  }"

  # The path to the configuration file
  config_file="/usr/local/sof-elk/configfiles/1000-preprocess-all.conf"

  # Insert the new block at the end of the file
  # sudo bash -c  "sed -i -e '$d' $config_file"   # Remove the last line (closing brace of the previous "filter" block)
  sudo sed -i '$s/}//' "$config_file" # Remove the last line (closing brace of the previous "filter" block)
  sudo bash -c  "echo '$new_block' >> $config_file"  # Append the new block
  sudo bash -c  "echo '}' >> $config_file"   # Add back the closing brace of the "filter" block
  # ===========================================================================================================

  # Copy 6xxx-parsing-<parsername>.conf and 9xxx-output-<parsername>.conf to configfiles directory
  print_verbose "Copying 6xxx-parsing-$parser_name.conf to configfiles directory ..."
  configfiles_directory="/usr/local/sof-elk/configfiles"
  
  processing_parser=$(find $parser_directory -iname "*-parsing-$parser_name.conf" | xargs -I {} basename {})
  # output_parser=$(find $parser_directory -iname "*-output-$parser_name.conf" | xargs -I {} basename {})  ---> REMOVING AFTER LAST UPDATE
  
  sudo cp -v "$parser_directory/$processing_parser" "$configfiles_directory/"
  # sudo cp -v "$parser_directory/$output_parser" "$configfiles_directory/" ---> REMOVING AFTER LAST UPDATE

  # Create symbolic links in /etc/logstash/conf.d for the parser configuration files
  print_verbose "Creating symbolic links in /etc/logstash/conf.d for the parser configuration files ..."
  logstash_conf_directory="/etc/logstash/conf.d"
  sudo ln -sv "$configfiles_directory/$processing_parser" "$logstash_conf_directory/"
  # sudo ln -sv "$configfiles_directory/$output_parser" "$logstash_conf_directory/"  ---> REMOVING AFTER LAST UPDATE

  # Copy index-<parser_name> to elasticsearch index template directory
  print_verbose "Copying index-$parser_name.json to elasticsearch index template directory ..."
  index_template_directory="/usr/local/sof-elk/lib/elasticsearch_templates/index_templates"
  sudo cp -v "$parser_directory/index-$parser_name.json" "$index_template_directory/"


  # Set permissions and ownership for the configuration files
  print_verbose "Setting permissions and ownership for the configuration files ..."
  sudo chown root:root "$configfiles_directory/$processing_parser"
  # sudo chown root:root "$configfiles_directory/$output_parser" ---> REMOVING AFTER LAST UPDATE
  sudo chown root:root "$index_template_directory/index-$parser_name.json"
  sudo chmod 644 "$configfiles_directory/$processing_parser"
  # sudo chmod 644 "$configfiles_directory/$output_parser"  ---> REMOVING AFTER LAST UPDATE
  sudo chmod 644 "$index_template_directory/index-$parser_name.json"

  # Restart logstash service
  print_verbose "Restarting logstash service ..."
  sudo systemctl restart logstash
  sudo systemctl status logstash
  
  # Restart Filebeat service
  print_verbose "Restarting filebeat service ..."
  sudo systemctl restart filebeat
  sudo systemctl status filebeat

  # Reload custom elasticsearch templates
  load_all_dashboards.sh

  print_success "Parser '$parser_name' installed successfully."
}

# Function to check the status and logs of Logstash and Filebeat processes for a specific parser
check_status() {
  parser_name=$1

  # Check if parser name is provided
  print_verbose "Checking if parser name is provided ..."
  if [ -z "$parser_name" ]; then
    print_error "Parser name not provided."
    return 1
  fi

  # Check Logstash status
  logstash_status=$(sudo systemctl is-active logstash)
  if [ "$logstash_status" == "active" ]; then
    print_success "Logstash is running."
  else
    print_error "Logstash is not running."
    return 1
  fi

  # Check Filebeat status
  filebeat_status=$(sudo systemctl is-active filebeat)
  if [ "$filebeat_status" == "active" ]; then
    print_success "Filebeat is running."
  else
    print_error "Filebeat is not running."
    return 1
  fi

  # Check Logstash logs for the parser name
  print_verbose "\n\nChecking Logstash logs for activity related to '$parser_name'..."
  sudo journalctl -u logstash | grep "$parser_name"

  # Check Filebeat logs for the parser name
  print_verbose "\n\nChecking Filebeat logs for activity related to '$parser_name'..."
  sudo journalctl -u filebeat | grep "$parser_name" | grep -v 'Configured paths:' | grep '\{.*\}' -o | jq
}

# Main script execution
if [ "$1" == "list" ]; then
  list_parsers
elif [ "$1" == "create" ]; then
  create_new_parser "$2"
elif [ "$1" == "install" ]; then
  install_parser "$2"
elif [ "$1" == "uninstall" ]; then
  uninstall_parser "$2"
elif [ "$1" == "status" ]; then
  check_status "$2"
else
  print_error "Invalid command. Usage: sof-elk-parser-manager\.sh <command> [parser_name]"
  print_verbose "Commands:"
  print_verbose_list "list      : List available parsers"
  print_verbose_list "create    : Create a new parser"
  print_verbose_list "status    : Check status of Logstash and Filebeat processes for a specific parser"
  print_verbose_list "install   : Install a specific parser into SOF-ELK"
  print_verbose_list "uninstall : Uninstall a specific parser from SOF-ELK"
fi