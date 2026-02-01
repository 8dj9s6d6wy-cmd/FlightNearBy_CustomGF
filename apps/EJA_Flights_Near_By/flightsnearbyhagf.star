"""
Applet: EJA Flights Near By HA
Summary: EJA Flights Nearby HA
Description: Flights nearby using data from Flightradar integration in HA
Author: motoridersd (Modified by FFeog187)
"""

load("cache.star", "cache")
#load("db.star", "DB")
load("encoding/json.star", "json")
load("filter.star", "filter")
load("http.star", "http")
load("images/airliner.png", AIRLINER_ASSET = "file")
load("images/airliner@2x.png", AIRLINER_ASSET_2X = "file")
load("images/balloon.png", BALLOON_ASSET = "file")
load("images/balloon@2x.png", BALLOON_ASSET_2X = "file")
load("images/cessna.png", CESSNA_ASSET = "file")
load("images/cessna@2x.png", CESSNA_ASSET_2X = "file")
load("images/ground_emergency.png", GROUND_EMERGENCY_ASSET = "file")
load("images/ground_emergency@2x.png", GROUND_EMERGENCY_ASSET_2X = "file")
load("images/ground_fixed.png", GROUND_FIXED_ASSET = "file")
load("images/ground_fixed@2x.png", GROUND_FIXED_ASSET_2X = "file")
load("images/ground_service.png", GROUND_SERVICE_ASSET = "file")
load("images/ground_service@2x.png", GROUND_SERVICE_ASSET_2X = "file")
load("images/ground_unknown.png", GROUND_UNKNOWN_ASSET = "file")
load("images/ground_unknown@2x.png", GROUND_UNKNOWN_ASSET_2X = "file")
load("images/heavy_2e.png", HEAVY_2E_ASSET = "file")
load("images/heavy_2e@2x.png", HEAVY_2E_ASSET_2X = "file")
load("images/heavy_4e.png", HEAVY_4E_ASSET = "file")
load("images/heavy_4e@2x.png", HEAVY_4E_ASSET_2X = "file")
load("images/helicopter.png", HELICOPTER_ASSET = "file")
load("images/helicopter@2x.png", HELICOPTER_ASSET_2X = "file")
load("images/hi_perf.png", HI_PERF_ASSET = "file")
load("images/hi_perf@2x.png", HI_PERF_ASSET_2X = "file")
load("images/jet_nonswept.png", JET_NONSWEPT_ASSET = "file")
load("images/jet_nonswept@2x.png", JET_NONSWEPT_ASSET_2X = "file")
load("images/jet_swept.png", JET_SWEPT_ASSET = "file")
load("images/jet_swept@2x.png", JET_SWEPT_ASSET_2X = "file")
load("images/twin_large.png", TWIN_LARGE_ASSET = "file")
load("images/twin_large@2x.png", TWIN_LARGE_ASSET_2X = "file")
load("images/twin_small.png", TWIN_SMALL_ASSET = "file")
load("images/twin_small@2x.png", TWIN_SMALL_ASSET_2X = "file")
load("images/unknown.png", UNKNOWN_ASSET = "file")
load("images/unknown@2x.png", UNKNOWN_ASSET_2X = "file")
load("images/NJALogo.png", NJA_TAIL = "file")
load("math.star", "math")
load("render.star", "canvas", "render")
load("schema.star", "schema")

SHAPES = {
    "airliner": {"1x": AIRLINER_ASSET, "2x": AIRLINER_ASSET_2X},
    "balloon": {"1x": BALLOON_ASSET, "2x": BALLOON_ASSET_2X},
    "cessna": {"1x": CESSNA_ASSET, "2x": CESSNA_ASSET_2X},
    "heavy_2e": {"1x": HEAVY_2E_ASSET, "2x": HEAVY_2E_ASSET_2X},
    "heavy_4e": {"1x": HEAVY_4E_ASSET, "2x": HEAVY_4E_ASSET_2X},
    "helicopter": {"1x": HELICOPTER_ASSET, "2x": HELICOPTER_ASSET_2X},
    "hi_perf": {"1x": HI_PERF_ASSET, "2x": HI_PERF_ASSET_2X},
    "jet_nonswept": {"1x": JET_NONSWEPT_ASSET, "2x": JET_NONSWEPT_ASSET_2X},
    "jet_swept": {"1x": JET_SWEPT_ASSET, "2x": JET_SWEPT_ASSET_2X},
    "twin_large": {"1x": TWIN_LARGE_ASSET, "2x": TWIN_LARGE_ASSET_2X},
    "twin_small": {"1x": TWIN_SMALL_ASSET, "2x": TWIN_SMALL_ASSET_2X},
    "ground_emergency": {"1x": GROUND_EMERGENCY_ASSET, "2x": GROUND_EMERGENCY_ASSET_2X},
    "ground_service": {"1x": GROUND_SERVICE_ASSET, "2x": GROUND_SERVICE_ASSET_2X},
    "ground_unknown": {"1x": GROUND_UNKNOWN_ASSET, "2x": GROUND_UNKNOWN_ASSET_2X},
    "ground_fixed": {"1x": GROUND_FIXED_ASSET, "2x": GROUND_FIXED_ASSET_2X},
    "unknown": {"1x": UNKNOWN_ASSET, "2x": UNKNOWN_ASSET_2X},
}

TYPE_DESIGNATOR_ICONS = {
    "A10": "hi_perf",
    "A148": "hi_perf",
    "A225": "heavy_4e",
    "A3": "hi_perf",
    "A37": "jet_nonswept",
    "A5": "cessna",
    "A6": "hi_perf",
    "A700": "jet_nonswept",
    "AC80": "twin_small",
    "AC90": "twin_small",
    "AC95": "twin_small",
    "AJ27": "jet_nonswept",
    "AJET": "hi_perf",
    "AN28": "twin_small",
    "ARCE": "hi_perf",
    "AT3": "hi_perf",
    "ATG1": "jet_nonswept",
    "B18T": "twin_small",
    "B190": "twin_small",
    "B25": "twin_large",
    "B350": "twin_small",
    "B52": "heavy_4e",
    "B712": "jet_swept",
    "B721": "airliner",
    "B722": "airliner",
    "BALL": "balloon",
    "BE10": "twin_small",
    "BE20": "twin_small",
    "BE30": "twin_small",
    "BE32": "twin_small",
    "BE40": "jet_nonswept",
    "BE99": "twin_small",
    "BE9L": "twin_small",
    "BE9T": "twin_small",
    "BN2T": "twin_small",
    "BPOD": "jet_swept",
    "BU20": "twin_small",
    "C08T": "jet_swept",
    "C125": "twin_small",
    "C212": "twin_small",
    "C21T": "twin_small",
    "C22J": "jet_nonswept",
    "C25A": "jet_nonswept",
    "C25B": "jet_nonswept",
    "C25C": "jet_nonswept",
    "C25M": "jet_nonswept",
    "C425": "twin_small",
    "C441": "twin_small",
    "C46": "twin_large",
    "C500": "jet_nonswept",
    "C501": "jet_nonswept",
    "C510": "jet_nonswept",
    "C525": "jet_nonswept",
    "C526": "jet_nonswept",
    "C550": "jet_nonswept",
    "C551": "jet_nonswept",
    "C55B": "jet_nonswept",
    "C560": "jet_nonswept",
    "C56X": "jet_nonswept",
    "C650": "jet_swept",
    "C680": "jet_nonswept",
    "C68A": "jet_nonswept",
    "C750": "jet_swept",
    "C82": "twin_large",
    "CKUO": "hi_perf",
    "CL30": "jet_swept",
    "CL35": "jet_swept",
    "CL60": "jet_swept",
    "CRJ1": "jet_swept",
    "CRJ2": "jet_swept",
    "CRJ7": "jet_swept",
    "CRJ9": "jet_swept",
    "CRJX": "jet_swept",
    "CVLP": "twin_large",
    "D228": "twin_small",
    "DA36": "hi_perf",
    "DA50": "airliner",
    "DC10": "heavy_2e",
    "DC3": "twin_large",
    "DC3S": "twin_large",
    "DHA3": "twin_small",
    "DHC4": "twin_large",
    "DHC6": "twin_small",
    "DLH2": "hi_perf",
    "E110": "twin_small",
    "E135": "jet_swept",
    "E145": "jet_swept",
    "E29E": "hi_perf",
    "E45X": "jet_swept",
    "E500": "jet_nonswept",
    "E50P": "jet_nonswept",
    "E545": "jet_swept",
    "E55P": "jet_nonswept",
    "EA50": "jet_nonswept",
    "EFAN": "jet_nonswept",
    "EFUS": "hi_perf",
    "ELIT": "jet_nonswept",
    "EUFI": "hi_perf",
    "F1": "hi_perf",
    "F100": "jet_swept",
    "F111": "hi_perf",
    "F117": "hi_perf",
    "F14": "hi_perf",
    "F15": "hi_perf",
    "F22": "hi_perf",
    "F2TH": "jet_swept",
    "F4": "hi_perf",
    "F406": "twin_small",
    "F5": "hi_perf",
    "F900": "jet_swept",
    "FA50": "jet_swept",
    "FA5X": "jet_swept",
    "FA7X": "jet_swept",
    "FA8X": "jet_swept",
    "FJ10": "jet_nonswept",
    "FOUG": "jet_nonswept",
    "FURY": "hi_perf",
    "G150": "jet_swept",
    "G3": "airliner",
    "GENI": "hi_perf",
    "GL5T": "jet_swept",
    "GLEX": "jet_swept",
    "GLF2": "jet_swept",
    "GLF3": "jet_swept",
    "GLF4": "jet_swept",
    "GLF5": "jet_swept",
    "GLF6": "jet_swept",
    "GSPN": "jet_nonswept",
    "H25A": "jet_swept",
    "H25B": "jet_swept",
    "H25C": "jet_swept",
    "HA4T": "airliner",
    "HDJT": "jet_nonswept",
    "HERN": "jet_swept",
    "J8A": "hi_perf",
    "J8B": "hi_perf",
    "JH7": "hi_perf",
    "JS31": "twin_small",
    "JS32": "twin_small",
    "JU52": "twin_small",
    "L101": "heavy_2e",
    "LAE1": "hi_perf",
    "LEOP": "jet_nonswept",
    "LJ23": "jet_nonswept",
    "LJ24": "jet_nonswept",
    "LJ25": "jet_nonswept",
    "LJ28": "jet_nonswept",
    "LJ31": "jet_nonswept",
    "LJ35": "jet_nonswept",
    "LJ40": "jet_nonswept",
    "LJ45": "jet_nonswept",
    "LJ55": "jet_nonswept",
    "LJ60": "jet_nonswept",
    "LJ70": "jet_nonswept",
    "LJ75": "jet_nonswept",
    "LJ85": "jet_nonswept",
    "LTNG": "hi_perf",
    "M28": "twin_small",
    "MD11": "heavy_2e",
    "MD81": "jet_swept",
    "MD82": "jet_swept",
    "MD83": "jet_swept",
    "MD87": "jet_swept",
    "MD88": "jet_swept",
    "MD90": "jet_swept",
    "ME62": "jet_nonswept",
    "METR": "hi_perf",
    "MG19": "hi_perf",
    "MG25": "hi_perf",
    "MG29": "hi_perf",
    "MG31": "hi_perf",
    "MG44": "hi_perf",
    "MH02": "jet_nonswept",
    "MS76": "jet_nonswept",
    "MT2": "hi_perf",
    "MU2": "twin_small",
    "P180": "twin_small",
    "P2": "twin_large",
    "P68T": "twin_small",
    "PA47": "jet_nonswept",
    "PAT4": "twin_small",
    "PAY1": "twin_small",
    "PAY2": "twin_small",
    "PAY3": "twin_small",
    "PAY4": "twin_small",
    "PIAE": "hi_perf",
    "PIT4": "hi_perf",
    "PITE": "hi_perf",
    "PRM1": "jet_nonswept",
    "PRTS": "jet_nonswept",
    "Q5": "hi_perf",
    "R721": "airliner",
    "R722": "airliner",
    "RFAL": "hi_perf",
    "ROAR": "hi_perf",
    "S3": "hi_perf",
    "S32E": "hi_perf",
    "S37": "hi_perf",
    "S601": "jet_nonswept",
    "SATA": "jet_nonswept",
    "SB05": "jet_nonswept",
    "SC7": "twin_small",
    "SF50": "jet_nonswept",
    "SJ30": "jet_nonswept",
    "SLCH": "heavy_4e",
    "SM60": "twin_small",
    "SOL1": "jet_swept",
    "SOL2": "jet_swept",
    "SP33": "jet_nonswept",
    "SR71": "hi_perf",
    "SS2": "hi_perf",
    "SU15": "hi_perf",
    "SU24": "hi_perf",
    "SU25": "hi_perf",
    "SU27": "hi_perf",
    "SW2": "twin_small",
    "SW3": "twin_small",
    "SW4": "twin_small",
    "T154": "airliner",
    "T2": "jet_nonswept",
    "T22M": "hi_perf",
    "T37": "jet_nonswept",
    "T38": "jet_nonswept",
    "T4": "hi_perf",
    "TJET": "jet_nonswept",
    "TOR": "hi_perf",
    "TRIM": "twin_small",
    "TRIS": "twin_small",
    "TRMA": "twin_small",
    "TU22": "hi_perf",
    "VAUT": "hi_perf",
    "Y130": "hi_perf",
    "Y141": "airliner",
    "YK28": "hi_perf",
    "YK38": "airliner",
    "YK40": "airliner",
    "YK42": "airliner",
    "YURO": "hi_perf",
}
TYPE_DESCRIPTION_ICONS = {
    "H": "helicopter",
    "L1P": "cessna",
    "L1T": "cessna",
    "L1J": "hi_perf",
    "L2P": "twin_small",
    "L2T": "twin_large",
    "L2J-L": "jet_swept",
    "L2J-M": "airliner",
    "L2J-H": "heavy_2e",
    "L4T": "heavy_4e",
    "L4J-H": "heavy_4e",
}
CATEGORY_ICONS = {
    "A1": "cessna",
    "A2": "jet_nonswept",
    "A3": "airliner",
    "A4": "heavy_2e",
    "A5": "heavy_4e",
    "A6": "hi_perf",
    "A7": "helicopter",
    "B1": "cessna",
    "B2": "balloon",
    "B4": "cessna",
    "B7": "hi_perf",
    "C0": "ground_unknown",
    "C1": "ground_emergency",
    "C2": "ground_service",
    "C3": "ground_fixed",
    "C4": "ground_fixed",
    "C5": "ground_fixed",
    "C6": "ground_unknown",
    "C7": "ground_unknown",
}
DB = {
    "A002": {
        "desc": "G1P",
        "wtc": "L",
    },
    "A1": {
        "desc": "L1P",
        "wtc": "M",
    },
    "A10": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A109": {
        "desc": "G1P",
        "wtc": "L",
    },
    "A119": {
        "desc": "H1T",
        "wtc": "L",
    },
    "A122": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A124": {
        "desc": "L4J",
        "wtc": "H",
    },
    "A129": {
        "desc": "H2T",
        "wtc": "L",
    },
    "A139": {
        "desc": "H2T",
        "wtc": "L",
    },
    "A140": {
        "desc": "L2T",
        "wtc": "M",
    },
    "A148": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A149": {
        "desc": "H2T",
        "wtc": "M",
    },
    "A158": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A16": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A169": {
        "desc": "H2T",
        "wtc": "L",
    },
    "A189": {
        "desc": "H2T",
        "wtc": "M",
    },
    "A19": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A20": {
        "desc": "L2P",
        "wtc": "M",
    },
    "A205": {
        "desc": "G1P",
        "wtc": "L",
    },
    "A21": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A210": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A211": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A22": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A223": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A225": {
        "desc": "L6J",
        "wtc": "H",
    },
    "A23": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A25": {
        "desc": "A1P",
        "wtc": "L",
    },
    "A251": {
        "desc": "A2P",
        "wtc": "L",
    },
    "A27": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A270": {
        "desc": "L1T",
        "wtc": "L",
    },
    "A29": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A2RT": {
        "desc": "H2T",
        "wtc": "L",
    },
    "A3": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A306": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A30B": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A31": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A310": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A318": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A319": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A19N": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A320": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A20N": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A321": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A21N": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A33": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A330": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A332": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A333": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A338": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A339": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A342": {
        "desc": "L4J",
        "wtc": "H",
    },
    "A343": {
        "desc": "L4J",
        "wtc": "H",
    },
    "A345": {
        "desc": "L4J",
        "wtc": "H",
    },
    "A346": {
        "desc": "L4J",
        "wtc": "H",
    },
    "A35": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A358": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A359": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A35K": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A37": {
        "desc": "L2J",
        "wtc": "L",
    },
    "A388": {
        "desc": "L4J",
        "wtc": "H",
    },
    "A3ST": {
        "desc": "L2J",
        "wtc": "H",
    },
    "A4": {
        "desc": "L1J",
        "wtc": "M",
    },
    "A400": {
        "desc": "L4T",
        "wtc": "H",
    },
    "A5": {
        "desc": "A1P",
        "wtc": "L",
    },
    "A50": {
        "desc": "L4J",
        "wtc": "H",
    },
    "A500": {
        "desc": "L2P",
        "wtc": "L",
    },
    "A504": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A6": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A600": {
        "desc": "H1P",
        "wtc": "L",
    },
    "A660": {
        "desc": "L1T",
        "wtc": "L",
    },
    "A7": {
        "desc": "L1J",
        "wtc": "M",
    },
    "A700": {
        "desc": "L2J",
        "wtc": "L",
    },
    "A743": {
        "desc": "L2J",
        "wtc": "M",
    },
    "A748": {
        "desc": "L2T",
        "wtc": "M",
    },
    "A890": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A9": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A900": {
        "desc": "L1P",
        "wtc": "L",
    },
    "A910": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AA1": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AA37": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AA5": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AAT3": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AAT4": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AB11": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AB15": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AB18": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AB95": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AC10": {
        "desc": "G1P",
        "wtc": "L",
    },
    "AC11": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AC31": {
        "desc": "H1T",
        "wtc": "L",
    },
    "AC33": {
        "desc": "H3T",
        "wtc": "M",
    },
    "AC4": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AC50": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AC52": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AC56": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AC5A": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AC5M": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AC68": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AC6L": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AC72": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AC80": {
        "desc": "L2T",
        "wtc": "L",
    },
    "AC90": {
        "desc": "L2T",
        "wtc": "L",
    },
    "AC95": {
        "desc": "L2T",
        "wtc": "L",
    },
    "ACAM": {
        "desc": "L2P",
        "wtc": "L",
    },
    "ACAR": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ACED": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ACJR": {
        "desc": "A1P",
        "wtc": "L",
    },
    "ACPL": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ACR2": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ACRD": {
        "desc": "L2P",
        "wtc": "L",
    },
    "ACRO": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ACSR": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AD20": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ADEL": {
        "desc": "G1P",
        "wtc": "L",
    },
    "ADVE": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ADVN": {
        "desc": "A1P",
        "wtc": "L",
    },
    "AE45": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AEA1": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AERK": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AEST": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AFOX": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AG02": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AGSH": {
        "desc": "A1P",
        "wtc": "L",
    },
    "AI10": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AIGT": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AIRD": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AIRL": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AJ27": {
        "desc": "L2J",
        "wtc": "M",
    },
    "AJET": {
        "desc": "L2J",
        "wtc": "M",
    },
    "AK1": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AKOY": {
        "desc": "A1P",
        "wtc": "L",
    },
    "AKRO": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ALBU": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ALC1": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ALGR": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ALH": {
        "desc": "H2T",
        "wtc": "L",
    },
    "ALIG": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ALIZ": {
        "desc": "L1T",
        "wtc": "M",
    },
    "ALO2": {
        "desc": "H1T",
        "wtc": "L",
    },
    "ALO3": {
        "desc": "H1T",
        "wtc": "L",
    },
    "ALPI": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ALSL": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ALTO": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AM3": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AMX": {
        "desc": "L1J",
        "wtc": "M",
    },
    "AN12": {
        "desc": "L4T",
        "wtc": "M",
    },
    "AN2": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AN22": {
        "desc": "L4T",
        "wtc": "H",
    },
    "AN24": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AN26": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AN28": {
        "desc": "L2T",
        "wtc": "L",
    },
    "AN3": {
        "desc": "L1T",
        "wtc": "L",
    },
    "AN30": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AN32": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AN38": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AN70": {
        "desc": "L4T",
        "wtc": "M",
    },
    "AN72": {
        "desc": "L2J",
        "wtc": "M",
    },
    "AN8": {
        "desc": "L2T",
        "wtc": "M",
    },
    "ANGL": {
        "desc": "L2P",
        "wtc": "L",
    },
    "ANSN": {
        "desc": "L2P",
        "wtc": "L",
    },
    "ANST": {
        "desc": "H2T",
        "wtc": "L",
    },
    "AP20": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AP22": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AP24": {
        "desc": "A1P",
        "wtc": "L",
    },
    "AP26": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AP28": {
        "desc": "L2P",
        "wtc": "L",
    },
    "AP36": {
        "desc": "L2P",
        "wtc": "L",
    },
    "APM2": {
        "desc": "L1P",
        "wtc": "L",
    },
    "APM3": {
        "desc": "L1P",
        "wtc": "L",
    },
    "APM4": {
        "desc": "L1P",
        "wtc": "L",
    },
    "APUP": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AR11": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AR15": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AR50": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AR5T": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AR65": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AR6T": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AR79": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ARCE": {
        "desc": "L1E",
        "wtc": "L",
    },
    "ARCP": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ARES": {
        "desc": "L1J",
        "wtc": "L",
    },
    "ARKS": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ARON": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ARV1": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ARVA": {
        "desc": "L2T",
        "wtc": "L",
    },
    "ARWF": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS02": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS14": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS16": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS20": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS21": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS22": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS24": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS25": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS26": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS28": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS29": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS2T": {
        "desc": "L1T",
        "wtc": "L",
    },
    "AS30": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS31": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AS32": {
        "desc": "H2T",
        "wtc": "M",
    },
    "AS3B": {
        "desc": "H2T",
        "wtc": "M",
    },
    "AS50": {
        "desc": "H1T",
        "wtc": "L",
    },
    "AS55": {
        "desc": "H2T",
        "wtc": "L",
    },
    "AS65": {
        "desc": "H2T",
        "wtc": "L",
    },
    "AS80": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ASO4": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ASTO": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ASTR": {
        "desc": "L2J",
        "wtc": "M",
    },
    "AT2P": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AT3": {
        "desc": "L2J",
        "wtc": "M",
    },
    "AT3P": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AT3T": {
        "desc": "L1T",
        "wtc": "L",
    },
    "AT43": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AT44": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AT45": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AT46": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AT5P": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AT5T": {
        "desc": "L1T",
        "wtc": "L",
    },
    "AT6T": {
        "desc": "L1T",
        "wtc": "L",
    },
    "AT72": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AT73": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AT75": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AT76": {
        "desc": "L2T",
        "wtc": "M",
    },
    "AT8T": {
        "desc": "L1T",
        "wtc": "L",
    },
    "ATAC": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ATG1": {
        "desc": "L2J",
        "wtc": "L",
    },
    "ATIS": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ATL": {
        "desc": "L1P",
        "wtc": "L",
    },
    "ATLA": {
        "desc": "L2T",
        "wtc": "M",
    },
    "ATP": {
        "desc": "L2T",
        "wtc": "M",
    },
    "ATTL": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AU11": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AUJ2": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AUJ4": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AUS3": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AUS4": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AUS5": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AUS6": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AUS7": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AUS9": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AV68": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AVAM": {
        "desc": "A1P",
        "wtc": "L",
    },
    "AVID": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AVIN": {
        "desc": "L1P",
        "wtc": "L",
    },
    "AVK4": {
        "desc": "L2T",
        "wtc": "L",
    },
    "AVLN": {
        "desc": "A1T",
        "wtc": "L",
    },
    "AVTR": {
        "desc": "A1P",
        "wtc": "L",
    },
    "B06": {
        "desc": "H1T",
        "wtc": "L",
    },
    "B06T": {
        "desc": "H2T",
        "wtc": "L",
    },
    "B1": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B103": {
        "desc": "A2P",
        "wtc": "L",
    },
    "B105": {
        "desc": "H2T",
        "wtc": "L",
    },
    "B13": {
        "desc": "L1P",
        "wtc": "L",
    },
    "B14A": {
        "desc": "L1P",
        "wtc": "L",
    },
    "B14B": {
        "desc": "L1P",
        "wtc": "L",
    },
    "B14C": {
        "desc": "L1P",
        "wtc": "L",
    },
    "B150": {
        "desc": "H1T",
        "wtc": "L",
    },
    "B17": {
        "desc": "L4P",
        "wtc": "M",
    },
    "B18T": {
        "desc": "L2T",
        "wtc": "L",
    },
    "B190": {
        "desc": "L2T",
        "wtc": "M",
    },
    "B2": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B209": {
        "desc": "L1P",
        "wtc": "L",
    },
    "B212": {
        "desc": "H2T",
        "wtc": "L",
    },
    "B214": {
        "desc": "H1T",
        "wtc": "M",
    },
    "B222": {
        "desc": "H2T",
        "wtc": "L",
    },
    "B23": {
        "desc": "L2P",
        "wtc": "M",
    },
    "B230": {
        "desc": "H2T",
        "wtc": "L",
    },
    "B24": {
        "desc": "L4P",
        "wtc": "M",
    },
    "B25": {
        "desc": "L2P",
        "wtc": "M",
    },
    "B26": {
        "desc": "L2P",
        "wtc": "M",
    },
    "B26M": {
        "desc": "L2P",
        "wtc": "M",
    },
    "B29": {
        "desc": "L4P",
        "wtc": "M",
    },
    "B305": {
        "desc": "H1P",
        "wtc": "L",
    },
    "B350": {
        "desc": "L2T",
        "wtc": "L",
    },
    "B360": {
        "desc": "L1P",
        "wtc": "L",
    },
    "B36T": {
        "desc": "L1T",
        "wtc": "L",
    },
    "B407": {
        "desc": "H1T",
        "wtc": "L",
    },
    "B412": {
        "desc": "H2T",
        "wtc": "L",
    },
    "B427": {
        "desc": "H2T",
        "wtc": "L",
    },
    "B429": {
        "desc": "H2T",
        "wtc": "L",
    },
    "B430": {
        "desc": "H2T",
        "wtc": "L",
    },
    "B461": {
        "desc": "L4J",
        "wtc": "M",
    },
    "B462": {
        "desc": "L4J",
        "wtc": "M",
    },
    "B463": {
        "desc": "L4J",
        "wtc": "M",
    },
    "B47G": {
        "desc": "H1P",
        "wtc": "L",
    },
    "B47J": {
        "desc": "H1P",
        "wtc": "L",
    },
    "B47T": {
        "desc": "H1T",
        "wtc": "L",
    },
    "B52": {
        "desc": "L8J",
        "wtc": "H",
    },
    "B525": {
        "desc": "H2T",
        "wtc": "M",
    },
    "B58T": {
        "desc": "L2P",
        "wtc": "L",
    },
    "B60": {
        "desc": "L1P",
        "wtc": "L",
    },
    "B609": {
        "desc": "T2T",
        "wtc": "M",
    },
    "B60T": {
        "desc": "L2T",
        "wtc": "L",
    },
    "B701": {
        "desc": "L4J",
        "wtc": "M",
    },
    "B703": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B712": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B720": {
        "desc": "L4J",
        "wtc": "M",
    },
    "B721": {
        "desc": "L3J",
        "wtc": "M",
    },
    "B722": {
        "desc": "L3J",
        "wtc": "M",
    },
    "B731": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B732": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B733": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B734": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B735": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B736": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B737": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B738": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B739": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B37M": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B38M": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B39M": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B741": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B742": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B743": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B744": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B748": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B74D": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B74R": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B74S": {
        "desc": "L4J",
        "wtc": "H",
    },
    "B752": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B753": {
        "desc": "L2J",
        "wtc": "M",
    },
    "B762": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B763": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B764": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B772": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B773": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B778": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B779": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B77L": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B77W": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B788": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B789": {
        "desc": "L2J",
        "wtc": "H",
    },
    "B78X": {
        "desc": "L2J",
        "wtc": "H",
    },
    "BA11": {
        "desc": "L2J",
        "wtc": "M",
    },
    "BABY": {
        "desc": "H1P",
        "wtc": "L",
    },
    "BAR6": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BARC": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BASS": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BBAT": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BBIR": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BCA3": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BCAT": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BCS1": {
        "desc": "L2J",
        "wtc": "M",
    },
    "BCS3": {
        "desc": "L2J",
        "wtc": "M",
    },
    "BD10": {
        "desc": "L1J",
        "wtc": "L",
    },
    "BD12": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BD17": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BD4": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BD5": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BD5J": {
        "desc": "L1J",
        "wtc": "L",
    },
    "BD5T": {
        "desc": "L1T",
        "wtc": "L",
    },
    "BDOG": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BE10": {
        "desc": "L2T",
        "wtc": "L",
    },
    "BE12": {
        "desc": "A2T",
        "wtc": "M",
    },
    "BE17": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BE18": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE19": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BE20": {
        "desc": "L2T",
        "wtc": "L",
    },
    "BE23": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BE24": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BE30": {
        "desc": "L2T",
        "wtc": "L",
    },
    "BE32": {
        "desc": "L2T",
        "wtc": "M",
    },
    "BE33": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BE35": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BE36": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BE40": {
        "desc": "L2J",
        "wtc": "M",
    },
    "BE45": {
        "desc": "L2J",
        "wtc": "M",
    },
    "BE50": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE55": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE56": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE58": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE60": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE65": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE70": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE76": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE77": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BE80": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE88": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE95": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BE99": {
        "desc": "L2T",
        "wtc": "L",
    },
    "BE9L": {
        "desc": "L2T",
        "wtc": "L",
    },
    "BE9T": {
        "desc": "L2T",
        "wtc": "L",
    },
    "BEAR": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BELF": {
        "desc": "L4T",
        "wtc": "M",
    },
    "BER2": {
        "desc": "A2J",
        "wtc": "M",
    },
    "BER4": {
        "desc": "A2J",
        "wtc": "M",
    },
    "BETA": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BEVR": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BF19": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BFIT": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BILO": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BIPL": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BIRD": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BISC": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BK17": {
        "desc": "H2T",
        "wtc": "L",
    },
    "BKUT": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BL11": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BL17": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BL19": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BL8": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BLBU": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BLCF": {
        "desc": "L4J",
        "wtc": "H",
    },
    "BLEN": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BLKS": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BM6": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BMAN": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BN2P": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BN2T": {
        "desc": "L2T",
        "wtc": "L",
    },
    "BOLT": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BOOM": {
        "desc": "L2P",
        "wtc": "L",
    },
    "BPAT": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BPOD": {
        "desc": "L4E",
        "wtc": "L",
    },
    "BR14": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BR54": {
        "desc": "G1P",
        "wtc": "L",
    },
    "BR60": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BR61": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BRAV": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BRB2": {
        "desc": "H1P",
        "wtc": "L",
    },
    "BREZ": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BROU": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BS60": {
        "desc": "L2T",
        "wtc": "L",
    },
    "BSCA": {
        "desc": "L4J",
        "wtc": "H",
    },
    "BSTP": {
        "desc": "H2T",
        "wtc": "M",
    },
    "BSTR": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BT36": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BTUB": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BU20": {
        "desc": "L3P",
        "wtc": "L",
    },
    "BU31": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BU33": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BU81": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BUC": {
        "desc": "L2J",
        "wtc": "M",
    },
    "BUCA": {
        "desc": "A1P",
        "wtc": "L",
    },
    "BULT": {
        "desc": "L1P",
        "wtc": "L",
    },
    "BX2": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C02T": {
        "desc": "L2T",
        "wtc": "L",
    },
    "C04T": {
        "desc": "L2T",
        "wtc": "L",
    },
    "C06T": {
        "desc": "L1T",
        "wtc": "L",
    },
    "C07T": {
        "desc": "L1T",
        "wtc": "L",
    },
    "C08T": {
        "desc": "LCT",
        "wtc": "L",
    },
    "C1": {
        "desc": "L2J",
        "wtc": "M",
    },
    "C101": {
        "desc": "L1J",
        "wtc": "L",
    },
    "C10T": {
        "desc": "L1T",
        "wtc": "L",
    },
    "C119": {
        "desc": "L2P",
        "wtc": "M",
    },
    "C120": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C123": {
        "desc": "L2P",
        "wtc": "M",
    },
    "C125": {
        "desc": "L3P",
        "wtc": "M",
    },
    "C130": {
        "desc": "L4T",
        "wtc": "M",
    },
    "C133": {
        "desc": "L4T",
        "wtc": "M",
    },
    "C135": {
        "desc": "L4J",
        "wtc": "H",
    },
    "C140": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C141": {
        "desc": "L4J",
        "wtc": "H",
    },
    "C14T": {
        "desc": "L2T",
        "wtc": "L",
    },
    "C15": {
        "desc": "L4J",
        "wtc": "M",
    },
    "C150": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C152": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C160": {
        "desc": "L2T",
        "wtc": "M",
    },
    "C162": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C170": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C172": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C175": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C177": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C180": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C182": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C185": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C188": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C190": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C195": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C2": {
        "desc": "L2T",
        "wtc": "M",
    },
    "C205": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C206": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C207": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C208": {
        "desc": "L1T",
        "wtc": "L",
    },
    "C210": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C212": {
        "desc": "L2T",
        "wtc": "M",
    },
    "C21T": {
        "desc": "L2T",
        "wtc": "L",
    },
    "C22J": {
        "desc": "L2J",
        "wtc": "L",
    },
    "C240": {
        "desc": "L1P",
        "wtc": "L",
    },
    "C25A": {
        "desc": "L2J",
        "wtc": "L",
    },
    "C25B": {
        "desc": "L2J",
        "wtc": "L",
    },
    "C25C": {
        "desc": "L2J",
        "wtc": "M",
    },
    "C25M": {
        "desc": "L2J",
        "wtc": "L",
    },
    "C270": {
        "desc": "L1P",
        "wtc": "L",
    }, 
    # ... keep DB entries as originally present ...
}

def get_airplane_shape(flight):
    print(flight)
    if "aircraft_code" in flight:
        type_designator = flight["aircraft_code"]
    else:
        type_designator = None
    if type_designator in DB:
        x = DB[type_designator]
        type_description = x["desc"]
        wtc = x["wtc"]
    else:
        type_description = None
        wtc = None

    if type_designator in TYPE_DESIGNATOR_ICONS:
        return SHAPES[TYPE_DESIGNATOR_ICONS[type_designator]]

    if type_description != None and len(type_description) == 3:
        if wtc != None and len(wtc) == 1:
            type_description_with_wtc = type_description + "-" + wtc
            if type_description_with_wtc in TYPE_DESCRIPTION_ICONS:
                return SHAPES[TYPE_DESCRIPTION_ICONS[type_description_with_wtc]]

        if type_description in TYPE_DESCRIPTION_ICONS:
            return SHAPES[TYPE_DESCRIPTION_ICONS[type_description]]

        basic_type = type_description[0]
        if basic_type in TYPE_DESCRIPTION_ICONS:
            return SHAPES[TYPE_DESCRIPTION_ICONS[basic_type]]

    return SHAPES["unknown"]

def get_entity_status(ha_server, entity_id, token, show_dummy_info):
    if ha_server == None:
        #fail("Home Assistant server not configured")
        return None

    if entity_id == None:
        #fail("Entity ID not configured")
        return None

    if token == None:
        #fail("Bearer token not configured")
        return None
    if show_dummy_info == True:
        return None

    state_res = None
    cache_key = "%s.%s" % (ha_server, entity_id)
    cached_res = cache.get(cache_key)
    if cached_res != None:
        state_res = json.decode(cached_res)
    else:
        rep = http.get("%s/api/states/%s" % (ha_server, entity_id), headers = {
            "Authorization": "Bearer %s" % token,
        })
        if rep.status_code != 200:
            return None

        state_res = rep.json()
        cache.set(cache_key, rep.body(), ttl_seconds = 10)
    return state_res

def get_ha_location(base_url, token):
    url = "%s/api/config" % base_url
    res = http.get(url, headers = {"Authorization": "Bearer %s" % token, "content-type": "application/json"}, ttl_seconds = 86400)
    if res.status_code != 200:
        return None
    data = res.json()
    return data.get("latitude"), data.get("longitude")

def skip_execution():
    print("skip_execution")
    return []

def filter_flight(flight):
    # default filter - only show US registrations that end with QS
    reg = flight.get("aircraft_registration") or ""
    return reg.startswith("N") and reg.endswith("QS")

def debug_print(message, data = None):
    """Print debug messages when DEBUG_ENABLED is True"""
    if DEBUG_ENABLED:
        if data != None:
            print("[DEBUG] %s: %s" % (message, data))
        else:
            print("[DEBUG] %s" % message)

def main(config):
    #If hardcoding HA info in applet, replace values below with yours. REMOVE EVERYTHING AFTER THE = and add your values
    #For example, ha_server = "http://192.168.1.100:8123"
    #The config.get strings are only used for serving the applet via pixlet serve
    #ha_server, entity_id and token have to be updated with your own values.
    ha_server = config.get("homeassistant_server")  #Don't forget to include a port at the end of the URL if using one
    entity_id = config.get("homeassistant_entity_id")  #The FlightRadar24 Integration sensor, default is 'sensor.flightradar24_current_in_area'
    token = config.get("homeassistant_token")  #Your long lived access token
    show_all_aircraft = config.bool("show_all_aircraft")
    show_dummy_info = config.bool("show_dummy_info")

    airhex_url2 = config.get("airhex_tail_direction", "_30_30_f.png")
    if canvas.is2x():
        airhex_url2 = airhex_url2.replace("30_30", "60_60")
    airhex_url1 = "https://content.airhex.com/content/logos/airlines_"

    scale = 2 if canvas.is2x() else 1

    sorted_matches = []

    home_lat = None
    home_lon = None
    media_image = None

    if not ha_server or not entity_id or not token or show_dummy_info:
        # Dummy data for preview
        sorted_matches = [{
            "airline_icao": "EJA",
            "altitude": 35000,
            "flight_number": "EJA FAKE",
            "callsign": "EJA FAKE",
            "airport_origin_code_iata": "CMH",
            "airport_destination_code_iata": "OSU",
            "aircraft_code": "E55P",
            "heading": 270,
            "latitude": 39.9,
            "longitude": -104.9,
            "distance": 10,
            "ground_speed": 343,
        }]

        # Dummy home location for preview
        home_lat = 39.8
        home_lon = -105.0
    else:
        entity_status = get_entity_status(ha_server, entity_id, token)
        extracted_attributes = entity_status["attributes"] if entity_status and "attributes" in entity_status else dict()
        flights = extracted_attributes["flights"] if "flights" in extracted_attributes else dict()
        matches_filters = [flight for flight in flights if filter_flight(flight)]
        sorted_matches = sorted(
            matches_filters,
            key = lambda flight: flight["distance"],
            reverse = False,
        )

        loc = get_ha_location(ha_server, token)
        if loc:
            home_lat, home_lon = loc

    if len(sorted_matches) == 0:
        return skip_execution()

    if media_image == None:
        if sorted_matches[0].get("airline_icao") == 'EJA':
            media_image = NJA_TAIL.readall()
        elif "airline_icao" in sorted_matches[0] and sorted_matches[0]["airline_icao"]:
            res = http.get("%s%s%s" % (airhex_url1, sorted_matches[0]["airline_icao"], airhex_url2), ttl_seconds = 86400)
            media_image = res.body()
        else:
            # Use small icon as fallback for non-commercial
            airplane_shape = get_airplane_shape(sorted_matches[0])
            media_image = airplane_shape["2x"].readall() if canvas.is2x() else airplane_shape["1x"].readall()

    airplane_shape = get_airplane_shape(sorted_matches[0])

    # Always set tiny_ico
    tiny_ico = airplane_shape["2x"].readall() if canvas.is2x() else airplane_shape["1x"].readall()

    lines = []

    #make a list of lines we'd prefer to have in order, we'll display the top 3 of them.
    if "flight_number" in sorted_matches[0] and sorted_matches[0]["flight_number"]:
        lines.append(render.Text("%s" % sorted_matches[0]["flight_number"]))
    elif "callsign" in sorted_matches[0] and sorted_matches[0]["callsign"]:
        lines.append(render.Text("%s" % sorted_matches[0]["callsign"]))

    # origin/destination row (only if either exists)
    if (("airport_origin_code_iata" in sorted_matches[0] and sorted_matches[0]["airport_origin_code_iata"]) or
        ("airport_destination_code_iata" in sorted_matches[0] and sorted_matches[0]["airport_destination_code_iata"])):
        origin = sorted_matches[0].get("airport_origin_code_iata") or "?"
        destination = sorted_matches[0].get("airport_destination_code_iata") or "?"
        line = render.Row(
            expanded = True,
            main_align = "between_evenly",
            children = [
                render.Text(origin),
                render.Text("→", color = "#00a"),
                render.Text(destination),
            ],
        )
        lines.append(line)

    if "aircraft_code" in sorted_matches[0] and sorted_matches[0]["aircraft_code"] != None and tiny_ico:
        line = render.Row(
            children = [
                render.Box(
                    width = 10 * scale,
                    height = 10 * scale,
                    child = filter.Rotate(
                        child = render.Image(tiny_ico, height = 10 * scale),
                        angle = 0,
                    ),
                ),
                render.Text(" %s" % sorted_matches[0]["aircraft_code"]),
            ],
        )
        lines.append(line)
    elif "aircraft_code" in sorted_matches[0] and sorted_matches[0]["aircraft_code"] != None:
        line = render.Text("%s" % sorted_matches[0]["aircraft_code"])
        lines.append(line)

    display = render.Row(
        children = [
            render.Box(
                width = 28 * scale,
                #child = render.Image(ico),
                child = render.Image(src = media_image, height = 30 * scale, width = 30 * scale),
            ),
            render.Box(
                child = render.Column(
                    expanded = True,
                    main_align = "space_evenly",
                    children = lines[:3],
                ),
            ),
        ],
    )

    return render.Root(
        child = display,
    )

def get_schema():
    airhex_logo_option = [
        schema.Option(
            display = "Regular",
            value = "_30_30_t.png",
        ),
        schema.Option(
            display = "Flipped",
            value = "_30_30_f.png",
        ),
    ]

    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "homeassistant_server",
                name = "Home Assistant Server",
                desc = "URL of Home Assistant server",
                icon = "server",
            ),
            schema.Text(
                id = "homeassistant_token",
                name = "Bearer Token",
                icon = "key",
                desc = "Long-lived access token for Home Assistant",
            ),
            schema.Text(
                id = "homeassistant_entity_id",
                name = "Entity ID",
                icon = "play",
                desc = "Entity ID of the media player entity in Home Assistant",
            ),
            schema.Dropdown(
                id = "airhex_tail_direction",
                name = "Tail Direction",
                icon = "plane",
                desc = "Choose which tail logo you would like to use",
                default = airhex_logo_option[1].value,
                options = airhex_logo_option,
            ),
            schema.Toggle(
                id = "show_all_aircraft",
                name = "Show All Aircraft",
                desc = "Show all aircraft, not just commercial ones",
                icon = "plane",
                default = False,
            ),
            schema.Toggle(
                id = "show_dummy_info",
                name = "Show dummy info",
                desc = "Show the dummy info",
                icon = "plane",
                default = False,
            ),
            schema.Toggle(
                id = "debug_mode",
                name = "Debug Mode",
                desc = "Enable debug logging and error display",
                icon = "bug",
                default = False,
)
        ],
    )
