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

## S3 Setup (Public Page Image Uploads)

The website page editor (`/edit`) now supports uploading page images to S3 instead of writing to `public/uploads/...`.

### 1) Recommended bucket security

- Keep **S3 Block Public Access ON**.
- Serve images through **CloudFront + Origin Access Control (OAC)**.
- Set `PUBLIC_UPLOAD_ASSET_HOST` to your CloudFront domain (for example `https://d123abc.cloudfront.net`).

### 2) Environment variables

Set these in `.env.prod` (or your server environment):

```bash
PUBLIC_UPLOAD_S3_BUCKET=your-public-page-images-bucket
PUBLIC_UPLOAD_S3_REGION=ap-southeast-2
PUBLIC_UPLOAD_ASSET_HOST=https://your-cloudfront-domain
AWS_REGION=ap-southeast-2
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

If you are using an IAM role on the server, omit `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

### 3) IAM policy for app upload credentials/role

Attach this policy to the IAM user/role used by the app:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::your-public-page-images-bucket"
    },
    {
      "Sid": "ManagePublicPageObjects",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::your-public-page-images-bucket/public_pages/*"
    }
  ]
}
```

### 4) Bucket policy for CloudFront OAC (private bucket)

Replace the distribution ARN and bucket name:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontReadOnly",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::your-public-page-images-bucket/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/EXAMPLE123"
        }
      }
    }
  ]
}
```

### 5) Rails Active Storage (optional S3 backend)

If you also want Rails Active Storage files on S3:

```bash
ACTIVE_STORAGE_SERVICE=amazon
AWS_S3_BUCKET=your-active-storage-bucket
AWS_REGION=ap-southeast-2
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

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


```bash
SHA=$(git rev-parse --short HEAD)
docker buildx build --platform linux/amd64 \
  -t ghcr.io/edward0127/curtain_b2b_quote:$SHA \
  -t ghcr.io/edward0127/curtain_b2b_quote:latest \
  --push .
```

then on the docker server, run the command to redeploy

```bash
cd /var/curtain_b2b_quote
git pull
./script/deploy.sh deploy
```

Hi currently when new changes are done, I need to commit the change and push to remote repo, then regenerate the docker image via the command:
  SHA=$(git rev-parse --short HEAD)
  docker buildx build --platform linux/amd64 \
    -t ghcr.io/edward0127/curtain_b2b_quote:$SHA \
    -t ghcr.io/edward0127/curtain_b2b_quote:latest \
    --push .
  then run the command to ssh to remote server: ssh root@amituofo.com.au and go to the dictionary /var/curtain_b2b_quote and run the command to update the live site
  git pull
  ./script/deploy.sh deploy
  Could you automate the whole process similar to C:\Users\edward\projects\saas_savings_site\script\deploy_production.sh does?
