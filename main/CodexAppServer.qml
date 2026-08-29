import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string state: "disconnected"
    property string sandboxName: ""
    property string lastError: ""
    property int nextRequestId: 1
    property int reconnectAttempt: 0
    property bool intentionalStop: false
    readonly property bool ready: state === "ready" || state === "streaming"

    signal notification(string method, var params)
    signal serverRequest(int requestId, string method, var params)
    signal response(int requestId, bool succeeded, var payload)
    signal diagnostic(string message)

    function start() {
        if (process.running || state === "connecting" || state === "initializing") {
            return;
        }

        if (sandboxName.length === 0) {
            state = "error";
            lastError = "No sbx sandbox is configured.";
            return;
        }

        intentionalStop = false;
        lastError = "";
        state = "connecting";
        process.running = true;
    }

    function stop() {
        intentionalStop = true;
        reconnectTimer.stop();
        process.running = false;
        state = "disconnected";
    }

    function reconnect() {
        reconnectAttempt = 0;
        stop();
        intentionalStop = false;
        Qt.callLater(() => start());
    }

    function request(method, params) {
        if (!process.running) {
            return -1;
        }

        const requestId = nextRequestId++;
        writeMessage({ id: requestId, method: method, params: params || {} });
        if (AiConfig.debug) {
            console.log("AI app-server request", requestId, method);
        }
        return requestId;
    }

    function notify(method, params) {
        if (process.running) {
            writeMessage({ method: method, params: params || {} });
        }
    }

    function reply(requestId, result) {
        writeMessage({ id: requestId, result: result });
    }

    function replyError(requestId, code, message) {
        writeMessage({ id: requestId, error: { code: code, message: message } });
    }

    function writeMessage(message) {
        process.write(JSON.stringify(message) + "\n");
    }

    function handleLine(line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (error) {
            diagnostic("Ignored a malformed app-server message.");
            return;
        }

        if (message.id !== undefined && message.method !== undefined) {
            serverRequest(Number(message.id), String(message.method), message.params || {});
        } else if (message.id !== undefined) {
            response(Number(message.id), message.error === undefined,
                message.error === undefined ? message.result : message.error);
        } else if (message.method !== undefined) {
            notification(String(message.method), message.params || {});
        }
    }

    Process {
        id: process

        command: [AiConfig.sbxExecutable, "exec", "-i",
            root.sandboxName, "codex", "app-server"]
        stdinEnabled: true

        stdout: SplitParser {
            onRead: data => root.handleLine(data)
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.trim().length > 0) {
                    root.diagnostic("Codex app-server reported a diagnostic on stderr.");
                }
            }
        }

        onStarted: {
            root.state = "initializing";
        }

        onExited: function(exitCode) {
            if (root.intentionalStop) {
                return;
            }

            root.state = "error";
            root.lastError = "Codex app-server exited (code " + exitCode + ").";
            root.diagnostic(root.lastError);
            if (root.reconnectAttempt < 3) {
                reconnectTimer.interval = Math.min(8000, 750 * Math.pow(2, root.reconnectAttempt));
                root.reconnectAttempt++;
                reconnectTimer.restart();
            }
        }
    }

    Timer {
        id: reconnectTimer

        repeat: false
        onTriggered: root.start()
    }
}
