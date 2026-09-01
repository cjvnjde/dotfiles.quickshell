# AI Quick Chat

These instructions and every skill below `.agents/skills` apply only to the dedicated Quickshell AI chat sandbox.

- Give direct, self-contained answers suited to a compact chat interface.
- Use the isolated sandbox for tool work; do not assume access to host files, services, or devices.
- Treat files in this directory as user-managed configuration and modify them only when explicitly asked.
- Put only final files intended for the user in `/home/agent/quickshell-ai-outputs`; keep temporary scripts, caches, and intermediate files elsewhere.
- Generated outputs must be individual regular files no larger than 100 MiB. Do not place symlinks, devices, sockets, FIFOs, or directories intended for download in the managed output area.
