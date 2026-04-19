"""
Applet: TAR1090 ADS-B
Summary: ADS-B From Your Station
Description: ADS-B Information from your publically available tar1090 instance.
Author: Modified by Geoff Finnegan
"""

load("http.star", "http")
load("images/blank.png", BLANK_ASSET = "file")
load("images/error.gif", ERROR_ASSET = "file")
load("re.star", "re")
load("render.star", "render")
load("schema.star", "schema")
load("images/NJALogo.png", NJA_TAIL = "file")

ERROR_ICON = ERROR_ASSET.readall()

TAR1090_URL_DEFAULT = "SET YOUR URL"
HEXDB_BASE_URL = "https://hexdb.io/api/v1"

DEFAULT_CONVERSION_UNITS = "a"

FEET_TO_METERS_RATIO = 0.3048
NMI_TO_KM_RATIO = 1.8520
NMI_TO_MI_RATIO = 1.1508

EMERGENCY_SQUAWKS = {
    "7500": "HIJACK",
    "7600": "RADIO FAIL",
    "7700": "EMERGENCY",
}

# Keywords used to identify military-owned aircraft from RegisteredOwners field
MIL_KEYWORDS = [
    "army",
    "air force",
    "navy",
    "marines",
    "coast guard",
    "national guard",
    "luftwaffe",
    "royal air force",
    "royal navy",
    "bundeswehr",
]

COMPASS_DIRS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

# ── hexdb.io API helpers ──────────────────────────────────────────────────────

def lookup_hexdb_aircraft(icao):
    """Fetch aircraft record from hexdb.io by ICAO hex. Returns dict or None."""
    url = "%s/aircraft/%s" % (HEXDB_BASE_URL, icao.upper())
    response = http.get(url, ttl_seconds = 86400)
    if response.status_code != 200:
        print("hexdb aircraft lookup failed: %d" % response.status_code)
        return None
    data = response.json()
    if "error" in data:
        print("hexdb aircraft not found: %s" % icao)
        return None
    return data

def lookup_hexdb_route(callsign):
    """Fetch ICAO route for a callsign from hexdb.io. Returns 'ORIG-DEST' string or None."""
    clean = callsign.strip()
    if len(clean) == 0:
        return None
    url = "%s/route/icao/%s" % (HEXDB_BASE_URL, clean)
    response = http.get(url, ttl_seconds = 3600)
    if response.status_code != 200:
        return None
    data = response.json()
    if "error" in data:
        return None
    if "route" in data:
        return data["route"]
    return None

# ── Aircraft classification helpers ──────────────────────────────────────────

def is_military_aircraft(hexdb_data):
    """Detect military aircraft by checking RegisteredOwners for known keywords."""
    if hexdb_data == None:
        return False
    owner = hexdb_data.get("RegisteredOwners", "").lower()
    for kw in MIL_KEYWORDS:
        if kw in owner:
            return True
    return False

def track_to_compass(track):
    """Convert a track/heading in degrees to an 8-point compass string."""
    idx = int((track + 22.5) / 45) % 8
    return COMPASS_DIRS[idx]

def get_alt_display(conversion_unit, alt_baro):
    """Return altitude as FL notation (aeronautical/imperial) or meters (metric)."""
    if alt_baro == "ground":
        return "GND"
    alt = int(alt_baro)
    if alt <= 0:
        return "GND"
    if conversion_unit == "m":
        return "%dm" % int(alt * FEET_TO_METERS_RATIO)
    return "FL%d" % int(alt / 100)

# ── Aircraft icon helper ──────────────────────────────────────────────────────

def get_aircraft_icon(category, designator, description, addrtype, color):
    url = (
        "https://tar1090tidbyt.azurewebsites.net/api/aircraft_icon" +
        "?category=%s&typeDesignator=%s&typeDescription=%s&addrtype=%s&color=%s" % (
            category, designator, description.replace(" ", "%20"), addrtype, color
        )
    )
    response = http.get(url, ttl_seconds = 86400)
    if response.status_code != 200:
        fail("Aircraft icon request failed with status %d" % response.status_code)
    return response.body()

def get_altitude_icon_color(altitude):
    if altitude == "ground":
        altitude = 0
    if altitude <= 1000:
        return "EF6913"
    elif altitude <= 2000:
        return "F07819"
    elif altitude <= 4000:
        return "F19820"
    elif altitude <= 6000:
        return "E9B714"
    elif altitude <= 8000:
        return "C2C50E"
    elif altitude <= 10000:
        return "61C70D"
    elif altitude <= 20000:
        return "20C231"
    elif altitude <= 30000:
        return "0FB5bE"
    elif altitude <= 40000:
        return "3C3dEF"
    else:
        return "CC0DCE"

# ── Unit conversions ──────────────────────────────────────────────────────────

def convert_spd(unit, value):
    if unit == "i":
        return value * NMI_TO_MI_RATIO
    elif unit == "m":
        return value * NMI_TO_KM_RATIO
    return value

def convert_dst(unit, value):
    if unit == "i":
        return value * NMI_TO_MI_RATIO
    elif unit == "m":
        return value * NMI_TO_KM_RATIO
    return value

# ── Haversine distance (custom coords feature) ───────────────────────────────

def calculate_distance(lat1, lon1, lat2, lon2):
    lat1_rad = lat1 * 3.14159265359 / 180.0
    lon1_rad = lon1 * 3.14159265359 / 180.0
    lat2_rad = lat2 * 3.14159265359 / 180.0
    lon2_rad = lon2 * 3.14159265359 / 180.0
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    sin_dlat_2 = _sin(dlat / 2)
    sin_dlon_2 = _sin(dlon / 2)
    a = (sin_dlat_2 * sin_dlat_2) + _cos(lat1_rad) * _cos(lat2_rad) * (sin_dlon_2 * sin_dlon_2)
    c = 2 * _atan2(_sqrt(a), _sqrt(1 - a))
    return 3440.065 * c

def _sin(x):
    result = x
    term = x
    for i in range(1, 10):
        term = -term * x * x / ((2 * i) * (2 * i + 1))
        result = result + term
    return result

def _cos(x):
    result = 1
    term = 1
    for i in range(1, 10):
        term = -term * x * x / ((2 * i - 1) * (2 * i))
        result = result + term
    return result

def _sqrt(x):
    if x == 0:
        return 0
    estimate = x / 2.0
    for _ in range(10):
        estimate = (estimate + x / estimate) / 2.0
    return estimate

def _atan2(y, x):
    if x > 0:
        return _atan(y / x)
    elif x < 0 and y >= 0:
        return _atan(y / x) + 3.14159265359
    elif x < 0 and y < 0:
        return _atan(y / x) - 3.14159265359
    elif x == 0 and y > 0:
        return 3.14159265359 / 2
    elif x == 0 and y < 0:
        return -3.14159265359 / 2
    return 0

def _atan(x):
    if x > 1:
        return 3.14159265359 / 2 - _atan(1 / x)
    elif x < -1:
        return -3.14159265359 / 2 - _atan(1 / x)
    result = 0
    term = x
    for i in range(20):
        result = result + term
        term = -term * x * x * (2 * i + 1) / (2 * i + 3)
    return result

# ── Aircraft selection ────────────────────────────────────────────────────────

def aircraft_distance_sort(aircraft, priority_distance, use_custom_coords, custom_lat, custom_lon):
    if use_custom_coords and "lat" in aircraft and "lon" in aircraft:
        distance = calculate_distance(custom_lat, custom_lon, aircraft["lat"], aircraft["lon"])
    elif "r_dst" in aircraft:
        distance = aircraft["r_dst"]
    else:
        distance = 10000

    is_emergency = "squawk" in aircraft and aircraft["squawk"] in EMERGENCY_SQUAWKS

    is_priority = False
    if "flight" in aircraft:
        callsign = aircraft["flight"].strip().upper()
        if (callsign.startswith("EJA") or callsign.startswith("EJM")) and distance <= priority_distance:
            is_priority = True

    return (not is_emergency, not is_priority, distance)

def find_nearest_aircraft(aircrafts, priority_distance, use_custom_coords, custom_lat, custom_lon):
    aircrafts = sorted(
        aircrafts,
        key = lambda aircraft: aircraft_distance_sort(aircraft, priority_distance, use_custom_coords, custom_lat, custom_lon),
    )
    for aircraft in aircrafts:
        if "category" in aircraft and "alt_baro" in aircraft:
            return aircraft
    return None

def get_callsign(aircraft):
    if "flight" in aircraft:
        return aircraft["flight"]
    return "None"

# ── Dummy data for testing ────────────────────────────────────────────────────

def generate_dummy_aircraft():
    return [
        {
            "hex": "a12345",
            "type": "adsb_icao",
            "flight": "EJA123  ",
            "alt_baro": 35000,
            "gs": 450.5,
            "track": 90.0,
            "squawk": "1234",
            "emergency": "none",
            "category": "A3",
            "lat": 40.0,
            "lon": -83.0,
            "r_dst": 8.5,
            "r_dir": 180.0,
            "messages": 500,
            "seen": 0.1,
        },
        {
            "hex": "AE5D9B",
            "type": "adsb_icao",
            "flight": "ARMY123 ",
            "alt_baro": 3500,
            "gs": 140.0,
            "track": 270.0,
            "squawk": "7700",
            "emergency": "general",
            "category": "A3",
            "lat": 40.5,
            "lon": -83.5,
            "r_dst": 4.2,
            "r_dir": 45.0,
            "messages": 850,
            "seen": 0.3,
        },
    ]

# ── Error display ─────────────────────────────────────────────────────────────

def unable_to_reach_tar_error(tar_url):
    return render.Root(
        child = render.Column(
            children = [
                render.Image(src = ERROR_ICON),
                render.Marquee(
                    width = 64,
                    child = render.Text("!!! CAN'T REACH TAR1090 @ " + tar_url + " !!!"),
                    scroll_direction = "horizontal",
                ),
            ],
        ),
    )

def validate_url(url):
    url_regex = "http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*(),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+"
    return len(re.findall(url_regex, url)) > 0

# ── Main ──────────────────────────────────────────────────────────────────────

def main(config):
    tar_url = config.str("tar1090url", TAR1090_URL_DEFAULT)
    dummy_mode = config.str("dummy_mode", "none")
    priority_distance = int(config.str("priority_distance", "10"))
    use_custom_coords = config.bool("use_custom_coords", False)
    custom_lat = float(config.str("custom_lat", "0.0"))
    custom_lon = float(config.str("custom_lon", "0.0"))

    if use_custom_coords and custom_lat == 0.0 and custom_lon == 0.0:
        use_custom_coords = False

    route = None

    # ── Data acquisition ──────────────────────────────────────────────────────
    if dummy_mode != "none":
        dummy_aircraft = generate_dummy_aircraft()

        if dummy_mode == "aircraft1":
            aircraft = dummy_aircraft[0]
            hexdb_data = {
                "Registration": "N123EJ",
                "ICAOTypeCode": "C700",
                "Manufacturer": "Cessna",
                "Type": "Citation Longitude",
                "RegisteredOwners": "NetJets Aviation Inc",
                "OperatorFlagCode": "EJA",
                "ModeS": "A12345",
            }
            route = "KLAS-KTEB"

        elif dummy_mode == "aircraft2":
            aircraft = dummy_aircraft[1]
            hexdb_data = {
                "Registration": "16-20913",
                "ICAOTypeCode": "H60",
                "Manufacturer": "Sikorsky",
                "Type": "UH-60M Blackhawk",
                "RegisteredOwners": "United States Army",
                "OperatorFlagCode": "H60",
                "ModeS": "AE5D9B",
            }
            route = None  # Military: will fall back to heading

        else:
            return unable_to_reach_tar_error("NO DUMMY AIRCRAFT SELECTED")

    else:
        # Live mode
        if tar_url == TAR1090_URL_DEFAULT or not validate_url(tar_url):
            return unable_to_reach_tar_error(tar_url)

        response = http.get(tar_url + "/data/aircraft.json")
        if response.status_code != 200:
            return unable_to_reach_tar_error(tar_url)

        aircrafts = response.json()["aircraft"]

        aircraft = find_nearest_aircraft(aircrafts, priority_distance, use_custom_coords, custom_lat, custom_lon)
        if aircraft == None:
            return unable_to_reach_tar_error(tar_url)

        # hexdb lookups (both are gracefully optional)
        hexdb_data = lookup_hexdb_aircraft(aircraft["hex"])

        callsign_raw = get_callsign(aircraft).strip()
        if len(callsign_raw) > 0 and callsign_raw != "None":
            route = lookup_hexdb_route(callsign_raw)

    conversion_unit = config.str("units", DEFAULT_CONVERSION_UNITS)

    # ── Derived display values ────────────────────────────────────────────────
    callsign = get_callsign(aircraft).strip().upper()
    is_nja = callsign.startswith("EJA") or callsign.startswith("EJM")
    is_mil = is_military_aircraft(hexdb_data)

    alt_baro = aircraft.get("alt_baro", 0)
    alt_display = get_alt_display(conversion_unit, alt_baro)

    spd = int(convert_spd(conversion_unit, aircraft.get("gs", 0)))
    spd_display = "Sp:%d" % spd

    if use_custom_coords and "lat" in aircraft and "lon" in aircraft:
        dst_val = int(convert_dst(conversion_unit, calculate_distance(custom_lat, custom_lon, aircraft["lat"], aircraft["lon"])))
        dst_display = "Dst:%d" % dst_val
    elif "r_dst" in aircraft:
        dst_val = int(convert_dst(conversion_unit, aircraft["r_dst"]))
        dst_display = "Dst:%d" % dst_val
    else:
        dst_display = ""

    # Bottom bar priority: emergency > route > compass heading
    is_emergency = "squawk" in aircraft and aircraft["squawk"] in EMERGENCY_SQUAWKS
    if is_emergency:
        bottom_content = "%s: %s" % (aircraft["squawk"], EMERGENCY_SQUAWKS[aircraft["squawk"]])
        bottom_color = "#FF0000"
    elif route != None:
        bottom_content = route.replace("-", "  >  ")
        bottom_color = "#FFFFFF"
    else:
        compass = track_to_compass(aircraft.get("track", 0))
        bottom_content = "HDG: %s" % compass
        bottom_color = "#AAAAAA"

    # hexdb fields (fall back gracefully if lookup failed)
    registration = hexdb_data.get("Registration", "N/A") if hexdb_data else "N/A"
    type_desc = hexdb_data.get("Type", "Unknown Type") if hexdb_data else "Unknown Type"
    icao_type = hexdb_data.get("ICAOTypeCode", "ZZZC") if hexdb_data else "ZZZC"
    owner = hexdb_data.get("RegisteredOwners", "Unknown Owner") if hexdb_data else "Unknown Owner"

    # Aircraft silhouette icon
    icon_alt = int(alt_baro) if alt_baro != "ground" else 0
    icon_color = get_altitude_icon_color(icon_alt)

    if dummy_mode != "none":
        icon_response = http.get(
            "https://tar1090tidbyt.azurewebsites.net/api/aircraft_icon" +
            "?category=%s&typeDesignator=%s&typeDescription=%s&addrtype=%s&color=%s" % (
                aircraft["category"], icao_type, type_desc.replace(" ", "%20"), aircraft.get("type", "adsb_icao"), icon_color
            ),
            ttl_seconds = 86400,
        )
        aircraft_icon = icon_response.body() if icon_response.status_code == 200 else BLANK_ASSET.readall()
    else:
        aircraft_icon = get_aircraft_icon(
            aircraft["category"],
            icao_type,
            type_desc,
            aircraft.get("type", None),
            icon_color,
        )

    # ── Frame 1 ───────────────────────────────────────────────────────────────
    #
    #  ┌──────────────────────────────────────────────────────────────┐
    #  │  [NJA logo]  │  FL350                                        │
    #  │  or FLIGHT   │  Sp:450    (30px left | 34px right)          │
    #  │  EJA123      │  Dst:8                                        │
    #  ├──────────────────────────────────────────────────────────────┤
    #  │  KLAS>KTEB  or  HDG: NW  or  7700: EMERGENCY (red)          │
    #  └──────────────────────────────────────────────────────────────┘

    if is_nja:
        left_children = [
            render.Image(src = NJA_TAIL.readall(), height = 10),
            render.Text(content = callsign, font = "tom-thumb"),
        ]
    else:
        left_children = [
            render.Text(content = "FLIGHT", font = "tom-thumb"),
            render.Text(content = callsign, font = "tom-thumb"),
        ]

    right_children = [
        render.Text(content = alt_display, font = "tom-thumb"),
        render.Text(content = spd_display, font = "tom-thumb"),
    ]
    if dst_display != "":
        right_children.append(render.Text(content = dst_display, font = "tom-thumb"))

    frame1 = render.Column(
        children = [
            render.Row(
                children = [
                    render.Box(
                        width = 30,
                        height = 26,
                        child = render.Column(
                            children = left_children,
                            cross_align = "center",
                            main_align = "center",
                        ),
                    ),
                    render.Box(
                        width = 34,
                        height = 26,
                        child = render.Column(
                            children = right_children,
                            cross_align = "center",
                            main_align = "center",
                        ),
                    ),
                ],
            ),
            # Bottom bar: route / heading / emergency — centered
            render.Box(
                width = 64,
                height = 6,
                child = render.Column(
                    children = [
                        render.Text(
                            content = bottom_content,
                            font = "tom-thumb",
                            color = bottom_color,
                        ),
                    ],
                    main_align = "center",
                    cross_align = "center",
                    expanded = True,
                ),
            ),
        ],
        cross_align = "center",
    )

    # ── Frame 2 ───────────────────────────────────────────────────────────────
    #
    #  ┌──────────────────────────────────────────────────────────────┐
    #  │  [icon]  │  N123EJ                                           │
    #  │  18px    │  Citation Longitude  (tom-thumb wrapped)          │
    #  │          │  ← NetJets Aviation Inc (marquee) →              │
    #  └──────────────────────────────────────────────────────────────┘

    frame2 = render.Row(
        children = [
            render.Box(
                width = 18,
                height = 32,
                child = render.Image(src = aircraft_icon, height = 18, width = 18),
            ),
            render.Box(
                width = 46,
                height = 32,
                child = render.Column(
                    children = [
                        render.Text(
                            content = registration,
                            font = "tom-thumb",
                        ),
                        render.WrappedText(
                            content = type_desc,
                            font = "tom-thumb",
                            width = 46,
                            align = "center",
                        ),
                        render.Marquee(
                            width = 46,
                            child = render.Text(
                                content = owner,
                                font = "tom-thumb",
                            ),
                            scroll_direction = "horizontal",
                            offset_start = 5,
                        ),
                    ],
                    cross_align = "center",
                    main_align = "center",
                ),
            ),
        ],
        expanded = True,
    )

    return render.Root(
        delay = 5000,
        child = render.Animation(
            children = [frame1, frame2],
        ),
    )

# ── Schema ────────────────────────────────────────────────────────────────────

def get_schema():
    unit_options = [
        schema.Option(display = "Aeronautical (kts / ft / nm)", value = "a"),
        schema.Option(display = "Imperial (mph / ft / mi)", value = "i"),
        schema.Option(display = "Metric (km/h / m / km)", value = "m"),
    ]

    dummy_options = [
        schema.Option(display = "None (Use Live Data)", value = "none"),
        schema.Option(display = "Dummy 1 — NetJets C700 @ FL350", value = "aircraft1"),
        schema.Option(display = "Dummy 2 — Army UH-60 (Emergency)", value = "aircraft2"),
    ]

    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "tar1090url",
                name = "tar1090 URL",
                desc = "Your self-hosted, publicly available tar1090 instance.",
                icon = "plane",
            ),
            schema.Dropdown(
                id = "units",
                name = "Units",
                desc = "Unit system for speed, altitude, and distance.",
                icon = "ruler",
                default = unit_options[0].value,
                options = unit_options,
            ),
            schema.Dropdown(
                id = "priority_distance",
                name = "NetJets Priority Distance",
                desc = "Show EJA/EJM flights first if within this range (nautical miles).",
                icon = "star",
                default = "10",
                options = [
                    schema.Option(display = "5 NM", value = "5"),
                    schema.Option(display = "10 NM", value = "10"),
                    schema.Option(display = "15 NM", value = "15"),
                    schema.Option(display = "20 NM", value = "20"),
                ],
            ),
            schema.Toggle(
                id = "use_custom_coords",
                name = "Use Custom Location",
                desc = "Calculate distance from custom coordinates instead of tar1090 receiver location.",
                icon = "locationDot",
                default = False,
            ),
            schema.Text(
                id = "custom_lat",
                name = "Custom Latitude",
                desc = "Decimal degrees, e.g. 40.7128 for New York.",
                icon = "mapPin",
                default = "0.0",
            ),
            schema.Text(
                id = "custom_lon",
                name = "Custom Longitude",
                desc = "Decimal degrees, e.g. -74.0060 for New York.",
                icon = "mapPin",
                default = "0.0",
            ),
            schema.Dropdown(
                id = "dummy_mode",
                name = "Test Mode",
                desc = "Use dummy aircraft data for testing instead of live data.",
                icon = "vial",
                default = dummy_options[0].value,
                options = dummy_options,
            ),
        ],
    )
