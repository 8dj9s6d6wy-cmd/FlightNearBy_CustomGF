"""
Applet: Weather Radar
Summary: Animated US Weather Radar
Description: Displays an animated US weather radar loop from Weather Underground.
Author: Geoff Finnegan
"""

load("cache.star", "cache")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

# Default radar URL — animated APNG from Weather Underground
DEFAULT_RADAR_URL = "https://s.w-x.co/staticmaps/wu/wu/radsum1200_cur/usday/animate.png"

# Cache for 5 minutes — radar updates roughly every 5–10 min
CACHE_TTL = 300

def main(config):
    radar_url = config.str("radar_url", DEFAULT_RADAR_URL)
    show_label = config.bool("show_label", True)

    # Try cache first
    cached = cache.get(radar_url)
    if cached != None:
        img_data = cached
    else:
        res = http.get(radar_url)
        if res.status_code != 200:
            return render_error("Radar fetch failed (%d)" % res.status_code)
        img_data = res.body()
        cache.set(radar_url, img_data, ttl_seconds = CACHE_TTL)

    if show_label:
        return render.Root(
            child = render.Stack(
                children = [
                    render.Image(
                        src = img_data,
                        width = 64,
                        height = 32,
                    ),
                    # Small label pinned to bottom-left
                    render.Column(
                        children = [
                            render.Box(width = 64, height = 24),
                            render.Box(
                                width = 36,
                                height = 8,
                                color = "#00000088",
                                child = render.Text(
                                    content = "US RADAR",
                                    font = "tom-thumb",
                                    color = "#FFFFFF",
                                ),
                            ),
                        ],
                    ),
                ],
            ),
        )
    else:
        return render.Root(
            child = render.Image(
                src = img_data,
                width = 64,
                height = 32,
            ),
        )

def render_error(message):
    return render.Root(
        child = render.Column(
            main_align = "center",
            cross_align = "center",
            expanded = True,
            children = [
                render.Text(
                    content = "RADAR",
                    font = "tom-thumb",
                    color = "#FF4444",
                ),
                render.Marquee(
                    width = 64,
                    child = render.Text(
                        content = message,
                        font = "tom-thumb",
                        color = "#AAAAAA",
                    ),
                    scroll_direction = "horizontal",
                    offset_start = 64,
                ),
            ],
        ),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "radar_url",
                name = "Radar Image URL",
                desc = "URL of an animated PNG radar image. Defaults to the US national radar loop.",
                icon = "cloud",
                default = DEFAULT_RADAR_URL,
            ),
            schema.Toggle(
                id = "show_label",
                name = "Show Label",
                desc = "Show a small 'US RADAR' label overlay.",
                icon = "tag",
                default = True,
            ),
        ],
    )
