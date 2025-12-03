"""
Utilities for normalizing and displaying Kalshi tickers in a human-readable format.

Kalshi tickers are often cryptic (e.g., "PRES-2024-11-05-BIDEN") and need
to be converted to friendly display names for users.
"""

import re
from typing import Optional, Dict, Any


def parse_kalshi_ticker(ticker: str) -> Dict[str, Any]:
    """
    Parse a Kalshi ticker into its components.
    
    Examples:
        "PRES-2024-11-05-BIDEN" -> {
            "event_type": "PRES",
            "year": "2024",
            "month": "11",
            "day": "05",
            "outcome": "BIDEN"
        }
        
        "INFLATION-2024-12-31-ABOVE-3" -> {
            "event_type": "INFLATION",
            "year": "2024",
            "month": "12",
            "day": "31",
            "outcome": "ABOVE-3"
        }
    """
    parts = ticker.split("-")
    
    if len(parts) < 4:
        return {
            "raw": ticker,
            "event_type": parts[0] if parts else None,
            "parsed": False,
        }
    
    result = {
        "raw": ticker,
        "event_type": parts[0],
        "year": parts[1] if len(parts) > 1 else None,
        "month": parts[2] if len(parts) > 2 else None,
        "day": parts[3] if len(parts) > 3 else None,
        "outcome": "-".join(parts[4:]) if len(parts) > 4 else None,
        "parsed": True,
    }
    
    return result


def format_ticker_display_name(ticker: str, market_data: Optional[Dict[str, Any]] = None) -> str:
    """
    Convert a Kalshi ticker to a human-readable display name.
    
    Uses market data (title, subtitle) if available, otherwise
    attempts to parse and format the ticker.
    
    Args:
        ticker: Raw Kalshi ticker
        market_data: Optional market metadata from API
    
    Returns:
        Human-readable display name
    """
    # If we have market data with a title, use it
    if market_data:
        title = market_data.get("title") or market_data.get("subtitle")
        if title:
            return title
    
    # Otherwise, try to parse and format
    parsed = parse_kalshi_ticker(ticker)
    
    if not parsed.get("parsed"):
        return ticker  # Return as-is if we can't parse
    
    event_type = parsed["event_type"]
    outcome = parsed.get("outcome")
    year = parsed.get("year")
    month = parsed.get("month")
    day = parsed.get("day")
    
    # Format based on event type
    if event_type == "PRES":
        if outcome:
            return f"{outcome.title()} Election {year}"
        return f"Presidential Election {year}"
    
    elif event_type == "INFLATION":
        if outcome:
            # "ABOVE-3" -> "Above 3%"
            outcome_display = outcome.replace("-", " ").title()
            return f"Inflation {outcome_display} ({year})"
        return f"Inflation {year}"
    
    elif event_type == "GDP":
        if outcome:
            outcome_display = outcome.replace("-", " ").title()
            return f"GDP {outcome_display} ({year})"
        return f"GDP {year}"
    
    elif event_type == "UNEMPLOYMENT":
        if outcome:
            outcome_display = outcome.replace("-", " ").title()
            return f"Unemployment {outcome_display} ({year})"
        return f"Unemployment {year}"
    
    # Generic formatting
    if year and month and day:
        date_str = f"{year}-{month}-{day}"
        if outcome:
            return f"{event_type} {outcome.replace('-', ' ').title()} ({date_str})"
        return f"{event_type} ({date_str})"
    
    if outcome:
        return f"{event_type} {outcome.replace('-', ' ').title()}"
    
    return f"{event_type} {year or ''}".strip()


def format_parlay_display(parlay_data: Dict[str, Any]) -> str:
    """
    Format a parlay (multi-variant event) for display.
    
    Parlays in Kalshi are combinations of multiple events.
    This function creates a readable description of the parlay.
    
    Args:
        parlay_data: Dictionary containing parlay information
            - markets: List of market tickers in the parlay
            - outcomes: List of required outcomes
    
    Returns:
        Human-readable parlay description
    """
    markets = parlay_data.get("markets", [])
    outcomes = parlay_data.get("outcomes", [])
    
    if not markets:
        return "Unknown Parlay"
    
    # Format each market in the parlay
    market_names = []
    for i, ticker in enumerate(markets):
        outcome = outcomes[i] if i < len(outcomes) else None
        display_name = format_ticker_display_name(ticker)
        
        if outcome:
            market_names.append(f"{display_name}: {outcome}")
        else:
            market_names.append(display_name)
    
    return " + ".join(market_names)


def categorize_ticker(ticker: str) -> str:
    """
    Categorize a ticker by event type.
    
    Returns a category name for grouping/filtering.
    """
    parsed = parse_kalshi_ticker(ticker)
    event_type = parsed.get("event_type", "").upper()
    
    category_map = {
        "PRES": "Politics",
        "SENATE": "Politics",
        "HOUSE": "Politics",
        "GOV": "Politics",
        "INFLATION": "Economics",
        "GDP": "Economics",
        "UNEMPLOYMENT": "Economics",
        "FED": "Economics",
        "RATES": "Economics",
        "WEATHER": "Weather",
        "SPORTS": "Sports",
    }
    
    return category_map.get(event_type, "Other")


def is_parlay(ticker: str, market_data: Optional[Dict[str, Any]] = None) -> bool:
    """
    Check if a ticker represents a parlay (multi-variant event).
    
    Args:
        ticker: Market ticker
        market_data: Optional market metadata
    
    Returns:
        True if this is a parlay
    """
    if market_data:
        # Check market data for parlay indicators
        return market_data.get("is_parlay", False) or market_data.get("parlay", False)
    
    # Heuristic: parlays often have multiple outcomes or special formatting
    # This is a simple check - may need refinement
    parts = ticker.split("-")
    return len(parts) > 5  # Parlays tend to have more components


def get_ticker_metadata(ticker: str, market_data: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Get comprehensive metadata about a ticker for display purposes.
    
    Returns:
        Dictionary with:
        - display_name: Human-readable name
        - category: Event category
        - is_parlay: Whether it's a parlay
        - parsed_components: Parsed ticker components
        - friendly_description: Full description
    """
    parsed = parse_kalshi_ticker(ticker)
    display_name = format_ticker_display_name(ticker, market_data)
    category = categorize_ticker(ticker)
    parlay = is_parlay(ticker, market_data)
    
    return {
        "ticker": ticker,
        "display_name": display_name,
        "category": category,
        "is_parlay": parlay,
        "parsed_components": parsed,
        "friendly_description": display_name,
    }

