#!/usr/bin/env python3

def solve():
    n = int(input())
    a = list(map(int, input().split()))
    
    # 値ごとにインデックスのリストを作成
    pos = {}
    for i in range(n):
        if a[i] not in pos:
            pos[a[i]] = []
        pos[a[i]].append(i)
    
    result = 0
    
    # 2つの異なる値のペアを全て調べる
    values = list(pos.keys())
    m = len(values)
    
    for i in range(m):
        for j in range(i + 1, m):
            v1, v2 = values[i], values[j]
            pos1, pos2 = pos[v1], pos[v2]
            
            # v1が2個、v2が1個のパターン
            if len(pos1) >= 2:
                # pos1から2つ選ぶ組み合わせ数
                count1 = len(pos1) * (len(pos1) - 1) // 2
                # それぞれに対してpos2から1つ選ぶ
                result += count1 * len(pos2)
            
            # v1が1個、v2が2個のパターン
            if len(pos2) >= 2:
                # pos2から2つ選ぶ組み合わせ数
                count2 = len(pos2) * (len(pos2) - 1) // 2
                # それぞれに対してpos1から1つ選ぶ
                result += count2 * len(pos1)
    
    print(result)

if __name__ == "__main__":
    solve()
