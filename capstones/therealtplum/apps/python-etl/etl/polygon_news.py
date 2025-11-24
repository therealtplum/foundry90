import os
import time

def main():
    print("fmhub ETL container is running (stub).")
    print("DATABASE_URL =", os.environ.get("DATABASE_URL", "<not set>"))
    print("POLYGON_API_KEY =", "<set>" if os.environ.get("POLYGON_API_KEY") else "<not set>")
    # In real ETL, we'd fetch news + write to Postgres here.
    # For now, just sleep a bit so logs are visible, then exit.
    time.sleep(2)
    print("fmhub ETL stub done.")

if __name__ == "__main__":
    main()