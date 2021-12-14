$modules_folder=$(python -m site --user-site)

New-Item -Path $modules_folder -Name "dependencies" -ItemType "directory" -Force

Invoke-WebRequest "https://raw.githubusercontent.com/germanespinosa/dependencies/main/dependencies/__init__.py" -OutFile "$modules_folder/dependencies/__init__.py"
Invoke-WebRequest "https://raw.githubusercontent.com/germanespinosa/dependencies/main/dependencies/__version__.py" -OutFile "$modules_folder/dependencies/__version__.py"