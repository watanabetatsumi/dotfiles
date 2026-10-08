# 顧客画面 vs 管理画面 比較早見表

フロントエンドが2つあるため、初心者が混乱しやすい違いをまとめる。

## 基本情報

| 項目 | 顧客画面 (`policy-cloud-front`) | 管理画面 (`policy-cloud-server/frontend`) |
|-----|-------------------------------|------------------------------------------|
| フレームワーク | Next.js 15 + React 19 | React 18 + Vite |
| ルーティング | Next.js App Router（ファイルベース） | TanStack Router |
| データ取得 | GraphQL（Strawberry） / Server Component | REST API（OpenAPI クライアント）+ TanStack Query |
| UI ライブラリ | Material-UI + Tailwind CSS | Chakra UI |
| 認証 | Firebase（GCP Identity Platform） | Firebase（GCP Identity Platform） |
| 型生成 | `npm run generate`（GraphQL Codegen） | `make generate-client`（OpenAPI Generator） |
| ビルド | `npm run build` | `npm run build` |
| テスト | `npm run test:run` | `npm run test:run` |

## ディレクトリ構造

### 顧客画面

```
policy-cloud-front/src/
├── app/
│   ├── (authorized)/          # 認証必須ルート
│   │   ├── meetings/
│   │   │   ├── page.tsx       # 会議一覧
│   │   │   ├── loading.tsx    # ローディング UI
│   │   │   ├── error.tsx      # エラー UI
│   │   │   └── [id]/page.tsx  # 会議詳細
│   │   └── ...
│   ├── (unauthorized)/        # 認証不要ルート
│   └── _components/           # 共有コンポーネント
├── lib/
│   ├── gql/
│   │   ├── queries/           # ← ここを編集する
│   │   └── generated/         # ← 自動生成（編集禁止）
│   └── firebase/
└── ...
```

### 管理画面

```
policy-cloud-server/frontend/src/
├── routes/                    # TanStack Router のルート
│   ├── __root.tsx             # ルートレイアウト
│   ├── index.tsx              # トップページ
│   └── meetings/
│       ├── index.tsx          # 会議一覧
│       └── $id.tsx            # 会議詳細（$id は動的パラメータ）
├── client/                    # ← 自動生成（編集禁止）
│   └── ...                    # make generate-client で更新
├── components/                # 共有コンポーネント
└── ...
```

## データ取得パターン

### 顧客画面（GraphQL）

```typescript
// 1. クエリを定義（src/lib/gql/queries/meeting.graphql）
query GetMeeting($id: Int!) {
  meeting(id: $id) {
    id
    title
    heldAt
  }
}

// 2. 型生成（npm run generate）

// 3. 生成された hook を使う
import { useGetMeetingQuery } from "@/lib/gql/generated/graphql";

const { data, loading, error } = useGetMeetingQuery({ variables: { id } });
```

### 管理画面（REST API + TanStack Query）

```typescript
// 1. OpenAPI クライアントを使う（src/client/ は自動生成済み）
import { MeetingsService } from "@/client";

// 2. TanStack Query の useQuery でラップ
import { useQuery } from "@tanstack/react-query";

const { data, isLoading, error } = useQuery({
  queryKey: ["meetings"],
  queryFn: () => MeetingsService.listMeetings(),
});
```

## UI コンポーネントの書き方

### 顧客画面（MUI + Tailwind）

```tsx
import { Button, Card, CardContent, Typography } from "@mui/material";

// MUI でコンポーネント、Tailwind でレイアウト・スペーシング
export function MeetingCard({ meeting }: MeetingCardProps) {
  return (
    <Card className="mb-4">
      <CardContent>
        <Typography variant="h6">{meeting.title}</Typography>
        <Button variant="contained" className="mt-2">
          詳細を見る
        </Button>
      </CardContent>
    </Card>
  );
}
```

### 管理画面（Chakra UI）

```tsx
import { Box, Heading, Button, Text } from "@chakra-ui/react";

// Chakra UI のプロパティでスタイリング（Tailwind は使わない）
export function MeetingCard({ meeting }: MeetingCardProps) {
  return (
    <Box borderWidth={1} borderRadius="md" p={4} mb={4}>
      <Heading size="md" mb={2}>{meeting.title}</Heading>
      <Button colorScheme="blue" size="sm" mt={2}>
        詳細を見る
      </Button>
    </Box>
  );
}
```

## ルーティングの違い

### 顧客画面（Next.js App Router）

ファイルを置くだけでルートになる：
```
app/(authorized)/meetings/page.tsx → /meetings
app/(authorized)/meetings/[id]/page.tsx → /meetings/123
```

### 管理画面（TanStack Router）

ファイルベースだが、ルート定義も必要：
```typescript
// src/routes/meetings/index.tsx
import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/meetings/")({
  component: MeetingsPage,
});

function MeetingsPage() {
  // ...
}
```

## ミューテーション（データの変更）

### 顧客画面（GraphQL Mutation）

```typescript
// 1. mutation を定義（src/lib/gql/mutations/meeting.graphql）
mutation CreateMeeting($input: MeetingCreateInput!) {
  createMeeting(input: $input) {
    id
    title
  }
}

// 2. 生成された hook を使う
import { useCreateMeetingMutation } from "@/lib/gql/generated/graphql";

const [createMeeting, { loading }] = useCreateMeetingMutation();
await createMeeting({ variables: { input: { title: "新しい会議" } } });
```

### 管理画面（REST API + TanStack Query useMutation）

```typescript
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { MeetingsService } from "@/client";

const queryClient = useQueryClient();

const { mutate, isPending } = useMutation({
  mutationFn: (data: MeetingCreate) => MeetingsService.createMeeting({ requestBody: data }),
  onSuccess: () => {
    // 一覧を再取得する
    queryClient.invalidateQueries({ queryKey: ["meetings"] });
  },
});
```
