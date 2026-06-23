const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const cache: Record<string, { data: string; time: number }> = {}
const CACHE_TTL = 30 * 60_000 // 30 minutes — preserve daily API quota // 5 minutes

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { symbol, interval = '15min' } = await req.json()
  const cacheKey = `${symbol}_${interval}`
  const now = Date.now()

  if (cache[cacheKey] && now - cache[cacheKey].time < CACHE_TTL) {
    return new Response(cache[cacheKey].data, {
      headers: { ...CORS, 'Content-Type': 'application/json', 'X-Cache': 'HIT' },
    })
  }

  const KEY = Deno.env.get('TWELVEDATA_KEY') ?? ''
  const base = 'https://api.twelvedata.com'

  // Parallel fetch: RSI, MACD, EMA50(H1 for HTF), and candles for S/D zones
  const [rsiRes, macdRes, htfRes, tsRes] = await Promise.all([
    fetch(`${base}/rsi?symbol=${symbol}&interval=${interval}&outputsize=1&apikey=${KEY}`),
    fetch(`${base}/macd?symbol=${symbol}&interval=${interval}&outputsize=1&apikey=${KEY}`),
    fetch(`${base}/ema?symbol=${symbol}&interval=1h&time_period=50&outputsize=2&apikey=${KEY}`),
    fetch(`${base}/time_series?symbol=${symbol}&interval=${interval}&outputsize=300&apikey=${KEY}`),
  ])

  const [rsiData, macdData, htfData, tsData] = await Promise.all([
    rsiRes.json(), macdRes.json(), htfRes.json(), tsRes.json(),
  ])

  // Detect API errors (rate limit / quota exhaustion / bad key)
  console.log('RSI response:', JSON.stringify(rsiData))
  console.log('MACD response:', JSON.stringify(macdData))
  console.log('TS response keys:', Object.keys(tsData ?? {}))
  const apiError = rsiData?.code || macdData?.code || tsData?.code
  if (apiError) {
    const msg = rsiData?.message ?? macdData?.message ?? tsData?.message ?? 'API error'
    const debugInfo = { error: true, message: msg, code: apiError, rsi: rsiData, macd: macdData }
    console.log('API ERROR:', JSON.stringify(debugInfo))
    return new Response(JSON.stringify(debugInfo), {
      status: 503,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // ── RSI ──────────────────────────────────────────────────────────────────
  const rsi           = parseFloat(rsiData?.values?.[0]?.rsi       ?? '50')
  const macdValue     = parseFloat(macdData?.values?.[0]?.macd      ?? '0')
  const macdSignal    = parseFloat(macdData?.values?.[0]?.macd_signal ?? '0')
  const macdHistogram = parseFloat(macdData?.values?.[0]?.macd_hist  ?? '0')

  // ── HTF trend via EMA50 direction on H1 ──────────────────────────────────
  const ema1 = parseFloat(htfData?.values?.[0]?.ema ?? '0')
  const ema2 = parseFloat(htfData?.values?.[1]?.ema ?? '0')
  let htfTrend = 'Sideways'
  if (ema1 > 0 && ema2 > 0) {
    const pct = (ema1 - ema2) / ema2 * 100
    if (pct > 0.02)  htfTrend = 'Bullish'
    else if (pct < -0.02) htfTrend = 'Bearish'
  }

  // ── Supply/Demand zones via pivot detection ───────────────────────────────
  type Candle = { high: string; low: string; open: string; close: string }
  const candles: Candle[] = tsData?.values ?? []
  const currentPrice = parseFloat(candles[0]?.close ?? '0')
  const tolerance = currentPrice * 0.002 // 0.2% proximity

  const pivotHighs: number[] = []
  const pivotLows: number[]  = []

  for (let i = 2; i < candles.length - 2; i++) {
    const high = parseFloat(candles[i].high)
    const low  = parseFloat(candles[i].low)

    // Pivot high: higher than 2 neighbours on each side
    if (high > parseFloat(candles[i-1].high) && high > parseFloat(candles[i-2].high) &&
        high > parseFloat(candles[i+1].high) && high > parseFloat(candles[i+2].high)) {
      pivotHighs.push(high)
    }
    // Pivot low: lower than 2 neighbours on each side
    if (low < parseFloat(candles[i-1].low) && low < parseFloat(candles[i-2].low) &&
        low < parseFloat(candles[i+1].low) && low < parseFloat(candles[i+2].low)) {
      pivotLows.push(low)
    }
  }

  const nearLows  = pivotLows.filter(l  => Math.abs(currentPrice - l)  < tolerance)
  const nearHighs = pivotHighs.filter(h => Math.abs(currentPrice - h) < tolerance)

  let sdZone = 'neutral'
  if      (nearLows.length  >= 2) sdZone = 'strongDemand'
  else if (nearLows.length  === 1) sdZone = 'weakDemand'
  else if (nearHighs.length >= 2) sdZone = 'strongSupply'
  else if (nearHighs.length === 1) sdZone = 'weakSupply'

  // Candle data oldest→newest (100 candles)
  const candleData = candles.slice(0, 100).reverse().map((c: Candle) => ({
    o: parseFloat(c.open),
    h: parseFloat(c.high),
    l: parseFloat(c.low),
    c: parseFloat(c.close),
  }))

  const result = JSON.stringify({
    rsi, macd_value: macdValue, macd_signal: macdSignal,
    macd_histogram: macdHistogram, htf_trend: htfTrend, sd_zone: sdZone,
    candles: candleData,
    pivot_highs: pivotHighs.slice(0, 5),
    pivot_lows: pivotLows.slice(0, 5),
  })
  cache[cacheKey] = { data: result, time: now }

  return new Response(result, {
    headers: { ...CORS, 'Content-Type': 'application/json', 'X-Cache': 'MISS' },
  })
})
