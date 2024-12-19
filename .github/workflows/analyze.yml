name: "analyze"
on:
  pull_request:
  push:
    branches:
      - master

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          channel: "stable"
          flutter-version-file: pubspec.yaml
          architecture: x64
      - run: flutter pub get
      - uses: invertase/github-action-dart-analyzer@v1
