#!/bin/bash

MYVAR=hello

if [ -n "${MYVAR+x}" ]; then
echo MYVAR is set
else
echo MYVAR is not set
fi

if [ -n "${MYVAR1+x}" ]; then
echo MYVAR1 is set
else
echo MYVAR1 is not set
fi
