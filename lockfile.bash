LOGOS_CLI=master
LOGOS_PACKAGE_MANAGER=master

STORAGE_MODULE=v1.1.0
STORAGE_LIBSTORAGE=master
#STORAGE_LIBSTORAGE=refs/tags/v0.4.0-rc4

# We need the bare reference for git clone --branch
bare="$STORAGE_LIBSTORAGE"
bare="${bare#refs/}"
bare="${bare#tags/}"
bare="${bare#heads/}"

STORAGE_LIBSTORAGE_BARE="${bare}"
unset bare
