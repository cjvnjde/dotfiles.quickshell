#!/usr/bin/env python3

import json
import subprocess
import sys
from collections.abc import Iterable
from typing import Any

PW_DUMP_TIMEOUT_SECONDS = 5
PW_LINK_TIMEOUT_SECONDS = 5


class RouteError(Exception):
    pass


def object_properties(pipewire_object: dict[str, Any]) -> dict[str, Any]:
    return pipewire_object.get("info", {}).get("props", {})


def load_graph() -> list[dict[str, Any]]:
    try:
        result = subprocess.run(
            ["pw-dump"],
            check=True,
            capture_output=True,
            text=True,
            timeout=PW_DUMP_TIMEOUT_SECONDS,
        )
        graph = json.loads(result.stdout)
    except (FileNotFoundError, subprocess.SubprocessError, json.JSONDecodeError) as error:
        raise RouteError("Could not read the PipeWire graph") from error

    if not isinstance(graph, list):
        raise RouteError("PipeWire returned an invalid graph")
    return graph


def audio_ports(
    graph: Iterable[dict[str, Any]], node_id: int, direction: str
) -> list[dict[str, Any]]:
    ports = []
    for pipewire_object in graph:
        if pipewire_object.get("type") != "PipeWire:Interface:Port":
            continue

        properties = object_properties(pipewire_object)
        if properties.get("node.id") != node_id:
            continue
        if properties.get("port.direction") != direction:
            continue
        if not properties.get("audio.channel"):
            continue
        ports.append(pipewire_object)

    return sorted(
        ports,
        key=lambda port: (
            object_properties(port).get("port.id", 0),
            port.get("id", 0),
        ),
    )


def pair_ports(
    source_ports: list[dict[str, Any]], sink_ports: list[dict[str, Any]]
) -> list[tuple[int, int]]:
    if not source_ports:
        raise RouteError("The selected input has no audio output ports")
    if not sink_ports:
        raise RouteError("The selected output has no audio input ports")

    if len(source_ports) == 1:
        return [(source_ports[0]["id"], sink_port["id"]) for sink_port in sink_ports]
    if len(sink_ports) == 1:
        return [(source_port["id"], sink_ports[0]["id"]) for source_port in source_ports]

    sinks_by_channel = {
        object_properties(port)["audio.channel"]: port for port in sink_ports
    }
    matching_channels = [
        (source_port["id"], sinks_by_channel[channel]["id"])
        for source_port in source_ports
        if (channel := object_properties(source_port)["audio.channel"])
        in sinks_by_channel
    ]
    if matching_channels:
        return matching_channels

    if len(source_ports) == len(sink_ports):
        return [
            (source_port["id"], sink_port["id"])
            for source_port, sink_port in zip(source_ports, sink_ports, strict=True)
        ]

    raise RouteError("The selected input and output channel layouts are incompatible")


def route_links(
    graph: Iterable[dict[str, Any]], source_id: int, sink_id: int
) -> list[dict[str, Any]]:
    links = []
    for pipewire_object in graph:
        if pipewire_object.get("type") != "PipeWire:Interface:Link":
            continue

        properties = object_properties(pipewire_object)
        if (
            properties.get("link.output.node") == source_id
            and properties.get("link.input.node") == sink_id
        ):
            links.append(pipewire_object)
    return links


def run_pw_link(arguments: list[str]) -> None:
    try:
        result = subprocess.run(
            ["pw-link", *arguments],
            capture_output=True,
            text=True,
            timeout=PW_LINK_TIMEOUT_SECONDS,
        )
    except FileNotFoundError as error:
        raise RouteError("pw-link is not installed") from error
    except subprocess.TimeoutExpired as error:
        raise RouteError("PipeWire did not finish changing the route") from error

    if result.returncode != 0:
        detail = result.stderr.strip()
        raise RouteError(detail or "pw-link could not change the route")


def connect(source_id: int, sink_id: int) -> None:
    graph = load_graph()
    pairs = pair_ports(
        audio_ports(graph, source_id, "out"),
        audio_ports(graph, sink_id, "in"),
    )
    existing_pairs = {
        (
            object_properties(link).get("link.output.port"),
            object_properties(link).get("link.input.port"),
        )
        for link in route_links(graph, source_id, sink_id)
    }
    original_link_ids = {link["id"] for link in route_links(graph, source_id, sink_id)}

    try:
        for output_port_id, input_port_id in pairs:
            if (output_port_id, input_port_id) not in existing_pairs:
                run_pw_link(["--linger", str(output_port_id), str(input_port_id)])
    except RouteError:
        for link in route_links(load_graph(), source_id, sink_id):
            if link["id"] not in original_link_ids:
                run_pw_link(["--disconnect", str(link["id"])])
        raise


def disconnect(source_id: int, sink_id: int) -> None:
    for link in route_links(load_graph(), source_id, sink_id):
        run_pw_link(["--disconnect", str(link["id"])])


def main(arguments: list[str]) -> int:
    if len(arguments) != 3 or arguments[0] not in {"connect", "disconnect"}:
        print("usage: AudioRoute.py connect|disconnect SOURCE_ID SINK_ID", file=sys.stderr)
        return 2

    try:
        source_id = int(arguments[1])
        sink_id = int(arguments[2])
        if arguments[0] == "connect":
            connect(source_id, sink_id)
        else:
            disconnect(source_id, sink_id)
    except (RouteError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
