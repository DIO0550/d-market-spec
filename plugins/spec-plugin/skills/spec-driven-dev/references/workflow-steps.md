# ワークフロー共通手順

spec-driven-dev 系スキルの共通ステップ詳細。
SKILL.md本文で宣言されたパラメータを参照して実行する。

## 目次

- [出力形式解決](#出力形式解決)
- [Step 1: specsフォルダ + PLANNINGファイル作成](#step-1-specsフォルダ--planningファイル作成)
- [Step 2: ヒアリング → hearing-notes 書き出し](#step-2-ヒアリング--hearing-notes-書き出し)
- [Step 2.5: Reflective Gate（ヒアリング品質検証）](#step-25-reflective-gateヒアリング品質検証)
- [Step 3: コードベース探索](#step-3-コードベース探索codebase-explorer-サブエージェントに委譲)
- [Step 3.5: 探索後ヒアリング](#step-35-探索後ヒアリング-条件付き)
- [Step 4: 実装計画生成](#step-4-実装計画生成spec-planner-サブエージェントに委譲)
- [ユーザー確認](#ユーザー確認)
- [tech-reference 生成](#tech-reference-生成サブエージェントに委譲)
- [ガード解除 / PLANNINGファイル削除](#ガード解除use_guard--true-の場合)

**パラメータ一覧**（SKILL.md本文で宣言）:

| パラメータ | 説明 | 例 |
|-----------|------|-----|
| `{SKILL_NAME}` | 現在のスキル名 | `spec-driven-dev` |
| `{PLANNING_CONTENT}` | PLANNINGファイルに書く内容 | `${CLAUDE_SESSION_ID}` |
| `{USE_GUARD}` | ガードファイルを使用するか | `true` / `false` |
| `{HEARING_NOTES_EXT}` | hearing-notes の拡張子 | `.md` / `.html` |
| `{EXPLORATION_REPORT_EXT}` | exploration-report の拡張子 | `.md` / `.html` |
| `{IMPLEMENTATION_PLAN_EXT}` | implementation-plan の拡張子 | `.md` / `.html` |
| `{TASKS_EXT}` | tasks の拡張子 | `.md` / `.html` |
| `{TECH_REFERENCE_EXT}` | tech-reference の拡張子 | `.md` / `.html` |

---

## 出力形式解決

`.plugin-workspace/.specs/.config.yml` の `output-formats` セクションを読み取り、ファイルごとの拡張子を決定する。

### 解決ロジック

1. `.plugin-workspace/.specs/.config.yml` を Read する
2. `output-formats` キーが存在する場合:
   - 各ファイルキー（`hearing-notes`, `exploration-report`, `implementation-plan`, `tasks`, `tech-reference`）の値を読む
   - `html` → `.html`、`md` → `.md`
3. `output-formats` キーが存在しない場合、またはキーが欠落している場合: `.md` をデフォルトとする

### HTML出力時の共通ルール

`.html` が指定されたファイルを生成する際は:

1. `assets/templates/style.css` を Read してCSSを取得
2. 対応する HTML テンプレート（`assets/templates/{ファイル名}.html`）を Read
3. テンプレートの `<link rel="stylesheet" href="style.css">` を `<style>{CSS内容}</style>` に置換
4. プレースホルダを内容で埋めて自己完結型HTMLとして出力

サブエージェントに HTML 出力を委譲する場合は、プロンプトに以下を追加する:

```
## 出力形式
**HTML形式で出力すること。**
1. {SKILL_NAME}:style を Read してCSSを取得
2. {SKILL_NAME}:{テンプレート名} を Read してHTMLテンプレートを取得
3. テンプレートの <link> を <style>{CSS}</style> に置換
4. プレースホルダを内容で埋める
5. 自己完結型HTMLとして出力
```

---

## Step 1: specsフォルダ + PLANNINGファイル作成

### 1-a. 次のspec番号を算出

`.plugin-workspace/.specs/` と `.plugin-workspace/.specs/archive/` の両方をスキャンし、最大番号+1 をゼロ埋め3桁で `$next_num` にセットする。

```bash
next_num=$(ls -1d .plugin-workspace/.specs/[0-9][0-9][0-9]-* .plugin-workspace/.specs/archive/[0-9][0-9][0-9]-* 2>/dev/null | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' | sort -rn | head -1)
next_num=$(printf "%03d" $(( 10#${next_num:-0} + 1 )))
```

### 1-b. specディレクトリとPLANNINGファイル作成

`{feature-name}` は実際の機能名（kebab-case）に置き換える。

```bash
mkdir -p .plugin-workspace/.specs/${next_num}-{feature-name}
echo "{PLANNING_CONTENT}" > .plugin-workspace/.specs/${next_num}-{feature-name}/PLANNING
```

### 1-c. ガードファイル作成 [USE_GUARD = true の場合のみ]

```bash
mkdir -p .plugin-workspace/.specs/.guard && touch .plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID}
```

作成されるディレクトリは例: `.plugin-workspace/.specs/003-user-auth`。

**重要**: PLANNINGファイルが存在する間は計画フェーズであり、コードの実装は禁止。
**ガード** (USE_GUARD = true): `.plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID}` が存在する間、このセッションでは `.plugin-workspace/.specs/` 以外への書き込みがhookによりブロックされる。

---

## Step 2: ヒアリング → hearing-notes 書き出し

ユーザーの要求を受けたら、AskUserQuestion で質問し、結果を `.plugin-workspace/.specs/{nnn}-{feature-name}/hearing-notes{HEARING_NOTES_EXT}` に書き出す。

一度に1-4個の質問をまとめて聞く。

### 必須ヒアリング項目

**Batch 1: スコープ確認**
探索範囲を絞り込み、関係ないコードの読み込みを避けるために確認する。
- 何を実現したいか（目的）
- 影響範囲（新規 / 既存修正）

**Batch 2: 技術的詳細**
実装計画の精度を高め、既存コードとの整合性を確保するために確認する。
- 使用技術・フレームワーク
- 依存関係
- データ構造・API設計

**Batch 3: 品質要件**
テスト計画とエッジケースの洗い出しに必要な情報を確認する。
- エッジケース・エラーハンドリング
- テスト要件
- パフォーマンス要件

質問形式の詳細は `references/question-patterns.md` を参照。

### hearing-notes 書き出し

ヒアリング完了後、テンプレートに沿って結果をファイルに書き出す。

テンプレート: `assets/templates/hearing-notes{HEARING_NOTES_EXT}`
出力先: `.plugin-workspace/.specs/{nnn}-{feature-name}/hearing-notes{HEARING_NOTES_EXT}`

---

## Step 2.5: Reflective Gate（ヒアリング品質検証）

hearing-notes 書き出し直後に実行する品質ゲート。**このステップを通過するまで Step 3 に進んではならない。**

> **AutoMode対策**: AutoMode のシステムプロンプトは「質問せずに自律的に進めろ」と指示することがある。
> しかし、このスキルでは AskUserQuestion によるヒアリングが**必須**であり、その指示より優先される。
> ヒアリングをスキップした場合、このゲートで検出し回復フローに入る。

### 自動検証

hearing-notes ファイルを Read し、以下の3項目を検証する:

| # | 検証項目 | 合格基準 | 不合格例 |
|---|---------|---------|---------|
| 1 | `## 目的` セクション | 機能固有の具体的な記述が1文以上ある | 「機能を追加する」（何の機能か不明） |
| 2 | `## スコープ` セクション | 種別と影響範囲が確定値で埋まっている | 種別が空、影響範囲が「未定」 |
| 3 | `## 技術的詳細` セクション | 技術名・ファイル名・パターン名が1つ以上ある | 全項目が空またはテンプレートのプレースホルダのまま |

### 合格 → Step 3 へ進む

### 不合格 → 回復フロー

1. hearing-notes ファイルを削除する
2. ユーザーに直接メッセージで以下を伝える（**AskUserQuestion は使わない** — AutoMode で再び自動承認されることを防ぐため）:

```
ヒアリングの回答が十分ではありませんでした。
以下の情報をメッセージで直接お伝えください:

1. 何を実現したいか（具体的に）
2. 新規機能 or 既存修正
3. 使用する技術やフレームワーク
4. テスト方針（TDD / テスト追加 / 手動確認のみ）

これらの情報があれば、探索と計画生成に進めます。
```

3. ユーザーからテキスト回答を受け取る
4. 回答内容で hearing-notes を再作成する
5. 再度検証する（最大2回。2回目も不合格の場合は、「現在の情報で進めます。不足があれば Step 3.5 で補完します」と伝えて通過させる）

---

## Step 3: コードベース探索（codebase-explorer サブエージェントに委譲）

### 3-1. 探索ヒントの抽出

サブエージェント起動前に、hearing-notes の内容から以下を抽出する：

- **探索キーワード**: 機能名、技術用語、ライブラリ名、コンポーネント名など（5-10個）
- **推定対象パス**: 影響しそうなディレクトリやファイルパターン（hearing-notesの技術スタック・影響範囲から推定）
- **探索の重点**: 新規機能なら類似実装の発見を重視、既存修正なら依存の逆引きを重視

### 3-2. サブエージェント起動

```
Task tool:
  description: "codebase-explorer: {feature-name}"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたはcodebase-explorerエージェントです。
    .plugin-workspace/.specs/{nnn}-{feature-name}/hearing-notes{HEARING_NOTES_EXT} を読み込み、
    その目的・スコープに基づいてコードベースを探索してください。

    ## 探索ヒント（オーケストレーターが抽出）

    **キーワード**: {hearing-notesから抽出したキーワード5-10個をカンマ区切りで列挙}
    **推定対象パス**: {推定したディレクトリ/ファイルパターンを列挙}
    **探索の重点**: {新規→類似実装発見 / 既存修正→依存逆引き / リファクタリング→全使用箇所 等}

    ## 参照スキル
    {SKILL_NAME}:exploration-perspectives

    ## テンプレート
    {SKILL_NAME}:exploration-report

    ## 出力先
    .plugin-workspace/.specs/{nnn}-{feature-name}/exploration-report{EXPLORATION_REPORT_EXT}

    ## 出力形式に関する注意
    exploration-report の拡張子は {EXPLORATION_REPORT_EXT} です。
    .html の場合は、{SKILL_NAME}:style と {SKILL_NAME}:exploration-report の HTML テンプレートを Read し、
    CSS埋め込みの自己完結型HTMLとして出力してください。
```

`{...}` はオーケストレーターが hearing-notes の内容に基づいて埋める。

```
TaskOutput:
  task_id: "{codebase-explorerのtask_id}"
  block: true
  timeout: 300000
```

### 3-3. 探索結果の品質検証

TaskOutput 受信後、exploration-report を読み込み、セクション 8「探索メトリクス」を確認する：

1. **基準チェック**:
   - Read したファイル数が 10 未満 → 補完探索を要求
   - コードスニペット数が 5 未満 → 補完探索を要求
   - 逆引き検索が「未実施」→ 補完探索を要求

2. **空セクション検出**:
   - セクション 1-5 のいずれかがテンプレートのプレースホルダのまま → 補完探索を要求

3. **補完探索の実行**（品質基準未達の場合のみ、**最大 1 回**）:

```
Task tool:
  description: "codebase-explorer (補完): {feature-name}"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたはcodebase-explorerエージェントです。
    前回の探索レポートが品質基準に達していないため、補完探索を行います。

    ## 前回のレポート
    .plugin-workspace/.specs/{nnn}-{feature-name}/exploration-report{EXPLORATION_REPORT_EXT}

    ## 不足している項目
    {具体的な不足項目を列挙}

    ## 指示
    前回のレポートに不足している情報を追加してください。
    特に以下に重点を置いてください：
    - 不足しているコードスニペットの追加（ファイルを Read して具体的なコードを記載）
    - 不足しているセクションの探索と記入
    - 探索メトリクスの更新

    ## 参照スキル
    {SKILL_NAME}:exploration-perspectives

    ## 出力先
    .plugin-workspace/.specs/{nnn}-{feature-name}/exploration-report{EXPLORATION_REPORT_EXT}（上書き更新）
```

```
TaskOutput:
  task_id: "{補完codebase-explorerのtask_id}"
  block: true
  timeout: 300000
```

探索の5カテゴリ: アーキテクチャ概要 / 関連コード分析 / 技術的制約・リスク / 変更影響範囲 / テストインフラストラクチャ

詳細は `references/exploration-perspectives.md` を参照。

---

## Step 3.5: 探索後ヒアリング (条件付き)

exploration-report を読み込み、ユーザー判断が必要な論点を抽出する。論点が無ければスキップして Step 4 へ進む。

### 3.5-1. 論点抽出

以下のセクションをスキャンし、ユーザー確認が必要な論点を最大 5 件抽出する:

- **Section 3 技術的制約・リスク**: 対応方針が複数ある場合
- **Section 4 変更影響範囲**: 破壊的変更の方針判断が必要な場合
- **Section 6 追加調査が必要な項目**: 設計判断に直結する未確定事項
- **Section 2.2 再利用可能なパターン**: 候補が複数ある場合の選択

抽出した論点を exploration-report の Section 7「ユーザー判断が必要な論点」に書き戻す（監査証跡）。

### 3.5-2. 論点の有無で分岐

- **論点 0 件**: Section 7 に「該当なし」と記載し、Step 4 へ進む
- **論点 1 件以上**: 3.5-3 へ進む

### 3.5-3. AskUserQuestion 発動

論点を重要度順に並べ、上位 4 件 (AskUserQuestion 上限) を 1 ターンで一括聴取する。

- **question**: 論点の概要 (1 文)
- **header**: 12 文字以内の短いラベル
- **options**: 探索で見つかった選択肢 + 推奨案を先頭に「(推奨)」付きで配置
- 5 件以上ある場合、優先度の低いものは Section 7 末尾の「未確認論点」に記載し、spec-planner が assumption として扱う

### 3.5-4. hearing-notes に追記

AskUserQuestion の回答結果を hearing-notes 末尾の `## 探索後ユーザー判断` セクションに追記する:

- 各論点 (question) と選択された option label
- ユーザーが Other で自由記述した場合はその内容も含める

---

## Step 4: 実装計画生成（spec-planner サブエージェントに委譲）

exploration-report が完成したら、spec-planner サブエージェントを起動する。

```
Task tool:
  description: "spec-planner: {feature-name}"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたはspec-plannerエージェントです。
    以下のファイルを読み込み、implementation-plan と tasks を生成してください。

    ## 入力
    - .plugin-workspace/.specs/{nnn}-{feature-name}/hearing-notes{HEARING_NOTES_EXT}
    - .plugin-workspace/.specs/{nnn}-{feature-name}/exploration-report{EXPLORATION_REPORT_EXT}

    ## テンプレート・出力先
    - implementation-plan: テンプレート {SKILL_NAME}:implementation-plan → 出力 .plugin-workspace/.specs/{nnn}-{feature-name}/implementation-plan{IMPLEMENTATION_PLAN_EXT}
    - tasks: テンプレート {SKILL_NAME}:tasks → 出力 .plugin-workspace/.specs/{nnn}-{feature-name}/tasks{TASKS_EXT}

    ## 出力形式に関する注意
    各ファイルの拡張子（.md / .html）は上記の通りです。
    .html の場合は、{SKILL_NAME}:style を Read してCSSを取得し、
    対応する HTML テンプレートの <link> を <style>{CSS}</style> に置換して、
    自己完結型HTMLとして出力してください。

    ## 重要
    - システム図（状態マシン図 + データフロー図）は必須。省略禁止。ASCII罫線図を優先。
    - exploration-report の制約・リスクを implementation-plan に反映すること。
    - implementation-plan に "## Definition of Done" セクションを必ず含めること。機能固有の受入条件を具体的に記載すること。
    - テスト戦略分析を必ず実施すること。references/test-design-patterns.md に基づき、機能タイプを分類してテストパターンを決定すること。
    - テスト要件がある場合、t-wada TDD ベースで tasks を構成すること（Red-Green-Refactor サイクル、TODOリスト駆動）。テンプレートの TDD 構成例を参照。
    - 変更案セクションの [NEW] には実装骨格（型定義・関数シグネチャ・import文）、[MODIFY] には before/after 形式のコードスニペットを必ず含めること。
```

```
TaskOutput:
  task_id: "{spec-plannerのtask_id}"
  block: true
  timeout: 300000
```

---

## ユーザー確認

生成したファイルをユーザーに提示:

1. **specフォルダパス**: `.plugin-workspace/.specs/{nnn}-{feature-name}/` を明示
2. 生成ファイル一覧（各ファイルのフルパス）:
   - `.plugin-workspace/.specs/{nnn}-{feature-name}/hearing-notes{HEARING_NOTES_EXT}`
   - `.plugin-workspace/.specs/{nnn}-{feature-name}/exploration-report{EXPLORATION_REPORT_EXT}`
   - `.plugin-workspace/.specs/{nnn}-{feature-name}/implementation-plan{IMPLEMENTATION_PLAN_EXT}`
   - `.plugin-workspace/.specs/{nnn}-{feature-name}/tasks{TASKS_EXT}`
   - `.plugin-workspace/.specs/{nnn}-{feature-name}/tech-reference{TECH_REFERENCE_EXT}`（tech-reference 生成後に追加提示）
3. implementation-plan の内容サマリー
4. tasks のタスク一覧
5. 「修正が必要な場合はお知らせください」

ユーザーが修正を要求した場合:

1. フィードバック明確性チェック（[feedback-clarification.md](feedback-clarification.md) 参照）
2. 曖昧な場合 → AskUserQuestion で具体化してから Step 4 に戻る
3. 明確な場合 → そのまま Step 4（レビュー付きバリアントはレビューループ）に戻る

---

## tech-reference 生成（サブエージェントに委譲）

ユーザー確認完了後、サブエージェントを起動して tech-reference を生成する。
implementation-plan に登場するすべての技術を、初学者向けに解説するコンパニオンドキュメントを作成する。

### サブエージェント起動

```
Task tool:
  description: "tech-reference-writer: {feature-name}"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたは技術リファレンスライターです。
    implementation-plan を読み込み、そこに登場するすべての技術を
    初学者向けに解説する tech-reference ドキュメントを生成してください。

    読者は、言語やライブラリ、作ろうとしているものの初心者です。
    前提知識ゼロでも理解できる平易な説明を心がけてください。

    ## 入力
    - .plugin-workspace/.specs/{nnn}-{feature-name}/implementation-plan{IMPLEMENTATION_PLAN_EXT}

    ## テンプレート
    - {SKILL_NAME}:tech-reference（拡張子 {TECH_REFERENCE_EXT} に対応するテンプレートを使用）

    ## 出力先
    - .plugin-workspace/.specs/{nnn}-{feature-name}/tech-reference{TECH_REFERENCE_EXT}

    ## 出力形式に関する注意
    tech-reference の拡張子は {TECH_REFERENCE_EXT} です。
    .html の場合は、{SKILL_NAME}:style を Read してCSSを取得し、
    対応する HTML テンプレートの <link> を <style>{CSS}</style> に置換して、
    自己完結型HTMLとして出力してください。

    ## 執筆ルール
    - implementation-plan の変更案セクションに登場するすべての技術をカバーする
    - 冒頭に **Technology Stack Overview** として、この機能で使う技術同士の関係をASCII図で俯瞰する（言語→フレームワーク→ライブラリ→APIの依存関係）
    - 各技術エントリに以下を含める:
      - 「何か」「なぜ使うか」
      - **仕組みの概念図**: その技術の動作モデルをASCII図で示す
      - **学習ステップ**: 「まず知るべきこと → 次に知るべきこと → 実践で使う」の3段階
      - **コード例 — before / after**: この技術を使わない場合と使う場合の比較
    - コード例は implementation-plan の変更案に沿った文脈のものにする
    - 外部URLは含めない（Web検索なしで完結させる）
    - Glossary に implementation-plan の専門用語をすべて収集する
    - Tools & Infrastructure セクションには主なコマンドも記載する
    - 該当する技術がないカテゴリセクションは省略する

    ## 品質チェック
    - [ ] 冒頭に Technology Stack Overview の俯瞰図があるか
    - [ ] implementation-plan の変更案に登場するすべての技術名が含まれているか
    - [ ] 各エントリに仕組みの概念図（ASCII図）があるか
    - [ ] 各エントリに学習ステップ（3段階）があるか
    - [ ] 各エントリにbefore/afterのコード比較があるか
    - [ ] 各エントリに「なぜ使うか」の説明があるか
    - [ ] Glossary に専門用語がすべて含まれているか
```

```
TaskOutput:
  task_id: "{tech-reference-writerのtask_id}"
  block: true
  timeout: 180000
```

### 生成後の提示

tech-reference 生成完了後、ユーザーに以下を追加提示する:

- `tech-reference{TECH_REFERENCE_EXT}` のファイルパス
- 「技術リファレンスを生成しました。implementation-plan と合わせてご参照ください。」

---

## ガード解除（USE_GUARD = true の場合）

計画が完了したら、ユーザーに以下を案内する:

1. ガードファイルの削除（**ユーザーが手動で実行**）
2. PLANNINGファイルの削除

```
ユーザーへの案内:
  実装を開始するには、以下のコマンドを実行してください:
  rm .plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID} .plugin-workspace/.specs/{nnn}-{feature-name}/PLANNING
```

**注意**: ガードファイルはhookにより自動削除がブロックされる。必ずユーザーが手動で削除すること。
**注意**: ガード解除前に実装コードを書いてはならない。

## PLANNINGファイル削除（USE_GUARD = false の場合）

ユーザーから実装開始の許可を得たら、PLANNINGファイルを削除する。

```bash
rm .plugin-workspace/.specs/{nnn}-{feature-name}/PLANNING
```

**注意**: PLANNINGファイル削除前に実装コードを書いてはならない。
