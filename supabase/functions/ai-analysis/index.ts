const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { symbol, rsi, macd, htf, zone, score, session, sessionQuality, sessionWarning, lang } = await req.json()

  const ANTHROPIC_KEY = Deno.env.get('ANTHROPIC_KEY') ?? ''

  const langLabel = lang === 'ar' ? 'Arabic' : lang === 'tr' ? 'Turkish' : 'English'

  const sessionCtx = sessionWarning
    ? `Current session: ${session ?? 'Unknown'} — LOW LIQUIDITY WARNING: ${sessionWarning} (quality: ${sessionQuality ?? 0}/1.0)`
    : `Current session: ${session ?? 'Unknown'} (quality: ${sessionQuality ?? 1}/1.0 — good liquidity)`

  const systemPrompt = `You are a professional forex and commodities scalping analyst with 15 years of experience.
Analyze the given technical data AND current trading session together.
Always respond in ${langLabel}.
Factor session quality into confidence — London/NY overlap (quality≈1.0) = excellent; Tokyo/Sydney (quality≈0.3) = caution and reduce size.
Be direct and professional. Maximum 3 sentences.`

  const userPrompt = `Asset: ${symbol}
RSI: ${rsi}
MACD: ${macd}
Higher Timeframe Trend: ${htf}
Supply/Demand Zone: ${zone}
Confluence Score: ${score}/100
${sessionCtx}

Based on ALL data including session context, provide:
1. Signal: BUY, SELL, or WAIT
2. Brief professional analysis in ${langLabel} — explicitly factor in the session quality and its impact on trade confidence`

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': ANTHROPIC_KEY,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 350,
      system: systemPrompt,
      messages: [{ role: 'user', content: userPrompt }],
    }),
  })

  const data = await res.json()
  const text = data?.content?.[0]?.text ?? 'Analysis unavailable.'

  return new Response(JSON.stringify({ analysis: text }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
