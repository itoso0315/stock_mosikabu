from datetime import date, datetime, timezone
from unittest import TestCase

from backend.app.main import app, get_health, get_stock_close, get_stock_quote
from backend.app.services.stock_price_provider import HistoricalClose, StockPrice


class FakeStockPriceProvider:
    def fetch(self, code: str) -> StockPrice:
        if code != "8306":
            raise AssertionError("Unexpected stock code")
        return StockPrice(
            price=2135.0,
            fetched_at=datetime(2026, 8, 11, 9, 42, tzinfo=timezone.utc),
        )

    def fetch_close(self, code: str, target_date: date) -> HistoricalClose:
        if code != "8306" or target_date != date(2026, 9, 11):
            raise AssertionError("Unexpected close request")
        return HistoricalClose(close=3780.0, price_date=date(2026, 9, 11))


class StockQuoteEndpointTest(TestCase):
    def test_health_returns_ok_without_creating_a_stock_price_provider(self) -> None:
        health_route = next(route for route in app.routes if route.path == "/health")

        self.assertIn("GET", health_route.methods)
        self.assertEqual(health_route.status_code or 200, 200)
        self.assertEqual(get_health().model_dump(), {"status": "ok"})

    def test_get_stock_quote(self) -> None:
        response = get_stock_quote(
            code="8306",
            name="三菱UFJフィナンシャル・グループ",
            provider=FakeStockPriceProvider(),
        )
        self.assertEqual(
            response.model_dump(),
            {
                "code": "8306",
                "name": "三菱UFJフィナンシャル・グループ",
                "price": 2135.0,
                "fetched_at": "2026-08-11T09:42:00+00:00",
            },
        )

    def test_get_stock_close(self) -> None:
        response = get_stock_close(
            code="8306",
            date_value=date(2026, 9, 11),
            provider=FakeStockPriceProvider(),
        )
        self.assertEqual(
            response.model_dump(),
            {
                "code": "8306",
                "date": "2026-09-11",
                "close": 3780.0,
                "priceDate": "2026-09-11",
            },
        )
