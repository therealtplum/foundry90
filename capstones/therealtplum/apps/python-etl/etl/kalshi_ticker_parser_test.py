"""
Unit tests for Kalshi ticker parser.

Run with: python -m pytest etl/kalshi_ticker_parser_test.py
Or: python etl/kalshi_ticker_parser_test.py
"""

import unittest
from kalshi_ticker_parser import (
    parse_kalshi_ticker,
    parse_sports_game_ticker,
    parse_election_ticker,
    parse_corporate_event_ticker,
    parse_economic_ticker,
    parse_entertainment_ticker,
    parse_date_encoded,
)


class TestDateParsing(unittest.TestCase):
    def test_date_encoded_standard(self):
        result = parse_date_encoded("25NOV29")
        self.assertIsNotNone(result)
        iso_date, display_date = result
        self.assertEqual(iso_date, "2025-11-29")
        self.assertEqual(display_date, "Nov 29, 2025")

    def test_date_encoded_with_dash(self):
        result = parse_date_encoded("26-JAN01")
        self.assertIsNotNone(result)
        iso_date, display_date = result
        self.assertEqual(iso_date, "2026-01-01")
        self.assertEqual(display_date, "Jan 01, 2026")


class TestSportsParsing(unittest.TestCase):
    def test_nba_game_ticker(self):
        result = parse_sports_game_ticker("KXNBAGAME-25NOV29TORCHA")
        self.assertIsNotNone(result)
        self.assertEqual(result["category"], "sports")
        self.assertEqual(result["sport"], "NBA")
        self.assertEqual(result["date"], "2025-11-29")
        # Note: Team parsing may need refinement
        self.assertIn("teams", result)
        self.assertIn("team_codes", result)

    def test_aleague_game_with_outcome(self):
        result = parse_sports_game_ticker("KXALEAGUEGAME-25DEC05AUCWPH-AUC")
        self.assertIsNotNone(result)
        self.assertEqual(result["category"], "sports")
        self.assertEqual(result["sport"], "A-League")
        self.assertEqual(result["date"], "2025-12-05")
        self.assertIn("outcome", result)


class TestElectionParsing(unittest.TestCase):
    def test_primary_ticker(self):
        result = parse_election_ticker("KX2028DRUN-28-AOC")
        self.assertIsNotNone(result)
        self.assertEqual(result["category"], "election")
        self.assertEqual(result["event_type"], "primary")
        self.assertEqual(result["year"], 2028)
        self.assertEqual(result["party"], "Democrat")
        self.assertEqual(result["candidate"], "Alexandria Ocasio-Cortez")

    def test_governor_ticker(self):
        result = parse_election_ticker("GOVPARTYAL-26-D")
        self.assertIsNotNone(result)
        self.assertEqual(result["category"], "election")
        self.assertEqual(result["event_type"], "governor")
        self.assertEqual(result["year"], 2026)
        self.assertEqual(result["state"], "Alabama")
        self.assertEqual(result["party"], "Democrat")


class TestCorporateParsing(unittest.TestCase):
    def test_apple_fold_ticker(self):
        result = parse_corporate_event_ticker("APPLEFOLD-25DEC31")
        self.assertIsNotNone(result)
        self.assertEqual(result["category"], "corporate")
        self.assertEqual(result["company"], "APPLE")
        self.assertEqual(result["event_type"], "Stock Split/Fold")
        self.assertEqual(result["date"], "2025-12-31")


class TestEconomicParsing(unittest.TestCase):
    def test_fed_rate_ticker(self):
        result = parse_economic_ticker("FED-25DEC-T3.75")
        self.assertIsNotNone(result)
        self.assertEqual(result["category"], "economic")
        self.assertEqual(result["indicator"], "Federal Reserve Rate")
        self.assertEqual(result["target_rate"], 3.75)


class TestEntertainmentParsing(unittest.TestCase):
    def test_song_ticker(self):
        result = parse_entertainment_ticker("KX1SONG-DRAKE-DEC2725")
        self.assertIsNotNone(result)
        self.assertEqual(result["category"], "entertainment")
        self.assertEqual(result["event_type"], "#1 Song")
        self.assertEqual(result["artist"], "DRAKE")

    def test_genre_ticker(self):
        result = parse_entertainment_ticker("BEYONCEGENRE-30-AFA")
        self.assertIsNotNone(result)
        self.assertEqual(result["category"], "entertainment")
        self.assertEqual(result["event_type"], "Genre")
        self.assertEqual(result["artist"], "BEYONCE")
        self.assertEqual(result["year"], 2030)


class TestMainParser(unittest.TestCase):
    def test_unknown_ticker(self):
        result = parse_kalshi_ticker("UNKNOWN-TICKER-123")
        self.assertEqual(result["category"], "other")
        self.assertFalse(result["parsed"])

    def test_all_categories(self):
        test_cases = [
            ("KXNBAGAME-25NOV29TORCHA", "sports"),
            ("KX2028DRUN-28-AOC", "election"),
            ("APPLEFOLD-25DEC31", "corporate"),
            ("FED-25DEC-T3.75", "economic"),
            ("KX1SONG-DRAKE-DEC2725", "entertainment"),
        ]
        
        for ticker, expected_category in test_cases:
            result = parse_kalshi_ticker(ticker)
            self.assertEqual(result["category"], expected_category)
            self.assertTrue(result["parsed"])


if __name__ == "__main__":
    unittest.main()

