# 🏠 LeanHouse - Modern Rental Property Management Platform

> **Nền tảng Quản trị Nhà trọ & Ký túc xá Thông minh**
> Built with **Ruby on Rails 8.1**, **Hotwire**, **PostgreSQL**, and integrated with **VietQR & payOS**.

---

## 📖 Overview

**LeanHouse** is a full-featured, multi-tenant property management platform designed to automate and simplify rental operations for landlords and provide a seamless, transparent living experience for tenants.

By combining real-time communication (Hotwire Turbo & ActionCable), utility tracking, flexible billing cycles, and automated banking reconciliation (VietQR & payOS), LeanHouse transforms manual, error-prone boarding house operations into an automated, paperless workflow.

---

## ✨ Key Features

### 🏢 1. Landlord Portal (`/landlord`)
* **Property & Unit Management:**
  * Multi-house management with independent configurations.
  * Hierarchical layout: **Houses ➔ Floors ➔ Rooms ➔ Beds** (supports both private room rentals and dormitory/shared bed models).
  * Room status tracking (Available, Occupied, Under Maintenance).
* **Tenancy & Contracts:**
  * Full digital tenancy lifecycle: drafting, signing, room transfers, extensions, renewals, and contract termination with deposit reconciliation.
  * Contract archiving and historical lookup.
* **Services & Meter Tracking:**
  * Customizable services (fixed fee per room, fee per head, or metered consumption like electricity & water).
  * Meter reading recording with photo proof uploads.
  * Review and approve tenant self-reported utility readings.
* **Smart Invoicing & Billing:**
  * Automated monthly invoice batch generation based on contract terms, room rent, and actual utility consumption.
  * One-off custom invoices with custom line items.
  * Instant invoice issue, preview, PDF export, and browser printing.
* **FinTech & Payments:**
  * **VietQR Generation:** Automatically generates standardized VietQR codes with exact payment amount and invoice reference.
  * **payOS Real-Time Auto-Reconciliation:** Connect bank accounts (MB Bank, ACB, BIDV, OCB, KienlongBank, etc.) via payOS Open API. Invoices automatically update to **Paid** within 1–3 seconds upon receiving webhooks.
  * Manual payment confirmation (Cash / Direct Transfer) and payment rollback (Undo Paid) with reason audit logging.
* **Tenant Requests & Maintenance:**
  * Manage maintenance/repair requests, vehicle registration, and move-out notices.
  * Asset and equipment tracking with maintenance logs.
* **Financial Analytics & Dashboard:**
  * Real-time revenue overview, month-over-month revenue comparison, collection progress, and occupancy rates.

---

### 📱 2. Tenant Portal (`/tenant`)
* **Tenant Dashboard:**
  * Instant view of active contract, room information, and pending payments.
* **Invoices & Payment:**
  * View detailed invoice breakdowns (rent, electricity, water, internet, cleaning, etc.).
  * Scan static VietQR code with any mobile banking app.
  * Open payOS checkout portal for instant dynamic QR payment and immediate automated status confirmation.
  * Attach payment proof screenshots for manual verification when needed.
* **Utility Meter Self-Reporting:**
  * Submit monthly electricity and water meter readings along with image attachments directly to the landlord.
* **Service Requests:**
  * Submit repair tickets with descriptions and photo evidence.
  * Submit vehicle parking registration and contract termination notices.
* **Profile & Security:**
  * Manage personal profile, upload avatar, and securely change registered phone numbers via OTP.

---

### 🛡️ 3. Admin Portal (`/admin`)
* **Platform Operations:**
  * Manage landlords, tenants, and administrator accounts.
  * Account activation/deactivation and phone number recycling.
* **Global Monitoring:**
  * Inspect houses, active contracts, and invoices system-wide.
  * Track and resolve platform issue reports submitted by users.
  * Send broadcast announcements and platform notifications.

---

## 🛠️ Tech Stack & Architecture

| Layer | Technology |
| :--- | :--- |
| **Backend Framework** | [Ruby on Rails 8.1.0](https://rubyonrails.org/) |
| **Ruby Version** | [Ruby 3.4.4](https://www.ruby-lang.org/) |
| **Database** | [PostgreSQL](https://www.postgresql.org/) (via `pg` gem) |
| **Frontend / Reactive UI** | [Hotwire](https://hotwired.dev/) (Turbo Rails 8 + Stimulus JS) |
| **CSS & Assets** | [Bootstrap 5](https://getbootstrap.com/), Sass, [Propshaft](https://github.com/rails/propshaft) Asset Pipeline, Material Symbols |
| **Caching & Jobs** | `solid_cache`, `solid_queue`, `solid_cable` |
| **Authorization** | [CanCanCan](https://github.com/CanCanCommunity/cancancan) |
| **Notifications** | [Noticed v3](https://github.com/excid3/noticed) with Turbo Streams |
| **Payment Integrations** | [VietQR API](https://vietqr.io/), [payOS Open API](https://payos.vn/) |
| **File Storage** | Rails Active Storage with `mini_magick` |
| **Localization (I18n)** | Full bilingual support: Vietnamese (`:vi` - Default) & English (`:en`) |

---

## 🚀 Getting Started

### Prerequisites
Make sure you have the following installed on your machine:
* **Ruby**: `3.4.4` (managed via `rbenv`, `rvm`, or `asdf`)
* **PostgreSQL**: `14+`
* **Node.js**: `18+` & **Yarn** / **npm**
* **ImageMagick** or **libvips** (for image variant processing)

---

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/DaoThiHaAn/LeanHouse.git
   cd LeanHouse
   ```

2. **Install Ruby and JavaScript dependencies:**
   ```bash
   bundle install
   yarn install
   ```

3. **Configure the Database:**
   Ensure PostgreSQL is running locally. Update your credentials in `config/database.yml` if necessary.

4. **Prepare Database and Run Seeds:**
   ```bash
   bin/rails db:prepare
   bin/rails db:seed
   ```

5. **Synchronize Vietnamese Banks (VietQR):**
   Fetch and cache the up-to-date list of all Vietnamese banks and BIN codes from VietQR:
   ```bash
   bin/rails vietqr:sync_banks
   ```

6. **Start the Development Server:**
   ```bash
   bin/dev
   ```
   Or run Puma directly:
   ```bash
   bin/rails server
   ```
   Access the application in your browser at `http://localhost:3000`.

---

## 🔑 Default Seed Accounts

After running `bin/rails db:seed`, you can log in with the default admin accounts at `http://localhost:3000/admin/login`:

| Role | Email | Password |
| :--- | :--- | :--- |
| **Super Admin** | `admin@leanhouse.vn` | `Password123!` |
| **Support Admin** | `support@leanhouse.vn` | `Password123!` |

*(Landlord and Tenant accounts can be created directly via the registration and onboarding flows at `/signup`).*

---

## 💳 Payment Gateway (payOS & VietQR) Setup

LeanHouse supports dual-mode payment reconciliation:

1. **Static VietQR Code:**
   * Every invoice automatically renders a compliant VietQR with bank account details, pre-filled amount, and a unique transfer syntax (`HD <order_code>`).
2. **payOS Real-Time Auto-Reconciliation:**
   * Landlords can configure their payOS credentials (`Client ID`, `API Key`, and `Checksum Key`) in **Landlord Portal ➔ Bank Accounts**.
   * Webhook endpoint: `POST /webhooks/payos`
   * To test payOS webhooks in a local development environment, use [ngrok](https://ngrok.com/):
     ```bash
     ngrok http 3000
     ```
     Set the webhook URL in your payOS Developer Dashboard to:
     `https://<your-ngrok-subdomain>.ngrok-free.app/webhooks/payos`

---

## 🧪 Running Tests & Quality Checks

Run the automated test suite with Minitest:
```bash
bin/rails test
```

Run security static analysis:
```bash
bin/brakeman
```

Run code style checks:
```bash
bin/rubocop
```

---

## 📁 Project Structure

```text
app/
├── controllers/
│   ├── admin_portal/       # Platform administration controllers
│   ├── landlord_portal/    # Landlord dashboard & property management
│   ├── tenant_portal/      # Tenant portal & self-service features
│   ├── webhooks/           # Webhook listeners (payOS)
│   └── ...                 # Public pages & authentication
├── models/                 # Active Record models & business logic
├── services/               # Dedicated service objects (Invoicing, PayOS, Contracts)
├── notifiers/              # Noticed v3 notification classes
├── views/
│   ├── admin_portal/
│   ├── landlord_portal/
│   ├── tenant_portal/
│   └── layouts/shared_components/  # Shared cards, badges, modals, flash messages
└── assets/                 # Custom stylesheets & JavaScript controllers
config/
├── locales/
│   ├── vi/                 # Vietnamese translations
│   └── en/                 # English translations
└── routes.rb               # Modular RESTful routes
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
