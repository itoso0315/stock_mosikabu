"""Mac向けデスクトップ版・株式管理GUIの起動エントリーポイント。

このファイルは既存のTkinter版を残すための入口です。
Safariで動かすWeb版は別ファイルで作成し、このファイルは変更せず維持します。
"""

from app import StockManagerApp


def main():
    StockManagerApp().mainloop()


if __name__ == "__main__":
    main()
