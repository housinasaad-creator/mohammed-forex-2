const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const BATCH1 = 'EUR/USD,GBP/USD,USD/JPY,AUD/USD,USD/CAD,NZD/USD,USD/CHF,EUR/GBP'
const BATCH2 = 'XAU/USD,GBP/JPY,EUR/JPY,USOIL,UKOIL,NGAS,XAG/USD,USD/TRY'

let cache: string | null = null
let cacheTime = 0
const CACHE_TTL = 5 * 60_000 // 5 minutes

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const now = Date.now()
  if (cache && now - cacheTime < CACHE_TTL) {
    return new Response(cache, { headers: { ...CORS, 'Content-Type': 'application/json' } })
  }

  const KEY  = Deno.env.get('TWELVEDATA_KEY') ?? ''
  const base = 'https://api.twelvedata.com'

  const res1  = await fetch(`${base}/time_series?symbol=${BATCH1}&interval=15min&outputsize=20&apikey=${KEY}`)
  const data1 = await res1.json()

  await new Promise(r => setTimeout(r, 1100))

  const res2  = await fetch(`${base}/time_series?symbol=${BATCH2}&interval=15min&outputsize=20&apikey=${KEY}`)
  const data2 = await res2.json()

  // Extract last 20 close prices (oldest→newest) per symbol
  const result: Record<string, number[]> = {}
  for (const raw of [data1, data2]) {
    for (const [sym, symData] of Object.entries(raw)) {
      const values = (symData as Record<string, unknown>)?.values
      if (Array.isArray(values) && values.length > 0) {
        result[sym] = [...values]
          .slice(0, 20)
          .map((v: Record<string, string>) => parseFloat(v.close))
          .reverse()
      }
    }
  }

  cache = JSON.stringify(result)
  cacheTime = now

  return new Response(cache, { headers: { ...CORS, 'Content-Type': 'application/json' } })
})
