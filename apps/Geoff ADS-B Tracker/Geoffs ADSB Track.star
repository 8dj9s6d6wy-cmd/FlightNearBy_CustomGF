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


    {"start": 0x006000, "end": 0x006FFF, "country": "Mozambique", "flag_image": "Mozambique.png"},
    {"start": 0x008000, "end": 0x00FFFF, "country": "South Africa", "flag_image": "South_Africa.png"},
    {"start": 0x010000, "end": 0x017FFF, "country": "Egypt", "flag_image": "Egypt.png"},
    {"start": 0x018000, "end": 0x01FFFF, "country": "Libyan Arab Jamahiriya", "flag_image": "Libya.png"},
    {"start": 0x020000, "end": 0x027FFF, "country": "Morocco", "flag_image": "Morocco.png"},
    {"start": 0x028000, "end": 0x02FFFF, "country": "Tunisia", "flag_image": "Tunisia.png"},
    {"start": 0x030000, "end": 0x0303FF, "country": "Botswana", "flag_image": "Botswana.png"},
    {"start": 0x032000, "end": 0x032FFF, "country": "Burundi", "flag_image": "Burundi.png"},
    {"start": 0x034000, "end": 0x034FFF, "country": "Cameroon", "flag_image": "Cameroon.png"},
    {"start": 0x035000, "end": 0x0353FF, "country": "Comoros", "flag_image": "Comoros.png"},
    {"start": 0x036000, "end": 0x036FFF, "country": "Congo", "flag_image": "Republic_of_the_Congo.png"},
    {"start": 0x038000, "end": 0x038FFF, "country": "Cote d'Ivoire", "flag_image": "Cote_d_Ivoire.png"},
    {"start": 0x03E000, "end": 0x03EFFF, "country": "Gabon", "flag_image": "Gabon.png"},
    {"start": 0x040000, "end": 0x040FFF, "country": "Ethiopia", "flag_image": "Ethiopia.png"},
    {"start": 0x042000, "end": 0x042FFF, "country": "Equatorial Guinea", "flag_image": "Equatorial_Guinea.png"},
    {"start": 0x044000, "end": 0x044FFF, "country": "Ghana", "flag_image": "Ghana.png"},
    {"start": 0x046000, "end": 0x046FFF, "country": "Guinea", "flag_image": "Guinea.png"},
    {"start": 0x048000, "end": 0x0483FF, "country": "Guinea-Bissau", "flag_image": "Guinea_Bissau.png"},
    {"start": 0x04A000, "end": 0x04A3FF, "country": "Lesotho", "flag_image": "Lesotho.png"},
    {"start": 0x04C000, "end": 0x04CFFF, "country": "Kenya", "flag_image": "Kenya.png"},
    {"start": 0x050000, "end": 0x050FFF, "country": "Liberia", "flag_image": "Liberia.png"},
    {"start": 0x054000, "end": 0x054FFF, "country": "Madagascar", "flag_image": "Madagascar.png"},
    {"start": 0x058000, "end": 0x058FFF, "country": "Malawi", "flag_image": "Malawi.png"},
    {"start": 0x05A000, "end": 0x05A3FF, "country": "Maldives", "flag_image": "Maldives.png"},
    {"start": 0x05C000, "end": 0x05CFFF, "country": "Mali", "flag_image": "Mali.png"},
    {"start": 0x05E000, "end": 0x05E3FF, "country": "Mauritania", "flag_image": "Mauritania.png"},
    {"start": 0x060000, "end": 0x0603FF, "country": "Mauritius", "flag_image": "Mauritius.png"},
    {"start": 0x062000, "end": 0x062FFF, "country": "Niger", "flag_image": "Niger.png"},
    {"start": 0x064000, "end": 0x064FFF, "country": "Nigeria", "flag_image": "Nigeria.png"},
    {"start": 0x068000, "end": 0x068FFF, "country": "Uganda", "flag_image": "Uganda.png"},
    {"start": 0x06A000, "end": 0x06A3FF, "country": "Qatar", "flag_image": "Qatar.png"},
    {"start": 0x06C000, "end": 0x06CFFF, "country": "Central African Republic", "flag_image": "Central_African_Republic.png"},
    {"start": 0x06E000, "end": 0x06EFFF, "country": "Rwanda", "flag_image": "Rwanda.png"},
    {"start": 0x070000, "end": 0x070FFF, "country": "Senegal", "flag_image": "Senegal.png"},
    {"start": 0x074000, "end": 0x0743FF, "country": "Seychelles", "flag_image": "Seychelles.png"},
    {"start": 0x076000, "end": 0x0763FF, "country": "Sierra Leone", "flag_image": "Sierra_Leone.png"},
    {"start": 0x078000, "end": 0x078FFF, "country": "Somalia", "flag_image": "Somalia.png"},
    {"start": 0x07A000, "end": 0x07A3FF, "country": "Swaziland", "flag_image": "Swaziland.png"},
    {"start": 0x07C000, "end": 0x07CFFF, "country": "Sudan", "flag_image": "Sudan.png"},
    {"start": 0x080000, "end": 0x080FFF, "country": "Tanzania", "flag_image": "Tanzania.png"},
    {"start": 0x084000, "end": 0x084FFF, "country": "Chad", "flag_image": "Chad.png"},
    {"start": 0x088000, "end": 0x088FFF, "country": "Togo", "flag_image": "Togo.png"},
    {"start": 0x08A000, "end": 0x08AFFF, "country": "Zambia", "flag_image": "Zambia.png"},
    {"start": 0x08C000, "end": 0x08CFFF, "country": "DR Congo", "flag_image": "Democratic_Republic_of_the_Congo.png"},
    {"start": 0x090000, "end": 0x090FFF, "country": "Angola", "flag_image": "Angola.png"},
    {"start": 0x094000, "end": 0x0943FF, "country": "Benin", "flag_image": "Benin.png"},
    {"start": 0x096000, "end": 0x0963FF, "country": "Cape Verde", "flag_image": "Cape_Verde.png"},
    {"start": 0x098000, "end": 0x0983FF, "country": "Djibouti", "flag_image": "Djibouti.png"},
    {"start": 0x09A000, "end": 0x09AFFF, "country": "Gambia", "flag_image": "Gambia.png"},
    {"start": 0x09C000, "end": 0x09CFFF, "country": "Burkina Faso", "flag_image": "Burkina_Faso.png"},
    {"start": 0x09E000, "end": 0x09E3FF, "country": "Sao Tome and Principe", "flag_image": "Sao_Tome_and_Principe.png"},
    {"start": 0x0A0000, "end": 0x0A7FFF, "country": "Algeria", "flag_image": "Algeria.png"},
    {"start": 0x0A8000, "end": 0x0A8FFF, "country": "Bahamas", "flag_image": "Bahamas.png"},
    {"start": 0x0AA000, "end": 0x0AA3FF, "country": "Barbados", "flag_image": "Barbados.png"},
    {"start": 0x0AB000, "end": 0x0AB3FF, "country": "Belize", "flag_image": "Belize.png"},
    {"start": 0x0AC000, "end": 0x0ACFFF, "country": "Colombia", "flag_image": "Colombia.png"},
    {"start": 0x0AE000, "end": 0x0AEFFF, "country": "Costa Rica", "flag_image": "Costa_Rica.png"},
    {"start": 0x0B0000, "end": 0x0B0FFF, "country": "Cuba", "flag_image": "Cuba.png"},
    {"start": 0x0B2000, "end": 0x0B2FFF, "country": "El Salvador", "flag_image": "El_Salvador.png"},
    {"start": 0x0B4000, "end": 0x0B4FFF, "country": "Guatemala", "flag_image": "Guatemala.png"},
    {"start": 0x0B6000, "end": 0x0B6FFF, "country": "Guyana", "flag_image": "Guyana.png"},
    {"start": 0x0B8000, "end": 0x0B8FFF, "country": "Haiti", "flag_image": "Haiti.png"},
    {"start": 0x0BA000, "end": 0x0BAFFF, "country": "Honduras", "flag_image": "Honduras.png"},
    {"start": 0x0BC000, "end": 0x0BC3FF, "country": "Saint Vincent and the Grenadines", "flag_image": "Saint_Vincent_and_the_Grenadines.png"},
    {"start": 0x0BE000, "end": 0x0BEFFF, "country": "Jamaica", "flag_image": "Jamaica.png"},
    {"start": 0x0C0000, "end": 0x0C0FFF, "country": "Nicaragua", "flag_image": "Nicaragua.png"},
    {"start": 0x0C2000, "end": 0x0C2FFF, "country": "Panama", "flag_image": "Panama.png"},
    {"start": 0x0C4000, "end": 0x0C4FFF, "country": "Dominican Republic", "flag_image": "Dominican_Republic.png"},
    {"start": 0x0C6000, "end": 0x0C6FFF, "country": "Trinidad and Tobago", "flag_image": "Trinidad_and_Tobago.png"},
    {"start": 0x0C8000, "end": 0x0C8FFF, "country": "Suriname", "flag_image": "Suriname.png"},
    {"start": 0x0CA000, "end": 0x0CA3FF, "country": "Antigua and Barbuda", "flag_image": "Antigua_and_Barbuda.png"},
    {"start": 0x0CC000, "end": 0x0CC3FF, "country": "Grenada", "flag_image": "Grenada.png"},
    {"start": 0x0D0000, "end": 0x0D7FFF, "country": "Mexico", "flag_image": "Mexico.png"},
    {"start": 0x0D8000, "end": 0x0DFFFF, "country": "Venezuela", "flag_image": "Venezuela.png"},
    {"start": 0x100000, "end": 0x1FFFFF, "country": "Russia", "flag_image": "Russian_Federation.png"},
    {"start": 0x201000, "end": 0x2013FF, "country": "Namibia", "flag_image": "Namibia.png"},
    {"start": 0x202000, "end": 0x2023FF, "country": "Eritrea", "flag_image": "Eritrea.png"},
    {"start": 0x300000, "end": 0x33FFFF, "country": "Italy", "flag_image": "Italy.png"},
    {"start": 0x340000, "end": 0x37FFFF, "country": "Spain", "flag_image": "Spain.png"},
    {"start": 0x380000, "end": 0x3BFFFF, "country": "France", "flag_image": "France.png"},
    {"start": 0x3C0000, "end": 0x3FFFFF, "country": "Germany", "flag_image": "Germany.png"},
    {"start": 0x400000, "end": 0x4001BF, "country": "Bermuda", "flag_image": "Bermuda.png"},
    {"start": 0x4001C0, "end": 0x4001FF, "country": "Cayman Islands", "flag_image": "Cayman_Islands.png"},
    {"start": 0x400300, "end": 0x4003FF, "country": "Turks and Caicos Islands", "flag_image": "Turks_and_Caicos_Islands.png"},
    {"start": 0x424135, "end": 0x4241F2, "country": "Cayman Islands", "flag_image": "Cayman_Islands.png"},
    {"start": 0x424200, "end": 0x4246FF, "country": "Bermuda", "flag_image": "Bermuda.png"},
    {"start": 0x424700, "end": 0x424899, "country": "Cayman Islands", "flag_image": "Cayman_Islands.png"},
    {"start": 0x424B00, "end": 0x424BFF, "country": "Isle of Man", "flag_image": "Isle_of_Man.png"},
    {"start": 0x43BE00, "end": 0x43BEFF, "country": "Bermuda", "flag_image": "Bermuda.png"},
    {"start": 0x43E700, "end": 0x43EAFD, "country": "Isle of Man", "flag_image": "Isle_of_Man.png"},
    {"start": 0x43EAFE, "end": 0x43EEFF, "country": "Guernsey", "flag_image": "Guernsey.png"},
    {"start": 0x400000, "end": 0x43FFFF, "country": "United Kingdom", "flag_image": "United_Kingdom.png"},
    {"start": 0x440000, "end": 0x447FFF, "country": "Austria", "flag_image": "Austria.png"},
    {"start": 0x448000, "end": 0x44FFFF, "country": "Belgium", "flag_image": "Belgium.png"},
    {"start": 0x450000, "end": 0x457FFF, "country": "Bulgaria", "flag_image": "Bulgaria.png"},
    {"start": 0x458000, "end": 0x45FFFF, "country": "Denmark", "flag_image": "Denmark.png"},
    {"start": 0x460000, "end": 0x467FFF, "country": "Finland", "flag_image": "Finland.png"},
    {"start": 0x468000, "end": 0x46FFFF, "country": "Greece", "flag_image": "Greece.png"},
    {"start": 0x470000, "end": 0x477FFF, "country": "Hungary", "flag_image": "Hungary.png"},
    {"start": 0x478000, "end": 0x47FFFF, "country": "Norway", "flag_image": "Norway.png"},
    {"start": 0x480000, "end": 0x487FFF, "country": "Kingdom of the Netherlands", "flag_image": "Netherlands.png"},
    {"start": 0x488000, "end": 0x48FFFF, "country": "Poland", "flag_image": "Poland.png"},
    {"start": 0x490000, "end": 0x497FFF, "country": "Portugal", "flag_image": "Portugal.png"},
    {"start": 0x498000, "end": 0x49FFFF, "country": "Czechia", "flag_image": "Czech_Republic.png"},
    {"start": 0x4A0000, "end": 0x4A7FFF, "country": "Romania", "flag_image": "Romania.png"},
    {"start": 0x4A8000, "end": 0x4AFFFF, "country": "Sweden", "flag_image": "Sweden.png"},
    {"start": 0x4B0000, "end": 0x4B7FFF, "country": "Switzerland", "flag_image": "Switzerland.png"},
    {"start": 0x4B8000, "end": 0x4BFFFF, "country": "Turkey", "flag_image": "Turkey.png"},
    {"start": 0x4C0000, "end": 0x4C7FFF, "country": "Serbia", "flag_image": "Serbia.png"},
    {"start": 0x4C8000, "end": 0x4C83FF, "country": "Cyprus", "flag_image": "Cyprus.png"},
    {"start": 0x4CA000, "end": 0x4CAFFF, "country": "Ireland", "flag_image": "Ireland.png"},
    {"start": 0x4CC000, "end": 0x4CCFFF, "country": "Iceland", "flag_image": "Iceland.png"},
    {"start": 0x4D0000, "end": 0x4D03FF, "country": "Luxembourg", "flag_image": "Luxembourg.png"},
    {"start": 0x4D2000, "end": 0x4D2FFF, "country": "Malta", "flag_image": "Malta.png"},
    {"start": 0x4D4000, "end": 0x4D43FF, "country": "Monaco", "flag_image": "Monaco.png"},
    {"start": 0x500000, "end": 0x5003FF, "country": "San Marino", "flag_image": "San_Marino.png"},
    {"start": 0x501000, "end": 0x5013FF, "country": "Albania", "flag_image": "Albania.png"},
    {"start": 0x501C00, "end": 0x501FFF, "country": "Croatia", "flag_image": "Croatia.png"},
    {"start": 0x502C00, "end": 0x502FFF, "country": "Latvia", "flag_image": "Latvia.png"},
    {"start": 0x503C00, "end": 0x503FFF, "country": "Lithuania", "flag_image": "Lithuania.png"},
    {"start": 0x504C00, "end": 0x504FFF, "country": "Moldova", "flag_image": "Moldova.png"},
    {"start": 0x505C00, "end": 0x505FFF, "country": "Slovakia", "flag_image": "Slovakia.png"},
    {"start": 0x506C00, "end": 0x506FFF, "country": "Slovenia", "flag_image": "Slovenia.png"},
    {"start": 0x507C00, "end": 0x507FFF, "country": "Uzbekistan", "flag_image": "Uzbekistan.png"},
    {"start": 0x508000, "end": 0x50FFFF, "country": "Ukraine", "flag_image": "Ukraine.png"},
    {"start": 0x510000, "end": 0x5103FF, "country": "Belarus", "flag_image": "Belarus.png"},
    {"start": 0x511000, "end": 0x5113FF, "country": "Estonia", "flag_image": "Estonia.png"},
    {"start": 0x512000, "end": 0x5123FF, "country": "Macedonia", "flag_image": "Macedonia.png"},
    {"start": 0x513000, "end": 0x5133FF, "country": "Bosnia and Herzegovina", "flag_image": "Bosnia.png"},
    {"start": 0x514000, "end": 0x5143FF, "country": "Georgia", "flag_image": "Georgia.png"},
    {"start": 0x515000, "end": 0x5153FF, "country": "Tajikistan", "flag_image": "Tajikistan.png"},
    {"start": 0x516000, "end": 0x5163FF, "country": "Montenegro", "flag_image": "Montenegro.png"},
    {"start": 0x600000, "end": 0x6003FF, "country": "Armenia", "flag_image": "Armenia.png"},
    {"start": 0x600800, "end": 0x600BFF, "country": "Azerbaijan", "flag_image": "Azerbaijan.png"},
    {"start": 0x601000, "end": 0x6013FF, "country": "Kyrgyzstan", "flag_image": "Kyrgyzstan.png"},
    {"start": 0x601800, "end": 0x601BFF, "country": "Turkmenistan", "flag_image": "Turkmenistan.png"},
    {"start": 0x680000, "end": 0x6803FF, "country": "Bhutan", "flag_image": "Bhutan.png"},
    {"start": 0x681000, "end": 0x6813FF, "country": "Micronesia, Federated States of", "flag_image": "Micronesia.png"},
    {"start": 0x682000, "end": 0x6823FF, "country": "Mongolia", "flag_image": "Mongolia.png"},
    {"start": 0x683000, "end": 0x6833FF, "country": "Kazakhstan", "flag_image": "Kazakhstan.png"},
    {"start": 0x684000, "end": 0x6843FF, "country": "Palau", "flag_image": "Palau.png"},
    {"start": 0x700000, "end": 0x700FFF, "country": "Afghanistan", "flag_image": "Afghanistan.png"},
    {"start": 0x702000, "end": 0x702FFF, "country": "Bangladesh", "flag_image": "Bangladesh.png"},
    {"start": 0x704000, "end": 0x704FFF, "country": "Myanmar", "flag_image": "Myanmar.png"},
    {"start": 0x706000, "end": 0x706FFF, "country": "Kuwait", "flag_image": "Kuwait.png"},
    {"start": 0x708000, "end": 0x708FFF, "country": "Laos", "flag_image": "Laos.png"},
    {"start": 0x70A000, "end": 0x70AFFF, "country": "Nepal", "flag_image": "Nepal.png"},
    {"start": 0x70C000, "end": 0x70C3FF, "country": "Oman", "flag_image": "Oman.png"},
    {"start": 0x70E000, "end": 0x70EFFF, "country": "Cambodia", "flag_image": "Cambodia.png"},
    {"start": 0x710000, "end": 0x717FFF, "country": "Saudi Arabia", "flag_image": "Saudi_Arabia.png"},
    {"start": 0x718000, "end": 0x71FFFF, "country": "South Korea", "flag_image": "South_Korea.png"},
    {"start": 0x720000, "end": 0x727FFF, "country": "North Korea", "flag_image": "North_Korea.png"},
    {"start": 0x728000, "end": 0x72FFFF, "country": "Iraq", "flag_image": "Iraq.png"},
    {"start": 0x730000, "end": 0x737FFF, "country": "Iran", "flag_image": "Iran.png"},
    {"start": 0x738000, "end": 0x73FFFF, "country": "Israel", "flag_image": "Israel.png"},
    {"start": 0x740000, "end": 0x747FFF, "country": "Jordan", "flag_image": "Jordan.png"},
    {"start": 0x748000, "end": 0x74FFFF, "country": "Lebanon", "flag_image": "Lebanon.png"},
    {"start": 0x750000, "end": 0x757FFF, "country": "Malaysia", "flag_image": "Malaysia.png"},
    {"start": 0x758000, "end": 0x75FFFF, "country": "Philippines", "flag_image": "Philippines.png"},
    {"start": 0x760000, "end": 0x767FFF, "country": "Pakistan", "flag_image": "Pakistan.png"},
    {"start": 0x768000, "end": 0x76FFFF, "country": "Singapore", "flag_image": "Singapore.png"},
    {"start": 0x770000, "end": 0x777FFF, "country": "Sri Lanka", "flag_image": "Sri_Lanka.png"},
    {"start": 0x778000, "end": 0x77FFFF, "country": "Syria", "flag_image": "Syria.png"},
    {"start": 0x789000, "end": 0x789FFF, "country": "Hong Kong", "flag_image": "Hong_Kong.png"},
    {"start": 0x780000, "end": 0x7BFFFF, "country": "China", "flag_image": "China.png"},
    {"start": 0x7C0000, "end": 0x7FFFFF, "country": "Australia", "flag_image": "Australia.png"},
    {"start": 0x800000, "end": 0x83FFFF, "country": "India", "flag_image": "India.png"},
    {"start": 0x840000, "end": 0x87FFFF, "country": "Japan", "flag_image": "Japan.png"},
    {"start": 0x880000, "end": 0x887FFF, "country": "Thailand", "flag_image": "Thailand.png"},
    {"start": 0x888000, "end": 0x88FFFF, "country": "Viet Nam", "flag_image": "Vietnam.png"},
    {"start": 0x890000, "end": 0x890FFF, "country": "Yemen", "flag_image": "Yemen.png"},
    {"start": 0x894000, "end": 0x894FFF, "country": "Bahrain", "flag_image": "Bahrain.png"},
    {"start": 0x895000, "end": 0x8953FF, "country": "Brunei", "flag_image": "Brunei.png"},
    {"start": 0x896000, "end": 0x896FFF, "country": "United Arab Emirates", "flag_image": "UAE.png"},
    {"start": 0x897000, "end": 0x8973FF, "country": "Solomon Islands", "flag_image": "Soloman_Islands.png"},
    {"start": 0x898000, "end": 0x898FFF, "country": "Papua New Guinea", "flag_image": "Papua_New_Guinea.png"},
    {"start": 0x899000, "end": 0x8993FF, "country": "Taiwan", "flag_image": "Taiwan.png"},
    {"start": 0x8A0000, "end": 0x8A7FFF, "country": "Indonesia", "flag_image": "Indonesia.png"},
    {"start": 0x900000, "end": 0x9003FF, "country": "Marshall Islands", "flag_image": "Marshall_Islands.png"},
    {"start": 0x901000, "end": 0x9013FF, "country": "Cook Islands", "flag_image": "Cook_Islands.png"},
    {"start": 0x902000, "end": 0x9023FF, "country": "Samoa", "flag_image": "Samoa.png"},
    {"start": 0xA00000, "end": 0xAFFFFF, "country": "United States", "flag_image": "United_States_of_America.png"},
    {"start": 0xC00000, "end": 0xC3FFFF, "country": "Canada", "flag_image": "Canada.png"},
    {"start": 0xC80000, "end": 0xC87FFF, "country": "New Zealand", "flag_image": "New_Zealand.png"},
    {"start": 0xC88000, "end": 0xC88FFF, "country": "Fiji", "flag_image": "Fiji.png"},
    {"start": 0xC8A000, "end": 0xC8A3FF, "country": "Nauru", "flag_image": "Nauru.png"},
    {"start": 0xC8C000, "end": 0xC8C3FF, "country": "Saint Lucia", "flag_image": "Saint_Lucia.png"},
    {"start": 0xC8D000, "end": 0xC8D3FF, "country": "Tonga", "flag_image": "Tonga.png"},
    {"start": 0xC8E000, "end": 0xC8E3FF, "country": "Kiribati", "flag_image": "Kiribati.png"},
    {"start": 0xC90000, "end": 0xC903FF, "country": "Vanuatu", "flag_image": "Vanuatu.png"},
    {"start": 0xE00000, "end": 0xE3FFFF, "country": "Argentina", "flag_image": "Argentina.png"},
    {"start": 0xE40000, "end": 0xE7FFFF, "country": "Brazil", "flag_image": "Brazil.png"},
    {"start": 0xE80000, "end": 0xE80FFF, "country": "Chile", "flag_image": "Chile.png"},
    {"start": 0xE84000, "end": 0xE84FFF, "country": "Ecuador", "flag_image": "Ecuador.png"},
    {"start": 0xE88000, "end": 0xE88FFF, "country": "Paraguay", "flag_image": "Paraguay.png"},
    {"start": 0xE8C000, "end": 0xE8CFFF, "country": "Peru", "flag_image": "Peru.png"},
    {"start": 0xE90000, "end": 0xE90FFF, "country": "Uruguay", "flag_image": "Uruguay.png"},
    {"start": 0xE94000, "end": 0xE94FFF, "country": "Bolivia", "flag_image": "Bolivia.png"},
    {"start": 0xF00000, "end": 0xF07FFF, "country": "ICAO (temporary)", "flag_image": "blank.png"},
    {"start": 0xF09000, "end": 0xF093FF, "country": "ICAO (special use)", "flag_image": "blank.png"},
    {"start": 0x200000, "end": 0x27FFFF, "country": "Unassigned (AFI region)", "flag_image": "blank.png"},
    {"start": 0x280000, "end": 0x28FFFF, "country": "Unassigned (SAM region)", "flag_image": "blank.png"},
    {"start": 0x500000, "end": 0x5FFFFF, "country": "Unassigned (EUR / NAT regions)", "flag_image": "blank.png"},
    {"start": 0x600000, "end": 0x67FFFF, "country": "Unassigned (MID region)", "flag_image": "blank.png"},
    {"start": 0x680000, "end": 0x6FFFFF, "country": "Unassigned (ASIA region)", "flag_image": "blank.png"},
    {"start": 0x900000, "end": 0x9FFFFF, "country": "Unassigned (NAM / PAC regions)", "flag_image": "blank.png"},
    {"start": 0xB00000, "end": 0xBFFFFF, "country": "Unassigned (reserved for future use)", "flag_image": "blank.png"},
    {"start": 0xEC0000, "end": 0xEFFFFF, "country": "Unassigned (CAR region)", "flag_image": "blank.png"},
    {"start": 0xD00000, "end": 0xDFFFFF, "country": "Unassigned (reserved for future use)", "flag_image": "blank.png"},
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
            category, designator, description, addrtype, color
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

    # Bottom bar: emergency > route > compass heading
    is_emergency = "squawk" in aircraft and aircraft["squawk"] in EMERGENCY_SQUAWKS
    if is_emergency:
        bottom_content = "%s: %s" % (aircraft["squawk"], EMERGENCY_SQUAWKS[aircraft["squawk"]])
        bottom_color = "#FF0000"
    elif route != None:
        # hexdb returns "ORIG-DEST"; replace dash with > for display
        bottom_content = route.replace("-", ">")
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

    # Prefix military owner for clarity
    if is_mil:
        owner = "[MIL] " + owner

    # Aircraft silhouette icon
    icon_alt = int(alt_baro) if alt_baro != "ground" else 0
    icon_color = get_altitude_icon_color(icon_alt)

    if dummy_mode != "none":
        icon_response = http.get(
            "https://tar1090tidbyt.azurewebsites.net/api/aircraft_icon" +
            "?category=%s&typeDesignator=%s&typeDescription=%s&addrtype=%s&color=%s" % (
                aircraft["category"], icao_type, type_desc, aircraft.get("type", "adsb_icao"), icon_color
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
    #  │  or FLIGHT   │  Sp: 450   (30px left | 34px right)          │
    #  │  EJA123      │  Dst: 8                                       │
    #  ├──────────────────────────────────────────────────────────────┤
    #  │  KLAS>KTEB   or   HDG: NW   or   7700: EMERGENCY (red)      │
    #  └──────────────────────────────────────────────────────────────┘

    if is_nja:
        left_children = [
            render.Image(src = NJA_TAIL.readall(), height = 10),
            render.Text(content = callsign, font = "tom-thumb"),
        ]
    else:
        left_children = [
            render.Text(content = "FLIGHT", font = "CG-pixel-4x5-mono"),
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
            # Bottom bar: route / heading / emergency
            render.Box(
                width = 64,
                height = 6,
                child = render.Marquee(
                    width = 64,
                    child = render.Text(
                        content = bottom_content,
                        font = "tom-thumb",
                        color = bottom_color,
                    ),
                    scroll_direction = "horizontal",
                    offset_start = 5,
                ),
            ),
        ],
        cross_align = "center",
    )

    # ── Frame 2 ───────────────────────────────────────────────────────────────
    #
    #  ┌──────────────────────────────────────────────────────────────┐
    #  │  [icon]  │  N123EJ                                          │
    #  │  18px    │  Citation                                         │
    #  │          │  Longitude    (46px right, tom-thumb)             │
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
