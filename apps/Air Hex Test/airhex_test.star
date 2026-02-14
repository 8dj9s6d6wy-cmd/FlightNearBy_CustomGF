"""
Test AirHex Logo URLs
"""

load("http.star", "http")
load("render.star", "render")

def main(config):
    # Test common airline codes
    test_codes = ["UAL", "AAL", "DAL", "SWA", "EJA", "GTX"]
    
    results = []
    
    for code in test_codes:
        # Try different size formats
        url_12 = "https://content.airhex.com/content/logos/airlines_%s_12_12_s.png" % code
        url_30 = "https://content.airhex.com/content/logos/airlines_%s_30_30_r.png" % code
        
        res_12 = http.get(url_12)
        res_30 = http.get(url_30)
        
        results.append("%s: 12=%d 30=%d" % (code, res_12.status_code, res_30.status_code))
    
    return render.Root(
        child = render.Column(
            children = [
                render.Text("AirHex Test:", font = "tom-thumb"),
                render.Marquee(
                    width = 64,
                    height = 24,
                    child = render.Column(
                        children = [render.Text(r, font = "tom-thumb") for r in results]
                    ),
                    scroll_direction = "vertical",
                ),
            ],
        ),
    )
