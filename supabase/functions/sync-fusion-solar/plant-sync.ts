import { FusionSolarClient } from './fusion-solar-api.ts'

export async function syncPlants(
  userId: string,
  token: string,
  fusionSolarAPI: FusionSolarClient,
  supabaseClient: any
): Promise<any[]> {
  // Get plants from FusionSolar
  const plantsResponse = await fusionSolarAPI.apiCall(
    '/thirdData/getStationList',
    token,
    {}
  )

  if (!plantsResponse?.success || !plantsResponse.data) {
    throw new Error('Failed to get plants from FusionSolar')
  }

  const plants = plantsResponse.data

  // Update plants in database
  for (const plant of plants) {
    await supabaseClient
      .from('plants')
      .upsert({
        user_id: userId,
        stationCode: plant.stationCode,
        stationName: plant.stationName,
        stationAddr: plant.stationAddr,
        capacity: plant.capacity,
        fetched_at: new Date().toISOString()
      }, { onConflict: 'user_id,stationCode' })
  }

  return plants
}