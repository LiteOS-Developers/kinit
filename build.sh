#! /bin/bash
mkdir -p $TARGET/sbin
cp $SRC/src/init.lua $TARGET/sbin/
cp $SRC/src/init.lua.attr $TARGET/sbin/

printf "[  \033[1;92mOK\033[0;39m  ] kinit\n"
