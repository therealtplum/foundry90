"""
Seed Sports Teams Database

Populates the sports_teams table with comprehensive team data for:
- Major US Professional Leagues (NBA, NFL, MLB, NHL, MLS)
- NCAA Division I Teams (Basketball, Football)
- International Soccer Leagues (as needed)

Usage:
    python -m etl.seed_sports_teams
"""

import os
import sys
import psycopg2
from psycopg2.extras import execute_values
from typing import List, Dict, Optional
import logging

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

log = logging.getLogger(__name__)

# Database connection (use environment variables)
DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@localhost:5432/fmhub")

def get_db_connection():
    """Get database connection from DATABASE_URL or individual environment variables."""
    if DATABASE_URL:
        return psycopg2.connect(DATABASE_URL)
    else:
        # Fallback to individual env vars
        return psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=os.getenv('DB_PORT', '5432'),
            database=os.getenv('DB_NAME', 'fmhub'),
            user=os.getenv('DB_USER', 'app'),
            password=os.getenv('DB_PASSWORD', 'app')
        )


# =====================================================================
# TEAM DATA DEFINITIONS
# =====================================================================

NBA_TEAMS = [
    # Eastern Conference
    {"code": "ATL", "name": "Atlanta Hawks", "short": "Hawks", "city": "Atlanta", "state": "GA", "conference": "Eastern", "division": "Southeast"},
    {"code": "BOS", "name": "Boston Celtics", "short": "Celtics", "city": "Boston", "state": "MA", "conference": "Eastern", "division": "Atlantic"},
    {"code": "BKN", "name": "Brooklyn Nets", "short": "Nets", "city": "Brooklyn", "state": "NY", "conference": "Eastern", "division": "Atlantic", "alternate": ["BRO", "NJN"]},
    {"code": "CHA", "name": "Charlotte Hornets", "short": "Hornets", "city": "Charlotte", "state": "NC", "conference": "Eastern", "division": "Southeast", "alternate": ["CHH", "CHA"]},
    {"code": "CHI", "name": "Chicago Bulls", "short": "Bulls", "city": "Chicago", "state": "IL", "conference": "Eastern", "division": "Central"},
    {"code": "CLE", "name": "Cleveland Cavaliers", "short": "Cavaliers", "city": "Cleveland", "state": "OH", "conference": "Eastern", "division": "Central", "alternate": ["CAV"]},
    {"code": "DET", "name": "Detroit Pistons", "short": "Pistons", "city": "Detroit", "state": "MI", "conference": "Eastern", "division": "Central"},
    {"code": "IND", "name": "Indiana Pacers", "short": "Pacers", "city": "Indianapolis", "state": "IN", "conference": "Eastern", "division": "Central"},
    {"code": "MIA", "name": "Miami Heat", "short": "Heat", "city": "Miami", "state": "FL", "conference": "Eastern", "division": "Southeast"},
    {"code": "MIL", "name": "Milwaukee Bucks", "short": "Bucks", "city": "Milwaukee", "state": "WI", "conference": "Eastern", "division": "Central"},
    {"code": "NY", "name": "New York Knicks", "short": "Knicks", "city": "New York", "state": "NY", "conference": "Eastern", "division": "Atlantic", "alternate": ["NYK"]},
    {"code": "ORL", "name": "Orlando Magic", "short": "Magic", "city": "Orlando", "state": "FL", "conference": "Eastern", "division": "Southeast"},
    {"code": "PHI", "name": "Philadelphia 76ers", "short": "76ers", "city": "Philadelphia", "state": "PA", "conference": "Eastern", "division": "Atlantic", "alternate": ["PHIL"]},
    {"code": "TOR", "name": "Toronto Raptors", "short": "Raptors", "city": "Toronto", "state": "ON", "country": "CA", "conference": "Eastern", "division": "Atlantic"},
    {"code": "WAS", "name": "Washington Wizards", "short": "Wizards", "city": "Washington", "state": "DC", "conference": "Eastern", "division": "Southeast", "alternate": ["WSH", "WAS"]},
    
    # Western Conference
    {"code": "DAL", "name": "Dallas Mavericks", "short": "Mavericks", "city": "Dallas", "state": "TX", "conference": "Western", "division": "Southwest"},
    {"code": "DEN", "name": "Denver Nuggets", "short": "Nuggets", "city": "Denver", "state": "CO", "conference": "Western", "division": "Northwest"},
    {"code": "GSW", "name": "Golden State Warriors", "short": "Warriors", "city": "San Francisco", "state": "CA", "conference": "Western", "division": "Pacific", "alternate": ["GS", "GOLDENSTATE"]},
    {"code": "HOU", "name": "Houston Rockets", "short": "Rockets", "city": "Houston", "state": "TX", "conference": "Western", "division": "Southwest"},
    {"code": "LAC", "name": "LA Clippers", "short": "Clippers", "city": "Los Angeles", "state": "CA", "conference": "Western", "division": "Pacific", "alternate": ["LALAC", "CLIP"]},
    {"code": "LAL", "name": "Los Angeles Lakers", "short": "Lakers", "city": "Los Angeles", "state": "CA", "conference": "Western", "division": "Pacific", "alternate": ["LA"]},
    {"code": "MEM", "name": "Memphis Grizzlies", "short": "Grizzlies", "city": "Memphis", "state": "TN", "conference": "Western", "division": "Southwest"},
    {"code": "MIN", "name": "Minnesota Timberwolves", "short": "Timberwolves", "city": "Minneapolis", "state": "MN", "conference": "Western", "division": "Northwest", "alternate": ["MINN"]},
    {"code": "NO", "name": "New Orleans Pelicans", "short": "Pelicans", "city": "New Orleans", "state": "LA", "conference": "Western", "division": "Southwest", "alternate": ["NOP", "NOLA"]},
    {"code": "OKC", "name": "Oklahoma City Thunder", "short": "Thunder", "city": "Oklahoma City", "state": "OK", "conference": "Western", "division": "Northwest"},
    {"code": "PHX", "name": "Phoenix Suns", "short": "Suns", "city": "Phoenix", "state": "AZ", "conference": "Western", "division": "Pacific", "alternate": ["PHO"]},
    {"code": "POR", "name": "Portland Trail Blazers", "short": "Trail Blazers", "city": "Portland", "state": "OR", "conference": "Western", "division": "Northwest", "alternate": ["BLAZERS"]},
    {"code": "SAC", "name": "Sacramento Kings", "short": "Kings", "city": "Sacramento", "state": "CA", "conference": "Western", "division": "Pacific"},
    {"code": "SA", "name": "San Antonio Spurs", "short": "Spurs", "city": "San Antonio", "state": "TX", "conference": "Western", "division": "Southwest", "alternate": ["SAS"]},
    {"code": "UTA", "name": "Utah Jazz", "short": "Jazz", "city": "Salt Lake City", "state": "UT", "conference": "Western", "division": "Northwest", "alternate": ["UTAH"]},
]

NFL_TEAMS = [
    # AFC
    {"code": "BAL", "name": "Baltimore Ravens", "short": "Ravens", "city": "Baltimore", "state": "MD", "conference": "AFC", "division": "North"},
    {"code": "BUF", "name": "Buffalo Bills", "short": "Bills", "city": "Buffalo", "state": "NY", "conference": "AFC", "division": "East"},
    {"code": "CIN", "name": "Cincinnati Bengals", "short": "Bengals", "city": "Cincinnati", "state": "OH", "conference": "AFC", "division": "North"},
    {"code": "CLE", "name": "Cleveland Browns", "short": "Browns", "city": "Cleveland", "state": "OH", "conference": "AFC", "division": "North"},
    {"code": "DEN", "name": "Denver Broncos", "short": "Broncos", "city": "Denver", "state": "CO", "conference": "AFC", "division": "West"},
    {"code": "HOU", "name": "Houston Texans", "short": "Texans", "city": "Houston", "state": "TX", "conference": "AFC", "division": "South"},
    {"code": "IND", "name": "Indianapolis Colts", "short": "Colts", "city": "Indianapolis", "state": "IN", "conference": "AFC", "division": "South"},
    {"code": "JAX", "name": "Jacksonville Jaguars", "short": "Jaguars", "city": "Jacksonville", "state": "FL", "conference": "AFC", "division": "South", "alternate": ["JAC"]},
    {"code": "KC", "name": "Kansas City Chiefs", "short": "Chiefs", "city": "Kansas City", "state": "MO", "conference": "AFC", "division": "West", "alternate": ["KCC"]},
    {"code": "LV", "name": "Las Vegas Raiders", "short": "Raiders", "city": "Las Vegas", "state": "NV", "conference": "AFC", "division": "West", "alternate": ["OAK", "RAIDERS"]},
    {"code": "LAC", "name": "Los Angeles Chargers", "short": "Chargers", "city": "Los Angeles", "state": "CA", "conference": "AFC", "division": "West", "alternate": ["SD", "SDC"]},
    {"code": "MIA", "name": "Miami Dolphins", "short": "Dolphins", "city": "Miami", "state": "FL", "conference": "AFC", "division": "East"},
    {"code": "NE", "name": "New England Patriots", "short": "Patriots", "city": "Foxborough", "state": "MA", "conference": "AFC", "division": "East", "alternate": ["NEP", "PATRIOTS"]},
    {"code": "NYJ", "name": "New York Jets", "short": "Jets", "city": "East Rutherford", "state": "NJ", "conference": "AFC", "division": "East"},
    {"code": "PIT", "name": "Pittsburgh Steelers", "short": "Steelers", "city": "Pittsburgh", "state": "PA", "conference": "AFC", "division": "North"},
    {"code": "TEN", "name": "Tennessee Titans", "short": "Titans", "city": "Nashville", "state": "TN", "conference": "AFC", "division": "South", "alternate": ["TENN"]},
    
    # NFC
    {"code": "ARI", "name": "Arizona Cardinals", "short": "Cardinals", "city": "Glendale", "state": "AZ", "conference": "NFC", "division": "West"},
    {"code": "ATL", "name": "Atlanta Falcons", "short": "Falcons", "city": "Atlanta", "state": "GA", "conference": "NFC", "division": "South"},
    {"code": "CAR", "name": "Carolina Panthers", "short": "Panthers", "city": "Charlotte", "state": "NC", "conference": "NFC", "division": "South"},
    {"code": "CHI", "name": "Chicago Bears", "short": "Bears", "city": "Chicago", "state": "IL", "conference": "NFC", "division": "North"},
    {"code": "DAL", "name": "Dallas Cowboys", "short": "Cowboys", "city": "Dallas", "state": "TX", "conference": "NFC", "division": "East"},
    {"code": "DET", "name": "Detroit Lions", "short": "Lions", "city": "Detroit", "state": "MI", "conference": "NFC", "division": "North"},
    {"code": "GB", "name": "Green Bay Packers", "short": "Packers", "city": "Green Bay", "state": "WI", "conference": "NFC", "division": "North", "alternate": ["GNB"]},
    {"code": "LAR", "name": "Los Angeles Rams", "short": "Rams", "city": "Los Angeles", "state": "CA", "conference": "NFC", "division": "West", "alternate": ["LA", "STL"]},
    {"code": "MIN", "name": "Minnesota Vikings", "short": "Vikings", "city": "Minneapolis", "state": "MN", "conference": "NFC", "division": "North", "alternate": ["MINN"]},
    {"code": "NO", "name": "New Orleans Saints", "short": "Saints", "city": "New Orleans", "state": "LA", "conference": "NFC", "division": "South", "alternate": ["NOS", "NOLA"]},
    {"code": "NYG", "name": "New York Giants", "short": "Giants", "city": "East Rutherford", "state": "NJ", "conference": "NFC", "division": "East", "alternate": ["NY"]},
    {"code": "PHI", "name": "Philadelphia Eagles", "short": "Eagles", "city": "Philadelphia", "state": "PA", "conference": "NFC", "division": "East"},
    {"code": "SF", "name": "San Francisco 49ers", "short": "49ers", "city": "Santa Clara", "state": "CA", "conference": "NFC", "division": "West", "alternate": ["SFO"]},
    {"code": "SEA", "name": "Seattle Seahawks", "short": "Seahawks", "city": "Seattle", "state": "WA", "conference": "NFC", "division": "West"},
    {"code": "TB", "name": "Tampa Bay Buccaneers", "short": "Buccaneers", "city": "Tampa", "state": "FL", "conference": "NFC", "division": "South", "alternate": ["TAM", "TBB"]},
    {"code": "WAS", "name": "Washington Commanders", "short": "Commanders", "city": "Landover", "state": "MD", "conference": "NFC", "division": "East", "alternate": ["WSH", "WAS", "REDSKINS"]},
]

MLB_TEAMS = [
    # American League
    {"code": "BAL", "name": "Baltimore Orioles", "short": "Orioles", "city": "Baltimore", "state": "MD", "conference": "American League", "division": "East"},
    {"code": "BOS", "name": "Boston Red Sox", "short": "Red Sox", "city": "Boston", "state": "MA", "conference": "American League", "division": "East", "alternate": ["BOSOX"]},
    {"code": "NYY", "name": "New York Yankees", "short": "Yankees", "city": "Bronx", "state": "NY", "conference": "American League", "division": "East", "alternate": ["NY", "YANKS"]},
    {"code": "TB", "name": "Tampa Bay Rays", "short": "Rays", "city": "St. Petersburg", "state": "FL", "conference": "American League", "division": "East", "alternate": ["TAM", "TBR", "DEVILRAYS"]},
    {"code": "TOR", "name": "Toronto Blue Jays", "short": "Blue Jays", "city": "Toronto", "state": "ON", "country": "CA", "conference": "American League", "division": "East"},
    {"code": "CWS", "name": "Chicago White Sox", "short": "White Sox", "city": "Chicago", "state": "IL", "conference": "American League", "division": "Central", "alternate": ["CWS", "CHW"]},
    {"code": "CLE", "name": "Cleveland Guardians", "short": "Guardians", "city": "Cleveland", "state": "OH", "conference": "American League", "division": "Central", "alternate": ["CLEV", "INDIANS"]},
    {"code": "DET", "name": "Detroit Tigers", "short": "Tigers", "city": "Detroit", "state": "MI", "conference": "American League", "division": "Central"},
    {"code": "KC", "name": "Kansas City Royals", "short": "Royals", "city": "Kansas City", "state": "MO", "conference": "American League", "division": "Central", "alternate": ["KCR"]},
    {"code": "MIN", "name": "Minnesota Twins", "short": "Twins", "city": "Minneapolis", "state": "MN", "conference": "American League", "division": "Central", "alternate": ["MINN"]},
    {"code": "HOU", "name": "Houston Astros", "short": "Astros", "city": "Houston", "state": "TX", "conference": "American League", "division": "West"},
    {"code": "LAA", "name": "Los Angeles Angels", "short": "Angels", "city": "Anaheim", "state": "CA", "conference": "American League", "division": "West", "alternate": ["ANA", "LAA", "ANGELS"]},
    {"code": "OAK", "name": "Oakland Athletics", "short": "Athletics", "city": "Oakland", "state": "CA", "conference": "American League", "division": "West", "alternate": ["A'S", "AS"]},
    {"code": "SEA", "name": "Seattle Mariners", "short": "Mariners", "city": "Seattle", "state": "WA", "conference": "American League", "division": "West"},
    {"code": "TEX", "name": "Texas Rangers", "short": "Rangers", "city": "Arlington", "state": "TX", "conference": "American League", "division": "West"},
    
    # National League
    {"code": "ATL", "name": "Atlanta Braves", "short": "Braves", "city": "Atlanta", "state": "GA", "conference": "National League", "division": "East"},
    {"code": "MIA", "name": "Miami Marlins", "short": "Marlins", "city": "Miami", "state": "FL", "conference": "National League", "division": "East", "alternate": ["FLA", "FLORIDA"]},
    {"code": "NYM", "name": "New York Mets", "short": "Mets", "city": "Flushing", "state": "NY", "conference": "National League", "division": "East"},
    {"code": "PHI", "name": "Philadelphia Phillies", "short": "Phillies", "city": "Philadelphia", "state": "PA", "conference": "National League", "division": "East"},
    {"code": "WAS", "name": "Washington Nationals", "short": "Nationals", "city": "Washington", "state": "DC", "conference": "National League", "division": "East", "alternate": ["WSH", "WAS", "EXPOS"]},
    {"code": "CHC", "name": "Chicago Cubs", "short": "Cubs", "city": "Chicago", "state": "IL", "conference": "National League", "division": "Central"},
    {"code": "CIN", "name": "Cincinnati Reds", "short": "Reds", "city": "Cincinnati", "state": "OH", "conference": "National League", "division": "Central"},
    {"code": "MIL", "name": "Milwaukee Brewers", "short": "Brewers", "city": "Milwaukee", "state": "WI", "conference": "National League", "division": "Central"},
    {"code": "PIT", "name": "Pittsburgh Pirates", "short": "Pirates", "city": "Pittsburgh", "state": "PA", "conference": "National League", "division": "Central"},
    {"code": "STL", "name": "St. Louis Cardinals", "short": "Cardinals", "city": "St. Louis", "state": "MO", "conference": "National League", "division": "Central"},
    {"code": "ARI", "name": "Arizona Diamondbacks", "short": "Diamondbacks", "city": "Phoenix", "state": "AZ", "conference": "National League", "division": "West", "alternate": ["AZ", "DBACKS"]},
    {"code": "COL", "name": "Colorado Rockies", "short": "Rockies", "city": "Denver", "state": "CO", "conference": "National League", "division": "West"},
    {"code": "LAD", "name": "Los Angeles Dodgers", "short": "Dodgers", "city": "Los Angeles", "state": "CA", "conference": "National League", "division": "West", "alternate": ["LA", "BROOKLYN"]},
    {"code": "SD", "name": "San Diego Padres", "short": "Padres", "city": "San Diego", "state": "CA", "conference": "National League", "division": "West", "alternate": ["SDP"]},
    {"code": "SF", "name": "San Francisco Giants", "short": "Giants", "city": "San Francisco", "state": "CA", "conference": "National League", "division": "West", "alternate": ["SFO", "SFG"]},
]

NHL_TEAMS = [
    # Eastern Conference
    {"code": "BOS", "name": "Boston Bruins", "short": "Bruins", "city": "Boston", "state": "MA", "conference": "Eastern", "division": "Atlantic"},
    {"code": "BUF", "name": "Buffalo Sabres", "short": "Sabres", "city": "Buffalo", "state": "NY", "conference": "Eastern", "division": "Atlantic"},
    {"code": "DET", "name": "Detroit Red Wings", "short": "Red Wings", "city": "Detroit", "state": "MI", "conference": "Eastern", "division": "Atlantic"},
    {"code": "FLA", "name": "Florida Panthers", "short": "Panthers", "city": "Sunrise", "state": "FL", "conference": "Eastern", "division": "Atlantic"},
    {"code": "MTL", "name": "Montreal Canadiens", "short": "Canadiens", "city": "Montreal", "state": "QC", "country": "CA", "conference": "Eastern", "division": "Atlantic", "alternate": ["MON"]},
    {"code": "OTT", "name": "Ottawa Senators", "short": "Senators", "city": "Ottawa", "state": "ON", "country": "CA", "conference": "Eastern", "division": "Atlantic"},
    {"code": "TB", "name": "Tampa Bay Lightning", "short": "Lightning", "city": "Tampa", "state": "FL", "conference": "Eastern", "division": "Atlantic", "alternate": ["TBL", "TAM"]},
    {"code": "TOR", "name": "Toronto Maple Leafs", "short": "Maple Leafs", "city": "Toronto", "state": "ON", "country": "CA", "conference": "Eastern", "division": "Atlantic", "alternate": ["LEAFS"]},
    {"code": "CAR", "name": "Carolina Hurricanes", "short": "Hurricanes", "city": "Raleigh", "state": "NC", "conference": "Eastern", "division": "Metropolitan"},
    {"code": "CBJ", "name": "Columbus Blue Jackets", "short": "Blue Jackets", "city": "Columbus", "state": "OH", "conference": "Eastern", "division": "Metropolitan", "alternate": ["CLB"]},
    {"code": "NJ", "name": "New Jersey Devils", "short": "Devils", "city": "Newark", "state": "NJ", "conference": "Eastern", "division": "Metropolitan", "alternate": ["NJD"]},
    {"code": "NYI", "name": "New York Islanders", "short": "Islanders", "city": "Elmont", "state": "NY", "conference": "Eastern", "division": "Metropolitan"},
    {"code": "NYR", "name": "New York Rangers", "short": "Rangers", "city": "New York", "state": "NY", "conference": "Eastern", "division": "Metropolitan"},
    {"code": "PHI", "name": "Philadelphia Flyers", "short": "Flyers", "city": "Philadelphia", "state": "PA", "conference": "Eastern", "division": "Metropolitan"},
    {"code": "PIT", "name": "Pittsburgh Penguins", "short": "Penguins", "city": "Pittsburgh", "state": "PA", "conference": "Eastern", "division": "Metropolitan"},
    {"code": "WAS", "name": "Washington Capitals", "short": "Capitals", "city": "Washington", "state": "DC", "conference": "Eastern", "division": "Metropolitan", "alternate": ["WSH", "CAPS"]},
    
    # Western Conference
    {"code": "ARI", "name": "Arizona Coyotes", "short": "Coyotes", "city": "Tempe", "state": "AZ", "conference": "Western", "division": "Central", "alternate": ["PHX"]},
    {"code": "CHI", "name": "Chicago Blackhawks", "short": "Blackhawks", "city": "Chicago", "state": "IL", "conference": "Western", "division": "Central"},
    {"code": "COL", "name": "Colorado Avalanche", "short": "Avalanche", "city": "Denver", "state": "CO", "conference": "Western", "division": "Central"},
    {"code": "DAL", "name": "Dallas Stars", "short": "Stars", "city": "Dallas", "state": "TX", "conference": "Western", "division": "Central"},
    {"code": "MIN", "name": "Minnesota Wild", "short": "Wild", "city": "St. Paul", "state": "MN", "conference": "Western", "division": "Central", "alternate": ["MINN"]},
    {"code": "NSH", "name": "Nashville Predators", "short": "Predators", "city": "Nashville", "state": "TN", "conference": "Western", "division": "Central", "alternate": ["NAS"]},
    {"code": "STL", "name": "St. Louis Blues", "short": "Blues", "city": "St. Louis", "state": "MO", "conference": "Western", "division": "Central"},
    {"code": "WPG", "name": "Winnipeg Jets", "short": "Jets", "city": "Winnipeg", "state": "MB", "country": "CA", "conference": "Western", "division": "Central"},
    {"code": "ANA", "name": "Anaheim Ducks", "short": "Ducks", "city": "Anaheim", "state": "CA", "conference": "Western", "division": "Pacific"},
    {"code": "CGY", "name": "Calgary Flames", "short": "Flames", "city": "Calgary", "state": "AB", "country": "CA", "conference": "Western", "division": "Pacific"},
    {"code": "EDM", "name": "Edmonton Oilers", "short": "Oilers", "city": "Edmonton", "state": "AB", "country": "CA", "conference": "Western", "division": "Pacific"},
    {"code": "LA", "name": "Los Angeles Kings", "short": "Kings", "city": "Los Angeles", "state": "CA", "conference": "Western", "division": "Pacific", "alternate": ["LAK"]},
    {"code": "SJ", "name": "San Jose Sharks", "short": "Sharks", "city": "San Jose", "state": "CA", "conference": "Western", "division": "Pacific", "alternate": ["SJS"]},
    {"code": "SEA", "name": "Seattle Kraken", "short": "Kraken", "city": "Seattle", "state": "WA", "conference": "Western", "division": "Pacific"},
    {"code": "VAN", "name": "Vancouver Canucks", "short": "Canucks", "city": "Vancouver", "state": "BC", "country": "CA", "conference": "Western", "division": "Pacific"},
    {"code": "VGK", "name": "Vegas Golden Knights", "short": "Golden Knights", "city": "Las Vegas", "state": "NV", "conference": "Western", "division": "Pacific", "alternate": ["VEGAS", "LV"]},
]

# Complete Power 4 Conference Teams (Big 12, Big Ten, SEC, ACC) + Notre Dame
NCAA_BASKETBALL_TEAMS = [
    # Big 12 (16 teams - updated 2024)
    {"code": "ARIZ", "name": "Arizona Wildcats", "short": "Wildcats", "city": "Tucson", "state": "AZ", "conference": "Big 12", "alternate": ["ARIZONA", "UA"]},
    {"code": "ASU", "name": "Arizona State Sun Devils", "short": "Sun Devils", "city": "Tempe", "state": "AZ", "conference": "Big 12", "alternate": ["ARIZONAST"]},
    {"code": "BYU", "name": "BYU Cougars", "short": "Cougars", "city": "Provo", "state": "UT", "conference": "Big 12", "alternate": ["BRIGHAMYOUNG"]},
    {"code": "BAYLOR", "name": "Baylor Bears", "short": "Bears", "city": "Waco", "state": "TX", "conference": "Big 12"},
    {"code": "COLO", "name": "Colorado Buffaloes", "short": "Buffaloes", "city": "Boulder", "state": "CO", "conference": "Big 12", "alternate": ["COLORADO", "CU"]},
    {"code": "CIN", "name": "Cincinnati Bearcats", "short": "Bearcats", "city": "Cincinnati", "state": "OH", "conference": "Big 12", "alternate": ["CINCY"]},
    {"code": "HOU", "name": "Houston Cougars", "short": "Cougars", "city": "Houston", "state": "TX", "conference": "Big 12", "alternate": ["HOUSTON"]},
    {"code": "ISU", "name": "Iowa State Cyclones", "short": "Cyclones", "city": "Ames", "state": "IA", "conference": "Big 12", "alternate": ["IOWAST"]},
    {"code": "KU", "name": "Kansas Jayhawks", "short": "Jayhawks", "city": "Lawrence", "state": "KS", "conference": "Big 12", "alternate": ["KAN", "KANSAS", "KANSASJAYHAWKS"]},
    {"code": "KSU", "name": "Kansas State Wildcats", "short": "Wildcats", "city": "Manhattan", "state": "KS", "conference": "Big 12", "alternate": ["KSTATE", "KANSASST"]},
    {"code": "OKST", "name": "Oklahoma State Cowboys", "short": "Cowboys", "city": "Stillwater", "state": "OK", "conference": "Big 12", "alternate": ["OSU", "OKLAHOMAST"]},
    {"code": "TCU", "name": "TCU Horned Frogs", "short": "Horned Frogs", "city": "Fort Worth", "state": "TX", "conference": "Big 12"},
    {"code": "TTU", "name": "Texas Tech Red Raiders", "short": "Red Raiders", "city": "Lubbock", "state": "TX", "conference": "Big 12", "alternate": ["TEXASTECH"]},
    {"code": "UCF", "name": "UCF Knights", "short": "Knights", "city": "Orlando", "state": "FL", "conference": "Big 12", "alternate": ["CENTRALFLORIDA"]},
    {"code": "UTAH", "name": "Utah Utes", "short": "Utes", "city": "Salt Lake City", "state": "UT", "conference": "Big 12"},
    {"code": "WVU", "name": "West Virginia Mountaineers", "short": "Mountaineers", "city": "Morgantown", "state": "WV", "conference": "Big 12", "alternate": ["WVA", "WESTVA"]},
    
    # Big Ten (18 teams as of 2024)
    {"code": "ILL", "name": "Illinois Fighting Illini", "short": "Fighting Illini", "city": "Champaign", "state": "IL", "conference": "Big Ten", "alternate": ["ILLINOIS"]},
    {"code": "IND", "name": "Indiana Hoosiers", "short": "Hoosiers", "city": "Bloomington", "state": "IN", "conference": "Big Ten"},
    {"code": "IOWA", "name": "Iowa Hawkeyes", "short": "Hawkeyes", "city": "Iowa City", "state": "IA", "conference": "Big Ten"},
    {"code": "MICH", "name": "Michigan Wolverines", "short": "Wolverines", "city": "Ann Arbor", "state": "MI", "conference": "Big Ten", "alternate": ["MICHIGAN", "UM"]},
    {"code": "MSU", "name": "Michigan State Spartans", "short": "Spartans", "city": "East Lansing", "state": "MI", "conference": "Big Ten", "alternate": ["MICHST", "MICHIGANST"]},
    {"code": "MINN", "name": "Minnesota Golden Gophers", "short": "Golden Gophers", "city": "Minneapolis", "state": "MN", "conference": "Big Ten", "alternate": ["MINNESOTA"]},
    {"code": "NEB", "name": "Nebraska Cornhuskers", "short": "Cornhuskers", "city": "Lincoln", "state": "NE", "conference": "Big Ten", "alternate": ["NEBRASKA"]},
    {"code": "NU", "name": "Northwestern Wildcats", "short": "Wildcats", "city": "Evanston", "state": "IL", "conference": "Big Ten", "alternate": ["NW", "NORTHWESTERN"]},
    {"code": "OSU", "name": "Ohio State Buckeyes", "short": "Buckeyes", "city": "Columbus", "state": "OH", "conference": "Big Ten", "alternate": ["OHIOST", "OHIOSTATE", "THEOHIOSTATE"]},
    {"code": "PUR", "name": "Purdue Boilermakers", "short": "Boilermakers", "city": "West Lafayette", "state": "IN", "conference": "Big Ten", "alternate": ["PURDUE"]},
    {"code": "RUT", "name": "Rutgers Scarlet Knights", "short": "Scarlet Knights", "city": "Piscataway", "state": "NJ", "conference": "Big Ten", "alternate": ["RUTGERS"]},
    {"code": "WIS", "name": "Wisconsin Badgers", "short": "Badgers", "city": "Madison", "state": "WI", "conference": "Big Ten", "alternate": ["WISC", "WISCONSIN"]},
    {"code": "MD", "name": "Maryland Terrapins", "short": "Terrapins", "city": "College Park", "state": "MD", "conference": "Big Ten", "alternate": ["MARYLAND"]},
    {"code": "PSU", "name": "Penn State Nittany Lions", "short": "Nittany Lions", "city": "State College", "state": "PA", "conference": "Big Ten", "alternate": ["PENNST", "PENNSTATE"]},
    {"code": "ORE", "name": "Oregon Ducks", "short": "Ducks", "city": "Eugene", "state": "OR", "conference": "Big Ten", "alternate": ["OREGON"]},
    {"code": "UCLA", "name": "UCLA Bruins", "short": "Bruins", "city": "Los Angeles", "state": "CA", "conference": "Big Ten"},
    {"code": "USC", "name": "USC Trojans", "short": "Trojans", "city": "Los Angeles", "state": "CA", "conference": "Big Ten", "alternate": ["SOUTHERN CAL"]},
    {"code": "WASH", "name": "Washington Huskies", "short": "Huskies", "city": "Seattle", "state": "WA", "conference": "Big Ten", "alternate": ["WASHINGTON"]},
    
    # SEC (16 teams - updated 2024)
    {"code": "ALA", "name": "Alabama Crimson Tide", "short": "Crimson Tide", "city": "Tuscaloosa", "state": "AL", "conference": "SEC", "alternate": ["ALABAMA", "BAMA"]},
    {"code": "ARK", "name": "Arkansas Razorbacks", "short": "Razorbacks", "city": "Fayetteville", "state": "AR", "conference": "SEC", "alternate": ["ARKANSAS"]},
    {"code": "AUB", "name": "Auburn Tigers", "short": "Tigers", "city": "Auburn", "state": "AL", "conference": "SEC", "alternate": ["AUBURN"]},
    {"code": "FLA", "name": "Florida Gators", "short": "Gators", "city": "Gainesville", "state": "FL", "conference": "SEC", "alternate": ["FLORIDA", "UF"]},
    {"code": "UGA", "name": "Georgia Bulldogs", "short": "Bulldogs", "city": "Athens", "state": "GA", "conference": "SEC", "alternate": ["GEORGIA"]},
    {"code": "UK", "name": "Kentucky Wildcats", "short": "Wildcats", "city": "Lexington", "state": "KY", "conference": "SEC", "alternate": ["KENTUCKY"]},
    {"code": "LSU", "name": "LSU Tigers", "short": "Tigers", "city": "Baton Rouge", "state": "LA", "conference": "SEC"},
    {"code": "MISS", "name": "Ole Miss Rebels", "short": "Rebels", "city": "Oxford", "state": "MS", "conference": "SEC", "alternate": ["OLEMISS", "MISSISSIPPI"]},
    {"code": "MSST", "name": "Mississippi State Bulldogs", "short": "Bulldogs", "city": "Starkville", "state": "MS", "conference": "SEC", "alternate": ["MISSST", "MISSISSIPPIST"]},
    {"code": "MIZ", "name": "Missouri Tigers", "short": "Tigers", "city": "Columbia", "state": "MO", "conference": "SEC", "alternate": ["MISSOURI", "MIZZOU"]},
    {"code": "OKLA", "name": "Oklahoma Sooners", "short": "Sooners", "city": "Norman", "state": "OK", "conference": "SEC", "alternate": ["OU", "OKLAHOMA"]},
    {"code": "SC", "name": "South Carolina Gamecocks", "short": "Gamecocks", "city": "Columbia", "state": "SC", "conference": "SEC", "alternate": ["SOUTHCAR", "SOUTHCAROLINA"]},
    {"code": "TENN", "name": "Tennessee Volunteers", "short": "Volunteers", "city": "Knoxville", "state": "TN", "conference": "SEC", "alternate": ["TENNESSEE"]},
    {"code": "TEX", "name": "Texas Longhorns", "short": "Longhorns", "city": "Austin", "state": "TX", "conference": "SEC", "alternate": ["TEXAS", "UT"]},
    {"code": "TAMU", "name": "Texas A&M Aggies", "short": "Aggies", "city": "College Station", "state": "TX", "conference": "SEC", "alternate": ["TEXASAM", "A&M"]},
    {"code": "VAN", "name": "Vanderbilt Commodores", "short": "Commodores", "city": "Nashville", "state": "TN", "conference": "SEC", "alternate": ["VANDY", "VANDERBILT"]},
    
    # ACC
    {"code": "BC", "name": "Boston College Eagles", "short": "Eagles", "city": "Chestnut Hill", "state": "MA", "conference": "ACC", "alternate": ["BOSTONCOL"]},
    {"code": "CLEM", "name": "Clemson Tigers", "short": "Tigers", "city": "Clemson", "state": "SC", "conference": "ACC", "alternate": ["CLEMSON"]},
    {"code": "DUKE", "name": "Duke Blue Devils", "short": "Blue Devils", "city": "Durham", "state": "NC", "conference": "ACC"},
    {"code": "FSU", "name": "Florida State Seminoles", "short": "Seminoles", "city": "Tallahassee", "state": "FL", "conference": "ACC", "alternate": ["FLORIDAST"]},
    {"code": "GT", "name": "Georgia Tech Yellow Jackets", "short": "Yellow Jackets", "city": "Atlanta", "state": "GA", "conference": "ACC", "alternate": ["GEORGIATECH"]},
    {"code": "LOU", "name": "Louisville Cardinals", "short": "Cardinals", "city": "Louisville", "state": "KY", "conference": "ACC", "alternate": ["LOUISVILLE"]},
    {"code": "MIA", "name": "Miami Hurricanes", "short": "Hurricanes", "city": "Coral Gables", "state": "FL", "conference": "ACC", "alternate": ["MIAMIFL"]},
    {"code": "UNC", "name": "North Carolina Tar Heels", "short": "Tar Heels", "city": "Chapel Hill", "state": "NC", "conference": "ACC", "alternate": ["NOCAR", "NORTHCAR"]},
    {"code": "NCST", "name": "NC State Wolfpack", "short": "Wolfpack", "city": "Raleigh", "state": "NC", "conference": "ACC", "alternate": ["NCSTATE", "NCS"]},
    {"code": "ND", "name": "Notre Dame Fighting Irish", "short": "Fighting Irish", "city": "Notre Dame", "state": "IN", "conference": "ACC", "alternate": ["NOTREDAME"]},
    {"code": "PITT", "name": "Pittsburgh Panthers", "short": "Panthers", "city": "Pittsburgh", "state": "PA", "conference": "ACC", "alternate": ["PITT", "PIT"]},
    {"code": "SYR", "name": "Syracuse Orange", "short": "Orange", "city": "Syracuse", "state": "NY", "conference": "ACC", "alternate": ["SYRACUSE"]},
    {"code": "UVA", "name": "Virginia Cavaliers", "short": "Cavaliers", "city": "Charlottesville", "state": "VA", "conference": "ACC", "alternate": ["VIRGINIA"]},
    {"code": "VT", "name": "Virginia Tech Hokies", "short": "Hokies", "city": "Blacksburg", "state": "VA", "conference": "ACC", "alternate": ["VIRGINIATECH"]},
    {"code": "WAKE", "name": "Wake Forest Demon Deacons", "short": "Demon Deacons", "city": "Winston-Salem", "state": "NC", "conference": "ACC", "alternate": ["WAKEFOREST"]},
    {"code": "CAL", "name": "California Golden Bears", "short": "Golden Bears", "city": "Berkeley", "state": "CA", "conference": "ACC", "alternate": ["CALIFORNIA"]},
    {"code": "STAN", "name": "Stanford Cardinal", "short": "Cardinal", "city": "Stanford", "state": "CA", "conference": "ACC", "alternate": ["STANFORD"]},
    {"code": "SMU", "name": "SMU Mustangs", "short": "Mustangs", "city": "Dallas", "state": "TX", "conference": "ACC", "alternate": ["SOUTHERNMETHODIST"]},
    
    # Big East (11 teams)
    {"code": "BUT", "name": "Butler Bulldogs", "short": "Bulldogs", "city": "Indianapolis", "state": "IN", "conference": "Big East", "alternate": ["BUTLER"]},
    {"code": "CREI", "name": "Creighton Bluejays", "short": "Bluejays", "city": "Omaha", "state": "NE", "conference": "Big East", "alternate": ["CREIGHTON"]},
    {"code": "DEP", "name": "DePaul Blue Demons", "short": "Blue Demons", "city": "Chicago", "state": "IL", "conference": "Big East", "alternate": ["DEPAUL"]},
    {"code": "GTWN", "name": "Georgetown Hoyas", "short": "Hoyas", "city": "Washington", "state": "DC", "conference": "Big East", "alternate": ["GEORGETOWN"]},
    {"code": "MARQ", "name": "Marquette Golden Eagles", "short": "Golden Eagles", "city": "Milwaukee", "state": "WI", "conference": "Big East", "alternate": ["MARQUETTE"]},
    {"code": "PROV", "name": "Providence Friars", "short": "Friars", "city": "Providence", "state": "RI", "conference": "Big East", "alternate": ["PROVIDENCE"]},
    {"code": "SHU", "name": "Seton Hall Pirates", "short": "Pirates", "city": "South Orange", "state": "NJ", "conference": "Big East", "alternate": ["SETONHALL"]},
    {"code": "SJU", "name": "St. John's Red Storm", "short": "Red Storm", "city": "Queens", "state": "NY", "conference": "Big East", "alternate": ["STJOHNS", "STJOHN"]},
    {"code": "UCONN", "name": "UConn Huskies", "short": "Huskies", "city": "Storrs", "state": "CT", "conference": "Big East", "alternate": ["UCONN", "CONNECTICUT"]},
    {"code": "NOVA", "name": "Villanova Wildcats", "short": "Wildcats", "city": "Villanova", "state": "PA", "conference": "Big East", "alternate": ["VILLANOVA"]},
    {"code": "XAV", "name": "Xavier Musketeers", "short": "Musketeers", "city": "Cincinnati", "state": "OH", "conference": "Big East", "alternate": ["XAVIER"]},
]

NCAA_FOOTBALL_TEAMS = [
    # Big 12 (16 teams - updated 2024)
    {"code": "ARIZ", "name": "Arizona Wildcats", "short": "Wildcats", "city": "Tucson", "state": "AZ", "conference": "Big 12", "alternate": ["ARIZONA", "UA"]},
    {"code": "ASU", "name": "Arizona State Sun Devils", "short": "Sun Devils", "city": "Tempe", "state": "AZ", "conference": "Big 12", "alternate": ["ARIZONAST"]},
    {"code": "BYU", "name": "BYU Cougars", "short": "Cougars", "city": "Provo", "state": "UT", "conference": "Big 12", "alternate": ["BRIGHAMYOUNG"]},
    {"code": "BAYLOR", "name": "Baylor Bears", "short": "Bears", "city": "Waco", "state": "TX", "conference": "Big 12"},
    {"code": "COLO", "name": "Colorado Buffaloes", "short": "Buffaloes", "city": "Boulder", "state": "CO", "conference": "Big 12", "alternate": ["COLORADO", "CU"]},
    {"code": "CIN", "name": "Cincinnati Bearcats", "short": "Bearcats", "city": "Cincinnati", "state": "OH", "conference": "Big 12", "alternate": ["CINCY"]},
    {"code": "HOU", "name": "Houston Cougars", "short": "Cougars", "city": "Houston", "state": "TX", "conference": "Big 12", "alternate": ["HOUSTON"]},
    {"code": "ISU", "name": "Iowa State Cyclones", "short": "Cyclones", "city": "Ames", "state": "IA", "conference": "Big 12", "alternate": ["IOWAST"]},
    {"code": "KU", "name": "Kansas Jayhawks", "short": "Jayhawks", "city": "Lawrence", "state": "KS", "conference": "Big 12", "alternate": ["KAN", "KANSAS"]},
    {"code": "KSU", "name": "Kansas State Wildcats", "short": "Wildcats", "city": "Manhattan", "state": "KS", "conference": "Big 12", "alternate": ["KSTATE", "KANSASST"]},
    {"code": "OKST", "name": "Oklahoma State Cowboys", "short": "Cowboys", "city": "Stillwater", "state": "OK", "conference": "Big 12", "alternate": ["OSU", "OKLAHOMAST"]},
    {"code": "TCU", "name": "TCU Horned Frogs", "short": "Horned Frogs", "city": "Fort Worth", "state": "TX", "conference": "Big 12"},
    {"code": "TTU", "name": "Texas Tech Red Raiders", "short": "Red Raiders", "city": "Lubbock", "state": "TX", "conference": "Big 12", "alternate": ["TEXASTECH"]},
    {"code": "UCF", "name": "UCF Knights", "short": "Knights", "city": "Orlando", "state": "FL", "conference": "Big 12", "alternate": ["CENTRALFLORIDA"]},
    {"code": "UTAH", "name": "Utah Utes", "short": "Utes", "city": "Salt Lake City", "state": "UT", "conference": "Big 12"},
    {"code": "WVU", "name": "West Virginia Mountaineers", "short": "Mountaineers", "city": "Morgantown", "state": "WV", "conference": "Big 12", "alternate": ["WVA", "WESTVA"]},
    
    # Big Ten (18 teams as of 2024)
    {"code": "ILL", "name": "Illinois Fighting Illini", "short": "Fighting Illini", "city": "Champaign", "state": "IL", "conference": "Big Ten", "alternate": ["ILLINOIS"]},
    {"code": "IND", "name": "Indiana Hoosiers", "short": "Hoosiers", "city": "Bloomington", "state": "IN", "conference": "Big Ten"},
    {"code": "IOWA", "name": "Iowa Hawkeyes", "short": "Hawkeyes", "city": "Iowa City", "state": "IA", "conference": "Big Ten"},
    {"code": "MICH", "name": "Michigan Wolverines", "short": "Wolverines", "city": "Ann Arbor", "state": "MI", "conference": "Big Ten", "alternate": ["MICHIGAN", "UM"]},
    {"code": "MSU", "name": "Michigan State Spartans", "short": "Spartans", "city": "East Lansing", "state": "MI", "conference": "Big Ten", "alternate": ["MICHST", "MICHIGANST"]},
    {"code": "MINN", "name": "Minnesota Golden Gophers", "short": "Golden Gophers", "city": "Minneapolis", "state": "MN", "conference": "Big Ten", "alternate": ["MINNESOTA"]},
    {"code": "NEB", "name": "Nebraska Cornhuskers", "short": "Cornhuskers", "city": "Lincoln", "state": "NE", "conference": "Big Ten", "alternate": ["NEBRASKA"]},
    {"code": "NU", "name": "Northwestern Wildcats", "short": "Wildcats", "city": "Evanston", "state": "IL", "conference": "Big Ten", "alternate": ["NW", "NORTHWESTERN"]},
    {"code": "OSU", "name": "Ohio State Buckeyes", "short": "Buckeyes", "city": "Columbus", "state": "OH", "conference": "Big Ten", "alternate": ["OHIOST", "OHIOSTATE", "THEOHIOSTATE"]},
    {"code": "PUR", "name": "Purdue Boilermakers", "short": "Boilermakers", "city": "West Lafayette", "state": "IN", "conference": "Big Ten", "alternate": ["PURDUE"]},
    {"code": "RUT", "name": "Rutgers Scarlet Knights", "short": "Scarlet Knights", "city": "Piscataway", "state": "NJ", "conference": "Big Ten", "alternate": ["RUTGERS"]},
    {"code": "WIS", "name": "Wisconsin Badgers", "short": "Badgers", "city": "Madison", "state": "WI", "conference": "Big Ten", "alternate": ["WISC", "WISCONSIN"]},
    {"code": "MD", "name": "Maryland Terrapins", "short": "Terrapins", "city": "College Park", "state": "MD", "conference": "Big Ten", "alternate": ["MARYLAND"]},
    {"code": "PSU", "name": "Penn State Nittany Lions", "short": "Nittany Lions", "city": "State College", "state": "PA", "conference": "Big Ten", "alternate": ["PENNST", "PENNSTATE"]},
    {"code": "ORE", "name": "Oregon Ducks", "short": "Ducks", "city": "Eugene", "state": "OR", "conference": "Big Ten", "alternate": ["OREGON"]},
    {"code": "UCLA", "name": "UCLA Bruins", "short": "Bruins", "city": "Los Angeles", "state": "CA", "conference": "Big Ten"},
    {"code": "USC", "name": "USC Trojans", "short": "Trojans", "city": "Los Angeles", "state": "CA", "conference": "Big Ten", "alternate": ["SOUTHERN CAL"]},
    {"code": "WASH", "name": "Washington Huskies", "short": "Huskies", "city": "Seattle", "state": "WA", "conference": "Big Ten", "alternate": ["WASHINGTON"]},
    
    # SEC (16 teams - updated 2024)
    {"code": "ALA", "name": "Alabama Crimson Tide", "short": "Crimson Tide", "city": "Tuscaloosa", "state": "AL", "conference": "SEC", "alternate": ["ALABAMA", "BAMA"]},
    {"code": "ARK", "name": "Arkansas Razorbacks", "short": "Razorbacks", "city": "Fayetteville", "state": "AR", "conference": "SEC", "alternate": ["ARKANSAS"]},
    {"code": "AUB", "name": "Auburn Tigers", "short": "Tigers", "city": "Auburn", "state": "AL", "conference": "SEC", "alternate": ["AUBURN"]},
    {"code": "FLA", "name": "Florida Gators", "short": "Gators", "city": "Gainesville", "state": "FL", "conference": "SEC", "alternate": ["FLORIDA", "UF"]},
    {"code": "UGA", "name": "Georgia Bulldogs", "short": "Bulldogs", "city": "Athens", "state": "GA", "conference": "SEC", "alternate": ["GEORGIA"]},
    {"code": "UK", "name": "Kentucky Wildcats", "short": "Wildcats", "city": "Lexington", "state": "KY", "conference": "SEC", "alternate": ["KENTUCKY"]},
    {"code": "LSU", "name": "LSU Tigers", "short": "Tigers", "city": "Baton Rouge", "state": "LA", "conference": "SEC"},
    {"code": "MISS", "name": "Ole Miss Rebels", "short": "Rebels", "city": "Oxford", "state": "MS", "conference": "SEC", "alternate": ["OLEMISS", "MISSISSIPPI"]},
    {"code": "MSST", "name": "Mississippi State Bulldogs", "short": "Bulldogs", "city": "Starkville", "state": "MS", "conference": "SEC", "alternate": ["MISSST", "MISSISSIPPIST"]},
    {"code": "MIZ", "name": "Missouri Tigers", "short": "Tigers", "city": "Columbia", "state": "MO", "conference": "SEC", "alternate": ["MISSOURI", "MIZZOU"]},
    {"code": "OKLA", "name": "Oklahoma Sooners", "short": "Sooners", "city": "Norman", "state": "OK", "conference": "SEC", "alternate": ["OU", "OKLAHOMA"]},
    {"code": "SC", "name": "South Carolina Gamecocks", "short": "Gamecocks", "city": "Columbia", "state": "SC", "conference": "SEC", "alternate": ["SOUTHCAR", "SOUTHCAROLINA"]},
    {"code": "TENN", "name": "Tennessee Volunteers", "short": "Volunteers", "city": "Knoxville", "state": "TN", "conference": "SEC", "alternate": ["TENNESSEE"]},
    {"code": "TEX", "name": "Texas Longhorns", "short": "Longhorns", "city": "Austin", "state": "TX", "conference": "SEC", "alternate": ["TEXAS", "UT"]},
    {"code": "TAMU", "name": "Texas A&M Aggies", "short": "Aggies", "city": "College Station", "state": "TX", "conference": "SEC", "alternate": ["TEXASAM", "A&M"]},
    {"code": "VAN", "name": "Vanderbilt Commodores", "short": "Commodores", "city": "Nashville", "state": "TN", "conference": "SEC", "alternate": ["VANDY", "VANDERBILT"]},
    
    # ACC (18 teams including Notre Dame)
    {"code": "BC", "name": "Boston College Eagles", "short": "Eagles", "city": "Chestnut Hill", "state": "MA", "conference": "ACC", "alternate": ["BOSTONCOL"]},
    {"code": "CAL", "name": "California Golden Bears", "short": "Golden Bears", "city": "Berkeley", "state": "CA", "conference": "ACC", "alternate": ["CALIFORNIA"]},
    {"code": "CLEM", "name": "Clemson Tigers", "short": "Tigers", "city": "Clemson", "state": "SC", "conference": "ACC", "alternate": ["CLEMSON"]},
    {"code": "DUKE", "name": "Duke Blue Devils", "short": "Blue Devils", "city": "Durham", "state": "NC", "conference": "ACC"},
    {"code": "FSU", "name": "Florida State Seminoles", "short": "Seminoles", "city": "Tallahassee", "state": "FL", "conference": "ACC", "alternate": ["FLORIDAST"]},
    {"code": "GT", "name": "Georgia Tech Yellow Jackets", "short": "Yellow Jackets", "city": "Atlanta", "state": "GA", "conference": "ACC", "alternate": ["GEORGIATECH"]},
    {"code": "LOU", "name": "Louisville Cardinals", "short": "Cardinals", "city": "Louisville", "state": "KY", "conference": "ACC", "alternate": ["LOUISVILLE"]},
    {"code": "MIA", "name": "Miami Hurricanes", "short": "Hurricanes", "city": "Coral Gables", "state": "FL", "conference": "ACC", "alternate": ["MIAMIFL"]},
    {"code": "UNC", "name": "North Carolina Tar Heels", "short": "Tar Heels", "city": "Chapel Hill", "state": "NC", "conference": "ACC", "alternate": ["NOCAR", "NORTHCAR"]},
    {"code": "NCST", "name": "NC State Wolfpack", "short": "Wolfpack", "city": "Raleigh", "state": "NC", "conference": "ACC", "alternate": ["NCSTATE", "NCS"]},
    {"code": "ND", "name": "Notre Dame Fighting Irish", "short": "Fighting Irish", "city": "Notre Dame", "state": "IN", "conference": "ACC", "alternate": ["NOTREDAME"]},
    {"code": "PITT", "name": "Pittsburgh Panthers", "short": "Panthers", "city": "Pittsburgh", "state": "PA", "conference": "ACC", "alternate": ["PITT", "PIT"]},
    {"code": "SYR", "name": "Syracuse Orange", "short": "Orange", "city": "Syracuse", "state": "NY", "conference": "ACC", "alternate": ["SYRACUSE"]},
    {"code": "UVA", "name": "Virginia Cavaliers", "short": "Cavaliers", "city": "Charlottesville", "state": "VA", "conference": "ACC", "alternate": ["VIRGINIA"]},
    {"code": "VT", "name": "Virginia Tech Hokies", "short": "Hokies", "city": "Blacksburg", "state": "VA", "conference": "ACC", "alternate": ["VIRGINIATECH"]},
    {"code": "WAKE", "name": "Wake Forest Demon Deacons", "short": "Demon Deacons", "city": "Winston-Salem", "state": "NC", "conference": "ACC", "alternate": ["WAKEFOREST"]},
    {"code": "CAL", "name": "California Golden Bears", "short": "Golden Bears", "city": "Berkeley", "state": "CA", "conference": "ACC", "alternate": ["CALIFORNIA"]},
    {"code": "STAN", "name": "Stanford Cardinal", "short": "Cardinal", "city": "Stanford", "state": "CA", "conference": "ACC", "alternate": ["STANFORD"]},
    {"code": "SMU", "name": "SMU Mustangs", "short": "Mustangs", "city": "Dallas", "state": "TX", "conference": "ACC", "alternate": ["SOUTHERNMETHODIST"]},
]

WNBA_TEAMS = [
    {"code": "ATL", "name": "Atlanta Dream", "short": "Dream", "city": "Atlanta", "state": "GA", "conference": "Eastern", "division": "Eastern"},
    {"code": "CHI", "name": "Chicago Sky", "short": "Sky", "city": "Chicago", "state": "IL", "conference": "Eastern", "division": "Eastern"},
    {"code": "IND", "name": "Indiana Fever", "short": "Fever", "city": "Indianapolis", "state": "IN", "conference": "Eastern", "division": "Eastern"},
    {"code": "NY", "name": "New York Liberty", "short": "Liberty", "city": "Brooklyn", "state": "NY", "conference": "Eastern", "division": "Eastern", "alternate": ["NYL"]},
    {"code": "CONN", "name": "Connecticut Sun", "short": "Sun", "city": "Uncasville", "state": "CT", "conference": "Eastern", "division": "Eastern", "alternate": ["CONN"]},
    {"code": "WAS", "name": "Washington Mystics", "short": "Mystics", "city": "Washington", "state": "DC", "conference": "Eastern", "division": "Eastern", "alternate": ["WSH"]},
    {"code": "DAL", "name": "Dallas Wings", "short": "Wings", "city": "Arlington", "state": "TX", "conference": "Western", "division": "Western"},
    {"code": "LV", "name": "Las Vegas Aces", "short": "Aces", "city": "Las Vegas", "state": "NV", "conference": "Western", "division": "Western", "alternate": ["VEGAS"]},
    {"code": "LA", "name": "Los Angeles Sparks", "short": "Sparks", "city": "Los Angeles", "state": "CA", "conference": "Western", "division": "Western", "alternate": ["LAL", "LASP"]},
    {"code": "MIN", "name": "Minnesota Lynx", "short": "Lynx", "city": "Minneapolis", "state": "MN", "conference": "Western", "division": "Western", "alternate": ["MINN"]},
    {"code": "PHX", "name": "Phoenix Mercury", "short": "Mercury", "city": "Phoenix", "state": "AZ", "conference": "Western", "division": "Western", "alternate": ["PHO"]},
    {"code": "SEA", "name": "Seattle Storm", "short": "Storm", "city": "Seattle", "state": "WA", "conference": "Western", "division": "Western"},
]



def insert_teams(conn, teams: List[Dict], sport_type: str, league_code: str, league_name: str, level: str = "Professional", gender: Optional[str] = None):
    """Insert teams into the database."""
    cursor = conn.cursor()
    
    # Deduplicate teams by (team_code, league_code) - keep last occurrence
    seen = {}
    for team in teams:
        key = (team["code"], league_code)
        seen[key] = team
    teams = list(seen.values())
    
    values = []
    for team in teams:
        alternate_codes = team.get("alternate", [])
        if isinstance(alternate_codes, str):
            alternate_codes = [alternate_codes]
        
        values.append((
            team["code"],
            team["name"],
            team.get("short", ""),
            sport_type,
            league_code,
            league_name,
            level,
            gender,
            team.get("division"),
            team.get("conference"),
            team.get("city"),
            team.get("state"),
            team.get("country", "US"),
            None,  # region
            alternate_codes if alternate_codes else None,
            None,  # official_team_id
            None,  # espn_id
            None,  # sports_reference_id
            True,  # is_active
            None,  # founded_year
            None,  # colors
            None,  # logo_url
        ))
    
    insert_sql = """
        INSERT INTO sports_teams (
            team_code, team_name, team_name_short,
            sport_type, league_code, league_name,
            level, gender, division, conference,
            city, state_province, country, region,
            alternate_codes, official_team_id, espn_id, sports_reference_id,
            is_active, founded_year, colors, logo_url
        ) VALUES %s
        ON CONFLICT (team_code, league_code)
        DO UPDATE SET
            team_name = EXCLUDED.team_name,
            team_name_short = EXCLUDED.team_name_short,
            sport_type = EXCLUDED.sport_type,
            league_name = EXCLUDED.league_name,
            level = EXCLUDED.level,
            gender = EXCLUDED.gender,
            division = EXCLUDED.division,
            conference = EXCLUDED.conference,
            city = EXCLUDED.city,
            state_province = EXCLUDED.state_province,
            country = EXCLUDED.country,
            alternate_codes = EXCLUDED.alternate_codes,
            updated_at = NOW()
    """
    
    execute_values(cursor, insert_sql, values)
    conn.commit()
    log.info(f"Inserted/updated {len(teams)} teams for {league_name}")


def main():
    """Main seeding function."""
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    
    conn = get_db_connection()
    
    try:
        log.info("Starting sports teams seeding...")
        
        # Professional Leagues
        log.info("Seeding NBA teams...")
        insert_teams(conn, NBA_TEAMS, "Basketball", "NBA", "National Basketball Association", "Professional")
        
        log.info("Seeding NFL teams...")
        insert_teams(conn, NFL_TEAMS, "Football", "NFL", "National Football League", "Professional")
        
        log.info("Seeding MLB teams...")
        insert_teams(conn, MLB_TEAMS, "Baseball", "MLB", "Major League Baseball", "Professional")
        
        log.info("Seeding NHL teams...")
        insert_teams(conn, NHL_TEAMS, "Hockey", "NHL", "National Hockey League", "Professional")
        
        # NCAA Teams
        log.info("Seeding NCAA Basketball teams...")
        insert_teams(conn, NCAA_BASKETBALL_TEAMS, "Basketball", "NCAAB", "NCAA Men's Basketball", "Collegiate", "Men's")
        
        log.info("Seeding NCAA Football teams...")
        insert_teams(conn, NCAA_FOOTBALL_TEAMS, "Football", "NCAAF", "NCAA Football", "Collegiate", "Men's")
        
        log.info("Seeding WNBA teams...")
        insert_teams(conn, WNBA_TEAMS, "Basketball", "WNBA", "Women's National Basketball Association", "Professional", "Women's")
        
        log.info("Sports teams seeding completed successfully!")
        
        # Print summary
        cursor = conn.cursor()
        cursor.execute("""
            SELECT league_code, COUNT(*) as team_count
            FROM sports_teams
            WHERE is_active = true
            GROUP BY league_code
            ORDER BY league_code
        """)
        
        log.info("\nSummary:")
        for row in cursor.fetchall():
            log.info(f"  {row[0]}: {row[1]} teams")
        
    except Exception as e:
        log.error(f"Error seeding sports teams: {e}", exc_info=True)
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()

