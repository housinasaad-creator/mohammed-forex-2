const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

let cache: string | null = null
let cacheTime = 0
const CACHE_TTL = 60 * 60_000 // 1 hour

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  if (cache && Date.now() - cacheTime < CACHE_TTL) {
    return new Response(cache, { headers: { ...CORS, 'Content-Type': 'application/json' } })
  }

  const KEY = Deno.env.get('TWELVEDATA_KEY') ?? ''
  const today = new Date()
  const start = today.toISOString().slice(0, 10)
  const end7  = new Date(today.getTime() + 7 * 24 * 3600_000).toISOString().slice(0, 10)

  const res  = await fetch(
    `https://api.twelvedata.com/economic_calendar?start_date=${start}&end_date=${end7}&apikey=${KEY}`
  )
  const data = await res.json()

  // Keep only high & medium impact events, max 8
  const all    = data?.result?.values ?? []
  const events = all
    .filter((e: Record<string, string>) => e.impact === 'high' || e.impact === 'medium')
    .slice(0, 8)

  cache = JSON.stringify({ events })
  cacheTime = Date.now()

  return new Response(cache, { headers: { ...CORS, 'Content-Type': 'application/json' } })
})
