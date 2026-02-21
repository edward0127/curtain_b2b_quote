# Curtain B2B Quote Portal

Rails app for B2B curtain quote requests with:

- Devise login (no self-registration)
- Role enum on `User` (`admin`, `b2b_customer`)
- Admin portal to create/edit/delete B2B customer credentials
- Product catalog (`Product`) with pricing mode (`per_square_meter`, `per_unit`)
- Product-level pricing rules (`PricingRule`) with quantity and area conditions
- Multi-item quote builder (`QuoteRequest` + `QuoteItem`)
- Quote templates (`QuoteTemplate`) and printable document/PDF export
- Admin quote workflow (`submitted -> reviewed -> priced -> sent -> approved -> converted`)
- Job conversion (`Job`) from approved quotes
- Email notification sent via Action Mailer with Mailgun SMTP

## Stack

- Ruby on Rails 8.1
- SQLite
- Devise
- Hotwire (default Rails setup)

## Setup

1. Install gems:

   ```bash
   bundle install
   ```

2. Configure environment variables for admin seeding:

   ```powershell
   $env:SEED_ADMIN_EMAIL="admin@your-domain.com"
   $env:SEED_ADMIN_PASSWORD="strong-password"
   ```

3. Prepare database and seed initial admin:

   ```bash
   bin/rails db:prepare
   bin/rails db:seed
   ```

   Default seeded admin credentials:

   - Email: `admin@example.com`
   - Password: `ChangeMe123!`

4. Start server:

   ```bash
   bin/rails server
   ```

5. Open:

   - `http://localhost:3000`

## Main Flow

1. Admin logs in and opens `Manage Customers`.
2. Admin configures catalog (`Products`) and pricing logic (`Pricing Rules`).
3. Admin configures quote content (`Quote Templates`) and SMTP settings.
4. B2B user logs in and submits multi-item quote request.
5. System computes line pricing, sends quote email, and stores workflow state.
6. Admin advances workflow status and converts approved quote to `Job`.

## Docker Deploy (Single Server)

This project includes:

- `docker-compose.yml`
- `.env.prod.example`
- `script/deploy.sh`

Recommended for your existing server with multiple containers: bind this app to a new host port (default `3012`) to avoid conflicts.

1. Clone repo on server:

   ```bash
   git clone <your-repo-url> curtain_b2b_quote
   cd curtain_b2b_quote
   ```

2. Create production env file:

   ```bash
   cp .env.prod.example .env.prod
   nano .env.prod
   ```

   Required values:

   - `RAILS_MASTER_KEY` (from `config/master.key`)
   - `SEED_ADMIN_EMAIL`
   - `SEED_ADMIN_PASSWORD`

3. Make deploy script executable:

   ```bash
   chmod +x script/deploy.sh
   ```

4. First deploy:

   ```bash
   ./script/deploy.sh bootstrap
   ```

5. Check health:

   ```bash
   curl http://127.0.0.1:3012/up
   ```

6. Open browser:

   - `http://<your-server-ip>:3012`

### Update Deployment

```bash
git pull
./script/deploy.sh deploy
```

Useful commands:

- `./script/deploy.sh status`
- `./script/deploy.sh logs`
- `./script/deploy.sh migrate`
- `./script/deploy.sh down`
