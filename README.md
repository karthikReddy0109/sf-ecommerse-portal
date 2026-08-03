# SF-Commerce — E-Commerce Order Management Portal

![Salesforce](https://img.shields.io/badge/Salesforce-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)
![Apex](https://img.shields.io/badge/Apex-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)
![LWC](https://img.shields.io/badge/LWC-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)

A full-stack Salesforce application for managing e-commerce operations —
products, orders, customers, inventory, and support — built entirely on the
Salesforce platform using Apex, Lightning Web Components, Flows, and REST APIs.

---

## Table of Contents

- [Application Overview](#application-overview)
- [Data Model](#data-model)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Project Structure](#project-structure)
- [Apex Layer](#apex-layer)
- [LWC Components](#lwc-components)
- [Flows](#flows)
- [Integrations](#integrations)
- [Setup Instructions](#setup-instructions)
- [Sample Data](#sample-data)
- [Author](#author)

---

## Application Overview

SF-Commerce is an internal Salesforce application that replaces spreadsheet-based
e-commerce operations with a fully integrated platform. It enables:

- **Operations Team** — manage orders, track shipments, monitor inventory
- **Sales Team** — manage customers, loyalty tiers, discounts
- **Support Team** — handle cases and customer complaints
- **Management** — view revenue dashboards and KPIs in real time

### Key Business Problems Solved

- Manual order processing replaced by automated Queueable pipeline
- Stock management with automatic restock requests to suppliers
- Customer loyalty tier calculation running nightly via Batch Apex
- Real-time order status updates via Platform Events
- Bidirectional REST API integration with shipping and inventory systems

---

## Data Model

### Standard Objects

- Account → Customer companies
- Contact → Individual customers
- Case → Support tickets

### Custom Objects

| Object                | Purpose                                      |
| --------------------- | -------------------------------------------- |
| `Product__c`          | Product catalogue with stock management      |
| `Order__c`            | Customer orders with full lifecycle tracking |
| `Order_Line_Item__c`  | Individual products within an order          |
| `Shipment__c`         | Shipment records linked to orders            |
| `Customer_Loyalty__c` | Loyalty tier and points per customer         |
| `Refund__c`           | Refund requests with approval workflow       |
| `Sync_Error_Log__c`   | External system sync failure tracking        |
| `Error_Log__c`        | Internal Apex error logging                  |
| `Flow_Error_Log__c`   | Flow execution error tracking                |

### Relationships

- Account (1) ──── (1) Customer_Loyalty__c
- Account (1) ──── (M) Order__c
- Order__c (1) ──── (M) Order_Line_Item__c [Master-Detail]
- Order__c (1) ──── (M) Shipment__c
- Order__c (1) ──── (M) Refund__c
- Order_Line_Item__c (M) ──── (1) Product__c

### Custom Metadata Types

| Metadata Type              | Purpose                              |
| -------------------------- | ------------------------------------ |
| `Discount_Rule__mdt`       | Loyalty tier discount configuration  |
| `Loyalty_Tier_Config__mdt` | Tier thresholds and points per rupee |
| `Order_Config__mdt`        | Order processing configuration       |

---

## Tech Stack

| Layer            | Technology                                      |
| ---------------- | ----------------------------------------------- |
| Backend          | Apex, SOQL, Platform Events                     |
| Frontend         | Lightning Web Components, SLDS, Chart.js        |
| Automation       | Screen Flows, Record-Triggered Flows            |
| Integration      | REST API, Named Credentials, Queueable Callouts |
| Async Processing | Batch Apex, Queueable Apex, Schedulable Apex    |
| DevOps           | SFDX, GitHub, GitHub Actions                    |

---

## Features

### Order Management

- Create orders with multiple line items
- Automatic stock validation before order creation
- 4-step automated processing pipeline (Validate → Payment → Fulfil → Ship)
- Status transition validation — prevents invalid state changes
- Order cancellation with automatic refund creation
- Real-time status updates via Platform Events

### Product Catalogue

- Multi-filter product search (name, category, stock status)
- Dynamic SOQL with SOQL injection prevention
- Automatic low-stock detection and restock requests
- Batch payload restock with retry logic (3 attempts, chunked at 200)

### Customer Loyalty

- Automatic Bronze tier assignment on Account creation
- Points calculation based on tier and order amount
- Nightly batch tier recalculation based on lifetime spend
- Discount engine driven by Custom Metadata

### Inventory Management

- Automatic restock trigger when stock drops below threshold
- Outbound REST callout to supplier system (batch payload)
- Queueable chain with chunking (200 per chunk) and retry logic
- Sync error tracking with retry count

### Revenue Dashboard

- Live KPIs — today, month, quarter, year
- Revenue trend line chart (last 6 months)
- Orders by status donut chart
- Top 5 products bar chart
- Auto-refresh every 60 seconds

### Customer 360

- Single screen view — account info, loyalty tier, KPIs
- Lazy-loaded tabs — Recent Orders, Open Cases, Loyalty History
- Tier badge with color coding (Bronze/Silver/Gold/Platinum)

---

## Project Structure

---

## Apex Layer

### Service Classes

**`OrderService`**

- `createOrder(OrderCreateRequest)` — validates stock, creates Order + Line Items
- `updateOrderStatus(orderId, newStatus)` — validates transitions, updates status
- `cancelOrder(orderId)` — releases stock, creates refund if paid
- `getOrders(status, paymentStatus, fromDate, toDate)` — dynamic SOQL with filters
- `getOrderLineItems(orderId)` — lazy loads line items for a specific order
- `getValidNextStatuses(currentStatus)` — returns valid transitions for combobox
- `getOrderTimeline(orderId)` — returns order + field history for timeline component

**`ProductService`**

- `searchProducts(searchTerm, category, stockStatus)` — multi-filter dynamic SOQL
- `checkStockAvailability(productId, quantity)` — single product stock check
- `getProductById(productId)` — full product detail fetch

**`CustomerLoyaltyService`**

- `initializeLoyalty(accounts)` — creates Bronze loyalty on Account insert
- `applyLoyaltyDiscount(accountId, orderAmount)` — returns DiscountResult wrapper
- `addLoyaltyPoints(deliveredOrders, oldMap)` — adds points on Delivered status

### Async Classes

**Order Processing Pipeline (Queueable Chain)**

ValidateOrderQueueable
↓ (on success)
PaymentGatewayService
↓ (on success)
OrderFulfillmentQueueable
↓ (on success)
ShipmentServiceQueueable

**`ProductRestockQueueable`**

- Batch payload to supplier API
- Chunking at 200 records
- Retry logic up to 3 attempts
- Chains remaining chunks after each chunk completes

**`LoyaltyTierUpdateBatch`**

- Runs nightly via `LoyaltyTierUpdateScheduler`
- Recalculates tier for all accounts
- Updates Discount_Percent__c
- Sends summary email in finish()

**`OverdueOrderBatch`**

- Runs every morning
- Flags orders overdue by configurable days
- Creates tasks and sends email alerts

### REST APIs

**`ShippingCallbackService`** (`/RestockCallback/*`)

- Inbound PATCH from shipping carrier
- Updates Shipment__c status and tracking

**`OrderStatusAPI`** (`/OrderStatus/*`)

- Inbound GET for external systems
- Returns order status by order number

---

## LWC Components

| Component             | Location                  | Purpose                                   |
| --------------------- | ------------------------- | ----------------------------------------- |
| `productCatalogue`    | App Page                  | Product browsing with search and filters  |
| `productCard`         | Child of productCatalogue | Individual product display card           |
| `orderManagement`     | App Page                  | Full order management with inline expand  |
| `orderLineItemEditor` | Child of orderManagement  | Line items table for expanded order       |
| `orderTimeline`       | Order Record Page         | Visual order journey with Platform Events |
| `customer360View`     | Account Record Page       | Full customer profile with lazy tabs      |
| `revenueDashboard`    | Home Page                 | Live KPI dashboard with Chart.js charts   |

---

## Flows

### New Customer Onboarding (Screen Flow)

- 4-step wizard: Company Details → Contact + Duplicate Check → Review → Success
- Duplicate detection via custom LWC component
- Creates Account + Contact automatically
- Account trigger creates Customer_Loyalty__c (Bronze)
- Sends welcome email via @InvocableMethod
- Creates follow-up Task for sales rep

### Order Cancellation (Record-Triggered Flow)

- Fires when Order Status changes to Cancelled
- Creates Refund__c if Payment Status was Paid
- Sends cancellation email to Contact
- Creates Task for operations team review

### Refund Auto Submit (Record-Triggered Flow)

- Fires when Refund__c is created with Status = Pending
- Automatically submits for approval via @InvocableMethod
- Routes to manager based on amount threshold

---

## Integrations

### Outbound — Supplier Restock API

- Triggered when Product stock drops below threshold
- Batch payload with all low-stock products
- Chunked at 200 records per API call
- Retry logic up to 3 attempts per chunk
- Uses Named Credential for endpoint

### Outbound — Payment Gateway

- Called during Order Processing Step 2
- Batch payload for all orders in pipeline
- Mock endpoint via webhook.site for testing

### Outbound — Shipping API

- Called during Order Processing Step 4
- Returns tracking numbers per order
- Creates Shipment__c records on success

### Inbound — Shipping Callback

- External carrier calls back with delivery updates
- PATCH endpoint updates Shipment__c status
- Returns 200/404/500 with JSON response

### Inbound — Order Status Query

- External systems query order status by order number
- GET endpoint returns structured JSON
- Validates request via Custom Setting token

---

## Setup Instructions

### Prerequisites

- Salesforce Developer Org or Sandbox
- Salesforce CLI installed
- Git installed
- VS Code with Salesforce Extension Pack

### Step 1 — Clone the Repository

```bash
git clone https://github.com/karthikReddy0109/sf-ecommerse-portal.git
cd sf-ecommerse-portal
```

### Step 2 — Authenticate to Salesforce

```bash
sf org login web --alias sf-commerce-org
```

### Step 3 — Deploy to Org

```bash
sf project deploy start --target-org sf-commerce-org
```

### Step 4 — Setup Custom Metadata Records

Navigate to Setup → Custom Metadata Types and add records for:

**Discount_Rule__mdt:**

| Label             | Tier     | Discount % | Min Order Amount |
| ----------------- | -------- | ---------- | ---------------- |
| Bronze Discount   | Bronze   | 5          | 1000             |
| Silver Discount   | Silver   | 10         | 1000             |
| Gold Discount     | Gold     | 15         | 1000             |
| Platinum Discount | Platinum | 20         | 1000             |

**Loyalty_Tier_Config__mdt:**

| Label           | Tier     | Min Spend | Points Per Rupee |
| --------------- | -------- | --------- | ---------------- |
| Bronze Config   | Bronze   | 0         | 1                |
| Silver Config   | Silver   | 10000     | 2                |
| Gold Config     | Gold     | 50000     | 3                |
| Platinum Config | Platinum | 100000    | 5                |

**Order_Config__mdt:**

| Label          | Refund Threshold | Max Discount % | Overdue Days |
| -------------- | ---------------- | -------------- | ------------ |
| Default Config | 5000             | 30             | 3            |

### Step 5 — Enable Field History Tracking

Setup → Object Manager → Order__c → Fields → Set History Tracking → check Status__c

### Step 6 — Schedule Batch Jobs

Run in Anonymous Apex:

```apex
// Nightly loyalty tier update at midnight
System.schedule(
    'Nightly Loyalty Tier Update',
    '0 0 0 * * ?',
    new LoyaltyTierUpdateScheduler()
);

// Morning overdue order check at 6 AM
System.schedule(
    'Morning Overdue Order Check',
    '0 0 6 * * ?',
    new OverdueOrderBatch()
);
```

### Step 7 — Upload Chart.js Static Resource

Setup → Static Resources → New

- Name: chartjs
- File: chartjs.min.js (download from cdn.jsdelivr.net/npm/chart.js)
- Cache Control: Public

### Step 8 — Configure Remote Site Settings

Setup → Remote Site Settings → New

- Name: Webhook_Site
- URL: https://webhook.site
- Active: checked

### Step 9 — Add Components to App Pages

Setup → App Builder:

- SF-Commerce Home Page → add revenueDashboard
- SF-Commerce App Page → add productCatalogue and orderManagement
- Account Record Page → add customer360View
- Order Record Page → add orderTimeline

---

## Sample Data

Run the following in Developer Console → Execute Anonymous to create sample data:

```apex
// Create sample Accounts
List<Account> accounts = new List<Account>{
    new Account(Name='TechCorp Solutions', Industry='Technology', Phone='9876543201'),
    new Account(Name='Retail Masters', Industry='Retail', Phone='9876543202'),
    new Account(Name='Global Imports', Industry='Manufacturing', Phone='9876543203')
};
insert accounts;

// Create sample Products
List<Product__c> products = new List<Product__c>{
    new Product__c(Name='Wireless Headphones', Product_Code__c='PROD-001',
        Category__c='Electronics', Unit_Price__c=2999, Cost_Price__c=1800,
        Stock_Quantity__c=150, Restock_Threshold__c=20, Is_Active__c=true),
    new Product__c(Name='USB-C Hub', Product_Code__c='PROD-002',
        Category__c='Electronics', Unit_Price__c=1499, Cost_Price__c=900,
        Stock_Quantity__c=8, Restock_Threshold__c=15, Is_Active__c=true),
    new Product__c(Name='Mechanical Keyboard', Product_Code__c='PROD-003',
        Category__c='Electronics', Unit_Price__c=4499, Cost_Price__c=2800,
        Stock_Quantity__c=0, Restock_Threshold__c=10, Is_Active__c=true)
};
insert products;
```

---

## Author

**Karthik Reddy**
Salesforce Developer | Deloitte | Bengaluru

- Salesforce Certified: Agentforce Specialist, Platform Administrator, AI Associate
- GitHub: [karthikReddy0109](https://github.com/karthikReddy0109)
