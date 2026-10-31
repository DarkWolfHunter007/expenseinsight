@echo off
cd /d "D:/Non-Work/Personal/expenseinsight/mobile/flutter_app"
call flutter run -d web-server --release --web-port 3000 --web-hostname localhost --dart-define=API_URL=http://localhost:8000
