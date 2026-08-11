from dataclasses import dataclass
from datetime import date, datetime, timedelta
from math import isfinite
from typing import Protocol

import yfinance as yf


@dataclass(frozen=True)
class StockPrice:
    price: float
    fetched_at: datetime


@dataclass(frozen=True)
class HistoricalClose:
    close: float
    price_date: date


class StockPriceProvider(Protocol):
    def fetch(self, code: str) -> StockPrice: ...

    def fetch_close(self, code: str, target_date: date) -> HistoricalClose: ...


class YFinanceStockPriceProvider:
    """Development-only stock price provider backed by yfinance."""

    def fetch(self, code: str) -> StockPrice:
        ticker = yf.Ticker(f"{code.upper()}.T")
        history = ticker.history(
            period="1d",
            interval="1m",
            auto_adjust=False,
            timeout=10,
            raise_errors=True,
        )
        if history.empty:
            history = ticker.history(
                period="5d",
                interval="1d",
                auto_adjust=False,
                timeout=10,
                raise_errors=True,
            )
        if history.empty:
            raise ValueError("Price data is unavailable")

        close = float(history["Close"].dropna().iloc[-1])
        if not isfinite(close) or close <= 0:
            raise ValueError("The fetched price is invalid")

        timestamp = history["Close"].dropna().index[-1]
        return StockPrice(price=close, fetched_at=timestamp.to_pydatetime())

    def fetch_close(self, code: str, target_date: date) -> HistoricalClose:
        ticker = yf.Ticker(f"{code.upper()}.T")
        history = ticker.history(
            start=target_date.isoformat(),
            end=(target_date + timedelta(days=1)).isoformat(),
            interval="1d",
            auto_adjust=False,
            timeout=10,
            raise_errors=True,
        )
        closes = history["Close"].dropna() if not history.empty else []
        if len(closes) == 0:
            raise ValueError("Close price data is unavailable for the date")
        close = float(closes.iloc[-1])
        if not isfinite(close) or close <= 0:
            raise ValueError("The fetched close price is invalid")
        timestamp = closes.index[-1]
        return HistoricalClose(close=close, price_date=timestamp.date())
