# sdb - Smart Development Bridge for Tizen Emulator

You are helping the user communicate with a Tizen emulator via `sdb` (Smart Development Bridge).

## Key sdb Commands

```
sdb devices                          # 연결된 에뮬레이터/디바이스 목록 확인
sdb -e shell [command]               # 에뮬레이터에서 명령 실행 (-e: emulator)
sdb -e push <local> <remote>         # 호스트 → 에뮬레이터 파일 복사
sdb -e pull <remote> [<local>]       # 에뮬레이터 → 호스트 파일 복사
sdb -e root on                       # root 모드 활성화
sdb -e root off                      # developer 모드로 복귀
sdb -e dlog                          # 디바이스 로그 스트리밍
sdb start-server                     # sdb 서버 시작
sdb kill-server                      # sdb 서버 중지
```

## Workflow for This Project

### 1. 연결 확인
```bash
sdb devices
```

### 2. Root 권한 획득 (systemd 파일 수정 시 필요)
```bash
sdb -e root on
```

### 3. 빌드 바이너리 push
```bash
sdb -e push <build-output>/systemd /usr/lib/systemd/systemd
```

### 4. gcov dump 트리거 (SIGRTMIN+30)
```bash
# SIGRTMIN 값 확인 (보통 34)
sdb -e shell "python3 -c 'import signal; print(signal.SIGRTMIN)'"
# dump 트리거
sdb -e shell "kill -\$((34+30)) 1"
```

### 5. gcda 파일 수집
```bash
sdb -e pull /tmp/gcov-data ./gcov-data
```

### 6. 로그 확인
```bash
sdb -e shell "journalctl -b --no-pager | tail -100"
sdb -e shell "cat /proc/1/status | grep -E 'VmRSS|VmSize|VmPeak'"
```

## Notes

- `-e` 플래그는 에뮬레이터 대상. 실제 디바이스면 `-d` 사용.
- 여러 에뮬레이터가 동시에 실행 중이면 `-s <serial>` 으로 특정.
- systemd 바이너리 교체 후 에뮬레이터 재부팅 필요: `sdb -e shell "reboot"`

## Usage

When the user invokes `/sdb`, use the appropriate sdb commands above based on the task context.
Always run `sdb devices` first to confirm the emulator is connected before other operations.
