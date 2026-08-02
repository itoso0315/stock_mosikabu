import unittest

from api import parse_minkabu_dividend_months, parse_minkabu_stock_name


class MinkabuStockNameTest(unittest.TestCase):
    def test_extracts_japanese_name_from_title(self):
        page_html = "<html><head><title>三菱商事 (8058) : 株価 - みんかぶ</title></head></html>"

        self.assertEqual(parse_minkabu_stock_name(page_html, "8058"), "三菱商事")

    def test_extracts_name_for_alphanumeric_code(self):
        page_html = "<title>キオクシアホールディングス (285A) : 株価 - みんかぶ</title>"

        self.assertEqual(parse_minkabu_stock_name(page_html, "285A"), "キオクシアホールディングス")

    def test_returns_none_without_matching_title(self):
        self.assertIsNone(parse_minkabu_stock_name("<html>not found</html>", "8058"))

    def test_extracts_dividend_record_months(self):
        page_html = "<div>配当権利確定月 <strong>3月, 9月</strong></div>"

        self.assertEqual(parse_minkabu_dividend_months(page_html), [3, 9])
