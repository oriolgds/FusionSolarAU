import { FusionSolarAPI } from './fusion-solar-api.ts'

export async function syncPlants(
  userId: string,
  token: string,
  fusionSolarAPI: FusionSolarAPI,
  supabaseClient: any
): Promise<{ plants: any[], fromCache: boolean }> {
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
    
    // Check for rate limiting or other API issues - fallback to cache
    if (plantsResponse?.failCode === 407 || plantsResponse?.data === 'ACCESS_FREQUENCY_IS_TOO_HIGH' || !plantsResponse) {
      const { data: cachedPlants } = await supabaseClient
        .from('plants')
        .select('station_code, station_name, station_addr, capacity, aid_type, build_state, combine_type, linkman_pho, station_linkman')
        .eq('user_id', userId)
      
      return { plants: cachedPlants || [], fromCache: true }
    }
    
    throw new Error('Failed to get plants from FusionSolar')
  }

  const plants = plantsResponse.data

  // Update plants in database with fresh data
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

  return { plants, fromCache: false }
}