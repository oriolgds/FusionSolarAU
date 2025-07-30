# Supabase Edge Functions

## Functions Overview

### 1. `validate-fusion-solar`
Validates FusionSolar API credentials by making a login request.

**Usage:**
```bash
supabase functions invoke validate-fusion-solar --data '{"userName": "your_username", "systemCode": "your_password"}'
```

### 2. `sync-fusion-solar`
Synchronizes data from FusionSolar API for all configured users.

**Features:**
- Fetches plant data
- Syncs daily statistics (production, consumption, income)
- Syncs real-time data (inverter and meter readings)
- Runs automatically every 5 minutes via cron job

**Manual invoke:**
```bash
supabase functions invoke sync-fusion-solar
```

## Deployment

1. Deploy functions:
```bash
supabase functions deploy validate-fusion-solar
supabase functions deploy sync-fusion-solar
```

2. Set up cron job (run the SQL in `_shared/cron-setup.sql`):
```sql
-- Update the URL with your actual project reference
SELECT cron.schedule(
  'sync-fusion-solar-data',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/sync-fusion-solar',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
```

## Architecture

```
sync-fusion-solar/
├── index.ts              # Main entry point
├── fusion-solar-api.ts   # FusionSolar API client
├── sync-service.ts       # Main sync orchestrator
├── plant-sync.ts         # Plant data synchronization
├── daily-data-sync.ts    # Daily statistics sync
├── realtime-sync.ts      # Real-time data sync
└── deno.json            # Deno configuration
```

## Database Tables

The functions interact with these tables:
- `users` - User credentials
- `plants` - Solar plant information
- `solar_daily_data` - Daily production/consumption stats
- `real_time_data` - Real-time inverter/meter data