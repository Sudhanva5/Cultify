# CLAUDE.md — CultifyMe

This is the single source of truth for building CultifyMe. Read every word before writing any code. Build exactly what is described. Nothing more.

---

## What is CultifyMe

A personal health logging and AI analysis app for 2 users: Sudhanva and Sagar. Users log their daily exercise, food, sleep, and weight. Every night at 10pm IST, a cron job sends each user's data to Claude API, which generates a structured daily analysis. The next morning, the user opens the app and reads their report.

There is also a live chat with Claude — max 5 messages per user per day — where they can ask questions based on their own logged data.

---

## App name: CultifyMe

---

## Tech stack

| Layer | Technology |
|---|---|
| Mobile | React Native + Expo SDK 51, iOS primary |
| Backend | FastAPI, Python 3.11 |
| Database | PostgreSQL on Railway |
| ORM | SQLAlchemy 2.0 async + asyncpg |
| Migrations | Alembic |
| Auth | JWT — python-jose + passlib[bcrypt] |
| Scheduler | APScheduler 3.x (inside FastAPI process) |
| AI | Anthropic Claude API — model: `claude-sonnet-4-5` |
| Exercise data | free-exercise-db (GitHub, public domain) — seeded into Postgres on first deploy |
| Food photo AI | Claude vision API — called on every food photo upload |
| Image storage | Local filesystem on Railway, served as static files |
| Sheets export | gspread + Google Service Account |
| Hosting | Railway |

---

## Project structure

```
cultify-me/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── scheduler.py
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   ├── user.py
│   │   │   ├── logs.py
│   │   │   └── exercise_ref.py
│   │   ├── schemas/
│   │   │   ├── __init__.py
│   │   │   ├── user.py
│   │   │   └── logs.py
│   │   ├── routers/
│   │   │   ├── __init__.py
│   │   │   ├── auth.py
│   │   │   ├── logs.py
│   │   │   ├── exercises.py
│   │   │   ├── analysis.py
│   │   │   ├── chat.py
│   │   │   └── export.py
│   │   └── services/
│   │       ├── __init__.py
│   │       ├── claude_service.py
│   │       ├── cron_service.py
│   │       └── sheets_service.py
│   ├── alembic/
│   │   ├── env.py
│   │   └── versions/
│   ├── scripts/
│   │   └── seed_exercises.py
│   ├── static/
│   │   └── exercises/
│   ├── uploads/
│   ├── alembic.ini
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── railway.toml
│   └── .env.example
│
└── mobile/
    ├── app/
    │   ├── _layout.tsx
    │   ├── index.tsx                 ← splash / auth gate
    │   ├── (auth)/
    │   │   ├── login.tsx
    │   │   └── register.tsx
    │   └── (tabs)/
    │       ├── _layout.tsx           ← two tabs: Log + Analysis
    │       ├── log.tsx               ← Tab 1: all logging
    │       └── analysis.tsx          ← Tab 2: analysis + chat
    ├── components/
    │   ├── log/
    │   │   ├── ExercisePicker.tsx
    │   │   ├── ExerciseCard.tsx
    │   │   ├── SetRow.tsx
    │   │   ├── FoodLogger.tsx
    │   │   ├── SleepLogger.tsx
    │   │   └── WeightLogger.tsx
    │   ├── analysis/
    │   │   ├── AnalysisCard.tsx
    │   │   ├── NutritionArtifact.tsx
    │   │   ├── CalendarStrip.tsx
    │   │   └── ChatInterface.tsx
    │   └── shared/
    │       ├── api.ts
    │       └── auth.ts
    ├── constants/
    │   └── theme.ts
    ├── package.json
    ├── app.json
    └── tsconfig.json
```

---

## Database schema

```sql
-- users
CREATE TABLE users (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email            VARCHAR(255) UNIQUE NOT NULL,
  hashed_password  VARCHAR(255) NOT NULL,
  name             VARCHAR(100) NOT NULL,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- exercise_reference (seeded from free-exercise-db, never user-modified)
CREATE TABLE exercise_reference (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id       VARCHAR(50) UNIQUE,
  name              VARCHAR(200) NOT NULL,
  body_part         VARCHAR(100),
  equipment         VARCHAR(100),
  target_muscle     VARCHAR(100),
  secondary_muscles JSONB,
  instructions      JSONB,
  gif_path          TEXT,
  is_cult_relevant  BOOLEAN DEFAULT TRUE
);

-- exercise_logs
CREATE TABLE exercise_logs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID REFERENCES users(id) ON DELETE CASCADE,
  exercise_ref_id  UUID REFERENCES exercise_reference(id),
  custom_name      VARCHAR(200),
  logged_at        TIMESTAMPTZ DEFAULT NOW(),
  sets             INTEGER,
  reps             INTEGER,
  weight_kg        FLOAT,
  duration_minutes INTEGER,
  notes            TEXT
);

-- sleep_logs
CREATE TABLE sleep_logs (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES users(id) ON DELETE CASCADE,
  date           DATE NOT NULL,
  slept_at       TIMESTAMPTZ NOT NULL,
  woke_at        TIMESTAMPTZ NOT NULL,
  duration_hours FLOAT
);

-- food_logs
CREATE TABLE food_logs (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID REFERENCES users(id) ON DELETE CASCADE,
  logged_at            TIMESTAMPTZ DEFAULT NOW(),
  meal_type            VARCHAR(20),
  photo_path           TEXT,
  description          TEXT,
  estimated_calories   FLOAT,
  estimated_protein_g  FLOAT,
  estimated_carbs_g    FLOAT,
  estimated_fat_g      FLOAT,
  claude_food_analysis TEXT
);

-- weight_logs
CREATE TABLE weight_logs (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  logged_at  TIMESTAMPTZ DEFAULT NOW(),
  weight_kg  FLOAT NOT NULL
);

-- daily_analyses (written by nightly cron only)
CREATE TABLE daily_analyses (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
  analysis_date   DATE NOT NULL,
  -- structured fields parsed from Claude response
  day_remark      TEXT,
  nutrition_json  JSONB,   -- {calories_consumed, protein_consumed, calories_target, protein_target, efficiency_pct, suggestion}
  weight_projection TEXT,
  recommendations JSONB,   -- array of 3 strings
  full_response   TEXT,    -- raw Claude output
  tokens_used     INTEGER,
  generated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, analysis_date)
);

-- chat_messages (5 per user per day limit)
CREATE TABLE chat_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  role        VARCHAR(10) NOT NULL,   -- 'user' or 'assistant'
  content     TEXT NOT NULL,
  date        DATE NOT NULL           -- which day this chat belongs to
);
```

---

## Exercise seed script — `scripts/seed_exercises.py`

Run once on first deploy. Do the following:

1. Download JSON from:
   `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json`

2. For each exercise, download the first image from:
   `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{id}/0.jpg`
   Save to: `backend/static/exercises/{id}.jpg`
   If 404, skip the image (gif_path = NULL).

3. Insert into `exercise_reference`. Set `is_cult_relevant = FALSE` for equipment in:
   `['assisted', 'sled machine', 'bosu ball', 'leverage machine', 'skierg machine', 'rope', 'roller', 'wheel roller']`
   Everything else: `is_cult_relevant = TRUE`.

4. After seeding from the JSON, insert these additional rows manually (these are Cult-specific classes not in the dataset):

```python
custom_exercises = [
    {"name": "Cult Live Class", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
    {"name": "HRX Workout", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
    {"name": "Badminton", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
    {"name": "Swimming", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
    {"name": "Dance Practice", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
    {"name": "Walk / Run (Outdoor)", "body_part": "cardio", "equipment": "none", "target_muscle": "full body"},
]
```

Script must be idempotent — if rows already exist (check by external_id), skip them.

---

## API endpoints

### Auth
```
POST  /auth/register     {email, password, name}
POST  /auth/login        {email, password} → {access_token, user}
GET   /auth/me           → {id, email, name}
```

### Logging
```
POST  /logs/exercise
      body: {exercise_ref_id?, custom_name?, sets?, reps?, weight_kg?,
             duration_minutes?, notes?, logged_at?}

GET   /logs/exercise?date=YYYY-MM-DD
      returns exercise_logs joined with exercise_reference (name, gif_path, body_part)

DELETE /logs/exercise/{id}

POST  /logs/sleep
      body: {date, slept_at, woke_at}
      computes duration_hours = (woke_at - slept_at) in hours, stores it

GET   /logs/sleep?date=YYYY-MM-DD

POST  /logs/food
      multipart/form-data: photo (file), meal_type (str), description (str)
      → saves photo to /uploads/{user_id}/{uuid}.jpg
      → calls Claude vision (see claude_service.py)
      → stores macro estimates in food_logs
      → returns food_log row with estimates

GET   /logs/food?date=YYYY-MM-DD

DELETE /logs/food/{id}

POST  /logs/weight
      body: {weight_kg, logged_at?}

GET   /logs/weight?days=90
      returns [{logged_at, weight_kg}] sorted ascending
```

### Exercises
```
GET   /exercises?body_part=chest&search=bench&cult_only=true
      returns paginated exercise_reference list
      includes: id, name, body_part, equipment, target_muscle, gif_path

GET   /exercises/{id}
```

### Analysis
```
GET   /analysis?date=YYYY-MM-DD
      returns daily_analyses row for that date
      if not found: {status: "not_generated"}

GET   /analysis/history?days=30
      returns [{analysis_date, day_remark, nutrition_json, recommendations, generated_at}]
      sorted descending
```

### Chat
```
POST  /chat
      body: {message: string}
      
      Checks: how many chat_messages with role='user' exist for today? 
      If >= 5: return 429 {error: "Daily limit reached", messages_used: 5, limit: 5}
      
      Builds context from today's data + latest analysis
      Calls Claude API
      Stores both user message and assistant response in chat_messages
      Returns: {response: string, messages_used: int, limit: 5}

GET   /chat/today
      returns all chat_messages for today, sorted ascending
      includes: {messages: [...], messages_used: int, limit: 5}
```

### Export
```
GET   /export/sheets    → triggers Google Sheets export, returns {sheet_url}
GET   /export/json      → returns all user data as downloadable JSON
```

### Health check
```
GET   /health           → {status: "ok"}
```

---

## Claude service — `services/claude_service.py`

### 1. Food photo analysis (called immediately on food upload)

```python
async def analyse_food_photo(image_path: str, description: str) -> dict:
    with open(image_path, "rb") as f:
        image_data = base64.standard_b64encode(f.read()).decode("utf-8")

    message = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=300,
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {"type": "base64", "media_type": "image/jpeg", "data": image_data}
                },
                {
                    "type": "text",
                    "text": f"""Analyse this meal photo. User description: "{description or 'not provided'}".

Estimate nutritional content based on what you see — portion sizes, ingredients, cooking method visible.

Respond ONLY with valid JSON, nothing else:
{{"calories": 450, "protein_g": 22, "carbs_g": 55, "fat_g": 12, "what_i_see": "Brief description of plate contents and estimated portions"}}"""
                }
            ]
        }]
    )

    return json.loads(message.content[0].text.strip())
```

### 2. Nightly analysis (called by cron at 10pm IST)

Build context from:
- TODAY: full exercise list, food list with macros, sleep, weight
- LAST 7 DAYS: aggregated stats only (avg sleep, gym session count, avg calories, avg protein)
- WEIGHT HISTORY: all weight entries ever, date + kg, sorted ascending

Prompt:

```
You are analysing health data for {user_name}. Be direct and specific. No generic advice.

TODAY ({date}):
Exercises: {exercises or "none logged"}
Food: {food items with macro estimates, totals}
Sleep: {duration or "not logged"}
Weight: {weight or "not logged"}

LAST 7 DAYS:
- Avg sleep: X hrs
- Gym sessions: X of 7 days
- Avg calories: ~X kcal/day
- Avg protein: ~Xg/day

WEIGHT HISTORY (for projection):
{date: weight_kg for every entry}

Respond with ONLY valid JSON in exactly this structure:
{
  "day_remark": "2-3 sentences. Honest assessment of today specifically.",
  "nutrition": {
    "calories_consumed": 1850,
    "protein_consumed": 98,
    "calories_target": 2200,
    "protein_target": 130,
    "efficiency_pct": 84,
    "suggestion": "One specific sentence about what to eat tomorrow based on today's gap."
  },
  "weight_projection": "Based on X data points showing Y trend, projected weight in 4 weeks: Z kg, 8 weeks: Z kg. Brief reasoning.",
  "recommendations": [
    "Specific recommendation 1 based on actual data pattern",
    "Specific recommendation 2 based on actual data pattern",
    "Specific recommendation 3 based on actual data pattern"
  ]
}

nutrition.calories_target and protein_target: use 2200 kcal and 130g protein as defaults unless there is enough data to infer differently.
efficiency_pct: (calories_consumed / calories_target * 0.5 + protein_consumed / protein_target * 0.5) * 100, capped at 100.
```

Parse the JSON response. Store each field in the appropriate `daily_analyses` column.

### 3. Chat (called on POST /chat)

Build context:

```python
def build_chat_context(user_name: str, today_data: dict, latest_analysis: dict) -> str:
    return f"""You are a health assistant for {user_name}. You have access to their logged health data.

TODAY'S DATA:
Exercises: {today_data['exercises_summary']}
Food: {today_data['food_summary']} (~{today_data['total_calories']} kcal, ~{today_data['total_protein']}g protein)
Sleep: {today_data['sleep_summary']}
Weight: {today_data['weight_summary']}

LATEST ANALYSIS ({latest_analysis['date'] if latest_analysis else 'none yet'}):
{latest_analysis['day_remark'] if latest_analysis else 'No analysis generated yet.'}
Recommendations: {latest_analysis['recommendations'] if latest_analysis else 'N/A'}

Answer the user's question based only on this data. Be direct and specific. Max 150 words."""
```

Call Claude with the context as system message + full conversation history for today.

---

## Cron service — `services/cron_service.py`

```python
scheduler = AsyncIOScheduler(timezone=pytz.timezone("Asia/Kolkata"))

scheduler.add_job(
    run_nightly_analysis,
    CronTrigger(hour=22, minute=0),
    id="nightly_analysis",
    replace_existing=True
)
```

`run_nightly_analysis()`:
1. Fetch all users
2. For each user: build context → call Claude → parse JSON response → upsert into daily_analyses
3. On any exception for a single user: log error, continue to next user
4. Never crash the whole job for one user's failure

---

## Mobile UI — complete specification

### Theme — `constants/theme.ts`

```typescript
export const theme = {
  bg: '#060b14',
  card: '#0d1117',
  cardBorder: 'rgba(255,255,255,0.07)',
  accent: '#E85D24',
  accentBlue: '#378ADD',
  textPrimary: '#FFFFFF',
  textSecondary: '#6B7280',
  textMuted: '#374151',
  success: '#10B981',
  warning: '#F59E0B',
  danger: '#EF4444',
  radius: {
    card: 12,
    input: 8,
    pill: 20,
  }
}
```

### App entry — `app/index.tsx`

Splash screen behaviour:
- Check for stored JWT token
- If valid: redirect to `/(tabs)/log`
- If not: redirect to `/(auth)/login`

Show app name "CultifyMe" centered on bg color during check.

### Auth screens

Simple dark-themed login and register forms. Email + password. On successful login: store JWT in SecureStore, redirect to tabs.

### Two tabs — `app/(tabs)/_layout.tsx`

```
Tab 1: "Log"      icon: edit-3 (feather)
Tab 2: "Analysis" icon: bar-chart-2 (feather)
```

Tab bar: dark background `#0d1117`, active tab accent orange `#E85D24`, inactive `#6B7280`.

No other tabs. No profile tab. No settings tab.

---

### TAB 1 — Log (`app/(tabs)/log.tsx`)

**Header:**
```
CultifyMe                    [avatar/initials circle]
{Day}, {Date}                e.g. "Monday, 17 May"
```

Four sections below, each a card with a section header. All visible on scroll — no accordions, no collapsing. Keep it simple.

---

#### SECTION 1: WORKOUT

Header: "💪 Workout"

"+ Add Exercise" button (full width, dashed border, accent color text).

Tapping opens a **bottom sheet** (use `@gorhom/bottom-sheet`):

**Inside the bottom sheet:**

Search bar at top: `"Search exercises..."` — filters by name in real time.

Horizontal scroll pills below search:
`All  |  Chest  |  Back  |  Shoulders  |  Arms  |  Legs  |  Core  |  Cardio`

Exercise list — each row:
- Left: exercise GIF/image (48×48, rounded, from `{API_URL}/static/exercises/{gif_path}`)
- Middle: exercise name (bold), equipment label (muted)
- Right: body part pill (colored)

Tapping a row: closes the list, shows the log form:
- Exercise name shown at top
- Toggle: **Strength** | **Cardio**
- Strength: three number inputs in a row — Sets / Reps / Weight (kg)
- Cardio: one input — Duration (min)
- "Log Exercise" button → POST /logs/exercise → closes bottom sheet

Today's logged exercises below the button. Each card:
- Exercise name + body part pill
- Strength: `3 × 10 @ 60 kg` | Cardio: `30 min`
- Swipe left → delete button → DELETE /logs/exercise/{id}

---

#### SECTION 2: FOOD

Header: "🍽 Food"

"+ Add Meal" button.

Tapping opens bottom sheet:

**Meal type selector** (pill row): `Breakfast  |  Lunch  |  Dinner  |  Snack`

**Big camera button** in the center of the sheet:
```
[  📷  ]
Take a photo of your meal
```
Tapping opens camera (use `expo-image-picker`, `launchCameraAsync`).
Also show "Choose from Gallery" text link below.

After photo selected:

**Text input** appears: `"Add description (optional)"` — placeholder: `"e.g. dal chawal, 2 rotis, curd"`

**"Analyse & Log" button** (orange, full width):
- Shows loading: `"Claude is analysing your meal..."`
- POST /logs/food (multipart: photo file + meal_type + description)
- On success: shows result card:
  ```
  ✓ Meal logged
  ~450 kcal  |  22g protein  |  55g carbs  |  12g fat
  "A plate of dal chawal with approximately 1.5 cups rice..."
  ```
- "Done" button closes sheet

Today's food logs below:
Each card: thumbnail photo (48×48) + meal type label + macro summary line.
Tap to expand: shows Claude's description of what it saw.
Swipe left → delete.

---

#### SECTION 3: SLEEP

Header: "😴 Sleep"

Two time pickers side by side:
```
[ Slept at ]        [ Woke at ]
  11:00 PM            7:00 AM
```
Use `@react-native-community/datetimepicker`.

Auto-computed below: `"Duration: 8 hrs 0 min"`

"Log Sleep" button → POST /logs/sleep.

If already logged today: show the entry. Show "Edit" to replace.

---

#### SECTION 4: WEIGHT

Header: "⚖️ Weight"

Center of card:
```
[ 79.0 ] kg
```
Large numeric input. "Log Weight" button.

Below: last 5 entries mini-list: `"17 May — 79.0 kg"`

---

### TAB 2 — Analysis (`app/(tabs)/analysis.tsx`)

This tab has three sections stacked vertically.

---

#### SECTION 1: CALENDAR + DAY ANALYSIS

**Calendar strip** at top — horizontal scrollable row of day pills:
```
  14    15    16   [17]   18    19    20
  Mon   Tue   Wed   Thu   Fri   Sat   Sun
```
Selected day has accent orange background. Tapping a day loads that day's analysis.

**Analysis card** below the calendar:

If analysis exists for selected day:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TODAY'S REMARK
{day_remark text}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RECOMMENDATIONS
• {recommendation 1}
• {recommendation 2}
• {recommendation 3}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WEIGHT PROJECTION
{weight_projection text}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If no analysis for selected day:
```
Analysis for this day hasn't been generated yet.
Reports generate automatically every night at 10pm.
```

---

#### SECTION 2: NUTRITION ARTIFACT

This is the "artifact" — a visual card showing nutrition data for the selected day.

Pull data from `daily_analyses.nutrition_json`:
```json
{
  "calories_consumed": 1850,
  "protein_consumed": 98,
  "calories_target": 2200,
  "protein_target": 130,
  "efficiency_pct": 84,
  "suggestion": "Add a whey shake tonight to close the protein gap."
}
```

Render as `NutritionArtifact.tsx`:

```
┌─────────────────────────────────────────┐
│  NUTRITION SNAPSHOT                      │
│                                          │
│  Calories          Protein               │
│  [████████░░] 84%  [███████░░░] 75%      │
│  1850 / 2200 kcal  98 / 130g            │
│                                          │
│  Overall efficiency: 84%                 │
│  ● Good / Needs Work / On Track          │
│                                          │
│  💡 {suggestion}                         │
└─────────────────────────────────────────┘
```

Progress bars: use `react-native` `View` with percentage width, not a library.
- 0–60%: danger red `#EF4444`
- 60–80%: warning amber `#F59E0B`
- 80–100%: success green `#10B981`

Efficiency label:
- < 60%: "Needs work"
- 60–80%: "Getting there"
- 80–95%: "On track"
- 95–100%: "Nailed it"

If no nutrition data for selected day: show muted placeholder card.

---

#### SECTION 3: CHAT WITH CLAUDE

Header: "💬 Ask Claude" with pill on the right showing `"{X}/5 today"`

Messages list — conversation style, dark bubbles:
- User messages: right-aligned, accent orange background
- Claude messages: left-aligned, card background with border

If 0 messages today, show placeholder:
```
Ask me anything about your health data.
Based on what you've logged, I can help you understand
your progress and answer specific questions.
```

Input row at bottom:
```
[Type a message...              ] [Send →]
```

Send button:
- If messages_used >= 5: button disabled, input disabled
- Show: `"Daily limit reached (5/5). Resets tomorrow."`
- If messages_used < 5: enabled normally

On send:
- Append user message to list immediately (optimistic)
- POST /chat with {message}
- Show typing indicator (three dots animation) for Claude's response
- Append Claude's response
- Update the `{X}/5 today` pill

Chat only shows today's messages. Yesterday's chat is gone (still stored in DB but not shown).

---

## Chat rate limit logic — backend

In `POST /chat`:

```python
today = date.today()
user_message_count = await db.execute(
    select(func.count(ChatMessage.id))
    .where(ChatMessage.user_id == current_user.id)
    .where(ChatMessage.date == today)
    .where(ChatMessage.role == 'user')
)
count = user_message_count.scalar()

if count >= 5:
    raise HTTPException(
        status_code=429,
        detail={"error": "Daily limit reached", "messages_used": 5, "limit": 5}
    )
```

---

## Google Sheets export

Four tabs: Weight, Sleep, Food, Exercises.
Sheet named: `"CultifyMe — {user.name}"`
Clears and rewrites on every call.
Returns the sheet URL.

---

## requirements.txt

```
fastapi==0.111.0
uvicorn[standard]==0.29.0
sqlalchemy==2.0.30
asyncpg==0.29.0
alembic==1.13.1
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.9
pydantic-settings==2.2.1
anthropic==0.28.0
apscheduler==3.10.4
pytz==2024.1
gspread==6.1.2
google-auth==2.29.0
httpx==0.27.0
aiofiles==23.2.1
Pillow==10.3.0
requests==2.31.0
```

## package.json dependencies (mobile)

```json
{
  "dependencies": {
    "expo": "~51.0.0",
    "expo-router": "~3.5.0",
    "expo-secure-store": "~13.0.0",
    "expo-image-picker": "~15.0.0",
    "expo-camera": "~15.0.0",
    "@gorhom/bottom-sheet": "^4.6.0",
    "@react-native-community/datetimepicker": "^7.6.0",
    "axios": "^1.6.0",
    "react-native-gesture-handler": "~2.16.0",
    "react-native-reanimated": "~3.10.0"
  }
}
```

---

## .env.example

```
DATABASE_URL=postgresql+asyncpg://user:pass@host:5432/dbname
SECRET_KEY=your-secret-key-at-least-32-characters
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_SERVICE_ACCOUNT_JSON=/app/google-service-account.json
GOOGLE_SHARE_EMAIL=your@gmail.com
UPLOAD_DIR=/app/uploads
STATIC_DIR=/app/static
PORT=8000
```

```
# mobile/.env
EXPO_PUBLIC_API_URL=https://your-app.railway.app
```

---

## railway.toml

```toml
[build]
builder = "DOCKERFILE"

[deploy]
startCommand = "alembic upgrade head && python scripts/seed_exercises.py && uvicorn app.main:app --host 0.0.0.0 --port $PORT"
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
```

## Dockerfile

```dockerfile
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN mkdir -p /app/uploads /app/static/exercises
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Build order — follow exactly

1. Project folder structure
2. `config.py` (pydantic-settings), `database.py` (async engine + session factory)
3. All SQLAlchemy models
4. Alembic migration — verify matches schema exactly
5. `seed_exercises.py` — download + store images + seed DB (idempotent)
6. Auth router + JWT middleware dependency
7. All logging routers (exercise, sleep, food with Claude vision, weight)
8. Exercise reference router
9. `claude_service.py` — food photo + nightly prompt + chat context
10. `cron_service.py` — APScheduler at 10pm IST
11. Analysis router
12. Chat router with 5/day rate limit
13. Export router + `sheets_service.py`
14. `GET /health` endpoint
15. Mobile: auth screens (login, register)
16. Mobile: theme constants
17. Mobile: Tab 1 — all four log sections with bottom sheets and camera
18. Mobile: Tab 2 — calendar strip, analysis card, nutrition artifact, chat interface
19. Mobile: `api.ts` with JWT interceptor + auto token refresh
20. Railway deployment files

---

## Non-negotiable rules

1. Every single database query must filter by `user_id`. No exceptions.
2. JWT token validated via FastAPI `Depends` on every protected endpoint.
3. Food photo Claude call: save to DB before returning response. If Claude fails, save the food log anyway with NULL macros.
4. Nightly cron: one user's failure must never stop other users from getting their analysis.
5. Chat limit: enforced server-side. Client UI reflects it but server is the authority.
6. `daily_analyses` has a UNIQUE constraint on (user_id, analysis_date). Use upsert (INSERT ... ON CONFLICT DO UPDATE).
7. All timestamps: stored as TIMESTAMPTZ. API returns ISO 8601 strings.
8. Exercise GIF download in seed script: if any single image download fails, log the error and continue. Do not crash the whole seed.
9. The `efficiency_pct` in nutrition_json: computed by Claude as instructed in the prompt, stored as-is.
10. No features not listed in this document. No streak tracking. No notifications. No social features. No settings screen. No profile screen.

---

## What success looks like

Sudhanva opens CultifyMe → Tab 1 → adds "Bench Press 4×8 @ 70kg" → takes photo of his dal chawal lunch → Claude says "~680 kcal, 28g protein" → logs sleep 11pm–7am → logs 79.2kg.

10pm: cron runs. Claude analyses the day. Stores structured JSON.

Next morning: Sudhanva opens Tab 2 → sees today's remark, his nutrition bars showing 84% efficiency, 3 specific recommendations, weight projected at 78.1kg in 4 weeks → asks Claude "was my protein enough today?" → gets a direct answer → that's message 1 of 5.

Sagar does the same. His analysis is completely different. Same app. Same code. Different data, different output.

That is the entire product. Build it.