# Building iPXE 
To best support booting nodes, we need to build iPXE from source. This fixes issues with nodes getting stuck in the boot process and enables compressed images to be used. 

This section is based on this script[https://github.com/hpcng/warewulf/blob/41c289023277fb9cdaace9a71809db10acfb122c/scripts/build-ipxe.sh] and references from the Warewulf slack channel. 

As of Jan 2024, the latest commits to the iPXE GitHub do not work for us and we need to pull from a commit from Aug 2023. 

```
git clone https://github.com/ipxe/ipxe.git
cd ipxe
git checkout 9e99a55b317f5da66f5110891b154084b337a031
```

### Building for x86_64
Using the commit we checked out above, we can enable the compressed image features and serial console/framebuffer, then build. 
```
cd src
vim config/general.h #Uncomment IMAGE_GZIP and IMAGE_ZLIB from this file
vim config/console.h #Uncomment CONSOLE_FRAMEBUFFER and CONSOLE_SERIAL from this file
vim config/branding.h #Optional- Add the appropriate title to PRODUCT_NAME
make -j 4 bin-x86_64-efi/snponly.efi
cp bin-x86_64-efi/snponly.efi /var/lib/tftpboot/warewulf/x86_64.efi #Make sure the warewulf.conf file is set to use this build
```

### Building for ARM
To build for ARM on an x86_64 host, we need to install the right cross-compiler. Then enable compressed image features, but not enable the serial console, then build. 
```
dnf install gcc-aarch64-linux-gnu.x86_64
vim config/general.h #Uncomment IMAGE_GZIP and IMAGE_ZLIB from this file
vim config/branding.h #Optional - Add the appropriate title to PRODUCT_NAME
make -j 4 CROSS=aarch64-linux-gnu- bin-arm64-efi/snponly.efi
cp bin-arm64-efi/snponly.efi /var/lib/tftpboot/warewulf/arm64.efi #Make sure the warewulf.conf file is set to use this build
```
