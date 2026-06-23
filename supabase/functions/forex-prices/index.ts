const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Two batches of 8 (free plan = 8 credits/min) with 1.1s gap between them
const BATCH1 = 'EUR/USD,GBP/USD,USD/JPY,AUD/USD,USD/CAD,NZD/USD,USD/CHF,EUR/GBP'
const BATCH2 = 'XAU/USD,GBP/JPY,EUR/JPY,USOIL,UKOIL,NGAS,XAG/USD,USD/TRY'

let cache: string | null = null
let cacheTime = 0
const CACHE_TTL = 61_000

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const now = Date.now()
  if (cache && now - cacheTime < CACHE_TTL) {
    return new Response(cache, {
      headers: { ...CORS, 'Content-Type': 'application/json', 'X-Cache': 'HIT' },
    })
  }

  const KEY = Deno.env.get('TWELVEDATA_KEY') ?? ''
  const base = 'https://api.twelvedata.com'

  const res1  = await fetch(`${base}/price?symbol=${BATCH1}&apikey=${KEY}`)
  const data1 = await res1.json()

  // 1.1s gap so the two batches don't count in the same rate-limit second
  await new Promise(r => setTimeout(r, 1100))

  const res2  = await fetch(`${base}/price?symbol=${BATCH2}&apikey=${KEY}`)
  const data2 = await res2.json()

  const merged = { ...data1, ...data2 }

  cache = JSON.stringify(merged)
  cacheTime = Date.now()

  return new Response(cache, {
    headers: { ...CORS, 'Content-Type': 'application/json', 'X-Cache': 'MISS' },
  })
})
