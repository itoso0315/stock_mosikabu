height_cm = float(input("身長をcmで入力してください: "))
weight_kg = float(input("体重をkgで入力してください: "))

height_m = height_cm / 100
bmi = weight_kg / (height_m ** 2)

print(f"BMIは {bmi:.1f} です。")