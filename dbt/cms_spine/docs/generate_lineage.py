"""One-off script to render the dbt DAG from target/manifest.json as a PNG.
Not part of the dbt pipeline -- run manually after `dbt docs generate` if the
lineage graph needs to be refreshed for the README.
"""
import json
import re
from pathlib import Path

import matplotlib.pyplot as plt
import networkx as nx

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / "target" / "manifest.json").read_text(encoding="utf-8"))

nodes = {**manifest["nodes"], **manifest["sources"]}

G = nx.DiGraph()
layer_of = {}


def layer(node):
    if node.get("resource_type") == "source":
        return 0
    if node.get("resource_type") == "seed":
        return 1
    path = node.get("path", "")
    if path.startswith("staging"):
        return 1
    if "dims" in path or "facts" in path:
        return 2
    return 3


for uid, node in nodes.items():
    if node.get("resource_type") == "test":
        continue
    name = node.get("name", uid)
    G.add_node(uid, label=name)
    layer_of[uid] = layer(node)

for uid, node in manifest["nodes"].items():
    if node.get("resource_type") == "test":
        continue
    for dep in node.get("depends_on", {}).get("nodes", []):
        if dep in G.nodes:
            G.add_edge(dep, uid)

# Layout: x = layer (source -> staging/seed -> mart -> ...), y = spread within layer
by_layer = {}
for uid in G.nodes:
    by_layer.setdefault(layer_of.get(uid, 0), []).append(uid)

pos = {}
for l, uids in by_layer.items():
    uids.sort()
    n = len(uids)
    for i, uid in enumerate(uids):
        pos[uid] = (l * 3.0, (i - n / 2) * 1.0)

color_map = {0: "#c9d6e3", 1: "#a8d5a2", 2: "#f2c078", 3: "#e06c75"}
node_colors = [color_map.get(layer_of.get(u, 0), "#cccccc") for u in G.nodes]

fig, ax = plt.subplots(figsize=(16, 10))
nx.draw_networkx_edges(G, pos, ax=ax, arrows=True, arrowsize=10, edge_color="#999999", width=0.8)
nx.draw_networkx_nodes(G, pos, ax=ax, node_color=node_colors, node_size=1800, edgecolors="#333333")
labels = {uid: re.sub(r"^(stg_|dim_|fct_|seed_)", "", G.nodes[uid]["label"]) for uid in G.nodes}
nx.draw_networkx_labels(G, pos, labels=labels, ax=ax, font_size=7)

ax.set_title("cms_spine dbt lineage: sources -> staging/seeds -> dims/facts", fontsize=13)
ax.axis("off")
plt.tight_layout()

out_path = root / "docs" / "lineage_graph.png"
plt.savefig(out_path, dpi=150)
print(f"Wrote {out_path}")
