# Task 005 development API

Install and start the local API from the project root:

```sh
python3 -m pip install --user -r backend/requirements.txt
python3 -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000
```

The Flutter app uses `127.0.0.1:8000` on the iOS Simulator and
`10.0.2.2:8000` on the Android Emulator. Override the URL when needed:

```sh
flutter run --dart-define=API_BASE_URL=http://YOUR_HOST:8000
```
