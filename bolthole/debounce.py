from dataclasses import dataclass


@dataclass(frozen=True)
class Event:
    type: str
    path: str
    new_path: str | None = None


def find_origin(
    renames: dict[str, str],
    path: str,
) -> str | None:
    for origin, dest in renames.items():
        if dest == path:
            return origin
    return None


def build_result(
    states: dict[str, str],
    renames: dict[str, str],
) -> list[Event]:
    result = []
    emitted = set()
    for origin, dest in sorted(renames.items()):
        if origin in emitted or dest == origin:
            continue
        if renames.get(dest) == origin:
            result.append(Event("renamed", origin, dest))
            result.append(Event("renamed", dest, origin))
            emitted.add(dest)
        else:
            result.append(Event("renamed", origin, dest))
        emitted.add(origin)

    for path, state in sorted(states.items()):
        result.append(Event(state, path))

    return result


def collapse_events(
    events: list[Event],
) -> list[Event]:
    states: dict[str, str] = {}
    renames: dict[str, str] = {}
    vacated: set[str] = set()

    for event in events:
        if event.type == "created":
            path = event.path
            if states.get(path) == "deleted":
                states[path] = "modified"
            else:
                states[path] = "created"
            vacated.discard(path)

        elif event.type == "modified":
            path = event.path
            if path in vacated:
                continue
            if find_origin(renames, path):
                continue
            if states.get(path) != "created":
                states[path] = "modified"

        elif event.type == "deleted":
            path = event.path
            if path in vacated:
                continue
            origin = find_origin(renames, path)
            if origin:
                del renames[origin]
                states[origin] = "deleted"
                continue
            if states.get(path) == "created":
                del states[path]
            else:
                states[path] = "deleted"

        elif event.type == "renamed":
            src, dst = event.path, event.new_path
            src_origin = find_origin(renames, src)
            if not src_origin:
                src_origin = src
            src_state = states.get(src)
            dst_state = states.get(dst)

            if dst_state == "deleted":
                states[dst] = "modified"
                if src_origin != src and src_origin in renames:
                    del renames[src_origin]
                vacated.add(src)
                continue

            if dst_state == "modified":
                states[src_origin] = "deleted"
                vacated.add(src)
                if src_origin in renames:
                    del renames[src_origin]
                continue

            if dst_state == "created":
                del states[dst]

            if src_state == "created":
                states.pop(src, None)
                states[dst] = "created"
            else:
                states.pop(src, None)
                renames[src_origin] = dst
                vacated.add(src)

    return build_result(states, renames)
