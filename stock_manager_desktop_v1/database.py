import sqlite3
import json
from pathlib import Path

from stock import update_position


DATABASE_FILE = Path(__file__).with_name("stocks.db")
DEFAULT_INITIAL_CAPITAL = 10_000_000


def get_connection():
    connection = sqlite3.connect(DATABASE_FILE)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


def initialize_database():
    with get_connection() as connection:
        connection.executescript("""
            CREATE TABLE IF NOT EXISTS stocks (
                id INTEGER PRIMARY KEY, name TEXT NOT NULL, code TEXT NOT NULL UNIQUE,
                shares INTEGER NOT NULL, average_price REAL NOT NULL, current_price REAL,
                dividend_yield REAL, price_updated_at TEXT
            );
            CREATE TABLE IF NOT EXISTS purchases (
                id INTEGER PRIMARY KEY, stock_id INTEGER NOT NULL, shares INTEGER NOT NULL, price REAL NOT NULL,
                FOREIGN KEY (stock_id) REFERENCES stocks(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS transactions (
                id INTEGER PRIMARY KEY,
                stock_id INTEGER NOT NULL,
                transaction_type TEXT NOT NULL CHECK(transaction_type IN ('buy', 'sell')),
                shares INTEGER NOT NULL,
                price REAL NOT NULL,
                FOREIGN KEY (stock_id) REFERENCES stocks(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS app_settings (
                setting_key TEXT PRIMARY KEY,
                setting_value TEXT NOT NULL
            );
        """)
        connection.execute(
            "INSERT OR IGNORE INTO app_settings (setting_key, setting_value) VALUES ('initial_capital', ?)",
            (str(DEFAULT_INITIAL_CAPITAL),),
        )
        stock_columns = {row[1] for row in connection.execute("PRAGMA table_info(stocks)")}
        if "dividend_months" not in stock_columns:
            connection.execute("ALTER TABLE stocks ADD COLUMN dividend_months TEXT")
        stock_rows = connection.execute("SELECT id FROM stocks").fetchall()
        for row in stock_rows:
            transaction_count = connection.execute(
                "SELECT COUNT(*) FROM transactions WHERE stock_id = ?", (row["id"],)
            ).fetchone()[0]
            if transaction_count:
                continue
            purchases = connection.execute(
                "SELECT shares, price FROM purchases WHERE stock_id = ? ORDER BY id", (row["id"],)
            ).fetchall()
            for purchase in purchases:
                connection.execute(
                    """INSERT INTO transactions (stock_id, transaction_type, shares, price)
                       VALUES (?, 'buy', ?, ?)""",
                    (row["id"], purchase["shares"], purchase["price"]),
                )


def load_stocks():
    initialize_database()
    with get_connection() as connection:
        rows = connection.execute("SELECT * FROM stocks ORDER BY id").fetchall()
        stocks = []
        for row in rows:
            transaction_rows = connection.execute(
                """SELECT transaction_type, shares, price FROM transactions
                   WHERE stock_id = ? ORDER BY id""", (row["id"],)
            ).fetchall()
            stock = {
                "name": row["name"],
                "code": row["code"],
                "shares": row["shares"],
                "average_price": row["average_price"],
                "dividend_yield": row["dividend_yield"],
                "dividend_months": json.loads(row["dividend_months"] or "[]"),
                "transactions": [
                    {"type": transaction["transaction_type"], "shares": transaction["shares"], "price": transaction["price"]}
                    for transaction in transaction_rows
                ],
            }
            if row["current_price"] is not None:
                stock["current_price"] = row["current_price"]
            if row["price_updated_at"] is not None:
                stock["price_updated_at"] = row["price_updated_at"]
            update_position(stock)
            stocks.append(stock)
        return stocks


def save_stocks(stocks):
    initialize_database()
    with get_connection() as connection:
        connection.execute("DELETE FROM transactions")
        connection.execute("DELETE FROM purchases")
        connection.execute("DELETE FROM stocks")
        for stock in stocks:
            cursor = connection.execute(
                """INSERT INTO stocks (name, code, shares, average_price, current_price, dividend_yield, price_updated_at, dividend_months)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (stock["name"], stock["code"], stock["shares"], stock["average_price"],
                 stock.get("current_price"), stock.get("dividend_yield"), stock.get("price_updated_at"),
                 json.dumps(stock.get("dividend_months", []))),
            )
            for transaction in stock.get("transactions", []):
                connection.execute(
                    """INSERT INTO transactions (stock_id, transaction_type, shares, price)
                       VALUES (?, ?, ?, ?)""",
                    (cursor.lastrowid, transaction["type"], transaction["shares"], transaction["price"]),
                )


def load_initial_capital():
    initialize_database()
    with get_connection() as connection:
        value = connection.execute(
            "SELECT setting_value FROM app_settings WHERE setting_key = 'initial_capital'"
        ).fetchone()[0]
    return int(value)


def save_initial_capital(amount):
    if amount <= 0:
        raise ValueError("仮想資金は1円以上で設定してください。")
    initialize_database()
    with get_connection() as connection:
        connection.execute(
            """INSERT INTO app_settings (setting_key, setting_value) VALUES ('initial_capital', ?)
               ON CONFLICT(setting_key) DO UPDATE SET setting_value = excluded.setting_value""",
            (str(amount),),
        )
