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

FEET_TO_METERS_RATIO = 0.3048
NMI_TO_KM_RATIO = 1.8520
NMI_TO_MI_RATIO = 1.1508

EMERGENCY_SQUAWKS = {
    "7500": "HIJACK",
    "7600": "RADIO FAIL",
    "7700": "EMERGENCY",
}

COMPASS_DIRS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

# ── AeroAPI helpers ───────────────────────────────────────────────────────────

def lookup_aeroapi_flight(callsign, api_key):
    if len(callsign) == 0 or api_key == None or api_key == "":
        return None
    url = "%s/flights/%s" % (AEROAPI_BASE_URL, callsign.upper())
    headers = {"x-apikey": api_key}
    response = http.get(url, headers = headers, ttl_seconds = 300)
    if response.status_code != 200:
        print("AeroAPI flight lookup failed for %s: %d" % (callsign, response.status_code))
        return None
    data = response.json()
    flights = data.get("flights", [])
    if len(flights) == 0:
        return None
    # Prefer en route flight
    for flight in flights:
        progress = flight.get("progress_percent", 0)
        if progress != None and progress > 0 and progress < 100:
            return flight
    return flights[0]

def lookup_aeroapi_operator(operator_icao, api_key):
    if operator_icao == None or operator_icao == "" or api_key == None or api_key == "":
        return None
    url = "%s/operators/%s" % (AEROAPI_BASE_URL, operator_icao)
    headers = {"x-apikey": api_key}
    response = http.get(url, headers = headers, ttl_seconds = 86400)
    if response.status_code != 200:
        print("AeroAPI operator lookup failed for %s: %d" % (operator_icao, response.status_code))
        return None
    data = response.json()
    return data.get("shortname", None)

# ── Flight data helpers ───────────────────────────────────────────────────────

def get_display_ident(flight):
    codeshares = flight.get("codeshares", [])
    if codeshares != None and len(codeshares) > 0:
        return codeshares[0]
    ident_icao = flight.get("ident_icao", None)
    if ident_icao != None and ident_icao != "":
        return ident_icao
    return flight.get("ident", "")

def get_codeshare_operator_icao(flight):
    """If the flight has a codeshare, extract the 3-letter ICAO prefix from the
    first codeshare ident (e.g. 'UAX4821' -> 'UAX') to use for the marketing
    carrier operator lookup instead of the regional operator_icao."""
    codeshares = flight.get("codeshares", [])
    if codeshares == None or len(codeshares) == 0:
        return None
    if type(codeshares) == "string":
        return None
    cs = codeshares[0].strip()
    # ICAO airline codes are 3 letters; strip trailing digits to get the prefix
    prefix = ""
    for ch in cs:
        if ch >= "A" and ch <= "Z" or ch >= "a" and ch <= "z":
            prefix = prefix + ch
        else:
            break
    if len(prefix) >= 2:
        return prefix.upper()
    return None

def parse_iso_time(iso_str):
    if iso_str == None or iso_str == "":
        return None
    return time.parse_time(iso_str, format = "2006-01-02T15:04:05Z", location = "UTC")

def format_time_remaining(estimated_on_str):
    if estimated_on_str == None or estimated_on_str == "":
        return None
    arrival = parse_iso_time(estimated_on_str)
    if arrival == None:
        return None
    now = time.now()
    diff = arrival - now
    total_seconds = diff.seconds
    total_minutes = int(total_seconds / 60)
    if total_minutes <= 0:
        return None
    hours = int(total_minutes / 60)
    minutes = total_minutes % 60
    if hours > 0:
        return "%dh %dm" % (hours, minutes)
    return "%dm" % minutes

def build_bottom_bar(aircraft, aero_flight, is_emergency):
    if is_emergency:
        squawk = aircraft["squawk"]
        return ("%s: %s" % (squawk, EMERGENCY_SQUAWKS[squawk]), "#FF0000")

    if aero_flight != None:
        origin = aero_flight.get("origin", None)
        dest = aero_flight.get("destination", None)
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
            progress = aero_flight.get("progress_percent", 0)
            cancelled = aero_flight.get("cancelled", False)
            diverted = aero_flight.get("diverted", False)

            if cancelled:
                return ("%s > %s CNCLD" % (origin_code, dest_code), "#FF6600")
            elif diverted:
                return ("%s > %s DIVRT" % (origin_code, dest_code), "#FF6600")
            elif progress != None and progress >= 100:
                return ("%s > %s ARVD" % (origin_code, dest_code), "#AAAAAA")
            elif progress != None and progress > 0:
                time_remaining = format_time_remaining(aero_flight.get("estimated_on", None))
                if time_remaining != None:
                    return ("%s --- %s --- %s" % (origin_code, time_remaining, dest_code), "#FFFFFF")
                return ("%s > %s" % (origin_code, dest_code), "#FFFFFF")
            else:
                return ("%s > %s" % (origin_code, dest_code), "#FFFFFF")

    compass = track_to_compass(aircraft.get("track", 0))
    return ("HDG: %s" % compass, "#AAAAAA")

# ── Aircraft helpers ──────────────────────────────────────────────────────────

def track_to_compass(track):
    idx = int((track + 22.5) / 45) % 8
    return COMPASS_DIRS[idx]

def get_alt_display(conversion_unit, alt_baro):
    if alt_baro == "ground":
        return "GND"
    alt = int(alt_baro)
    if alt <= 0:
        return "GND"
    if conversion_unit == "m":
        return "%dm" % int(alt * FEET_TO_METERS_RATIO)
    return "FL%d" % int(alt / 100)

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
        cs = aircraft["flight"].strip().upper()
        if (cs.startswith("EJA") or cs.startswith("EJM")) and distance <= priority_distance:
            is_priority = True
    return (not is_emergency, not is_priority, distance)

def find_nearest_aircraft(aircrafts, priority_distance, use_custom_coords, custom_lat, custom_lon):
    aircrafts = sorted(
        aircrafts,
        key = lambda a: aircraft_distance_sort(
            a, priority_distance, use_custom_coords, custom_lat, custom_lon
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
        },
        {
            "hex": "a12345",
            "type": "adsb_icao",
            "flight": "EJA468  ",
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
        },
    ]

def generate_dummy_aero_commercial():
    return {
        "ident": "SWA2269",
        "ident_icao": "SWA2269",
        "registration": "N8731A",
        "operator": "SWA",
        "operator_icao": "SWA",
        "aircraft_type": "B737",
        "codeshares": [],
        "progress_percent": 55,
        "cancelled": False,
        "diverted": False,
        "status": "En Route",
        "origin": {"code": "KHOU", "code_icao": "KHOU"},
        "destination": {"code": "KBNA", "code_icao": "KBNA"},
        "estimated_on": "2026-05-03T23:30:00Z",
    }

def generate_dummy_aero_netjets():
    return {
        "ident": "EJA468",
        "ident_icao": "EJA468",
        "registration": "N468QS",
        "operator": "EJA",
        "operator_icao": "EJA",
        "aircraft_type": "E55P",
        "codeshares": [],
        "progress_percent": 68,
        "cancelled": False,
        "diverted": False,
        "status": "En Route",
        "origin": {"code": "KMMU", "code_icao": "KMMU"},
        "destination": {"code": "KSDF", "code_icao": "KSDF"},
        "estimated_on": "2026-05-03T23:45:00Z",
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
    operator_short = None

    # ── Data acquisition ──────────────────────────────────────────────────────

    if dummy_mode != "none":
        dummy_list = generate_dummy_aircraft()

        if dummy_mode == "commercial":
            aircraft = dummy_list[0]
            aero_flight = generate_dummy_aero_commercial()
            operator_short = "Southwest"

        elif dummy_mode == "netjets":
            aircraft = dummy_list[1]
            aero_flight = generate_dummy_aero_netjets()
            operator_short = "NetJets Aviation"

        elif dummy_mode == "military":
            aircraft = dummy_list[2]
            aero_flight = None
            operator_short = None

        else:
            return show_error("INVALID DUMMY MODE")

    else:
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

        callsign_raw = get_callsign(aircraft)
        if len(callsign_raw) > 0 and len(api_key) > 0:
            aero_flight = lookup_aeroapi_flight(callsign_raw, api_key)

        if aero_flight != None and len(api_key) > 0:
            # If a codeshare exists, look up the marketing carrier (e.g. UAX)
            # rather than the regional operator flying the metal (e.g. SKW)
            codeshare_icao = get_codeshare_operator_icao(aero_flight)
            if codeshare_icao != None:
                operator_short = lookup_aeroapi_operator(codeshare_icao, api_key)
            if operator_short == None:
                operator_icao = aero_flight.get("operator_icao", None)
                if operator_icao != None:
                    operator_short = lookup_aeroapi_operator(operator_icao, api_key)
            if operator_short == None:
                operator_short = aero_flight.get("operator_icao", None)

    # ── Resolve display values ────────────────────────────────────────────────

    if aero_flight != None:
        display_callsign = get_display_ident(aero_flight).upper()
    else:
        display_callsign = get_callsign(aircraft).upper()
    if len(display_callsign) == 0:
        display_callsign = aircraft.get("hex", "------").upper()

    is_nja = display_callsign.startswith("EJA") or display_callsign.startswith("EJM")
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

    (bottom_content, bottom_color) = build_bottom_bar(aircraft, aero_flight, is_emergency)

    # Registration
    registration = None
    if aero_flight != None:
        registration = aero_flight.get("registration", None)
    if registration == None or registration == "":
        registration = aircraft.get("hex", "------").upper()

    # Aircraft type
    aircraft_type = "Unknown"
    if aero_flight != None:
        aircraft_type = aero_flight.get("aircraft_type", "Unknown")
        if aircraft_type == None:
            aircraft_type = "Unknown"

    # Operator display
    if operator_short != None and operator_short != "":
        owner_display = operator_short
    elif aero_flight != None:
        fallback = aero_flight.get("operator_icao", None)
        owner_display = fallback if fallback != None else "Unknown"
    else:
        owner_display = "Unknown"

    # ── Aircraft icon ─────────────────────────────────────────────────────────

    icon_alt = int(alt_baro) if alt_baro != "ground" else 0
    icon_color = get_altitude_icon_color(icon_alt)
    addrtype = aircraft.get("type", "adsb_icao")

    aircraft_icon = get_aircraft_icon(
        aircraft["category"], aircraft_type, aircraft_type, addrtype, icon_color
    )
    if aircraft_icon == None:
        aircraft_icon = BLANK_ASSET.readall()

    # ── Frame 1 ───────────────────────────────────────────────────────────────

    if is_nja:
        label_widget = render.Image(src = NJA_TAIL.readall(), height = 10)
    else:
        label_widget = render.Text(content = "Flight", font = "tom-thumb")

    frame1 = render.Stack(
        children = [
            render.Box(width = 64, height = 32),
                render.Box(width = 30, height = 26,
                    # Left: label + callsign
                    child = render.Column(
                        children = [
                            render.Box(width = 1, height = 3),
                            label_widget,
                            render.Box(width = 1, height = 2),
                            render.Text(content = display_callsign, font = "tom-thumb"),
                        ],
                        cross_align = "center",
                        main_align = "center",
                    ),
                ),
            # Right: alt, speed, dst
            render.Row(
                children = [
                    render.Box(width = 34, height = 1),
                    render.Box(width = 34, height = 26,
                        child = render.Column(
                            children = [
                                render.Box(width = 1, height = 3),
                                render.Text(content = alt_display, font = "tom-thumb"),
                                render.Box(width = 1, height = 2),
                                render.Text(content = spd_display, font = "tom-thumb"),
                                render.Box(width = 1, height = 2),
                                render.Text(content = dst_display, font = "tom-thumb"),
                            ],
                            cross_align = "center",
                            main_align = "center",
                        ),
                    ),
                ],
            ),

            # Bottom bar pinned to row 26
            render.Column(
                children = [
                    render.Box(width = 64, height = 26),
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
                            cross_align = "center",
                            expanded = True,
                        ) if len(bottom_content) <= 14 else render.Marquee(
                            width = 64,
                            child = render.Text(
                                content = bottom_content,
                                font = "tom-thumb",
                                color = bottom_color,
                            ),
                            scroll_direction = "horizontal",
                            offset_start = 64,
                        ),
                    ),
                ],
            ),
        ],
    )

    # ── Frame 2 ───────────────────────────────────────────────────────────────

    frame2 = render.Row(
        expanded = True,
        children = [
            render.Box(
                width = 21,
                height = 32,
                child = render.Image(src = aircraft_icon, height = 18, width = 18),
            ),
            render.Box(
                width = 43,
                height = 32,
                child = render.Column(
                    expanded = True,
                    main_align = "center",
                    cross_align = "center",
                    children = [
                        render.Text(content = registration, font = "tom-thumb"),
                        render.Text(content = aircraft_type, font = "tom-thumb"),
                        render.Marquee(
                            width = 43,
                            child = render.Text(
                                content = owner_display,
                                font = "tom-thumb",
                                color = "#AAAAAA",
                            ),
                            scroll_direction = "horizontal",
                            offset_start = 43,
                        ),
                    ],
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
        schema.Option(display = "NetJets — EJA468 @ FL410", value = "netjets"),
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
                desc = "Your FlightAware AeroAPI key.",
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
