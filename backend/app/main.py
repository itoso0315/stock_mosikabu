import re
from datetime import date

from fastapi import Depends, FastAPI, HTTPException, Query
from pydantic import BaseModel
from starlette.responses import PlainTextResponse

from .services.stock_price_provider import (
    StockPriceProvider,
    YFinanceStockPriceProvider,
)

app = FastAPI(title="Moshi Kabu development API")

APP_ADS_TXT = "google.com, pub-8799841145695406, DIRECT, f08c47fec0942fa0"


class StockQuoteResponse(BaseModel):
    code: str
    name: str
    price: float
    fetched_at: str


class StockCloseResponse(BaseModel):
    code: str
    date: str
    close: float
    priceDate: str


class HealthResponse(BaseModel):
    status: str


def get_stock_price_provider() -> StockPriceProvider:
    return YFinanceStockPriceProvider()


@app.get("/health", response_model=HealthResponse)
def get_health() -> HealthResponse:
    return HealthResponse(status="ok")


@app.get("/app-ads.txt", response_class=PlainTextResponse)
def get_app_ads_txt() -> str:
    return APP_ADS_TXT


@app.get("/api/stocks/{code}/quote", response_model=StockQuoteResponse)
def get_stock_quote(
    code: str,
    name: str = Query(min_length=1),
    provider: StockPriceProvider = Depends(get_stock_price_provider),
) -> StockQuoteResponse:
    normalized_code = code.strip().upper()
    if re.fullmatch(r"[0-9A-Z]{4}", normalized_code) is None:
        raise HTTPException(status_code=400, detail="Invalid Japanese stock code")

    try:
        stock_price = provider.fetch(normalized_code)
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail="Failed to fetch the stock price",
        ) from error

    return StockQuoteResponse(
        code=normalized_code,
        name=name,
        price=stock_price.price,
        fetched_at=stock_price.fetched_at.isoformat(),
    )


@app.get("/api/stocks/{code}/close", response_model=StockCloseResponse)
def get_stock_close(
    code: str,
    date_value: date = Query(alias="date"),
    provider: StockPriceProvider = Depends(get_stock_price_provider),
) -> StockCloseResponse:
    normalized_code = code.strip().upper()
    if re.fullmatch(r"[0-9A-Z]{4}", normalized_code) is None:
        raise HTTPException(status_code=400, detail="Invalid Japanese stock code")
    try:
        result = provider.fetch_close(normalized_code, date_value)
    except Exception as error:
        raise HTTPException(
            status_code=404,
            detail="Close price is unavailable for the date",
        ) from error
    return StockCloseResponse(
        code=normalized_code,
        date=date_value.isoformat(),
        close=result.close,
        priceDate=result.price_date.isoformat(),
    )
