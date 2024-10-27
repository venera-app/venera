import subprocess

debianContent = ''
desktopContent = ''
version = ''

with open('debian/debian.yaml', 'r') as f:
    debianContent = f.read()
with open('debian/gui/venera.desktop', 'r') as f:
    desktopContent = f.read()
with open('pubspec.yaml', 'r') as f:
    version = str.split(str.split(f.read(), 'version: ')[1], '+')[0]

with open('debian/debian.yaml', 'w') as f:
    f.write(debianContent.replace('{{Version}}', version))
with open('debian/gui/venera.desktop', 'w') as f:
    f.write(desktopContent.replace('{{Version}}', version))

subprocess.run(["flutter", "build", "linux"])

subprocess.run(["$HOME/.pub-cache/bin/flutter_to_debian"], shell=True)

with open('debian/debian.yaml', 'w') as f:
    f.write(debianContent)
with open('debian/gui/venera.desktop', 'w') as f:
    f.write(desktopContent)
