# What is LACK? #
LACK stands for **Linux Appliance Construction Kit**.  LACK is a set of
scripts written in Perl and Bash that will take an existing Linux
installation, and build minimized "packages" that can then be used on
"embedded-style" systems, i.e. systems that boot off of CD-ROM/USB/Network,
and run completely in RAM.

## Other LACK-related Projects ##
- [Main Project](https://github.com/spicyjack/lack)
  - This project
  - Contains scripts to be used with the `initramfs` image, tools scripts,
    sample config files from `/etc`, sample `dialog` menu scripts, and sample
    config files for use with the web server `thttpd`.
- [Documentation](https://github.com/spicyjack/lack-docs)
- [Projects](https://github.com/spicyjack/lack-projects)
  - Sample projects that are used with LACK; these projects should "always"
    build
- [Recipes](https://github.com/spicyjack/lack-recipes)
  - Recipes are lists of files, formatted to be used with the `gen_init_cpio`
    binary that's built inside the Linux kernel whenever you build a Linux
    kernel.  `gen_init_cpio` is used to build `initramfs` images, the RAM disk
    that Linux loads into memory after the kernel itself finishes
    initializing.

vim: filetype=markdown shiftwidth=2 tabstop=2
