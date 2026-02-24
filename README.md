 # Local Harness for Logos Node with Storage

This repository provides build recipes and a harness to run a local fleet of Logos nodes with storage enabled. It illustrates how building the configurations for the individual nodes should work, as well as how to initialize them with data with the current Logos headless CLI.

### Usage

```bash
# Builds the storage module, liblogos and the CLI app.
> bash build.bash
# Generates some test files to prepopulate the Logos nodes.
> bash gen-files.sh
# Starts the Logos nodes.
> bash startup.bash ./testfiles
```

You can now inspect the `nodes/config` folder to see the configuration files and the `nodes/log` folder to see the logs. You can also download files from the nodes using the UI or any of the other methods for downloading files. When you are done, you can tear everything down with:

```bash
> bash shutdown.bash
```
