#!/usr/bin/env python3
"""
Seed CME Group venue codes for sports teams.

Based on CME Group SER 9634R (December 1, 2025):
- Pro Basketball Games (Table 1)
- Pro Football Games (Table 2)
- College Football Games (Table 3)
- Pro Hockey Games (Table 4)
- Men's College Basketball Games (Table 5)
"""

import os
import sys
import logging
import psycopg2
from psycopg2.extras import execute_values
from typing import List, Dict, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def get_db_connection():
    """Get database connection from environment variable."""
    database_url = os.getenv('DATABASE_URL')
    if not database_url:
        raise ValueError("DATABASE_URL environment variable not set")
    return psycopg2.connect(database_url)


# CME Code Mappings from SER 9634R
# Format: (team_code, league_code, cme_code, team_name_hint)

CME_NBA_CODES = [
    ("ATL", "NBA", "NGATL", "Atlanta"),
    ("BOS", "NBA", "NGBOS", "Boston"),
    ("BKN", "NBA", "NGBKN", "Brooklyn"),
    ("CHA", "NBA", "NGCHA", "Charlotte"),
    ("CHI", "NBA", "NGCHI", "Chicago"),
    ("CLE", "NBA", "NGCLE", "Cleveland"),
    ("DAL", "NBA", "NGDAL", "Dallas"),
    ("DEN", "NBA", "NGDEN", "Denver"),
    ("DET", "NBA", "NGDET", "Detroit"),
    ("GSW", "NBA", "NGGSW", "Golden State"),
    ("HOU", "NBA", "NGHOU", "Houston"),
    ("IND", "NBA", "NGIND", "Indiana"),
    ("LAC", "NBA", "NGLAC", "Los Angeles C"),
    ("LAL", "NBA", "NGLAL", "Los Angeles L"),
    ("MEM", "NBA", "NGMEM", "Memphis"),
    ("MIA", "NBA", "NGMIA", "Miami"),
    ("MIL", "NBA", "NGMIL", "Milwaukee"),
    ("MIN", "NBA", "NGMIN", "Minnesota"),
    ("NO", "NBA", "NGNOP", "New Orleans"),  # Our DB uses "NO", CME uses "NGNOP"
    ("NY", "NBA", "NGNYK", "New York"),  # Our DB uses "NY", CME uses "NGNYK"
    ("OKC", "NBA", "NGOKC", "Oklahoma City"),
    ("ORL", "NBA", "NGORL", "Orlando"),
    ("PHI", "NBA", "NGPHI", "Philadelphia"),
    ("PHX", "NBA", "NGPHX", "Phoenix"),
    ("POR", "NBA", "NGPOR", "Portland"),
    ("SAC", "NBA", "NGSAC", "Sacramento"),
    ("SA", "NBA", "NGSAS", "San Antonio"),  # Our DB uses "SA", CME uses "NGSAS"
    ("TOR", "NBA", "NGTOR", "Toronto"),
    ("UTA", "NBA", "NGUTA", "Utah"),
    ("WAS", "NBA", "NGWAS", "Washington"),
]

CME_NFL_CODES = [
    ("ARI", "NFL", "FGARI", "Arizona"),
    ("ATL", "NFL", "FGATL", "Atlanta"),
    ("BAL", "NFL", "FGBAL", "Baltimore"),
    ("BUF", "NFL", "FGBUF", "Buffalo"),
    ("CAR", "NFL", "FGCAR", "Carolina"),
    ("CHI", "NFL", "FGCHI", "Chicago"),
    ("CIN", "NFL", "FGCIN", "Cincinnati"),
    ("CLE", "NFL", "FGCLE", "Cleveland"),
    ("DAL", "NFL", "FGDAL", "Dallas"),
    ("DEN", "NFL", "FGDEN", "Denver"),
    ("DET", "NFL", "FGDET", "Detroit"),
    ("GB", "NFL", "FGGBX", "Green Bay"),
    ("HOU", "NFL", "FGHOU", "Houston"),
    ("IND", "NFL", "FGIND", "Indianapolis"),
    ("JAX", "NFL", "FGJAX", "Jacksonville"),
    ("KC", "NFL", "FGKCX", "Kansas City"),
    ("LV", "NFL", "FGLVX", "Las Vegas"),
    ("LAC", "NFL", "FGLAC", "Los Angeles C"),
    ("LAR", "NFL", "FGLAR", "Los Angeles R"),
    ("MIA", "NFL", "FGMIA", "Miami"),
    ("MIN", "NFL", "FGMIN", "Minnesota"),
    ("NE", "NFL", "FGNEX", "New England"),
    ("NO", "NFL", "FGNOX", "New Orleans"),
    ("NYG", "NFL", "FGNYG", "New York G"),
    ("NYJ", "NFL", "FGNYJ", "New York J"),
    ("PHI", "NFL", "FGPHI", "Philadelphia"),
    ("PIT", "NFL", "FGPIT", "Pittsburgh"),
    ("SF", "NFL", "FGSFX", "San Francisco"),
    ("SEA", "NFL", "FGSEA", "Seattle"),
    ("TB", "NFL", "FGTBX", "Tampa Bay"),
    ("TEN", "NFL", "FGTEN", "Tennessee"),
    ("WAS", "NFL", "FGWAS", "Washington"),
]

CME_NCAAF_CODES = [
    ("OSU", "NCAAF", "CGOSU", "Ohio State"),
    ("IND", "NCAAF", "CGIND", "Indiana"),
    ("TAMU", "NCAAF", "CGTAM", "Texas A&M"),
    ("ALA", "NCAAF", "CGALA", "Alabama"),
    ("UGA", "NCAAF", "CGUGA", "Georgia"),
    ("MISS", "NCAAF", "CGOLE", "Ole Miss"),
    ("BYU", "NCAAF", "CGBYU", "BYU"),
    ("TTU", "NCAAF", "CGTTU", "Texas Tech"),
    ("ND", "NCAAF", "CGXND", "Notre Dame"),
    ("UVA", "NCAAF", "CGUVA", "Virginia"),
    ("OKLA", "NCAAF", "CGOKL", "Oklahoma"),
    ("TEX", "NCAAF", "CGXUT", "Texas"),
    ("LOU", "NCAAF", "CGLOU", "Louisville"),
    ("GT", "NCAAF", "CGGTU", "Georgia Tech"),
    ("MIA", "NCAAF", "CGMIA", "Miami"),
    ("MIZ", "NCAAF", "CGMIZ", "Missouri"),
    ("UTAH", "NCAAF", "CGUTA", "Utah"),
    ("USC", "NCAAF", "CGUSC", "USC"),
    ("MICH", "NCAAF", "CGMIC", "Michigan"),
    ("VAN", "NCAAF", "CGVAN", "Vanderbilt"),
    ("IOWA", "NCAAF", "CGIOW", "Iowa"),
    ("CIN", "NCAAF", "CGCIN", "Cincinnati"),
    ("WASH", "NCAAF", "CGWAS", "Washington"),
    ("TCU", "NCAAF", "CGTCU", "TCU"),
    ("SMU", "NCAAF", "CGSMU", "SMU"),
    # Note: Memphis, North Texas, South Florida, James Madison not in our database
    ("ORE", "NCAAF", "CGORE", "Oregon"),
]

CME_NHL_CODES = [
    ("ANA", "NHL", "HGANA", "Anaheim"),
    ("BOS", "NHL", "HGBOS", "Boston"),
    ("BUF", "NHL", "HGBUF", "Buffalo"),
    ("CGY", "NHL", "HGCGY", "Calgary"),
    ("CAR", "NHL", "HGCAR", "Carolina"),
    ("CHI", "NHL", "HGCHI", "Chicago"),
    ("COL", "NHL", "HGCOL", "Colorado"),
    ("CBJ", "NHL", "HGCBJ", "Columbus"),
    ("DAL", "NHL", "HGDAL", "Dallas"),
    ("DET", "NHL", "HGDET", "Detroit"),
    ("EDM", "NHL", "HGEDM", "Edmonton"),
    ("FLA", "NHL", "HGFLA", "Florida"),
    ("LA", "NHL", "HGLAK", "Los Angeles"),  # Our DB uses "LA", CME uses "HGLAK"
    ("MIN", "NHL", "HGMIN", "Minnesota"),
    ("MTL", "NHL", "HGMTL", "Montreal"),
    ("NSH", "NHL", "HGNSH", "Nashville"),
    ("NJ", "NHL", "HGNJD", "New Jersey"),  # Our DB uses "NJ", CME uses "HGNJD"
    ("NYI", "NHL", "HGNYI", "New York I"),
    ("NYR", "NHL", "HGNYR", "New York R"),
    ("OTT", "NHL", "HGOTT", "Ottawa"),
    ("PHI", "NHL", "HGPHI", "Philadelphia"),
    ("PIT", "NHL", "HGPIT", "Pittsburgh"),
    ("SJ", "NHL", "HGSJS", "San Jose"),  # Our DB uses "SJ", CME uses "HGSJS"
    ("SEA", "NHL", "HGSEA", "Seattle"),
    ("STL", "NHL", "HGSTL", "St. Louis"),
    ("TB", "NHL", "HGTBL", "Tampa Bay"),
    ("TOR", "NHL", "HGTOR", "Toronto"),
    # Note: Utah (HGUTA) is not in our database yet - they're a new NHL team
    ("VAN", "NHL", "HGVAN", "Vancouver"),
    ("VGK", "NHL", "HGVGK", "Vegas"),
    ("WAS", "NHL", "HGWSH", "Washington"),
    ("WPG", "NHL", "HGWPG", "Winnipeg"),
]

CME_NCAAB_CODES = [
    ("ALA", "NCAAB", "BGALA", "Alabama"),
    ("AUB", "NCAAB", "BGAUB", "Auburn"),
    ("ARK", "NCAAB", "BGARK", "Arkansas"),
    ("ARIZ", "NCAAB", "BGARI", "Arizona"),
    ("ASU", "NCAAB", "BGASU", "Arizona State"),
    ("CAL", "NCAAB", "BGCAL", "California"),
    ("UCLA", "NCAAB", "BGUCL", "UCLA"),
    ("USC", "NCAAB", "BGUSC", "USC"),
    ("COLO", "NCAAB", "BGCOL", "Colorado"),
    ("UCONN", "NCAAB", "BGCON", "Connecticut"),
    ("GTWN", "NCAAB", "BGGTW", "Georgetown"),
    ("FLA", "NCAAB", "BGFLA", "Florida"),
    ("FSU", "NCAAB", "BGFSU", "Florida State"),
    ("MIA", "NCAAB", "BGMIA", "Miami"),
    ("UGA", "NCAAB", "BGUGA", "Georgia"),
    ("GT", "NCAAB", "BGGTX", "Georgia Tech"),
    ("IOWA", "NCAAB", "BGIOW", "Iowa"),
    ("ISU", "NCAAB", "BGISU", "Iowa State"),
    ("DEP", "NCAAB", "BGDEP", "DePaul"),
    ("ILL", "NCAAB", "BGILL", "Illinois"),
    ("NU", "NCAAB", "BGNWX", "Northwestern"),
    ("IND", "NCAAB", "BGIND", "Indiana"),
    ("ND", "NCAAB", "BGNDX", "Notre Dame"),
    ("PUR", "NCAAB", "BGPUR", "Purdue"),
    ("KU", "NCAAB", "BGKUX", "Kansas"),
    ("KSU", "NCAAB", "BGKSU", "Kansas State"),
    ("UK", "NCAAB", "BGUKX", "Kentucky"),
    ("LOU", "NCAAB", "BGLOU", "Louisville"),
    ("LSU", "NCAAB", "BGLSU", "LSU"),
    ("BC", "NCAAB", "BGBCX", "Boston"),
    ("MD", "NCAAB", "BGMDX", "Maryland"),
    ("MICH", "NCAAB", "BGMIC", "Michigan"),
    ("MSU", "NCAAB", "BGMSU", "Michigan State"),
    ("MINN", "NCAAB", "BGMIN", "Minnesota"),
    ("MIZ", "NCAAB", "BGMIZ", "Missouri"),
    ("MSST", "NCAAB", "BGMSS", "Mississippi State"),
    ("MISS", "NCAAB", "BGMIS", "Ole Miss"),
    ("DUKE", "NCAAB", "BGDUK", "Duke"),
    ("NCST", "NCAAB", "BGNCS", "NC State"),
    ("UNC", "NCAAB", "BGUNC", "North Carolina"),
    ("TENN", "NCAAB", "BGTEN", "Tennessee"),
    ("TEX", "NCAAB", "BGTEX", "Texas"),
    ("TAMU", "NCAAB", "BGTAM", "Texas A&M"),
    ("TTU", "NCAAB", "BGTTU", "Texas Tech"),
    ("OKLA", "NCAAB", "BGOKL", "Oklahoma"),
    ("OKST", "NCAAB", "BGOKS", "Oklahoma State"),
    ("ORE", "NCAAB", "BGORE", "Oregon"),
    ("PSU", "NCAAB", "BGPSU", "Penn State"),
    ("PITT", "NCAAB", "BGPIT", "Pittsburgh"),
    ("PROV", "NCAAB", "BGPRO", "Providence"),
    ("STAN", "NCAAB", "BGSTA", "Stanford"),
    ("SYR", "NCAAB", "BGSYR", "Syracuse"),
    ("TCU", "NCAAB", "BGTCU", "TCU"),
    ("UVA", "NCAAB", "BGUVA", "Virginia"),
    ("VT", "NCAAB", "BGVAT", "Virginia Tech"),
    ("WAKE", "NCAAB", "BGWAK", "Wake Forest"),
    ("WIS", "NCAAB", "BGWIS", "Wisconsin"),
]


def insert_cme_codes(conn, mappings: List[tuple], league_name: str):
    """
    Insert CME venue codes for teams.
    
    Args:
        conn: Database connection
        mappings: List of (team_code, league_code, cme_code, team_name_hint) tuples
        league_name: Display name for logging
    """
    cursor = conn.cursor()
    
    # Get CME venue_id
    cursor.execute("SELECT id FROM venues WHERE venue_code = 'CME' AND is_active = true")
    venue_row = cursor.fetchone()
    if not venue_row:
        logger.error("CME venue not found in database")
        return
    venue_id = venue_row[0]
    
    # Build values list with team lookups
    values = []
    skipped = []
    
    for team_code, league_code, cme_code, team_name_hint in mappings:
        # Look up team_id
        cursor.execute("""
            SELECT id, team_name 
            FROM sports_teams 
            WHERE team_code = %s 
              AND league_code = %s 
              AND is_active = true
            LIMIT 1
        """, (team_code, league_code))
        
        team_row = cursor.fetchone()
        if not team_row:
            skipped.append((team_code, league_code, cme_code, team_name_hint))
            continue
        
        team_id, team_name = team_row
        values.append((
            team_id,
            venue_id,
            cme_code,
            team_name,  # venue_team_name
            True,  # is_active
            True,  # is_primary
            1.00,  # confidence (manual mapping from official document)
            'manual',  # match_method
            'CME SER 9634R',  # match_source
            None,  # notes
        ))
    
    if skipped:
        logger.warning(f"Skipped {len(skipped)} teams not found in database:")
        for team_code, league_code, cme_code, hint in skipped:
            logger.warning(f"  {team_code} ({league_code}) -> {cme_code} ({hint})")
    
    if not values:
        logger.warning(f"No teams to insert for {league_name}")
        return
    
    # Insert with ON CONFLICT
    insert_sql = """
        INSERT INTO sports_teams_venue_codes (
            team_id, venue_id, venue_code, venue_team_name,
            is_active, is_primary, confidence, match_method, match_source, notes
        ) VALUES %s
        ON CONFLICT (team_id, venue_id, venue_code) 
        DO UPDATE SET
            venue_team_name = EXCLUDED.venue_team_name,
            match_source = EXCLUDED.match_source,
            confidence = EXCLUDED.confidence,
            updated_at = NOW()
    """
    
    execute_values(cursor, insert_sql, values)
    conn.commit()
    
    logger.info(f"Inserted/updated {len(values)} CME codes for {league_name}")
    
    if skipped:
        logger.info(f"  ({len(skipped)} teams skipped - not in database)")


def main():
    """Main function to seed CME venue codes."""
    logger.info("Starting CME venue codes seeding...")
    
    try:
        conn = get_db_connection()
        
        logger.info("Seeding NBA CME codes...")
        insert_cme_codes(conn, CME_NBA_CODES, "NBA")
        
        logger.info("Seeding NFL CME codes...")
        insert_cme_codes(conn, CME_NFL_CODES, "NFL")
        
        logger.info("Seeding NCAA Football CME codes...")
        insert_cme_codes(conn, CME_NCAAF_CODES, "NCAA Football")
        
        logger.info("Seeding NHL CME codes...")
        insert_cme_codes(conn, CME_NHL_CODES, "NHL")
        
        logger.info("Seeding NCAA Basketball CME codes...")
        insert_cme_codes(conn, CME_NCAAB_CODES, "NCAA Basketball")
        
        # Summary
        cursor = conn.cursor()
        cursor.execute("""
            SELECT COUNT(*) 
            FROM sports_teams_venue_codes stvc
            INNER JOIN venues v ON stvc.venue_id = v.id
            WHERE v.venue_code = 'CME' AND stvc.is_active = true
        """)
        total_count = cursor.fetchone()[0]
        
        logger.info("")
        logger.info("CME venue codes seeding completed successfully!")
        logger.info(f"Total CME codes: {total_count}")
        
        conn.close()
        
    except Exception as e:
        logger.error(f"Error seeding CME codes: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()

