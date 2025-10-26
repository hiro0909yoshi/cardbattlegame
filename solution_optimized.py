#!/usr/bin/env python3

def solve():
    n = int(input())
    a = [0] * n  # 各値の出現回数をカウント（0-indexed）
    
    # 入力を読み込み、各値の出現回数をカウント
    arr = list(map(int, input().split()))
    for x in arr:
        a[x - 1] += 1
    
    ans = 0
    # 各値について、その値が2個、他の値が1個の組み合わせを計算
    for i in range(n):
        ans += a[i] * (a[i] - 1) * (n - a[i]) // 2
    
    print(ans)

if __name__ == "__main__":
    solve()
