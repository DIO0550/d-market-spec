# テストレビュールール定義

古典学派（Classical School）のテスト原則に基づくレビュールール。

---

## ルール一覧

| ID | ルール名 | 原則 |
|----|---------|------|
| MOCK-SCOPE | モック制限 | モックは外部依存関係のみに限定する |
| BEHAVIOR-TEST | 振る舞いテスト | 実装詳細ではなく観察可能な振る舞いを検証する |

---

## MOCK-SCOPE: モック制限

### 原則

モックはテストと実装の間に結合を生む。内部モジュールをモックすると、振る舞いが保持されていてもリファクタリングでテストが壊れる。モックはテスト対象と外部世界の境界でのみ使用する。

### 外部依存（モック許可）

以下はテスト対象が制御できない外部依存であり、モックしてよい:

| カテゴリ | 例 |
|---------|-----|
| ネットワーク I/O | HTTP クライアント、WebSocket、gRPC スタブ |
| データベースアクセス | SQL クエリ、ORM 呼び出し、コネクションプール |
| ファイルシステム I/O | read / write / stat / delete |
| OS・ランタイムサービス | タイマー、時刻、乱数、環境変数 |
| サードパーティ SDK | 決済ゲートウェイ、クラウドサービス、認証プロバイダ |

### 内部モジュール（モック禁止）

以下はプロジェクト内のコードであり、モックしてはならない:

| カテゴリ | 例 |
|---------|-----|
| 相対パスで import されるモジュール | `./services/UserService`, `../utils/calculate` |
| パスエイリアスで import されるプロジェクト内モジュール | `@/services/UserService`, `~/utils/calculate` |
| 同一リポジトリ内のクラス・関数・モジュール | ドメインモデル、ユーティリティ、ヘルパー |

### 検出パターン

**VIOLATION**:

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
// UserRepository は内部で定義されたインターフェースだが、
// その実装は DB アクセスという外部依存をラップしている
vi.mock('./repositories/UserRepository');
```

この場合、`UserRepository` が明示的なアーキテクチャ境界（DIP に基づく抽象）として設計されているかどうかで判断が分かれる。WARNING として報告し、レビュイーの判断に委ねる。

**判断ガイダンス**: そのインターフェースがアーキテクチャ上の境界として意図的に設計されている場合はモック許容。単なる内部クラスの場合は VIOLATION 寄り。

---

## BEHAVIOR-TEST: 振る舞いテスト

### 原則

テストはシステムが「何をするか」（観察可能な振る舞い）を検証すべきであり、「どうやるか」（実装詳細）を検証すべきではない。これによりテストがリファクタリング耐性を持つ: 振る舞いが保持される限り、内部構造を変更してもテストは通る。

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

**VIOLATION**:

```typescript
// 内部コラボレーターへの spy アサーション
const spy = vi.spyOn(calculator, 'internalCalculate');
service.process(input);
expect(spy).toHaveBeenCalled();           // 実装詳細
expect(spy).toHaveBeenCalledTimes(2);     // 実装詳細
expect(spy).toHaveBeenCalledWith(42);     // 実装詳細

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

**中間データ形状のアサーション**: テスト対象の出力契約の一部ではない中間データの形状を検証している場合。

```typescript
// processData の戻り値の内部構造を詳細に検証
// この構造が公開 API の契約の一部かどうかで判断が分かれる
const result = service.processData(input);
expect(result._metadata.processingSteps).toHaveLength(3);
```

**判断ガイダンス**: そのフィールドが公開 API の契約（型定義・ドキュメント）に含まれていれば OK。内部的な処理情報であれば VIOLATION 寄り。

### 重要な区別: 外部境界の spy は許容

外部依存（MOCK-SCOPE でモック許可とされるもの）に対する spy アサーションは VIOLATION ではない。これはシステムの外部への出力を検証しており、観察可能な振る舞いに該当する。

```typescript
// これは OK — 外部境界への出力の検証
const apiSpy = vi.spyOn(httpClient, 'post');
service.createOrder(orderData);
expect(apiSpy).toHaveBeenCalledWith('/api/orders', expect.objectContaining({
  items: orderData.items,
}));
```
