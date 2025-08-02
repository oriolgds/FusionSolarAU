import { FusionSolarAPI } from './fusion-solar-api.ts'

export async function syncPlants(
  userId: string,
  token: string,
  fusionSolarAPI: FusionSolarAPI,
  supabaseClient: any
): Promise<any[]> {
  // Get plants from FusionSolar
  const plantsResponse = await fusionSolarAPI.apiCall(
    '/thirdData/getStationList',
    token,
    {}
  )

  if (!plantsResponse?.success || !plantsResponse.data) {
    // Check for token expiration
    if (plantsResponse?.failCode === 305 || plantsResponse?.message === 'USER_MUST_RELOGIN') {
      throw new Error('USER_MUST_RELOGIN')
    }
    
    // Check for rate limiting
    if (plantsResponse?.failCode === 407 || plantsResponse?.data === 'ACCESS_FREQUENCY_IS_TOO_HIGH') {
      console.warn(`Rate limited for user ${userId}, using cached plants`)
      
      // Fallback to cached data
      const { data: cachedPlants } = await supabaseClient
        .from('plants')
        .select('*')
        .eq('user_id', userId)
      
      return cachedPlants || []
    }
    
    throw new Error('Failed to get plants from FusionSolar')
  }

  const plants = plantsResponse.data

  // Update plants in database only if we got fresh data from API
  if (plantsResponse?.success && plantsResponse.data) {
    for (const plant of plants) {
      const { error } = await supabaseClient
        .from('plants')
        .upsert({
          user_id: userId,
          station_code: plant.stationCode,
          station_name: plant.stationName,
          station_addr: plant.stationAddr,
          capacity: plant.capacity,
          aid_type: plant.aidType,
          build_state: plant.buildState,
          combine_type: plant.combineType,
          linkman_pho: plant.linkmanPho,
          station_linkman: plant.stationLinkman
        }, { onConflict: 'user_id,station_code' })

      if (error) {
        console.error('Error saving plant:', error)
        throw error
      }
    }
    console.log(`${plants.length} plants synced for user ${userId}`)
  } else {
    console.log(`Using ${plants.length} cached plants for user ${userId}`)
  }

  return plants
}