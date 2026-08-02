def input_number(label):
    while True:
        try:
            return int(input(label))
        except ValueError:
            print("数字を入力してください。")


def get_title(level):
    if level < 10:
        return "見習い"
    if level < 30:
        return "冒険者"
    if level < 50:
        return "英雄"
    return "伝説"


print("=== キャラクター作成 ===")

name = input("名前：")
job = input("職業：")
level = input_number("レベル：")
attack = input_number("攻撃力：")
defense = input_number("防御力：")

combat_power = attack + defense
title = get_title(level)

print("\n========================")
print(f"{title} {name}\n")
print(f"職業：{job}")
print(f"レベル：{level}\n")
print("🟢 HP：██████████")
print(f"🔴 攻撃力：{attack}")
print(f"🔵 防御力：{defense}\n")
print(f"総合戦闘力：{combat_power}\n")
print("========================")
