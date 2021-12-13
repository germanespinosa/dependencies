#!/bin/python
import sys

def get_version_from_string(version_string):
    major = int(version_string.split(".")[0])
    minor = int(version_string.split(".")[1])
    build = int(version_string.split(".")[2])
    return major, minor, build


def get_current_version(module_name):
    import os
    if os.path.exists(module_name + "/__version__.py"):
        sys.path.insert(1, module_name)
        from __version__ import module_version
        return module_version()
    else:
        return 0, 0, 0


def get_version_string(major, minor, build):
    return str(major) + "." + str(minor) + "." + '{:0>3}'.format(build)


def get_version_script(major, minor, build):
    version_script = "def module_version():\n"
    version_script += "\treturn " + str(major) + ", " + str(minor) + ", " + str(build) + " \n"
    return version_script


def save_version_script(module_name, major, minor, build):
    script = get_version_script(major, minor, build)
    with open(module_name + "/__version__.py", "w") as v:
        v.write(script)


def build_module(module_name, module_file):
    from zipfile import ZipFile
    from glob import glob
    zipObj = ZipFile(module_file, 'w')
    g = glob(module_name + "/*")
    for f in g:
        zipObj.write(f)
    zipObj.close()


module_name = sys.argv[1]

major, minor, build = (0, 0, 0)

if len(sys.argv) > 2:
    major, minor, build = get_version_from_string(sys.argv[2])
else:
    major, minor, build = get_current_version(module_name)
    build += 1

version = get_version_string(major, minor, build)

save_version_script(module_name, major, minor, build)
module_file = 'build/' + module_name + version + '.zip'
build_module(module_name, module_file)
print(module_file)
