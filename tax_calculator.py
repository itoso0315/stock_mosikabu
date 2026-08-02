price = float(input("商品の値段（税抜）を入力してください: "))

tax = price * 0.10
total_price = price + tax

print(f"消費税: {tax:.0f}円")
print(f"税込価格: {total_price:.0f}円")
