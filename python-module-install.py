#!/bin/python

import sys
from dependencies import install_dependency


module_file = sys.argv[1]
install_dependency(module_file)