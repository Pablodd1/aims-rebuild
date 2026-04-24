# AIMS Rebuild - Real-Time Deployment Dashboard

Full-stack app with Next.js frontend and Express backend, powered by Supabase for real-time deployment tracking.

## Stack
- **Frontend**: Next.js 14, TypeScript, Tailwind CSS
- **Backend**: Express.js
- **Database**: Supabase (PostgreSQL)
- **Deploy**: Vercel

## Setup

```bash
# Frontend
cd frontend && npm install

# Backend  
cd backend && npm install
```

## Environment Variables

Set in Vercel dashboard:
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your Supabase anon key

## Database Schema (Supabase)

```sql
CREATE TABLE deployments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  url TEXT,
  status TEXT DEFAULT 'pending',
  project TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

ALTER TABLE deployments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all" ON deployments FOR ALL USING (true);
```

## Deploy

```bash
vercel --prod
```
