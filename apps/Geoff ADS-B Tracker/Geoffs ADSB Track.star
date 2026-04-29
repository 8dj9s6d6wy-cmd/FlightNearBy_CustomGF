"""
Applet: PiAware ADS-B
Summary: ADS-B From Your PiAware Station
Description: Live ADS-B flight information using your PiAware feeder and FlightAware AeroAPI.
Author: Geoff Finnegan
"""

load("http.star", "http")
load("images/blank.png", BLANK_ASSET = "file")
load("images/error.gif", ERROR_ASSET = "file")
load("re.star", "re")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")
load("images/NJALogo.png", NJA_TAIL = "file")

ERROR_ICON = ERROR_ASSET.readall()

PIAWARE_URL_DEFAULT = "SET YOUR URL"
AEROAPI_BASE_URL = "https://aeroapi.flightaware.com/aeroapi"

DEFAULT_CONVERSION_UNITS = "a"
DISPLAY_TIMEZONE = "America/New_York"

FEET_TO_METERS_RATIO = 0.3048
NMI_TO_KM_RATIO = 1.8520
NMI_TO_MI_RATIO = 1.1508

EMERGENCY_SQUAWKS = {
    "7500": "HIJACK",
    "7600": "RADIO FAIL",
    "7700": "EMERGENCY",
}

COMPASS_DIRS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

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

# ── AeroAPI helpers ───────────────────────────────────────────────────────────

def lookup_aeroapi_flight(callsign, api_key):
    """
    Fetch the most recent flight record for a callsign from AeroAPI.
    Returns the first flight dict or None.
    Cached 5 minutes to avoid burning quota.
    """
    if len(callsign) == 0 or api_key == "" or api_key == None:
        return None

    url = "%s/flights/%s" % (AEROAPI_BASE_URL, callsign)
    headers = {"x-apikey": api_key}
    response = http.get(url, headers = headers, ttl_seconds = 300)

    if response.status_code != 200:
        print("AeroAPI flight lookup failed for %s: %d" % (callsign, response.status_code))
        return None

    data = response.json()
    flights = data.get("flights", [])
    if len(flights) == 0:
        return None

    # Return the most recent flight (first in list)
    return flights[0]

def lookup_hexdb_aircraft(icao):
    """
    Fetch aircraft record from hexdb.io by ICAO hex.
    Used as fallback when no callsign or AeroAPI miss.
    Cached 24 hours.
    """
    url = "https://hexdb.io/api/v1/aircraft/%s" % icao.upper()
    response = http.get(url, ttl_seconds = 86400)
    if response.status_code != 200:
        return None
    data = response.json()
    if "error" in data:
        return None
    return data

# ── Time helpers ──────────────────────────────────────────────────────────────

def parse_iso_time(iso_str):
    """
    Parse an ISO 8601 timestamp string returned by AeroAPI.
    AeroAPI returns strings like: '2024-04-19T14:30:00Z'
    Returns a time.Time object or None.
    """
    if iso_str == None or iso_str == "":
        return None
    t = time.parse_time(iso_str, format = "2006-01-02T15:04:05Z", location = "UTC")
    return t

def format_time_remaining(estimated_arrival_str):
    """
    Given an ISO arrival time string, return a human-readable time remaining string.
    e.g. '1h 30m' or '45m' or None if can't compute.
    """
    if estimated_arrival_str == None or estimated_arrival_str == "":
        return None

    arrival = parse_iso_time(estimated_arrival_str)
    if arrival == None:
        return None

    now = time.now()
    diff = arrival - now

    # Duration.seconds gives total seconds as integer
    total_seconds = diff.seconds
    total_minutes = int(total_seconds / 60)

    if total_minutes <= 0:
        return None

    hours = int(total_minutes / 60)
    minutes = total_minutes % 60

    if hours > 0:
        return "%dh %dm" % (hours, minutes)
    else:
        return "%dm" % minutes

def build_bottom_bar(aircraft, aero_flight, is_emergency):
    """
    Build the bottom bar content and color for Frame 1.
    Priority: emergency > flight route+time > heading fallback
    """
    # Emergency always wins
    if is_emergency:
        squawk = aircraft["squawk"]
        return (
            "%s: %s" % (squawk, EMERGENCY_SQUAWKS[squawk]),
            "#FF0000",
        )

    # Try to build route string from AeroAPI data
    if aero_flight != None:
        origin = aero_flight.get("origin", None)
        dest = aero_flight.get("destination", None)
        status = aero_flight.get("status", "")

        origin_code = None
        dest_code = None

        if origin != None:
            origin_code = origin.get("code_icao", None)
            if origin_code == None:
                origin_code = origin.get("code", None)
        if dest != None:
            dest_code = dest.get("code_icao", None)
            if dest_code == None:
                dest_code = dest.get("code", None)

        if origin_code != None and dest_code != None:
            # Determine display based on flight status
            status_lower = status.lower()

            if "land" in status_lower:
                return ("%s > %s  LANDED" % (origin_code, dest_code), "#AAAAAA")

            elif "scheduled" in status_lower or "filed" in status_lower:
                return ("%s > %s" % (origin_code, dest_code), "#FFFFFF")

            else:
                # En route — try to show time remaining
                estimated_arrival = aero_flight.get("estimated_arrival_time", None)
                if estimated_arrival == None:
                    estimated_arrival = aero_flight.get("scheduled_arrival_time", None)

                time_remaining = format_time_remaining(estimated_arrival)

                if time_remaining != None:
                    content = "%s --- %s --- %s" % (origin_code, time_remaining, dest_code)
                else:
                    content = "%s > %s" % (origin_code, dest_code)

                return (content, "#FFFFFF")

    # Fallback: compass heading from tar1090 track
    compass = track_to_compass(aircraft.get("track", 0))
    return ("HDG: %s" % compass, "#AAAAAA")

# ── Aircraft classification helpers ──────────────────────────────────────────

def is_military_aircraft(owner):
    """Detect military aircraft by checking owner string for known keywords."""
    if owner == None:
        return False
    owner_lower = owner.lower()
    for kw in MIL_KEYWORDS:
        if kw in owner_lower:
            return True
    return False

def track_to_compass(track):
    """Convert a track/heading in degrees to an 8-point compass string."""
    idx = int((track + 22.5) / 45) % 8
    return COMPASS_DIRS[idx]

def get_alt_display(conversion_unit, alt_baro):
    """Return altitude as FL notation or meters for metric."""
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
            category,
            designator,
            description.replace(" ", "%20"),
            addrtype,
            color,
        )
    )
    response = http.get(url, ttl_seconds = 86400)
    if response.status_code != 200:
        return None
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

# ── Haversine distance ────────────────────────────────────────────────────────

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
        key = lambda aircraft: aircraft_distance_sort(
            aircraft, priority_distance, use_custom_coords, custom_lat, custom_lon
        ),
    )
    for aircraft in aircrafts:
        if "category" in aircraft and "alt_baro" in aircraft:
            return aircraft
    return None

def get_callsign(aircraft):
    if "flight" in aircraft:
        return aircraft["flight"].strip()
    return ""

# ── Type description word splitter ───────────────────────────────────────────

def split_type_desc(type_desc):
    """
    Split a type description string into two lines for tom-thumb font at 46px.
    tom-thumb: 4px char + 1px spacing = 5px per char, so 46px fits ~8 chars.
    Using 7 as safe limit to avoid any clipping.
    Hard-truncates words longer than the limit.
    Returns (line1, line2).
    """
    MAX_CHARS = 7
    words = type_desc.split(" ")
    line1 = ""
    line2 = ""
    for word in words:
        # Hard-truncate any single word that exceeds the limit
        if len(word) > MAX_CHARS:
            word = word[:MAX_CHARS]
        if len(line1) == 0:
            line1 = word
        elif len(line1) + 1 + len(word) <= MAX_CHARS:
            line1 = line1 + " " + word
        elif len(line2) == 0:
            line2 = word
        elif len(line2) + 1 + len(word) <= MAX_CHARS:
            line2 = line2 + " " + word
    return (line1, line2)

# ── Dummy data ────────────────────────────────────────────────────────────────

def generate_dummy_aircraft():
    return [
        {
            "hex": "a835af",
            "type": "adsb_icao",
            "flight": "SWA2269 ",
            "alt_baro": 38000,
            "gs": 416.0,
            "track": 45.0,
            "squawk": "2175",
            "emergency": "none",
            "category": "A3",
            "lat": 40.0,
            "lon": -83.0,
            "r_dst": 3.2,
            "r_dir": 90.0,
            "messages": 600,
            "seen": 0.2,
        },
        {
            "hex": "a12345",
            "type": "adsb_icao",
            "flight": "EJA456  ",
            "alt_baro": 41000,
            "gs": 460.0,
            "track": 90.0,
            "squawk": "4521",
            "emergency": "none",
            "category": "A2",
            "lat": 40.1,
            "lon": -83.1,
            "r_dst": 7.5,
            "r_dir": 180.0,
            "messages": 400,
            "seen": 0.4,
        },
        {
            "hex": "AE5D9B",
            "type": "adsb_icao",
            "flight": "ARMY01  ",
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

def generate_dummy_aero_flight():
    return {
        "ident": "SWA2269",
        "status": "En Route / On Time",
        "origin": {
            "code": "HOU",
            "code_icao": "KHOU",
            "name": "William P Hobby Airport",
        },
        "destination": {
            "code": "BNA",
            "code_icao": "KBNA",
            "name": "Nashville International Airport",
        },
        "operator": "Southwest Airlines",
        "aircraft_type": "B737",
        "scheduled_departure_time": "2024-04-19T18:00:00Z",
        "scheduled_arrival_time": "2024-04-19T21:30:00Z",
        "estimated_arrival_time": "2024-04-19T21:25:00Z",
        "actual_departure_time": "2024-04-19T18:05:00Z",
    }

def generate_dummy_hexdb():
    return {
        "Registration": "N8731A",
        "ICAOTypeCode": "B738",
        "Manufacturer": "Boeing",
        "Type": "737-800",
        "RegisteredOwners": "Southwest Airlines",
        "ModeS": "A835AF",
    }

# ── Error display ─────────────────────────────────────────────────────────────

def show_error(message):
    return render.Root(
        child = render.Column(
            children = [
                render.Image(src = ERROR_ICON),
                render.Marquee(
                    width = 64,
                    child = render.Text("!!! " + message + " !!!"),
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
    piaware_url = config.str("piaware_url", PIAWARE_URL_DEFAULT)
    api_key = config.str("aeroapi_key", "")
    dummy_mode = config.str("dummy_mode", "none")
    priority_distance = int(config.str("priority_distance", "10"))
    use_custom_coords = config.bool("use_custom_coords", False)
    custom_lat = float(config.str("custom_lat", "0.0"))
    custom_lon = float(config.str("custom_lon", "0.0"))
    conversion_unit = config.str("units", DEFAULT_CONVERSION_UNITS)

    if use_custom_coords and custom_lat == 0.0 and custom_lon == 0.0:
        use_custom_coords = False

    aero_flight = None
    hexdb_data = None

    # ── Data acquisition ──────────────────────────────────────────────────────

    if dummy_mode != "none":
        dummy_list = generate_dummy_aircraft()

        if dummy_mode == "commercial":
            aircraft = dummy_list[0]
            aero_flight = generate_dummy_aero_flight()
            hexdb_data = generate_dummy_hexdb()

        elif dummy_mode == "netjets":
            aircraft = dummy_list[1]
            aero_flight = None
            hexdb_data = {
                "Registration": "N123EJ",
                "ICAOTypeCode": "C700",
                "Manufacturer": "Cessna",
                "Type": "Citation Longitude",
                "RegisteredOwners": "NetJets Aviation Inc",
                "ModeS": "A12345",
            }

        elif dummy_mode == "military":
            aircraft = dummy_list[2]
            aero_flight = None
            hexdb_data = {
                "Registration": "16-20913",
                "ICAOTypeCode": "H60",
                "Manufacturer": "Sikorsky",
                "Type": "UH-60M Blackhawk",
                "RegisteredOwners": "United States Army",
                "ModeS": "AE5D9B",
            }

        else:
            return show_error("INVALID DUMMY MODE")

    else:
        # Live mode
        if piaware_url == PIAWARE_URL_DEFAULT or not validate_url(piaware_url):
            return show_error("INVALID PIAWARE URL")

        response = http.get(piaware_url + "/data/aircraft.json")
        if response.status_code != 200:
            return show_error("CAN'T REACH PIAWARE @ " + piaware_url)

        aircrafts = response.json().get("aircraft", [])
        if len(aircrafts) == 0:
            return show_error("NO AIRCRAFT IN RANGE")

        aircraft = find_nearest_aircraft(
            aircrafts, priority_distance, use_custom_coords, custom_lat, custom_lon
        )
        if aircraft == None:
            return show_error("NO AIRCRAFT WITH POSITION DATA")

        # AeroAPI lookup if we have a callsign and key
        callsign_raw = get_callsign(aircraft)
        if len(callsign_raw) > 0 and len(api_key) > 0:
            aero_flight = lookup_aeroapi_flight(callsign_raw, api_key)

        # hexdb fallback for aircraft details (always try)
        hexdb_data = lookup_hexdb_aircraft(aircraft["hex"])

    # ── Resolve display data ──────────────────────────────────────────────────

    callsign = get_callsign(aircraft).upper()
    if len(callsign) == 0:
        callsign = aircraft.get("hex", "------").upper()

    is_nja = callsign.startswith("EJA") or callsign.startswith("EJM")
    is_emergency = "squawk" in aircraft and aircraft["squawk"] in EMERGENCY_SQUAWKS

    alt_baro = aircraft.get("alt_baro", 0)
    alt_display = get_alt_display(conversion_unit, alt_baro)

    spd = int(convert_spd(conversion_unit, aircraft.get("gs", 0)))
    spd_display = "Sp:%d" % spd

    if use_custom_coords and "lat" in aircraft and "lon" in aircraft:
        dst_raw = calculate_distance(custom_lat, custom_lon, aircraft["lat"], aircraft["lon"])
        dst_display = "Dst:%d" % int(convert_dst(conversion_unit, dst_raw))
    elif "r_dst" in aircraft:
        dst_display = "Dst:%d" % int(convert_dst(conversion_unit, aircraft["r_dst"]))
    else:
        dst_display = ""

    # Bottom bar
    (bottom_content, bottom_color) = build_bottom_bar(aircraft, aero_flight, is_emergency)

    # Aircraft details — prefer AeroAPI operator, fall back to hexdb
    registration = "N/A"
    type_desc = "Unknown Type"
    icao_type = "ZZZC"
    owner = "Unknown"

    if hexdb_data != None:
        registration = hexdb_data.get("Registration", "N/A")
        type_desc = hexdb_data.get("Type", "Unknown Type")
        icao_type = hexdb_data.get("ICAOTypeCode", "ZZZC")
        owner = hexdb_data.get("RegisteredOwners", "Unknown")

    # AeroAPI operator overrides hexdb owner if available
    if aero_flight != None:
        aero_operator = aero_flight.get("operator", None)
        if aero_operator != None and len(aero_operator) > 0:
            owner = aero_operator
        # AeroAPI aircraft_type can fill in icao_type if hexdb missed
        if icao_type == "ZZZC":
            aero_type = aero_flight.get("aircraft_type", None)
            if aero_type != None:
                icao_type = aero_type

    # ── Aircraft icon ─────────────────────────────────────────────────────────

    icon_alt = int(alt_baro) if alt_baro != "ground" else 0
    icon_color = get_altitude_icon_color(icon_alt)
    addrtype = aircraft.get("type", "adsb_icao")

    aircraft_icon = get_aircraft_icon(aircraft["category"], icao_type, type_desc, addrtype, icon_color)
    if aircraft_icon == None:
        aircraft_icon = BLANK_ASSET.readall()

    # ── Frame 1 ───────────────────────────────────────────────────────────────
    #
    #  ┌──────────────────────────────────────────────────────────────┐
    #  │  FLIGHT   FL380                                              │
    #  │  SWA2269  Sp:416                                             │
    #  │           Dst:3                                              │
    #  ├──────────────────────────────────────────────────────────────┤
    #  │  ← KHOU --- 1h 30m --- KBNA (marquee, centered) →          │
    #  └──────────────────────────────────────────────────────────────┘

    if is_nja:
        left_col = render.Column(
            children = [
                render.Image(src = NJA_TAIL.readall(), height = 10),
                render.Text(content = callsign, font = "tom-thumb"),
            ],
        )
    else:
        left_col = render.Column(
            children = [
                render.Text(content = "FLIGHT", font = "tom-thumb"),
                render.Box(width = 1, height = 2),
                render.Text(content = callsign, font = "tom-thumb"),
            ],
        )

    right_col = render.Column(
        children = [
            render.Text(content = alt_display, font = "tom-thumb"),
            render.Text(content = spd_display, font = "tom-thumb"),
            render.Text(content = dst_display, font = "tom-thumb"),
        ],
    )

    frame1 = render.Column(
        children = [
            render.Padding(
                pad = (2, 2, 2, 0),
                child = render.Row(
                    children = [
                        render.Padding(
                            pad = (0, 0, 4, 0),
                            child = left_col,
                        ),
                        right_col,
                    ],
                ),
            ),
            # Bottom bar — centered marquee
            render.Column(
                children = [
                    render.Marquee(
                        width = 64,
                        child = render.Text(
                            content = bottom_content,
                            font = "tom-thumb",
                            color = bottom_color,
                        ),
                        scroll_direction = "horizontal",
                        offset_start = 64,
                    ),
                ],
                cross_align = "center",
                expanded = True,
            ),
        ],
    )

    # ── Frame 2 ───────────────────────────────────────────────────────────────
    #
    #  ┌──────────────────────────────────────────────────────────────┐
    #  │  [icon 12x12]  N220RA  King Air                             │
    #  │                ← RAN (owner marquee) →                      │
    #  └──────────────────────────────────────────────────────────────┘

    # Combine registration + type onto one scrolling line if they fit,
    # otherwise marquee the full string
    reg_type = registration + "  " + type_desc

    frame2 = render.Column(
        children = [
            render.Padding(
                pad = (0, 4, 0, 0),
                child = render.Row(
                    children = [
                        render.Padding(
                            pad = (0, 0, 4, 0),
                            child = render.Image(
                                src = aircraft_icon,
                                height = 12,
                                width = 12,
                            ),
                        ),
                        render.Column(
                            children = [
                                render.Marquee(
                                    width = 48,
                                    child = render.Text(
                                        content = reg_type,
                                        font = "tom-thumb",
                                    ),
                                    scroll_direction = "horizontal",
                                    offset_start = 48,
                                ),
                            ],
                        ),
                    ],
                ),
            ),
            render.Padding(
                pad = (0, 4, 0, 0),
                child = render.Marquee(
                    width = 64,
                    child = render.Text(
                        content = owner,
                        font = "tom-thumb",
                        color = "#AAAAAA",
                    ),
                    scroll_direction = "horizontal",
                    offset_start = 64,
                ),
            ),
        ],
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
        schema.Option(display = "Commercial — SWA2269 @ FL380", value = "commercial"),
        schema.Option(display = "NetJets — EJA456 @ FL410", value = "netjets"),
        schema.Option(display = "Military — Army UH-60 (Emergency)", value = "military"),
    ]

    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "piaware_url",
                name = "PiAware URL",
                desc = "URL of your PiAware/tar1090 instance, e.g. http://192.168.1.100",
                icon = "plane",
            ),
            schema.Text(
                id = "aeroapi_key",
                name = "AeroAPI Key",
                desc = "Your FlightAware AeroAPI key for flight details.",
                icon = "key",
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
                desc = "Calculate distance from custom coordinates instead of receiver location.",
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
                desc = "Use dummy data for testing instead of live data.",
                icon = "vial",
                default = dummy_options[0].value,
                options = dummy_options,
            ),
        ],
    )
