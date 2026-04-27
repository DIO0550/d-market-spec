---
name: spec-driven-dev-lite
description: 仕様策定ワークフローの軽量版。サブエージェントを使わず、ユーザーが探索範囲を指定し、オーケストレーターが直接計画を生成。トークン消費を大幅に削減。
disable-model-invocation: true
allowed-tools: Bash(ls *), Bash(mkdir *), Bash(touch *), Bash(echo *), Bash(printf *), Bash(rm .plugin-workspace/.specs/*/PLANNING), Bash(rm .plugin-workspace/.specs/.guard/*), Bash(find *), Bash(grep *), Bash(wc *)
---

# Spec-Driven Development (Lite)

機能実装前に仕様を明確化し、実装計画とタスクリストを生成する軽量版スキル。
**サブエージェントを使わず、ユーザーが探索範囲を指定し、オーケストレーターが直接計画を生成する。**
複雑な機能で網羅的な探索が必要な場合は、フルバージョン `spec-driven-dev` を使用すること。

## 絶対厳守事項

1. **最初にフォルダとPLANNINGファイルを作成** — 質問・探索・実装の前に必ず Step 1 を実行
2. **システム図は必須** — implementation-plan.md には状態マシン図 + データフロー図を含める（ASCII罫線優先）
3. **PLANNINGファイルがある間はコード実装禁止** — AutoCompact 対策

## ワークフロー概要

```
1. specsフォルダ作成 + PLANNINGファイル + ガードファイル配置
   ↓
2. 簡易ヒアリング (1バッチ, 関連ファイルをユーザーに聞く) → hearing-notes.md
   ↓
3. ユーザー指定ファイルの確認 Read (指定なしの場合のみ最小探索)
   ↓
4. implementation-plan.md + tasks.md を直接生成
   ↓
5. ユーザー確認
   ↓
6. ガード解除案内
```

## Step 1: specsフォルダ + PLANNINGファイル作成

### 1-a. 次のspec番号を算出

```bash
next_num=$(ls -1d .plugin-workspace/.specs/[0-9][0-9][0-9]-* .plugin-workspace/.specs/archive/[0-9][0-9][0-9]-* 2>/dev/null | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' | sort -rn | head -1)
next_num=$(printf "%03d" $(( 10#${next_num:-0} + 1 )))
```

### 1-b. specディレクトリとPLANNINGファイル作成

```bash
mkdir -p .plugin-workspace/.specs/${next_num}-{feature-name}
echo "${CLAUDE_SESSION_ID}" > .plugin-workspace/.specs/${next_num}-{feature-name}/PLANNING
```

### 1-c. ガードファイル作成

```bash
mkdir -p .plugin-workspace/.specs/.guard && touch .plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID}
```

## Step 2: 簡易ヒアリング → hearing-notes.md

AskUserQuestion で以下を1バッチで聴取する。

### 必須質問

- **目的とスコープ**: 何を実現したいか、新規 or 既存修正か
- **技術アプローチ**: 使用技術・パターン、既存コードとの関係
- **関連ファイル/ディレクトリ**: 関係するファイルやディレクトリのパスを列挙してもらう（選択肢に「わからない」を含める）

### 条件付き質問

- **テスト方針**: テスト可能なロジックがありそうな場合のみ（TDD / テスト追加 / 手動検証のみ）

### hearing-notes.md 書き出し

ヒアリング結果を以下の形式で書き出す:

```markdown
# Hearing Notes: {機能名}

## 目的
{1-2文}

## スコープ
- **種別**: {新規機能 / 既存修正 / バグ修正 / リファクタリング}
- **影響範囲**: {新規 / 既存修正}

## 技術的詳細
{使用技術・フレームワーク・依存関係}

## 関連ファイル
{ユーザーが指定したファイル/ディレクトリ一覧、または「指定なし」}

## テスト方針
{TDD / テスト追加 / 手動検証のみ / 未定}
```

## Step 3: ファイル確認

### 通常パス（ユーザーがファイル/ディレクトリを指定した場合）

ユーザーが指定したファイルのみ Read で確認する。自律的な grep/find は行わない。

### フォールバックパス（ユーザーが「わからない」と答えた場合）

最小限の探索を行う:

1. `find src -type f -name "*.{拡張子}" | head -20` でプロジェクト構造把握
2. ヒアリングから1-2キーワードを抽出し `grep -rl "{keyword}" src/ | head -5` で関連ファイル特定
3. 上位3ファイルのみ Read

これ以上の探索が必要な場合はフルバージョン (`spec-driven-dev`) の使用を推奨する旨をユーザーに伝える。

## Step 4: implementation-plan.md + tasks.md 生成

テンプレート `assets/templates/implementation-plan.md` と `assets/templates/tasks.md` を参照し、オーケストレーターが直接生成する。

### 必須要素（hookで検証される）

- `### 状態マシン / フロー図` セクション + ASCII罫線図 or mermaid
- `### データフロー` セクション + ASCII罫線図 or mermaid
- `## 変更案` セクション内にコードブロック（型定義・関数シグネチャ）

### tasks.md の構成判断

- Pure Logic / Data Transformation / State Management → TDD構成（Red-Green-Refactor）
- API / Async / UI Component で自動テストが有効 → Implementation + Test セクション
- 純粋なUI/スタイリング変更 → 手動検証のみ

## Step 5: ユーザー確認

生成ファイルをユーザーに提示:

1. specフォルダパス
2. implementation-plan.md の要約（変更案とDoD）
3. tasks.md のタスク一覧
4. 「修正が必要な場合はお知らせください」

## Step 6: ガード解除案内

```
実装を開始するには、以下のコマンドを実行してください:
rm .plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID} .plugin-workspace/.specs/{nnn}-{feature-name}/PLANNING
```

ガードファイルはhookにより自動削除がブロックされる。必ずユーザーが手動で削除すること。

## 出力ディレクトリ

```
.plugin-workspace/.specs/
└── {nnn}-{feature-name}/
    ├── PLANNING                 # 計画中は存在、実装開始時に削除
    ├── hearing-notes.md         # ヒアリング結果
    ├── implementation-plan.md   # 実装計画（システム図・変更案・DoD含む）
    └── tasks.md                 # タスクリスト
```
