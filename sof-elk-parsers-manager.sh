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
  echo -e "[${RED}!${RESET}] ${message}"
}

print_success() {
  local message=$1
  echo -e "[${GREEN}+${RESET}] ${message}"
}

print_verbose() {
  local message=$1
  echo -e "[${WHITE}-${RESET}] ${message}"
}

# Function to list available parsers
list_parsers() {
  print_verbose "Available parsers:"
  ls -1 "$parsers_directory"
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
  new_parser_directory="$parsers_directory/$parser_name"
  sudo mkdir -vp "$new_parser_directory"

  # Copy the template files to the new parser directory
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
  if [ -z "$parser_name" ]; then
    print_error "Parser name not provided."
    return 1
  fi

  # Check if parser directory exists
  parser_directory="$parsers_directory/$parser_name"
  if [ ! -d "$parser_directory" ]; then
    print_error "Parser does not exist."
    return 1
  fi

  # Copy <parsername>.yml to filebeat_inputs directory
  filebeat_inputs_directory="/usr/local/sof-elk/lib/filebeat_inputs"
  sudo cp -v "$parser_directory/$parser_name.yml" "$filebeat_inputs_directory/"

  # Extract parser_data_folder from <parsername>.yml
  parser_data_folder=$(sudo awk '/paths:/ {getline; getline; print}' "$filebeat_inputs_directory/$parser_name.yml")

  # Create directory for parser in /logstash/
  logstash_directory="/logstash/$parser_name"
  sudo mkdir -vp "$logstash_directory"

  # Set permissions and ownership for the parser directory
  sudo chown root:root "$logstash_directory"
  sudo chmod 1777 "$logstash_directory"

  # Copy 6xxx-parsing-<parsername>.conf and 9xxx-output-<parsername>.conf to configfiles directory
  configfiles_directory="/usr/local/sof-elk/configfiles"
  sudo cp -v "$parser_directory/6xxx-parsing-$parser_name.conf" "$configfiles_directory/"
  sudo cp -v "$parser_directory/9xxx-output-$parser_name.conf" "$configfiles_directory/"

  # Create symbolic links in /etc/logstash/conf.d for the parser configuration files
  logstash_conf_directory="/etc/logstash/conf.d"
  sudo ln -sv "$configfiles_directory/6xxx-parsing-$parser_name.conf" "$logstash_conf_directory/"
  sudo ln -sv "$configfiles_directory/9xxx-output-$parser_name.conf" "$logstash_conf_directory/"

  # Set permissions and ownership for the configuration files
  sudo chown root:root "$configfiles_directory/6xxx-parsing-$parser_name.conf"
  sudo chown root:root "$configfiles_directory/9xxx-output-$parser_name.conf"
  sudo chmod 644 "$configfiles_directory/6xxx-parsing-$parser_name.conf"
  sudo chmod 644 "$configfiles_directory/9xxx-output-$parser_name.conf"

  # Restart logstash service
  sudo systemctl restart logstash

  print_success "\nParser '$parser_name' installed successfully."
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
  print_verbose "  list      : List available parsers"
  print_verbose "  create    : Create a new parser"
  print_verbose "  install   : Install a specific parser into SOF-ELK"
fi