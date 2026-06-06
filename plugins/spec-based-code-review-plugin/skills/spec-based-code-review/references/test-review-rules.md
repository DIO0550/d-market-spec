# テストレビュールール定義

古典学派（Classical School）のテスト原則に基づくレビュールール。
test-quality-reviewer エージェントが参照する。計画ドキュメントを読んでテスト戦略を理解した上で適用する。

---

## ルール一覧

| ID | ルール名 | 担当次元 | 原則 |
|----|---------|---------|------|
| MOCK-SCOPE | モック制限 | 次元 10 | モックは外部依存関係のみに限定する |
| BEHAVIOR-TEST | 振る舞いテスト | 次元 11 | 実装詳細ではなく観察可能な振る舞いを検証する |
| TEST-VALUE | テスト価値 | 次元 12 | テストが意味のあるリグレッション保護を提供しているか |

---

## MOCK-SCOPE: モック制限

### 外部依存（モック許可）

| カテゴリ | 例 |
|---------|-----|
| ネットワーク I/O | HTTP クライアント、WebSocket、gRPC スタブ |
| データベースアクセス | SQL クエリ、ORM 呼び出し、コネクションプール |
| ファイルシステム I/O | read / write / stat / delete |
| OS・ランタイムサービス | タイマー、時刻、乱数、環境変数 |
| サードパーティ SDK | 決済ゲートウェイ、クラウドサービス、認証プロバイダ |

### 内部モジュール（モック禁止）

| カテゴリ | 例 |
|---------|-----|
| 相対パスで import されるモジュール | `./services/UserService`, `../utils/calculate` |
| パスエイリアスで import されるプロジェクト内モジュール | `@/services/UserService`, `~/utils/calculate` |
| 同一リポジトリ内のクラス・関数・モジュール | ドメインモデル、ユーティリティ、ヘルパー |

### 検出パターン

**CRITICAL**:

```typescript
// 相対パスの内部モジュールをモック
vi.mock('./services/UserService');
jest.mock('../utils/calculate');

// パスエイリアスの内部モジュールをモック
vi.mock('@/services/UserService');

// 内部モジュールの関数を spy してモック化
const spy = vi.spyOn(internalModule, 'someFunction');
spy.mockReturnValue(fakeValue);
```

**OK**:

```typescript
// 外部ライブラリのモック
vi.mock('axios');
jest.mock('pg');
vi.mock('@stripe/stripe-node');

// タイマー・時刻のモック
vi.useFakeTimers();
jest.spyOn(Date, 'now').mockReturnValue(1234567890);

// 環境変数のモック
vi.stubEnv('API_KEY', 'test-key');
```

### 境界ケース（WARNING）

内部インターフェースが外部依存をラップしている場合:

```typescript
vi.mock('./repositories/UserRepository');
```

**判断ガイダンス**: アーキテクチャ上の境界として意図的に設計されたインターフェースならモック許容。単なる内部クラスなら CRITICAL 寄り。

### PROTECTED パターン

| 表面的な印象 | 仕様根拠の例 |
|-------------|-------------|
| 内部モジュールをモックしている | implementation-plan のテスト戦略で「Repository 層はモックして単体テストする」と明記 |
| モックが多い | exploration-report のテストインフラ規約でモック戦略が定義されている |

---

## BEHAVIOR-TEST: 振る舞いテスト

### 観察可能な振る舞い（アサーション対象にしてよい）

| カテゴリ | 例 |
|---------|-----|
| 戻り値 | `expect(result).toBe(expected)` |
| 公開 API を通じた状態変化 | `addItem(cart, item)` の後に `cart.items` を検証 |
| 外部境界への出力 | 外部 API が正しい引数で呼ばれたことの検証 |
| 例外・エラー | `expect(() => action()).toThrow(ExpectedError)` |

### 実装詳細（アサーション対象にしてはならない）

| カテゴリ | 例 |
|---------|-----|
| 内部メソッドの呼び出し回数 | `expect(internalSpy).toHaveBeenCalledTimes(n)` |
| 内部メソッドの呼び出し引数 | `expect(internalSpy).toHaveBeenCalledWith(...)` |
| 内部メソッドの呼び出し有無 | `expect(internalSpy).toHaveBeenCalled()` |
| 内部メソッドの呼び出し順序 | 呼び出し順の検証 |
| プライベートフィールド・内部状態 | `expect(obj._privateField).toBe(...)` |

### 検出パターン

**CRITICAL**:

```typescript
// 内部コラボレーターへの spy アサーション
const spy = vi.spyOn(calculator, 'internalCalculate');
service.process(input);
expect(spy).toHaveBeenCalled();
expect(spy).toHaveBeenCalledTimes(2);
expect(spy).toHaveBeenCalledWith(42);

// プライベートメソッドの直接テスト
expect(obj['_privateMethod'](input)).toBe(expected);
expect((obj as any).privateField).toBe(expected);
```

**OK**:

```typescript
// 戻り値の検証
const result = service.process(input);
expect(result).toEqual(expectedOutput);

// 公開 API を通じた状態変化の検証
cart.addItem(item);
expect(cart.getItems()).toContain(item);
expect(cart.getTotalPrice()).toBe(1000);

// 例外の検証
expect(() => service.process(invalidInput)).toThrow(ValidationError);

// 外部境界への出力の検証（外部依存の spy は OK）
const sendEmailSpy = vi.spyOn(emailService, 'send');
service.registerUser(userData);
expect(sendEmailSpy).toHaveBeenCalledWith(
  expect.objectContaining({ to: userData.email })
);
```

### 境界ケース（WARNING）

中間データ形状のアサーション:

```typescript
const result = service.processData(input);
expect(result._metadata.processingSteps).toHaveLength(3);
```

**判断ガイダンス**: 公開 API の契約に含まれていれば OK。内部的な処理情報であれば CRITICAL 寄り。

### 重要な区別

外部依存への spy アサーションは CRITICAL ではない。システムの外部への出力の検証であり、観察可能な振る舞いに該当する。

### PROTECTED パターン

| 表面的な印象 | 仕様根拠の例 |
|-------------|-------------|
| 内部メソッドの呼び出しを検証している | implementation-plan で振る舞いの一部として保証すると明記 |
| 実装詳細に依存したテスト | exploration-report のテストインフラ規約で既存パターンとして確立 |

---

## TEST-VALUE: テスト価値

### 原則

テストはリグレッション保護のために書く。ロジック（分岐・ループ・計算・条件判定・例外送出）のないコードは壊れる可能性がほぼなく、テストしてもリグレッション保護の価値がない。そのようなテストは保守コストだけを増やす。

### ロジックのないコード（テスト不要）

| パターン | 例 |
|---------|-----|
| 単純コンストラクタ | プロパティ代入のみの `constructor(name, email) { this.name = name; this.email = email; }` |
| 単純 getter/setter | `get name() { return this._name; }` |
| パススルーメソッド | 引数をそのまま別メソッドに渡すだけの委譲 |
| 定数返却 | `getType() { return 'user'; }` |
| 単純ファクトリ | `static create(props) { return new Entity(props); }`（バリデーションなし） |

### ロジックのあるコード（テスト価値あり）

| パターン | 例 |
|---------|-----|
| 条件分岐 | `if (age < 0) throw ...` |
| 計算 | `getTotalPrice() { return items.reduce(...) }` |
| ループ | `items.forEach(item => ...)` |
| 変換 | `toDTO() { return { fullName: this.first + ' ' + this.last, ... } }` |
| バリデーション付きコンストラクタ | `constructor(email) { if (!email.includes('@')) throw ... }` |
| 状態遷移 | `approve() { if (this.status !== 'pending') throw ...; this.status = 'approved'; }` |

### 検出パターン

**WARNING**:

```typescript
// ロジックのない単純コンストラクタのテスト
test('should create user', () => {
  const user = new User('John', 'john@example.com');
  expect(user.name).toBe('John');
  expect(user.email).toBe('john@example.com');
});

// 単純 getter のテスト
test('should return name', () => {
  const user = new User('John');
  expect(user.getName()).toBe('John');
});

// パススルーメソッドのテスト
test('should delegate to repository', () => {
  service.save(entity);
  // save() が repository.save(entity) を呼ぶだけ
});
```

**OK**:

```typescript
// バリデーション付きコンストラクタのテスト（ロジックあり）
test('should reject invalid email', () => {
  expect(() => new User('John', 'invalid')).toThrow(ValidationError);
});

// 計算ロジックのテスト
test('should calculate total with tax', () => {
  cart.addItem({ price: 1000 });
  expect(cart.getTotalWithTax()).toBe(1100);
});

// 状態遷移のテスト
test('should not approve already approved order', () => {
  order.approve();
  expect(() => order.approve()).toThrow(InvalidStateError);
});
```

### 判断基準

テスト対象のコードを読んで以下を確認する:

1. **分岐（if / switch / 三項演算子）があるか？** → あればテスト価値あり
2. **ループ（for / while / map / reduce / filter）があるか？** → あればテスト価値あり
3. **計算・変換があるか？** → あればテスト価値あり
4. **例外を投げる条件があるか？** → あればテスト価値あり
5. **上記すべて NO** → テスト価値なし（WARNING）

### PROTECTED パターン

| 表面的な印象 | 仕様根拠の例 |
|-------------|-------------|
| ロジックのないコードをテストしている | implementation-plan のテストTODOリストに明示的に含まれている |
| 単純コンストラクタのテスト | hearing-notes で「オブジェクト生成の正常系を保証すること」と要求されている |
