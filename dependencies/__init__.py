def install_dependency(module_file):
    filename = module_file.split("/")[-1].replace(".zip", "")
    current_module_version = (0, 0, 0)
    try:
        build = int(filename.split(".")[-1])
        minor = int(filename.split(".")[-2])
        major = int(filename.split(".")[-3])
        required_version = (major, minor, build)
        module_name = filename.split(".")[0]
        module_version = getattr(__import__(module_name, fromlist=["__module_version__"]), "__module_version__")
        current_module_version = module_version()
    except:
        pass
    if required_version != current_module_version:
        if module_file.startswith("https://") or module_file.startswith("http://"):
            module_file = download_module(module_file)
            destination = get_user_modules_folder()
            extract_module(module_file, destination)


def download_module(uri):
    import requests
    import tempfile
    try:
        content = requests.get(uri).content
        with tempfile.NamedTemporaryFile(delete=False) as file:
            file.write(content)
            return file.name
    except:
        print("error downloading file")
        exit(1)


def extract_module(file_name, destination):
    import zipfile
    with zipfile.ZipFile(file_name, 'r') as zip_ref:
        zip_ref.extractall(destination)


def get_user_modules_folder():
    import subprocess
    return subprocess.Popen(["python", "-m", "site", "--user-site"], stdout=subprocess.PIPE).communicate()[
        0].decode().replace("\n", "").replace("\r", "")


def get_version_from_string(version_string):
    major = int(version_string.split(".")[0])
    minor = int(version_string.split(".")[1])
    build = int(version_string.split(".")[2])
    return major, minor, build


def get_current_version(module_name):
    import os
    import sys
    if os.path.exists(module_name + "/__version__.py"):
        sys.path.insert(1, module_name)
        from __version__ import __module_version__
        return __module_version__()
    else:
        return 0, 0, 0


def get_version_string(major, minor, build):
    return str(major) + "." + str(minor) + "." + '{:0>3}'.format(build)


def get_version_script(major, minor, build):
    version_script = "def __module_version__():\n"
    version_script += "\treturn " + str(major) + ", " + str(minor) + ", " + str(build) + " \n"
    return version_script


def save_version_script(module_name, major, minor, build):
    script = get_version_script(major, minor, build)
    with open(module_name + "/__version__.py", "w") as v:
        v.write(script)
    found = False
    lines = []
    with open(module_name + "/__init__.py", "r") as m:
        lines = m.readlines()
    for line in lines:
        if "import __module_version__" in line:
            found = True
    if not found:
        with open(module_name + "/__init__.py", "w") as m:
            m.writelines(["from .__version__ import __module_version__ # DO NOT MODIFY DEPENDENCIES MODULE VERSION\n"])
            m.writelines(lines)


def build_module(module_name, version_string=None):
    import os
    major, minor, build = (0, 0, 0)

    if version_string is None:
        major, minor, build = get_current_version(module_name)
        build += 1
    else:
        major, minor, build = get_version_from_string(version_string)

    version = get_version_string(major, minor, build)
    save_version_script(module_name, major, minor, build)

    if not os.path.isdir("python-build"):
        os.mkdir("python-build")

    module_file = 'python-build/' + module_name + "." + version + '.zip'

    from zipfile import ZipFile
    from glob import glob
    zipObj = ZipFile(module_file, 'w')
    g = glob(module_name + "/*")
    for f in g:
        zipObj.write(f)
    zipObj.close()
    return module_file


if __name__ == "__main__":
    from __version__ import __module_version__
    major, minor, build = __module_version__()
    install_dependency("https://github.com/germanespinosa/dependencies/raw/main/python-build/dependencies." + get_version_string(major, minor, build) + ".zip")
