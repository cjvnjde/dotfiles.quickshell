#!/usr/bin/env python3
"""Capture backend: no shell interpolation, one recorder owned by a user unit."""
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import time

UNIT = 'quickshell-bar-recording.service'
STATE = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / 'quickshell-bar-recording.json'

def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

def notify(title, body):
    subprocess.run(['notify-send', '-a', 'Screen capture', title, body], check=False)

def recording():
    return subprocess.run(['systemctl', '--user', 'is-active', '--quiet', UNIT]).returncode == 0

def folder(kind, child):
    result = subprocess.run(['xdg-user-dir', kind], text=True, capture_output=True)
    base = result.stdout.strip() if result.returncode == 0 else ''
    path = (Path(base) if base else Path.home() / kind.title()) / child
    path.mkdir(parents=True, exist_ok=True)
    return path

def geometry():
    result = subprocess.run(['slurp'], stdin=subprocess.DEVNULL, capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ''

def main():
    action = sys.argv[1]
    if action == 'status':
        data = {}
        if STATE.exists():
            try: data = json.loads(STATE.read_text())
            except (ValueError, OSError): pass
        data['recording'] = recording()
        print(json.dumps(data))
        return
    if action == 'stop':
        run(['systemctl', '--user', 'stop', UNIT])
        if STATE.exists():
            data = json.loads(STATE.read_text())
            notify('Recording saved', data.get('path', ''))
        return
    full = len(sys.argv) > 2 and sys.argv[2] == 'full'
    region = '' if full else geometry()
    if not full and not region:
        return  # Selection cancelled.
    stamp = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S-%f')
    if action == 'screenshot':
        path = folder('PICTURES', 'Screenshots') / f'Screenshot_{stamp}.png'
        run(['grim'] + (['-g', region] if region else []) + [str(path)])
        with path.open('rb') as source:
            run(['wl-copy', '--type', 'image/png'], stdin=source)
        notify('Screenshot saved and copied', str(path))
    elif action == 'record':
        if recording():
            return
        path = folder('VIDEOS', 'Recordings') / f'Recording_{stamp}.mp4'
        command = ['wf-recorder', '--no-dmabuf', '-r', '30', '-c', 'libx264', '-p', 'preset=ultrafast', '-p', 'crf=23', '-f', str(path)]
        if region:
            command += ['-g', region]
        elif len(sys.argv) > 3 and sys.argv[3]:
            command += ['-o', sys.argv[3]]
        subprocess.run(['systemctl', '--user', 'reset-failed', UNIT], capture_output=True)
        run(['systemd-run', '--user', '--quiet', '--collect', '--unit', UNIT,
             '--property=KillSignal=SIGINT', '--property=TimeoutStopSec=20',
             '--setenv=WAYLAND_DISPLAY=' + os.environ['WAYLAND_DISPLAY']] + command)
        STATE.write_text(json.dumps({'started': time.time(), 'path': str(path)}))
        time.sleep(0.5)
        if not recording():
            raise RuntimeError('Recorder did not start. See journalctl --user -u ' + UNIT)
    else:
        raise ValueError('Unknown action: ' + action)

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        notify('Capture failed', str(error))
        print(str(error), file=sys.stderr)
        sys.exit(1)
