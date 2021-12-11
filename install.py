#/bin/python

import sys
import subprocess


def download_module(uri):
    import requests
    import tempfile
    try:
        content = requests.get(uri).content
        with tempfile.TemporaryFile(delete=False) as file:
            file.write(content)
            return file.name
    except:
        print("error downloading file")
        exit(1)


def extract_module(file_name, destination):
    import zipfile
    with zipfile.ZipFile(file_name, 'r') as zip_ref:
        zip_ref.extractall(destination)


module_file = download_module(sys.argv[1])
destination = subprocess.Popen(["python", "-m", "site", "--user-site"], stdout=subprocess.PIPE).communicate()[0].decode().replace("\n", "").replace("\r", "")
extract_module(module_file, destination)

