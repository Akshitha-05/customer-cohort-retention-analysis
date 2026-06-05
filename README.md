
# 🛒 Customer Cohort & Retention Analysis

> A PostgreSQL cohort analysis project that tracks customer retention over time using the E-Commerce dataset.

---

## 📌 Problem Statement

> _"Which acquisition cohorts retain customers best, and at what month do most customers churn?"_

---

## 📁 Project Structure

```
customer-cohort-retention/
│
├── 📄 Customer_Cohort_And_Retention_Analysis.sql   # All SQL queries (Steps 1–6)
├── 📄 README.md                                     # Project documentation
├── 📄 Project_Documentation.docx                   # Detailed Word documentation
│
└── 📂 data/
    └── E-Commerce Data                           # Source dataset (download from Kaggle)
```

---

## 🗃️ Dataset

| Property | Details |
|---|---|
| **Name** | E-Commerce Dataset |
| **Source** | [Kaggle — carrie1/ecommerce-data](https://www.kaggle.com/datasets/carrie1/ecommerce-data) |
| **Rows** | ~541,909 transactions |
| **Period** | December 2010 – December 2011 |
| **Countries** | 38 countries (primarily UK-based) |
| **Encoding** | LATIN1 (contains £ pound sign) |

### Columns

| Column | Type | Description |
|---|---|---|
| `invoice_no` | VARCHAR(20) | Invoice number — starts with `C` for cancellations |
| `stock_code` | VARCHAR(20) | Product/item code |
| `description` | TEXT | Product name |
| `quantity` | INT | Units purchased — negative for returns |
| `invoice_date` | TIMESTAMP | Date and time of purchase |
| `unit_price` | NUMERIC(10,2) | Price per unit in GBP (£) |
| `customer_id` | VARCHAR(20) | Unique customer ID — nullable |
| `country` | VARCHAR(50) | Country of the customer |

---

## 🛠️ Tools & Technologies

| Tool | Purpose |
|---|---|
| **PostgreSQL 18** | Primary database engine |
| **pgAdmin 4** | GUI for query execution and CSV import |
| **SQL** | All analysis — no Python or external tools used |

---

## ⚙️ Setup Instructions

### 1. Create the database

```sql
CREATE DATABASE retail_db_new;
```

Or in pgAdmin: right-click **Databases → Create → Database** → name it `retail_db_new`

---

### 2. Fix the date format

The CSV uses `MM/DD/YYYY` format. Run this before importing, then **disconnect and reconnect** pgAdmin:

```sql
ALTER DATABASE retail_db_new SET datestyle = 'ISO, MDY';
```

---

### 3. Create the table

```sql
CREATE TABLE online_retail (
    invoice_no    VARCHAR(20),
    stock_code    VARCHAR(20),
    description   TEXT,
    quantity      INT,
    invoice_date  TIMESTAMP,
    unit_price    NUMERIC(10,2),
    customer_id   VARCHAR(20),
    country       VARCHAR(50)
);
```

---

### 4. Import the CSV via pgAdmin

Right-click `online_retail` table → **Import/Export Data** → set:

- **Format** → `csv`
- **Header** → `ON`
- **Encoding** → `LATIN1` ⚠️ *(not UTF8 — CSV has £ symbol)*
- **Delimiter** → `,`

---

### 5. Verify the import

```sql
SELECT COUNT(*) FROM online_retail;
-- Expected: 541909
```

---

## 🧠 SQL Concepts Used

| Concept | How It Is Used |
|---|---|
| `DATE_TRUNC('month', ...)` | Groups invoice dates into monthly buckets |
| `MIN() GROUP BY` | Finds each customer's first purchase (acquisition month) |
| `WITH (CTE)` | Breaks multi-step logic into readable named queries |
| `Self JOIN` | Joins each customer back to all their transactions |
| `CASE WHEN` pivoting | Turns long-format rows into a wide retention matrix |
| `DATE_PART` arithmetic | Calculates exact months between two timestamps |
| `ROUND(100.0 * ...)` | Computes retention % without integer division errors |

---

## 📊 Query Breakdown

### Step 1 — Data Exploration
Understand the raw data before any analysis:
- Total rows, unique customers, date range, country count
- Check how many rows have `NULL` customer_id (~24% excluded)
- Check for cancelled orders (`invoice_no LIKE 'C%'`)
- Top 10 countries by revenue

### Step 2 — Cohort Foundation
Find each customer's **first purchase month** — this is their cohort:
```sql
SELECT
    customer_id,
    DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
FROM online_retail
WHERE customer_id IS NOT NULL
  AND invoice_no NOT LIKE 'C%'
  AND quantity > 0
GROUP BY customer_id;
```

### Step 3 — Cohort Index
Calculate `cohort_index` = months since first purchase:
- `cohort_index = 0` → acquisition month
- `cohort_index = 1` → came back 1 month later
- `cohort_index = 6` → came back 6 months later

### Step 4 — Retention Counts
Raw count of active customers per cohort per month before converting to percentages.

### Step 5 — Retention Matrix ⭐
The **main deliverable** — a pivoted table showing retention % from Month 0 to Month 12:

| cohort_month | cohort_size | month_0 | month_1 | month_2 | month_3 | month_6 |
|---|---|---|---|---|---|---|
| 2010-12-01 | 948 | 100.0% | 36.1% | 35.0% | 38.7% | 45.3% |
| 2011-01-01 | 421 | 100.0% | 25.2% | 25.4% | 28.3% | 32.1% |
| 2011-02-01 | 380 | 100.0% | 24.7% | 26.1% | 27.4% | 30.8% |
| 2011-03-01 | 452 | 100.0% | 22.6% | 24.3% | 26.5% | 29.4% |

### Step 6 — Answer the Project Questions
- **Query 1** → Ranks cohorts by 1-month, 3-month, 6-month retention
- **Query 2** → Average retention at each month index to find peak churn point

---

## 🔍 Key Insights

**1. Peak churn is at Month 1**
The biggest customer drop-off happens between Month 0 and Month 1. On average, only 20–36% of customers return after their first purchase — meaning 64–80% churn immediately.

**2. Early cohorts retain best**
The December 2010 and January 2011 cohorts show the highest long-term retention. These were the store's earliest loyal customers and consistently outperform later cohorts at every interval.

**3. Survivors are loyal**
Customers who return past Month 1 show significantly more stable retention in subsequent months. The hardest battle is converting a first-time buyer into a repeat buyer.

---

## 🧹 Data Cleaning Decisions

| Issue | Fix Applied |
|---|---|
| ~135K rows with `NULL` customer_id | Excluded — cannot track cohort without an ID |
| Cancelled orders (`invoice_no LIKE 'C%'`) | Excluded from all cohort queries |
| Negative quantities (returns) | Excluded with `WHERE quantity > 0` |
| Date format `MM/DD/YYYY` in CSV | Fixed with `ALTER DATABASE ... SET datestyle` |
| `£` symbol causing UTF8 import error | Changed import encoding to `LATIN1` |

---

## ⚠️ Common Errors & Fixes

| Error | Fix |
|---|---|
| `date/time field value out of range` | Run `ALTER DATABASE retail_db_new SET datestyle = 'ISO, MDY';` then reconnect |
| `invalid byte sequence for encoding "UTF8": 0xa3` | Change CSV import encoding from UTF8 to **LATIN1** |
| Retention % showing `0` instead of decimals | Use `100.0 *` not `100 *` to avoid integer division |
| `NULL` values in retention columns | Expected — means 0% retention for that cohort/month |

---

## 📂 How to Run

1. Open `Customer_Cohort_And_Retention_Analysis.sql` in pgAdmin Query Tool
2. Run each step in order — **Steps 1 through 6**
3. Each step is clearly labelled with `---Step X---` comments
4. Step 6 contains the final answers to the project questions

---

## 👤 Author

Munnanuri Akshitha
- 🗄️ Database: `retail_db_new` on PostgreSQL 18
- 🛠️ Tool: pgAdmin 4

