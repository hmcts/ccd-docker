# Azure Authentication for pulling docker images

## Install Azure CLI on MacOS

Based on  https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-macos?view=azure-cli-latest
### Install with homebrew

Install Azure-CLI locally,

```bash
brew update && brew install azure-cli
```

and to update a Azure-CLI locally,

```bash
brew update azure-cli
```

## Install Azure CLI on other platforms
See: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest


## Login with Azure CLI and CCD 
then,
login to MS Azure,

```bash
az login
```
and finally, Login to the Azure Container registry:

```bash
./ccd login
```

On windows platform, we are installing the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) using executable .msi file.
If "az login" command throws an error like "Access Denied", please follow these steps.
We will need to install the az cli using Python PIP.
1. If Microsoft Azure CLI is already installed, uninstall it from control panel.
2. Setup the Python(version 2.x/3.x) on windows machine. PIP is bundled with Python.
3. Execute the command "pip install azure-cli" using command line. It takes about 20 minutes to install the azure cli.
4. Verify the installation using the command az --version.

[Back to readme](../README.md)