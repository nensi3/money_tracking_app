# Money Tracking App - Database Tables

This is a single-file database design for the whole project.

Your app currently uses Firebase Auth and Cloud Firestore, so the tables below are logical tables mapped to Firestore collections and subcollections.

## Database Approach

- Auth: Firebase Authentication
- App data: Cloud Firestore
- Best structure: user-scoped collections for privacy and simpler security rules

Recommended root structure:

- users/{uid}
- users/{uid}/transactions/{transactionId}
- users/{uid}/categories/{categoryId}
- users/{uid}/budgets/{budgetId}
- users/{uid}/budgetCategoryLimits/{limitId}
- users/{uid}/notifications/{notificationId}
- users/{uid}/reportExports/{exportId}
- users/{uid}/emailSummaries/{summaryId}
- systemCategories/{categoryId}
- systemSettings/{settingId}
- reviewQueue/{itemId}
- adminActions/{actionId}
- analyticsDaily/{dateKey}

## 1. users

Firestore path: users/{uid}

| Field         | Type      | Required | Key / Constraint            | Purpose                  |
| ------------- | --------- | -------- | --------------------------- | ------------------------ |
| uid           | string    | Yes      | Primary key, same as doc id | Firebase Auth user id    |
| email         | string    | Yes      | Unique logically            | Login identity           |
| displayName   | string    | No       |                             | User name                |
| photoUrl      | string    | No       |                             | Profile image            |
| provider      | string    | Yes      | email, google               | Auth provider            |
| role          | string    | Yes      | user, admin                 | Access control           |
| isActive      | bool      | Yes      | default true                | Account status           |
| emailVerified | bool      | No       | default false               | Email verification state |
| currencyCode  | string    | Yes      | default INR                 | Currency display         |
| timezone      | string    | Yes      | default Asia/Kolkata        | Local reporting          |
| createdAt     | timestamp | Yes      | server timestamp            | Record creation          |
| updatedAt     | timestamp | Yes      | server timestamp            | Last update              |
| lastLoginAt   | timestamp | No       |                             | Last active session      |

Used by:

- Login/signup flow
- Profile tab
- Admin user management

## 2. transactions

Firestore path: users/{uid}/transactions/{transactionId}

| Field                | Type      | Required | Key / Constraint                  | Purpose                         |
| -------------------- | --------- | -------- | --------------------------------- | ------------------------------- |
| transactionId        | string    | Yes      | Primary key, doc id               | Transaction id                  |
| uid                  | string    | Yes      | Foreign key -> users.uid          | Owner user                      |
| amount               | number    | Yes      | > 0                               | Transaction amount              |
| type                 | string    | Yes      | income, expense                   | Transaction type                |
| categoryId           | string    | No       | FK -> categories/systemCategories | Stable category link            |
| categoryName         | string    | Yes      |                                   | Current/simple UI category name |
| categoryNameSnapshot | string    | No       |                                   | Historical category label       |
| note                 | string    | No       |                                   | User note                       |
| date                 | timestamp | Yes      | indexed                           | Transaction date                |
| monthKey             | string    | Yes      | YYYY-MM                           | Monthly reports                 |
| createdAt            | timestamp | Yes      | server timestamp                  | Creation time                   |
| updatedAt            | timestamp | Yes      | server timestamp                  | Last edit                       |
| createdBy            | string    | No       | FK -> users.uid                   | Usually same as owner           |
| approvalStatus       | string    | No       | pending, approved, rejected       | Admin approval flow             |
| isDeleted            | bool      | Yes      | default false                     | Soft delete support             |

Used by:

- Home page transaction list
- Stats tab
- Budget checks
- Admin approve transactions page
- Analytics page

## 3. categories

Firestore path: users/{uid}/categories/{categoryId}

| Field          | Type      | Required | Key / Constraint      | Purpose                    |
| -------------- | --------- | -------- | --------------------- | -------------------------- |
| categoryId     | string    | Yes      | Primary key, doc id   | Category id                |
| uid            | string    | Yes      | FK -> users.uid       | Owner user                 |
| name           | string    | Yes      |                       | Category name              |
| normalizedName | string    | Yes      | lowercase             | Search and duplicate check |
| type           | string    | Yes      | income, expense, both | Usage scope                |
| colorHex       | string    | No       |                       | UI color                   |
| iconKey        | string    | No       |                       | UI icon reference          |
| isActive       | bool      | Yes      | default true          | Hide/show category         |
| source         | string    | Yes      | custom                | Origin                     |
| createdAt      | timestamp | Yes      | server timestamp      | Creation time              |
| updatedAt      | timestamp | Yes      | server timestamp      | Last edit                  |

Used by:

- Add transaction screen
- Admin category management

## 4. systemCategories

Firestore path: systemCategories/{categoryId}

| Field          | Type      | Required | Key / Constraint      | Purpose                    |
| -------------- | --------- | -------- | --------------------- | -------------------------- |
| categoryId     | string    | Yes      | Primary key, doc id   | Global category id         |
| name           | string    | Yes      |                       | Default category name      |
| normalizedName | string    | Yes      | lowercase             | Search and duplicate check |
| type           | string    | Yes      | income, expense, both | Usage scope                |
| colorHex       | string    | No       |                       | UI color                   |
| iconKey        | string    | No       |                       | UI icon reference          |
| isActive       | bool      | Yes      | default true          | Visible to users           |
| sortOrder      | number    | No       |                       | UI ordering                |
| createdAt      | timestamp | Yes      | server timestamp      | Creation time              |
| updatedAt      | timestamp | Yes      | server timestamp      | Last edit                  |

Used by:

- Default app setup
- Shared categories across all users

## 5. budgets

Firestore path: users/{uid}/budgets/{budgetId}

Recommended budget id:

- monthly_YYYY-MM

| Field                 | Type      | Required | Key / Constraint      | Purpose         |
| --------------------- | --------- | -------- | --------------------- | --------------- |
| budgetId              | string    | Yes      | Primary key, doc id   | Budget row id   |
| uid                   | string    | Yes      | FK -> users.uid       | Owner user      |
| periodType            | string    | Yes      | monthly               | Budget period   |
| monthKey              | string    | Yes      | YYYY-MM               | Reporting month |
| monthlyLimit          | number    | Yes      | >= 0                  | Total budget    |
| warnPercent           | number    | Yes      | 1 to 100              | Alert threshold |
| spentAmountCached     | number    | No       | >= 0                  | Fast UI reads   |
| remainingAmountCached | number    | No       | >= 0                  | Fast UI reads   |
| status                | string    | No       | ok, warning, exceeded | Budget state    |
| createdAt             | timestamp | Yes      | server timestamp      | Creation time   |
| updatedAt             | timestamp | Yes      | server timestamp      | Last edit       |

Used by:

- Set budget page
- Budget report summary
- Notification trigger logic

## 6. budgetCategoryLimits

Firestore path: users/{uid}/budgetCategoryLimits/{limitId}

| Field                | Type      | Required | Key / Constraint                  | Purpose               |
| -------------------- | --------- | -------- | --------------------------------- | --------------------- |
| limitId              | string    | Yes      | Primary key, doc id               | Row id                |
| uid                  | string    | Yes      | FK -> users.uid                   | Owner user            |
| monthKey             | string    | Yes      | YYYY-MM                           | Reporting month       |
| categoryId           | string    | Yes      | FK -> categories/systemCategories | Target category       |
| categoryNameSnapshot | string    | Yes      |                                   | Stored name           |
| limitAmount          | number    | Yes      | >= 0                              | Budgeted amount       |
| spentAmountCached    | number    | No       | >= 0                              | Fast progress display |
| status               | string    | No       | ok, warning, exceeded             | Category budget state |
| updatedAt            | timestamp | Yes      | server timestamp                  | Last update           |

Used by:

- Budget by category section
- Budget vs spent charts

## 7. notifications

Firestore path: users/{uid}/notifications/{notificationId}

| Field            | Type      | Required | Key / Constraint                      | Purpose             |
| ---------------- | --------- | -------- | ------------------------------------- | ------------------- |
| notificationId   | string    | Yes      | Primary key, doc id                   | Notification id     |
| uid              | string    | Yes      | FK -> users.uid                       | Owner user          |
| type             | string    | Yes      | budget_warning, budget_exceeded, info | Notification type   |
| title            | string    | Yes      |                                       | Alert title         |
| body             | string    | Yes      |                                       | Alert content       |
| monthKey         | string    | No       | YYYY-MM                               | Related month       |
| deliveredLocally | bool      | Yes      | default false                         | Local device status |
| isRead           | bool      | Yes      | default false                         | In-app state        |
| createdAt        | timestamp | Yes      | server timestamp                      | Notification time   |

Used by:

- Local notifications history
- Future notification center

## 8. reportExports

Firestore path: users/{uid}/reportExports/{exportId}

| Field       | Type      | Required | Key / Constraint      | Purpose       |
| ----------- | --------- | -------- | --------------------- | ------------- |
| exportId    | string    | Yes      | Primary key, doc id   | Export job id |
| uid         | string    | Yes      | FK -> users.uid       | Owner user    |
| monthKey    | string    | Yes      | YYYY-MM               | Report month  |
| format      | string    | Yes      | pdf, csv              | Export format |
| status      | string    | Yes      | queued, ready, failed | Job state     |
| fileUrl     | string    | No       |                       | Download path |
| requestedAt | timestamp | Yes      | server timestamp      | Start time    |
| completedAt | timestamp | No       |                       | End time      |

Used by:

- Export report page

## 9. emailSummaries

Firestore path: users/{uid}/emailSummaries/{summaryId}

| Field          | Type      | Required | Key / Constraint     | Purpose        |
| -------------- | --------- | -------- | -------------------- | -------------- |
| summaryId      | string    | Yes      | Primary key, doc id  | Email job id   |
| uid            | string    | Yes      | FK -> users.uid      | Owner user     |
| monthKey       | string    | Yes      | YYYY-MM              | Summary month  |
| recipientEmail | string    | Yes      |                      | Target email   |
| subject        | string    | No       |                      | Email subject  |
| status         | string    | Yes      | queued, sent, failed | Delivery state |
| sentAt         | timestamp | No       |                      | Sent time      |
| createdAt      | timestamp | Yes      | server timestamp     | Request time   |

Used by:

- Email summary page

## 10. systemSettings

Firestore path: systemSettings/{settingId}

Recommended documents:

- systemSettings/app
- systemSettings/finance
- systemSettings/notifications

| Field                | Type      | Required | Key / Constraint            | Purpose                    |
| -------------------- | --------- | -------- | --------------------------- | -------------------------- |
| settingId            | string    | Yes      | Primary key, doc id         | Settings section id        |
| allowSignup          | bool      | No       |                             | Toggle registration        |
| defaultCurrencyCode  | string    | No       |                             | App-wide currency          |
| defaultWarnPercent   | number    | No       | 1 to 100                    | Default budget warning     |
| maintenanceMode      | bool      | No       |                             | Block access if needed     |
| notificationsEnabled | bool      | No       |                             | Global notification switch |
| updatedAt            | timestamp | Yes      | server timestamp            | Last update                |
| updatedBy            | string    | No       | FK -> users.uid(role=admin) | Admin who changed it       |

Used by:

- System settings page
- App configuration defaults

## 11. reviewQueue

Firestore path: reviewQueue/{itemId}

| Field         | Type      | Required | Key / Constraint            | Purpose                     |
| ------------- | --------- | -------- | --------------------------- | --------------------------- |
| itemId        | string    | Yes      | Primary key, doc id         | Queue row id                |
| queueType     | string    | Yes      | transaction, user           | Reviewed object type        |
| targetUid     | string    | Yes      | FK -> users.uid             | Related user                |
| targetDocPath | string    | Yes      |                             | Firestore path under review |
| status        | string    | Yes      | pending, approved, rejected | Review state                |
| reason        | string    | No       |                             | Review note                 |
| createdAt     | timestamp | Yes      | server timestamp            | Queue time                  |
| resolvedAt    | timestamp | No       |                             | Resolution time             |
| resolvedBy    | string    | No       | FK -> users.uid(role=admin) | Resolver                    |

Used by:

- Approve transactions page
- Future account moderation

## 12. adminActions

Firestore path: adminActions/{actionId}

| Field      | Type      | Required | Key / Constraint            | Purpose                |
| ---------- | --------- | -------- | --------------------------- | ---------------------- |
| actionId   | string    | Yes      | Primary key, doc id         | Audit id               |
| adminUid   | string    | Yes      | FK -> users.uid(role=admin) | Admin user             |
| actionType | string    | Yes      |                             | Action name            |
| targetPath | string    | Yes      |                             | Changed Firestore path |
| metadata   | map       | No       |                             | Extra detail           |
| reason     | string    | No       |                             | Admin note             |
| createdAt  | timestamp | Yes      | server timestamp            | Audit time             |

Used by:

- Admin audit trail

## 13. analyticsDaily

Firestore path: analyticsDaily/{dateKey}

Document id format:

- YYYYMMDD

| Field             | Type      | Required | Key / Constraint    | Purpose                  |
| ----------------- | --------- | -------- | ------------------- | ------------------------ |
| dateKey           | string    | Yes      | Primary key, doc id | Analytics day            |
| totalUsers        | number    | Yes      | >= 0                | Total registered users   |
| activeUsers       | number    | Yes      | >= 0                | Daily active users       |
| totalTransactions | number    | Yes      | >= 0                | Total daily transactions |
| totalIncome       | number    | Yes      | >= 0                | Daily income total       |
| totalExpense      | number    | Yes      | >= 0                | Daily expense total      |
| newUsers          | number    | No       | >= 0                | New users that day       |
| updatedAt         | timestamp | Yes      | server timestamp    | Last refresh             |

Used by:

- View analytics page
- Admin dashboard cards

## Relationships

| Parent Table                | Child Table          | Relationship | Key        |
| --------------------------- | -------------------- | ------------ | ---------- |
| users                       | transactions         | 1 to many    | uid        |
| users                       | categories           | 1 to many    | uid        |
| users                       | budgets              | 1 to many    | uid        |
| users                       | budgetCategoryLimits | 1 to many    | uid        |
| users                       | notifications        | 1 to many    | uid        |
| users                       | reportExports        | 1 to many    | uid        |
| users                       | emailSummaries       | 1 to many    | uid        |
| categories/systemCategories | transactions         | 1 to many    | categoryId |
| users(role=admin)           | adminActions         | 1 to many    | adminUid   |
| users(role=admin)           | reviewQueue          | 1 to many    | resolvedBy |

## Required Firestore Indexes

| Collection     | Index Fields                                |
| -------------- | ------------------------------------------- |
| transactions   | type ASC, monthKey ASC, date DESC           |
| transactions   | monthKey ASC, categoryId ASC, date DESC     |
| transactions   | monthKey ASC, approvalStatus ASC, date DESC |
| categories     | isActive ASC, type ASC, name ASC            |
| reviewQueue    | status ASC, createdAt ASC                   |
| analyticsDaily | dateKey DESC                                |
| notifications  | isRead ASC, createdAt DESC                  |

## Mapping From Your Current Code

Current code uses:

- transactions
- categories
- settings/budget

Recommended mapping:

| Current Collection | Better Project-Wide Table                  |
| ------------------ | ------------------------------------------ |
| transactions       | users/{uid}/transactions                   |
| categories         | users/{uid}/categories or systemCategories |
| settings/budget    | users/{uid}/budgets/monthly_YYYY-MM        |

## Minimal Tables Needed Right Now

If you only want to implement what your current code already needs, start with these first:

1. users
2. transactions
3. categories
4. budgets
5. notifications

Then add later:

1. budgetCategoryLimits
2. reportExports
3. emailSummaries
4. reviewQueue
5. adminActions
6. analyticsDaily
7. systemSettings

## Best Practice Notes

- Keep user financial data inside users/{uid}/... paths.
- Store monthKey in every transaction for fast monthly reports.
- Store categoryNameSnapshot in transactions so old entries remain readable after category rename.
- Use role in users table for admin access.
- Use server timestamps for createdAt and updatedAt.
- Add approvalStatus only if you actually want admin approval flow.

