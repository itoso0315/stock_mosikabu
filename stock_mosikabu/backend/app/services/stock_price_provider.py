from fastapi import FastAPI, HTTPException
import re
import logging

from .services.stock_price_provider import (
    StockPriceProvider,
    YFinanceStockPriceProvider,
)

logger = logging.getLogger(__name__)

app = FastAPI()

# ... other code ...

@app.get("/stock_quote")
async def get_stock_quote(code: str, name: str = ""):
    normalized_code = code.upper()
    provider: StockPriceProvider = YFinanceStockPriceProvider()
    try:
        stock_price = provider.fetch(normalized_code)
        return {"price": stock_price.price, "fetched_at": stock_price.fetched_at.isoformat()}
    except Exception as error:
        logger.exception(
            "Failed to fetch stock price for code=%s name=%s",
            normalized_code,
            name,
        )
        raise HTTPException(
            status_code=502,
            detail="Failed to fetch the stock price",
        ) from error

@app.get("/stock_close")
async def get_stock_close(code: str, date: str):
    normalized_code = code.upper()
    provider: StockPriceProvider = YFinanceStockPriceProvider()
    try:
        date_value = datetime.strptime(date, "%Y-%m-%d").date()
        historical_close = provider.fetch_close(normalized_code, date_value)
        return {"close": historical_close.close, "price_date": historical_close.price_date.isoformat()}
    except Exception as error:
        logger.exception(
            "Failed to fetch close price for code=%s date=%s",
            normalized_code,
            date_value.isoformat(),
        )
        raise HTTPException(
            status_code=404,
            detail="Close price is unavailable for the date",
        ) from error
