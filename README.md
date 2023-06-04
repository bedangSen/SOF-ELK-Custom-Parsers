# SOF-ELK-Custom-Parsers

## Overview

SOF-ELK-Custom-Parsers is a collection of bash scripts designed to simplify the process of downloading and setting up different custom parsers for the SOF-ELK platform. These custom parsers enhance the log parsing capabilities of SOF-ELK, allowing you to extract and analyze specific information from your custom datasets.

## Features

+ Simplified parser installation: Download and set up various custom parsers for SOF-ELK with ease.
+ Enhanced log parsing: Extend the log parsing capabilities of SOF-ELK to extract specific data fields from your logs.
+ Easy customization: Modify or add additional parsers to suit your specific log sources and requirements.

## Prerequisites

1. SOF-ELK: Ensure you have a functional instance of SOF-ELK set up and running. If you don't have SOF-ELK installed yet, you can download it from [here](https://github.com/philhagen/sof-elk/blob/main/VM_README.md).
1. Bash: The scripts are designed to be executed using a Bash shell.

## Installation

1. Clone or download the SOF-ELK-Custom-Parsers repository to your SOF-ELK server.

   ```bash
   git clone https://github.com/bedangSen/SOF-ELK-Custom-Parsers.git
   ```

2. Change to the directory of the downloaded repository.

   ```bash
   cd SOF-ELK-Custom-Parsers
   ```

3. Update the permissions of the script to make it a executable.

   ```bash
   chmod +x ./sof-elk-parser-manager.sh
   ```

3. Run the desired parser installation script to set up the parsers you require.

   ```bash
   ./sof-elk-parser-manager.sh
   ```

4. Follow the prompts and instructions provided by the installation script to complete the parser installation.

5. Repeat Step 3 for each additional parser you wish to install.

## Usage

### List Available Parsers

To list the available parsers, run the following command:
```
./sof-elk-parser-manager.sh list
```

### Create a New Parser

To create a new parser, run the following command:
```
./sof-elk-parser-manager.sh create <parser-name>
```

Replace `<parser-name>` with the desired name for your new parser.

### Install a Parser

To install a specific parser into SOF-ELK, run the following command:
```
./sof-elk-parser-manager.sh install <parser-name>
```

Replace `<parser-name>` with the name of the parser you want to install.

## Contributing

Contributions to the SOF-ELK-Custom-Parsers project are welcome! If you have additional parsers or improvements to share, please follow these steps:

1. Fork the repository.
2. Create a new branch for your changes.
3. Make your modifications or additions.
4. Commit and push your changes to your forked repository.
5. Submit a pull request describing your changes.

## License

This project is licensed under the [MIT License](LICENSE).

## Disclaimer

- Please note that SOF-ELK-Custom-Parsers is provided as-is, without any warranty or guarantee. Use it at your own risk.
- Always review and validate the parsers before deploying them in a production environment.
