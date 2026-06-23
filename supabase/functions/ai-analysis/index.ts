const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const body = await req.json()
  const {
    symbol, timeframe, signal, accuracy,
    rsi, rsiDivergence,
    macd, macdHistogram,
    htf, zone, score,
    bb, smc,
    pattern, atrPips,
    entry, sl, tp,
    session, sessionQuality, sessionWarning,
    lang,
  } = body

  const ANTHROPIC_KEY = Deno.env.get('ANTHROPIC_KEY') ?? ''
  const langLabel = lang === 'ar' ? 'Arabic' : lang === 'tr' ? 'Turkish' : 'English'

  const sessionCtx = sessionWarning
    ? `Session: ${session ?? 'Unknown'} ⚠️ LOW LIQUIDITY: ${sessionWarning} (quality ${sessionQuality ?? 0}/1.0)`
    : `Session: ${session ?? 'Unknown'} (quality ${sessionQuality ?? 1}/1.0 — good liquidity)`

  const smcCtx   = smc && smc !== 'No SMC signals' ? `SMC: ${smc}` : 'SMC: No clear SMC signals'
  const divCtx   = rsiDivergence ?? 'No divergence'
  const bbCtx    = bb ?? 'price near midline'
  const patCtx   = pattern && pattern !== 'None' ? `Candle Pattern: ${pattern}` : 'Candle Pattern: None'
  const atrCtx   = atrPips ? `ATR: ${atrPips} pips` : ''
  const levCtx   = entry ? `Entry: ${entry}  SL: ${sl}  TP: ${tp}` : ''

  const systemPrompt = `You are an expert forex scalping analyst with 15+ years experience in Smart Money Concepts (SMC), technical analysis, and risk management.
Respond ONLY in ${langLabel}.
You will receive comprehensive technical data including traditional indicators AND advanced SMC/deep analysis.
Integrate ALL provided data in your assessment — give extra weight to SMC confluence (BOS, Order Blocks, FVG, Liquidity Sweeps) and RSI divergence as these are high-probability signals.
Session quality affects confidence: London/NY overlap (≈1.0) = full confidence; Tokyo/Sydney (≈0.3) = reduced size and caution.`

  const userPrompt = `=== FULL TECHNICAL ANALYSIS ===
Asset: ${symbol}  |  Timeframe: ${timeframe ?? '–'}  |  Signal: ${signal ?? '–'}  |  Accuracy: ${accuracy ?? '–'}%

--- Traditional Indicators ---
RSI(14): ${rsi}
RSI Divergence: ${divCtx}
MACD: ${macd}
Higher Timeframe (H1 EMA50): ${htf}
Supply/Demand Zone: ${zone}
Bollinger Bands: ${bbCtx}
${atrCtx}

--- Smart Money Concepts ---
${smcCtx}

--- Price Action ---
${patCtx}

--- Trade Levels ---
${levCtx}

--- Session ---
${sessionCtx}

Overall Confluence Score: ${score}/10

=== TASK ===
Respond with valid JSON only (no markdown, no extra text):
{
  "analysis": "<2-3 sentence professional assessment in ${langLabel}, integrating ALL factors above — especially SMC confluence and divergence>",
  "trade_note": "<ONE specific sentence in ${langLabel} starting with ⏱ — tell the trader exactly how many minutes to wait before closing the trade if TP is not reached, and WHY based on the specific indicators provided>"
}`

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': ANTHROPIC_KEY,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 500,
      system: systemPrompt,
      messages: [{ role: 'user', content: userPrompt }],
    }),
  })

  const data = await res.json()
  const rawText = (data?.content?.[0]?.text ?? '').trim()

  // Try to parse as JSON; fall back to wrapping the text in analysis field
  try {
    const parsed = JSON.parse(rawText)
    return new Response(JSON.stringify(parsed), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch {
    // Claude returned plain text — wrap it
    return new Response(
      JSON.stringify({ analysis: rawText, trade_note: '' }),
      { headers: { ...CORS, 'Content-Type': 'application/json' } }
    )
  }
})
