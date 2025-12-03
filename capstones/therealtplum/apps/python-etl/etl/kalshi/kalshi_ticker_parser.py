"""
Kalshi Ticker Parser

Parses Kalshi market tickers into structured metadata for human-readable display names.

Examples:
- KXNBAGAME-25NOV29TORCHA → NBA game, Nov 29, 2025, Toronto at Charlotte
- KXALEAGUEGAME-25DEC05AUCWPH-AUC → A-League game, Dec 5, 2025, Auckland vs Wellington Phoenix, Auckland wins
- KX2028DRUN-28-AOC → 2028 Democratic primary, Alexandria Ocasio-Cortez
- GOVPARTYAL-26-D → 2026 Alabama Governor, Democrat
- FED-25DEC-T3.75 → Federal Reserve rate, Dec 2025, Target 3.75%
"""

import re
from typing import Dict, Optional, Tuple
from datetime import datetime
import logging

log = logging.getLogger(__name__)

# Team/League abbreviations mapping
SPORTS_LEAGUES = {
    "NBA": "NBA",
    "NHL": "NHL",
    "NFL": "NFL",
    "MLB": "MLB",
    "NCAA": "NCAA",
    "NCAAFB": "NCAA Football",
    "NCAAMB": "NCAA Men's Basketball",
    "NCAAMBK": "NCAA Men's Basketball",
    "ALEAGUE": "A-League",
    "ARGPREMDIV": "Argentine Primera División",
    "BELGIANPL": "Belgian Pro League",
    "MVESPORTSMULTIGAME": "Multi-Sport Event",
}

# State abbreviations (for government markets)
US_STATES = {
    "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
    "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
    "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho",
    "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas",
    "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland",
    "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi",
    "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
    "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
    "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma",
    "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina",
    "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas", "UT": "Utah",
    "VT": "Vermont", "VA": "Virginia", "WA": "Washington", "WV": "West Virginia",
    "WI": "Wisconsin", "WY": "Wyoming", "DC": "District of Columbia",
}

# Common team abbreviations (expand as needed)
TEAM_ABBREVIATIONS = {
    # NBA
    "TOR": "Toronto", "CHA": "Charlotte", "NY": "New York", "BOS": "Boston",
    "LAL": "LA Lakers", "GSW": "Golden State", "MIA": "Miami", "CHI": "Chicago",
    # NHL
    "WSH": "Washington", "NYI": "NY Islanders", "TOR": "Toronto", "MTL": "Montreal",
    # NCAA Basketball
    "KU": "Kansas", "KAN": "Kansas", "KANSAS": "Kansas",
    "UK": "Kentucky", "DUKE": "Duke", "UNC": "North Carolina", "UCLA": "UCLA",
    "NOVA": "Villanova", "GONZ": "Gonzaga", "BAYLOR": "Baylor", "MICH": "Michigan",
    "MSU": "Michigan State", "PUR": "Purdue", "IND": "Indiana", "ILL": "Illinois",
    # A-League
    "AUC": "Auckland", "WPH": "Wellington Phoenix", "MAC": "Macarthur", "VIC": "Victory",
    "PER": "Perth", "WES": "Western United", "CCM": "Central Coast", "SYD": "Sydney",
    "NUJ": "Newcastle Jets", "MEL": "Melbourne",
    # Argentine Primera
    "BAR": "Barcelona", "GLP": "Gimnasia LP", "RAC": "Racing", "TIG": "Tigre",
    "CC": "Central Córdoba", "ELP": "Estudiantes LP",
}

# Party codes
PARTY_CODES = {
    "D": "Democrat",
    "R": "Republican",
    "I": "Independent",
    "G": "Green",
    "L": "Libertarian",
}

# Candidate abbreviations (expand as needed)
CANDIDATE_CODES = {
    "AOC": "Alexandria Ocasio-Cortez",
    "DJT": "Donald Trump",
    "DJTJR": "Donald Trump Jr.",
    "GNEW": "Gavin Newsom",
    "JFET": "J.D. Vance",
    "KHAR": "Kamala Harris",
    "RCOO": "Ron DeSantis",
    "SAS": "Sarah Sanders",
    "TWAL": "Tim Walz",
    "DPHI": "Dean Phillips",
    "CHOL": "Chris Hollins",
    "GYOU": "Glenn Youngkin",
    "MRUB": "Marco Rubio",
    "MTAY": "Mike Taylor",
    "NHAL": "Nikki Haley",
    "RDES": "Ron DeSantis",
    "TCRU": "Ted Cruz",
    "VRAM": "Vivek Ramaswamy",
}


def parse_date_encoded(date_str: str) -> Optional[Tuple[str, str]]:
    """
    Parse Kalshi date encoding.
    
    Formats:
    - 25NOV29 → (2025-11-29, "Nov 29, 2025")
    - 25DEC05 → (2025-12-05, "Dec 5, 2025")
    - 25DEC31 → (2025-12-31, "Dec 31, 2025")
    - 26-JAN01 → (2026-01-01, "Jan 1, 2026")
    
    Returns: (iso_date, display_date) or None if parsing fails
    """
    # Pattern: YYMMMDD or YY-MMMDD
    match = re.match(r"(\d{2})-?([A-Z]{3})(\d{2})", date_str)
    if not match:
        return None
    
    year_short, month_str, day = match.groups()
    year = 2000 + int(year_short)
    
    month_map = {
        "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
        "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12,
    }
    
    if month_str not in month_map:
        return None
    
    month = month_map[month_str]
    day_int = int(day)
    
    try:
        date_obj = datetime(year, month, day_int)
        iso_date = date_obj.strftime("%Y-%m-%d")
        display_date = date_obj.strftime("%b %d, %Y")
        return (iso_date, display_date)
    except ValueError:
        return None


def parse_sports_game_ticker(ticker: str) -> Optional[Dict]:
    """
    Parse sports game tickers.
    
    Patterns:
    - KXNBAGAME-25NOV29TORCHA → NBA game, Nov 29, 2025, Toronto at Charlotte
    - KXALEAGUEGAME-25DEC05AUCWPH-AUC → A-League, Dec 5, 2025, Auckland vs Wellington Phoenix, Auckland wins
    - KXALEAGUEGAME-25DEC05AUCWPH-TIE → A-League, Dec 5, 2025, Auckland vs Wellington Phoenix, Tie
    """
    # Pattern: KX{LEAGUE}GAME-{DATE}{TEAM1}{TEAM2}-{OUTCOME}
    # Need to be more careful - team codes vary in length
    # Try to match known league patterns first
    for league_code in SPORTS_LEAGUES.keys():
        if ticker.startswith(f"KX{league_code}GAME-"):
            # Extract date and teams
            remaining = ticker[len(f"KX{league_code}GAME-"):]
            # Date is YYMMMDD format (7 chars: YY + MMM + DD)
            if len(remaining) < 7:
                continue
            date_str = remaining[:7]  # Standard 7-char format (YYMMMDD)
            teams_and_outcome = remaining[7:]  # Everything after the date
            
            # Parse the date
            date_info = parse_date_encoded(date_str)
            if not date_info:
                continue
            
            # Split teams and outcome - outcome is after last dash (if present)
            outcome = None
            teams_part = teams_and_outcome
            
            if "-" in teams_and_outcome:
                teams_part, outcome = teams_and_outcome.rsplit("-", 1)
            
            league = SPORTS_LEAGUES.get(league_code, league_code)
            date_info = parse_date_encoded(date_str)
            if not date_info:
                continue
            
            iso_date, display_date = date_info
            
            # Try to identify team codes from the teams_part
            # Common patterns: 3-4 char codes, sometimes longer
            # For NBA: TOR, CHA, etc. (3 chars)
            # For A-League: AUC, WPH, etc. (3-4 chars)
            # This is a heuristic - we'll improve with more examples
            team1_code = None
            team2_code = None
            
            # Try matching known team codes (longest first)
            # Strategy: try all combinations of known codes
            matched = False
            team1_code = None
            team2_code = None
            
            # Sort codes by length (longest first) to prefer longer matches
            sorted_codes = sorted(TEAM_ABBREVIATIONS.keys(), key=len, reverse=True)
            
            # Try startswith approach first
            for code1 in sorted_codes:
                if teams_part.startswith(code1):
                    remaining_team = teams_part[len(code1):]
                    # Check if remaining exactly matches another known code
                    if remaining_team and remaining_team in TEAM_ABBREVIATIONS:
                        team1_code = code1
                        team2_code = remaining_team
                        matched = True
                        break
            
            # If not matched, try endswith approach
            if not matched:
                for code2 in sorted_codes:
                    if teams_part.endswith(code2):
                        remaining = teams_part[:-len(code2)]
                        # Check if remaining exactly matches another known code
                        if remaining in TEAM_ABBREVIATIONS:
                            team1_code = remaining
                            team2_code = code2
                            matched = True
                            break
            
            # Last resort: split in middle (rough heuristic)
            if not matched:
                mid = len(teams_part) // 2
                team1_code = teams_part[:mid]
                team2_code = teams_part[mid:]
            
            team1 = TEAM_ABBREVIATIONS.get(team1_code, team1_code)
            team2 = TEAM_ABBREVIATIONS.get(team2_code, team2_code)
            
            # Determine market type and outcome display
            if outcome:
                if outcome == "TIE":
                    market_type = "tie"
                    outcome_display = "Tie"
                elif outcome in [team1_code, team2_code]:
                    market_type = "moneyline"
                    outcome_display = team1 if outcome == team1_code else team2
                else:
                    market_type = "spread" if re.match(r"[A-Z]+\d+", outcome) else "other"
                    outcome_display = outcome
            else:
                # No outcome suffix - this is the base game market
                market_type = "game"
                outcome_display = None
            
            result = {
                "category": "sports",
                "sport": league,
                "event_type": "game",
                "date": iso_date,
                "date_display": display_date,
                "teams": [team1, team2],
                "team_codes": [team1_code, team2_code],
                "market_type": market_type,
            }
            
            if outcome:
                result["outcome"] = outcome
                result["outcome_display"] = outcome_display
            
            return result
    
    return None


def parse_election_ticker(ticker: str) -> Optional[Dict]:
    """
    Parse election tickers.
    
    Patterns:
    - KX2028DRUN-28-AOC → 2028 Democratic primary, Alexandria Ocasio-Cortez
    - KX2028RRUN-28-DJT → 2028 Republican primary, Donald Trump
    - GOVPARTYAL-26-D → 2026 Alabama Governor, Democrat
    - CONTROLH-2026-D → 2026 House Control, Democrat
    """
    # Pattern 1: KX{YEAR}{PARTY}RUN-{YEAR}-{CANDIDATE}
    match = re.match(r"KX(\d{4})([DR])RUN-(\d{2})-([A-Z]+)", ticker)
    if match:
        year, party_code, year_short, candidate_code = match.groups()
        party = PARTY_CODES.get(party_code, party_code)
        candidate = CANDIDATE_CODES.get(candidate_code, candidate_code)
        
        return {
            "category": "election",
            "event_type": "primary",
            "year": int(year),
            "party": party,
            "party_code": party_code,
            "candidate": candidate,
            "candidate_code": candidate_code,
        }
    
    # Pattern 2: GOVPARTY{STATE}-{YEAR}-{PARTY}
    match = re.match(r"GOVPARTY([A-Z]{2})-(\d{2})-([DR])", ticker)
    if match:
        state_code, year_short, party_code = match.groups()
        state = US_STATES.get(state_code, state_code)
        year = 2000 + int(year_short)
        party = PARTY_CODES.get(party_code, party_code)
        
        return {
            "category": "election",
            "event_type": "governor",
            "year": year,
            "state": state,
            "state_code": state_code,
            "party": party,
            "party_code": party_code,
        }
    
    # Pattern 3: CONTROL{H/S}-{YEAR}-{PARTY}
    match = re.match(r"CONTROL([HS])-(\d{4})-([DR])", ticker)
    if match:
        chamber, year, party_code = match.groups()
        chamber_name = "House" if chamber == "H" else "Senate"
        party = PARTY_CODES.get(party_code, party_code)
        
        return {
            "category": "election",
            "event_type": "chamber_control",
            "year": int(year),
            "chamber": chamber_name,
            "chamber_code": chamber,
            "party": party,
            "party_code": party_code,
        }
    
    return None


def parse_corporate_event_ticker(ticker: str) -> Optional[Dict]:
    """
    Parse corporate event tickers.
    
    Patterns:
    - APPLEFOLD-25DEC31 → Apple stock fold, Dec 31, 2025
    - APPLEUS-29DEC31 → Apple US market, Dec 31, 2029
    - AMAZONFTC-29DEC31 → Amazon FTC case, Dec 31, 2029
    """
    # Pattern: {COMPANY}{EVENT}-{DATE}
    # Don't match if it starts with KX (those are other categories)
    if ticker.startswith("KX"):
        return None
    
    # Known event types to match first
    event_types = ["FOLD", "US", "FTC", "PORT", "HOTDOG"]
    for event_type in event_types:
        if f"{event_type}-" in ticker:
            # Extract company and date
            parts = ticker.split(f"{event_type}-")
            if len(parts) == 2:
                company = parts[0]
                date_str = parts[1]
                date_info = parse_date_encoded(date_str)
                if date_info:
                    iso_date, display_date = date_info
                    event_map = {
                        "FOLD": "Stock Split/Fold",
                        "US": "US Market",
                        "FTC": "FTC Case",
                        "PORT": "Portfolio",
                        "HOTDOG": "Hot Dog Price",
                    }
                    return {
                        "category": "corporate",
                        "company": company,
                        "event_type": event_map.get(event_type, event_type),
                        "date": iso_date,
                        "date_display": display_date,
                    }
    
    return None


def parse_economic_ticker(ticker: str) -> Optional[Dict]:
    """
    Parse economic indicator tickers.
    
    Patterns:
    - FED-25DEC-T3.75 → Federal Reserve rate, Dec 2025, Target 3.75%
    - FEDHIKE-25DEC31 → Fed rate hike, Dec 31, 2025
    - CHINAUSGDP-30 → China-US GDP, 2030
    """
    # Pattern 1: FED-{DATE}-T{VALUE}
    match = re.match(r"FED-(\d{2}[A-Z]{3})-T([\d.]+)", ticker)
    if match:
        date_str, target_rate = match.groups()
        date_info = parse_date_encoded(date_str + "01")  # Use first day of month
        if date_info:
            iso_date, display_date = date_info
            return {
                "category": "economic",
                "indicator": "Federal Reserve Rate",
                "date": iso_date,
                "date_display": display_date,
                "target_rate": float(target_rate),
            }
    
    # Pattern 2: FEDHIKE-{DATE}
    match = re.match(r"FEDHIKE-(\d{2}[A-Z]{3}\d{2})", ticker)
    if match:
        date_str = match.group(1)
        date_info = parse_date_encoded(date_str)
        if date_info:
            iso_date, display_date = date_info
            return {
                "category": "economic",
                "indicator": "Fed Rate Hike",
                "date": iso_date,
                "date_display": display_date,
            }
    
    # Pattern 3: {INDICATOR}-{YEAR}
    match = re.match(r"([A-Z]+)-(\d{2})", ticker)
    if match:
        indicator, year_short = match.groups()
        year = 2000 + int(year_short)
        return {
            "category": "economic",
            "indicator": indicator,
            "year": year,
        }
    
    return None


def parse_entertainment_ticker(ticker: str) -> Optional[Dict]:
    """
    Parse entertainment tickers.
    
    Patterns:
    - KX1SONG-DRAKE-DEC2725 → #1 Song, Drake, Dec 27, 2025
    - BEYONCEGENRE-30-AFA → Beyoncé genre, 2030, Afrobeats
    """
    # Pattern 1: KX1SONG-{ARTIST}-{DATE}
    match = re.match(r"KX1SONG-([A-Z]+)-([A-Z]{3}\d{2}\d{2})", ticker)
    if match:
        artist, date_str = match.groups()
        # Date format: DEC2725 → Dec 27, 2025
        date_match = re.match(r"([A-Z]{3})(\d{2})(\d{2})", date_str)
        if date_match:
            month_str, day, year_short = date_match.groups()
            year = 2000 + int(year_short)
            month_map = {
                "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
                "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12,
            }
            if month_str in month_map:
                try:
                    date_obj = datetime(year, month_map[month_str], int(day))
                    iso_date = date_obj.strftime("%Y-%m-%d")
                    display_date = date_obj.strftime("%b %d, %Y")
                    return {
                        "category": "entertainment",
                        "event_type": "#1 Song",
                        "artist": artist,
                        "date": iso_date,
                        "date_display": display_date,
                    }
                except ValueError:
                    pass
    
    # Pattern 2: {ARTIST}GENRE-{YEAR}-{GENRE}
    # Check for GENRE pattern before economic parser
    if "GENRE-" in ticker:
        parts = ticker.split("-")
        if len(parts) == 3:
            artist_part = parts[0]
            if artist_part.endswith("GENRE"):
                artist = artist_part[:-5]  # Remove "GENRE"
                year_short = parts[1]
                genre_code = parts[2]
                try:
                    year = 2000 + int(year_short)
                    return {
                        "category": "entertainment",
                        "event_type": "Genre",
                        "artist": artist,
                        "year": year,
                        "genre": genre_code,
                    }
                except ValueError:
                    pass
    
    return None


def parse_kalshi_ticker(ticker: str) -> Dict:
    """
    Main parser function. Tries all parsers and returns structured metadata.
    
    Returns dict with:
    - category: "sports" | "election" | "corporate" | "economic" | "entertainment" | "other"
    - parsed: True if successfully parsed, False otherwise
    - ... (category-specific fields)
    """
    # Try each parser in order (entertainment before economic to catch GENRE patterns)
    parsers = [
        ("sports", parse_sports_game_ticker),
        ("election", parse_election_ticker),
        ("entertainment", parse_entertainment_ticker),
        ("corporate", parse_corporate_event_ticker),
        ("economic", parse_economic_ticker),
    ]
    
    for category, parser_func in parsers:
        result = parser_func(ticker)
        if result:
            result["parsed"] = True
            return result
    
    # If no parser matched, return minimal structure
    return {
        "category": "other",
        "parsed": False,
        "ticker": ticker,
    }


if __name__ == "__main__":
    # Test cases
    test_tickers = [
        "KXNBAGAME-25NOV29TORCHA",
        "KXALEAGUEGAME-25DEC05AUCWPH-AUC",
        "KX2028DRUN-28-AOC",
        "GOVPARTYAL-26-D",
        "APPLEFOLD-25DEC31",
        "FED-25DEC-T3.75",
        "KX1SONG-DRAKE-DEC2725",
        "BEYONCEGENRE-30-AFA",
        "UNKNOWN-TICKER-123",
    ]
    
    for ticker in test_tickers:
        result = parse_kalshi_ticker(ticker)
        print(f"{ticker}")
        print(f"  → {result}")
        print()

