import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

def box(ax, x, y, w, h, text, color):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.3",
                                ec="black", fc=color, lw=1.5))
    ax.text(x + w/2, y + h/2, text, ha="center", va="center",
            fontsize=10.5, weight="bold", wrap=True)

def arrow(ax, x1, y1, x2, y2, color="gray", style="-"):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle="->", lw=1.4,
                                color=color, linestyle=style))

def badge(ax, x, y, text, fc="#ffffff", ec="#888888"):
    ax.add_patch(FancyBboxPatch((x, y), 2.2, 0.6, boxstyle="round,pad=0.2",
                                ec=ec, fc=fc, lw=1.0))
    ax.text(x + 1.1, y + 0.3, text, ha="center", va="center",
            fontsize=9, color="#444444")

def fig_system_architecture_clean():
    fig = plt.figure(figsize=(14, 6))
    ax = plt.gca()

    W, H = 3.4, 1.2
    y_main = 3.0
    x_app, x_storage, x_edge, x_api, x_model = 0.5, 4.3, 8.1, 11.9, 15.7
    y_db = 1.1
    x_db = 8.1

    box(ax, x_app, y_main, W, H, "Flutter\nMobile App", "#a3c9f7")
    box(ax, x_storage, y_main, W, H, "Supabase\nStorage", "#c9e7c1")
    box(ax, x_edge, y_main, W, H, "Supabase\nEdge Function", "#c9e7c1")
    box(ax, x_api, y_main, W, H, "FastAPI Backend\n(/api/v1/unified)", "#f9d199")
    box(ax, x_model, y_main, W, H, "ML Model\n(Random Forest)", "#f7a8a8")

    badge(ax, x_api + 0.5, y_main + H + 0.2, "/api/v1/health")
    box(ax, x_db, y_db, W, H, "Supabase Cloud DB", "#c9e7c1")

    # Main arrows
    arrow(ax, x_app + W, y_main + H/2, x_storage, y_main + H/2)
    arrow(ax, x_storage + W, y_main + H/2, x_edge, y_main + H/2)
    arrow(ax, x_edge + W, y_main + H/2, x_api, y_main + H/2)
    arrow(ax, x_api + W, y_main + H/2, x_model, y_main + H/2)

    # Downward data flow
    arrow(ax, x_edge + W/2, y_main, x_db + W/2, y_db + H, style="--")
    arrow(ax, x_api + W/2, y_main, x_db + W/2, y_db + H, style="--")

    ax.text((x_edge + x_db)/2 + 0.3, (y_main + y_db)/2 + 0.2,
            "Insert results", color="gray", fontsize=9, ha="center")
    ax.text((x_api + x_db)/2 + 0.3, (y_main + y_db)/2 - 0.1,
            "Alerts / History", color="gray", fontsize=9, ha="center")

    plt.axis("off")
    plt.title("System Overview — Breath Easy Architecture", fontsize=14, weight="bold", pad=20)
    ax.set_xlim(-0.5, 19.0)
    ax.set_ylim(0.5, 5.5)
    plt.tight_layout()
    plt.savefig("fig_system_architecture_clean_v2.png", dpi=300, bbox_inches="tight")

if __name__ == "__main__":
    fig_system_architecture_clean()
    print("Saved clean version: fig_system_architecture_clean_v2.png")
