"""Read a value out of a gNMI answer by its path.

The answer of gnmic is a JSON array with one object per target, and every
object holds a list of updates. An update carries the path that was asked
for and the values below it.

Three things about the paths are worth knowing, because they decide how a
value has to be looked up:

* gnmic writes the path of an update without the leading slash, so the path
  of the request and the path of the answer are never equal as they are.
* The key of a value is the path without its key selectors, e.g. the answer
  of "/ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/data-set-name"
  holds the value under "ds-profile/ds-port-configuration/data-set-name".
* A key selector names the key of the level below it. The JSON of the
  ds-profile is
      ds-profile -> ds-port-configuration -> AMP_PORT_NORTH -> data-set-name
  while the path is
      ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/data-set-name
  so walking a path means descending by the name of a segment and then by
  the value of its selector.

The module is a plain python module, not a Robot library. It is used from
IT_Common.resource through the Evaluate keyword.
"""

MISSING = object()


def strip_selectors(path):
    """The path without its key selectors, e.g. the key of a value."""
    out = []
    depth = 0
    for char in path:
        if char == "[":
            depth += 1
        elif char == "]":
            depth -= 1
        elif depth == 0:
            out.append(char)
    return "".join(out)


def split_segments(path):
    """The path split into (name, selectors) pairs.

    A segment can carry more than one key selector, e.g.
    "legacy-us-input-atten[port=AMP_PORT_MAIN][index=0]" carries the port and
    the index. Every selector is a (key, value) pair.
    """
    segments = []
    for part in path.strip("/").split("/"):
        if not part:
            continue
        name = part.split("[", 1)[0]
        selectors = []
        for chunk in part.split("[")[1:]:
            chunk = chunk.rstrip("]")
            if not chunk:
                continue
            key, _, value = chunk.partition("=")
            selectors.append((key, value))
        segments.append((name, selectors))
    return segments


def canonical(path):
    """The path with its key selectors in a fixed order.

    The DUT answers with the selectors in its own order, e.g. it answers
    "legacy-us-input-atten[port=AMP_PORT_MAIN][index=0]" with
    "legacy-us-input-atten[index=0][port=AMP_PORT_MAIN]", so two paths are
    the same when they are the same after this.
    """
    parts = []
    for name, selectors in split_segments(path):
        if selectors:
            keys = ",".join(sorted("%s=%s" % (key, value) for key, value in selectors))
            parts.append("%s[%s]" % (name, keys))
        else:
            parts.append(name)
    return "/".join(parts)


def walk(node, path):
    """Walk a path down a value tree, or return MISSING.

    A selector names a key of the level below it, but not every selector of
    the path is a key of the tree: the tree of the legacy upstream input
    attenuation holds one value per port and the index of the path is not a
    key of it. A selector whose value is not a key of the node is skipped.
    """
    for name, selectors in split_segments(path):
        if not isinstance(node, dict) or name not in node:
            return MISSING
        node = node[name]
        for _key, value in selectors:
            if isinstance(node, dict) and value in node:
                node = node[value]
    return node


def updates_of(response):
    """The update list of a gnmic answer.

    An answer that is not a list of updates, e.g. the error text of a
    refused request, gives an empty list.
    """
    if isinstance(response, str):
        return []
    targets = response if isinstance(response, list) else [response]
    updates = []
    for target in targets:
        if isinstance(target, dict):
            updates.extend(target.get("updates") or [])
    return updates


def names_of(segments):
    """The names of the segments of a path."""
    return [name for name, _ in segments]


def _same_path(answered, wanted):
    """Whether two paths name the same node of the tree.

    The order of the key selectors does not matter, e.g. the DUT answers
    "legacy-us-input-atten[port=AMP_PORT_MAIN][index=0]" with
    "legacy-us-input-atten[index=0][port=AMP_PORT_MAIN]".
    """
    if names_of(answered) != names_of(wanted):
        return False
    for (_name, one), (_other, two) in zip(answered, wanted):
        if set(one) != set(two):
            return False
    return True


def path_of(segments):
    """The path of a list of segments."""
    parts = []
    for name, selectors in segments:
        if selectors:
            keys = ",".join("%s=%s" % (key, value) for key, value in selectors)
            parts.append("%s[%s]" % (name, keys))
        else:
            parts.append(name)
    return "/".join(parts)


def resolve(response, path):
    """The value of a path inside a gnmic answer, or None when it is not there.

    None is the answer for a path that the answer does not hold, e.g. when
    the DUT refused the request and answered with an error text.
    """
    want = path.strip("/")
    want_segments = split_segments(want)
    for update in updates_of(response):
        answered = str(update.get("Path", "")).strip("/")
        values = update.get("values") or {}
        if not isinstance(values, dict):
            continue
        answered_segments = split_segments(answered)
        if not _same_path(answered_segments, want_segments[:len(answered_segments)]):
            continue
        if len(answered_segments) == len(want_segments):
            # The answer is the path itself, so the value is under the key of
            # the path without its selectors.
            for candidate in (want, strip_selectors(want), canonical(want)):
                if candidate in values:
                    return values[candidate]
            continue
        # The answer is the start of the path, so the rest of the path is
        # walked down the value of the answer.
        base = values.get(strip_selectors(answered), values.get(answered))
        for _key, value in answered_segments[-1][1]:
            if isinstance(base, dict) and value in base:
                base = base[value]
        found = walk(base, path_of(want_segments[len(answered_segments):]))
        if found is not MISSING:
            return found
    return None


def all_values(response):
    """The value of every update of a gnmic answer.

    A GET with a wildcard path answers with one update per matched
    instance, and the values of such an update are held under the path
    without its key selectors, e.g. the answer of
    "amp-alignment[alignment-type=ALIGN_UPSTREAM]" holds them under
    "amp-alignment".
    """
    out = []
    for update in updates_of(response):
        values = update.get("values") or {}
        if not isinstance(values, dict):
            continue
        path = str(update.get("Path", ""))
        key = strip_selectors(path)
        if key in values:
            out.append(values[key])
        elif path in values:
            out.append(values[path])
    return out


def instances_with(response, leaf, value):
    """The instances of a wildcard answer whose leaf holds the given value.

    Used to ask whether the DUT is busy, e.g. whether any alignment stage
    still reports ALIGN_STATUS_IN_PROGRESS.
    """
    return [item for item in all_values(response)
            if isinstance(item, dict) and item.get(leaf) == value]
