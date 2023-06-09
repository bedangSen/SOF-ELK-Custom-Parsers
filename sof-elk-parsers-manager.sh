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
  sudo cp -v "$templates_directory/configfiles-templates/9xxx-output-template.conf.sample" "$new_parser_directory/9xxx-output-$parser_name.conf"
  sudo cp -v "$templates_directory/lib/filebeat_inputs/filebeat_template.yml.sample" "$new_parser_directory/$parser_name.yml"
  sudo cp -v "$templates_directory/lib/elasticsearch_templates/index_templates/000_index-example.json.sample" "$new_parser_directory/index-$parser_name.json"

  print_success "New parser created successfully."
  print_verbose "Parser name: $parser_name"
  print_verbose "Parser directory: $new_parser_directory"
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

  # ## Checking if filebeat live reload is enabled.
  # # YAML file path
  # yaml_file="/usr/local/sof-elk/lib/configfiles/filebeat.yml"

  # # Start and end patterns for the section
  # start_pattern="filebeat.config.inputs:"
  # end_pattern="filebeat.config.modules:"

  # # Check if the reload.enabled setting exists within the section
  # reload_enabled_exists=$(awk "/$start_pattern/,/$end_pattern/" "$yaml_file" | awk '/reload.enabled:/ {found=1; exit} END{print found}')

  # if [[ $reload_enabled_exists -eq 0 ]]; then
  #   # reload.enabled setting does not exist, add it with the value true
  #   sed -i "/$start_pattern/a \  reload.enabled: true" "$yaml_file"
  #   print_verbose "Added reload.enabled setting with the value true"
  # else
  #   # reload.enabled setting exists, check if the value is true
  #   reload_enabled_value=$(awk "/$start_pattern/,/$end_pattern/" "$yaml_file" | awk '/reload.enabled:/ {print $2}')
  #   if [[ $reload_enabled_value != "true" ]]; then
  #     # reload.enabled value is not true, change it to true
  #     sed -i "s/\($start_pattern.*\n\)\(.*reload.enabled: \).*/\1\2true/" "$yaml_file"
  #     print_verbose "Changed reload.enabled value to true"
  #   else
  #     print_verbose "reload.enabled setting is already true"
  #   fi
  # fi

  # Copy 6xxx-parsing-<parsername>.conf and 9xxx-output-<parsername>.conf to configfiles directory
  print_verbose "Copying 6xxx-parsing-$parser_name.conf and 9xxx-output-$parser_name.conf to configfiles directory ..."
  configfiles_directory="/usr/local/sof-elk/configfiles"
  
  processing_parser=$(find $parser_directory -iname "*-parsing-$parser_name.conf" | xargs -I {} basename {})
  output_parser=$(find $parser_directory -iname "*-output-$parser_name.conf" | xargs -I {} basename {})
  
  sudo cp -v "$parser_directory/$processing_parser" "$configfiles_directory/"
  sudo cp -v "$parser_directory/$output_parser" "$configfiles_directory/"

  # Create symbolic links in /etc/logstash/conf.d for the parser configuration files
  print_verbose "Creating symbolic links in /etc/logstash/conf.d for the parser configuration files ..."
  logstash_conf_directory="/etc/logstash/conf.d"
  sudo ln -sv "$configfiles_directory/$processing_parser" "$logstash_conf_directory/"
  sudo ln -sv "$configfiles_directory/$output_parser" "$logstash_conf_directory/"

  # Copy index-<parser_name> to elasticsearch index template directory
  print_verbose "Copying index-$parser_name.json to elasticsearch index template directory ..."
  index_template_directory="/usr/local/sof-elk/lib/elasticsearch_templates/index_templates"
  sudo cp -v "$parser_directory/index-$parser_name.json" "$index_template_directory/"


  # Set permissions and ownership for the configuration files
  print_verbose "Setting permissions and ownership for the configuration files ..."
  sudo chown root:root "$configfiles_directory/$processing_parser"
  sudo chown root:root "$configfiles_directory/$output_parser"
  sudo chown root:root "$index_template_directory/index-$parser_name.json"
  sudo chmod 644 "$configfiles_directory/$processing_parser"
  sudo chmod 644 "$configfiles_directory/$output_parser"
  sudo chmod 644 "$index_template_directory/index-$parser_name.json"

  # Restart logstash service
  print_verbose "Restarting logstash service ..."
  sudo systemctl restart logstash
  sudo systemctl status logstash
  
  # Restart Filebeat service
  print_verbose "Restarting filebeat service ..."
  sudo systemctl restart filebeat
  sudo systemctl status filebeat

  print_success "Parser '$parser_name' installed successfully."
}

# Main script execution
if [ "$1" == "list" ]; then
  list_parsers
elif [ "$1" == "create" ]; then
  create_new_parser "$2"
elif [ "$1" == "install" ]; then
  install_parser "$2"
else
  print_error "Invalid command. Usage: sof-elk-parser-manager\.sh <command> [parser_name]"
  print_verbose "Commands:"
  print_verbose_list "list      : List available parsers"
  print_verbose_list "create    : Create a new parser"
  print_verbose_list "install   : Install a specific parser into SOF-ELK"
fi
