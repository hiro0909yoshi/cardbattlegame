# 3Dキャラクターモデル ワークフロー

## 確定ワークフロー
1. Meshy AI でキャラクター3Dモデル生成
2. MeshyからFBXダウンロード
3. Mixamoにアップロード → 自動リグ
4. Mixamoから各アニメーションを「With Skin」「In Place」でFBXダウンロード
5. `assets/models/{キャラ名}/` にFBXを配置（walk.fbx, idle.fbx）
6. Godotに直接インポート（GLB変換不要）
7. CharacterBody3Dをルートにしたシーン(.tscn)を作成

## フォルダ構造
```
assets/models/
├── necromancer/
│   ├── walk.fbx
│   └── idle.fbx
├── {次のキャラ}/
│   ├── walk.fbx
│   └── idle.fbx
```

## シーン構造 (例: scenes/Characters/Necromancer.tscn)
```
CharacterBody3D (Player)
├── CollisionShape3D
├── WalkModel (walk.fbx instance) - 移動時表示
│   ├── Camera (visible=false)
│   ├── Camera_001 (visible=false)
│   ├── Light (visible=false)
│   └── Light_001 (visible=false)
└── IdleModel (idle.fbx instance) - 停止時表示
    ├── Camera (visible=false)
    ├── Camera_001 (visible=false)
    ├── Light (visible=false)
    └── Light_001 (visible=false)
```

## モデル設定
- スケール: 2.2倍
- 位置オフセット: X=0, Y=0, Z=0 (モデル自体)
- タイル上オフセット: TILE_OFFSET = Vector3(0.8, 0, 0.8) (movement_controller.gd)
- 停止時の向き: Y軸45度

## アニメーション制御 (movement_controller.gd)
- `_play_walk_animation(player_node, true)`: WalkModel表示+mixamo_com再生、IdleModel非表示
- `_play_walk_animation(player_node, false)`: IdleModel表示+mixamo_com再生、WalkModel非表示、45度回転
- `_face_direction()`: look_atで進行方向を向く（-direction=反転で正面向き）
- アニメーション名: "mixamo_com" (Mixamoデフォルト)
- ループ設定: FBXインポート設定でループモード=Linear

## FBXインポート注意点
- FBXに含まれるCamera/Lightは非表示にする（ゲームのカメラ/ライトと干渉）
- FBXのルートはNode3Dなので、CharacterBody3Dの子ノードとして配置
- `assets/images/`にFBXを置くとフリーズする場合がある → `assets/models/`に配置

## 初期アニメーション設定
- quest_game.gd, game_3d.gd の `_setup_initial_animation()` でIdleモデル表示+再生
- プレイヤー・敵の両方に適用必要

## characters.json
- model_path で各キャラクターのシーンパスを指定
- 現在全キャラクターが Necromancer.tscn を参照

## 未解決・今後の課題
- モデルの正面方向補正（現在はlook_at + 45度固定で対応）
- テクスチャ未適用（灰色のまま）
- キャラクターごとの個別モデル作成（現在は全員ネクロマンサー）
