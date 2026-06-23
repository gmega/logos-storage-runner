 # Local Harness for Logos Node with Storage

This repository provides a reference harness for running a fleet of Logos nodes with storage enabled. In its current version, it supports a mixed network in which part of the nodes are storage nodes, and part of them are mix relays/DHT proxies.

## Building

You'll need nix, and all the build tools required by [libstorage](https://github.com/logos-storage/logos-storage-nim) (make and gcc, mostly) to build the utility binaries.

You can then build everything by running:

```bash
bash build.bash
```

## K-node Experiment

In a k-node experiment, a random node in the network will be drawn as the _seeder_ of a file, while all the other ones will act as _leechers_, trying to download the file at the same time. In this version of the experiment, we have an additional set of _mix relays_ which will help leechers hide their queries behind a mix network.

To run a single k-node experiment with $5$ mix relays and $10$ storage nodes, do:

```bash
bash k-node.bash 5 10 1
```
