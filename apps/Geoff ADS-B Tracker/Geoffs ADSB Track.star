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

# Local operator name lookup — avoids AeroAPI /operators calls.
# Key = ICAO airline code, Value = short display name.
# Add or edit entries here as needed.
OPERATOR_NAMES = {
    # ── NetJets / fractional ──────────────────────────────────────────────────
    "EJA": "NetJets",
    "EJM": "EJM",
    "VJT": "VistaJet",
    "FLJ": "FlexJet",
    "TWY": "Wheels Up",
    # ── US majors ─────────────────────────────────────────────────────────────
    "AAL": "American",
    "DAL": "Delta",
    "UAL": "United",
    "SWA": "Southwest",
    "ASA": "Alaska",
    "JBU": "JetBlue",
    "HAL": "Hawaiian",
    "FFT": "Frontier",
    "NKS": "Spirit",
    "SUN": "Sun Country",
    "WN":  "Southwest",
    # ── US regionals (often the actual operator on codeshare flights) ─────────
    "RPA": "Republic",
    "SKW": "SkyWest",
    "ENY": "Envoy",
    "PDT": "Piedmont",
    "JIA": "PSA Airlines",
    "EDV": "Endeavor",
    "ASH": "Mesa",
    "CPZ": "Compass",
    "QXE": "Horizon Air",
    "BTA": "Air Wisconsin",
    "TCF": "Transcom",
    "GJS": "GoJet",
    # ── US cargo ──────────────────────────────────────────────────────────────
    "UPS": "UPS",
    "FDX": "FedEx",
    "ABX": "ABX Air",
    "ATN": "Air Transport Intl",
    "KFS": "Kalitta Air",
    "GTI": "Atlas Air",
    # ── US charter / other ────────────────────────────────────────────────────
    "AWI": "Air Wisconsin",
    "SWQ": "Swoop",
    "VRD": "Virgin America",
    "XJT": "ExpressJet",
    # ── Military / government ─────────────────────────────────────────────────
    "AFO": "Air Force",
    "AIO": "Air Force",
    "HXA": "Army",
    "HXB": "Army",
    "VMF": "Marines",
    "NOF": "Navy",
    "CGF": "Coast Guard",
    # ── International majors ──────────────────────────────────────────────────
    "BAW": "British Airways",
    "DLH": "Lufthansa",
    "AFR": "Air France",
    "KLM": "KLM",
    "UAE": "Emirates",
    "QTR": "Qatar",
    "SIA": "Singapore Air",
    "CPA": "Cathay Pacific",
    "ANA": "ANA",
    "JAL": "JAL",
    "AC":  "Air Canada",
    "ACA": "Air Canada",
    "WJA": "WestJet",
    "VOZ": "Virgin Australia",
    "QFA": "Qantas",
}

# ICAO callsign prefixes eligible for an AeroAPI lookup. Restricting lookups to
# these carriers (US majors, major-affiliated regionals, US cargo/freight, and
# NetJets/Executive Jet) keeps AeroAPI call volume down — GA, military, and
# other charter/other traffic never trigger a call, even if they're the
# nearest aircraft. Regionals are included because their raw ADS-B callsign
# shows the regional's own code (e.g. ENY), not the major they're flying for
# (e.g. AAL) — only an AeroAPI lookup can resolve the codeshare to the major.
AEROAPI_ELIGIBLE_CARRIERS = {
    # US majors
    "AAL": True,
    "DAL": True,
    "UAL": True,
    "SWA": True,
    "ASA": True,
    "JBU": True,
    "HAL": True,
    "FFT": True,
    "NKS": True,
    "SUN": True,
    "WN": True,
    # US regionals (major-affiliated codeshare operators)
    "RPA": True,
    "SKW": True,
    "ENY": True,
    "PDT": True,
    "JIA": True,
    "EDV": True,
    "AWI": True,
    "ASH": True,
    "CPZ": True,
    "QXE": True,
    "BTA": True,
    "GJS": True,
    # US cargo / freight
    "UPS": True,
    "FDX": True,
    "ABX": True,
    "ATN": True,
    "KFS": True,
    "GTI": True,
    # NetJets / fractional
    "EJA": True,
    "EJM": True,
}

# Regional carriers fly under their own ICAO callsign (RPA5650) but sell seats
# under a major's brand and flight number (UAL4650). Used to pick the marketing
# ident out of AeroAPI's codeshare list and to label the airline frame.
REGIONAL_CARRIERS = {
    "RPA": True,
    "SKW": True,
    "ENY": True,
    "EDV": True,
    "JIA": True,
    "PDT": True,
    "CPZ": True,
    "QXE": True,
    "GJS": True,
    "AWI": True,
    "ASH": True,
}

# The majors a regional flies for. Only these are accepted as the marketing
# ident, so a partner airline's codeshare (e.g. Finnair on an American flight)
# is never shown in place of the flight's own callsign.
MARKETING_CARRIERS = {
    "AAL": True,
    "DAL": True,
    "UAL": True,
    "ASA": True,
}

# Brand for regionals that fly for a single major, used when neither AeroAPI nor
# the airframe's registered owner names one. Multi-partner regionals (Republic,
# SkyWest, ...) are deliberately absent: only per-flight or per-airframe data
# can say which major they are flying for.
REGIONAL_BRANDS = {
    "ENY": "American Eagle",
    "PDT": "American Eagle",
    "JIA": "American Eagle",
    "EDV": "Delta Connection",
}

COMPASS_DIRS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

# Aircraft type/registration lookups keyed by ICAO hex. An airframe's type and
# registration essentially never change, so cache the answers for a long time.
TAR1090_DB_TTL = 86400
HEXDB_URL = "https://hexdb.io/api/v1/aircraft/"
HEXDB_TTL = 604800

# ADS-B emitter category -> short class label. Shown (dimmed) only when no
# source can name the actual type designator, so the screen still says
# something more useful than "Unknown". Kept to ~10 chars to fit the type column.
CATEGORY_LABELS = {
    "A1": "LIGHT",
    "A2": "SMALL",
    "A3": "LARGE",
    "A4": "HI VORTEX",
    "A5": "HEAVY",
    "A6": "HI PERF",
    "A7": "ROTOR",
    "B1": "GLIDER",
    "B2": "BALLOON",
    "B3": "SKYDIVER",
    "B4": "ULTRALIGHT",
    "B6": "UAV",
    "B7": "SPACE",
    "C1": "SURF VEH",
    "C2": "SURF VEH",
    "C3": "OBSTACLE",
}

def dbg(enabled, msg):
    if enabled:
        print("[ADSB] " + msg)

def pad(text, width):
    # Starlark's % operator has no width flag, so pad by hand.
    return text + " " * (width - len(text))

def dbg_render_values(rows):
    """Prints every value the two frames display, one line per value, as
    (label, shown value, detail on where it came from) rows."""
    print("[ADSB] render values (what the display is showing):")
    for row in rows:
        line = "[ADSB]   %s %s" % (pad(row[0], 15), pad(str(row[1]), 20))
        if row[2] != "":
            line = line + " <- " + row[2]
        print(line.rstrip())

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

    # First priority: exact "En Route" status
    for flight in flights:
        if flight.get("status", "") == "En Route":
            return flight

    # Second priority: progress-based en route (status field absent or different)
    for flight in flights:
        progress = flight.get("progress_percent", 0)
        if progress != None and progress > 0 and progress < 100:
            return flight

    # No en route flight found — return nothing rather than a stale/future flight
    return None

def has_route_data(flight):
    """AeroAPI often returns no origin/destination when queried by a regional's
    own operating ident, but returns full route data when queried by the
    marketing carrier's codeshare ident instead."""
    if flight == None:
        return False
    return flight.get("origin", None) != None and flight.get("destination", None) != None

# ── Flight data helpers ───────────────────────────────────────────────────────

def marketing_ident(flight):
    """The marketing carrier's flight ident (e.g. 'UAL4650') from a flight's
    codeshare list: the first one that belongs to a major in MARKETING_CARRIERS,
    or None. AeroAPI lists every partner that sells the flight (an American
    flight may list Finnair first), so the first entry can't be trusted."""
    codeshares = flight.get("codeshares", [])
    if codeshares == None or type(codeshares) == "string":
        return None
    for codeshare in codeshares:
        if extract_icao_prefix(codeshare) in MARKETING_CARRIERS:
            return codeshare
    return None

def get_display_ident(flight):
    """The ident to show. A regional's own callsign (RPA5650) is swapped for its
    marketing carrier's (UAL4650) when AeroAPI lists one; every other flight
    keeps its own ident rather than being relabelled with a partner's code."""
    own_ident = flight.get("ident_icao", None)
    if own_ident == None or own_ident == "":
        own_ident = flight.get("ident", "")
    if extract_icao_prefix(own_ident) in REGIONAL_CARRIERS:
        marketing = marketing_ident(flight)
        if marketing != None:
            return marketing
    return own_ident

def extract_icao_prefix(ident):
    """Extracts the leading alphabetic ICAO airline prefix from a flight ident
    (e.g. 'SWA2269' -> 'SWA'). Returns None if fewer than 2 leading letters."""
    if ident == None or ident == "":
        return None
    trimmed = ident.strip()
    prefix = ""
    for i in range(len(trimmed)):
        ch = trimmed[i]
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
        return "%dh%dm" % (hours, minutes)
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

            # The bar fits 16 characters and its marquee never scrolls, so
            # anything longer is simply not shown. Keep every string within 16.
            if cancelled:
                return ("%s %s CNCLD" % (origin_code, dest_code), "#FF6600")
            elif diverted:
                return ("%s %s DIVRT" % (origin_code, dest_code), "#FF6600")
            elif progress != None and progress >= 100:
                return ("%s > %s ARVD" % (origin_code, dest_code), "#AAAAAA")
            elif progress != None and progress > 0:
                time_remaining = format_time_remaining(aero_flight.get("estimated_on", None))
                if time_remaining != None:
                    return ("%s %s %s" % (origin_code, time_remaining, dest_code), "#FFFFFF")
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

# ── Aircraft identity (registration / type / airline) ─────────────────────────

def clean_text(value):
    """Returns value stripped, or None if it isn't a non-empty string."""
    if value == None or type(value) != "string":
        return None
    trimmed = value.strip()
    if trimmed == "":
        return None
    return trimmed

def clean_id(value):
    """clean_text, uppercased (registrations and type designators)."""
    text = clean_text(value)
    if text == None:
        return None
    return text.upper()

def safe_json(response):
    """Decodes a JSON object body, or returns None on a non-200 status or a
    non-JSON body. Starlark has no try/catch and response.json() aborts the
    whole render on bad JSON, so a proxy answering 200 with an HTML page (or a
    third-party outage page) has to be screened out first."""
    if response.status_code != 200:
        return None
    if not response.body().strip().startswith("{"):
        return None
    return response.json()

def is_icao_hex(hex_id):
    """True for a plain 24-bit ICAO address. tar1090 marks TIS-B/anonymous
    targets with a leading '~', which no aircraft database contains."""
    return hex_id != None and len(re.findall("^[0-9a-fA-F]{6}$", hex_id)) > 0

def tar1090_db_base(base_url):
    """Returns '<base>/db-<version>', where a tar1090 receiver keeps its sharded
    aircraft DB and its type/operator tables, or None. Plain PiAware/dump1090
    installs have no version.json, so this quietly returns None there."""
    root = base_url.rstrip("/")
    version = safe_json(http.get(root + "/version.json", ttl_seconds = 1800))
    if version == None or version.get("databaseVersion", None) == None:
        return None
    return "%s/db-%s" % (root, version["databaseVersion"])

def lookup_tar1090_db(db_base, hex_id):
    """Looks the hex up in the receiver's aircraft DB with the same sharded
    lookup the tar1090 web UI does (<hex prefix>.js, entry = [registration,
    type, flags, long name], deeper shards listed under "children"). Returns
    (registration, type, long name) or None."""
    hex_up = hex_id.upper()
    for level in range(1, len(hex_up)):
        shard = safe_json(http.get("%s/%s.js" % (db_base, hex_up[0:level]), ttl_seconds = TAR1090_DB_TTL))
        if shard == None:
            return None
        entry = shard.get(hex_up[level:], None)
        if entry != None and type(entry) == "list" and len(entry) > 1:
            return (entry[0], entry[1], entry[3] if len(entry) > 3 else None)
        if hex_up[0:level + 1] not in shard.get("children", []):
            return None
    return None

def lookup_tar1090_type_name(db_base, type_code):
    """Long type name ('EMBRAER ERJ-170-200 (long wing)') from the receiver's
    ICAO type table."""
    types = safe_json(http.get(db_base + "/icao_aircraft_types2.js", ttl_seconds = TAR1090_DB_TTL))
    if types == None:
        return None
    entry = types.get(type_code, None)
    if entry != None and type(entry) == "list" and len(entry) > 0:
        return entry[0]
    return None

def lookup_tar1090_operator(db_base, prefix):
    """Airline name for an ICAO airline prefix from the receiver's operator list."""
    operators = safe_json(http.get(db_base + "/operators.js", ttl_seconds = TAR1090_DB_TTL))
    if operators == None:
        return None
    entry = operators.get(prefix, None)
    if entry != None and type(entry) == "dict":
        return clean_text(entry.get("n", None))
    return None

def lookup_hexdb(hex_id):
    """Looks the hex up on hexdb.io (free, no key, covers GA and military as
    well as airlines). Returns a dict of registration / type / long name /
    registered owner, or None."""
    data = safe_json(http.get(HEXDB_URL + hex_id.upper(), ttl_seconds = HEXDB_TTL))
    if data == None:
        return None
    maker = clean_text(data.get("Manufacturer", None))
    model = clean_text(data.get("Type", None))
    name = model
    if maker != None and model != None and not model.upper().startswith(maker.upper()):
        name = maker + " " + model
    return {
        "registration": data.get("Registration", None),
        "type": data.get("ICAOTypeCode", None),
        "name": name,
        "owner": clean_text(data.get("RegisteredOwners", None)),
    }

def fill_identity(ident, source, registration = None, type_code = None, name = None):
    """Fills whichever of registration/type/long name is still empty from one source."""
    reg = clean_id(registration)
    typ = clean_id(type_code)
    long_name = clean_text(name)
    if ident["registration"] == None and reg != None:
        ident["registration"] = reg
        ident["registration_src"] = source
    if ident["type"] == None and typ != None:
        ident["type"] = typ
        ident["type_src"] = source
    if ident["name"] == None and long_name != None:
        ident["name"] = long_name
        ident["name_src"] = source

def identity_complete(ident):
    return ident["registration"] != None and ident["type"] != None and ident["name"] != None

def resolve_identity(aircraft, aero_flight, db_base, allow_network, want_hexdb, debug):
    """Resolves the registration, ICAO type designator and long type name,
    cheapest source first, so the display only falls back to the hex / a
    category label when every source has failed. Keyed by ICAO hex, so it works
    for GA and military traffic and does not depend on AeroAPI, its carrier
    list, or business hours.
      1. r / t / desc on the aircraft.json record (readsb with an aircraft DB)
      2. the AeroAPI flight already fetched for route data
      3. the receiver's own tar1090 database and type table
      4. hexdb.io (also asked when want_hexdb, for a regional's brand)
    """
    ident = {
        "registration": None,
        "type": None,
        "name": None,
        "registration_src": None,
        "type_src": None,
        "name_src": None,
        "hexdb": None,
    }
    fill_identity(ident, "aircraft.json", aircraft.get("r", None), aircraft.get("t", None), aircraft.get("desc", None))
    if aero_flight != None:
        fill_identity(ident, "aeroapi", aero_flight.get("registration", None), aero_flight.get("aircraft_type", None))

    hex_id = aircraft.get("hex", None)
    if allow_network and is_icao_hex(hex_id):
        if db_base != None:
            db_name = None
            if ident["registration"] == None or ident["type"] == None:
                db_hit = lookup_tar1090_db(db_base, hex_id)
                if db_hit != None:
                    fill_identity(ident, "tar1090 db", db_hit[0], db_hit[1])
                    db_name = db_hit[2]
            if ident["name"] == None and ident["type"] != None:
                fill_identity(ident, "tar1090 types", None, None, lookup_tar1090_type_name(db_base, ident["type"]))
            fill_identity(ident, "tar1090 db", None, None, db_name)
        if want_hexdb or not identity_complete(ident):
            ident["hexdb"] = lookup_hexdb(hex_id)
            if ident["hexdb"] != None:
                fill_identity(ident, "hexdb.io", ident["hexdb"]["registration"], ident["hexdb"]["type"], ident["hexdb"]["name"])

    dbg(debug, "identity hex=%s type=%s (via %s) registration=%s (via %s) name=%r (via %s)" % (
        hex_id,
        ident["type"],
        ident["type_src"],
        ident["registration"],
        ident["registration_src"],
        ident["name"],
        ident["name_src"],
    ))
    return ident

def split_type_name(name):
    """Splits a long type name ('EMBRAER ERJ-170-200 (long wing)') into
    manufacturer and model lines that each fit the 10-character type column.
    The model starts at the first word containing a digit and takes whole
    words while they fit, so 'CESSNA 172 Skyhawk' gives ('CESSNA', '172')."""
    if name == None:
        return []
    words = name.split("(")[0].upper().split()
    if len(words) == 0:
        return []
    lines = [words[0][:10]]
    rest = words[1:]
    start = 0
    for i in range(len(rest)):
        if len(re.findall("[0-9]", rest[i])) > 0:
            start = i
            break
    model = ""
    for word in rest[start:]:
        candidate = word if model == "" else model + " " + word
        if len(candidate) > 10:
            if model == "":
                model = word[:10]
            break
        model = candidate
    if model != "":
        lines.append(model)
    return lines

def airline_name(prefix, db_base):
    """Airline name for an ICAO prefix: your curated OPERATOR_NAMES table first,
    then the receiver's own operator list."""
    if prefix == None:
        return None
    name = OPERATOR_NAMES.get(prefix, None)
    if name != None:
        return name
    if db_base != None and len(prefix) == 3:
        return lookup_tar1090_operator(db_base, prefix)
    return None

def brand_from_owner(owner):
    """A regional airframe's registered owner is often the brand it flies for
    ('Delta Connection', 'American Eagle', 'United Express'). Other owners
    (leasing companies, LLCs) are not shown."""
    if owner == None:
        return None
    lowered = owner.lower()
    for keyword in ["eagle", "express", "connection"]:
        if keyword in lowered:
            return owner
    return None

def resolve_airline(callsign_raw, display_callsign, hexdb_owner, db_base):
    """Names the carrier actually flying the aircraft (from the ADS-B callsign
    prefix) and, for a regional, the major whose brand it flies under. The brand
    comes from the most specific source available:
      1. the marketing ident AeroAPI gave (already in display_callsign)
      2. the airframe's registered owner on hexdb.io (per aircraft, so it tells
         Republic's Delta, American and United jets apart)
      3. REGIONAL_BRANDS, for regionals that fly for a single major
    """
    result = {"operator": None, "brand": None, "operator_src": None, "brand_src": None}
    op_prefix = extract_icao_prefix(callsign_raw)
    if op_prefix == None:
        return result

    result["operator"] = airline_name(op_prefix, db_base)
    if result["operator"] != None:
        result["operator_src"] = "operator table" if op_prefix in OPERATOR_NAMES else "tar1090 operators"

    if op_prefix in REGIONAL_CARRIERS:
        shown_prefix = extract_icao_prefix(display_callsign)
        if shown_prefix != None and shown_prefix != op_prefix and shown_prefix in MARKETING_CARRIERS:
            result["brand"] = airline_name(shown_prefix, db_base)
            result["brand_src"] = "aeroapi marketing ident (%s)" % shown_prefix
        if result["brand"] == None:
            result["brand"] = brand_from_owner(hexdb_owner)
            result["brand_src"] = "hexdb registered owner"
        if result["brand"] == None:
            result["brand"] = REGIONAL_BRANDS.get(op_prefix, None)
            result["brand_src"] = "regional table"
        if result["brand"] == None:
            result["brand_src"] = None
    return result

def build_airline_frame(operator, brand):
    """Full-screen card naming the carrier. A regional shows the brand it flies
    for, then 'operated by' the regional itself. None when there's no name."""
    lines = []
    if brand != None:
        lines.append(render.WrappedText(content = brand[:32], width = 64, font = "tom-thumb", align = "center"))
        if operator != None:
            lines.append(render.Text(content = "operated by", font = "tom-thumb", color = "#777777"))
            lines.append(render.WrappedText(content = operator[:32], width = 64, font = "tom-thumb", align = "center", color = "#AAAAAA"))
    elif operator != None:
        lines.append(render.WrappedText(content = operator[:48], width = 64, font = "tom-thumb", align = "center"))
    if len(lines) == 0:
        return None
    return render.Box(
        width = 64,
        height = 32,
        child = render.Column(
            children = lines,
            main_align = "center",
            cross_align = "center",
            expanded = True,
        ),
    )

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
            "desc": "BOEING 737-700",
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
            "desc": "EMBRAER EMB-505 Phenom 300",
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
        {
            "hex": "a1a924",
            "type": "adsb_icao",
            "flight": "RPA5650 ",
            "alt_baro": 24000,
            "gs": 380.0,
            "track": 300.0,
            "squawk": "3421",
            "emergency": "none",
            "category": "A3",
            "lat": 40.2,
            "lon": -83.2,
            "r_dst": 5.1,
            "r_dir": 200.0,
            "r": "N206JQ",
            "t": "E75L",
            "desc": "EMBRAER ERJ-170-200 (long wing)",
        },
        {
            "hex": "a0f1bb",
            "type": "adsb_icao",
            "flight": "AAL1234 ",
            "alt_baro": 35000,
            "gs": 450.0,
            "track": 250.0,
            "squawk": "5012",
            "emergency": "none",
            "category": "A3",
            "lat": 40.3,
            "lon": -83.3,
            "r_dst": 6.0,
            "r_dir": 120.0,
            "r": "N160AN",
            "t": "A321",
            "desc": "AIRBUS A-321",
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

def dummy_eta(minutes):
    """An ISO arrival time `minutes` from now, so the bottom bar shows a live ETA."""
    arrival = time.now() + time.parse_duration("%dm" % minutes)
    return arrival.in_location("UTC").format("2006-01-02T15:04:05Z")

def generate_dummy_aero_regional():
    """A Republic flight sold by United, with a partner codeshare listed first:
    the display must pick UAL4650, not ACA7891."""
    return {
        "ident": "RPA5650",
        "ident_icao": "RPA5650",
        "registration": "N206JQ",
        "operator": "RPA",
        "operator_icao": "RPA",
        "aircraft_type": "E75L",
        "codeshares": ["ACA7891", "UAL4650"],
        "progress_percent": 40,
        "cancelled": False,
        "diverted": False,
        "status": "En Route",
        "origin": {"code": "KCMH", "code_icao": "KCMH"},
        "destination": {"code": "KORD", "code_icao": "KORD"},
        "estimated_on": dummy_eta(75),
    }

def generate_dummy_aero_codeshare():
    """An American-operated flight that AeroAPI also lists under partner
    airlines, Finnair first: the display must keep AAL1234, not FIN5678."""
    return {
        "ident": "AAL1234",
        "ident_icao": "AAL1234",
        "registration": "N160AN",
        "operator": "AAL",
        "operator_icao": "AAL",
        "aircraft_type": "A321",
        "codeshares": ["FIN5678", "BAW4321"],
        "progress_percent": 30,
        "cancelled": False,
        "diverted": False,
        "status": "En Route",
        "origin": {"code": "KCMH", "code_icao": "KCMH"},
        "destination": {"code": "KDFW", "code_icao": "KDFW"},
        "estimated_on": dummy_eta(150),
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

def is_business_hours():
    """Returns True if current time is Mon-Fri 7am-5pm Eastern.
    Uses Unix timestamp arithmetic to avoid Starlark time API limitations.
    DST: second Sunday in March 2:00am -> first Sunday in November 2:00am."""
    now_utc = time.now()

    # Seconds since Unix epoch
    now_unix = int(now_utc.unix)

    # Approximate DST boundaries for the current year using day-of-year offsets.
    # Rather than computing exact Sunday boundaries (requires weekday()),
    # we use the known range: EDT runs roughly Mar 8–14 start, Nov 1–7 end.
    # We hardcode the UTC epoch seconds for 2026 and nearby years.
    # Format: (edt_start_unix, edt_end_unix)
    dst_windows = {
        2024: (1710057600, 1730620800),  # Mar 10 07:00 UTC, Nov  3 06:00 UTC
        2025: (1741507200, 1762070400),  # Mar  9 07:00 UTC, Nov  2 06:00 UTC
        2026: (1772956800, 1793520000),  # Mar  8 07:00 UTC, Nov  1 06:00 UTC
        2027: (1804406400, 1824969600),  # Mar 14 07:00 UTC, Nov  7 06:00 UTC
        2028: (1835856000, 1857024000),  # Mar 12 07:00 UTC, Nov  5 06:00 UTC
    }

    year = now_utc.year
    window = dst_windows.get(year, None)

    if window != None and now_unix >= window[0] and now_unix < window[1]:
        offset_secs = -4 * 3600   # EDT UTC-4
    else:
        offset_secs = -5 * 3600   # EST UTC-5

    eastern_unix = now_unix + offset_secs

    # Derive weekday and hour from eastern Unix timestamp
    # Unix epoch (Jan 1 1970) was a Thursday = weekday 3 (0=Mon)
    days_since_epoch = int(eastern_unix / 86400)
    weekday = (days_since_epoch + 3) % 7   # 0=Mon, 6=Sun

    seconds_in_day = eastern_unix % 86400
    hour = int(seconds_in_day / 3600)

    return weekday <= 4 and hour >= 7 and hour < 17

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
    ignore_business_hours = config.bool("debug_ignore_business_hours", False)
    debug_logging = config.bool("debug_logging", False)
    debug_render_values = config.bool("debug_render_values", False)

    if use_custom_coords and custom_lat == 0.0 and custom_lon == 0.0:
        use_custom_coords = False

    aero_flight = None

    # ── Data acquisition ──────────────────────────────────────────────────────

    if dummy_mode != "none":
        dummy_list = generate_dummy_aircraft()

        if dummy_mode == "commercial":
            aircraft = dummy_list[0]
            aero_flight = generate_dummy_aero_commercial()

        elif dummy_mode == "netjets":
            aircraft = dummy_list[1]
            aero_flight = generate_dummy_aero_netjets()

        elif dummy_mode == "military":
            aircraft = dummy_list[2]
            aero_flight = None

        elif dummy_mode == "regional":
            aircraft = dummy_list[3]
            aero_flight = generate_dummy_aero_regional()

        elif dummy_mode == "codeshare":
            aircraft = dummy_list[4]
            aero_flight = generate_dummy_aero_codeshare()

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

        dbg(debug_logging, "selected aircraft hex=%s flight=%r r_dst=%s category=%s" % (
            aircraft.get("hex", "?"),
            aircraft.get("flight", "?"),
            aircraft.get("r_dst", "?"),
            aircraft.get("category", "?"),
        ))

        callsign_raw = get_callsign(aircraft)
        carrier_prefix = extract_icao_prefix(callsign_raw)
        is_aeroapi_eligible = carrier_prefix != None and carrier_prefix in AEROAPI_ELIGIBLE_CARRIERS
        dbg(debug_logging, "callsign=%r carrier_prefix=%s aeroapi_eligible=%s business_hours=%s ignore_business_hours=%s" % (
            callsign_raw, carrier_prefix, is_aeroapi_eligible, is_business_hours(), ignore_business_hours
        ))

        if is_aeroapi_eligible and len(api_key) > 0 and (ignore_business_hours or is_business_hours()):
            aero_flight = lookup_aeroapi_flight(callsign_raw, api_key)
            dbg(debug_logging, "lookup_aeroapi_flight(%s) -> found=%s has_route_data=%s" % (
                callsign_raw, aero_flight != None, has_route_data(aero_flight)
            ))

            # AeroAPI frequently omits origin/destination when queried by a
            # regional's own operating ident. If a marketing carrier's ident is
            # listed, re-query with that instead — it's the one that actually
            # carries route data. Only a major's ident is used: retrying with a
            # partner's codeshare would also swap the shown callsign for theirs.
            if aero_flight != None and not has_route_data(aero_flight):
                retry_ident = marketing_ident(aero_flight)
                if retry_ident != None:
                    dbg(debug_logging, "no route data for %s, retrying via marketing ident %s" % (callsign_raw, retry_ident))
                    marketing_flight = lookup_aeroapi_flight(retry_ident, api_key)
                    if marketing_flight != None and has_route_data(marketing_flight):
                        aero_flight = marketing_flight
                        dbg(debug_logging, "marketing ident retry succeeded, using %s" % retry_ident)
                    else:
                        dbg(debug_logging, "marketing ident retry via %s did not yield route data" % retry_ident)
        elif is_aeroapi_eligible:
            dbg(debug_logging, "skipping AeroAPI lookup for %s: api_key_set=%s business_hours=%s" % (
                callsign_raw, len(api_key) > 0, ignore_business_hours or is_business_hours()
            ))

        if aero_flight != None:
            dbg(debug_logging, "aeroapi flight ident=%r codeshares=%s shown ident=%r origin=%s destination=%s" % (
                aero_flight.get("ident_icao", aero_flight.get("ident", None)),
                aero_flight.get("codeshares", None),
                get_display_ident(aero_flight),
                aero_flight.get("origin", None),
                aero_flight.get("destination", None),
            ))

    # ── Resolve display values ────────────────────────────────────────────────

    # Test modes stay offline: only the dummy data (and its AeroAPI stub) is used.
    live = dummy_mode == "none"
    db_base = tar1090_db_base(piaware_url) if live else None
    callsign_raw = get_callsign(aircraft)

    # A regional's brand (Delta Connection, ...) is on hexdb.io per airframe; only
    # ask for it when AeroAPI hasn't already named the marketing carrier.
    has_marketing_ident = aero_flight != None and marketing_ident(aero_flight) != None
    want_brand = live and extract_icao_prefix(callsign_raw) in REGIONAL_CARRIERS and not has_marketing_ident
    ident = resolve_identity(aircraft, aero_flight, db_base, live, want_brand, debug_logging)

    if aero_flight != None:
        display_callsign = get_display_ident(aero_flight).upper()
        callsign_src = "aeroapi ident"
    else:
        display_callsign = get_callsign(aircraft).upper()
        callsign_src = "aircraft.json flight"
    if len(display_callsign) == 0:
        display_callsign = aircraft.get("hex", "------").upper()
        callsign_src = "hex (no callsign)"

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

    # Registration and type: see resolve_identity for the source order
    registration = ident["registration"]
    if registration == None:
        registration = aircraft.get("hex", "------").upper()

    type_code = ident["type"]
    if type_code != None:
        aircraft_type = type_code
        type_color = "#FFFFFF"
    else:
        # Nothing could name the type: show the ADS-B emitter class, dimmed so
        # it reads as a category rather than a confirmed type.
        aircraft_type = CATEGORY_LABELS.get(aircraft.get("category", ""), "Unknown")
        type_color = "#AAAAAA"

    # Manufacturer / model lines under the type code (none if no source had a name)
    type_lines = split_type_name(ident["name"])

    # Airline card (third frame): who is flying it and, for a regional, whose brand
    hexdb_owner = ident["hexdb"]["owner"] if ident["hexdb"] != None else None
    airline = resolve_airline(callsign_raw, display_callsign, hexdb_owner, db_base)
    airline_frame = build_airline_frame(airline["operator"], airline["brand"])

    # ── Aircraft icon ─────────────────────────────────────────────────────────

    icon_alt = int(alt_baro) if alt_baro != "ground" else 0
    icon_color = get_altitude_icon_color(icon_alt)
    addrtype = aircraft.get("type", "adsb_icao")

    # The icon service wants a real type designator; a class label isn't one.
    icon_type = type_code if type_code != None else "Unknown"
    aircraft_icon = get_aircraft_icon(
        aircraft["category"], icon_type, icon_type, addrtype, icon_color
    )
    icon_state = "icon service"
    if aircraft_icon == None:
        aircraft_icon = BLANK_ASSET.readall()
        icon_state = "blank (icon service failed)"

    # ── Render debug ──────────────────────────────────────────────────────────

    if debug_render_values:
        if is_emergency:
            bottom_src = "emergency squawk"
        elif bottom_content.startswith("HDG:"):
            bottom_src = "track (no route data)"
        else:
            bottom_src = "aeroapi route"

        if use_custom_coords and "lat" in aircraft and "lon" in aircraft:
            dst_src = "custom coords"
        elif "r_dst" in aircraft:
            dst_src = "r_dst=%s" % aircraft["r_dst"]
        else:
            dst_src = "no r_dst"

        dbg_render_values([
            ("F1 label", "NJA logo" if is_nja else "Flight", "callsign starts EJA/EJM" if is_nja else ""),
            ("F1 callsign", display_callsign, callsign_src),
            ("F1 altitude", alt_display, "alt_baro=%s units=%s" % (alt_baro, conversion_unit)),
            ("F1 speed", spd_display, "gs=%s units=%s" % (aircraft.get("gs", 0), conversion_unit)),
            ("F1 distance", dst_display if len(dst_display) > 0 else "(blank)", dst_src),
            ("F1 bottom bar", bottom_content, "%s, color=%s%s" % (bottom_src, bottom_color, ", marquee" if len(bottom_content) > 14 else "")),
            ("F2 icon", icon_type, "%s, category=%s color=%s addr=%s" % (icon_state, aircraft["category"], icon_color, addrtype)),
            ("F2 registration", registration, ident["registration_src"] if ident["registration_src"] != None else "hex (no source had it)"),
            ("F2 type", aircraft_type, "%s, color=%s" % (ident["type_src"] if ident["type_src"] != None else "category label (no source had it)", type_color)),
            ("F2 manufacturer", type_lines[0] if len(type_lines) > 0 else "(none)", ("name=%r via %s" % (ident["name"], ident["name_src"])) if ident["name"] != None else "no source had a type name"),
            ("F2 model", type_lines[1] if len(type_lines) > 1 else "(none)", ""),
            ("F3 airline card", "yes" if airline_frame != None else "(no frame 3)", ""),
            ("F3 brand", airline["brand"] if airline["brand"] != None else "(none)", airline["brand_src"] if airline["brand_src"] != None else ""),
            ("F3 operator", airline["operator"] if airline["operator"] != None else "(none)", airline["operator_src"] if airline["operator_src"] != None else "no name for callsign prefix"),
        ])

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
                                render.Text(content = dst_display, font = "tom-thumb") if len(dst_display) > 0 else render.Box(width = 1, height = 6),
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
                        ) if len(bottom_content) <= 16 else render.Marquee(
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

    # Registration and type code, then manufacturer and model when a name is known.
    # Every line is kept to 10 characters: a marquee can't scroll in a 2-3 frame
    # animation, so anything wider than the column would simply not show.
    frame2_lines = [
        render.Text(content = registration, font = "tom-thumb"),
        render.Text(content = aircraft_type, font = "tom-thumb", color = type_color),
    ]
    for type_line in type_lines:
        frame2_lines.append(render.Text(content = type_line, font = "tom-thumb", color = "#AAAAAA"))

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
                    children = frame2_lines,
                ),
            ),
        ],
    )

    # ── Frame 3 (only when a carrier name is known) ───────────────────────────

    frames = [frame1, frame2]
    if airline_frame != None:
        frames.append(airline_frame)

    return render.Root(
        delay = 5000,
        child = render.Animation(
            children = frames,
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
        schema.Option(display = "Regional — RPA5650 flying as United", value = "regional"),
        schema.Option(display = "Codeshare — AAL1234 with Finnair listed", value = "codeshare"),
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
            schema.Toggle(
                id = "debug_ignore_business_hours",
                name = "Debug: Ignore Business Hours",
                desc = "Allow AeroAPI lookups outside Mon-Fri 7am-5pm Eastern. For testing only — leave off to limit API usage.",
                icon = "bug",
                default = False,
            ),
            schema.Toggle(
                id = "debug_logging",
                name = "Debug: Verbose Logging",
                desc = "Print aircraft selection and AeroAPI lookup details to the render log. For testing only.",
                icon = "bug",
                default = False,
            ),
            schema.Toggle(
                id = "debug_render_values",
                name = "Debug: Render Values",
                desc = "Print every value shown on the display, and where it came from, to the render log. For testing only.",
                icon = "bug",
                default = False,
            ),
        ],
    )
