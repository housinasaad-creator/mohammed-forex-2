const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GROK_MODEL = 'grok-4.3'
const GROK_URL = 'https://api.x.ai/v1/chat/completions'

const NO_AI_RULE =
  'CRITICAL: Never mention "AI", "artificial intelligence", "Grok", "xAI", "language model", or any reference to automated/algorithmic generation anywhere in your output. Write as a professional market analyst stating findings directly.'

function langLabel(lang: string) {
  return lang === 'ar' ? 'Arabic' : lang === 'tr' ? 'Turkish' : 'English'
}

// ── Grok (xAI) call helper ────────────────────────────────────────────────────
// response_format:{type:"json_object"} guarantees valid JSON text back — no
// regex extraction needed. reasoning_effort:"low" keeps latency/cost down —
// this task is a single-pass analytical read, not a multi-step math problem.
// temperature:0 makes output reproducible given the same input: with the
// default sampling, the SAME market data could flip from BUY to SELL minutes
// apart for no real reason — unacceptable for a trading tool.
async function callGrok(
  apiKey: string,
  system: string,
  userContent: Record<string, unknown>[] | string,
) {
  const res = await fetch(GROK_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: GROK_MODEL,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: userContent },
      ],
      temperature: 0,
      reasoning_effort: 'low',
      response_format: { type: 'json_object' },
    }),
  })
  const data = await res.json()
  if (!res.ok) {
    console.error(`Grok API error ${res.status}:`, JSON.stringify(data))
    return `__ERROR__ ${res.status}: ${data?.error?.message ?? data?.error ?? JSON.stringify(data)}`
  }
  const text = data?.choices?.[0]?.message?.content ?? ''
  if (!text) {
    console.error('Grok empty response:', JSON.stringify(data))
  }
  return text.trim()
}

function extractJson(raw: string): Record<string, unknown> | null {
  try { return JSON.parse(raw) } catch { /* fall through */ }
  const match = raw.match(/\{[\s\S]*\}/)
  if (match) {
    try { return JSON.parse(match[0]) } catch { /* give up */ }
  }
  return null
}

// ── Agent 1: Chart_Vision_Agent ──────────────────────────────────────────────
async function chartVisionAgent(apiKey: string, symbol: string, lang: string, imageB64: string) {
  const system = `You are an expert chart-pattern analyst reading a candlestick chart visually, exactly like a trader looking at the screen.
${NO_AI_RULE}
Respond ONLY in ${langLabel(lang)}, ONLY with valid JSON: {"bias": "Bullish"|"Bearish"|"Neutral", "reason": "<one short sentence — pattern, structure, or trend you see>"}`

  const userText = `Asset: ${symbol}. This image shows the last 60 candles on the 30-minute timeframe. Analyze the visual price action: trend direction, candle patterns, and any clear support/resistance levels you can see. Give your bias.`

  const text = await callGrok(apiKey, system, [
    { type: 'image_url', image_url: { url: `data:image/png;base64,${imageB64}` } },
    { type: 'text', text: userText },
  ])
  return extractJson(text) ?? { bias: 'Neutral', reason: text.slice(0, 300) || '(empty response)' }
}

// ── Agent 2: Technical_Analyst_Agent ─────────────────────────────────────────
async function technicalAnalystAgent(apiKey: string, symbol: string, lang: string, indicators: Record<string, unknown>) {
  const system = `You are a quantitative technical analyst. You receive PRE-COMPUTED indicator values — do not recalculate anything, only interpret them.
${NO_AI_RULE}
Respond ONLY in ${langLabel(lang)}, ONLY with valid JSON: {"bias": "Bullish"|"Bearish"|"Neutral", "strength_pct": <0-100>, "reason": "<one short sentence citing the strongest 1-2 indicators>"}`

  const userText = `Asset: ${symbol} (30-minute timeframe). Indicator readout:\n${JSON.stringify(indicators, null, 2)}\n\nGive your technical bias and a confidence percentage purely from these numbers.`

  const text = await callGrok(apiKey, system, userText)
  return extractJson(text) ?? { bias: 'Neutral', strength_pct: 50, reason: text.slice(0, 300) || '(empty response)' }
}

// ── Agent 3: News_Sentiment_Agent ────────────────────────────────────────────
// Reads the real Forex Factory economic-calendar feed directly — no model
// call at all, so this agent costs nothing and never times out.
type FfEvent = { title: string; country: string; date: string; impact: string }

function currenciesOf(symbol: string): string[] {
  const clean = symbol.replace(/[^A-Za-z]/g, '').toUpperCase()
  if (clean.length >= 6) return [clean.slice(0, 3), clean.slice(3, 6)]
  return [clean]
}

function newsTexts(lang: string, events: FfEvent[], risk: string) {
  const fmt = (e: FfEvent) => {
    const t = new Date(e.date)
    const hh = t.getUTCHours().toString().padStart(2, '0')
    const mm = t.getUTCMinutes().toString().padStart(2, '0')
    return `${e.title} (${e.country}, ${hh}:${mm} UTC)`
  }
  const list = events.slice(0, 3).map(fmt).join(' | ')

  if (events.length === 0) {
    return lang === 'ar' ? 'لا توجد أحداث اقتصادية مؤثرة قريبة لعملتي هذا الزوج.'
         : lang === 'tr' ? 'Bu paritenin para birimleri için yakın zamanda önemli bir ekonomik olay yok.'
         : 'No significant economic events nearby for this pair\'s currencies.'
  }
  if (lang === 'ar') return `أحداث اقتصادية بمستوى تأثير ${risk === 'High' ? 'مرتفع' : risk === 'Medium' ? 'متوسط' : 'منخفض'}: ${list}`
  if (lang === 'tr') return `${risk} etki seviyeli ekonomik olaylar: ${list}`
  return `${risk}-impact economic events: ${list}`
}

async function newsSentimentAgent(symbol: string, lang: string) {
  try {
    const res = await fetch('https://nfs.faireconomy.media/ff_calendar_thisweek.json')
    if (!res.ok) throw new Error(`ff calendar HTTP ${res.status}`)
    const all = (await res.json()) as FfEvent[]

    const currencies = currenciesOf(symbol)
    const now = Date.now()
    const windowMs = (mins: number) => mins * 60 * 1000
    const relevant = all.filter((e) => {
      if (!currencies.includes(e.country)) return false
      const t = new Date(e.date).getTime()
      return t >= now - windowMs(30) && t <= now + windowMs(120)
    })

    const high = relevant.filter((e) => e.impact === 'High')
    const medium = relevant.filter((e) => e.impact === 'Medium')
    const risk = high.length > 0 ? 'High' : medium.length > 0 ? 'Medium' : 'Low'
    const shown = high.length > 0 ? high : medium.length > 0 ? medium : relevant

    return { risk, reason: newsTexts(lang, shown, risk) }
  } catch (e) {
    console.error('newsSentimentAgent (Forex Factory) failed:', e)
    return { risk: 'Low', reason: lang === 'ar' ? 'تعذّر جلب التقويم الاقتصادي — افتراض مخاطر منخفضة.' : 'Could not fetch economic calendar — assuming low risk.' }
  }
}

// ── Agent 4: Decision_Maker_Agent ────────────────────────────────────────────
async function decisionMakerAgent(
  apiKey: string,
  symbol: string,
  lang: string,
  atrPips: number,
  vision: Record<string, unknown>,
  technical: Record<string, unknown>,
  news: Record<string, unknown>,
  m1: { bias: string; note: string },
) {
  const system = `You are the senior trading desk decision-maker. You receive independent reports — chart vision, technical indicators, M1 short-term structure, and news risk — and must issue ONE final trade decision.
${NO_AI_RULE}
Trading style constraint: trades on this desk are based on 30-minute analysis, with an EXPECTED HOLD TIME between 30 minutes and a maximum of 1 HOUR — never longer. This is not scalping (seconds) and not swing trading (many hours/days). Size your stop-loss and take-profit distances and your exit-time guidance around this window.
M1 STRUCTURE RULE: the M1 report tells you the real, math-derived short-term swing structure (higher-highs/higher-lows vs lower-highs/lower-lows) forming right now. It is more current than the M30 read. If M1 structure clearly CONTRADICTS the M30-based direction you'd otherwise take, do not blindly override — instead lower your confidence significantly or signal WAIT, since a live structure conflict at entry time is a real warning sign, not noise to ignore.
CRITICAL — target sizing: tp_pips MUST be realistically reachable within 1 hour given the asset's actual recent volatility (ATR, provided to you below). As a hard rule, tp_pips should not exceed roughly 2-3x the ATR(14) value in pips — a target far beyond that takes hours or days to reach, not one hour, and is a fabricated number, not a real target. If you are not confident price can realistically travel that distance within 1 hour, lower tp_pips or signal WAIT instead.
Also decide a RISK PERCENTAGE — the % of the trader's account balance to risk on this single trade — scaled to your own confidence: weak/borderline setups get a low percentage (around 0.5%-1%), strong high-confluence setups can go up to 2%-3%. Never exceed 3%. On WAIT, risk percentage is 0.
Respond ONLY in ${langLabel(lang)}, ONLY with valid JSON:
{
  "signal": "BUY"|"SELL"|"WAIT",
  "confidence_pct": <0-100>,
  "reasons": "<one short, confident sentence — the core justification, suitable to print directly on a chart>",
  "sl_pips": <number, stop-loss distance in pips, sane for a 30m-1h hold>,
  "tp_pips": <number, take-profit distance in pips — realistically reachable within 1 hour given the asset's ATR, see CRITICAL rule above>,
  "risk_pct": <number, 0 to 3, the recommended % of account balance to risk on this trade>,
  "exit_note": "<one sentence, in ${langLabel(lang)}, telling the trader the maximum time to wait before closing manually if TP is not hit — base this on how strong/weak the confluence is, staying within the 30min-1h window>"
}`

  const userText = `Asset: ${symbol}
ATR (volatility): ${atrPips.toFixed(1)} pips

--- Chart Vision Report (M30) ---
${JSON.stringify(vision)}

--- Technical Indicator Report (M30) ---
${JSON.stringify(technical)}

--- M1 Short-Term Structure Report (live, math-derived) ---
{"bias": "${m1.bias}", "note": "${m1.note}"}

--- News & Event Risk Report ---
${JSON.stringify(news)}

Combine all reports and issue the final decision. Pay special attention to the M1 STRUCTURE RULE above.`

  const text = await callGrok(apiKey, system, userText)
  return { parsed: extractJson(text), raw: text }
}

// ── Entry point ───────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { symbol, lang, indicators, atrPips, chartImageBase64, m1Bias, m1Note } = await req.json()
    const GROK_KEY = Deno.env.get('GROK_KEY') ?? ''
    const safeLang = lang ?? 'en'

    // Agents 1, 2, 3 run in parallel — none depends on the others.
    const [vision, technical, news] = await Promise.all([
      chartVisionAgent(GROK_KEY, symbol, safeLang, chartImageBase64),
      technicalAnalystAgent(GROK_KEY, symbol, safeLang, indicators ?? {}),
      newsSentimentAgent(symbol, safeLang),
    ])

    // Agent 4 waits for all three, then makes the final call.
    const { parsed: decision, raw: decisionRaw } = await decisionMakerAgent(
      GROK_KEY, symbol, safeLang, Number(atrPips) || 0, vision, technical, news,
      { bias: m1Bias ?? 'Neutral', note: m1Note ?? '' },
    )

    if (!decision) {
      return new Response(JSON.stringify({
        error: 'decision_parse_failed',
        decisionRaw,
        vision, technical, news,
      }), {
        status: 502,
        headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({
      signal: decision.signal ?? 'WAIT',
      confidence_pct: decision.confidence_pct ?? 50,
      reasons: decision.reasons ?? '',
      sl_pips: decision.sl_pips ?? 0,
      tp_pips: decision.tp_pips ?? 0,
      risk_pct: decision.risk_pct ?? 0,
      exit_note: decision.exit_note ?? '',
      // debug context — not required by the client, harmless to include
      vision, technical, news,
    }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }
})
