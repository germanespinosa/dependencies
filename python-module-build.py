#!/bin/python
import sys
from dependencies import build_module

module_name = sys.argv[1]
module_version_string = None
if len(sys.argv) > 2:
    module_version_string = sys.argv[2]

module_file = build_module(module_name,module_version_string)
print(module_file)
